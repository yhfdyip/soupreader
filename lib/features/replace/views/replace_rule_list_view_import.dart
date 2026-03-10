// ignore_for_file: invalid_use_of_protected_member
part of 'replace_rule_list_view.dart';

extension _ReplaceRuleImportX on _ReplaceRuleListViewState {
  Future<void> _importFromFile() async {
    if (_importingLocal) return;
    setState(() => _importingLocal = true);
    try {
      final localText = await _pickLocalImportText();
      if (localText == null) {
        return;
      }
      await _importRulesFromInput(localText);
    } catch (error, stackTrace) {
      _recordViewError(
        node: 'replace_rule.import_local',
        message: '本地导入替换规则失败',
        error: error,
        stackTrace: stackTrace,
      );
      if (!mounted) return;
      await _showMessageDialog(
        title: '导入替换规则',
        message: _formatImportError(error),
      );
    } finally {
      if (mounted) {
        setState(() => _importingLocal = false);
      }
    }
  }

  Future<void> _importFromUrl() async {
    if (_importingOnline) return;
    setState(() => _importingOnline = true);
    try {
      final rawInput = await _showOnlineImportInputSheet();
      final normalizedInput = _sanitizeImportInput(rawInput ?? '');
      if (normalizedInput.isEmpty) {
        return;
      }
      if (_isHttpUrl(normalizedInput)) {
        await _pushOnlineImportHistory(normalizedInput);
      }
      await _importRulesFromInput(normalizedInput);
    } catch (error, stackTrace) {
      _recordViewError(
        node: 'replace_rule.import_online',
        message: '网络导入替换规则失败',
        error: error,
        stackTrace: stackTrace,
      );
      if (!mounted) return;
      await _showMessageDialog(
        title: '导入替换规则',
        message: _formatImportError(error),
      );
    } finally {
      if (mounted) {
        setState(() => _importingOnline = false);
      }
    }
  }

  Future<void> _importFromQr() async {
    if (_importingQr) return;
    setState(() => _importingQr = true);
    try {
      final text = await QrScanService.scanText(
        context,
        title: '二维码导入',
      );
      final normalizedInput = _sanitizeImportInput(text ?? '');
      if (normalizedInput.isEmpty) {
        return;
      }
      await _importRulesFromInput(normalizedInput);
    } catch (error, stackTrace) {
      _recordViewError(
        node: 'replace_rule.import_qr',
        message: '二维码导入替换规则失败',
        error: error,
        stackTrace: stackTrace,
      );
      if (!mounted) return;
      await _showMessageDialog(
        title: '导入替换规则',
        message: _formatImportError(error),
      );
    } finally {
      if (mounted) {
        setState(() => _importingQr = false);
      }
    }
  }

  Future<void> _importRulesFromInput(String rawInput) async {
    final importedRules = await _parseImportRulesFromInput(rawInput, depth: 0);
    final candidates = _buildImportCandidates(importedRules);
    if (candidates.isEmpty) {
      await _showMessageDialog(
        title: '导入替换规则',
        message: 'ImportError:格式不对',
      );
      return;
    }
    if (!mounted) return;
    final selectionDecision = await _showImportSelectionSheet(candidates);
    if (selectionDecision == null ||
        selectionDecision.selectedIndexes.isEmpty) {
      return;
    }
    if (!mounted) return;
    await _runImportingTask(() async {
      final selectedRules = <ReplaceRule>[];
      final sortedIndexes = selectionDecision.selectedIndexes.toList()..sort();
      for (final index in sortedIndexes) {
        if (index < 0 || index >= candidates.length) {
          continue;
        }
        selectedRules.add(
          _applyImportGroupPolicy(
            rule: candidates[index].rule,
            policy: selectionDecision.groupPolicy,
          ),
        );
      }
      await _repo.addRules(selectedRules);
    });
  }

