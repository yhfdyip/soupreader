import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../../../app/widgets/app_action_list_sheet.dart';
import '../../../app/widgets/app_cupertino_page_scaffold.dart';
import '../../../app/widgets/app_empty_state.dart';
import '../../../app/widgets/app_manage_search_field.dart';
import '../../../app/widgets/app_nav_bar_button.dart';
import '../../../app/widgets/app_popover_menu.dart';
import '../../../app/widgets/app_ui_kit.dart';
import '../../../app/widgets/cupertino_bottom_dialog.dart';
import '../../../core/database/database_service.dart';
import '../../../core/database/repositories/replace_rule_repository.dart';
import '../../../core/services/exception_log_service.dart';
import '../../../core/services/online_import_history_store.dart';
import '../../../core/services/qr_scan_service.dart';
import '../../../core/utils/file_picker_save_compat.dart';
import '../../../core/utils/legado_json.dart';
import '../../search/models/search_scope_group_helper.dart';
import '../../settings/views/app_help_dialog.dart';
import '../models/replace_rule.dart';
import '../services/replace_rule_import_export_service.dart';
import 'replace_rule_edit_view.dart';

class ReplaceRuleListView extends StatefulWidget {
  const ReplaceRuleListView({super.key});

  @override
  State<ReplaceRuleListView> createState() => _ReplaceRuleListViewState();
}

enum _ReplaceRuleTopMenuAction {
  create,
  importFile,
  importUrl,
  importQr,
  help,
}

class _ReplaceRuleListViewState extends State<ReplaceRuleListView> {
  static const int _maxImportDepth = 5;
  static const String _requestWithoutUaSuffix = '#requestWithoutUA';
  static const String _onlineImportHistoryKey = 'replaceRuleRecordKey';
  static const String _groupFilterAll = '';
  static const String _groupFilterNoGroup = '__no_group__';
  static const String _noGroupLabel = '未分组';
  static final RegExp _groupSplitPattern = RegExp(r'[,;，；]');

  late final ReplaceRuleRepository _repo;
  final GlobalKey _moreMenuKey = GlobalKey();
  final ReplaceRuleImportExportService _io = ReplaceRuleImportExportService();
  final TextEditingController _searchController = TextEditingController();
  final OnlineImportHistoryStore _onlineImportHistoryStore =
      OnlineImportHistoryStore();

  String _activeGroupQuery = _groupFilterAll;
  String _searchQuery = '';
  bool _importingLocal = false;
  bool _importingOnline = false;
  bool _importingQr = false;
  bool _exportingSelection = false;
  bool _enablingSelection = false;
  bool _disablingSelection = false;
  bool _toppingSelection = false;
  bool _bottomingSelection = false;
  bool _deletingSelection = false;
  bool _selectionMode = false;
  final Set<int> _selectedRuleIds = <int>{};

  bool get _selectionUpdating =>
      _enablingSelection ||
      _disablingSelection ||
      _toppingSelection ||
      _bottomingSelection;

  bool get _selectionActionBusy =>
      _exportingSelection || _selectionUpdating || _deletingSelection;

  bool get _menuBusy =>
      _importingLocal ||
      _importingOnline ||
      _importingQr ||
      _exportingSelection ||
      _selectionUpdating ||
      _deletingSelection;

