// ignore_for_file: invalid_use_of_protected_member
part of 'source_edit_view.dart';

extension _SourceEditDebugX on _SourceEditViewState {
  Widget _buildDebugTab() {
    return AppListView(
      controller: _debugTabScrollController,
      children: [
        _buildDebugOverviewSection(),
        _buildDebugPrimaryInputSection(),
        if (_showDebugQuickHelp) _buildDebugQuickActionsSection(),
        _buildDebugResultNavSection(),
        _buildDebugSecondaryToolsSection(),
        _buildDebugConsoleSection(),
      ],
    );
  }

  String _debugStatusText() {
    if (_debugLoading) return '运行中';
    if ((_debugError ?? '').trim().isNotEmpty) return '失败';
    if (_debugLinesAll.isNotEmpty) return '已完成';
    return '未开始';
  }

  Color _debugStatusColor() {
    if (_debugLoading) {
      return CupertinoColors.systemBlue.resolveFrom(context);
    }
    if ((_debugError ?? '').trim().isNotEmpty) {
      return CupertinoColors.systemRed.resolveFrom(context);
    }
    if (_debugLinesAll.isNotEmpty) {
      return CupertinoColors.systemGreen.resolveFrom(context);
    }
    return CupertinoColors.secondaryLabel.resolveFrom(context);
  }