  Future<List<ReplaceRule>> _parseImportRulesFromInput(
    String input, {
    required int depth,
  }) async {
    if (depth > _ReplaceRuleListViewState._maxImportDepth) {
      throw const FormatException('导入链接重定向层级过深');
    }
    final text = _sanitizeImportInput(input);
    if (text.isEmpty) {
      throw const FormatException('格式不对');
    }
    if (_looksLikeJson(text)) {
      final parsed = _io.importFromJson(text);
      if (parsed.success && parsed.rules.isNotEmpty) {
        return parsed.rules;
      }
      final detail = parsed.errorMessage?.trim();
      throw FormatException(
        detail == null || detail.isEmpty ? '格式不对' : detail,
      );
    }
    final parsedUri = Uri.tryParse(text);
    if (parsedUri != null) {
      final scheme = parsedUri.scheme.toLowerCase();
      if (scheme == 'http' || scheme == 'https') {
        final remoteText = await _loadTextFromUrl(text);
        return _parseImportRulesFromInput(remoteText, depth: depth + 1);
      }
      if (scheme == 'file') {
        final localText = await File.fromUri(parsedUri).readAsString();
        return _parseImportRulesFromInput(localText, depth: depth + 1);
      }
    }
    final localFile = File(text);
    if (await localFile.exists()) {
      final localText = await localFile.readAsString();
      return _parseImportRulesFromInput(localText, depth: depth + 1);
    }
    throw const FormatException('格式不对');
  }

