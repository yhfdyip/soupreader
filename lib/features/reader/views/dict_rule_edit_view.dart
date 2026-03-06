import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../../../app/widgets/app_action_list_sheet.dart';
import '../../../app/widgets/app_cupertino_page_scaffold.dart';
import '../../../app/widgets/app_nav_bar_button.dart';
import '../../../app/widgets/app_ui_kit.dart';
import '../../../app/widgets/cupertino_bottom_dialog.dart';
import '../models/dict_rule.dart';
import 'rule_edit_form_card.dart';

enum _DictRuleEditMenuAction {
  copyRule,
  pasteRule,
}

class DictRuleEditView extends StatefulWidget {
  const DictRuleEditView({
    super.key,
    required this.initialRule,
  });

  final DictRule initialRule;

  @override
  State<DictRuleEditView> createState() => _DictRuleEditViewState();
}

class _DictRuleEditViewState extends State<DictRuleEditView> {
  late final TextEditingController _nameController;
  late final TextEditingController _urlRuleController;
  late final TextEditingController _showRuleController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialRule.name);
    _urlRuleController =
        TextEditingController(text: widget.initialRule.urlRule);
    _showRuleController =
        TextEditingController(text: widget.initialRule.showRule);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _urlRuleController.dispose();
    _showRuleController.dispose();
    super.dispose();
  }

  Future<void> _showMoreMenu() async {
    final selected = await showAppActionListSheet<_DictRuleEditMenuAction>(
      context: context,
      title: '字典规则',
      showCancel: true,
      items: const [
        AppActionListItem<_DictRuleEditMenuAction>(
          value: _DictRuleEditMenuAction.copyRule,
          icon: CupertinoIcons.doc_on_doc,
          label: '复制规则',
        ),
        AppActionListItem<_DictRuleEditMenuAction>(
          value: _DictRuleEditMenuAction.pasteRule,
          icon: CupertinoIcons.doc_on_clipboard,
          label: '粘贴规则',
        ),
      ],
    );
    if (selected == null) return;
    switch (selected) {
      case _DictRuleEditMenuAction.copyRule:
        await _copyRuleToClipboard();
        return;
      case _DictRuleEditMenuAction.pasteRule:
        await _pasteRuleFromClipboard();
        return;
    }
  }

  Future<void> _copyRuleToClipboard() async {
    final text = json.encode(_currentEditingRule().toJson());
    await Clipboard.setData(ClipboardData(text: text));
  }

  Future<void> _pasteRuleFromClipboard() async {
    final clipData = await Clipboard.getData(Clipboard.kTextPlain);
    final clipText = clipData?.text;
    if (clipText == null || clipText.trim().isEmpty) {
      await _showMessage('剪贴板没有内容');
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
      final pastedRule = DictRule.fromJson(source);
      _nameController.text = pastedRule.name;
      _urlRuleController.text = pastedRule.urlRule;
      _showRuleController.text = pastedRule.showRule;
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

  void _saveRule() {
    Navigator.of(context).pop(_currentEditingRule());
  }

  DictRule _currentEditingRule() {
    return widget.initialRule.copyWith(
      name: _nameController.text,
      urlRule: _urlRuleController.text,
      showRule: _showRuleController.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppCupertinoPageScaffold(
      title: '字典规则',
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
                label: 'URL规则',
                placeholder: '请输入URL规则',
                controller: _urlRuleController,
              ),
              RuleEditFieldSpec(
                label: '显示规则',
                placeholder: '请输入显示规则',
                controller: _showRuleController,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
