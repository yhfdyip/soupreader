import 'package:flutter/cupertino.dart';

import '../models/replace_rule.dart';
import '../services/replace_rule_engine.dart';

class ReplaceRuleEditView extends StatefulWidget {
  final ReplaceRule initial;
  final ValueChanged<ReplaceRule> onSave;

  const ReplaceRuleEditView({
    super.key,
    required this.initial,
    required this.onSave,
  });

  @override
  State<ReplaceRuleEditView> createState() => _ReplaceRuleEditViewState();
}

class _ReplaceRuleEditViewState extends State<ReplaceRuleEditView> {
  final ReplaceRuleEngine _engine = ReplaceRuleEngine();

  late ReplaceRule _rule;

  late final TextEditingController _nameCtrl;
  late final TextEditingController _groupCtrl;
  late final TextEditingController _patternCtrl;
  late final TextEditingController _replacementCtrl;
  late final TextEditingController _scopeCtrl;
  late final TextEditingController _excludeScopeCtrl;
  late final TextEditingController _timeoutCtrl;
  late final TextEditingController _orderCtrl;

  final TextEditingController _testInputCtrl = TextEditingController();
  String _testOutput = '';

  @override
  void initState() {
    super.initState();
    _rule = widget.initial;
    _nameCtrl = TextEditingController(text: _rule.name);
    _groupCtrl = TextEditingController(text: _rule.group ?? '');
    _patternCtrl = TextEditingController(text: _rule.pattern);
    _replacementCtrl = TextEditingController(text: _rule.replacement);
    _scopeCtrl = TextEditingController(text: _rule.scope ?? '');
    _excludeScopeCtrl = TextEditingController(text: _rule.excludeScope ?? '');
    _timeoutCtrl = TextEditingController(text: _rule.timeoutMillisecond.toString());
    _orderCtrl = TextEditingController(text: _rule.order.toString());
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _groupCtrl.dispose();
    _patternCtrl.dispose();
    _replacementCtrl.dispose();
    _scopeCtrl.dispose();
    _excludeScopeCtrl.dispose();
    _timeoutCtrl.dispose();
    _orderCtrl.dispose();
    _testInputCtrl.dispose();
    super.dispose();
  }

  void _syncRuleFromFields() {
    int? tryInt(String text) => int.tryParse(text.trim());

    setState(() {
      _rule = _rule.copyWith(
        name: _nameCtrl.text,
        group: _groupCtrl.text.trim().isEmpty ? null : _groupCtrl.text.trim(),
        pattern: _patternCtrl.text,
        replacement: _replacementCtrl.text,
        scope: _scopeCtrl.text.trim().isEmpty ? null : _scopeCtrl.text.trim(),
        excludeScope: _excludeScopeCtrl.text.trim().isEmpty
            ? null
            : _excludeScopeCtrl.text.trim(),
        timeoutMillisecond: tryInt(_timeoutCtrl.text) ?? _rule.timeoutMillisecond,
        order: tryInt(_orderCtrl.text) ?? _rule.order,
      );
    });
  }

  void _save() {
    _syncRuleFromFields();
    widget.onSave(_rule);
    Navigator.pop(context);
  }

  Future<void> _runTest() async {
    _syncRuleFromFields();
    final input = _testInputCtrl.text;
    final out = await _engine.applyToContent(input, [_rule]);
    if (!mounted) return;
    setState(() => _testOutput = out);
  }

