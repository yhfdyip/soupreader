import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../../app/widgets/app_toast.dart';
import '../../../app/widgets/app_action_list_sheet.dart';
import '../../../app/widgets/app_cupertino_page_scaffold.dart';
import '../../../app/widgets/app_empty_state.dart';
import '../../../app/widgets/app_manage_search_field.dart';
import '../../../app/widgets/app_nav_bar_button.dart';
import '../../../app/widgets/app_popover_menu.dart';
import '../../../app/widgets/app_ui_kit.dart';
import '../../../app/widgets/cupertino_bottom_dialog.dart';
import '../../../core/database/database_service.dart';
import '../../../core/database/repositories/rss_source_repository.dart';
import '../../../core/services/exception_log_service.dart';
import '../../../core/services/online_import_history_store.dart';
import '../../../core/services/source_variable_store.dart';
import '../../../core/utils/legado_json.dart';
import '../../../core/services/qr_scan_service.dart';
import '../models/rss_source.dart';
import '../services/rss_source_import_commit_service.dart';
import '../services/rss_source_import_export_service.dart';
import '../services/rss_source_import_selection_helper.dart';
import '../services/rss_source_manage_helper.dart';
import 'rss_group_manage_view.dart';
import 'rss_subscription_view.dart';
import 'rss_source_edit_view.dart';

class _RssImportSelectionDecision {
  const _RssImportSelectionDecision({
    required this.candidates,
    required this.policy,
  });

  final List<RssSourceImportCandidate> candidates;
  final RssSourceImportSelectionPolicy policy;
}

enum _RssSourceMainMenuAction {
  create,
  importFile,
  importUrl,
  importQr,
  importDefault,
}

enum _RssSourceSelectionAction {
  enableSelection,
  disableSelection,
  addGroup,
  removeGroup,
  moveToTop,
  moveToBottom,
  exportSelection,
  shareSelection,
  checkSelectedInterval,
}

enum _RssSourceItemAction {
  moveToTop,
  moveToBottom,
  delete,
}

typedef _RssGroupMenuDecision = ({bool openManage, String? query});

class RssSourceManageView extends StatefulWidget {
  const RssSourceManageView({
    super.key,
    this.repository,
  });

  final RssSourceRepository? repository;

  @override
  State<RssSourceManageView> createState() => _RssSourceManageViewState();
}

class _RssSourceManageViewState extends State<RssSourceManageView> {
  static const String _onlineImportHistoryKey = 'rssSourceRecordKey';
  late final RssSourceRepository _repo;
  late final RssSourceImportExportService _importExportService;
  late final RssSourceImportCommitService _importCommitService;
  final TextEditingController _queryController = TextEditingController();
  final GlobalKey _groupMenuKey = GlobalKey();
  final GlobalKey _mainMenuKey = GlobalKey();
  final Set<String> _selectedSourceUrls = <String>{};
  final OnlineImportHistoryStore _onlineImportHistoryStore =
      OnlineImportHistoryStore();

  @override
  void initState() {
    super.initState();
    _repo = widget.repository ?? RssSourceRepository(DatabaseService());
    _importExportService = RssSourceImportExportService();
    _importCommitService = RssSourceImportCommitService(
      upsertSourceRawJson: _repo.upsertSourceRawJson,
      loadAllSources: _repo.getAllSources,
      loadRawJsonByUrl: _repo.getRawJsonByUrl,
    );
  }

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  String get _query => _queryController.text.trim();

