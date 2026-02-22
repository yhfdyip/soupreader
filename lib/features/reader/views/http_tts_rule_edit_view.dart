import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../../../app/widgets/app_cupertino_page_scaffold.dart';
import '../../../core/services/source_login_store.dart';
import '../../source/models/book_source.dart';
import '../../source/services/source_login_script_service.dart';
import '../../source/services/source_login_ui_helper.dart';
import '../../source/services/source_login_url_resolver.dart';
import '../../source/views/source_login_form_view.dart';
import '../../source/views/source_web_verify_view.dart';
import '../models/http_tts_rule.dart';
import '../services/http_tts_rule_store.dart';

enum _HttpTtsRuleEditMenuAction {
  login,
  showLoginHeader,
  deleteLoginHeader,
  pasteSource,
}

class HttpTtsRuleEditView extends StatefulWidget {
  const HttpTtsRuleEditView({
    super.key,
    required this.initialRule,
    this.ruleStore,
    this.onRuleSaved,
  });

  final HttpTtsRule initialRule;
  final HttpTtsRuleStore? ruleStore;
  final ValueChanged<HttpTtsRule>? onRuleSaved;

  @override
  State<HttpTtsRuleEditView> createState() => _HttpTtsRuleEditViewState();
}

class _HttpTtsRuleEditViewState extends State<HttpTtsRuleEditView> {
  late final HttpTtsRuleStore _ruleStore =
      widget.ruleStore ?? HttpTtsRuleStore();

  late final TextEditingController _nameCtrl;
  late final TextEditingController _urlCtrl;
  late final TextEditingController _contentTypeCtrl;
  late final TextEditingController _concurrentRateCtrl;
  late final TextEditingController _loginUrlCtrl;
  late final TextEditingController _loginUiCtrl;
  late final TextEditingController _loginCheckJsCtrl;
  late final TextEditingController _headersCtrl;

  bool _logining = false;
  bool _saving = false;

