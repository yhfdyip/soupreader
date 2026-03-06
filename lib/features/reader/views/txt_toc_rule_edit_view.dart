import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../../../app/widgets/app_action_list_sheet.dart';
import '../../../app/widgets/app_cupertino_page_scaffold.dart';
import '../../../app/widgets/app_nav_bar_button.dart';
import '../../../app/widgets/app_ui_kit.dart';
import '../../../app/widgets/cupertino_bottom_dialog.dart';
import '../models/txt_toc_rule.dart';
import 'rule_edit_form_card.dart';

enum _TxtTocRuleEditMenuAction {
  copyRule,
  pasteRule,
}

class TxtTocRuleEditView extends StatefulWidget {
  const TxtTocRuleEditView({
    super.key,
    required this.initialRule,
  });

  final TxtTocRule initialRule;

  @override
  State<TxtTocRuleEditView> createState() => _TxtTocRuleEditViewState();
}

class _TxtTocRuleEditViewState extends State<TxtTocRuleEditView> {
  late final TextEditingController _nameController;
  late final TextEditingController _ruleController;
  late final TextEditingController _exampleController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialRule.name);
    _ruleController = TextEditingController(text: widget.initialRule.rule);
    _exampleController = TextEditingController(
      text: widget.initialRule.example ?? '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ruleController.dispose();
    _exampleController.dispose();
    super.dispose();
  }

  Future<void> _showMoreMenu() async {
    final selected = await showAppActionListSheet<_TxtTocRuleEditMenuAction>(
      context: context,
      title: 'TXT 目录规则',
      showCancel: true,
      items: const [
        AppActionListItem<_TxtTocRuleEditMenuAction>(
          value: _TxtTocRuleEditMenuAction.copyRule,
          icon: CupertinoIcons.doc_on_doc,
          label: '复制规则',
        ),
        AppActionListItem<_TxtTocRuleEditMenuAction>(
          value: _TxtTocRuleEditMenuAction.pasteRule,
          icon: CupertinoIcons.doc_on_clipboard,
          label: '粘贴规则',
        ),
      ],
    );
    if (selected == null) return;
    switch (selected) {
      case _TxtTocRuleEditMenuAction.copyRule:
        await _copyRuleToClipboard();
        return;
      case _TxtTocRuleEditMenuAction.pasteRule:
        await _pasteRuleFromClipboard();
        return;
    }
  }

  Future<void> _copyRuleToClipboard() async {
    final jsonText = json.encode(_buildRuleFromInputs().toJson());
    await Clipboard.setData(ClipboardData(text: jsonText));
  }

  Future<void> _pasteRuleFromClipboard() async {
    final clipData = await Clipboard.getData(Clipboard.kTextPlain);
    final clipText = clipData?.text;
    if (clipText == null || clipText.trim().isEmpty) {
      await _showMessage('剪贴板为空');
      return;
    }
    try {
      final decoded = json.decode(clipText);
      if (decoded is! Map) {
        throw const FormatException('格式不对');
      }
      final source = decoded.map<String, dynamic>(
        (key, value) => MapEntry('$key', value),
      );
      final pastedRule = TxtTocRule.fromJson(source);
      _nameController.text = pastedRule.name;
      _ruleController.text = pastedRule.rule;
      _exampleController.text = pastedRule.example ?? '';
    } catch (_) {
      await _showMessage('格式不对');
    }
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

  Future<bool> _checkValid(TxtTocRule tocRule) async {
    if (tocRule.name.isEmpty) {
      await _showMessage('名称不能为空');
      return false;
    }
    try {
      RegExp(tocRule.rule, multiLine: true);
    } catch (error, stackTrace) {
      debugPrint('TxtTocRuleRegexError:$error');
      debugPrint('$stackTrace');
      await _showMessage('正则语法错误或不支持(txt)：$error');
      return false;
    }
    return true;
  }

  Future<void> _saveRule() async {
    final savedRule = _buildRuleFromInputs();
    if (!await _checkValid(savedRule)) {
      return;
    }
    if (!mounted) return;
    Navigator.of(context).pop(savedRule);
  }

  TxtTocRule _buildRuleFromInputs() {
    final exampleText = _exampleController.text;
    return widget.initialRule.copyWith(
      name: _nameController.text,
      rule: _ruleController.text,
      example: exampleText,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppCupertinoPageScaffold(
      title: 'TXT 目录规则',
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppNavBarButton(
            onPressed: _saveRule,
            child: const Text('保存'),
            minimumSize: const Size(30, 30),
          ),
          AppNavBarButton(
            onPressed: _showMoreMenu,
            child: const Icon(CupertinoIcons.ellipsis),
            minimumSize: const Size(30, 30),
          ),
        ],
      ),
      child: AppListView(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 20),
        children: [
          RuleEditFormCard(
            sectionTitle: '规则内容',
            fields: [
              RuleEditFieldSpec(
                label: '名称',
                placeholder: '请输入名称',
                controller: _nameController,
              ),
              RuleEditFieldSpec(
                label: '正则',
                placeholder: '请输入正则',
                controller: _ruleController,
              ),
              RuleEditFieldSpec(
                label: '示例',
                placeholder: '请输入示例',
                controller: _exampleController,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
