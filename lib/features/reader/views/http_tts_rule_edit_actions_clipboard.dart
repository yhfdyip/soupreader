part of 'http_tts_rule_edit_view.dart';

extension _HttpTtsRuleEditClipboardActions on _HttpTtsRuleEditViewState {
  Future<void> _showMoreMenu() async {
    if (_menuBusy) return;
    final selected = await showAppActionListSheet<_HttpTtsRuleEditMenuAction>(
      context: context,
      title: '朗读引擎',
      showCancel: true,
      items: const [
        AppActionListItem<_HttpTtsRuleEditMenuAction>(
          value: _HttpTtsRuleEditMenuAction.login,
          icon: CupertinoIcons.person_crop_circle_badge_checkmark,
          label: '登录',
        ),
        AppActionListItem<_HttpTtsRuleEditMenuAction>(
          value: _HttpTtsRuleEditMenuAction.showLoginHeader,
          icon: CupertinoIcons.doc_text,
          label: '查看登录头',
        ),
        AppActionListItem<_HttpTtsRuleEditMenuAction>(
          value: _HttpTtsRuleEditMenuAction.deleteLoginHeader,
          icon: CupertinoIcons.delete,
          label: '删除登录头',
          isDestructiveAction: true,
        ),
        AppActionListItem<_HttpTtsRuleEditMenuAction>(
          value: _HttpTtsRuleEditMenuAction.copySource,
          icon: CupertinoIcons.doc_on_doc,
          label: '拷贝源',
        ),
        AppActionListItem<_HttpTtsRuleEditMenuAction>(
          value: _HttpTtsRuleEditMenuAction.pasteSource,
          icon: CupertinoIcons.doc_on_clipboard,
          label: '粘贴源',
        ),
      ],
    );
    if (selected == null) return;
    switch (selected) {
      case _HttpTtsRuleEditMenuAction.login:
        await _login();
        return;
      case _HttpTtsRuleEditMenuAction.showLoginHeader:
        await _showLoginHeader();
        return;
      case _HttpTtsRuleEditMenuAction.deleteLoginHeader:
        await _deleteLoginHeader();
        return;
      case _HttpTtsRuleEditMenuAction.copySource:
        await _copySourceToClipboard();
        return;
      case _HttpTtsRuleEditMenuAction.pasteSource:
        await _pasteSourceFromClipboard();
        return;
    }
  }

  Future<void> _copySourceToClipboard() async {
    final draftRule = _buildRuleFromForm();
    final payload = LegadoJson.encode(draftRule.toJson());
    try {
      await Clipboard.setData(ClipboardData(text: payload));
    } catch (error, stackTrace) {
      ExceptionLogService().record(
        node: 'reader.menu.speak_engine_edit.copy_source.failed',
        message: '拷贝朗读源失败',
        error: error,
        stackTrace: stackTrace,
        context: <String, dynamic>{
          'ruleId': draftRule.id,
          'ruleName': draftRule.name,
          'payloadLength': payload.length,
        },
      );
      return;
    }
    if (!mounted) return;
    _showToastMessage('已拷贝');
  }

  Future<void> _pasteSourceFromClipboard() async {
    final clip = await Clipboard.getData(Clipboard.kTextPlain);
    final rawText = clip?.text?.trim() ?? '';
    if (rawText.isEmpty) {
      await _showMessage('剪贴板为空');
      return;
    }
    if (!rawText.startsWith('{') && !rawText.startsWith('[')) {
      await _showMessage('格式不对');
      return;
    }
    try {
      final rules = HttpTtsRule.listFromJsonText(rawText);
      if (rules.isEmpty) {
        await _showMessage('格式不对');
        return;
      }
      _applyRuleToForm(rules.first);
    } catch (error) {
      await _showMessage(_resolvePasteSourceError(error));
    }
  }

  void _applyRuleToForm(HttpTtsRule rule) {
    _nameCtrl.text = rule.name;
    _urlCtrl.text = rule.url;
    _contentTypeCtrl.text = rule.contentType ?? '';
    _concurrentRateCtrl.text = rule.concurrentRate ?? '';
    _loginUrlCtrl.text = rule.loginUrl ?? '';
    _loginUiCtrl.text = rule.loginUi ?? '';
    _loginCheckJsCtrl.text = rule.loginCheckJs ?? '';
    _headersCtrl.text = rule.header ?? '';
  }

  String _resolvePasteSourceError(Object error) {
    if (error is FormatException) {
      final message = error.message.toString().trim();
      if (message.isEmpty || message == 'JSON 格式不支持') {
        return '格式不对';
      }
      return message;
    }
    final raw = '$error'.trim();
    if (raw.isEmpty) return '格式不对';
    return raw.replaceFirst(RegExp(r'^(Exception|Error):\s*'), '');
  }
}
