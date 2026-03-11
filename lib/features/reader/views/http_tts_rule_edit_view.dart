import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../../../app/widgets/app_action_list_sheet.dart';
import '../../../app/widgets/app_toast.dart';
import '../../../app/widgets/app_cupertino_page_scaffold.dart';
import '../../../app/widgets/app_nav_bar_button.dart';
import '../../../app/widgets/cupertino_bottom_dialog.dart';
import '../../../core/services/exception_log_service.dart';
import '../../../core/services/source_login_store.dart';
import '../../../core/utils/legado_json.dart';
import '../../source/models/book_source.dart';
import '../../source/services/source_login_script_service.dart';
import '../../source/services/source_login_ui_helper.dart';
import '../../source/services/source_login_url_resolver.dart';
import '../../source/views/source_login_form_view.dart';
import '../../source/views/source_login_webview_view.dart';
import '../models/http_tts_rule.dart';
import '../services/http_tts_rule_store.dart';
import 'http_tts_rule_edit_form.dart';


enum _HttpTtsRuleEditMenuAction {
  login,
  showLoginHeader,
  deleteLoginHeader,
  copySource,
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

  bool _loggingIn = false;
  bool _saving = false;

  bool get _menuBusy => _loggingIn || _saving;

  void _setSaving(bool value) {
    if (!mounted) return;
    setState(() {
      _saving = value;
    });
  }

  void _setLoggingIn(bool value) {
    if (!mounted) return;
    setState(() {
      _loggingIn = value;
    });
  }

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

  @override
  Widget build(BuildContext context) {
    return AppCupertinoPageScaffold(
      title: '编辑朗读引擎',
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppNavBarButton(
            onPressed: _menuBusy ? null : _saveRule,
            child: _saving
                ? const CupertinoActivityIndicator(radius: 9)
                : const Text('保存'),
            minimumSize: const Size(30, 30),
          ),
          AppNavBarButton(
            onPressed: _menuBusy ? null : _showMoreMenu,
            child: _loggingIn
                ? const CupertinoActivityIndicator(radius: 9)
                : const Icon(CupertinoIcons.ellipsis),
            minimumSize: const Size(30, 30),
          ),
        ],
      ),
      child: HttpTtsRuleEditForm(
        nameController: _nameCtrl,
        urlController: _urlCtrl,
        contentTypeController: _contentTypeCtrl,
        concurrentRateController: _concurrentRateCtrl,
        loginUrlController: _loginUrlCtrl,
        loginUiController: _loginUiCtrl,
        loginCheckJsController: _loginCheckJsCtrl,
        headersController: _headersCtrl,
      ),
    );
  }


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
      unawaited(showAppToast(context, message: message));
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

      _setLoggingIn(true);
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
        _setLoggingIn(false);
      }
    }
}
