import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../../../app/widgets/app_action_list_sheet.dart';
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

part 'http_tts_rule_edit_actions_clipboard.dart';
part 'http_tts_rule_edit_actions_login.dart';

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

  bool _logining = false;
  bool _saving = false;

  bool get _menuBusy => _logining || _saving;

  void _setSaving(bool value) {
    if (!mounted) return;
    setState(() {
      _saving = value;
    });
  }

  void _setLogining(bool value) {
    if (!mounted) return;
    setState(() {
      _logining = value;
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
            child: _logining
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
}