  bool get _menuBusy => _logining || _saving;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.initialRule.name);
    _urlCtrl = TextEditingController(text: widget.initialRule.url);
    _contentTypeCtrl =
        TextEditingController(text: widget.initialRule.contentType ?? '');
    _concurrentRateCtrl =
        TextEditingController(text: widget.initialRule.concurrentRate ?? '');
    _loginUrlCtrl =
        TextEditingController(text: widget.initialRule.loginUrl ?? '');
    _loginUiCtrl =
        TextEditingController(text: widget.initialRule.loginUi ?? '');
    _loginCheckJsCtrl =
        TextEditingController(text: widget.initialRule.loginCheckJs ?? '');
    _headersCtrl = TextEditingController(text: widget.initialRule.header ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _urlCtrl.dispose();
    _contentTypeCtrl.dispose();
    _concurrentRateCtrl.dispose();
    _loginUrlCtrl.dispose();
    _loginUiCtrl.dispose();
    _loginCheckJsCtrl.dispose();
    _headersCtrl.dispose();
    super.dispose();
  }

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
    await showCupertinoDialog<void>(
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
    showCupertinoModalPopup<void>(
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

  Future<void> _showMoreMenu() async {
    if (_menuBusy) return;
    final selected = await showCupertinoModalPopup<_HttpTtsRuleEditMenuAction>(
      context: context,
      builder: (sheetContext) => CupertinoActionSheet(
        title: const Text('朗读引擎'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () =>
                Navigator.pop(sheetContext, _HttpTtsRuleEditMenuAction.login),
            child: const Text('登录'),
          ),
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(
              sheetContext,
              _HttpTtsRuleEditMenuAction.showLoginHeader,
            ),
            child: const Text('查看登录头'),
          ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(
              sheetContext,
              _HttpTtsRuleEditMenuAction.deleteLoginHeader,
            ),
            child: const Text('删除登录头'),
          ),
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(
              sheetContext,
              _HttpTtsRuleEditMenuAction.pasteSource,
            ),
            child: const Text('粘贴源'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(sheetContext),
          child: const Text('取消'),
        ),
      ),
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
      case _HttpTtsRuleEditMenuAction.pasteSource:
        await _pasteSourceFromClipboard();
        return;
    }
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

  Future<void> _saveRule() async {
    if (_menuBusy) return;
    setState(() => _saving = true);
    try {
      final draftRule = _buildRuleFromForm();
      await _ruleStore.upsertRule(draftRule);
      widget.onRuleSaved?.call(draftRule);
      _showToastMessage('保存成功');
    } catch (error) {
      await _showMessage('保存失败：$error');
    } finally {
      if (!mounted) return;
      setState(() => _saving = false);
    }
  }

  Future<void> _showLoginHeader() async {
    final draftRule = _buildRuleFromForm();
    final sourceKey = 'httpTts:${draftRule.id}';
    final headerText = await SourceLoginStore.getLoginHeaderText(sourceKey);
    if (!mounted) return;
    await showCupertinoDialog<void>(
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

    if (mounted) {
      setState(() => _logining = true);
    }
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
          builder: (_) => SourceWebVerifyView(initialUrl: resolvedUrl),
        ),
      );
    } catch (error) {
      await _showMessage('登录失败：$error');
    } finally {
      if (!mounted) return;
      setState(() => _logining = false);
    }
  }

  Widget _buildField({
    required String label,
    required TextEditingController controller,
    String? placeholder,
    int maxLines = 1,
    int minLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 2, bottom: 6),
            child: Text(
              label,
              style: TextStyle(
                color: CupertinoColors.secondaryLabel.resolveFrom(context),
                fontSize: 12,
              ),
            ),
          ),
          CupertinoTextField(
            controller: controller,
            placeholder: placeholder,
            minLines: minLines,
            maxLines: maxLines,
            clearButtonMode: OverlayVisibilityMode.editing,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppCupertinoPageScaffold(
      title: '编辑朗读引擎',
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CupertinoButton(
            padding: EdgeInsets.zero,
            minSize: 30,
            onPressed: _menuBusy ? null : _saveRule,
            child: _saving
                ? const CupertinoActivityIndicator(radius: 9)
                : const Text('保存'),
          ),
          CupertinoButton(
            padding: EdgeInsets.zero,
            minSize: 30,
            onPressed: _menuBusy ? null : _showMoreMenu,
            child: _logining
                ? const CupertinoActivityIndicator(radius: 9)
                : const Icon(CupertinoIcons.ellipsis),
          ),
        ],
      ),
      child: ListView(
        padding: const EdgeInsets.only(top: 8, bottom: 20),
        children: [
          CupertinoListSection.insetGrouped(
            header: const Text('基础'),
            children: [
              _buildField(
                label: '名称',
                controller: _nameCtrl,
                placeholder: 'name',
              ),
              _buildField(
                label: 'URL',
                controller: _urlCtrl,
                placeholder: 'url',
              ),
              _buildField(
                label: 'ContentType',
                controller: _contentTypeCtrl,
                placeholder: 'contentType',
              ),
              _buildField(
                label: '并发率',
                controller: _concurrentRateCtrl,
                placeholder: 'concurrentRate',
              ),
            ],
          ),
          CupertinoListSection.insetGrouped(
            header: const Text('登录'),
            footer: const Text('更多菜单中的“登录”会先保存当前输入，再进入登录流程。'),
            children: [
              _buildField(
                label: '登录 URL',
                controller: _loginUrlCtrl,
                placeholder: 'loginUrl',
              ),
              _buildField(
                label: '登录 UI',
                controller: _loginUiCtrl,
                placeholder: 'loginUi',
                minLines: 3,
                maxLines: 6,
              ),
              _buildField(
                label: '登录校验 JS',
                controller: _loginCheckJsCtrl,
                placeholder: 'loginCheckJs',
                minLines: 2,
                maxLines: 5,
              ),
              _buildField(
                label: '请求头',
                controller: _headersCtrl,
                placeholder: 'header(JSON)',
                minLines: 2,
                maxLines: 5,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