  @override
  Widget build(BuildContext context) {
    final valid = _engine.isValid(_rule);

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('编辑规则'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _save,
          child: const Text('保存'),
        ),
      ),
      child: SafeArea(
        child: ListView(
          children: [
            CupertinoListSection.insetGrouped(
              header: const Text('基础'),
              children: [
                CupertinoListTile.notched(
                  title: const Text('启用'),
                  trailing: CupertinoSwitch(
                    value: _rule.isEnabled,
                    onChanged: (v) => setState(() => _rule = _rule.copyWith(isEnabled: v)),
                  ),
                ),
                _TextFieldTile(
                  title: '名称',
                  controller: _nameCtrl,
                  onChanged: (_) => _syncRuleFromFields(),
                ),
                _TextFieldTile(
                  title: '分组',
                  controller: _groupCtrl,
                  placeholder: '可选',
                  onChanged: (_) => _syncRuleFromFields(),
                ),
              ],
            ),
            CupertinoListSection.insetGrouped(
              header: const Text('替换'),
              children: [
                CupertinoListTile.notched(
                  title: const Text('正则模式'),
                  trailing: CupertinoSwitch(
                    value: _rule.isRegex,
                    onChanged: (v) => setState(() => _rule = _rule.copyWith(isRegex: v)),
                  ),
                ),
                _TextFieldTile(
                  title: '匹配（pattern）',
                  controller: _patternCtrl,
                  placeholder: '必填',
                  maxLines: 3,
                  onChanged: (_) => _syncRuleFromFields(),
                ),
                _TextFieldTile(
                  title: '替换为（replacement）',
                  controller: _replacementCtrl,
                  placeholder: '可为空',
                  maxLines: 3,
                  onChanged: (_) => _syncRuleFromFields(),
                ),
                CupertinoListTile(
                  title: const Text('有效性'),
                  additionalInfo: Text(valid ? '有效' : '无效'),
                ),
              ],
            ),
            CupertinoListSection.insetGrouped(
              header: const Text('范围'),
              children: [
                _TextFieldTile(
                  title: '作用范围（scope）',
                  controller: _scopeCtrl,
                  placeholder: '书名/书源名/书源URL，逗号或换行分隔',
                  maxLines: 2,
                  onChanged: (_) => _syncRuleFromFields(),
                ),
                _TextFieldTile(
                  title: '排除范围（excludeScope）',
                  controller: _excludeScopeCtrl,
                  placeholder: '可选',
                  maxLines: 2,
                  onChanged: (_) => _syncRuleFromFields(),
                ),
                CupertinoListTile.notched(
                  title: const Text('作用于标题（scopeTitle）'),
                  trailing: CupertinoSwitch(
                    value: _rule.scopeTitle,
                    onChanged: (v) => setState(() => _rule = _rule.copyWith(scopeTitle: v)),
                  ),
                ),
                CupertinoListTile.notched(
                  title: const Text('作用于正文（scopeContent）'),
                  trailing: CupertinoSwitch(
                    value: _rule.scopeContent,
                    onChanged: (v) => setState(() => _rule = _rule.copyWith(scopeContent: v)),
                  ),
                ),
              ],
            ),
            CupertinoListSection.insetGrouped(
              header: const Text('排序/超时'),
              children: [
                _TextFieldTile(
                  title: '超时（ms）',
                  controller: _timeoutCtrl,
                  placeholder: '3000',
                  keyboardType: TextInputType.number,
                  onChanged: (_) => _syncRuleFromFields(),
                ),
                _TextFieldTile(
                  title: '排序（order）',
                  controller: _orderCtrl,
                  placeholder: '-2147483648',
                  keyboardType: TextInputType.number,
                  onChanged: (_) => _syncRuleFromFields(),
                ),
              ],
            ),
            CupertinoListSection.insetGrouped(
              header: const Text('测试'),
              children: [
                _TextFieldTile(
                  title: '输入文本',
                  controller: _testInputCtrl,
                  maxLines: 5,
                ),
                CupertinoListTile.notched(
                  title: const Text('运行测试'),
                  trailing: const CupertinoListTileChevron(),
                  onTap: _runTest,
                ),
                CupertinoListTile(
                  title: const Text('输出'),
                  subtitle: Text(_testOutput.isEmpty ? '—' : _testOutput),
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _TextFieldTile extends StatelessWidget {
  final String title;
  final TextEditingController controller;
  final String? placeholder;
  final int maxLines;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;

  const _TextFieldTile({
    required this.title,
    required this.controller,
    this.placeholder,
    this.maxLines = 1,
    this.keyboardType,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return CupertinoListTile(
      title: Text(title),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: CupertinoTextField(
          controller: controller,
          placeholder: placeholder,
          maxLines: maxLines,
          keyboardType: keyboardType,
          onChanged: onChanged,
        ),
      ),
    );
  }
}