  Future<String> _loadTextFromUrl(String rawUrl) async {
    var requestUrl = rawUrl.trim();
    var requestWithoutUa = false;
    if (requestUrl.endsWith(_ReplaceRuleListViewState._requestWithoutUaSuffix)) {
      requestWithoutUa = true;
      requestUrl = requestUrl.substring(
        0,
        requestUrl.length - _ReplaceRuleListViewState._requestWithoutUaSuffix.length,
      );
    }
    final uri = Uri.parse(requestUrl);
    final httpClient = HttpClient();
    try {
      final request = await httpClient.getUrl(uri);
      if (requestWithoutUa) {
        request.headers.set(HttpHeaders.userAgentHeader, 'null');
      }
      final response = await request.close();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException('HTTP ${response.statusCode}', uri: uri);
      }
      final text = await response.transform(utf8.decoder).join();
      if (_sanitizeImportInput(text).isEmpty) {
        throw const FormatException('格式不对');
      }
      return text;
    } finally {
      httpClient.close(force: true);
    }
  }

  Future<String?> _showOnlineImportInputSheet() async {
    final history = await _loadOnlineImportHistory();
    final inputController = TextEditingController();
    try {
      return showCupertinoBottomSheetDialog<String>(
        context: context,
        builder: (popupContext) {
          return CupertinoPopupSurface(
            isSurfacePainted: true,
            child: SizedBox(
              height: math.min(MediaQuery.sizeOf(context).height * 0.72, 560),
              child: StatefulBuilder(
                builder: (context, setDialogState) {
                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 12, 8),
                        child: Row(
                          children: [
                            const Expanded(
                              child: Text(
                                '网络导入',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            CupertinoButton(
                              padding: EdgeInsets.zero,
                              onPressed: () => Navigator.pop(popupContext),
                              child: const Text('取消'),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: CupertinoTextField(
                                controller: inputController,
                                placeholder: 'url',
                              ),
                            ),
                            const SizedBox(width: 8),
                            CupertinoButton.filled(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              onPressed: () {
                                Navigator.pop(
                                  popupContext,
                                  inputController.text.trim(),
                                );
                              },
                              child: const Text('导入'),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Row(
                          children: [
                            const Expanded(
                              child: Text(
                                '历史记录',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      Expanded(
                        child: history.isEmpty
                            ? const AppEmptyState(
                                illustration:
                                    AppEmptyPlanetIllustration(size: 76),
                                title: '暂无历史记录',
                                message: '输入 URL 并导入后会自动保存',
                              )
                            : ListView.separated(
                                padding:
                                    const EdgeInsets.fromLTRB(12, 0, 12, 12),
                                itemCount: history.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 6),
                                itemBuilder: (context, index) {
                                  final item = history[index];
                                  return AppCard(
                                    backgroundColor: CupertinoColors.systemGrey6.resolveFrom(context),
                                    padding:
                                        const EdgeInsets.fromLTRB(10, 8, 8, 8),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: GestureDetector(
                                            onTap: () {
                                              inputController.text = item;
                                            },
                                            child: Text(
                                              item,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style:
                                                  const TextStyle(fontSize: 13),
                                            ),
                                          ),
                                        ),
                                        CupertinoButton(
                                          padding: EdgeInsets.zero,
                                          minimumSize: const Size(28, 28),
                                          onPressed: () async {
                                            history.removeAt(index);
                                            await _saveOnlineImportHistory(
                                              history,
                                            );
                                            if (mounted) {
                                              setDialogState(() {});
                                            }
                                          },
                                          child: Icon(
                                            CupertinoIcons.delete,
                                            size: 18,
                                            color: CupertinoColors.systemRed.resolveFrom(context)
                                                .resolveFrom(context),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  );
                },
              ),
            ),
          );
        },
      );
    } finally {
      inputController.dispose();
    }
  }

  bool _isHttpUrl(String value) {
    final parsed = Uri.tryParse(value);
    if (parsed == null) return false;
    final scheme = parsed.scheme.toLowerCase();
    return scheme == 'http' || scheme == 'https';
  }

  Future<List<String>> _loadOnlineImportHistory() async {
    return _onlineImportHistoryStore.load(_ReplaceRuleListViewState._onlineImportHistoryKey);
  }

  Future<void> _saveOnlineImportHistory(List<String> history) async {
    await _onlineImportHistoryStore.save(_ReplaceRuleListViewState._onlineImportHistoryKey, history);
  }

  Future<void> _pushOnlineImportHistory(String url) async {
    await _onlineImportHistoryStore.push(_ReplaceRuleListViewState._onlineImportHistoryKey, url);
  }

  bool _looksLikeJson(String value) {
    return value.startsWith('{') || value.startsWith('[');
  }

  Future<void> _showExportPathDialog(String outputPath) async {
    final path = outputPath.trim();
    if (path.isEmpty || !mounted) return;
    final uri = Uri.tryParse(path);
    final isHttpPath = uri != null &&
        (uri.scheme.toLowerCase() == 'http' ||
            uri.scheme.toLowerCase() == 'https');
    final lines = <String>[
      '导出路径：',
      path,
      if (isHttpPath) '',
      if (isHttpPath) '检测到网络链接，可直接复制后分享。',
    ];
    await showCupertinoBottomDialog<void>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: const Text('导出成功'),
        content: Text('\n${lines.join('\n')}'),
        actions: [
          CupertinoDialogAction(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: path));
              if (!dialogContext.mounted) return;
              Navigator.pop(dialogContext);
            },
            child: const Text('复制路径'),
          ),
        ],
      ),
    );
  }

  void _showMessage(String message) {
    showCupertinoBottomDialog<void>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('提示'),
        content: Text('\n$message'),
        actions: [
          CupertinoDialogAction(
            child: const Text('好'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Future<void> _showReplaceRuleHelp() async {
    try {
      final markdownText =
          await rootBundle.loadString('assets/web/help/md/replaceRuleHelp.md');
      if (!mounted) return;
      await showAppHelpDialog(context, markdownText: markdownText);
    } catch (error) {
      if (!mounted) return;
      _showMessage('帮助文档加载失败：$error');
    }
  }

  List<_ReplaceRuleImportCandidate> _buildImportCandidates(
    List<ReplaceRule> importedRules,
  ) {
    final localById = <int, ReplaceRule>{
      for (final rule in _repo.getAllRules()) rule.id: rule,
    };
    return importedRules.map((rule) {
      final localRule = localById[rule.id];
      return _ReplaceRuleImportCandidate(
        rule: rule,
        localRule: localRule,
        state: _resolveCandidateState(
          importedRule: rule,
          localRule: localRule,
        ),
      );
    }).toList(growable: false);
  }

  _ReplaceRuleImportCandidateState _resolveCandidateState({
    required ReplaceRule importedRule,
    required ReplaceRule? localRule,
  }) {
    if (localRule == null) {
      return _ReplaceRuleImportCandidateState.newRule;
    }
    if (importedRule.pattern != localRule.pattern ||
        importedRule.replacement != localRule.replacement ||
        importedRule.isRegex != localRule.isRegex ||
        importedRule.scope != localRule.scope) {
      return _ReplaceRuleImportCandidateState.update;
    }
    return _ReplaceRuleImportCandidateState.existing;
  }

  Future<_ReplaceRuleImportSelectionDecision?> _showImportSelectionSheet(
    List<_ReplaceRuleImportCandidate> candidates,
  ) async {
    final selectedIndexes = <int>{
      for (var index = 0; index < candidates.length; index++)
        if (candidates[index].selectedByDefault) index,
    };
    var customGroupName = '';
    var appendCustomGroup = false;
    return showCupertinoBottomSheetDialog<_ReplaceRuleImportSelectionDecision>(
      context: context,
      builder: (popupContext) {
        return CupertinoPopupSurface(
          isSurfacePainted: true,
          child: StatefulBuilder(
            builder: (context, setDialogState) {
              final selectedCount = selectedIndexes.length;
              final totalCount = candidates.length;
              final allSelected = totalCount > 0 && selectedCount == totalCount;
              final toggleAllLabel = allSelected
                  ? '取消全选（$selectedCount/$totalCount）'
                  : '全选（$selectedCount/$totalCount）';
              return SizedBox(
                height: math.min(
                  MediaQuery.sizeOf(context).height * 0.86,
                  680,
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 10, 8, 8),
                      child: Row(
                        children: [
                          const Expanded(
                            child: Text(
                              '导入替换规则',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          CupertinoButton(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            onPressed: () => Navigator.pop(popupContext),
                            child: const Text('取消'),
                          ),
                          CupertinoButton.filled(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            onPressed: selectedCount == 0
                                ? null
                                : () => Navigator.pop(
                                      popupContext,
                                      _ReplaceRuleImportSelectionDecision(
                                        selectedIndexes:
                                            selectedIndexes.toSet(),
                                        groupPolicy:
                                            _ReplaceRuleImportGroupPolicy(
                                          groupName: customGroupName,
                                          appendGroup: appendCustomGroup,
                                        ),
                                      ),
                                    ),
                            child: Text('导入($selectedCount)'),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          CupertinoButton(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            color: CupertinoColors.systemGrey5.resolveFrom(context),
                            onPressed: () {
                              setDialogState(() {
                                if (allSelected) {
                                  selectedIndexes.clear();
                                } else {
                                  selectedIndexes
                                    ..clear()
                                    ..addAll(
                                      List<int>.generate(
                                        candidates.length,
                                        (index) => index,
                                      ),
                                    );
                                }
                              });
                            },
                            child: Text(toggleAllLabel),
                          ),
                          CupertinoButton(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            color: CupertinoColors.systemGrey5.resolveFrom(context),
                            onPressed: () async {
                              final input = await _showImportCustomGroupDialog(
                                initialGroupName: customGroupName,
                                initialAppendGroup: appendCustomGroup,
                              );
                              if (input == null || !popupContext.mounted) {
                                return;
                              }
                              setDialogState(() {
                                customGroupName = input.groupName;
                                appendCustomGroup = input.appendGroup;
                              });
                            },
                            child: Text(
                              _buildImportGroupActionLabel(
                                groupName: customGroupName,
                                appendGroup: appendCustomGroup,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                        itemCount: candidates.length,
                        separatorBuilder: (context, _) =>
                            const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final candidate = candidates[index];
                          final selected = selectedIndexes.contains(index);
                          return _ReplaceRuleImportCandidateTile(
                            candidate: candidate,
                            selected: selected,
                            onTap: () {
                              setDialogState(() {
                                if (selected) {
                                  selectedIndexes.remove(index);
                                } else {
                                  selectedIndexes.add(index);
                                }
                              });
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  ReplaceRule _applyImportGroupPolicy({
    required ReplaceRule rule,
    required _ReplaceRuleImportGroupPolicy policy,
  }) {
    final groupName = policy.groupName.trim();
    if (groupName.isEmpty) {
      return rule;
    }
    if (!policy.appendGroup) {
      return rule.copyWith(group: groupName);
    }
    final groups = <String>{};
    final rawGroup = rule.group;
    if (rawGroup != null && rawGroup.isNotEmpty) {
      for (final part in rawGroup.split(_ReplaceRuleListViewState._groupSplitPattern)) {
        final normalized = part.trim();
        if (normalized.isEmpty) continue;
        groups.add(normalized);
      }
    }
    groups.add(groupName);
    return rule.copyWith(group: groups.join(','));
  }

  String _buildImportGroupActionLabel({
    required String groupName,
    required bool appendGroup,
  }) {
    final normalized = groupName.trim();
    if (normalized.isEmpty) {
      return '自定义源分组';
    }
    final title = '【$normalized】';
    if (appendGroup) {
      return '+$title';
    }
    return title;
  }

  Future<_ReplaceRuleImportGroupInput?> _showImportCustomGroupDialog({
    required String initialGroupName,
    required bool initialAppendGroup,
  }) async {
    final controller = TextEditingController(text: initialGroupName.trim());
    var appendGroup = initialAppendGroup;
    try {
      return showCupertinoBottomDialog<_ReplaceRuleImportGroupInput>(
        context: context,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              return CupertinoAlertDialog(
                title: const Text('输入自定义源分组名称'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 12),
                    CupertinoTextField(
                      controller: controller,
                      placeholder: '分组名',
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            '追加分组',
                            style: TextStyle(fontSize: 14),
                          ),
                        ),
                        CupertinoSwitch(
                          value: appendGroup,
                          onChanged: (value) {
                            setDialogState(() => appendGroup = value);
                          },
                        ),
                      ],
                    ),
                  ],
                ),
                actions: [
                  CupertinoDialogAction(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    child: const Text('取消'),
                  ),
                  CupertinoDialogAction(
                    onPressed: () {
                      Navigator.of(dialogContext).pop(
                        _ReplaceRuleImportGroupInput(
                          groupName: controller.text.trim(),
                          appendGroup: appendGroup,
                        ),
                      );
                    },
                    child: const Text('确定'),
                  ),
                ],
              );
            },
          );
        },
      );
    } finally {
      controller.dispose();
    }
  }

  Future<void> _runImportingTask(Future<void> Function() task) async {
    final navigator = Navigator.of(context, rootNavigator: true);
    showCupertinoBottomDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => const CupertinoAlertDialog(
        content: AppBlockingProgress(text: '导入中...'),
      ),
    );
    await Future<void>.delayed(Duration.zero);
    try {
      await task();
    } finally {
      if (navigator.canPop()) {
        navigator.pop();
      }
    }
  }

  Future<String?> _pickLocalImportText() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['txt', 'json'],
      allowMultiple: false,
      withData: true,
    );
    if (result == null || result.files.isEmpty) {
      return null;
    }
    final file = result.files.first;
    if (file.bytes != null) {
      return utf8.decode(file.bytes!, allowMalformed: true);
    }
    final path = file.path;
    if (path != null && path.trim().isNotEmpty) {
      return File(path).readAsString();
    }
    throw const FileSystemException('无法读取文件内容');
  }

  String _sanitizeImportInput(String input) {
    var value = input.trim();
    if (value.startsWith('\uFEFF')) {
      value = value.replaceFirst(RegExp(r'^\uFEFF+'), '');
    }
    return value.trim();
  }

  String _formatImportError(Object error) {
    if (error is FileSystemException) {
      final message = error.message.trim();
      if (message.isEmpty) return 'readTextError:ERROR';
      return 'readTextError:$message';
    }
    if (error is FormatException) {
      final message = error.message.trim();
      if (message.isEmpty) return 'ImportError:格式不对';
      return 'ImportError:$message';
    }
    final text = '$error'.trim();
    if (text.isEmpty) return 'ImportError:ERROR';
    if (text.startsWith('Exception:')) {
      final stripped = text.substring('Exception:'.length).trim();
      return stripped.isEmpty ? 'ImportError:ERROR' : 'ImportError:$stripped';
    }
    return 'ImportError:$text';
  }

  Future<void> _showMessageDialog({
    required String title,
    required String message,
  }) async {
    if (!mounted) return;
    await showCupertinoBottomDialog<void>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }
}
