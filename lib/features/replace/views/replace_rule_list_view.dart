import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../../../app/widgets/app_cupertino_page_scaffold.dart';
import '../../../core/database/database_service.dart';
import '../../../core/database/repositories/replace_rule_repository.dart';
import '../../../core/utils/legado_json.dart';
import '../models/replace_rule.dart';
import '../services/replace_rule_import_export_service.dart';
import 'replace_rule_edit_view.dart';

class ReplaceRuleListView extends StatefulWidget {
  const ReplaceRuleListView({super.key});

  @override
  State<ReplaceRuleListView> createState() => _ReplaceRuleListViewState();
}

class _ReplaceRuleListViewState extends State<ReplaceRuleListView> {
  late final ReplaceRuleRepository _repo;
  final ReplaceRuleImportExportService _io = ReplaceRuleImportExportService();

  String _selectedGroup = '全部';
  final TextEditingController _urlCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _repo = ReplaceRuleRepository(DatabaseService());
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppCupertinoPageScaffold(
      title: '文本替换规则',
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CupertinoButton(
            padding: EdgeInsets.zero,
            minimumSize: const Size(30, 30),
            onPressed: _createRule,
            child: const Icon(CupertinoIcons.add),
          ),
          CupertinoButton(
            padding: EdgeInsets.zero,
            minimumSize: const Size(30, 30),
            onPressed: _showMoreMenu,
            child: const Icon(CupertinoIcons.ellipsis),
          ),
        ],
      ),
      child: StreamBuilder<List<ReplaceRule>>(
        stream: _repo.watchAllRules(),
        builder: (context, snapshot) {
          final allRules = snapshot.data ?? _repo.getAllRules();
          allRules.sort((a, b) => a.order.compareTo(b.order));

          final groups = _buildGroups(allRules);
          final activeGroup =
              groups.contains(_selectedGroup) ? _selectedGroup : '全部';
          final rules = _filter(allRules, activeGroup);

          return Column(
            children: [
              _buildGroupFilter(groups, activeGroup),
              Expanded(
                child: rules.isEmpty ? _empty() : _buildList(rules),
              ),
            ],
          );
        },
      ),
    );
  }

  List<String> _buildGroups(List<ReplaceRule> rules) {
    final groups = <String>{};
    for (final r in rules) {
      final g = r.group?.trim();
      if (g != null && g.isNotEmpty) groups.add(g);
    }
    return ['全部', ...groups.toList()..sort(), '未启用'];
  }

  List<ReplaceRule> _filter(List<ReplaceRule> rules, String group) {
    if (group == '全部') return rules;
    if (group == '未启用') return rules.where((r) => !r.isEnabled).toList();
    return rules.where((r) => r.group == group).toList();
  }

  Widget _buildGroupFilter(List<String> groups, String activeGroup) {
    return Container(
      height: 44,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: groups.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final group = groups[index];
          final isSelected = group == activeGroup;
          return GestureDetector(
            onTap: () => setState(() => _selectedGroup = group),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: isSelected
                    ? CupertinoTheme.of(context).primaryColor
                    : CupertinoColors.systemGrey5.resolveFrom(context),
                borderRadius: BorderRadius.circular(22),
              ),
              alignment: Alignment.center,
              child: Text(
                group,
                style: TextStyle(
                  color: isSelected
                      ? CupertinoColors.white
                      : CupertinoColors.label.resolveFrom(context),
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _empty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(CupertinoIcons.nosign, size: 56),
          const SizedBox(height: 12),
          Text(
            '暂无规则',
            style: TextStyle(
              color: CupertinoColors.secondaryLabel.resolveFrom(context),
            ),
          ),
          const SizedBox(height: 16),
          CupertinoButton.filled(
            onPressed: _createRule,
            child: const Text('新建规则'),
          ),
        ],
      ),
    );
  }

  Widget _buildList(List<ReplaceRule> rules) {
    return ListView.builder(
      itemCount: rules.length,
      itemBuilder: (context, index) {
        final rule = rules[index];
        final title = rule.name.isEmpty ? '(未命名)' : rule.name;
        final subtitle = [
          if (rule.group != null && rule.group!.trim().isNotEmpty) rule.group!,
          rule.isRegex ? '正则' : '普通',
          rule.isEnabled ? '启用' : '未启用',
        ].join(' · ');
        return CupertinoListTile.notched(
          title: Text(title),
          subtitle: Text(subtitle),
          trailing: CupertinoSwitch(
            value: rule.isEnabled,
            onChanged: (v) => _repo.updateRule(rule.copyWith(isEnabled: v)),
          ),
          onTap: () => _editRule(rule),
        );
      },
    );
  }

  void _createRule() {
    _editRule(ReplaceRule.create());
  }

  void _editRule(ReplaceRule rule) {
    Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (context) => ReplaceRuleEditView(
          initial: rule,
          onSave: (next) => _repo.addRule(next),
        ),
      ),
    );
  }

  void _showMoreMenu() {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('替换净化规则'),
        actions: [
          CupertinoActionSheetAction(
            child: const Text('从剪贴板导入'),
            onPressed: () {
              Navigator.pop(context);
              _importFromClipboard();
            },
          ),
          CupertinoActionSheetAction(
            child: const Text('从文件导入'),
            onPressed: () {
              Navigator.pop(context);
              _importFromFile();
            },
          ),
          CupertinoActionSheetAction(
            child: const Text('从网络导入'),
            onPressed: () {
              Navigator.pop(context);
              _importFromUrl();
            },
          ),
          CupertinoActionSheetAction(
            child: const Text('导出'),
            onPressed: () {
              Navigator.pop(context);
              _export();
            },
          ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            child: const Text('删除未启用规则'),
            onPressed: () {
              Navigator.pop(context);
              _repo.deleteDisabledRules();
            },
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          child: const Text('取消'),
          onPressed: () => Navigator.pop(context),
        ),
      ),
    );
  }

  Future<void> _importFromClipboard() async {
    final data = await Clipboard.getData('text/plain');
    final text = data?.text?.trim();
    if (text == null || text.isEmpty) {
      _showMessage('剪贴板为空');
      return;
    }
    final result = _io.importFromJson(text);
    if (!result.success) {
      _showMessage(result.errorMessage ?? '导入失败');
      return;
    }
    await _repo.addRules(result.rules);
    _showMessage('成功导入 ${result.rules.length} 条规则');
  }

  Future<void> _importFromFile() async {
    final result = await _io.importFromFile();
    if (!result.success) {
      if (result.cancelled) return;
      _showMessage(result.errorMessage ?? '导入失败');
      return;
    }
    await _repo.addRules(result.rules);
    _showMessage('成功导入 ${result.rules.length} 条规则');
  }

  Future<void> _importFromUrl() async {
    _urlCtrl.clear();
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('从网络导入'),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: CupertinoTextField(
            controller: _urlCtrl,
            placeholder: '输入规则 URL',
          ),
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('取消'),
            onPressed: () => Navigator.pop(context),
          ),
          CupertinoDialogAction(
            child: const Text('导入'),
            onPressed: () async {
              final url = _urlCtrl.text.trim();
              Navigator.pop(context);
              if (url.isEmpty) {
                _showMessage('URL 为空');
                return;
              }
              final result = await _io.importFromUrl(url);
              if (!result.success) {
                _showMessage(result.errorMessage ?? '导入失败');
                return;
              }
              await _repo.addRules(result.rules);
              _showMessage('成功导入 ${result.rules.length} 条规则');
            },
          ),
        ],
      ),
    );
  }

  Future<void> _export() async {
    final rules = _repo.getAllRules()
      ..sort((a, b) => a.order.compareTo(b.order));
    final jsonText = LegadoJson.encode(
      rules.map((r) => r.toJson()).toList(growable: false),
    );
    // iOS/Android：保存文件；Web：复制到剪贴板（这里统一复制，避免平台差异）
    await Clipboard.setData(ClipboardData(text: jsonText));
    _showMessage('已复制 JSON（可粘贴保存为 replaceRule.json）');
  }

  void _showMessage(String message) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('提示'),
        content: Text('\n$message'),
        actions: [
          CupertinoDialogAction(
            child: const Text('好'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }
}
