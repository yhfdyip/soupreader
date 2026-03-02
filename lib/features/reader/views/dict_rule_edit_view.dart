import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../../../app/widgets/app_cupertino_page_scaffold.dart';
import '../../../app/widgets/cupertino_bottom_dialog.dart';
import '../models/dict_rule.dart';

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
    final selected = await showCupertinoBottomDialog<_DictRuleEditMenuAction>(
      context: context,
      barrierDismissible: true,
      builder: (sheetContext) => CupertinoActionSheet(
        title: const Text('字典规则'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(
              sheetContext,
              _DictRuleEditMenuAction.copyRule,
            ),
            child: const Text('复制规则'),
          ),
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(
              sheetContext,
              _DictRuleEditMenuAction.pasteRule,
            ),
            child: const Text('粘贴规则'),
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
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: _saveRule,
            child: const Text('保存'),
            minimumSize: Size(30, 30),
          ),
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: _showMoreMenu,
            child: const Icon(CupertinoIcons.ellipsis),
            minimumSize: Size(30, 30),
          ),
        ],
      ),
      child: ListView(
        padding: const EdgeInsets.only(top: 8, bottom: 20),
        children: [
          CupertinoFormSection.insetGrouped(
            header: const Text('规则内容'),
            children: [
              CupertinoTextFormFieldRow(
                controller: _nameController,
                prefix: const Text('名称'),
                placeholder: '请输入名称',
              ),
              CupertinoTextFormFieldRow(
                controller: _urlRuleController,
                prefix: const Text('URL规则'),
                placeholder: '请输入URL规则',
              ),
              CupertinoTextFormFieldRow(
                controller: _showRuleController,
                prefix: const Text('显示规则'),
                placeholder: '请输入显示规则',
              ),
            ],
          ),
        ],
      ),
    );
  }
}