  @override
  void initState() {
    super.initState();
    _repo = ReplaceRuleRepository(DatabaseService());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ReplaceRule>>(
      stream: _repo.watchAllRules(),
      builder: (context, snapshot) {
        final allRules = List<ReplaceRule>.from(
          snapshot.data ?? _repo.getAllRules(),
        )..sort((a, b) => a.order.compareTo(b.order));
        _syncSelectionWithRules(allRules);

        final groups = _buildGroups(allRules);
        final activeGroupQuery = _resolveActiveGroupQuery(groups);
        // 对齐 legado：当搜索关键字非空时，优先走搜索分支（含 `group:` 与“未分组”语义）。
        final normalizedSearchQuery = _searchQuery.trim();
        final rules = normalizedSearchQuery.isEmpty
            ? _filterRulesByGroupQuery(allRules, activeGroupQuery)
            : _filterRulesBySearchQueryLikeLegado(
                allRules,
                normalizedSearchQuery,
              );
        final selectedCount = _selectedCountIn(rules);
        final totalCount = rules.length;
        final hasSelection = selectedCount > 0;
        final allSelected = totalCount > 0 && selectedCount == totalCount;
        final enabledColor = CupertinoColors.activeBlue.resolveFrom(context);
        final disabledColor = CupertinoColors.systemGrey.resolveFrom(context);

        return AppCupertinoPageScaffold(
          title: '文本替换规则',
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppNavBarButton(
                onPressed:
                    _menuBusy ? null : () => _showGroupFilterOptions(allRules),
                child: const Icon(CupertinoIcons.square_grid_2x2),
              ),
              AppNavBarButton(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                onPressed: _menuBusy || (!_selectionMode && allRules.isEmpty)
                    ? null
                    : () => _toggleSelectionMode(allRules),
                child: Text(
                  _selectionMode ? '完成' : '多选',
                  style: const TextStyle(fontSize: 13),
                ),
              ),
              AppNavBarButton(
                key: _moreMenuKey,
                onPressed: _selectionMode
                    ? (hasSelection && !_menuBusy
                        ? () => _showSelectionMoreMenu(rules)
                        : null)
                    : (_menuBusy ? null : _showMoreMenu),
                child: _selectionMode
                    ? (_selectionActionBusy
                        ? const CupertinoActivityIndicator(radius: 9)
                        : Icon(
                            CupertinoIcons.ellipsis_circle,
                            color: hasSelection ? enabledColor : disabledColor,
                          ))
                    : (_menuBusy
                        ? const CupertinoActivityIndicator(radius: 9)
                        : const Icon(CupertinoIcons.ellipsis)),
              ),
            ],
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
                child: AppManageSearchField(
                  controller: _searchController,
                  placeholder: '替换净化搜索',
                  onChanged: _onSearchQueryChanged,
                ),
              ),
              Expanded(
                child: rules.isEmpty ? _empty() : _buildList(rules),
              ),
              if (_selectionMode)
                SafeArea(
                  top: false,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(12, 6, 8, 8),
                    decoration: BoxDecoration(
                      color:
                          CupertinoColors.systemGroupedBackground.resolveFrom(
                        context,
                      ),
                      border: Border(
                        top: BorderSide(
                          color: CupertinoColors.systemGrey4.resolveFrom(
                            context,
                          ),
                          width: 0.5,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: CupertinoButton(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 6,
                            ),
                            minimumSize: const Size(30, 30),
                            alignment: Alignment.centerLeft,
                            onPressed: totalCount == 0
                                ? null
                                : () => _toggleSelectAllRules(rules),
                            child: Text(
                              allSelected
                                  ? '取消全选（$selectedCount/$totalCount）'
                                  : '全选（$selectedCount/$totalCount）',
                              style: TextStyle(
                                fontSize: 13,
                                color: totalCount == 0
                                    ? disabledColor
                                    : enabledColor,
                              ),
                            ),
                          ),
                        ),
                        CupertinoButton(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 6,
                          ),
                          minimumSize: const Size(30, 30),
                          onPressed: totalCount == 0
                              ? null
                              : () => _revertSelection(rules),
                          child: Text(
                            '反选',
                            style: TextStyle(
                              fontSize: 13,
                              color: totalCount == 0
                                  ? disabledColor
                                  : enabledColor,
                            ),
                          ),
                        ),
                        CupertinoButton(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 6,
                          ),
                          minimumSize: const Size(30, 30),
                          onPressed: hasSelection && !_menuBusy
                              ? () => _confirmDeleteSelectedRules(rules)
                              : null,
                          child: _deletingSelection
                              ? const CupertinoActivityIndicator(radius: 9)
                              : Text(
                                  '删除',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: hasSelection && !_menuBusy
                                        ? CupertinoColors.systemRed
                                            .resolveFrom(context)
                                        : disabledColor,
                                  ),
                                ),
                        ),
                        CupertinoButton(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 6,
                          ),
                          minimumSize: const Size(30, 30),
                          onPressed: hasSelection && !_menuBusy
                              ? () => _showSelectionMoreMenu(rules)
                              : null,
                          child: _selectionActionBusy
                              ? const CupertinoActivityIndicator(radius: 9)
                              : Icon(
                                  CupertinoIcons.ellipsis_circle,
                                  size: 19,
                                  color: hasSelection
                                      ? enabledColor
                                      : disabledColor,
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  void _syncSelectionWithRules(List<ReplaceRule> rules) {
    final availableIds = rules.map((rule) => rule.id).toSet();
    _selectedRuleIds.removeWhere((id) => !availableIds.contains(id));
  }

  void _toggleSelectionMode(List<ReplaceRule> rules) {
    if (rules.isEmpty) return;
    setState(() {
      _selectionMode = !_selectionMode;
      _selectedRuleIds.clear();
    });
  }

  int _selectedCountIn(List<ReplaceRule> rules) {
    var count = 0;
    for (final rule in rules) {
      if (_selectedRuleIds.contains(rule.id)) {
        count += 1;
      }
    }
    return count;
  }

  void _toggleRuleSelection(int ruleId) {
    setState(() {
      if (_selectedRuleIds.contains(ruleId)) {
        _selectedRuleIds.remove(ruleId);
      } else {
        _selectedRuleIds.add(ruleId);
      }
    });
  }

  void _toggleSelectAllRules(List<ReplaceRule> rules) {
    if (rules.isEmpty) return;
    setState(() {
      final allSelected = _selectedCountIn(rules) == rules.length;
      if (allSelected) {
        _selectedRuleIds.removeAll(rules.map((rule) => rule.id));
      } else {
        _selectedRuleIds.addAll(rules.map((rule) => rule.id));
      }
    });
  }

  void _revertSelection(List<ReplaceRule> rules) {
    if (rules.isEmpty) return;
    setState(() {
      for (final rule in rules) {
        if (_selectedRuleIds.contains(rule.id)) {
          _selectedRuleIds.remove(rule.id);
        } else {
          _selectedRuleIds.add(rule.id);
        }
      }
    });
  }

  void _onSearchQueryChanged(String value) {
    setState(() {
      _searchQuery = value;
      // 搜索分支与分组分支在 build 中互斥，输入搜索时无需主动改写分组状态。
      _selectedRuleIds.clear();
    });
  }

  List<String> _buildGroups(List<ReplaceRule> rules) {
    final groups = <String>{};
    for (final rule in rules) {
      final raw = rule.group?.trim();
      if (raw == null || raw.isEmpty) {
        continue;
      }
      for (final part in raw.split(_groupSplitPattern)) {
        final group = part.trim();
        if (group.isEmpty) {
          continue;
        }
        groups.add(group);
      }
    }
    final sorted = groups.toList(growable: false)
      ..sort(SearchScopeGroupHelper.cnCompareLikeLegado);
    return sorted;
  }

  String _resolveActiveGroupQuery(List<String> groups) {
    if (_activeGroupQuery == _groupFilterAll ||
        _activeGroupQuery == _groupFilterNoGroup) {
      return _activeGroupQuery;
    }
    if (groups.contains(_activeGroupQuery)) {
      return _activeGroupQuery;
    }
    return _groupFilterAll;
  }

  List<ReplaceRule> _filterRulesByGroupQuery(
    List<ReplaceRule> rules,
    String query,
  ) {
    if (query == _groupFilterAll) {
      return rules;
    }
    if (query == _groupFilterNoGroup) {
      return rules.where(_isNoGroupRule).toList(growable: false);
    }
    return rules
        .where((rule) => _containsLikeLegacy(rule.group ?? '', query))
        .toList(growable: false);
  }

  /// 对齐 legado ReplaceRuleActivity.observeReplaceRuleData：
  /// 1) `未分组` -> flowNoGroup
  /// 2) `group:xxx` -> flowGroupSearch("%xxx%")
  /// 3) 其它关键字 -> flowSearch("%key%")（name/group 联合搜索）
  List<ReplaceRule> _filterRulesBySearchQueryLikeLegado(
    List<ReplaceRule> rules,
    String query,
  ) {
    final raw = query.trim();
    if (raw.isEmpty) {
      return rules;
    }
    if (raw == _noGroupLabel) {
      return rules.where(_isNoGroupRule).toList(growable: false);
    }
    if (raw.startsWith('group:')) {
      final key = raw.substring(6).trim();
      return rules.where((rule) {
        final group = rule.group;
        if (group == null) return false;
        // legacy SQL `group like '%%'` 会匹配空字符串分组，但不会命中 null。
        if (key.isEmpty) return true;
        return _containsLikeLegacy(group, key);
      }).toList(growable: false);
    }
    return rules.where((rule) {
      final group = rule.group ?? '';
      return _containsLikeLegacy(group, raw) ||
          _containsLikeLegacy(rule.name, raw);
    }).toList(growable: false);
  }

  /// 近似对齐 SQLite `LIKE '%key%'` 的匹配语义：
  /// - 空 key 视为命中；
  /// - 采用不区分大小写的“包含”匹配，避免 Dart `contains` 比 SQL `LIKE` 更严格。
  bool _containsLikeLegacy(String text, String key) {
    final normalizedKey = key.trim();
    if (normalizedKey.isEmpty) return true;
    return text.toLowerCase().contains(normalizedKey.toLowerCase());
  }

  bool _isNoGroupRule(ReplaceRule rule) {
    final raw = rule.group;
    if (raw == null) {
      return true;
    }
    final text = raw.trim();
    if (text.isEmpty) {
      return true;
    }
    return text.contains(_noGroupLabel);
  }

  Future<void> _showGroupFilterOptions(List<ReplaceRule> allRules) async {
    final groups = _buildGroups(allRules);
    final activeGroupQuery = _resolveActiveGroupQuery(groups);
    const manageToken = '__group_manage__';
    final items = <AppActionListItem<String>>[
      const AppActionListItem<String>(
        value: manageToken,
        icon: CupertinoIcons.square_list,
        label: '分组管理',
      ),
      AppActionListItem<String>(
        value: _groupFilterAll,
        icon: activeGroupQuery == _groupFilterAll
            ? CupertinoIcons.check_mark_circled_solid
            : CupertinoIcons.square_grid_2x2,
        label: '${activeGroupQuery == _groupFilterAll ? '✓ ' : ''}全部',
      ),
      AppActionListItem<String>(
        value: _groupFilterNoGroup,
        icon: activeGroupQuery == _groupFilterNoGroup
            ? CupertinoIcons.check_mark_circled_solid
            : CupertinoIcons.circle,
        label:
            '${activeGroupQuery == _groupFilterNoGroup ? '✓ ' : ''}$_noGroupLabel',
      ),
      ...groups.map(
        (group) => AppActionListItem<String>(
          value: group,
          icon: activeGroupQuery == group
              ? CupertinoIcons.check_mark_circled_solid
              : CupertinoIcons.folder,
          label: '${activeGroupQuery == group ? '✓ ' : ''}$group',
        ),
      ),
    ];
    final selected = await showAppActionListSheet<String>(
      context: context,
      title: '分组',
      showCancel: true,
      items: items,
    );
    if (selected == null || !mounted) return;
    if (selected == manageToken) {
      _showGroupManageSheet();
      return;
    }
    _applyGroupQuery(selected);
  }

  void _applyGroupQuery(String query) {
    setState(() {
      _activeGroupQuery = query;
      _searchQuery = '';
      _selectedRuleIds.clear();
    });
    if (_searchController.text.isNotEmpty) {
      _searchController.clear();
    }
  }

  void _recordViewError({
    required String node,
    required String message,
    required Object error,
    required StackTrace stackTrace,
    Map<String, dynamic>? context,
  }) {
    ExceptionLogService().record(
      node: node,
      message: message,
      error: error,
      stackTrace: stackTrace,
      context: context,
    );
    debugPrint('[replace-rule] $node failed: $error');
  }

  Future<void> _showGroupManageSheet() async {
    await showCupertinoBottomSheetDialog<void>(
      context: context,
      builder: (sheetContext) {
        return CupertinoPopupSurface(
          isSurfacePainted: true,
          child: SizedBox(
            height:
                math.min(MediaQuery.of(sheetContext).size.height * 0.78, 560),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          '分组管理',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(32, 32),
                        onPressed: () async {
                          final name = await _showGroupInputDialog(
                            title: '添加分组',
                          );
                          if (name == null) return;
                          await _addGroupToNoGroupRules(name);
                        },
                        child: const Icon(CupertinoIcons.add_circled),
                      ),
                    ],
                  ),
                ),
                Container(
                  height: 0.5,
                  color: CupertinoColors.systemGrey4.resolveFrom(sheetContext),
                ),
                Expanded(
                  child: StreamBuilder<List<ReplaceRule>>(
                    stream: _repo.watchAllRules(),
                    builder: (context, snapshot) {
                      final allRules = List<ReplaceRule>.from(
                        snapshot.data ?? _repo.getAllRules(),
                      )..sort((a, b) => a.order.compareTo(b.order));
                      final groups = _buildGroups(allRules);
                      if (groups.isEmpty) {
                        return Center(
                          child: Text(
                            '暂无分组',
                            style: TextStyle(
                              color: CupertinoColors.secondaryLabel.resolveFrom(
                                context,
                              ),
                            ),
                          ),
                        );
                      }
                      return ListView.separated(
                        padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                        itemCount: groups.length,
                        separatorBuilder: (_, __) => Container(
                          height: 0.5,
                          color:
                              CupertinoColors.systemGrey4.resolveFrom(context),
                        ),
                        itemBuilder: (context, index) {
                          final group = groups[index];
                          return SizedBox(
                            height: 44,
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    group,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                CupertinoButton(
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 6),
                                  minimumSize: const Size(36, 30),
                                  onPressed: () async {
                                    final renamed = await _showGroupInputDialog(
                                      title: '编辑分组',
                                      initialValue: group,
                                    );
                                    if (renamed == null) return;
                                    await _renameGroup(
                                        oldGroup: group, newGroup: renamed);
                                  },
                                  child: const Text('编辑'),
                                ),
                                CupertinoButton(
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 6),
                                  minimumSize: const Size(36, 30),
                                  onPressed: () => _removeGroup(group),
                                  child: Text(
                                    '删除',
                                    style: TextStyle(
                                      color:
                                          CupertinoColors.systemRed.resolveFrom(
                                        context,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<String?> _showGroupInputDialog({
    required String title,
    String initialValue = '',
  }) async {
    final controller = TextEditingController(text: initialValue);
    try {
      final value = await showCupertinoBottomDialog<String>(
        context: context,
        builder: (dialogContext) => CupertinoAlertDialog(
          title: Text(title),
          content: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: CupertinoTextField(
              controller: controller,
              placeholder: '分组名称',
              autofocus: true,
            ),
          ),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('取消'),
            ),
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(dialogContext, controller.text),
              child: const Text('确定'),
            ),
          ],
        ),
      );
      return value?.trim();
    } finally {
      controller.dispose();
    }
  }

  Future<void> _addGroupToNoGroupRules(String group) async {
    final normalized = group.trim();
    if (normalized.isEmpty) return;
    try {
      final updates = _repo
          .getAllRules()
          .where((rule) {
            final raw = rule.group;
            return raw == null || raw.trim().isEmpty;
          })
          .map((rule) => rule.copyWith(group: normalized))
          .toList(growable: false);
      if (updates.isEmpty) return;
      await _repo.addRules(updates);
    } catch (error, stackTrace) {
      _recordViewError(
        node: 'replace_rule.group.add',
        message: '新增替换规则分组失败',
        error: error,
        stackTrace: stackTrace,
        context: <String, dynamic>{
          'group': normalized,
        },
      );
    }
  }

  Future<void> _renameGroup({
    required String oldGroup,
    required String newGroup,
  }) async {
    final nextGroup = newGroup.trim();
    try {
      final updates = <ReplaceRule>[];
      for (final rule in _repo.getAllRules()) {
        final raw = rule.group;
        if (raw == null || raw.isEmpty || !raw.contains(oldGroup)) {
          continue;
        }
        final groups = _splitGroupsForGroupMutation(raw);
        if (!groups.remove(oldGroup)) {
          continue;
        }
        if (nextGroup.isNotEmpty) {
          groups.add(nextGroup);
        }
        updates.add(rule.copyWith(group: _joinGroupsForGroupMutation(groups)));
      }
      if (updates.isEmpty) return;
      await _repo.addRules(updates);
    } catch (error, stackTrace) {
      _recordViewError(
        node: 'replace_rule.group.rename',
        message: '重命名替换规则分组失败',
        error: error,
        stackTrace: stackTrace,
        context: <String, dynamic>{
          'oldGroup': oldGroup,
          'newGroup': nextGroup,
        },
      );
    }
  }

  Future<void> _removeGroup(String group) async {
    await _renameGroup(oldGroup: group, newGroup: '');
  }

  Set<String> _splitGroupsForGroupMutation(String rawGroup) {
    final groups = <String>{};
    for (final part in rawGroup.split(_groupSplitPattern)) {
      final group = part.trim();
      if (group.isEmpty) {
        continue;
      }
      groups.add(group);
    }
    return groups;
  }

  String _joinGroupsForGroupMutation(Set<String> groups) {
    if (groups.isEmpty) {
      return '';
    }
    return groups.join(',');
  }

  Widget _empty() {
    return AppEmptyState(
      illustration: const AppEmptyPlanetIllustration(size: 86),
      title: '暂无规则',
      message: '可通过新建或导入创建替换净化规则',
      action: CupertinoButton.filled(
        onPressed: _createRule,
        child: const Text('新建规则'),
      ),
    );
  }

  Widget _buildList(List<ReplaceRule> rules) {
    return AppListView(
      padding: const EdgeInsets.only(top: 8, bottom: 20),
      children: [
        for (var index = 0; index < rules.length; index++) ...[
          Builder(
            builder: (context) {
              final rule = rules[index];
              final selected = _selectedRuleIds.contains(rule.id);
              final title = rule.name.isEmpty ? '(未命名)' : rule.name;
              final subtitle = [
                if (rule.group != null && rule.group!.trim().isNotEmpty)
                  rule.group!,
                rule.isRegex ? '正则' : '普通',
                rule.isEnabled ? '启用' : '未启用',
              ].join(' · ');
              final tile = CupertinoListTile.notched(
                title: Text(title),
                subtitle: Text(subtitle),
                trailing: _selectionMode
                    ? Icon(
                        selected
                            ? CupertinoIcons.check_mark_circled_solid
                            : CupertinoIcons.circle,
                        color: selected
                            ? CupertinoColors.activeBlue.resolveFrom(context)
                            : CupertinoColors.secondaryLabel
                                .resolveFrom(context),
                        size: 20,
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CupertinoSwitch(
                            value: rule.isEnabled,
                            onChanged: (v) =>
                                _repo.updateRule(rule.copyWith(isEnabled: v)),
                          ),
                          CupertinoButton(
                            padding: const EdgeInsets.only(left: 4, right: 2),
                            minimumSize: const Size(30, 30),
                            onPressed: () => _showRuleItemMenu(rule),
                            child: const Icon(
                              CupertinoIcons.ellipsis,
                              size: 18,
                            ),
                          ),
                        ],
                      ),
                onTap: _selectionMode
                    ? () => _toggleRuleSelection(rule.id)
                    : () => _editRule(rule),
              );
              final child = (!_selectionMode || !selected)
                  ? tile
                  : DecoratedBox(
                      decoration: BoxDecoration(
                        color: CupertinoColors.systemGrey6.resolveFrom(context),
                      ),
                      child: tile,
                    );
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: AppCard(
                  padding: EdgeInsets.zero,
                  child: child,
                ),
              );
            },
          ),
          if (index < rules.length - 1) const SizedBox(height: 8),
        ],
      ],
    );
  }

  void _createRule() {
    _editRule(ReplaceRule.create());
  }

  int _nextReplaceRuleOrder() {
    var maxOrder = ReplaceRule.unsetOrder;
    for (final rule in _repo.getAllRules()) {
      if (rule.order > maxOrder) {
        maxOrder = rule.order;
      }
    }
    return maxOrder + 1;
  }

  ReplaceRule _normalizeRuleForSave(ReplaceRule rule) {
    if (rule.order != ReplaceRule.unsetOrder) {
      return rule;
    }
    return rule.copyWith(order: _nextReplaceRuleOrder());
  }

  void _editRule(ReplaceRule rule) {
    Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (context) => ReplaceRuleEditView(
          initial: rule,
          onSave: (next) async {
            await _repo.addRule(_normalizeRuleForSave(next));
          },
        ),
      ),
    );
  }

  Future<void> _showMoreMenu() async {
    if (_menuBusy) return;
    if (!mounted) return;
    final action = await showAppPopoverMenu<_ReplaceRuleTopMenuAction>(
      context: context,
      anchorKey: _moreMenuKey,
      items: const [
        AppPopoverMenuItem(
          value: _ReplaceRuleTopMenuAction.create,
          icon: CupertinoIcons.add_circled,
          label: '新建替换',
        ),
        AppPopoverMenuItem(
          value: _ReplaceRuleTopMenuAction.importFile,
          icon: CupertinoIcons.doc,
          label: '本地导入',
        ),
        AppPopoverMenuItem(
          value: _ReplaceRuleTopMenuAction.importUrl,
          icon: CupertinoIcons.globe,
          label: '网络导入',
        ),
        AppPopoverMenuItem(
          value: _ReplaceRuleTopMenuAction.importQr,
          icon: CupertinoIcons.qrcode,
          label: '二维码导入',
        ),
        AppPopoverMenuItem(
          value: _ReplaceRuleTopMenuAction.help,
          icon: CupertinoIcons.question_circle,
          label: '帮助',
        ),
      ],
    );
    if (!mounted || action == null) return;
    switch (action) {
      case _ReplaceRuleTopMenuAction.create:
        _createRule();
        break;
      case _ReplaceRuleTopMenuAction.importFile:
        _importFromFile();
        break;
      case _ReplaceRuleTopMenuAction.importUrl:
        _importFromUrl();
        break;
      case _ReplaceRuleTopMenuAction.importQr:
        _importFromQr();
        break;
      case _ReplaceRuleTopMenuAction.help:
        _showReplaceRuleHelp();
        break;
    }
  }

  Future<void> _showRuleItemMenu(ReplaceRule rule) async {
    final action = await showAppActionListSheet<_ReplaceRuleItemMenuAction>(
      context: context,
      title: rule.name.isEmpty ? '未命名规则' : rule.name,
      showCancel: true,
      items: const [
        AppActionListItem<_ReplaceRuleItemMenuAction>(
          value: _ReplaceRuleItemMenuAction.top,
          icon: CupertinoIcons.arrow_up_circle,
          label: '置顶',
        ),
        AppActionListItem<_ReplaceRuleItemMenuAction>(
          value: _ReplaceRuleItemMenuAction.bottom,
          icon: CupertinoIcons.arrow_down_circle,
          label: '置底',
        ),
        AppActionListItem<_ReplaceRuleItemMenuAction>(
          value: _ReplaceRuleItemMenuAction.delete,
          icon: CupertinoIcons.delete,
          label: '删除',
          isDestructiveAction: true,
        ),
      ],
    );
    if (action == null || !mounted) return;
    switch (action) {
      case _ReplaceRuleItemMenuAction.top:
        await _moveRuleToTop(rule);
        return;
      case _ReplaceRuleItemMenuAction.bottom:
        await _moveRuleToBottom(rule);
        return;
      case _ReplaceRuleItemMenuAction.delete:
        if (_selectedRuleIds.remove(rule.id)) {
          setState(() {});
        }
        await _confirmDeleteRule(rule);
        return;
    }
  }

  Future<void> _confirmDeleteRule(ReplaceRule rule) async {
    final confirmed = await showCupertinoBottomDialog<bool>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: const Text('提醒'),
        content: Text('是否确认删除？\n${rule.name}'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('确定'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    try {
      await _repo.deleteRule(rule.id);
    } catch (error, stackTrace) {
      _recordViewError(
        node: 'replace_rule.delete',
        message: '删除替换规则失败',
        error: error,
        stackTrace: stackTrace,
        context: <String, dynamic>{
          'ruleId': rule.id,
          'ruleName': rule.name,
        },
      );
    }
  }

  Future<void> _confirmDeleteSelectedRules(
      List<ReplaceRule> visibleRules) async {
    final selectedRules = _selectedRulesByCurrentOrder(visibleRules);
    if (selectedRules.isEmpty) return;
    final confirmed = await showCupertinoBottomDialog<bool>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: const Text('提醒'),
        content: const Text('是否确认删除？'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('确定'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    await _deleteSelectedRules(selectedRules);
  }

  Future<void> _deleteSelectedRules(List<ReplaceRule> selectedRules) async {
    if (_deletingSelection || selectedRules.isEmpty) return;
    setState(() => _deletingSelection = true);
    try {
      final targetIds = selectedRules.map((rule) => rule.id).toSet();
      await _repo.deleteRulesByIds(targetIds);
      _selectedRuleIds.removeWhere(targetIds.contains);
    } catch (error, stackTrace) {
      _recordViewError(
        node: 'replace_rule.delete_selection',
        message: '批量删除替换规则失败',
        error: error,
        stackTrace: stackTrace,
        context: <String, dynamic>{
          'count': selectedRules.length,
        },
      );
    } finally {
      if (!mounted) return;
      setState(() => _deletingSelection = false);
    }
  }

  Future<void> _moveRuleToTop(ReplaceRule rule) async {
    try {
      final allRules = _repo.getAllRules();
      if (allRules.isEmpty) return;
      var minOrder = allRules.first.order;
      for (final current in allRules.skip(1)) {
        if (current.order < minOrder) {
          minOrder = current.order;
        }
      }
      await _repo.addRule(rule.copyWith(order: minOrder - 1));
    } catch (error, stackTrace) {
      _recordViewError(
        node: 'replace_rule.move_top',
        message: '替换规则置顶失败',
        error: error,
        stackTrace: stackTrace,
        context: <String, dynamic>{
          'ruleId': rule.id,
          'ruleName': rule.name,
        },
      );
    }
  }

  Future<void> _moveRuleToBottom(ReplaceRule rule) async {
    try {
      final allRules = _repo.getAllRules();
      if (allRules.isEmpty) return;
      var maxOrder = allRules.first.order;
      for (final current in allRules.skip(1)) {
        if (current.order > maxOrder) {
          maxOrder = current.order;
        }
      }
      await _repo.addRule(rule.copyWith(order: maxOrder + 1));
    } catch (error, stackTrace) {
      _recordViewError(
        node: 'replace_rule.move_bottom',
        message: '替换规则置底失败',
        error: error,
        stackTrace: stackTrace,
        context: <String, dynamic>{
          'ruleId': rule.id,
          'ruleName': rule.name,
        },
      );
    }
  }

  Future<void> _showSelectionMoreMenu(List<ReplaceRule> visibleRules) async {
    if (_menuBusy || _selectedCountIn(visibleRules) == 0) return;
    final selected = await showAppPopoverMenu<_ReplaceRuleSelectionMenuAction>(
      context: context,
      anchorKey: _moreMenuKey,
      items: const [
        AppPopoverMenuItem(
          value: _ReplaceRuleSelectionMenuAction.enableSelection,
          icon: CupertinoIcons.check_mark,
          label: '启用所选',
        ),
        AppPopoverMenuItem(
          value: _ReplaceRuleSelectionMenuAction.disableSelection,
          icon: CupertinoIcons.xmark,
          label: '禁用所选',
        ),
        AppPopoverMenuItem(
          value: _ReplaceRuleSelectionMenuAction.topSelection,
          icon: CupertinoIcons.arrow_up_to_line,
          label: '置顶所选',
        ),
        AppPopoverMenuItem(
          value: _ReplaceRuleSelectionMenuAction.bottomSelection,
          icon: CupertinoIcons.arrow_down_to_line,
          label: '置底所选',
        ),
        AppPopoverMenuItem(
          value: _ReplaceRuleSelectionMenuAction.exportSelection,
          icon: CupertinoIcons.square_arrow_up,
          label: '导出所选',
        ),
      ],
    );
    if (selected == null) return;
    switch (selected) {
      case _ReplaceRuleSelectionMenuAction.enableSelection:
        await _enableSelectedRules(visibleRules);
        return;
      case _ReplaceRuleSelectionMenuAction.disableSelection:
        await _disableSelectedRules(visibleRules);
        return;
      case _ReplaceRuleSelectionMenuAction.topSelection:
        await _topSelectedRules(visibleRules);
        return;
      case _ReplaceRuleSelectionMenuAction.bottomSelection:
        await _bottomSelectedRules(visibleRules);
        return;
      case _ReplaceRuleSelectionMenuAction.exportSelection:
        await _exportSelectedRules(visibleRules);
        return;
    }
  }

  List<ReplaceRule> _selectedRulesByCurrentOrder(
      List<ReplaceRule> visibleRules) {
    if (visibleRules.isEmpty) return const <ReplaceRule>[];
    return visibleRules
        .where((rule) => _selectedRuleIds.contains(rule.id))
        .toList(growable: false);
  }

  Future<void> _exportSelectedRules(List<ReplaceRule> visibleRules) async {
    if (_exportingSelection) return;
    final selectedRules = _selectedRulesByCurrentOrder(visibleRules);
    if (selectedRules.isEmpty) return;
    setState(() => _exportingSelection = true);
    try {
      final jsonText = LegadoJson.encode(
        selectedRules.map((rule) => rule.toJson()).toList(growable: false),
      );
      final outputPath = await saveFileWithTextCompat(
        dialogTitle: '导出所选',
        fileName: 'exportReplaceRule.json',
        allowedExtensions: const ['json'],
        text: jsonText,
      );
      if (outputPath == null || outputPath.trim().isEmpty) {
        return;
      }
      final normalizedPath = outputPath.trim();
      if (!mounted) return;
      await _showExportPathDialog(normalizedPath);
    } catch (error, stackTrace) {
      _recordViewError(
        node: 'replace_rule.export_selection',
        message: '导出所选替换规则失败',
        error: error,
        stackTrace: stackTrace,
        context: <String, dynamic>{
          'count': selectedRules.length,
        },
      );
      if (!mounted) return;
      await _showMessageDialog(
        title: '导出所选',
        message: '导出失败：$error',
      );
    } finally {
      if (!mounted) return;
      setState(() => _exportingSelection = false);
    }
  }

  Future<void> _enableSelectedRules(List<ReplaceRule> visibleRules) async {
    if (_enablingSelection) return;
    final selectedRules = _selectedRulesByCurrentOrder(visibleRules);
    if (selectedRules.isEmpty) return;
    setState(() => _enablingSelection = true);
    try {
      final updatedRules = selectedRules
          .map((rule) => rule.copyWith(isEnabled: true))
          .toList(growable: false);
      await _repo.addRules(updatedRules);
    } catch (error, stackTrace) {
      _recordViewError(
        node: 'replace_rule.enable_selection',
        message: '批量启用替换规则失败',
        error: error,
        stackTrace: stackTrace,
        context: <String, dynamic>{
          'count': selectedRules.length,
        },
      );
    } finally {
      if (!mounted) return;
      setState(() => _enablingSelection = false);
    }
  }

  Future<void> _disableSelectedRules(List<ReplaceRule> visibleRules) async {
    if (_disablingSelection) return;
    final selectedRules = _selectedRulesByCurrentOrder(visibleRules);
    if (selectedRules.isEmpty) return;
    setState(() => _disablingSelection = true);
    try {
      final updatedRules = selectedRules
          .map((rule) => rule.copyWith(isEnabled: false))
          .toList(growable: false);
      await _repo.addRules(updatedRules);
    } catch (error, stackTrace) {
      _recordViewError(
        node: 'replace_rule.disable_selection',
        message: '批量禁用替换规则失败',
        error: error,
        stackTrace: stackTrace,
        context: <String, dynamic>{
          'count': selectedRules.length,
        },
      );
    } finally {
      if (!mounted) return;
      setState(() => _disablingSelection = false);
    }
  }

  Future<void> _topSelectedRules(List<ReplaceRule> visibleRules) async {
    if (_toppingSelection) return;
    final selectedRules = _selectedRulesByCurrentOrder(visibleRules);
    if (selectedRules.isEmpty) return;
    setState(() => _toppingSelection = true);
    try {
      final allRules = _repo.getAllRules();
      if (allRules.isEmpty) return;
      var minOrder = allRules.first.order;
      for (final rule in allRules.skip(1)) {
        if (rule.order < minOrder) {
          minOrder = rule.order;
        }
      }
      var nextOrder = minOrder - selectedRules.length;
      final updatedRules = selectedRules.map((rule) {
        nextOrder += 1;
        return rule.copyWith(order: nextOrder);
      }).toList(growable: false);
      await _repo.addRules(updatedRules);
    } catch (error, stackTrace) {
      _recordViewError(
        node: 'replace_rule.top_selection',
        message: '批量置顶替换规则失败',
        error: error,
        stackTrace: stackTrace,
        context: <String, dynamic>{
          'count': selectedRules.length,
        },
      );
    } finally {
      if (!mounted) return;
      setState(() => _toppingSelection = false);
    }
  }

  Future<void> _bottomSelectedRules(List<ReplaceRule> visibleRules) async {
    if (_bottomingSelection) return;
    final selectedRules = _selectedRulesByCurrentOrder(visibleRules);
    if (selectedRules.isEmpty) return;
    setState(() => _bottomingSelection = true);
    try {
      final allRules = _repo.getAllRules();
      if (allRules.isEmpty) return;
      var maxOrder = allRules.first.order;
      for (final rule in allRules.skip(1)) {
        if (rule.order > maxOrder) {
          maxOrder = rule.order;
        }
      }
      final updatedRules = selectedRules.map((rule) {
        final currentOrder = maxOrder;
        maxOrder += 1;
        return rule.copyWith(order: currentOrder);
      }).toList(growable: false);
      await _repo.addRules(updatedRules);
    } catch (error, stackTrace) {
      _recordViewError(
        node: 'replace_rule.bottom_selection',
        message: '批量置底替换规则失败',
        error: error,
        stackTrace: stackTrace,
        context: <String, dynamic>{
          'count': selectedRules.length,
        },
      );
    } finally {
      if (!mounted) return;
      setState(() => _bottomingSelection = false);
    }
  }

  Future<void> _importFromFile() async {
    if (_importingLocal) return;
    setState(() => _importingLocal = true);
    try {
      final localText = await _pickLocalImportText();
      if (localText == null) {
        return;
      }
      await _importRulesFromInput(localText);
    } catch (error, stackTrace) {
      _recordViewError(
        node: 'replace_rule.import_local',
        message: '本地导入替换规则失败',
        error: error,
        stackTrace: stackTrace,
      );
      if (!mounted) return;
      await _showMessageDialog(
        title: '导入替换规则',
        message: _formatImportError(error),
      );
    } finally {
      if (mounted) {
        setState(() => _importingLocal = false);
      }
    }
  }

  Future<void> _importFromUrl() async {
    if (_importingOnline) return;
    setState(() => _importingOnline = true);
    try {
      final rawInput = await _showOnlineImportInputSheet();
      final normalizedInput = _sanitizeImportInput(rawInput ?? '');
      if (normalizedInput.isEmpty) {
        return;
      }
      if (_isHttpUrl(normalizedInput)) {
        await _pushOnlineImportHistory(normalizedInput);
      }
      await _importRulesFromInput(normalizedInput);
    } catch (error, stackTrace) {
      _recordViewError(
        node: 'replace_rule.import_online',
        message: '网络导入替换规则失败',
        error: error,
        stackTrace: stackTrace,
      );
      if (!mounted) return;
      await _showMessageDialog(
        title: '导入替换规则',
        message: _formatImportError(error),
      );
    } finally {
      if (mounted) {
        setState(() => _importingOnline = false);
      }
    }
  }

  Future<void> _importFromQr() async {
    if (_importingQr) return;
    setState(() => _importingQr = true);
    try {
      final text = await QrScanService.scanText(
        context,
        title: '二维码导入',
      );
      final normalizedInput = _sanitizeImportInput(text ?? '');
      if (normalizedInput.isEmpty) {
        return;
      }
      await _importRulesFromInput(normalizedInput);
    } catch (error, stackTrace) {
      _recordViewError(
        node: 'replace_rule.import_qr',
        message: '二维码导入替换规则失败',
        error: error,
        stackTrace: stackTrace,
      );
      if (!mounted) return;
      await _showMessageDialog(
        title: '导入替换规则',
        message: _formatImportError(error),
      );
    } finally {
      if (mounted) {
        setState(() => _importingQr = false);
      }
    }
  }

  Future<void> _importRulesFromInput(String rawInput) async {
    final importedRules = await _parseImportRulesFromInput(rawInput, depth: 0);
    final candidates = _buildImportCandidates(importedRules);
    if (candidates.isEmpty) {
      await _showMessageDialog(
        title: '导入替换规则',
        message: 'ImportError:格式不对',
      );
      return;
    }
    if (!mounted) return;
    final selectionDecision = await _showImportSelectionSheet(candidates);
    if (selectionDecision == null ||
        selectionDecision.selectedIndexes.isEmpty) {
      return;
    }
    if (!mounted) return;
    await _runImportingTask(() async {
      final selectedRules = <ReplaceRule>[];
      final sortedIndexes = selectionDecision.selectedIndexes.toList()..sort();
      for (final index in sortedIndexes) {
        if (index < 0 || index >= candidates.length) {
          continue;
        }
        selectedRules.add(
          _applyImportGroupPolicy(
            rule: candidates[index].rule,
            policy: selectionDecision.groupPolicy,
          ),
        );
      }
      await _repo.addRules(selectedRules);
    });
  }

  Future<List<ReplaceRule>> _parseImportRulesFromInput(
    String input, {
    required int depth,
  }) async {
    if (depth > _maxImportDepth) {
      throw const FormatException('导入链接重定向层级过深');
    }
    final text = _sanitizeImportInput(input);
    if (text.isEmpty) {
      throw const FormatException('格式不对');
    }
    if (_looksLikeJson(text)) {
      final parsed = _io.importFromJson(text);
      if (parsed.success && parsed.rules.isNotEmpty) {
        return parsed.rules;
      }
      final detail = parsed.errorMessage?.trim();
      throw FormatException(
        detail == null || detail.isEmpty ? '格式不对' : detail,
      );
    }
    final parsedUri = Uri.tryParse(text);
    if (parsedUri != null) {
      final scheme = parsedUri.scheme.toLowerCase();
      if (scheme == 'http' || scheme == 'https') {
        final remoteText = await _loadTextFromUrl(text);
        return _parseImportRulesFromInput(remoteText, depth: depth + 1);
      }
      if (scheme == 'file') {
        final localText = await File.fromUri(parsedUri).readAsString();
        return _parseImportRulesFromInput(localText, depth: depth + 1);
      }
    }
    final localFile = File(text);
    if (await localFile.exists()) {
      final localText = await localFile.readAsString();
      return _parseImportRulesFromInput(localText, depth: depth + 1);
    }
    throw const FormatException('格式不对');
  }

  Future<String> _loadTextFromUrl(String rawUrl) async {
    var requestUrl = rawUrl.trim();
    var requestWithoutUa = false;
    if (requestUrl.endsWith(_requestWithoutUaSuffix)) {
      requestWithoutUa = true;
      requestUrl = requestUrl.substring(
        0,
        requestUrl.length - _requestWithoutUaSuffix.length,
      );
    }
    final uri = Uri.parse(requestUrl);
    final httpClient = HttpClient();
    try {
      final request = await httpClient.getUrl(uri);
      if (requestWithoutUa) {
        request.headers.set(HttpHeaders.userAgentHeader, 'null');
      }
      final response = await request.close();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException('HTTP ${response.statusCode}', uri: uri);
      }
      final text = await response.transform(utf8.decoder).join();
      if (_sanitizeImportInput(text).isEmpty) {
        throw const FormatException('格式不对');
      }
      return text;
    } finally {
      httpClient.close(force: true);
    }
  }

  Future<String?> _showOnlineImportInputSheet() async {
    final history = await _loadOnlineImportHistory();
    final inputController = TextEditingController();
    try {
      return showCupertinoBottomSheetDialog<String>(
        context: context,
        builder: (popupContext) {
          return CupertinoPopupSurface(
            isSurfacePainted: true,
            child: SizedBox(
              height: math.min(MediaQuery.of(context).size.height * 0.72, 560),
              child: StatefulBuilder(
                builder: (context, setDialogState) {
                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 12, 8),
                        child: Row(
                          children: [
                            const Expanded(
                              child: Text(
                                '网络导入',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            CupertinoButton(
                              padding: EdgeInsets.zero,
                              onPressed: () => Navigator.pop(popupContext),
                              child: const Text('取消'),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: CupertinoTextField(
                                controller: inputController,
                                placeholder: 'url',
                              ),
                            ),
                            const SizedBox(width: 8),
                            CupertinoButton.filled(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              onPressed: () {
                                Navigator.pop(
                                  popupContext,
                                  inputController.text.trim(),
                                );
                              },
                              child: const Text('导入'),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Row(
                          children: [
                            const Expanded(
                              child: Text(
                                '历史记录',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      Expanded(
                        child: history.isEmpty
                            ? const AppEmptyState(
                                illustration:
                                    AppEmptyPlanetIllustration(size: 76),
                                title: '暂无历史记录',
                                message: '输入 URL 并导入后会自动保存',
                              )
                            : ListView.separated(
                                padding:
                                    const EdgeInsets.fromLTRB(12, 0, 12, 12),
                                itemCount: history.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 6),
                                itemBuilder: (context, index) {
                                  final item = history[index];
                                  return AppCard(
                                    backgroundColor: CupertinoColors.systemGrey6
                                        .resolveFrom(context),
                                    padding:
                                        const EdgeInsets.fromLTRB(10, 8, 8, 8),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: GestureDetector(
                                            onTap: () {
                                              inputController.text = item;
                                            },
                                            child: Text(
                                              item,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style:
                                                  const TextStyle(fontSize: 13),
                                            ),
                                          ),
                                        ),
                                        CupertinoButton(
                                          padding: EdgeInsets.zero,
                                          minimumSize: const Size(28, 28),
                                          onPressed: () async {
                                            history.removeAt(index);
                                            await _saveOnlineImportHistory(
                                              history,
                                            );
                                            if (mounted) {
                                              setDialogState(() {});
                                            }
                                          },
                                          child: Icon(
                                            CupertinoIcons.delete,
                                            size: 18,
                                            color: CupertinoColors.systemRed
                                                .resolveFrom(context),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  );
                },
              ),
            ),
          );
        },
      );
    } finally {
      inputController.dispose();
    }
  }

  bool _isHttpUrl(String value) {
    final parsed = Uri.tryParse(value);
    if (parsed == null) return false;
    final scheme = parsed.scheme.toLowerCase();
    return scheme == 'http' || scheme == 'https';
  }

  Future<List<String>> _loadOnlineImportHistory() async {
    return _onlineImportHistoryStore.load(_onlineImportHistoryKey);
  }

  Future<void> _saveOnlineImportHistory(List<String> history) async {
    await _onlineImportHistoryStore.save(_onlineImportHistoryKey, history);
  }

  Future<void> _pushOnlineImportHistory(String url) async {
    await _onlineImportHistoryStore.push(_onlineImportHistoryKey, url);
  }

  bool _looksLikeJson(String value) {
    return value.startsWith('{') || value.startsWith('[');
  }

  Future<void> _showExportPathDialog(String outputPath) async {
    final path = outputPath.trim();
    if (path.isEmpty || !mounted) return;
    final uri = Uri.tryParse(path);
    final isHttpPath = uri != null &&
        (uri.scheme.toLowerCase() == 'http' ||
            uri.scheme.toLowerCase() == 'https');
    final lines = <String>[
      '导出路径：',
      path,
      if (isHttpPath) '',
      if (isHttpPath) '检测到网络链接，可直接复制后分享。',
    ];
    await showCupertinoBottomDialog<void>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: const Text('导出成功'),
        content: Text('\n${lines.join('\n')}'),
        actions: [
          CupertinoDialogAction(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: path));
              if (!dialogContext.mounted) return;
              Navigator.pop(dialogContext);
            },
            child: const Text('复制路径'),
          ),
        ],
      ),
    );
  }

  void _showMessage(String message) {
    showCupertinoBottomDialog<void>(
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

  Future<void> _showReplaceRuleHelp() async {
    try {
      final markdownText =
          await rootBundle.loadString('assets/web/help/md/replaceRuleHelp.md');
      if (!mounted) return;
      await showAppHelpDialog(context, markdownText: markdownText);
    } catch (error) {
      if (!mounted) return;
      _showMessage('帮助文档加载失败：$error');
    }
  }

  List<_ReplaceRuleImportCandidate> _buildImportCandidates(
    List<ReplaceRule> importedRules,
  ) {
    final localById = <int, ReplaceRule>{
      for (final rule in _repo.getAllRules()) rule.id: rule,
    };
    return importedRules.map((rule) {
      final localRule = localById[rule.id];
      return _ReplaceRuleImportCandidate(
        rule: rule,
        localRule: localRule,
        state: _resolveCandidateState(
          importedRule: rule,
          localRule: localRule,
        ),
      );
    }).toList(growable: false);
  }

  _ReplaceRuleImportCandidateState _resolveCandidateState({
    required ReplaceRule importedRule,
    required ReplaceRule? localRule,
  }) {
    if (localRule == null) {
      return _ReplaceRuleImportCandidateState.newRule;
    }
    if (importedRule.pattern != localRule.pattern ||
        importedRule.replacement != localRule.replacement ||
        importedRule.isRegex != localRule.isRegex ||
        importedRule.scope != localRule.scope) {
      return _ReplaceRuleImportCandidateState.update;
    }
    return _ReplaceRuleImportCandidateState.existing;
  }

  Future<_ReplaceRuleImportSelectionDecision?> _showImportSelectionSheet(
    List<_ReplaceRuleImportCandidate> candidates,
  ) async {
    final selectedIndexes = <int>{
      for (var index = 0; index < candidates.length; index++)
        if (candidates[index].selectedByDefault) index,
    };
    var customGroupName = '';
    var appendCustomGroup = false;
    return showCupertinoBottomSheetDialog<_ReplaceRuleImportSelectionDecision>(
      context: context,
      builder: (popupContext) {
        return CupertinoPopupSurface(
          isSurfacePainted: true,
          child: StatefulBuilder(
            builder: (context, setDialogState) {
              final selectedCount = selectedIndexes.length;
              final totalCount = candidates.length;
              final allSelected = totalCount > 0 && selectedCount == totalCount;
              final toggleAllLabel = allSelected
                  ? '取消全选（$selectedCount/$totalCount）'
                  : '全选（$selectedCount/$totalCount）';
              return SizedBox(
                height: math.min(
                  MediaQuery.of(context).size.height * 0.86,
                  680,
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 10, 8, 8),
                      child: Row(
                        children: [
                          const Expanded(
                            child: Text(
                              '导入替换规则',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          CupertinoButton(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            onPressed: () => Navigator.pop(popupContext),
                            child: const Text('取消'),
                          ),
                          CupertinoButton.filled(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            onPressed: selectedCount == 0
                                ? null
                                : () => Navigator.pop(
                                      popupContext,
                                      _ReplaceRuleImportSelectionDecision(
                                        selectedIndexes:
                                            selectedIndexes.toSet(),
                                        groupPolicy:
                                            _ReplaceRuleImportGroupPolicy(
                                          groupName: customGroupName,
                                          appendGroup: appendCustomGroup,
                                        ),
                                      ),
                                    ),
                            child: Text('导入($selectedCount)'),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          CupertinoButton(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            color: CupertinoColors.systemGrey5.resolveFrom(
                              context,
                            ),
                            onPressed: () {
                              setDialogState(() {
                                if (allSelected) {
                                  selectedIndexes.clear();
                                } else {
                                  selectedIndexes
                                    ..clear()
                                    ..addAll(
                                      List<int>.generate(
                                        candidates.length,
                                        (index) => index,
                                      ),
                                    );
                                }
                              });
                            },
                            child: Text(toggleAllLabel),
                          ),
                          CupertinoButton(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            color: CupertinoColors.systemGrey5.resolveFrom(
                              context,
                            ),
                            onPressed: () async {
                              final input = await _showImportCustomGroupDialog(
                                initialGroupName: customGroupName,
                                initialAppendGroup: appendCustomGroup,
                              );
                              if (input == null || !popupContext.mounted) {
                                return;
                              }
                              setDialogState(() {
                                customGroupName = input.groupName;
                                appendCustomGroup = input.appendGroup;
                              });
                            },
                            child: Text(
                              _buildImportGroupActionLabel(
                                groupName: customGroupName,
                                appendGroup: appendCustomGroup,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                        itemCount: candidates.length,
                        separatorBuilder: (context, _) =>
                            const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final candidate = candidates[index];
                          final selected = selectedIndexes.contains(index);
                          return _ReplaceRuleImportCandidateTile(
                            candidate: candidate,
                            selected: selected,
                            onTap: () {
                              setDialogState(() {
                                if (selected) {
                                  selectedIndexes.remove(index);
                                } else {
                                  selectedIndexes.add(index);
                                }
                              });
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  ReplaceRule _applyImportGroupPolicy({
    required ReplaceRule rule,
    required _ReplaceRuleImportGroupPolicy policy,
  }) {
    final groupName = policy.groupName.trim();
    if (groupName.isEmpty) {
      return rule;
    }
    if (!policy.appendGroup) {
      return rule.copyWith(group: groupName);
    }
    final groups = <String>{};
    final rawGroup = rule.group;
    if (rawGroup != null && rawGroup.isNotEmpty) {
      for (final part in rawGroup.split(_groupSplitPattern)) {
        final normalized = part.trim();
        if (normalized.isEmpty) continue;
        groups.add(normalized);
      }
    }
    groups.add(groupName);
    return rule.copyWith(group: groups.join(','));
  }

  String _buildImportGroupActionLabel({
    required String groupName,
    required bool appendGroup,
  }) {
    final normalized = groupName.trim();
    if (normalized.isEmpty) {
      return '自定义源分组';
    }
    final title = '【$normalized】';
    if (appendGroup) {
      return '+$title';
    }
    return title;
  }

  Future<_ReplaceRuleImportGroupInput?> _showImportCustomGroupDialog({
    required String initialGroupName,
    required bool initialAppendGroup,
  }) async {
    final controller = TextEditingController(text: initialGroupName.trim());
    var appendGroup = initialAppendGroup;
    try {
      return showCupertinoBottomDialog<_ReplaceRuleImportGroupInput>(
        context: context,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              return CupertinoAlertDialog(
                title: const Text('输入自定义源分组名称'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 12),
                    CupertinoTextField(
                      controller: controller,
                      placeholder: '分组名',
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            '追加分组',
                            style: TextStyle(fontSize: 14),
                          ),
                        ),
                        CupertinoSwitch(
                          value: appendGroup,
                          onChanged: (value) {
                            setDialogState(() => appendGroup = value);
                          },
                        ),
                      ],
                    ),
                  ],
                ),
                actions: [
                  CupertinoDialogAction(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    child: const Text('取消'),
                  ),
                  CupertinoDialogAction(
                    onPressed: () {
                      Navigator.of(dialogContext).pop(
                        _ReplaceRuleImportGroupInput(
                          groupName: controller.text.trim(),
                          appendGroup: appendGroup,
                        ),
                      );
                    },
                    child: const Text('确定'),
                  ),
                ],
              );
            },
          );
        },
      );
    } finally {
      controller.dispose();
    }
  }

  Future<void> _runImportingTask(Future<void> Function() task) async {
    final navigator = Navigator.of(context, rootNavigator: true);
    showCupertinoBottomDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => const CupertinoAlertDialog(
        content: _BlockingProgressContent(text: '导入中...'),
      ),
    );
    await Future<void>.delayed(Duration.zero);
    try {
      await task();
    } finally {
      if (navigator.canPop()) {
        navigator.pop();
      }
    }
  }

  Future<String?> _pickLocalImportText() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['txt', 'json'],
      allowMultiple: false,
      withData: true,
    );
    if (result == null || result.files.isEmpty) {
      return null;
    }
    final file = result.files.first;
    if (file.bytes != null) {
      return utf8.decode(file.bytes!, allowMalformed: true);
    }
    final path = file.path;
    if (path != null && path.trim().isNotEmpty) {
      return File(path).readAsString();
    }
    throw const FileSystemException('无法读取文件内容');
  }

  String _sanitizeImportInput(String input) {
    var value = input.trim();
    if (value.startsWith('\uFEFF')) {
      value = value.replaceFirst(RegExp(r'^\uFEFF+'), '');
    }
    return value.trim();
  }

  String _formatImportError(Object error) {
    if (error is FileSystemException) {
      final message = error.message.trim();
      if (message.isEmpty) return 'readTextError:ERROR';
      return 'readTextError:$message';
    }
    if (error is FormatException) {
      final message = error.message.trim();
      if (message.isEmpty) return 'ImportError:格式不对';
      return 'ImportError:$message';
    }
    final text = '$error'.trim();
    if (text.isEmpty) return 'ImportError:ERROR';
    if (text.startsWith('Exception:')) {
      final stripped = text.substring('Exception:'.length).trim();
      return stripped.isEmpty ? 'ImportError:ERROR' : 'ImportError:$stripped';
    }
    return 'ImportError:$text';
  }

  Future<void> _showMessageDialog({
    required String title,
    required String message,
  }) async {
    if (!mounted) return;
    await showCupertinoBottomDialog<void>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }
}

enum _ReplaceRuleImportCandidateState {
  newRule,
  update,
  existing,
}

class _ReplaceRuleImportSelectionDecision {
  const _ReplaceRuleImportSelectionDecision({
    required this.selectedIndexes,
    required this.groupPolicy,
  });

  final Set<int> selectedIndexes;
  final _ReplaceRuleImportGroupPolicy groupPolicy;
}

class _ReplaceRuleImportGroupPolicy {
  const _ReplaceRuleImportGroupPolicy({
    required this.groupName,
    required this.appendGroup,
  });

  final String groupName;
  final bool appendGroup;
}

class _ReplaceRuleImportGroupInput {
  const _ReplaceRuleImportGroupInput({
    required this.groupName,
    required this.appendGroup,
  });

  final String groupName;
  final bool appendGroup;
}

enum _ReplaceRuleItemMenuAction {
  top,
  bottom,
  delete,
}

enum _ReplaceRuleSelectionMenuAction {
  enableSelection,
  disableSelection,
  topSelection,
  bottomSelection,
  exportSelection,
}

class _ReplaceRuleImportCandidate {
  const _ReplaceRuleImportCandidate({
    required this.rule,
    required this.localRule,
    required this.state,
  });

  final ReplaceRule rule;
  final ReplaceRule? localRule;
  final _ReplaceRuleImportCandidateState state;

  bool get selectedByDefault =>
      state == _ReplaceRuleImportCandidateState.newRule;
}

class _ReplaceRuleImportCandidateTile extends StatelessWidget {
  const _ReplaceRuleImportCandidateTile({
    required this.candidate,
    required this.selected,
    required this.onTap,
  });

  final _ReplaceRuleImportCandidate candidate;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final stateLabel = _stateLabel(candidate.state);
    final stateColor = _stateColor(context, candidate.state);
    final title = candidate.rule.name.trim().isEmpty
        ? '未命名规则'
        : candidate.rule.name.trim();
    final group = candidate.rule.group?.trim();
    final subtitle = group == null || group.isEmpty ? '未分组' : '分组：$group';
    final backgroundColor = selected
        ? CupertinoColors.systemGrey5.resolveFrom(context)
        : CupertinoColors.systemBackground.resolveFrom(context);
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onTap,
      child: AppCard(
        backgroundColor: backgroundColor,
        borderColor: CupertinoColors.separator.resolveFrom(context),
        borderWidth: 0.5,
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Row(
          children: [
            Icon(
              selected
                  ? CupertinoIcons.check_mark_circled_solid
                  : CupertinoIcons.circle,
              color: selected
                  ? CupertinoColors.activeBlue.resolveFrom(context)
                  : CupertinoColors.secondaryLabel.resolveFrom(context),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: CupertinoColors.secondaryLabel.resolveFrom(
                        context,
                      ),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            DecoratedBox(
              decoration: BoxDecoration(
                color: stateColor.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 2,
                ),
                child: Text(
                  stateLabel,
                  style: TextStyle(
                    color: stateColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _stateLabel(_ReplaceRuleImportCandidateState state) {
    return switch (state) {
      _ReplaceRuleImportCandidateState.newRule => '新增',
      _ReplaceRuleImportCandidateState.update => '更新',
      _ReplaceRuleImportCandidateState.existing => '已有',
    };
  }

  static Color _stateColor(
    BuildContext context,
    _ReplaceRuleImportCandidateState state,
  ) {
    return switch (state) {
      _ReplaceRuleImportCandidateState.newRule =>
        CupertinoColors.systemGreen.resolveFrom(context),
      _ReplaceRuleImportCandidateState.update =>
        CupertinoColors.systemOrange.resolveFrom(context),
      _ReplaceRuleImportCandidateState.existing =>
        CupertinoColors.secondaryLabel.resolveFrom(context),
    };
  }
}

class _BlockingProgressContent extends StatelessWidget {
  const _BlockingProgressContent({
    required this.text,
  });

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CupertinoActivityIndicator(),
          const SizedBox(height: 10),
          Text(text),
        ],
      ),
    );
  }
}
