import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../../../app/widgets/app_cupertino_page_scaffold.dart';
import '../../../app/widgets/cupertino_bottom_dialog.dart';
import '../models/txt_toc_rule.dart';

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
    final selected = await showCupertinoBottomDialog<_TxtTocRuleEditMenuAction>(
      context: context,
      barrierDismissible: true,
      builder: (sheetContext) => CupertinoActionSheet(
        title: const Text('TXT 目录规则'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () =>
                Navigator.pop(sheetContext, _TxtTocRuleEditMenuAction.copyRule),
            child: const Text('复制规则'),
          ),
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(
              sheetContext,
              _TxtTocRuleEditMenuAction.pasteRule,
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
                controller: _ruleController,
                prefix: const Text('正则'),
                placeholder: '请输入正则',
              ),
              CupertinoTextFormFieldRow(
                controller: _exampleController,
                prefix: const Text('示例'),
                placeholder: '请输入示例',
              ),
            ],
          ),
        ],
      ),
    );
  }
}
