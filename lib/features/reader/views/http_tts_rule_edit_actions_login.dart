part of 'http_tts_rule_edit_view.dart';

extension _HttpTtsRuleEditLoginActions on _HttpTtsRuleEditViewState {
  HttpTtsRule _buildRuleFromForm() {
    String? optional(TextEditingController controller) {
      final text = controller.text.trim();
      if (text.isEmpty) return null;
      return text;
    }

    return widget.initialRule.copyWith(
      name: _nameCtrl.text.trim(),
      url: _urlCtrl.text.trim(),
      contentType: optional(_contentTypeCtrl),
      concurrentRate: optional(_concurrentRateCtrl),
      loginUrl: optional(_loginUrlCtrl),
      loginUi: optional(_loginUiCtrl),
      loginCheckJs: optional(_loginCheckJsCtrl),
      header: optional(_headersCtrl),
      lastUpdateTime: DateTime.now().millisecondsSinceEpoch,
    );
  }

  BookSource _buildHttpTtsLoginSource(HttpTtsRule rule) {
    final sourceName = rule.name.trim().isEmpty ? 'HTTP朗读引擎' : rule.name.trim();
    return BookSource(
      bookSourceUrl: 'httpTts:${rule.id}',
      bookSourceName: sourceName,
      jsLib: rule.jsLib,
      enabledCookieJar: rule.enabledCookieJar ?? false,
      concurrentRate: rule.concurrentRate,
      header: rule.header,
      loginUrl: rule.loginUrl,
      loginUi: rule.loginUi,
      loginCheckJs: rule.loginCheckJs,
      lastUpdateTime: rule.lastUpdateTime,
    );
  }

  Future<void> _showMessage(String message) async {
    if (!mounted) return;
    await showCupertinoBottomDialog<void>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: const Text('提示'),
        content: Text('\n$message'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('好'),
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

  Future<void> _saveRule() async {
    if (_menuBusy) return;
    _setSaving(true);
    try {
      final draftRule = _buildRuleFromForm();
      await _ruleStore.upsertRule(draftRule);
      widget.onRuleSaved?.call(draftRule);
      _showToastMessage('保存成功');
    } catch (error) {
      await _showMessage('保存失败：$error');
    } finally {
      _setSaving(false);
    }
  }

  Future<void> _showLoginHeader() async {
    final draftRule = _buildRuleFromForm();
    final sourceKey = 'httpTts:${draftRule.id}';
    final headerText = await SourceLoginStore.getLoginHeaderText(sourceKey);
    if (!mounted) return;
    await showCupertinoBottomDialog<void>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: const Text('登录头'),
        content: headerText == null ? null : Text('\n$headerText'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('好'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteLoginHeader() async {
    final draftRule = _buildRuleFromForm();
    final sourceKey = 'httpTts:${draftRule.id}';
    await SourceLoginStore.removeLoginHeader(sourceKey);
  }

  Future<void> _login() async {
    if (_menuBusy) return;

    final draftRule = _buildRuleFromForm();
    if ((draftRule.loginUrl ?? '').trim().isEmpty) {
      await _showMessage('登录url不能为空');
      return;
    }

    _setLogining(true);
    try {
      await _ruleStore.upsertRule(draftRule);
      widget.onRuleSaved?.call(draftRule);

      if (!mounted) return;
      final loginSource = _buildHttpTtsLoginSource(draftRule);
      if (SourceLoginUiHelper.hasLoginUi(draftRule.loginUi)) {
        await Navigator.of(context).push(
          CupertinoPageRoute<void>(
            builder: (_) => SourceLoginFormView(source: loginSource),
          ),
        );
        return;
      }

      final resolvedUrl = SourceLoginUrlResolver.resolve(
        baseUrl: loginSource.bookSourceUrl,
        loginUrl:
            SourceLoginScriptService.resolveLoginScript(draftRule.loginUrl),
      ).trim();
      final uri = Uri.tryParse(resolvedUrl);
      final scheme = uri?.scheme.toLowerCase();
      if (resolvedUrl.isEmpty || (scheme != 'http' && scheme != 'https')) {
        await _showMessage('登录地址不是有效网页地址');
        return;
      }

      await Navigator.of(context).push(
        CupertinoPageRoute<void>(
          builder: (_) => SourceLoginWebViewView(
            source: loginSource,
            initialUrl: resolvedUrl,
          ),
        ),
      );
    } catch (error) {
      await _showMessage('登录失败：$error');
    } finally {
      _setLogining(false);
    }
  }
}
