part of 'speak_engine_manage_view.dart';

extension _SpeakEngineManageImportActions on _SpeakEngineManageViewState {
  Future<void> _importLocalRules() async {
    if (_importingLocal) return;
    _setImportingLocal(true);
    try {
      final fileText = await _pickLocalImportText();
      if (fileText == null) {
        return;
      }
      final candidates = await _ruleStore.previewImportCandidates(fileText);
      if (candidates.isEmpty) {
        await _showMessageDialog(
          title: '本地导入',
          message: '格式不对',
        );
        return;
      }
      if (!mounted) return;
      final selectedIndexes = await _showImportSelectionSheet(candidates);
      if (selectedIndexes == null || selectedIndexes.isEmpty) {
        return;
      }
      if (!mounted) return;
      await _runImportingTask(() async {
        await _ruleStore.importCandidates(
          candidates: candidates,
          selectedIndexes: selectedIndexes,
        );
      });
      await _reloadRules();
    } catch (error, stackTrace) {
      debugPrint('ImportError:$error');
      debugPrint('$stackTrace');
      if (!mounted) return;
      await _showMessageDialog(
        title: '本地导入',
        message: '导入失败：$error',
      );
    } finally {
      _setImportingLocal(false);
    }
  }

  Future<void> _importOnlineRules() async {
    if (_importingOnline) return;
    _setImportingOnline(true);
    try {
      final rawInput = await _showOnlineImportInputSheet();
      final normalizedInput = rawInput?.trim();
      if (normalizedInput == null || normalizedInput.isEmpty) {
        return;
      }
      if (_isHttpUrl(normalizedInput)) {
        await _pushOnlineImportHistory(normalizedInput);
      }
      final candidates = await _ruleStore.previewImportCandidates(
        normalizedInput,
      );
      if (candidates.isEmpty) {
        await _showMessageDialog(
          title: '网络导入',
          message: '格式不对',
        );
        return;
      }
      if (!mounted) return;
      final selectedIndexes = await _showImportSelectionSheet(candidates);
      if (selectedIndexes == null || selectedIndexes.isEmpty) {
        return;
      }
      if (!mounted) return;
      await _runImportingTask(() async {
        await _ruleStore.importCandidates(
          candidates: candidates,
          selectedIndexes: selectedIndexes,
        );
      });
      await _reloadRules();
    } on FormatException {
      if (!mounted) return;
      await _showMessageDialog(
        title: '网络导入',
        message: '格式不对',
      );
    } catch (error, stackTrace) {
      debugPrint('ImportError:$error');
      debugPrint('$stackTrace');
      if (!mounted) return;
      await _showMessageDialog(
        title: '网络导入',
        message: '导入失败：$error',
      );
    } finally {
      _setImportingOnline(false);
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

  Future<Set<int>?> _showImportSelectionSheet(
    List<HttpTtsImportCandidate> candidates,
  ) async {
    final selectedIndexes = <int>{
      for (var index = 0; index < candidates.length; index++)
        if (candidates[index].selectedByDefault) index,
    };
    return showCupertinoBottomSheetDialog<Set<int>>(
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
                  ? '取消全选($selectedCount/$totalCount)'
                  : '全选($selectedCount/$totalCount)';
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
                              '导入朗读引擎',
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
                                      selectedIndexes.toSet(),
                                    ),
                            child: Text('导入($selectedCount)'),
                          ),
                        ],
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                        child: CupertinoButton(
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
                          return _ImportCandidateTile(
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
}
