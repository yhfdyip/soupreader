part of 'speak_engine_manage_view.dart';

extension _SpeakEngineManageMenuActions on _SpeakEngineManageViewState {
  Future<void> _reloadRules() async {
    _setLoading(true);
    final rules = await _ruleStore.loadRules();
    final sorted = rules.toList()
      ..sort((a, b) {
        final byName = a.name.compareTo(b.name);
        if (byName != 0) return byName;
        return a.id.compareTo(b.id);
      });
    _setRulesLoaded(sorted);
  }

  HttpTtsRule _buildNewRuleDraft() {
    final usedIds = _rules.map((rule) => rule.id).toSet();
    var id = DateTime.now().millisecondsSinceEpoch;
    while (usedIds.contains(id)) {
      id++;
    }
    return HttpTtsRule(
      id: id,
      name: '',
      url: '',
      contentType: null,
      concurrentRate: '0',
      loginUrl: null,
      loginUi: null,
      header: null,
      jsLib: null,
      enabledCookieJar: false,
      loginCheckJs: null,
      lastUpdateTime: DateTime.now().millisecondsSinceEpoch,
    );
  }

  Future<void> _openRuleEditor(HttpTtsRule rule) async {
    await Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (_) => HttpTtsRuleEditView(
          initialRule: rule,
          onRuleSaved: (_) {
            _reloadRules();
          },
        ),
      ),
    );
  }

  Future<void> _addRule() async {
    if (_menuBusy) return;
    await _openRuleEditor(_buildNewRuleDraft());
  }

  Future<void> _importDefaultRules() async {
    if (_importingDefault) return;
    _setImportingDefault(true);
    try {
      await _ruleStore.importDefaultRules();
      await _reloadRules();
    } catch (error) {
      if (!mounted) return;
      await showCupertinoBottomDialog<void>(
        context: context,
        builder: (dialogContext) => CupertinoAlertDialog(
          title: const Text('导入默认规则'),
          content: Text('导入失败：$error'),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('关闭'),
            ),
          ],
        ),
      );
    } finally {
      _setImportingDefault(false);
    }
  }

  Future<void> _showMoreMenu() async {
    if (_menuBusy) return;
    final selected = await showAppActionListSheet<_SpeakEngineMenuAction>(
      context: context,
      title: '朗读引擎',
      showCancel: true,
      items: const [
        AppActionListItem<_SpeakEngineMenuAction>(
          value: _SpeakEngineMenuAction.importDefaultRules,
          icon: CupertinoIcons.arrow_down_doc,
          label: '导入默认规则',
        ),
        AppActionListItem<_SpeakEngineMenuAction>(
          value: _SpeakEngineMenuAction.importLocal,
          icon: CupertinoIcons.folder,
          label: '本地导入',
        ),
        AppActionListItem<_SpeakEngineMenuAction>(
          value: _SpeakEngineMenuAction.importOnline,
          icon: CupertinoIcons.cloud_download,
          label: '网络导入',
        ),
        AppActionListItem<_SpeakEngineMenuAction>(
          value: _SpeakEngineMenuAction.export,
          icon: CupertinoIcons.square_arrow_up,
          label: '导出',
        ),
      ],
    );
    if (selected == null) return;
    switch (selected) {
      case _SpeakEngineMenuAction.importDefaultRules:
        await _importDefaultRules();
        return;
      case _SpeakEngineMenuAction.importLocal:
        await _importLocalRules();
        return;
      case _SpeakEngineMenuAction.importOnline:
        await _importOnlineRules();
        return;
      case _SpeakEngineMenuAction.export:
        await _exportRules();
        return;
    }
  }

  Future<void> _exportRules() async {
    if (_exporting) return;
    _setExporting(true);
    try {
      final jsonText = HttpTtsRule.listToJsonText(_rules);
      final outputPath = await saveFileWithTextCompat(
        dialogTitle: '导出',
        fileName: 'httpTts.json',
        allowedExtensions: const ['json'],
        text: jsonText,
      );
      if (outputPath == null || outputPath.trim().isEmpty) {
        return;
      }
      final normalizedPath = outputPath.trim();
      if (!mounted) return;
      await _showExportPathDialog(normalizedPath);
    } catch (error) {
      if (!mounted) return;
      await _showMessageDialog(
        title: '导出',
        message: '导出失败：$error',
      );
    } finally {
      _setExporting(false);
    }
  }

  Future<void> _runImportingTask(Future<void> Function() task) async {
    final navigator = Navigator.of(context, rootNavigator: true);
    showCupertinoBottomDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => const CupertinoAlertDialog(
        content: _BlockingProgressContent(text: '导入中...'),
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

  Future<void> _showExportPathDialog(String outputPath) async {
    final path = outputPath.trim();
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
    if (!mounted) return;
    await showCupertinoBottomDialog<void>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: const Text('导出成功'),
        content: Text('\n${lines.join('\n')}'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('关闭'),
          ),
          CupertinoDialogAction(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: path));
              if (!dialogContext.mounted) return;
              Navigator.pop(dialogContext);
              _showToastMessage('已复制导出路径');
            },
            child: const Text('复制路径'),
          ),
        ],
      ),
    );
  }

  void _showToastMessage(String message) {
    if (!mounted) return;
    showCupertinoBottomSheetDialog<void>(
      context: context,
      barrierColor: CupertinoColors.black.withValues(alpha: 0.08),
      builder: (toastContext) {
        final navigator = Navigator.of(toastContext);
        Future<void>.delayed(const Duration(milliseconds: 1100), () {
          if (navigator.mounted && navigator.canPop()) {
            navigator.pop();
          }
        });
        return SafeArea(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              margin: const EdgeInsets.only(bottom: 28),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: CupertinoColors.systemBackground
                    .resolveFrom(context)
                    .withValues(alpha: 0.96),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: CupertinoColors.separator.resolveFrom(context),
                ),
              ),
              child: Text(
                message,
                style: TextStyle(
                  color: CupertinoColors.label.resolveFrom(context),
                  fontSize: 13,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