  Widget _buildCupertinoDebugCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: CupertinoColors.secondarySystemGroupedBackground
            .resolveFrom(context),
        borderRadius: BorderRadius.circular(AppDesignTokens.radiusCard),
      ),
      child: child,
    );
  }

  Widget _buildCupertinoDebugDivider() {
    return Container(
      height: 0.5,
      color: CupertinoColors.separator.resolveFrom(context),
    );
  }

  Widget _buildCupertinoGhostButton({
    required VoidCallback? onPressed,
    required Widget child,
    EdgeInsetsGeometry padding =
        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
  }) {
    final uiTokens = AppUiTokens.resolve(context);
    final enabled = onPressed != null;
    final fillColor =
        CupertinoColors.systemGrey5.resolveFrom(context).withValues(
              alpha: enabled ? 1 : 0.65,
            );
    final textColor = enabled
        ? CupertinoTheme.of(context).primaryColor
        : CupertinoColors.inactiveGray.resolveFrom(context);
    final borderColor =
        CupertinoColors.separator.resolveFrom(context).withValues(
              alpha: enabled ? 0.45 : 0.3,
            );
    return DecoratedBox(
      decoration: BoxDecoration(
        color: fillColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor, width: 0.6),
      ),
      child: CupertinoButton(
        padding: padding,
        minimumSize: uiTokens.sizes.compactTapSquare,
        onPressed: onPressed,
        child: DefaultTextStyle.merge(
          style: TextStyle(
            color: textColor,
            fontSize: 13,
          ),
          child: IconTheme(
            data: IconThemeData(color: textColor),
            child: child,
          ),
        ),
      ),
    );
  }

  Widget _buildDebugOverviewSection() {
    final secondaryLabelColor = CupertinoColors.secondaryLabel.resolveFrom(
      context,
    );
    final smallTextStyle =
        CupertinoTheme.of(context).textTheme.textStyle.copyWith(
              fontSize: 12,
              color: secondaryLabelColor,
            );
    final totalLines = _debugLinesAll.length;
    final hasLines = totalLines > 0;
    final hasError = (_debugError ?? '').trim().isNotEmpty;
    final statusColor = _debugStatusColor();

    return AppListSection(
      header: const Text('调试状态'),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: _buildCupertinoDebugCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '意图：${_currentDebugIntentHint()}',
                        style: smallTextStyle,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: statusColor.withValues(alpha: 0.36),
                        ),
                      ),
                      child: Text(
                        _debugStatusText(),
                        style: smallTextStyle.copyWith(
                          color: statusColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _buildCupertinoDebugDivider(),
                const SizedBox(height: 8),
                Text(
                  '日志 $totalLines 行 · 自动跟随 ${_debugAutoFollowLogs ? '开启' : '暂停'}',
                  style: smallTextStyle,
                ),
                if (hasError) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: CupertinoColors.systemRed
                          .resolveFrom(context)
                          .withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppDesignTokens.radiusControl),
                      border: Border.all(
                        color: CupertinoColors.systemRed
                            .resolveFrom(context)
                            .withValues(alpha: 0.35),
                      ),
                    ),
                    child: Text(
                      _debugError!.trim(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: smallTextStyle.copyWith(
                        color: CupertinoColors.systemRed.resolveFrom(context),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildCupertinoGhostButton(
                      onPressed: (hasLines && !_debugAutoFollowLogs)
                          ? () => _scrollDebugToBottom(
                                forceFollow: true,
                                animated: true,
                              )
                          : null,
                      child: const Text('回到最新日志'),
                    ),
                    _buildCupertinoGhostButton(
                      onPressed: hasLines ? _copyDebugConsole : null,
                      child: const Text('复制控制台'),
                    ),
                    _buildCupertinoGhostButton(
                      onPressed: hasLines ? _copyMinimalReproInfo : null,
                      child: const Text('复制复现信息'),
                    ),
                    _buildCupertinoGhostButton(
                      onPressed: hasLines ? _clearDebugConsole : null,
                      child: const Text('清空日志'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDebugResultNavSection() {
    return Column(
      children: [
        _buildDiagnosisSection(),
        _buildDebugSourcesSection(),
      ],
    );
  }

  Widget _buildDebugPrimaryInputSection() {
    final secondaryLabelColor = CupertinoColors.secondaryLabel.resolveFrom(
      context,
    );

    return AppListSection(
      header: const Text('快速输入'),
      footer: const Text('关键字/URL/前缀调试；完整语法见“工具 -> 菜单 -> 调试帮助”。'),
      children: [
        CupertinoListTile.notched(
          title: const Text('Key'),
          additionalInfo: Text(_currentDebugIntentHint()),
          subtitle: CupertinoTextField(
            controller: _debugKeyCtrl,
            focusNode: _debugKeyFocusNode,
            placeholder: '输入关键字或调试 key',
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _startDebugFromInputSubmit(),
            onChanged: (_) => setState(() {}),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: double.infinity,
                child: CupertinoButton.filled(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  onPressed: _debugLoading ? null : _startLegadoStyleDebug,
                  child: Text(_debugLoading ? '调试运行中…' : '开始调试'),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '输入后按对应链路执行（搜索/详情/发现/目录/正文）。',
                style: TextStyle(
                  fontSize: 12,
                  color: secondaryLabelColor,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDebugSecondaryToolsSection() {
    final hasLogs = _debugLinesAll.isNotEmpty;
    final quickToggleTitle = _showDebugQuickHelp ? '收起快捷动作' : '显示快捷动作';
    final quickToggleDesc =
        _showDebugQuickHelp ? '减少首屏占用，保留核心输入与结果' : '重新展开“我的/系统/发现候选/++/--”快捷区';

    return AppListSection(
      header: const Text('工具'),
      children: [
        CupertinoListTile.notched(
          title: Text(quickToggleTitle),
          subtitle: Text(quickToggleDesc),
          trailing: const CupertinoListTileChevron(),
          onTap: () {
            setState(() => _showDebugQuickHelp = !_showDebugQuickHelp);
            if (_showDebugQuickHelp) {
              _debugKeyFocusNode.requestFocus();
            }
          },
        ),
        CupertinoListTile.notched(
          title: const Text('菜单'),
          subtitle: const Text('扫码/查看源码/刷新发现/调试帮助'),
          additionalInfo:
              _refreshingExploreQuickActions ? const Text('刷新中…') : null,
          trailing: const CupertinoListTileChevron(),
          onTap: _showDebugLegacyMenuSheet,
        ),
        CupertinoListTile.notched(
          title: const Text('高级工具'),
          subtitle: const Text('导出/摘要/变量快照/网页验证'),
          trailing: const CupertinoListTileChevron(),
          onTap: _showDebugMoreToolsSheet,
        ),
        CupertinoListTile.notched(
          title: const Text('复制控制台（全部）'),
          subtitle: Text(hasLogs ? '共 ${_debugLinesAll.length} 行' : '暂无日志'),
          trailing: const CupertinoListTileChevron(),
          onTap: hasLogs ? _copyDebugConsole : null,
        ),
        CupertinoListTile.notched(
          title: const Text('一键导出调试包（推荐）'),
          subtitle: const Text('自动打包摘要、控制台与书源 JSON'),
          trailing: const CupertinoListTileChevron(),
          onTap: hasLogs
              ? () => _exportDebugBundleToFile(includeRawSources: false)
              : null,
        ),
      ],
    );
  }

  void _onDebugTabScrolled() {
    if (!_debugTabScrollController.hasClients) return;
    final position = _debugTabScrollController.position;
    final nearBottom = (position.maxScrollExtent - position.pixels) <= 72;
    if (nearBottom == _debugAutoFollowLogs) return;
    if (!mounted) {
      _debugAutoFollowLogs = nearBottom;
      return;
    }
    setState(() => _debugAutoFollowLogs = nearBottom);
  }

  void _onDebugKeyFocusChanged() {
    if (!_debugKeyFocusNode.hasFocus || !mounted) return;
  }

  void _queueDebugAutoScroll({bool force = false}) {
    if (!force && !_debugAutoFollowLogs) return;
    if (_debugAutoScrollQueued) return;
    _debugAutoScrollQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _debugAutoScrollQueued = false;
      if (!mounted || !_debugTabScrollController.hasClients) return;
      _scrollDebugToBottom(forceFollow: force, animated: false);
    });
  }

  void _scrollDebugToBottom({
    bool forceFollow = false,
    bool animated = false,
  }) {
    if (!_debugTabScrollController.hasClients) return;
    final target = _debugTabScrollController.position.maxScrollExtent;
    if (forceFollow && _debugAutoFollowLogs != true) {
      if (mounted) {
        setState(() => _debugAutoFollowLogs = true);
      } else {
        _debugAutoFollowLogs = true;
      }
    }
    if (animated) {
      _debugTabScrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
      );
      return;
    }
    _debugTabScrollController.jumpTo(target);
  }

  String? _structuredSummaryText() {
    if (_debugLinesAll.isEmpty) return null;
    return _prettyJson(LegadoJson.encode(_buildStructuredDebugSummary()));
  }

  String? _runtimeSnapshotText() {
    if (_debugRuntimeVarsSnapshot.isEmpty) return null;
    return _prettyJson(LegadoJson.encode(_debugRuntimeVarsSnapshot));
  }

  Future<void> _showDebugLegacyMenuSheet() async {
    final selected = await showAppActionListSheet<_SourceEditDebugMenuAction>(
      context: context,
      title: '菜单',
      showCancel: true,
      items: const [
        AppActionListItem<_SourceEditDebugMenuAction>(
          value: _SourceEditDebugMenuAction.scanDebugKeyFromQr,
          icon: CupertinoIcons.qrcode_viewfinder,
          label: '扫码填充 Key',
        ),
        AppActionListItem<_SourceEditDebugMenuAction>(
          value: _SourceEditDebugMenuAction.openSearchSource,
          icon: CupertinoIcons.search,
          label: '查看搜索源码',
        ),
        AppActionListItem<_SourceEditDebugMenuAction>(
          value: _SourceEditDebugMenuAction.openBookSource,
          icon: CupertinoIcons.book,
          label: '查看详情源码',
        ),
        AppActionListItem<_SourceEditDebugMenuAction>(
          value: _SourceEditDebugMenuAction.openTocSource,
          icon: CupertinoIcons.list_bullet,
          label: '查看目录源码',
        ),
        AppActionListItem<_SourceEditDebugMenuAction>(
          value: _SourceEditDebugMenuAction.openContentSource,
          icon: CupertinoIcons.doc_text,
          label: '查看正文源码',
        ),
        AppActionListItem<_SourceEditDebugMenuAction>(
          value: _SourceEditDebugMenuAction.refreshExploreQuickActions,
          icon: CupertinoIcons.refresh,
          label: '刷新发现快捷项',
        ),
        AppActionListItem<_SourceEditDebugMenuAction>(
          value: _SourceEditDebugMenuAction.openDebugHelp,
          icon: CupertinoIcons.question_circle,
          label: '调试帮助',
        ),
      ],
    );
    if (selected == null || !mounted) return;
    switch (selected) {
      case _SourceEditDebugMenuAction.scanDebugKeyFromQr:
        if (_debugLoading) {
          _showMessage('调试运行中，请稍后再试');
          return;
        }
        await _scanDebugKeyFromQr();
        return;
      case _SourceEditDebugMenuAction.openSearchSource:
        _openDebugSourceFromMenu('列表页源码', _debugListSrcHtml);
        return;
      case _SourceEditDebugMenuAction.openBookSource:
        _openDebugSourceFromMenu('详情页源码', _debugBookSrcHtml);
        return;
      case _SourceEditDebugMenuAction.openTocSource:
        _openDebugSourceFromMenu('目录页源码', _debugTocSrcHtml);
        return;
      case _SourceEditDebugMenuAction.openContentSource:
        _openDebugSourceFromMenu('正文页源码', _debugContentSrcHtml);
        return;
      case _SourceEditDebugMenuAction.refreshExploreQuickActions:
        if (_refreshingExploreQuickActions) {
          _showMessage('发现快捷项刷新中，请稍后再试');
          return;
        }
        await _refreshExploreQuickActions();
        return;
      case _SourceEditDebugMenuAction.openDebugHelp:
        await _showDebugHelp();
        return;
    }
  }

  Future<void> _showDebugMoreToolsSheet() async {
    final selected = await showAppActionListSheet<_SourceEditDebugToolsAction>(
      context: context,
      title: '高级工具',
      message: '问题复现与导出能力，集中在二级入口。',
      showCancel: true,
      items: const [
        AppActionListItem<_SourceEditDebugToolsAction>(
          value: _SourceEditDebugToolsAction.openWebVerify,
          icon: CupertinoIcons.cloud,
          label: '网页验证（Cloudflare）',
        ),
        AppActionListItem<_SourceEditDebugToolsAction>(
          value: _SourceEditDebugToolsAction.openDebugAdvancedPanel,
          icon: CupertinoIcons.wrench,
          label: '高级诊断与源码',
        ),
        AppActionListItem<_SourceEditDebugToolsAction>(
          value: _SourceEditDebugToolsAction.openStructuredSummary,
          icon: CupertinoIcons.doc_text_search,
          label: '结构化调试摘要（脱敏）',
        ),
        AppActionListItem<_SourceEditDebugToolsAction>(
          value: _SourceEditDebugToolsAction.copyStructuredSummary,
          icon: CupertinoIcons.doc_on_doc,
          label: '复制调试摘要（脱敏）',
        ),
        AppActionListItem<_SourceEditDebugToolsAction>(
          value: _SourceEditDebugToolsAction.exportDebugBundleQuick,
          icon: CupertinoIcons.square_arrow_up,
          label: '一键导出调试包（推荐）',
        ),
        AppActionListItem<_SourceEditDebugToolsAction>(
          value: _SourceEditDebugToolsAction.exportDebugBundleMore,
          icon: CupertinoIcons.ellipsis_circle,
          label: '导出调试包（更多选项）',
        ),
        AppActionListItem<_SourceEditDebugToolsAction>(
          value: _SourceEditDebugToolsAction.openRuntimeSnapshot,
          icon: CupertinoIcons.clock,
          label: '运行时变量快照（脱敏）',
        ),
        AppActionListItem<_SourceEditDebugToolsAction>(
          value: _SourceEditDebugToolsAction.copyRuntimeSnapshot,
          icon: CupertinoIcons.doc_on_clipboard,
          label: '复制变量快照（脱敏）',
        ),
        AppActionListItem<_SourceEditDebugToolsAction>(
          value: _SourceEditDebugToolsAction.copyDebugConsole,
          icon: CupertinoIcons.text_bubble,
          label: '复制控制台（全部）',
        ),
        AppActionListItem<_SourceEditDebugToolsAction>(
          value: _SourceEditDebugToolsAction.copyMinimalReproInfo,
          icon: CupertinoIcons.info_circle,
          label: '复制最小复现信息',
        ),
        AppActionListItem<_SourceEditDebugToolsAction>(
          value: _SourceEditDebugToolsAction.clearDebugConsole,
          icon: CupertinoIcons.delete,
          label: '清空控制台',
          isDestructiveAction: true,
        ),
      ],
    );
    if (selected == null || !mounted) return;
    switch (selected) {
      case _SourceEditDebugToolsAction.openWebVerify:
        _openWebVerify();
        return;
      case _SourceEditDebugToolsAction.openDebugAdvancedPanel:
        await _openDebugAdvancedPanel();
        return;
      case _SourceEditDebugToolsAction.openStructuredSummary:
        final structuredSummary = _structuredSummaryText();
        if (structuredSummary == null) {
          _showMessage('暂无调试摘要，请先执行调试');
          return;
        }
        await _openDebugText(title: '结构化调试摘要', text: structuredSummary);
        return;
      case _SourceEditDebugToolsAction.copyStructuredSummary:
        final structuredSummary = _structuredSummaryText();
        if (structuredSummary == null) {
          _showMessage('暂无调试摘要，请先执行调试');
          return;
        }
        await Clipboard.setData(ClipboardData(text: structuredSummary));
        if (mounted) unawaited(showAppToast(context, message: '已复制调试摘要（脱敏）'));
        return;
      case _SourceEditDebugToolsAction.exportDebugBundleQuick:
        if (_debugLinesAll.isEmpty) {
          _showMessage('暂无调试日志，请先执行调试');
          return;
        }
        await _exportDebugBundleToFile(includeRawSources: false);
        return;
      case _SourceEditDebugToolsAction.exportDebugBundleMore:
        if (_debugLinesAll.isEmpty) {
          _showMessage('暂无调试日志，请先执行调试');
          return;
        }
        await _showExportDebugBundleSheet();
        return;
      case _SourceEditDebugToolsAction.openRuntimeSnapshot:
        final runtimeSnapshot = _runtimeSnapshotText();
        if (runtimeSnapshot == null) {
          _showMessage('暂无变量快照');
          return;
        }
        await _openDebugText(title: '运行时变量快照（脱敏）', text: runtimeSnapshot);
        return;
      case _SourceEditDebugToolsAction.copyRuntimeSnapshot:
        final runtimeSnapshot = _runtimeSnapshotText();
        if (runtimeSnapshot == null) {
          _showMessage('暂无变量快照');
          return;
        }
        await Clipboard.setData(ClipboardData(text: runtimeSnapshot));
        if (mounted) unawaited(showAppToast(context, message: '已复制变量快照（脱敏）'));
        return;
      case _SourceEditDebugToolsAction.copyDebugConsole:
        _copyDebugConsole();
        return;
      case _SourceEditDebugToolsAction.copyMinimalReproInfo:
        _copyMinimalReproInfo();
        return;
      case _SourceEditDebugToolsAction.clearDebugConsole:
        _clearDebugConsole();
        return;
    }
  }

  Future<void> _openDebugAdvancedPanel() async {
    await Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (_) => AppCupertinoPageScaffold(
          title: '高级调试',
          child: AppListView(
            children: [
              _buildDiagnosisSection(),
              _buildDebugSourcesSection(),
            ],
          ),
        ),
      ),
    );
  }

  void _openWebVerify() {
    final map = _buildPatchedJsonForDebug();
    if (map == null) {
      _showMessage('JSON 格式错误');
      return;
    }
    final source = BookSource.fromJson(map);
    if (source.bookSourceUrl.trim().isEmpty) {
      _showMessage('bookSourceUrl 不能为空');
      return;
    }

    final key = _debugKeyCtrl.text.trim();
    final url = _resolveWebVerifyUrl(source: source, key: key);
    Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (_) => SourceWebVerifyView(
          initialUrl: url,
          sourceOrigin: source.bookSourceUrl,
          sourceName: source.bookSourceName,
        ),
      ),
    );
  }

  String _resolveWebVerifyUrl({
    required BookSource source,
    required String key,
  }) {
    String abs(String url) {
      final t = url.trim();
      if (t.startsWith('http://') || t.startsWith('https://')) return t;
      if (t.startsWith('//')) return 'https:$t';
      if (t.startsWith('/')) {
        final uri = Uri.parse(source.bookSourceUrl);
        return '${uri.scheme}://${uri.host}$t';
      }
      return '${source.bookSourceUrl}$t';
    }

    String buildSearchUrl(String template, String keyword) {
      var url = template;
      final enc = Uri.encodeComponent(keyword);
      url = url.replaceAll('{{key}}', enc);
      url = url.replaceAll('{key}', enc);
      url = url.replaceAll('{{searchKey}}', enc);
      url = url.replaceAll('{searchKey}', enc);
      return url;
    }

    if (key.isEmpty) return source.bookSourceUrl;
    if (key.startsWith('http://') || key.startsWith('https://')) return key;
    if (key.contains('::')) {
      final idx = key.indexOf('::');
      final url = key.substring(idx + 2).trim();
      return abs(url);
    }
    if (key.startsWith('++') || key.startsWith('--')) {
      final url = key.substring(2).trim();
      return abs(url);
    }
    if (source.searchUrl != null && source.searchUrl!.trim().isNotEmpty) {
      return abs(buildSearchUrl(source.searchUrl!.trim(), key));
    }
    return source.bookSourceUrl;
  }

  Widget _buildDebugQuickActionsSection() {
    final defaultSearchKey = _defaultDebugSearchKey();
    final myLabel = defaultSearchKey;
    final exploreEntries = _collectExploreQuickEntries();
    final actions = <Widget>[
      _buildQuickActionButton(
        label: myLabel,
        onTap: () => _setDebugKeyAndMaybeRun(defaultSearchKey, run: true),
      ),
      _buildQuickActionButton(
        label: '系统',
        onTap: () => _setDebugKeyAndMaybeRun('系统', run: true),
      ),
      if (exploreEntries.isNotEmpty)
        _buildQuickActionButton(
          label: exploreEntries.first.value,
          onTap: () =>
              _setDebugKeyAndMaybeRun(exploreEntries.first.key, run: true),
        ),
      if (exploreEntries.length > 1)
        _buildQuickActionButton(
          label: '发现候选',
          onTap: () => _showExploreQuickPicker(exploreEntries),
        ),
      _buildQuickActionButton(
        label: '详情URL',
        onTap: _runCurrentKey,
      ),
      _buildQuickActionButton(
        label: '++目录',
        onTap: () => _prefixKeyAndMaybeRun('++'),
      ),
      _buildQuickActionButton(
        label: '--正文',
        onTap: () => _prefixKeyAndMaybeRun('--'),
      ),
    ];

    return AppListSection(
      header: const Text('快捷'),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '搜索关键字：我的 / 系统；发现：标题::url；目录：++url；正文：--url',
                style: TextStyle(
                  fontSize: 12,
                  color: CupertinoColors.secondaryLabel.resolveFrom(context),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: actions,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActionButton({
    required String label,
    required VoidCallback onTap,
  }) {
    return _buildCupertinoGhostButton(
      onPressed: onTap,
      child: Text(
        label,
        style: const TextStyle(fontSize: 13),
      ),
    );
  }

  String _currentDebugIntentHint() {
    final parsed = _debugOrchestrator.parseKey(_debugKeyCtrl.text.trim());
    final intent = parsed.intent;
    if (intent != null) {
      return intent.label;
    }
    final last = _debugIntentType;
    if (last == null) return '无效';
    return '上次:${_intentTypeLabel(last)}';
  }

  String _intentTypeLabel(SourceDebugIntentType type) {
    switch (type) {
      case SourceDebugIntentType.search:
        return '搜索';
      case SourceDebugIntentType.bookInfo:
        return '详情';
      case SourceDebugIntentType.explore:
        return '发现';
      case SourceDebugIntentType.toc:
        return '目录';
      case SourceDebugIntentType.content:
        return '正文';
    }
  }

  String _defaultDebugSearchKey() {
    final searchKey = _searchCheckKeyWordCtrl.text.trim();
    return searchKey.isEmpty ? '我的' : searchKey;
  }

  void _startDebugFromInputSubmit() {
    if (_debugLoading) return;
    _startLegadoStyleDebug();
  }

  void _setDebugKeyAndMaybeRun(String key, {required bool run}) {
    setState(() => _debugKeyCtrl.text = key);
    if (run && !_debugLoading) {
      _startLegadoStyleDebug();
    }
  }

  Future<void> _showExploreQuickPicker(
    List<MapEntry<String, String>> entries,
  ) async {
    final selected = await showAppActionListSheet<int>(
      context: context,
      title: '选择发现入口',
      showCancel: true,
      items: [
        for (var i = 0; i < entries.length; i++)
          AppActionListItem<int>(
            value: i,
            icon: CupertinoIcons.compass,
            label: entries[i].value,
          ),
      ],
    );
    if (selected == null || selected < 0 || selected >= entries.length) return;
    _setDebugKeyAndMaybeRun(entries[selected].key, run: true);
  }

  List<MapEntry<String, String>> _collectExploreQuickEntries() {
    final parsed = _parseExploreQuickEntries(
      exploreUrl: _exploreUrlCtrl.text,
      exploreScreen: _exploreScreenCtrl.text,
    );
    if (_cachedExploreQuickEntries.isEmpty) {
      return parsed;
    }
    return _mergeExploreQuickEntries([
      ..._cachedExploreQuickEntries,
      ...parsed,
    ]);
  }

  List<MapEntry<String, String>> _parseExploreQuickEntries({
    required String exploreUrl,
    required String exploreScreen,
  }) {
    final result = <MapEntry<String, String>>[];
    final seen = <String>{};

    void addEntry(String title, String url) {
      final normalizedUrl = url.trim();
      if (normalizedUrl.isEmpty) return;
      final normalizedTitle = title.trim().isEmpty ? '发现' : title.trim();
      final key = '$normalizedTitle::$normalizedUrl';
      if (!seen.add(key)) return;
      final displayUrl = normalizedUrl.length <= 22
          ? normalizedUrl
          : '${normalizedUrl.substring(0, 22)}...';
      result.add(MapEntry(key, '$normalizedTitle::$displayUrl'));
    }

    bool isHttp(String value) {
      return value.startsWith('http://') || value.startsWith('https://');
    }

    void parseDynamic(dynamic node) {
      if (node is List) {
        for (final item in node) {
          parseDynamic(item);
        }
        return;
      }
      if (node is! Map) return;
      final map = node.map((key, value) => MapEntry('$key', value));
      final title = (map['title'] ?? map['name'] ?? '').toString().trim();
      final url =
          (map['url'] ?? map['value'] ?? map['link'] ?? '').toString().trim();
      if (isHttp(url)) {
        addEntry(title, url);
      }
    }

    final trimmedExploreUrl = exploreUrl.trim();
    if (trimmedExploreUrl.isNotEmpty) {
      final parts = trimmedExploreUrl.split(RegExp(r'(?:&&|\r?\n)+'));
      for (final rawPart in parts) {
        final part = rawPart.trim();
        if (part.isEmpty) continue;
        final idx = part.indexOf('::');
        if (idx >= 0) {
          final title = part.substring(0, idx).trim();
          final url = part.substring(idx + 2).trim();
          if (isHttp(url)) {
            addEntry(title, url);
          }
          continue;
        }
        if (isHttp(part)) {
          addEntry('发现', part);
        }
      }
      if (result.isEmpty &&
          (trimmedExploreUrl.startsWith('[') ||
              trimmedExploreUrl.startsWith('{'))) {
        try {
          parseDynamic(json.decode(trimmedExploreUrl));
        } catch (_) {
          // ignore parse failure
        }
      }
    }

    final raw = exploreScreen.trim();
    if (raw.isNotEmpty) {
      try {
        parseDynamic(json.decode(raw));
      } catch (_) {
        final regex = RegExp(r'([^:\n]+)::(https?://\S+)');
        for (final match in regex.allMatches(raw)) {
          final title = (match.group(1) ?? '').trim();
          final url = (match.group(2) ?? '').trim();
          if (url.isEmpty) continue;
          addEntry(title, url);
        }
      }
    }

    return result;
  }

  List<MapEntry<String, String>> _entriesFromExploreKinds(
    List<SourceExploreKind> kinds,
  ) {
    final out = <MapEntry<String, String>>[];
    for (final kind in kinds) {
      final url = (kind.url ?? '').trim();
      if (!(url.startsWith('http://') || url.startsWith('https://'))) {
        continue;
      }
      final title = kind.title.trim().isEmpty ? '发现' : kind.title.trim();
      final key = '$title::$url';
      final displayUrl = url.length <= 22 ? url : '${url.substring(0, 22)}...';
      out.add(MapEntry(key, '$title::$displayUrl'));
    }
    return out;
  }

  List<MapEntry<String, String>> _mergeExploreQuickEntries(
    List<MapEntry<String, String>> entries,
  ) {
    final seen = <String>{};
    final merged = <MapEntry<String, String>>[];
    for (final entry in entries) {
      final key = entry.key.trim();
      if (key.isEmpty || !seen.add(key)) continue;
      merged.add(entry);
    }
    return merged;
  }

  Future<void> _scanDebugKeyFromQr() async {
    final text = await QrScanService.scanText(
      context,
      title: '扫码填充调试 Key',
    );
    final value = text?.trim();
    if (value == null || value.isEmpty || !mounted) return;
    setState(() => _debugKeyCtrl.text = value);
  }

  void _runQuickSearchRuleTest() {
    if (!_ensureQuickTestIdle()) return;
    final key = SourceQuickTestHelper.buildSearchKey(
      checkKeyword: _searchCheckKeyWordCtrl.text,
    );
    _switchToDebugTabAndRun(key);
  }

  void _runQuickContentRuleTest() {
    if (!_ensureQuickTestIdle()) return;
    final key = SourceQuickTestHelper.buildContentKey(
      previewChapterUrl: _previewChapterUrl,
    );
    if (key == null) {
      _showMessage('请先调试搜索/目录拿到 chapterUrl，再测试正文规则');
      return;
    }
    _switchToDebugTabAndRun(key);
  }

  bool _ensureQuickTestIdle() {
    if (!_debugLoading) return true;
    _showMessage('调试运行中，请稍后再试');
    return false;
  }

  void _switchToDebugTabAndRun(String key) {
    setState(() => _tab = 3);
    _setDebugKeyAndMaybeRun(key, run: true);
  }

  void _prefixKeyAndMaybeRun(String prefix) {
    final text = _debugKeyCtrl.text.trim();
    if (text.isEmpty || text.length <= 2) {
      setState(() => _debugKeyCtrl.text = prefix);
      _debugKeyFocusNode.requestFocus();
      return;
    }
    final next = text.startsWith(prefix) ? text : '$prefix$text';
    setState(() => _debugKeyCtrl.text = next);
    if (!_debugLoading) {
      _startLegadoStyleDebug();
    }
  }

  void _runCurrentKey() {
    final key = _debugKeyCtrl.text.trim();
    if (key.isEmpty) {
      _showMessage('请先输入调试 key');
      return;
    }
    if (!_debugLoading) {
      _startLegadoStyleDebug();
    }
  }

  void _openDebugSourceFromMenu(String title, String? content) {
    final text = content?.trim();
    if (text == null || text.isEmpty) {
      _showMessage('$title 暂无内容，请先执行调试');
      return;
    }
    _openDebugText(title: title, text: text);
  }

  Future<void> _refreshExploreQuickActions() async {
    if (_refreshingExploreQuickActions) return;

    final map = _buildPatchedJsonForDebug();
    if (map == null) {
      _showMessage('JSON 格式错误');
      return;
    }
    final source = BookSource.fromJson(map);
    if (source.bookSourceUrl.trim().isEmpty) {
      _showMessage('bookSourceUrl 不能为空');
      return;
    }

    setState(() => _refreshingExploreQuickActions = true);
    try {
      await _exploreKindsService.clearExploreKindsCache(source);
      final exploreKinds = await _exploreKindsService.exploreKinds(
        source,
        forceRefresh: true,
      );
      final refreshed = <MapEntry<String, String>>[
        ..._entriesFromExploreKinds(exploreKinds),
        ..._parseExploreQuickEntries(
          exploreUrl: '',
          exploreScreen: source.exploreScreen ?? '',
        ),
      ];
      final debug = await _engine.exploreDebug(source);
      final requestUrl =
          (debug.fetch.finalUrl ?? debug.fetch.requestUrl).trim();
      if (requestUrl.isNotEmpty &&
          (requestUrl.startsWith('http://') ||
              requestUrl.startsWith('https://'))) {
        final key = '发现::$requestUrl';
        final display = requestUrl.length <= 22
            ? requestUrl
            : '${requestUrl.substring(0, 22)}...';
        refreshed.insert(0, MapEntry(key, '发现::$display'));
      }

      final merged = _mergeExploreQuickEntries(refreshed);
      setState(() => _cachedExploreQuickEntries = merged);

      if (merged.isEmpty) {
        _showMessage('当前未解析到发现快捷项，请检查 exploreUrl/exploreScreen');
        return;
      }
      if (debug.fetch.body == null || debug.error != null) {
        final reason = (debug.error ?? debug.fetch.error ?? '请求失败').trim();
        unawaited(showAppToast(context, message: '已刷新发现快捷项（${merged.length} 项），请求返回异常：$reason'));
        return;
      }
      unawaited(showAppToast(context, message: '已刷新发现快捷项（${merged.length} 项）'));
    } catch (e) {
      final fallback = _parseExploreQuickEntries(
        exploreUrl: _exploreUrlCtrl.text,
        exploreScreen: _exploreScreenCtrl.text,
      );
      setState(() => _cachedExploreQuickEntries = fallback);
      _showMessage('刷新失败：$e');
    } finally {
      if (mounted) {
        setState(() => _refreshingExploreQuickActions = false);
      }
    }
  }

  Future<void> _showDebugHelp() async {
    await _openDebugText(
      title: '调试帮助',
      text: _debugHelpText(),
    );
  }

  String _debugHelpText() {
    return SourceHelpTexts.debug;
  }

  Widget _buildDebugSourcesSection() {
    String? nonEmpty(String? s) =>
        (s != null && s.trim().isNotEmpty) ? s : null;
    final listHtml = nonEmpty(_debugListSrcHtml);
    final bookHtml = nonEmpty(_debugBookSrcHtml);
    final tocHtml = nonEmpty(_debugTocSrcHtml);
    final contentHtml = nonEmpty(_debugContentSrcHtml);
    final contentResult = nonEmpty(_debugContentResult);
    final hasDebugLines = _debugLinesAll.isNotEmpty;
    final structuredSummaryText = hasDebugLines
        ? _prettyJson(LegadoJson.encode(_buildStructuredDebugSummary()))
        : null;

    return AppListSection(
      header: const Text('源码 & 结果'),
      children: [
        CupertinoListTile.notched(
          title: const Text('结构化调试摘要（脱敏）'),
          subtitle: const Text('请求/解析/错误摘要，便于快速定位失败阶段'),
          additionalInfo: Text(hasDebugLines ? '可查看' : '—'),
          trailing: const CupertinoListTileChevron(),
          onTap: structuredSummaryText == null
              ? null
              : () => _openDebugText(
                    title: '结构化调试摘要',
                    text: structuredSummaryText,
                  ),
        ),
        CupertinoListTile.notched(
          title: const Text('复制调试摘要（脱敏）'),
          subtitle: const Text('用于 issue/群反馈，避免贴整段日志'),
          additionalInfo: Text(hasDebugLines ? '可复制' : '—'),
          trailing: const CupertinoListTileChevron(),
          onTap: structuredSummaryText == null
              ? null
              : () {
                  Clipboard.setData(ClipboardData(text: structuredSummaryText));
                  if (mounted) unawaited(showAppToast(context, message: '已复制调试摘要（脱敏）'));
                },
        ),
        CupertinoListTile.notched(
          title: const Text('列表页源码'),
          additionalInfo:
              Text(listHtml == null ? '—' : '${listHtml.length} 字符'),
          trailing: const CupertinoListTileChevron(),
          onTap: listHtml == null
              ? null
              : () => _openDebugText(title: '列表页源码', text: listHtml),
        ),
        CupertinoListTile.notched(
          title: const Text('详情页源码'),
          additionalInfo:
              Text(bookHtml == null ? '—' : '${bookHtml.length} 字符'),
          trailing: const CupertinoListTileChevron(),
          onTap: bookHtml == null
              ? null
              : () => _openDebugText(title: '详情页源码', text: bookHtml),
        ),
        CupertinoListTile.notched(
          title: const Text('目录页源码'),
          additionalInfo: Text(tocHtml == null ? '—' : '${tocHtml.length} 字符'),
          trailing: const CupertinoListTileChevron(),
          onTap: tocHtml == null
              ? null
              : () => _openDebugText(title: '目录页源码', text: tocHtml),
        ),
        CupertinoListTile.notched(
          title: const Text('正文页源码'),
          additionalInfo:
              Text(contentHtml == null ? '—' : '${contentHtml.length} 字符'),
          trailing: const CupertinoListTileChevron(),
          onTap: contentHtml == null
              ? null
              : () => _openDebugText(title: '正文页源码', text: contentHtml),
        ),
        CupertinoListTile.notched(
          title: const Text('正文结果（清理后）'),
          additionalInfo: Text(
            contentResult == null ? '—' : '${contentResult.length} 字符',
          ),
          trailing: const CupertinoListTileChevron(),
          onTap: contentResult == null
              ? null
              : () => _openDebugText(title: '正文结果', text: contentResult),
        ),
        CupertinoListTile.notched(
          title: const Text('运行时变量快照（脱敏）'),
          subtitle: const Text('含 @put/@get 运行期变量，用于调试链路排查'),
          additionalInfo: Text('${_debugRuntimeVarsSnapshot.length} 项'),
          trailing: const CupertinoListTileChevron(),
          onTap: _debugRuntimeVarsSnapshot.isEmpty
              ? null
              : () => _openDebugText(
                    title: '运行时变量快照（脱敏）',
                    text: _prettyJson(
                      LegadoJson.encode(_debugRuntimeVarsSnapshot),
                    ),
                  ),
        ),
        CupertinoListTile.notched(
          title: const Text('复制变量快照（脱敏）'),
          additionalInfo: Text('${_debugRuntimeVarsSnapshot.length} 项'),
          trailing: const CupertinoListTileChevron(),
          onTap: _debugRuntimeVarsSnapshot.isEmpty
              ? null
              : () {
                  Clipboard.setData(
                    ClipboardData(
                      text: _prettyJson(
                        LegadoJson.encode(_debugRuntimeVarsSnapshot),
                      ),
                    ),
                  );
                  if (mounted) unawaited(showAppToast(context, message: '已复制变量快照（脱敏）'));
                },
        ),
      ],
    );
  }

  Widget _buildDebugConsoleSection() {
    final hasLines = _debugLines.isNotEmpty;
    final totalLines = _debugLinesAll.length;
    final visibleLines = _debugLines;

    String buildContextText(_DebugLine picked, {int radius = 28}) {
      final idx = _debugLinesAll.indexOf(picked);
      if (idx < 0) return picked.text;
      final start = (idx - radius) < 0 ? 0 : (idx - radius);
      final end = (idx + radius + 1) > _debugLinesAll.length
          ? _debugLinesAll.length
          : (idx + radius + 1);
      final slice = _debugLinesAll.sublist(start, end);
      final buf = StringBuffer();
      for (var i = 0; i < slice.length; i++) {
        final lineNo = start + i + 1;
        buf.writeln('${lineNo.toString().padLeft(4)}│ ${slice[i].text}');
      }
      return buf.toString().trimRight();
    }

    final children = <Widget>[
      CupertinoListTile.notched(
        title: Text('总 $totalLines 行 · 展示 ${visibleLines.length} 行'),
        subtitle: Text(
          _debugAutoFollowLogs ? '自动跟随开启' : '自动跟随暂停（可在顶部点击“回到最新日志”恢复）',
        ),
      ),
      if (_debugError != null && _debugError!.trim().isNotEmpty)
        CupertinoListTile.notched(
          title: Text(
            '最近错误',
            style: TextStyle(
              color: CupertinoColors.systemRed.resolveFrom(context),
            ),
          ),
          subtitle: Text(
            _debugError!,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              color: CupertinoColors.systemRed.resolveFrom(context),
            ),
          ),
          trailing: CupertinoButton(
            padding: EdgeInsets.zero,
            minimumSize: const Size(30, 30),
            onPressed: _copyMinimalReproInfo,
            child: const Icon(CupertinoIcons.doc_on_doc, size: 16),
          ),
          onTap: () => _openDebugText(
            title: '最近错误',
            text: _debugError!.trim(),
          ),
        ),
      if (totalLines > visibleLines.length)
        CupertinoListTile.notched(
          title: Text('当前展示最近 ${visibleLines.length} 行'),
          subtitle: const Text('完整日志可用“复制控制台（全部）”或“导出调试包”获取'),
        ),
    ];

    if (!hasLines) {
      children.add(
        const CupertinoListTile.notched(
          title: Text('暂无日志'),
        ),
      );
      return AppListSection(
        header: const Text('控制台'),
        children: children,
      );
    }

    for (final line in visibleLines) {
      if (line.text.trim().isEmpty) continue;
      final color = line.state == -1
          ? CupertinoColors.systemRed.resolveFrom(context)
          : line.state == 1000
              ? CupertinoColors.systemGreen.resolveFrom(context)
              : CupertinoColors.label.resolveFrom(context);
      children.add(
        CupertinoListTile.notched(
          title: Text(
            line.text,
            style: TextStyle(
              fontFamily: AppTypography.fontFamilyMonospace,
              fontSize: 12.5,
              color: color,
            ),
          ),
          trailing: CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: () {
              Clipboard.setData(ClipboardData(text: line.text));
              if (mounted) unawaited(showAppToast(context, message: '已复制该行日志'));
            },
            child: const Icon(
              CupertinoIcons.doc_on_doc,
              size: 18,
            ),
          ),
          onTap: () => _openDebugText(
            title: '日志上下文',
            text: buildContextText(line),
          ),
        ),
      );
    }

    return AppListSection(
      header: Text('控制台（共 $totalLines 行）'),
      children: children,
    );
  }

  String _stripDebugTimePrefix(String text) {
    final t = text.trimLeft();
    if (!t.startsWith('[')) return t;
    final idx = t.indexOf('] ');
    if (idx < 0) return t;
    return t.substring(idx + 2);
  }

  void _updateRequestDecisionSummary(String message) {
    final plain = _stripDebugTimePrefix(message).trimLeft();
    String valueOf(String prefix) {
      return plain.substring(prefix.length).trim();
    }

    if (plain.startsWith('└请求决策：')) {
      _debugMethodDecision = valueOf('└请求决策：');
      return;
    }
    if (plain.startsWith('└重试决策：')) {
      _debugRetryDecision = valueOf('└重试决策：');
      return;
    }
    if (plain.startsWith('└请求编码：')) {
      _debugRequestCharsetDecision = valueOf('└请求编码：');
      return;
    }
    if (plain.startsWith('└请求体决策：')) {
      _debugBodyDecision = valueOf('└请求体决策：');
      return;
    }
    if (plain.startsWith('└响应编码：')) {
      _debugResponseCharset = valueOf('└响应编码：');
      return;
    }
    if (plain.startsWith('└响应解码决策：')) {
      _debugResponseCharsetDecision = valueOf('└响应解码决策：');
    }
  }

  void _updateRuleFieldPreviewFromLine(String message) {
    final plain = _stripDebugTimePrefix(message).trimLeft();
    if (plain.startsWith('┌获取章节名')) {
      _awaitingChapterNameValue = true;
      return;
    }
    if (plain.startsWith('┌获取章节链接')) {
      _awaitingChapterUrlValue = true;
      return;
    }
    if (plain.startsWith('┌')) {
      _awaitingChapterNameValue = false;
      _awaitingChapterUrlValue = false;
      return;
    }
    if (!plain.startsWith('└')) return;

    final value = plain.substring(1).trim();
    if (_awaitingChapterNameValue) {
      if (value.isNotEmpty) {
        _previewChapterName = value;
      }
      _awaitingChapterNameValue = false;
    }
    if (_awaitingChapterUrlValue) {
      if (value.isNotEmpty) {
        _previewChapterUrl = value;
      }
      _awaitingChapterUrlValue = false;
    }
  }

  List<String> _buildDebugDecisionSummaryLines() {
    final lines = <String>[];
    if (_debugMethodDecision != null && _debugMethodDecision!.isNotEmpty) {
      lines.add('method: $_debugMethodDecision');
    }
    if (_debugRetryDecision != null && _debugRetryDecision!.isNotEmpty) {
      lines.add('retry: $_debugRetryDecision');
    }
    if (_debugRequestCharsetDecision != null &&
        _debugRequestCharsetDecision!.isNotEmpty) {
      lines.add('requestCharset: $_debugRequestCharsetDecision');
    }
    if (_debugBodyDecision != null && _debugBodyDecision!.isNotEmpty) {
      lines.add('body: $_debugBodyDecision');
    }
    if (_debugResponseCharset != null && _debugResponseCharset!.isNotEmpty) {
      lines.add('responseCharset: $_debugResponseCharset');
    }
    if (_debugResponseCharsetDecision != null &&
        _debugResponseCharsetDecision!.isNotEmpty) {
      lines.add('responseDecode: $_debugResponseCharsetDecision');
    }
    return lines;
  }

  void _clearDebugConsole() {
    setState(() {
      _debugLines.clear();
      _debugLinesAll.clear();
      _debugAutoFollowLogs = true;
      _debugAutoScrollQueued = false;
      _debugError = null;
      _debugListSrcHtml = null;
      _debugBookSrcHtml = null;
      _debugTocSrcHtml = null;
      _debugContentSrcHtml = null;
      _debugContentResult = null;
      _debugMethodDecision = null;
      _debugRetryDecision = null;
      _debugRequestCharsetDecision = null;
      _debugBodyDecision = null;
      _debugResponseCharset = null;
      _debugResponseCharsetDecision = null;
      _debugRuntimeVarsSnapshot = <String, String>{};
      _previewChapterName = null;
      _previewChapterUrl = null;
      _awaitingChapterNameValue = false;
      _awaitingChapterUrlValue = false;
    });
    _queueDebugAutoScroll(force: true);
  }

  void _copyDebugConsole() {
    if (_debugLinesAll.isEmpty) {
      _showMessage('暂无日志可复制');
      return;
    }
    final text = _debugLinesAll.map((e) => e.text).join('\n');
    Clipboard.setData(ClipboardData(text: text));
    if (mounted) unawaited(showAppToast(context, message: '已复制全部日志'));
  }

  void _copyMinimalReproInfo() {
    final text = _buildMinimalReproText();
    Clipboard.setData(ClipboardData(text: text));
    if (mounted) unawaited(showAppToast(context, message: '已复制最小复现信息'));
  }

  String _buildMinimalReproText() {
    final now = DateTime.now().toIso8601String();
    final patched = _buildPatchedJsonForDebug();
    final source = patched == null ? null : BookSource.fromJson(patched);
    final debugKey = _debugKeyCtrl.text.trim();

    final lines = <String>[
      '最小复现信息',
      '生成时间：$now',
      'Debug Key：${debugKey.isEmpty ? '-' : debugKey}',
      if (source != null) '书源名称：${source.bookSourceName}',
      if (source != null) '书源地址：${source.bookSourceUrl}',
      if (source != null)
        '搜索地址：${(source.searchUrl ?? '').trim().isEmpty ? '-' : source.searchUrl}',
      if (source != null)
        '发现地址：${(source.exploreUrl ?? '').trim().isEmpty ? '-' : source.exploreUrl}',
      if (_debugError != null && _debugError!.trim().isNotEmpty)
        '最近错误：${_debugError!.trim()}',
    ];

    final decisions = _buildDebugDecisionSummaryLines();
    if (decisions.isNotEmpty) {
      lines
        ..add('')
        ..add('请求决策摘要：')
        ..addAll(decisions.map((e) => '- $e'));
    }

    final tailLogs = _debugLinesAll
        .map((e) => e.text)
        .where((e) => e.trim().isNotEmpty)
        .toList(growable: false);
    final start = tailLogs.length > 80 ? tailLogs.length - 80 : 0;
    final slice = tailLogs.sublist(start);
    if (slice.isNotEmpty) {
      lines
        ..add('')
        ..add('关键日志（最近 ${slice.length} 行）：')
        ..addAll(slice);
    }

    return lines.join('\n');
  }

  Map<String, dynamic> _buildStructuredDebugSummary() {
    final logs = _debugLinesAll.map((e) => e.text).toList(growable: false);
    final stageErrors = _debugLinesAll
        .where((e) => e.state == -1)
        .map((e) => e.text)
        .toList(growable: false);
    return SourceDebugSummaryParser.build(
      logLines: logs,
      debugError: _debugError,
      errorLines: stageErrors,
    );
  }

  List<String> _debugDiagnosisLabels(Map<String, dynamic> summary) {
    final diagnosis = summary['diagnosis'];
    if (diagnosis is! Map) return const <String>[];
    final labelsRaw = diagnosis['labels'];
    if (labelsRaw is! List) return const <String>[];
    return labelsRaw
        .map((e) => e.toString().trim())
        .where((e) => e.isNotEmpty)
        .toList(growable: false);
  }

  List<String> _debugDiagnosisHints(Map<String, dynamic> summary) {
    final diagnosis = summary['diagnosis'];
    if (diagnosis is! Map) return const <String>[];
    final hintsRaw = diagnosis['hints'];
    if (hintsRaw is! List) return const <String>[];
    return hintsRaw
        .map((e) => e.toString().trim())
        .where((e) => e.isNotEmpty)
        .toList(growable: false);
  }

  String _labelText(String code) {
    switch (code) {
      case 'request_failure':
        return '请求失败';
      case 'parse_failure':
        return '解析失败';
      case 'paging_interrupted':
        return '分页中断';
      case 'ok':
        return '基本正常';
      case 'no_data':
        return '无数据';
      default:
        return code;
    }
  }

  Color _labelColor(String code) {
    switch (code) {
      case 'request_failure':
      case 'parse_failure':
      case 'paging_interrupted':
        return CupertinoColors.systemRed.resolveFrom(context);
      case 'ok':
        return CupertinoColors.systemGreen.resolveFrom(context);
      default:
        return CupertinoColors.secondaryLabel.resolveFrom(context);
    }
  }

  Widget _buildDiagnosisSection() {
    final hasLogs = _debugLinesAll.isNotEmpty;
    final summary = _buildStructuredDebugSummary();
    final labels = _debugDiagnosisLabels(summary);
    final hints = _debugDiagnosisHints(summary);

    return AppListSection(
      header: const Text('诊断标签'),
      children: [
        CupertinoListTile.notched(
          title: const Text('失败分类'),
          subtitle: hasLogs
              ? Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final label in labels)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _labelColor(label).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(AppDesignTokens.radiusControl),
                          border: Border.all(
                            color: _labelColor(label).withValues(alpha: 0.35),
                          ),
                        ),
                        child: Text(
                          _labelText(label),
                          style: TextStyle(
                            fontSize: 12,
                            color: _labelColor(label),
                          ),
                        ),
                      ),
                  ],
                )
              : const Text('暂无调试数据，请先执行“开始调试”'),
          trailing: const CupertinoListTileChevron(),
          onTap: hasLogs
              ? () => _openDebugText(
                    title: '诊断标签（结构化）',
                    text: _prettyJson(LegadoJson.encode(summary['diagnosis'])),
                  )
              : null,
        ),
        CupertinoListTile.notched(
          title: const Text('定位建议'),
          subtitle: hasLogs
              ? Text(
                  hints.isEmpty ? '—' : hints.join('\n'),
                  style: TextStyle(
                    fontSize: 13,
                    color: CupertinoColors.secondaryLabel.resolveFrom(context),
                  ),
                )
              : const Text('—'),
          trailing: const CupertinoListTileChevron(),
          onTap: hasLogs
              ? () => _openDebugText(
                    title: '定位建议',
                    text: hints.isEmpty ? '—' : hints.join('\n'),
                  )
              : null,
        ),
      ],
    );
  }

  Map<String, dynamic> _buildDebugBundle({required bool includeRawSources}) {
    final now = DateTime.now().toIso8601String();
    final consoleText = _debugLinesAll.map((e) => e.text).join('\n');
    final lines = _debugLinesAll
        .map((e) => <String, dynamic>{'state': e.state, 'text': e.text})
        .toList(growable: false);
    final structuredSummary = _buildStructuredDebugSummary();

    final bundle = <String, dynamic>{
      'type': 'soupreader_debug_bundle',
      'version': 1,
      'createdAt': now,
      'debugKey': _debugKeyCtrl.text.trim(),
      'error': _debugError,
      'sourceJson': _jsonCtrl.text,
      'consoleText': consoleText,
      'consoleLines': lines,
      'requestDecisionSummary': <String, dynamic>{
        'method': _debugMethodDecision,
        'retry': _debugRetryDecision,
        'requestCharset': _debugRequestCharsetDecision,
        'body': _debugBodyDecision,
        'responseCharset': _debugResponseCharset,
        'responseDecode': _debugResponseCharsetDecision,
      },
      'structuredSummary': structuredSummary,
      'runtimeVariables': _debugRuntimeVarsSnapshot,
    };

    if (includeRawSources) {
      bundle['rawSources'] = <String, dynamic>{
        'listHtml': _debugListSrcHtml,
        'bookHtml': _debugBookSrcHtml,
        'tocHtml': _debugTocSrcHtml,
        'contentHtml': _debugContentSrcHtml,
        'contentResult': _debugContentResult,
      };
    }

    return bundle;
  }

  Future<void> _showExportDebugBundleSheet() async {
    final selected =
        await showAppActionListSheet<_SourceEditExportBundleAction>(
      context: context,
      title: '导出调试包',
      message: '调试包可能很大，建议优先保存到文件。',
      showCancel: true,
      items: const [
        AppActionListItem<_SourceEditExportBundleAction>(
          value: _SourceEditExportBundleAction.copyBundleWithoutRawSources,
          icon: CupertinoIcons.doc_on_doc,
          label: '复制调试包（不含源码，推荐）',
        ),
        AppActionListItem<_SourceEditExportBundleAction>(
          value: _SourceEditExportBundleAction.saveBundleWithoutRawSources,
          icon: CupertinoIcons.square_arrow_up,
          label: '保存调试包到文件（不含源码，推荐）',
        ),
        AppActionListItem<_SourceEditExportBundleAction>(
          value: _SourceEditExportBundleAction.saveBundleWithRawSources,
          icon: CupertinoIcons.archivebox,
          label: '保存调试包到文件（含源码）',
        ),
      ],
    );
    if (selected == null || !mounted) return;
    switch (selected) {
      case _SourceEditExportBundleAction.copyBundleWithoutRawSources:
        final bundle = _buildDebugBundle(includeRawSources: false);
        final json = _prettyJson(LegadoJson.encode(bundle));
        Clipboard.setData(ClipboardData(text: json));
        if (mounted) unawaited(showAppToast(context, message: '已复制调试包（不含源码）'));
        return;
      case _SourceEditExportBundleAction.saveBundleWithoutRawSources:
        await _exportDebugBundleToFile(includeRawSources: false);
        return;
      case _SourceEditExportBundleAction.saveBundleWithRawSources:
        await _exportDebugBundleToFile(includeRawSources: true);
        return;
    }
  }

  Future<void> _exportDebugBundleToFile({
    required bool includeRawSources,
  }) async {
    final bundle = _buildDebugBundle(includeRawSources: includeRawSources);
    final summary = _buildStructuredDebugSummary();
    final ts = DateTime.now().millisecondsSinceEpoch;
    final fileName = includeRawSources
        ? 'soupreader_debug_bundle_full_$ts.zip'
        : 'soupreader_debug_bundle_$ts.zip';

    final bundleJson = _prettyJson(LegadoJson.encode(bundle));
    final files = <String, String>{
      'bundle.json': bundleJson,
      'console.txt': _debugLinesAll.map((e) => e.text).join('\n'),
      'summary.json': _prettyJson(LegadoJson.encode(summary)),
      // 兼容排查：单独导出书源 JSON（原样）
      'source.json': _prettyJson(_jsonCtrl.text),
    };

    if (includeRawSources) {
      void putIfNonEmpty(String path, String? content) {
        final t = content?.trim();
        if (t == null || t.isEmpty) return;
        files[path] = content!;
      }

      putIfNonEmpty('raw/list.html', _debugListSrcHtml);
      putIfNonEmpty('raw/book.html', _debugBookSrcHtml);
      putIfNonEmpty('raw/toc.html', _debugTocSrcHtml);
      putIfNonEmpty('raw/content.html', _debugContentSrcHtml);
      putIfNonEmpty('raw/content_result.txt', _debugContentResult);
    }

    final ok = await _debugExportService.exportZipToFile(
      files: files,
      fileName: fileName,
    );
    if (!mounted) return;
    _showMessage(ok ? '已导出：$fileName' : '导出取消或失败');
  }

  Map<String, dynamic>? _buildPatchedJsonForDebug() {
    final base = _tryDecodeJsonMap(_jsonCtrl.text);
    if (base == null) return null;

    Map<String, dynamic> ensureMap(dynamic raw) {
      if (raw is Map<String, dynamic>) return Map<String, dynamic>.from(raw);
      if (raw is Map) {
        return raw.map((key, value) => MapEntry('$key', value));
      }
      return <String, dynamic>{};
    }

    final map = ensureMap(base);

    String? nonEmpty(TextEditingController ctrl, {bool trimValue = true}) {
      final raw = ctrl.text;
      if (raw.trim().isEmpty) return null;
      return trimValue ? raw.trim() : raw;
    }

    void setIfNonEmpty(
      String key,
      TextEditingController ctrl, {
      bool trimValue = true,
    }) {
      final v = nonEmpty(ctrl, trimValue: trimValue);
      if (v != null) map[key] = v;
    }

    void setIntIfParsable(String key, TextEditingController ctrl) {
      final t = ctrl.text.trim();
      if (t.isEmpty) return;
      final v = int.tryParse(t);
      if (v != null) map[key] = v;
    }

    // 基础字段：仅在表单非空时覆盖，避免“调试前同步”把 JSON 里的字段删空。
    setIfNonEmpty('bookSourceName', _nameCtrl);
    setIfNonEmpty('bookSourceUrl', _urlCtrl);
    setIfNonEmpty('bookSourceGroup', _groupCtrl);
    setIntIfParsable('bookSourceType', _typeCtrl);
    setIntIfParsable('customOrder', _customOrderCtrl);
    setIntIfParsable('weight', _weightCtrl);
    setIntIfParsable('respondTime', _respondTimeCtrl);
    map['enabled'] = _enabled;
    map['enabledExplore'] = _enabledExplore;
    map['enabledCookieJar'] = _enabledCookieJar;
    setIfNonEmpty('concurrentRate', _concurrentRateCtrl);
    setIfNonEmpty('bookUrlPattern', _bookUrlPatternCtrl);
    setIfNonEmpty('jsLib', _jsLibCtrl, trimValue: false);
    setIfNonEmpty('header', _headerCtrl, trimValue: false);
    setIfNonEmpty('loginUrl', _loginUrlCtrl);
    setIfNonEmpty('loginUi', _loginUiCtrl, trimValue: false);
    setIfNonEmpty('loginCheckJs', _loginCheckJsCtrl, trimValue: false);
    setIfNonEmpty('coverDecodeJs', _coverDecodeJsCtrl, trimValue: false);
    setIfNonEmpty('bookSourceComment', _bookSourceCommentCtrl,
        trimValue: false);
    setIfNonEmpty('variableComment', _variableCommentCtrl, trimValue: false);
    setIfNonEmpty('searchUrl', _searchUrlCtrl);
    setIfNonEmpty('exploreUrl', _exploreUrlCtrl);
    setIfNonEmpty('exploreScreen', _exploreScreenCtrl);

    Map<String, dynamic> patchRule(
      String key,
      Map<String, TextEditingController> updates, {
      Set<String> noTrimKeys = const {},
    }) {
      final rule = ensureMap(map[key]);
      for (final entry in updates.entries) {
        final fieldKey = entry.key;
        final ctrl = entry.value;
        final v = nonEmpty(ctrl, trimValue: !noTrimKeys.contains(fieldKey));
        if (v != null) rule[fieldKey] = v;
      }
      return rule;
    }

    map['ruleSearch'] = patchRule('ruleSearch', {
      'checkKeyWord': _searchCheckKeyWordCtrl,
      'bookList': _searchBookListCtrl,
      'name': _searchNameCtrl,
      'author': _searchAuthorCtrl,
      'bookUrl': _searchBookUrlCtrl,
      'coverUrl': _searchCoverUrlCtrl,
      'intro': _searchIntroCtrl,
      'kind': _searchKindCtrl,
      'lastChapter': _searchLastChapterCtrl,
      'updateTime': _searchUpdateTimeCtrl,
      'wordCount': _searchWordCountCtrl,
    });

    map['ruleExplore'] = patchRule('ruleExplore', {
      'bookList': _exploreBookListCtrl,
      'name': _exploreNameCtrl,
      'author': _exploreAuthorCtrl,
      'bookUrl': _exploreBookUrlCtrl,
      'coverUrl': _exploreCoverUrlCtrl,
      'intro': _exploreIntroCtrl,
      'kind': _exploreKindCtrl,
      'lastChapter': _exploreLastChapterCtrl,
      'updateTime': _exploreUpdateTimeCtrl,
      'wordCount': _exploreWordCountCtrl,
    });

    map['ruleBookInfo'] = patchRule(
      'ruleBookInfo',
      {
        'init': _infoInitCtrl,
        'name': _infoNameCtrl,
        'author': _infoAuthorCtrl,
        'coverUrl': _infoCoverUrlCtrl,
        'tocUrl': _infoTocUrlCtrl,
        'kind': _infoKindCtrl,
        'lastChapter': _infoLastChapterCtrl,
        'updateTime': _infoUpdateTimeCtrl,
        'wordCount': _infoWordCountCtrl,
        'intro': _infoIntroCtrl,
      },
      noTrimKeys: {'intro'},
    );

    map['ruleToc'] = patchRule(
      'ruleToc',
      {
        'chapterList': _tocChapterListCtrl,
        'chapterName': _tocChapterNameCtrl,
        'chapterUrl': _tocChapterUrlCtrl,
        'nextTocUrl': _tocNextTocUrlCtrl,
        'preUpdateJs': _tocPreUpdateJsCtrl,
        'formatJs': _tocFormatJsCtrl,
      },
      noTrimKeys: {'preUpdateJs', 'formatJs'},
    );

    map['ruleContent'] = patchRule(
      'ruleContent',
      {
        'title': _contentTitleCtrl,
        'content': _contentContentCtrl,
        'nextContentUrl': _contentNextContentUrlCtrl,
        'replaceRegex': _contentReplaceRegexCtrl,
      },
      noTrimKeys: {'content', 'replaceRegex', 'nextContentUrl'},
    );

    return map;
  }

  Future<void> _startLegadoStyleDebug() async {
    _debugKeyFocusNode.unfocus();

    final map = _buildPatchedJsonForDebug();
    if (map == null) {
      setState(() => _debugError = 'JSON 格式错误');
      return;
    }
    final source = BookSource.fromJson(map);
    if (source.bookSourceUrl.trim().isEmpty) {
      setState(() => _debugError = 'bookSourceUrl 不能为空（否则无法构建请求地址）');
      return;
    }
    var key = _debugKeyCtrl.text.trim();
    if (key.isEmpty) {
      key = _defaultDebugSearchKey();
      _debugKeyCtrl.text = key;
    }
    final parsed = _debugOrchestrator.parseKey(key);
    final intent = parsed.intent;
    if (intent == null) {
      setState(() => _debugError = parsed.error ?? '请输入有效 key');
      return;
    }

    setState(() {
      _debugLoading = true;
      _debugError = null;
      _debugLines.clear();
      _debugLinesAll.clear();
      _debugAutoFollowLogs = true;
      _debugAutoScrollQueued = false;
      _debugListSrcHtml = null;
      _debugBookSrcHtml = null;
      _debugTocSrcHtml = null;
      _debugContentSrcHtml = null;
      _debugContentResult = null;
      _debugMethodDecision = null;
      _debugRetryDecision = null;
      _debugRequestCharsetDecision = null;
      _debugBodyDecision = null;
      _debugResponseCharset = null;
      _debugResponseCharsetDecision = null;
      _debugRuntimeVarsSnapshot = <String, String>{};
      _debugIntentType = intent.type;
      _previewChapterName = null;
      _previewChapterUrl = null;
      _awaitingChapterNameValue = false;
      _awaitingChapterUrlValue = false;
    });
    _queueDebugAutoScroll(force: true);

    SourceDebugRunResult? runResult;
    try {
      runResult = await _debugOrchestrator.run(
        source: source,
        key: key,
        onEvent: _onDebugEvent,
      );
      if (!mounted) return;
      setState(() {
        _debugRuntimeVarsSnapshot = _engine.debugRuntimeVariablesSnapshot();
        if (_debugError == null &&
            runResult?.error?.trim().isNotEmpty == true) {
          _debugError = runResult!.error!.trim();
        }
      });
      _publishDebugSummary(
        source: source,
        intent: runResult.intent,
        runResult: runResult,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _debugError = '调试失败：$e');
      _publishDebugSummary(
        source: source,
        intent: intent,
        runResult: runResult,
      );
    } finally {
      if (mounted) {
        setState(() => _debugLoading = false);
      }
    }
  }

  void _onDebugEvent(SourceDebugEvent event) {
    if (!mounted) return;
    if (event.isRaw) {
      setState(() {
        switch (event.state) {
          case 10:
            _debugListSrcHtml = event.message;
            break;
          case 20:
            _debugBookSrcHtml = event.message;
            break;
          case 30:
            _debugTocSrcHtml = event.message;
            break;
          case 40:
            _debugContentSrcHtml = event.message;
            break;
          case 41:
            _debugContentResult = event.message;
            break;
        }
      });
      return;
    }

    setState(() {
      final line = _DebugLine(state: event.state, text: event.message);
      _updateRequestDecisionSummary(event.message);
      _updateRuleFieldPreviewFromLine(event.message);
      _debugLinesAll.add(line);
      _debugLines.add(line);
      // UI 列表模式保持轻量：仅保留最近一部分；“全文控制台/导出调试包”使用全量日志。
      const maxUiLines = 600;
      if (_debugLines.length > maxUiLines) {
        _debugLines.removeRange(0, _debugLines.length - maxUiLines);
      }

      if (event.state == -1) {
        _debugError = event.message;
      }
    });
    _queueDebugAutoScroll();
  }

  void _publishDebugSummary({
    required BookSource source,
    required SourceDebugIntent intent,
    required SourceDebugRunResult? runResult,
  }) {
    final logLines = _debugLinesAll.map((line) => line.text).toList();
    final errorLines = _debugLinesAll
        .where((line) => line.state == -1)
        .map((line) => line.text)
        .toList();
    final summary = SourceDebugSummaryParser.build(
      logLines: logLines,
      debugError: _debugError,
      errorLines: errorLines,
    );
    final diagnosisRaw = summary['diagnosis'];
    final diagnosis = diagnosisRaw is Map
        ? diagnosisRaw.map((k, v) => MapEntry('$k', v))
        : const <String, dynamic>{};
    final primary = (diagnosis['primary'] ?? 'no_data').toString();
    final labels = (diagnosis['labels'] is List)
        ? (diagnosis['labels'] as List)
            .map((e) => e.toString())
            .where((e) => e.trim().isNotEmpty)
            .toList(growable: false)
        : const <String>[];
    final hints = (diagnosis['hints'] is List)
        ? (diagnosis['hints'] as List)
            .map((e) => e.toString())
            .where((e) => e.trim().isNotEmpty)
            .toList(growable: false)
        : const <String>[];

    final success = runResult?.success ??
        (_debugError == null &&
            !labels.contains('request_failure') &&
            !labels.contains('parse_failure'));

    SourceDebugSummaryStore.instance.push(
      SourceDebugSummary(
        finishedAt: DateTime.now(),
        sourceUrl: source.bookSourceUrl,
        sourceName: source.bookSourceName,
        key: intent.runKey,
        intentType: intent.type,
        success: success,
        debugError: _debugError,
        primaryDiagnosis: primary,
        diagnosisLabels: labels,
        diagnosisHints: hints,
      ),
    );
  }

  Future<void> _openDebugText({
    required String title,
    required String text,
  }) async {
    await Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (_) => SourceDebugTextView(title: title, text: text),
      ),
    );
  }

  CupertinoListTile _buildTextFieldTile(
    String title,
    TextEditingController controller, {
    String? placeholder,
    int maxLines = 1,
  }) {
    return CupertinoListTile.notched(
      title: Text(title),
      subtitle: CupertinoTextField(
        controller: controller,
        placeholder: placeholder,
        maxLines: maxLines,
      ),
    );
  }

}