  @override
  Widget build(BuildContext context) {
    return AppCupertinoPageScaffold(
      title: '订阅源管理',
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppNavBarButton(
            onPressed: _openSubscriptions,
            child: const Icon(CupertinoIcons.dot_radiowaves_left_right),
          ),
          AppNavBarButton(
            key: _groupMenuKey,
            onPressed: _openGroupMenuSheet,
            child: const Icon(CupertinoIcons.folder),
          ),
          AppNavBarButton(
            key: _mainMenuKey,
            onPressed: _openMainOptions,
            child: const Icon(CupertinoIcons.ellipsis_circle),
          ),
        ],
      ),
      child: StreamBuilder<List<RssSource>>(
        stream: _repo.watchAllSources(),
        builder: (context, snapshot) {
          final allSources = snapshot.data ?? _repo.getAllSources();
          _cleanupSelection(allSources);
          final intent = RssSourceManageHelper.parseQueryIntent(_query);
          final visible = RssSourceManageHelper.applyQueryIntent(
            allSources,
            intent,
          );

          return Column(
            children: [
              Padding(
                padding: AppManageSearchField.outerPadding,
                child: AppManageSearchField(
                  controller: _queryController,
                  placeholder: '搜索订阅源',
                  onChanged: (_) => setState(() {}),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _query.isEmpty ? '全部源' : '筛选：${intent.rawQuery}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: CupertinoColors.secondaryLabel.resolveFrom(context)
                              .resolveFrom(context),
                          fontSize: 12,
                        ),
                      ),
                    ),
                    Text(
                      '${visible.length} 条',
                      style: TextStyle(
                        color:
                            CupertinoColors.secondaryLabel.resolveFrom(context),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child:
                    visible.isEmpty ? _buildEmptyState() : _buildList(visible),
              ),
              _buildSelectionActionBar(visibleSources: visible),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    final noData = _repo.size == 0;
    final title = noData ? '暂无订阅源' : '没有匹配结果';
    final action = noData ? '新建订阅源' : '清除筛选';
    final message = noData ? '通过导入或新建来添加第一条订阅源' : '请尝试调整筛选关键字';
    return AppEmptyState(
      illustration: const AppEmptyPlanetIllustration(size: 84),
      title: title,
      message: message,
      action: CupertinoButton(
        onPressed: noData ? _openAddSource : () => _setQuery(''),
        child: Text(action),
      ),
    );
  }

  Widget _buildList(List<RssSource> sources) {
    return AppListView(
      padding: const EdgeInsets.only(top: 4, bottom: 20),
      children: [
        for (var index = 0; index < sources.length; index++) ...[
          Builder(
            builder: (context) {
              final source = sources[index];
              final sourceUrl = source.sourceUrl.trim();
              final selected = _selectedSourceUrls.contains(sourceUrl);
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: AppCard(
                  padding: EdgeInsets.zero,
                  child: CupertinoListTile.notched(
                    leading: CupertinoButton(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(30, 30),
                      onPressed: () => _toggleSelection(sourceUrl),
                      child: Icon(
                        selected
                            ? CupertinoIcons.check_mark_circled_solid
                            : CupertinoIcons.circle,
                        size: 22,
                        color: selected
                            ? CupertinoColors.activeBlue.resolveFrom(context)
                            : CupertinoColors.secondaryLabel.resolveFrom(context)
                                .resolveFrom(context),
                      ),
                    ),
                    title: Text(source.getDisplayNameGroup()),
                    additionalInfo: Text(
                      source.sourceUrl,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CupertinoSwitch(
                          value: source.enabled,
                          onChanged: (value) => _updateEnabled(source, value),
                        ),
                        CupertinoButton(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          minimumSize: const Size(36, 36),
                          onPressed: () => _openEditSource(source),
                          child: Icon(
                            CupertinoIcons.pencil,
                            size: 18,
                            color: CupertinoColors.secondaryLabel.resolveFrom(context)
                                .resolveFrom(context),
                          ),
                        ),
                        CupertinoButton(
                          padding: const EdgeInsets.only(left: 2, right: 2),
                          minimumSize: const Size(36, 36),
                          onPressed: () => _showSourceActions(source),
                          child: Icon(
                            CupertinoIcons.ellipsis_vertical,
                            size: 18,
                            color: CupertinoColors.secondaryLabel.resolveFrom(context)
                                .resolveFrom(context),
                          ),
                        ),
                      ],
                    ),
                    onTap: () => _openEditSource(source),
                  ),
                ),
              );
            },
          ),
          if (index < sources.length - 1) const SizedBox(height: 8),
        ],
      ],
    );
  }

  void _cleanupSelection(List<RssSource> allSources) {
    if (_selectedSourceUrls.isEmpty) return;
    final allUrls = allSources
        .map((source) => source.sourceUrl.trim())
        .where((url) => url.isNotEmpty)
        .toSet();
    _selectedSourceUrls.removeWhere((url) => !allUrls.contains(url));
  }

  void _toggleSelection(String sourceUrl) {
    final normalized = sourceUrl.trim();
    if (normalized.isEmpty) return;
    setState(() {
      if (_selectedSourceUrls.contains(normalized)) {
        _selectedSourceUrls.remove(normalized);
      } else {
        _selectedSourceUrls.add(normalized);
      }
    });
  }

  List<RssSource> _selectedSources(List<RssSource> visibleSources) {
    return visibleSources
        .where(
          (source) => _selectedSourceUrls.contains(source.sourceUrl.trim()),
        )
        .toList(growable: false);
  }

  Widget _buildSelectionActionBar({
    required List<RssSource> visibleSources,
  }) {
    final selectedCount = _selectedSources(visibleSources).length;
    final totalCount = visibleSources.length;
    final allSelected = totalCount > 0 && selectedCount >= totalCount;
    final canOperate = totalCount > 0;
    final color = CupertinoTheme.of(context).primaryColor;
    final disabledColor = CupertinoColors.systemGrey.resolveFrom(context);
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 6, 8, 8),
        decoration: BoxDecoration(
          color: CupertinoColors.systemGroupedBackground.resolveFrom(context),
          border: Border(
            top: BorderSide(
              color: CupertinoColors.systemGrey4.resolveFrom(context),
              width: 0.5,
            ),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: CupertinoButton(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                minimumSize: const Size(30, 30),
                alignment: Alignment.centerLeft,
                onPressed: canOperate
                    ? () => _toggleAllVisibleSelection(
                          visibleSources: visibleSources,
                          allSelected: allSelected,
                        )
                    : null,
                child: Text(
                  allSelected
                      ? '取消全选（$selectedCount/$totalCount）'
                      : '全选（$selectedCount/$totalCount）',
                  style: TextStyle(
                    fontSize: 13,
                    color: canOperate ? color : disabledColor,
                  ),
                ),
              ),
            ),
            CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              minimumSize: const Size(30, 30),
              onPressed: canOperate
                  ? () => _invertVisibleSelection(visibleSources)
                  : null,
              child: Text(
                '反选',
                style: TextStyle(
                  fontSize: 13,
                  color: canOperate ? color : disabledColor,
                ),
              ),
            ),
            CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              minimumSize: const Size(30, 30),
              onPressed: canOperate
                  ? () => _showSelectionMoreActions(visibleSources)
                  : null,
              child: Icon(
                CupertinoIcons.ellipsis_circle,
                size: 19,
                color: canOperate ? color : disabledColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _toggleAllVisibleSelection({
    required List<RssSource> visibleSources,
    required bool allSelected,
  }) {
    setState(() {
      final visibleUrls = visibleSources
          .map((source) => source.sourceUrl.trim())
          .where((url) => url.isNotEmpty)
          .toSet();
      if (allSelected) {
        _selectedSourceUrls.removeAll(visibleUrls);
      } else {
        _selectedSourceUrls.addAll(visibleUrls);
      }
    });
  }

  void _invertVisibleSelection(List<RssSource> visibleSources) {
    setState(() {
      for (final source in visibleSources) {
        final sourceUrl = source.sourceUrl.trim();
        if (sourceUrl.isEmpty) continue;
        if (_selectedSourceUrls.contains(sourceUrl)) {
          _selectedSourceUrls.remove(sourceUrl);
        } else {
          _selectedSourceUrls.add(sourceUrl);
        }
      }
    });
  }

  Future<void> _showSelectionMoreActions(List<RssSource> visibleSources) async {
    if (!mounted) return;
    final selected = await showAppActionListSheet<_RssSourceSelectionAction>(
      context: context,
      title: '批量操作',
      showCancel: true,
      items: const [
        AppActionListItem<_RssSourceSelectionAction>(
          value: _RssSourceSelectionAction.enableSelection,
          icon: CupertinoIcons.check_mark_circled_solid,
          label: '启用所选',
        ),
        AppActionListItem<_RssSourceSelectionAction>(
          value: _RssSourceSelectionAction.disableSelection,
          icon: CupertinoIcons.clear_circled_solid,
          label: '禁用所选',
        ),
        AppActionListItem<_RssSourceSelectionAction>(
          value: _RssSourceSelectionAction.addGroup,
          icon: CupertinoIcons.add_circled_solid,
          label: '添加分组',
        ),
        AppActionListItem<_RssSourceSelectionAction>(
          value: _RssSourceSelectionAction.removeGroup,
          icon: CupertinoIcons.minus_circle,
          label: '移除分组',
        ),
        AppActionListItem<_RssSourceSelectionAction>(
          value: _RssSourceSelectionAction.moveToTop,
          icon: CupertinoIcons.arrow_up_circle,
          label: '置顶所选',
        ),
        AppActionListItem<_RssSourceSelectionAction>(
          value: _RssSourceSelectionAction.moveToBottom,
          icon: CupertinoIcons.arrow_down_circle,
          label: '置底所选',
        ),
        AppActionListItem<_RssSourceSelectionAction>(
          value: _RssSourceSelectionAction.exportSelection,
          icon: CupertinoIcons.square_arrow_up,
          label: '导出所选',
        ),
        AppActionListItem<_RssSourceSelectionAction>(
          value: _RssSourceSelectionAction.shareSelection,
          icon: CupertinoIcons.share,
          label: '分享选中源',
        ),
        AppActionListItem<_RssSourceSelectionAction>(
          value: _RssSourceSelectionAction.checkSelectedInterval,
          icon: CupertinoIcons.scope,
          label: '选中所选区间',
        ),
      ],
    );
    if (selected == null || !mounted) return;
    switch (selected) {
      case _RssSourceSelectionAction.enableSelection:
        await _enableSelection(visibleSources);
        return;
      case _RssSourceSelectionAction.disableSelection:
        await _disableSelection(visibleSources);
        return;
      case _RssSourceSelectionAction.addGroup:
        await _addGroupToSelection(visibleSources);
        return;
      case _RssSourceSelectionAction.removeGroup:
        await _removeGroupFromSelection(visibleSources);
        return;
      case _RssSourceSelectionAction.moveToTop:
        await _moveSelectionToTop(visibleSources);
        return;
      case _RssSourceSelectionAction.moveToBottom:
        await _moveSelectionToBottom(visibleSources);
        return;
      case _RssSourceSelectionAction.exportSelection:
        await _exportSelection(visibleSources);
        return;
      case _RssSourceSelectionAction.shareSelection:
        await _shareSelection(visibleSources);
        return;
      case _RssSourceSelectionAction.checkSelectedInterval:
        _checkSelectedInterval(visibleSources);
        return;
    }
  }

  Future<void> _enableSelection(List<RssSource> visibleSources) async {
    final selected = _selectedSources(visibleSources);
    if (selected.isEmpty) return;
    final selectedUrls = selected
        .map((source) => source.sourceUrl.trim())
        .where((url) => url.isNotEmpty)
        .toSet();
    if (selectedUrls.isEmpty) return;
    final updates = <RssSource>[];
    for (final sourceUrl in selectedUrls) {
      final current = _repo.getByKey(sourceUrl);
      if (current == null) continue;
      updates.add(current.copyWith(enabled: true));
    }
    if (updates.isEmpty) return;
    try {
      await _repo.updateSources(updates);
    } catch (error, stackTrace) {
      ExceptionLogService().record(
        node: 'rss_source_sel.menu_enable_selection',
        message: 'RSS 源管理启用所选失败',
        error: error,
        stackTrace: stackTrace,
        context: <String, dynamic>{
          'selectedCount': selected.length,
          'updateCount': updates.length,
          'sourceUrls':
              updates.map((source) => source.sourceUrl).toList(growable: false),
        },
      );
    }
  }

  Future<void> _disableSelection(List<RssSource> visibleSources) async {
    final selected = _selectedSources(visibleSources);
    if (selected.isEmpty) return;
    final selectedUrls = selected
        .map((source) => source.sourceUrl.trim())
        .where((url) => url.isNotEmpty)
        .toSet();
    if (selectedUrls.isEmpty) return;
    final updates = <RssSource>[];
    for (final sourceUrl in selectedUrls) {
      final current = _repo.getByKey(sourceUrl);
      if (current == null) continue;
      updates.add(current.copyWith(enabled: false));
    }
    if (updates.isEmpty) return;
    try {
      await _repo.updateSources(updates);
    } catch (error, stackTrace) {
      ExceptionLogService().record(
        node: 'rss_source_sel.menu_disable_selection',
        message: 'RSS 源管理禁用所选失败',
        error: error,
        stackTrace: stackTrace,
        context: <String, dynamic>{
          'selectedCount': selected.length,
          'updateCount': updates.length,
          'sourceUrls':
              updates.map((source) => source.sourceUrl).toList(growable: false),
        },
      );
    }
  }

  Future<void> _addGroupToSelection(List<RssSource> visibleSources) async {
    final groupInput = await _showSelectionGroupInputDialog(title: '添加分组');
    if (groupInput == null || groupInput.isEmpty) return;
    final selected = _selectedSources(visibleSources);
    if (selected.isEmpty) return;
    final selectedUrls = selected
        .map((source) => source.sourceUrl.trim())
        .where((url) => url.isNotEmpty)
        .toSet();
    if (selectedUrls.isEmpty) return;
    final updates = <RssSource>[];
    for (final sourceUrl in selectedUrls) {
      final current = _repo.getByKey(sourceUrl);
      if (current == null) continue;
      updates.add(current.addGroup(groupInput));
    }
    if (updates.isEmpty) return;
    try {
      await _repo.updateSources(updates);
    } catch (error, stackTrace) {
      ExceptionLogService().record(
        node: 'rss_source_sel.menu_add_group',
        message: 'RSS 源管理添加分组失败',
        error: error,
        stackTrace: stackTrace,
        context: <String, dynamic>{
          'selectedCount': selected.length,
          'updateCount': updates.length,
          'groupInput': groupInput,
          'sourceUrls':
              updates.map((source) => source.sourceUrl).toList(growable: false),
        },
      );
    }
  }

  Future<void> _removeGroupFromSelection(List<RssSource> visibleSources) async {
    final groupInput = await _showSelectionGroupInputDialog(title: '移除分组');
    if (groupInput == null || groupInput.isEmpty) return;
    final selected = _selectedSources(visibleSources);
    if (selected.isEmpty) return;
    final selectedUrls = selected
        .map((source) => source.sourceUrl.trim())
        .where((url) => url.isNotEmpty)
        .toSet();
    if (selectedUrls.isEmpty) return;
    final updates = <RssSource>[];
    for (final sourceUrl in selectedUrls) {
      final current = _repo.getByKey(sourceUrl);
      if (current == null) continue;
      updates.add(current.removeGroup(groupInput));
    }
    if (updates.isEmpty) return;
    try {
      await _repo.updateSources(updates);
    } catch (error, stackTrace) {
      ExceptionLogService().record(
        node: 'rss_source_sel.menu_remove_group',
        message: 'RSS 源管理移除分组失败',
        error: error,
        stackTrace: stackTrace,
        context: <String, dynamic>{
          'selectedCount': selected.length,
          'updateCount': updates.length,
          'groupInput': groupInput,
          'sourceUrls':
              updates.map((source) => source.sourceUrl).toList(growable: false),
        },
      );
    }
  }

  Future<void> _moveSelectionToTop(List<RssSource> visibleSources) async {
    final selected = _selectedSources(visibleSources);
    if (selected.isEmpty) return;
    final selectedUrls = selected
        .map((source) => source.sourceUrl.trim())
        .where((url) => url.isNotEmpty)
        .toSet();
    if (selectedUrls.isEmpty) return;
    final currentSelection = <RssSource>[];
    for (final sourceUrl in selectedUrls) {
      final current = _repo.getByKey(sourceUrl);
      if (current == null) continue;
      currentSelection.add(current);
    }
    if (currentSelection.isEmpty) return;
    final sortedSelection = currentSelection.toList(growable: false)
      ..sort((left, right) => left.customOrder.compareTo(right.customOrder));
    final minOrder = _repo.minOrder - 1;
    final updates = sortedSelection
        .asMap()
        .entries
        .map(
          (entry) => entry.value.copyWith(
            customOrder: minOrder - entry.key,
          ),
        )
        .toList(growable: false);
    try {
      await _repo.updateSources(updates);
    } catch (error, stackTrace) {
      ExceptionLogService().record(
        node: 'rss_source_sel.menu_top_sel',
        message: 'RSS 源管理置顶所选失败',
        error: error,
        stackTrace: stackTrace,
        context: <String, dynamic>{
          'selectedCount': selected.length,
          'updateCount': updates.length,
          'minOrderBase': minOrder,
          'sourceUrls':
              updates.map((source) => source.sourceUrl).toList(growable: false),
        },
      );
    }
  }

  Future<void> _moveSelectionToBottom(List<RssSource> visibleSources) async {
    final selected = _selectedSources(visibleSources);
    if (selected.isEmpty) return;
    final selectedUrls = selected
        .map((source) => source.sourceUrl.trim())
        .where((url) => url.isNotEmpty)
        .toSet();
    if (selectedUrls.isEmpty) return;
    final currentSelection = <RssSource>[];
    for (final sourceUrl in selectedUrls) {
      final current = _repo.getByKey(sourceUrl);
      if (current == null) continue;
      currentSelection.add(current);
    }
    if (currentSelection.isEmpty) return;
    final sortedSelection = currentSelection.toList(growable: false)
      ..sort((left, right) => left.customOrder.compareTo(right.customOrder));
    final maxOrder = _repo.maxOrder + 1;
    final updates = sortedSelection
        .asMap()
        .entries
        .map(
          (entry) => entry.value.copyWith(
            customOrder: maxOrder + entry.key,
          ),
        )
        .toList(growable: false);
    try {
      await _repo.updateSources(updates);
    } catch (error, stackTrace) {
      ExceptionLogService().record(
        node: 'rss_source_sel.menu_bottom_sel',
        message: 'RSS 源管理置底所选失败',
        error: error,
        stackTrace: stackTrace,
        context: <String, dynamic>{
          'selectedCount': selected.length,
          'updateCount': updates.length,
          'maxOrderBase': maxOrder,
          'sourceUrls':
              updates.map((source) => source.sourceUrl).toList(growable: false),
        },
      );
    }
  }

  Future<void> _exportSelection(List<RssSource> visibleSources) async {
    final selected = _selectedSources(visibleSources);
    final result = await _importExportService.exportToFile(
      selected,
      defaultFileName: 'exportRssSource.json',
    );
    if (result.cancelled) {
      return;
    }
    if (!result.success) {
      await _showMessage(result.errorMessage ?? '导出失败');
      return;
    }
    final path = (result.outputPath ?? '').trim();
    if (path.isEmpty) {
      unawaited(showAppToast(context, message: '导出成功'));
      return;
    }
    await _showExportPathDialog(path);
  }

  Future<void> _shareSelection(List<RssSource> visibleSources) async {
    final selected = _selectedSources(visibleSources);
    try {
      final file = await _importExportService.exportToShareFile(selected);
      if (file == null) return;
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'text/*')],
        ),
      );
    } catch (_) {
      // 对齐 legado Context.share(file)：分享异常不追加提示。
    }
  }

  void _checkSelectedInterval(List<RssSource> visibleSources) {
    if (_selectedSourceUrls.isEmpty || visibleSources.isEmpty) {
      return;
    }

    int? minIndex;
    int? maxIndex;
    for (var index = 0; index < visibleSources.length; index++) {
      final sourceUrl = visibleSources[index].sourceUrl.trim();
      if (sourceUrl.isEmpty || !_selectedSourceUrls.contains(sourceUrl)) {
        continue;
      }
      minIndex = minIndex == null || index < minIndex ? index : minIndex;
      maxIndex = maxIndex == null || index > maxIndex ? index : maxIndex;
    }
    if (minIndex == null || maxIndex == null) {
      return;
    }

    final startIndex = minIndex;
    final endIndex = maxIndex;
    setState(() {
      for (var index = startIndex; index <= endIndex; index++) {
        final sourceUrl = visibleSources[index].sourceUrl.trim();
        if (sourceUrl.isEmpty) {
          continue;
        }
        _selectedSourceUrls.add(sourceUrl);
      }
    });
  }

  void _setQuery(String value) {
    _queryController.text = value;
    _queryController.selection = TextSelection.collapsed(offset: value.length);
    setState(() {});
  }

  Future<String?> _showSelectionGroupInputDialog(
      {required String title}) async {
    if (!mounted) return null;
    final allGroups = _repo.allGroups();
    final controller = TextEditingController();
    try {
      return await showCupertinoBottomSheetDialog<String>(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            final query = controller.text.trim().toLowerCase();
            final quickGroups = allGroups
                .where((group) {
                  if (query.isEmpty) return true;
                  return group.toLowerCase().contains(query);
                })
                .take(12)
                .toList(growable: false);
            return CupertinoAlertDialog(
              title: Text(title),
              content: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CupertinoTextField(
                      controller: controller,
                      placeholder: '分组名称',
                      autofocus: true,
                      onChanged: (_) => setDialogState(() {}),
                    ),
                    if (quickGroups.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: SizedBox(
                          width: double.infinity,
                          height: math.min(quickGroups.length * 34.0, 118),
                          child: SingleChildScrollView(
                            child: Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: quickGroups.map((group) {
                                return CupertinoButton(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  minimumSize: const Size(0, 26),
                                  onPressed: () {
                                    controller.value = TextEditingValue(
                                      text: group,
                                      selection: TextSelection.collapsed(
                                        offset: group.length,
                                      ),
                                    );
                                    setDialogState(() {});
                                  },
                                  child: Text(
                                    group,
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                );
                              }).toList(growable: false),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              actions: [
                CupertinoDialogAction(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('取消'),
                ),
                CupertinoDialogAction(
                  onPressed: () =>
                      Navigator.of(dialogContext).pop(controller.text),
                  child: const Text('确定'),
                ),
              ],
            );
          },
        ),
      );
    } finally {
      controller.dispose();
    }
  }

  Future<void> _openAddSource() async {
    if (!mounted) return;
    await Navigator.of(context).push<bool>(
      CupertinoPageRoute<bool>(
        builder: (_) => const RssSourceEditView(),
      ),
    );
  }

  Future<void> _openSubscriptions() async {
    if (!mounted) return;
    await Navigator.of(context).push<void>(
      CupertinoPageRoute<void>(
        builder: (_) => RssSubscriptionView(repository: _repo),
      ),
    );
  }

  Future<void> _openEditSource(RssSource source) async {
    if (!mounted) return;
    await Navigator.of(context).push<bool>(
      CupertinoPageRoute<bool>(
        builder: (_) => RssSourceEditView(sourceUrl: source.sourceUrl),
      ),
    );
  }

  Future<void> _openGroupMenuSheet() async {
    final groups = _repo.allGroups();
    if (!mounted) return;
    final selected = await showAppPopoverMenu<_RssGroupMenuDecision>(
      context: context,
      anchorKey: _groupMenuKey,
      items: [
        const AppPopoverMenuItem(
          value: (openManage: true, query: null),
          icon: CupertinoIcons.gear,
          label: '分组管理',
        ),
        const AppPopoverMenuItem(
          value: (openManage: false, query: '已启用'),
          icon: CupertinoIcons.check_mark,
          label: '已启用',
        ),
        const AppPopoverMenuItem(
          value: (openManage: false, query: '已禁用'),
          icon: CupertinoIcons.xmark,
          label: '已禁用',
        ),
        const AppPopoverMenuItem(
          value: (openManage: false, query: '需要登录'),
          icon: CupertinoIcons.lock,
          label: '需要登录',
        ),
        const AppPopoverMenuItem(
          value: (openManage: false, query: '未分组'),
          icon: CupertinoIcons.tray,
          label: '未分组',
        ),
        for (final group in groups)
          AppPopoverMenuItem(
            value: (
              openManage: false,
              query: '${RssSourceManageHelper.groupPrefix}$group',
            ),
            icon: CupertinoIcons.folder,
            label: group,
          ),
      ],
    );
    if (!mounted || selected == null) return;
    if (selected.openManage) {
      _openGroupManageSheet();
      return;
    }
    final query = selected.query?.trim() ?? '';
    if (query.isEmpty) return;
    _setQuery(query);
  }

  Future<void> _openGroupManageSheet() async {
    if (!mounted) return;
    await showCupertinoBottomSheetDialog<void>(
      context: context,
      builder: (sheetContext) => CupertinoPopupSurface(
        isSurfacePainted: true,
        child: SizedBox(
          height: math.min(MediaQuery.of(sheetContext).size.height * 0.78, 560),
          child: RssGroupManageView(
            repository: _repo,
            embedded: true,
          ),
        ),
      ),
    );
  }

  Future<void> _openMainOptions() async {
    if (!mounted) return;
    final selected = await showAppPopoverMenu<_RssSourceMainMenuAction>(
      context: context,
      anchorKey: _mainMenuKey,
      items: const [
        AppPopoverMenuItem(
          value: _RssSourceMainMenuAction.create,
          icon: CupertinoIcons.add_circled,
          label: '新建订阅源',
        ),
        AppPopoverMenuItem(
          value: _RssSourceMainMenuAction.importFile,
          icon: CupertinoIcons.doc,
          label: '本地导入',
        ),
        AppPopoverMenuItem(
          value: _RssSourceMainMenuAction.importUrl,
          icon: CupertinoIcons.globe,
          label: '网络导入',
        ),
        AppPopoverMenuItem(
          value: _RssSourceMainMenuAction.importQr,
          icon: CupertinoIcons.qrcode,
          label: '二维码导入',
        ),
        AppPopoverMenuItem(
          value: _RssSourceMainMenuAction.importDefault,
          icon: CupertinoIcons.wand_rays,
          label: '导入默认规则',
        ),
      ],
    );
    if (!mounted || selected == null) return;
    switch (selected) {
      case _RssSourceMainMenuAction.create:
        _openAddSource();
        break;
      case _RssSourceMainMenuAction.importFile:
        _importFromLocalFile();
        break;
      case _RssSourceMainMenuAction.importUrl:
        _importFromOnlineInput();
        break;
      case _RssSourceMainMenuAction.importQr:
        _importFromQrCode();
        break;
      case _RssSourceMainMenuAction.importDefault:
        _importDefaultSources();
        break;
    }
  }

  Future<void> _importFromLocalFile() async {
    final result = await _importExportService.importFromFile();
    await _commitImportResult(result);
  }

  Future<void> _importFromOnlineInput() async {
    final rawInput = await _showOnlineImportInputSheet();
    final normalizedInput = rawInput?.trim();
    if (normalizedInput == null || normalizedInput.isEmpty) {
      return;
    }

    if (_isHttpUrl(normalizedInput)) {
      await _pushOnlineImportHistory(normalizedInput);
    }

    final result = await _importExportService.importFromText(normalizedInput);
    await _commitImportResult(result);
  }

  Future<void> _importFromQrCode() async {
    final text = await QrScanService.scanText(
      context,
      title: '二维码导入',
    );
    final normalizedInput = text?.trim();
    if (normalizedInput == null || normalizedInput.isEmpty) {
      return;
    }
    final result = await _importExportService.importFromText(normalizedInput);
    await _commitImportResult(result);
  }

  Future<void> _importDefaultSources() async {
    final result = await _importExportService.importFromDefaultAsset();
    if (!result.success) {
      _showImportError(result);
      return;
    }

    try {
      await _repo.deleteDefault();
      for (final source in result.sources) {
        final normalizedUrl = source.sourceUrl.trim();
        if (normalizedUrl.isEmpty) {
          continue;
        }
        final normalizedSource = source.copyWith(sourceUrl: normalizedUrl);
        final rawJson = result.rawJsonForSourceUrl(normalizedUrl) ??
            LegadoJson.encode(normalizedSource.toJson());
        await _repo.upsertSourceRawJson(rawJson: rawJson);
      }
    } catch (error) {
      await _showMessage('导入失败: $error');
    }
  }

  Future<String?> _showOnlineImportInputSheet() async {
    final history = await _loadOnlineImportHistory();
    final inputController = TextEditingController();
    try {
      if (!mounted) return null;
      return showCupertinoBottomSheetDialog<String>(
        context: context,
        builder: (popupContext) {
          return CupertinoPopupSurface(
            isSurfacePainted: true,
            child: SizedBox(
              height: math.min(MediaQuery.sizeOf(context).height * 0.72, 560),
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
                                    backgroundColor: CupertinoColors.systemGrey6.resolveFrom(context),
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
                                            color: CupertinoColors.systemRed.resolveFrom(context)
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

  Future<void> _commitImportResult(RssSourceImportResult result) async {
    if (!result.success) {
      if (!result.cancelled) {
        _showImportError(result);
      }
      return;
    }

    final candidates = RssSourceImportSelectionHelper.buildCandidates(
      result: result,
      localMap: _localSourceMap(),
    );
    if (candidates.isEmpty) {
      _showMessage('没有可导入的订阅源');
      return;
    }

    final decision = await _showImportSelectionDialog(candidates);
    if (decision == null) return;
    final plan = RssSourceImportSelectionHelper.buildCommitPlan(
      candidates: decision.candidates,
      policy: decision.policy,
    );
    if (plan.imported <= 0) {
      return;
    }

    final commitResult = await _importCommitService.commit(plan.items);
    if (commitResult.imported <= 0) {
      return;
    }
  }

  Map<String, RssSource> _localSourceMap() {
    final allSources = _repo.getAllSources();
    return {for (final source in allSources) source.sourceUrl: source};
  }

  Future<_RssImportSelectionDecision?> _showImportSelectionDialog(
    List<RssSourceImportCandidate> candidates,
  ) async {
    final dialogCandidates = candidates.toList(growable: false);
    final customGroupController = TextEditingController();
    final defaultSelected = RssSourceImportSelectionHelper.defaultSelectedUrls(
      dialogCandidates,
    );
    final selectedUrls = defaultSelected.toSet();
    var keepName = true;
    var keepGroup = true;
    var keepEnabled = true;
    var appendCustomGroup = false;
    try {
      return await showCupertinoBottomSheetDialog<_RssImportSelectionDecision>(
        context: context,
        builder: (popupContext) {
          return CupertinoPopupSurface(
            isSurfacePainted: true,
            child: StatefulBuilder(
              builder: (context, setDialogState) {
                final selectedCount = selectedUrls.length;
                final totalCount = dialogCandidates.length;
                final allSelected =
                    RssSourceImportSelectionHelper.areAllSelected(
                  candidates: dialogCandidates,
                  selectedUrls: selectedUrls,
                );
                return SizedBox(
                  height: math.min(
                    MediaQuery.sizeOf(context).height * 0.86,
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
                                '导入RSS源',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            CupertinoButton(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 8),
                              onPressed: () => Navigator.pop(popupContext),
                              child: const Text('取消'),
                            ),
                            CupertinoButton.filled(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 12),
                              onPressed: () {
                                Navigator.pop(
                                  context,
                                  _RssImportSelectionDecision(
                                    candidates: dialogCandidates,
                                    policy: RssSourceImportSelectionPolicy(
                                      selectedUrls: selectedUrls.toSet(),
                                      keepName: keepName,
                                      keepGroup: keepGroup,
                                      keepEnabled: keepEnabled,
                                      customGroup: customGroupController.text,
                                      appendCustomGroup: appendCustomGroup,
                                    ),
                                  ),
                                );
                              },
                              child: Text('导入($selectedCount)'),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                        child: Row(
                          children: [
                            CupertinoButton(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              color: CupertinoColors.systemGrey5.resolveFrom(context),
                              onPressed: () {
                                setDialogState(() {
                                  final next = RssSourceImportSelectionHelper
                                      .toggleAllSelection(
                                    candidates: dialogCandidates,
                                    selectedUrls: selectedUrls,
                                  );
                                  selectedUrls
                                    ..clear()
                                    ..addAll(next);
                                });
                              },
                              child: Text(allSelected ? '取消全选' : '全选'),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              '$selectedCount / $totalCount',
                              style: TextStyle(
                                color: CupertinoColors.secondaryLabel.resolveFrom(context)
                                    .resolveFrom(context),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: AppCard(
                          backgroundColor:
                              CupertinoColors.systemGrey6.resolveFrom(context),
                          padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                          child: Column(
                            children: [
                              _buildImportPolicySwitchRow(
                                title: '保留原名',
                                value: keepName,
                                onChanged: (value) {
                                  setDialogState(() => keepName = value);
                                },
                              ),
                              _buildImportPolicySwitchRow(
                                title: '保留分组',
                                value: keepGroup,
                                onChanged: (value) {
                                  setDialogState(() => keepGroup = value);
                                },
                              ),
                              _buildImportPolicySwitchRow(
                                title: '保留启用状态',
                                value: keepEnabled,
                                onChanged: (value) {
                                  setDialogState(() => keepEnabled = value);
                                },
                              ),
                              const SizedBox(height: 8),
                              CupertinoTextField(
                                controller: customGroupController,
                                placeholder: '自定义分组（可选）',
                              ),
                              const SizedBox(height: 6),
                              _buildImportPolicySwitchRow(
                                title: '追加到已有分组',
                                value: appendCustomGroup,
                                onChanged: (value) {
                                  setDialogState(
                                      () => appendCustomGroup = value);
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                          itemCount: dialogCandidates.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 6),
                          itemBuilder: (context, index) {
                            final candidate = dialogCandidates[index];
                            final selected =
                                selectedUrls.contains(candidate.url);
                            return GestureDetector(
                              onTap: () {
                                setDialogState(() {
                                  if (selected) {
                                    selectedUrls.remove(candidate.url);
                                  } else {
                                    selectedUrls.add(candidate.url);
                                  }
                                });
                              },
                              child: AppCard(
                                backgroundColor:
                                    CupertinoColors.systemGrey6.resolveFrom(context),
                                borderColor: selected
                                    ? CupertinoColors.activeBlue.resolveFrom(context)
                                        .resolveFrom(context)
                                    : CupertinoColors.separator.resolveFrom(context)
                                        .resolveFrom(context),
                                borderWidth: 0.6,
                                padding:
                                    const EdgeInsets.fromLTRB(10, 8, 10, 8),
                                child: Row(
                                  children: [
                                    Icon(
                                      selected
                                          ? CupertinoIcons
                                              .check_mark_circled_solid
                                          : CupertinoIcons.circle,
                                      size: 20,
                                      color: selected
                                          ? CupertinoColors.activeBlue.resolveFrom(context)
                                              .resolveFrom(context)
                                          : CupertinoColors.secondaryLabel.resolveFrom(context)
                                              .resolveFrom(context),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            candidate.incoming.sourceName,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            candidate.url,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: CupertinoColors
                                                  .secondaryLabel
                                                  .resolveFrom(context),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      _importStateLabel(candidate.state),
                                      style: TextStyle(
                                        color: _importStateColor(
                                          candidate.state,
                                          context,
                                        ),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
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
    } finally {
      customGroupController.dispose();
    }
  }

  Widget _buildImportPolicySwitchRow({
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontSize: 13),
            ),
          ),
          CupertinoSwitch(
            value: value,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  String _importStateLabel(RssSourceImportCandidateState state) {
    return switch (state) {
      RssSourceImportCandidateState.newSource => '新增',
      RssSourceImportCandidateState.update => '更新',
      RssSourceImportCandidateState.existing => '已有',
    };
  }

  Color _importStateColor(
    RssSourceImportCandidateState state,
    BuildContext context,
  ) {
    return switch (state) {
      RssSourceImportCandidateState.newSource =>
        CupertinoColors.systemGreen.resolveFrom(context),
      RssSourceImportCandidateState.update =>
        CupertinoColors.systemOrange.resolveFrom(context),
      RssSourceImportCandidateState.existing =>
        CupertinoColors.secondaryLabel.resolveFrom(context),
    };
  }

  void _showImportError(RssSourceImportResult result) {
    final lines = <String>[
      result.errorMessage ?? '导入失败',
    ];
    if (result.totalInputCount > 0) {
      lines.add('输入条数：${result.totalInputCount}');
      if (result.invalidCount > 0) {
        lines.add('无效条数：${result.invalidCount}');
      }
      if (result.duplicateCount > 0) {
        lines.add('重复URL：${result.duplicateCount}（后项覆盖）');
      }
    }
    if (result.warnings.isNotEmpty) {
      lines.add('详情：');
      lines.addAll(result.warnings.take(5));
      final more = result.warnings.length - 5;
      if (more > 0) {
        lines.add('…其余 $more 条省略');
      }
    }
    _showMessage(lines.join('\n'));
  }

  Future<void> _showMessage(String message) async {
    if (!mounted) return;
    await showCupertinoBottomSheetDialog<void>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('提示'),
        content: Text('\n$message'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('好'),
          ),
        ],
      ),
    );
  }

  Future<void> _showExportPathDialog(String outputPath) async {
    if (!mounted) return;
    final path = outputPath.trim();
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
    await showCupertinoBottomSheetDialog<void>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: const Text('导出成功'),
        content: Text('\n${lines.join('\n')}'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('关闭'),
          ),
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

  Future<void> _showSourceActions(RssSource source) async {
    if (!mounted) return;
    final selected = await showAppActionListSheet<_RssSourceItemAction>(
      context: context,
      title: source.sourceName,
      showCancel: true,
      items: const [
        AppActionListItem<_RssSourceItemAction>(
          value: _RssSourceItemAction.moveToTop,
          icon: CupertinoIcons.arrow_up_circle,
          label: '置顶',
        ),
        AppActionListItem<_RssSourceItemAction>(
          value: _RssSourceItemAction.moveToBottom,
          icon: CupertinoIcons.arrow_down_circle,
          label: '置底',
        ),
        AppActionListItem<_RssSourceItemAction>(
          value: _RssSourceItemAction.delete,
          icon: CupertinoIcons.delete,
          label: '删除',
          isDestructiveAction: true,
        ),
      ],
    );
    if (selected == null || !mounted) return;
    switch (selected) {
      case _RssSourceItemAction.moveToTop:
        await _moveToTop(source);
        return;
      case _RssSourceItemAction.moveToBottom:
        await _moveToBottom(source);
        return;
      case _RssSourceItemAction.delete:
        await _deleteSource(source);
        return;
    }
  }

  Future<void> _updateEnabled(RssSource source, bool value) async {
    final updated = source.copyWith(enabled: value);
    await _repo.updateSource(updated);
  }

  Future<void> _moveToTop(RssSource source) async {
    final sourceUrl = source.sourceUrl.trim();
    if (sourceUrl.isEmpty) return;
    final current = _repo.getByKey(sourceUrl);
    if (current == null) return;
    final updated = RssSourceManageHelper.moveToTop(
      source: current,
      minOrder: _repo.minOrder,
    );
    try {
      await _repo.updateSource(updated);
    } catch (error, stackTrace) {
      ExceptionLogService().record(
        node: 'rss_source_item.menu_top',
        message: 'RSS 源管理置顶失败',
        error: error,
        stackTrace: stackTrace,
        context: <String, dynamic>{
          'sourceUrl': sourceUrl,
          'sourceName': current.sourceName,
          'fromOrder': current.customOrder,
          'toOrder': updated.customOrder,
        },
      );
    }
  }

  Future<void> _moveToBottom(RssSource source) async {
    final sourceUrl = source.sourceUrl.trim();
    if (sourceUrl.isEmpty) return;
    final current = _repo.getByKey(sourceUrl);
    if (current == null) return;
    final updated = RssSourceManageHelper.moveToBottom(
      source: current,
      maxOrder: _repo.maxOrder,
    );
    try {
      await _repo.updateSource(updated);
    } catch (error, stackTrace) {
      ExceptionLogService().record(
        node: 'rss_source_item.menu_bottom',
        message: 'RSS 源管理置底失败',
        error: error,
        stackTrace: stackTrace,
        context: <String, dynamic>{
          'sourceUrl': sourceUrl,
          'sourceName': current.sourceName,
          'fromOrder': current.customOrder,
          'toOrder': updated.customOrder,
        },
      );
    }
  }

  Future<void> _deleteSource(RssSource source) async {
    if (!mounted) return;
    final sourceUrl = source.sourceUrl.trim();
    if (sourceUrl.isNotEmpty && _selectedSourceUrls.contains(sourceUrl)) {
      setState(() {
        _selectedSourceUrls.remove(sourceUrl);
      });
    }
    final confirmed = await showCupertinoBottomSheetDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('提醒'),
        content: Text('确定删除\n${source.sourceName}'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (sourceUrl.isEmpty) return;
    final current = _repo.getByKey(sourceUrl);
    if (current == null) return;
    try {
      await _repo.deleteSourceWithArticles(sourceUrl);
      await SourceVariableStore.removeVariable(sourceUrl);
    } catch (error, stackTrace) {
      ExceptionLogService().record(
        node: 'rss_source_item.menu_del',
        message: 'RSS 源管理删除订阅源失败',
        error: error,
        stackTrace: stackTrace,
        context: <String, dynamic>{
          'sourceUrl': sourceUrl,
          'sourceName': current.sourceName,
        },
      );
    }
  }
}
