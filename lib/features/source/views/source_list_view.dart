import 'dart:convert';
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart'
    show ReorderableDragStartListener, ReorderableListView;
import 'package:flutter/rendering.dart' show RenderBox;
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../app/widgets/app_cupertino_page_scaffold.dart';
import '../../../core/database/database_service.dart';
import '../../../core/database/repositories/source_repository.dart';
import '../../../core/services/exception_log_service.dart';
import '../../../core/services/keep_screen_on_service.dart';
import '../../../core/services/qr_scan_service.dart';
import '../../../core/services/settings_service.dart';
import '../../../core/services/source_variable_store.dart';
import '../../../core/utils/legado_json.dart';
import '../../settings/views/app_help_dialog.dart';
import '../../search/models/search_scope.dart';
import '../../search/views/search_view.dart';
import '../models/book_source.dart';
import '../services/source_availability_check_task_service.dart';
import '../services/source_check_source_state_helper.dart';
import '../services/source_host_group_helper.dart';
import '../services/source_import_commit_service.dart';
import '../services/source_import_export_service.dart';
import '../services/source_import_selection_helper.dart';
import '../services/source_login_url_resolver.dart';
import '../services/source_login_ui_helper.dart';
import '../../search/models/search_scope_group_helper.dart';
import 'source_debug_legacy_view.dart';
import 'source_edit_legacy_view.dart';
import 'source_login_form_view.dart';
import 'source_web_verify_view.dart';

enum _SourceSortMode {
  manual,
  weight,
  name,
  url,
  update,
  respond,
  enabled,
}

typedef SourceMoveSourcesHandler = Future<void> Function(
  List<BookSource> sources, {
  required bool toTop,
});

class _ImportSelectionDecision {
  const _ImportSelectionDecision({
    required this.candidates,
    required this.policy,
  });

  final List<SourceImportCandidate> candidates;
  final SourceImportSelectionPolicy policy;
}

enum _CheckKeywordDialogAction {
  cancel,
  openSettings,
  start,
}

class _CheckKeywordDialogResult {
  const _CheckKeywordDialogResult({
    required this.action,
    required this.keyword,
  });

  final _CheckKeywordDialogAction action;
  final String keyword;
}

class _CheckSettings {
  const _CheckSettings({
    required this.timeoutMs,
    required this.checkSearch,
    required this.checkDiscovery,
    required this.checkInfo,
    required this.checkCategory,
    required this.checkContent,
  });

  final int timeoutMs;
  final bool checkSearch;
  final bool checkDiscovery;
  final bool checkInfo;
  final bool checkCategory;
  final bool checkContent;
}

/// 书源管理页面
class SourceListView extends StatefulWidget {
  const SourceListView({
    super.key,
    this.moveSourcesHandler,
  });

  final SourceMoveSourcesHandler? moveSourcesHandler;

  @override
  State<SourceListView> createState() => _SourceListViewState();
}

class _SourceListViewState extends State<SourceListView> {
  _SourceSortMode _sortMode = _SourceSortMode.manual;
  bool _sortAscending = true;
  bool _groupSourcesByDomain = false;
  SourceCheckTaskSnapshot? _lastCheckSnapshot;

  late final SourceRepository _sourceRepo;
  late final DatabaseService _db;
  late final SourceImportCommitService _importCommitService;
  final SettingsService _settingsService = SettingsService();
  final KeepScreenOnService _keepScreenOnService = KeepScreenOnService.instance;
  final SourceAvailabilityCheckTaskService _checkTaskService =
      SourceAvailabilityCheckTaskService.instance;
  final SourceImportExportService _importExportService =
      SourceImportExportService();
  bool _checkTaskKeepScreenOn = false;

  final TextEditingController _urlController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _listScrollController = ScrollController();

  final Set<String> _selectedUrls = <String>{};
  final Map<String, String> _hostMap = <String, String>{};
  final Map<String, GlobalKey> _itemKeyByUrl = <String, GlobalKey>{};
  final GlobalKey _listViewportKey = GlobalKey();
  bool _dragSelecting = false;
  bool _dragSelectValue = true;
  int _dragLastIndex = -1;

  static const String _prefImportOnlineHistory = 'source_import_online_history';
  static const String _prefCheckKeyword = 'source_check_keyword';
  static const String _prefCheckTimeoutMs = 'source_check_timeout_ms';
  static const String _prefCheckSearch = 'source_check_search';
  static const String _prefCheckDiscovery = 'source_check_discovery';
  static const String _prefCheckInfo = 'source_check_info';
  static const String _prefCheckCategory = 'source_check_category';
  static const String _prefCheckContent = 'source_check_content';
  static const String _prefImportKeepName = 'source_import_keep_name';
  static const String _prefImportKeepGroup = 'source_import_keep_group';
  static const String _prefImportKeepEnable = 'source_import_keep_enable';
  static const String _prefSourceManageHelpShown =
      'source_manage_help_shown_v1';

  @override
  void initState() {
    super.initState();
    _db = DatabaseService();
    _sourceRepo = SourceRepository(_db);
    _importCommitService = SourceImportCommitService(
      upsertSourceRawJson: _sourceRepo.upsertSourceRawJson,
      loadAllSources: _sourceRepo.getAllSources,
      loadRawJsonByUrl: _sourceRepo.getRawJsonByUrl,
    );
    _lastCheckSnapshot = _checkTaskService.snapshot;
    _checkTaskService.listenable.addListener(_onCheckTaskChanged);
    _syncCheckKeepScreenOn(_lastCheckSnapshot);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybeShowSourceManageHelpOnce();
    });
  }

  @override
  void dispose() {
    _checkTaskService.listenable.removeListener(_onCheckTaskChanged);
    _syncCheckKeepScreenOn(null, forceDisable: true);
    _urlController.dispose();
    _searchController.dispose();
    _listScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<void>(
      canPop: _searchController.text.trim().isEmpty,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || _searchController.text.trim().isEmpty) return;
        setState(() => _searchController.clear());
      },
      child: AppCupertinoPageScaffold(
        title: '书源管理',
        middle: _buildNavigationSearchField(),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CupertinoButton(
              padding: EdgeInsets.zero,
              minimumSize: const Size(30, 30),
              onPressed: _showSortOptions,
              child: const Icon(CupertinoIcons.arrow_up_arrow_down),
            ),
            CupertinoButton(
              padding: EdgeInsets.zero,
              minimumSize: const Size(30, 30),
              onPressed: _showGroupFilterOptions,
              child: const Icon(CupertinoIcons.square_grid_2x2),
            ),
            CupertinoButton(
              padding: EdgeInsets.zero,
              minimumSize: const Size(30, 30),
              onPressed: _showMainOptions,
              child: const Icon(CupertinoIcons.ellipsis_circle),
            ),
          ],
        ),
        child: StreamBuilder<List<BookSource>>(
          stream: _sourceRepo.watchAllSources(),
          builder: (context, snapshot) {
            final allSources = snapshot.data ?? _sourceRepo.getAllSources();
            final cleanedAll = _normalizeSources(allSources);
            _cleanupSelection(cleanedAll);
            final filtered = _buildVisibleList(cleanedAll);

            return Column(
              children: [
                _buildCheckTaskBanner(),
                Expanded(
                  child: filtered.isEmpty
                      ? _buildEmptyState()
                      : _buildSourceList(cleanedAll, filtered),
                ),
                _buildBatchActionBar(visibleSources: filtered),
              ],
            );
          },
        ),
      ),
    );
  }

  List<BookSource> _normalizeSources(List<BookSource> sources) {
    final dedup = <String, BookSource>{};
    for (final source in sources) {
      final url = source.bookSourceUrl.trim();
      if (url.isEmpty) continue;
      dedup[url] = source;
    }
    return dedup.values.toList(growable: false);
  }

  void _cleanupSelection(List<BookSource> allSources) {
    final urls = allSources.map((s) => s.bookSourceUrl).toSet();
    _itemKeyByUrl.removeWhere((url, _) => !urls.contains(url));
    if (_selectedUrls.isEmpty) return;
    final toRemove = _selectedUrls.where((url) => !urls.contains(url)).toList();
    if (toRemove.isEmpty) return;
    _selectedUrls.removeAll(toRemove);
  }

  void _onCheckTaskChanged() {
    final current = _checkTaskService.snapshot;
    final previous = _lastCheckSnapshot;
    final finished = previous?.running == true && current?.running != true;
    _lastCheckSnapshot = current;
    _syncCheckKeepScreenOn(current);
    if (!mounted) return;
    setState(() {});
    if (!finished || current == null) return;
    _handleInlineCheckFinished(current);
  }

  void _syncCheckKeepScreenOn(
    SourceCheckTaskSnapshot? snapshot, {
    bool forceDisable = false,
  }) {
    final shouldKeepOn = !forceDisable && snapshot?.running == true;
    if (_checkTaskKeepScreenOn == shouldKeepOn) return;
    _checkTaskKeepScreenOn = shouldKeepOn;
    unawaited(_keepScreenOnService.setEnabled(shouldKeepOn));
  }

  void _handleInlineCheckFinished(SourceCheckTaskSnapshot snapshot) {
    final allSources = _normalizeSources(_sourceRepo.getAllSources());
    final hasInvalidGroup = allSources.any((source) {
      final groups = SourceCheckSourceStateHelper.splitGroups(
        source.bookSourceGroup,
      );
      return groups.any((group) => group.contains('失效'));
    });
    if (_searchController.text.trim().isEmpty && hasInvalidGroup) {
      setState(() => _searchController.text = '失效');
      _showToastMessage('发现有失效书源，已自动筛选');
    }
  }

  SourceCheckItem? _findCheckItem(String bookSourceUrl) {
    final snapshot = _checkTaskService.snapshot;
    if (snapshot == null) return null;
    for (final item in snapshot.items) {
      if (item.source.bookSourceUrl == bookSourceUrl) return item;
    }
    return null;
  }

  SourceCheckStatus? _inlineCheckStatus(BookSource source) {
    final item = _findCheckItem(source.bookSourceUrl);
    if (item != null) return item.status;
    final cached = _checkTaskService.lastResultFor(source.bookSourceUrl);
    return cached?.status;
  }

  String? _inlineCheckMessage(BookSource source) {
    final item = _findCheckItem(source.bookSourceUrl);
    final cached = _checkTaskService.lastResultFor(source.bookSourceUrl);
    final status = item?.status ?? cached?.status;
    if (status == null) return null;
    final base = switch (status) {
      SourceCheckStatus.pending => '待校验',
      SourceCheckStatus.running => '校验中',
      SourceCheckStatus.ok => '校验成功',
      SourceCheckStatus.empty => '空列表',
      SourceCheckStatus.fail => '校验失败',
      SourceCheckStatus.skipped => '已跳过',
    };
    final detail = ((item?.message) ?? (cached?.message) ?? '').trim();
    if (detail.isEmpty || detail == base) return base;
    return '$base：$detail';
  }

  Color _inlineCheckColor(SourceCheckStatus status) {
    switch (status) {
      case SourceCheckStatus.ok:
        return CupertinoColors.systemGreen.resolveFrom(context);
      case SourceCheckStatus.empty:
        return CupertinoColors.systemOrange.resolveFrom(context);
      case SourceCheckStatus.fail:
        return CupertinoColors.systemRed.resolveFrom(context);
      case SourceCheckStatus.running:
        return CupertinoTheme.of(context).primaryColor;
      case SourceCheckStatus.skipped:
        return CupertinoColors.systemGrey.resolveFrom(context);
      case SourceCheckStatus.pending:
        return CupertinoColors.secondaryLabel.resolveFrom(context);
    }
  }

  List<String> _buildGroups(List<BookSource> sources) {
    final rawGroups = sources
        .map((source) => source.bookSourceGroup?.trim() ?? '')
        .where((raw) => raw.isNotEmpty);
    return SearchScopeGroupHelper.dealGroups(rawGroups);
  }

  Widget _buildCheckTaskBanner() {
    final snapshot = _checkTaskService.snapshot;
    if (snapshot == null || !snapshot.running) {
      return const SizedBox.shrink();
    }
    final text = _buildCheckTaskProgressText(snapshot);
    return Container(
      width: double.infinity,
      color: CupertinoColors.systemYellow.resolveFrom(context).withValues(
            alpha: 0.14,
          ),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Row(
        children: [
          const CupertinoActivityIndicator(radius: 8),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                color: CupertinoColors.label.resolveFrom(context),
              ),
            ),
          ),
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            minimumSize: const Size(44, 28),
            onPressed: snapshot.stopRequested
                ? null
                : () {
                    _checkTaskService.requestStop();
                    setState(() {});
                  },
            child: Text(snapshot.stopRequested ? '停止中' : '停止'),
          ),
        ],
      ),
    );
  }

  String _buildCheckTaskProgressText(SourceCheckTaskSnapshot snapshot) {
    final items = snapshot.items;
    final total = items.length;
    final done =
        items.where((item) => item.status != SourceCheckStatus.pending).length;
    final runningItem =
        items.where((e) => e.status == SourceCheckStatus.running);
    final runningName = runningItem.isEmpty
        ? ''
        : ' · ${runningItem.first.source.bookSourceName}';
    if (snapshot.stopRequested) {
      return '正在停止校验（$done/$total）$runningName';
    }
    return '校验进行中（$done/$total）$runningName';
  }

  Widget _buildNavigationSearchField() {
    return SizedBox(
      height: 34,
      child: CupertinoSearchTextField(
        controller: _searchController,
        placeholder: '搜索书源',
        onChanged: (_) => setState(() {}),
      ),
    );
  }

  List<BookSource> _buildVisibleList(List<BookSource> allSources) {
    var filtered = allSources;

    final query = _searchController.text.trim();
    if (query.isNotEmpty) {
      filtered = _applyQueryFilter(filtered, query);
    }

    final sorted = filtered.toList(growable: false);
    _hostMap.clear();
    _sortSources(sorted);
    return sorted;
  }

  List<BookSource> _applyQueryFilter(List<BookSource> input, String query) {
    final q = query.toLowerCase();
    if (q == '已启用' || q == '启用') {
      return input.where((s) => s.enabled).toList(growable: false);
    }
    if (q == '已禁用' || q == '禁用') {
      return input.where((s) => !s.enabled).toList(growable: false);
    }
    if (q == '需要登录' || q == '需登录') {
      return input
          .where((s) => (s.loginUrl ?? '').trim().isNotEmpty)
          .toList(growable: false);
    }
    if (q == '未分组' || q == '无分组') {
      return input.where((s) {
        final group = s.bookSourceGroup ?? '';
        return group.isEmpty || group.contains('未分组');
      }).toList(growable: false);
    }
    if (q == '已启用发现' || q == '启用发现') {
      return input.where((s) => s.enabledExplore).toList(growable: false);
    }
    if (q == '已禁用发现' || q == '禁用发现') {
      return input.where((s) => !s.enabledExplore).toList(growable: false);
    }
    if (query.startsWith('group:')) {
      final key = query.substring(6);
      return input
          .where((s) => _matchesGroupQueryLegacy(s.bookSourceGroup, key))
          .toList(growable: false);
    }

    return input.where((s) {
      final name = s.bookSourceName.toLowerCase();
      final url = s.bookSourceUrl.toLowerCase();
      final group = (s.bookSourceGroup ?? '').toLowerCase();
      final comment = (s.bookSourceComment ?? '').toLowerCase();
      return name.contains(q) ||
          url.contains(q) ||
          group.contains(q) ||
          comment.contains(q);
    }).toList(growable: false);
  }

  void _sortSources(List<BookSource> list) {
    if (_groupSourcesByDomain) {
      list.sort((a, b) {
        final hostA = _hostOf(a.bookSourceUrl);
        final hostB = _hostOf(b.bookSourceUrl);
        final invalidA = hostA == '#';
        final invalidB = hostB == '#';
        if (invalidA != invalidB) {
          return invalidA ? 1 : -1;
        }
        final hostCmp = hostA.compareTo(hostB);
        if (hostCmp != 0) return hostCmp;
        return b.lastUpdateTime.compareTo(a.lastUpdateTime);
      });
      return;
    }

    int compareByMode(BookSource a, BookSource b) {
      switch (_sortMode) {
        case _SourceSortMode.manual:
          return a.customOrder.compareTo(b.customOrder);
        case _SourceSortMode.weight:
          return a.weight.compareTo(b.weight);
        case _SourceSortMode.name:
          return SearchScopeGroupHelper.cnCompareLikeLegado(
            a.bookSourceName,
            b.bookSourceName,
          );
        case _SourceSortMode.url:
          return a.bookSourceUrl.compareTo(b.bookSourceUrl);
        case _SourceSortMode.update:
          // 对齐 legado：升序模式下更新时间为“新到旧”。
          return b.lastUpdateTime.compareTo(a.lastUpdateTime);
        case _SourceSortMode.respond:
          return a.respondTime.compareTo(b.respondTime);
        case _SourceSortMode.enabled:
          final enabledCmp =
              (a.enabled == b.enabled) ? 0 : (a.enabled ? -1 : 1);
          if (enabledCmp != 0) return enabledCmp;
          return SearchScopeGroupHelper.cnCompareLikeLegado(
            a.bookSourceName,
            b.bookSourceName,
          );
      }
    }

    list.sort((a, b) {
      if (_sortMode == _SourceSortMode.enabled) {
        final enabledCmp = _sortAscending
            ? (a.enabled == b.enabled ? 0 : (a.enabled ? -1 : 1))
            : (a.enabled == b.enabled ? 0 : (a.enabled ? 1 : -1));
        if (enabledCmp != 0) {
          return enabledCmp;
        }
        // 对齐 legado：是否启用在反序时仅反转启用分组，同组内名称始终正序。
        return SearchScopeGroupHelper.cnCompareLikeLegado(
          a.bookSourceName,
          b.bookSourceName,
        );
      }
      final c = compareByMode(a, b);
      return _sortAscending ? c : -c;
    });
  }

  String _hostOf(String url) {
    return _hostMap.putIfAbsent(
        url, () => SourceHostGroupHelper.groupHost(url));
  }

  bool get _canManualReorder {
    return _sortMode == _SourceSortMode.manual && !_groupSourcesByDomain;
  }

  Widget _buildSourceList(
      List<BookSource> allSources, List<BookSource> visible) {
    final reorderEnabled = _canManualReorder;
    final theme = ShadTheme.of(context);
    final scheme = theme.colorScheme;

    Widget buildItem(BookSource source, int index) {
      final selected = _selectedUrls.contains(source.bookSourceUrl);
      final checkItem = _findCheckItem(source.bookSourceUrl);
      final checkStatus = _inlineCheckStatus(source);
      final checkMessage = _inlineCheckMessage(source);
      final showHeader = _groupSourcesByDomain &&
          (index == 0 ||
              _hostOf(visible[index - 1].bookSourceUrl) !=
                  _hostOf(source.bookSourceUrl));

      final groupText = (source.bookSourceGroup ?? '').trim();
      final displayName = groupText.isEmpty
          ? source.bookSourceName
          : '${source.bookSourceName} ($groupText)';
      final hasExplore = (source.exploreUrl ?? '').trim().isNotEmpty;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showHeader)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
              child: Text(
                _hostOf(source.bookSourceUrl),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: CupertinoColors.secondaryLabel.resolveFrom(context),
                ),
              ),
            ),
          Container(
            key: _itemKeyForUrl(source.bookSourceUrl),
            color: CupertinoColors.systemBackground.resolveFrom(context),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onLongPressStart: (_) {
                _startDragSelection(visible, index);
              },
              onLongPressMoveUpdate: (details) {
                _updateDragSelectionByGlobal(
                  visible,
                  details.globalPosition,
                );
                _autoScrollForDragSelection(
                  visible,
                  details.globalPosition,
                );
              },
              onLongPressEnd: (_) => _endDragSelection(),
              onLongPressCancel: _endDragSelection,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 10, 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 10, right: 8),
                      child: CupertinoButton(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(24, 24),
                        onPressed: () {
                          setState(
                              () => _toggleSelection(source.bookSourceUrl));
                        },
                        child: Icon(
                          selected
                              ? CupertinoIcons.check_mark_circled_solid
                              : CupertinoIcons.circle,
                          color: selected
                              ? CupertinoTheme.of(context).primaryColor
                              : CupertinoColors.systemGrey,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  displayName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.p.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: scheme.foreground,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (checkMessage != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 3),
                              child: Row(
                                children: [
                                  if (checkItem?.status ==
                                      SourceCheckStatus.running)
                                    const Padding(
                                      padding: EdgeInsets.only(right: 6),
                                      child: SizedBox(
                                        width: 11,
                                        height: 11,
                                        child: CupertinoActivityIndicator(
                                          radius: 5.5,
                                        ),
                                      ),
                                    ),
                                  Expanded(
                                    child: Text(
                                      checkMessage,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: _inlineCheckColor(
                                          checkStatus ??
                                              SourceCheckStatus.pending,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (reorderEnabled)
                      Padding(
                        padding: const EdgeInsets.only(top: 6, right: 6),
                        child: ReorderableDragStartListener(
                          index: index,
                          child: Icon(
                            CupertinoIcons.line_horizontal_3,
                            color: CupertinoColors.secondaryLabel.resolveFrom(
                              context,
                            ),
                          ),
                        ),
                      ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ShadSwitch(
                          value: source.enabled,
                          onChanged: (value) async {
                            await _sourceRepo
                                .updateSource(source.copyWith(enabled: value));
                          },
                        ),
                        const SizedBox(width: 2),
                        CupertinoButton(
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(28, 28),
                          onPressed: () => _openEditor(source.bookSourceUrl),
                          child: const Icon(
                            CupertinoIcons.pencil_circle,
                            size: 19,
                          ),
                        ),
                        const SizedBox(width: 2),
                        CupertinoButton(
                          key: ValueKey<String>(
                            'source-item-more-${source.bookSourceUrl}',
                          ),
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(28, 28),
                          onPressed: () => _showSourceActions(source),
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              const Icon(
                                CupertinoIcons.ellipsis_circle,
                                size: 19,
                              ),
                              if (hasExplore)
                                Positioned(
                                  right: -1,
                                  top: -1,
                                  child: Container(
                                    width: 7,
                                    height: 7,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: source.enabledExplore
                                          ? CupertinoColors.systemGreen
                                          : CupertinoColors.systemRed,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    }

    if (reorderEnabled) {
      return ReorderableListView.builder(
        key: _listViewportKey,
        scrollController: _listScrollController,
        buildDefaultDragHandles: false,
        padding: const EdgeInsets.fromLTRB(0, 0, 0, 12),
        itemCount: visible.length,
        onReorder: (oldIndex, newIndex) async {
          await _onReorderVisible(visible, oldIndex, newIndex);
        },
        itemBuilder: (context, index) {
          final source = visible[index];
          return KeyedSubtree(
            key: ValueKey(source.bookSourceUrl),
            child: buildItem(source, index),
          );
        },
      );
    }

    return ListView.separated(
      key: _listViewportKey,
      controller: _listScrollController,
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 12),
      itemCount: visible.length,
      separatorBuilder: (_, __) => Container(
        height: 0.5,
        color: CupertinoColors.systemGrey4.resolveFrom(context),
      ),
      itemBuilder: (context, index) {
        final source = visible[index];
        return buildItem(source, index);
      },
    );
  }

  Future<void> _onReorderVisible(
    List<BookSource> visible,
    int oldIndex,
    int newIndex,
  ) async {
    if (!_canManualReorder || visible.isEmpty) return;
    if (oldIndex < 0 || oldIndex >= visible.length) return;
    var targetIndex = newIndex;
    if (oldIndex < targetIndex) {
      targetIndex -= 1;
    }
    if (targetIndex < 0 || targetIndex >= visible.length) return;
    if (oldIndex == targetIndex) return;

    final start = math.min(oldIndex, targetIndex);
    final end = math.max(oldIndex, targetIndex);
    final originalOrders =
        visible.sublist(start, end + 1).map((e) => e.customOrder).toList();

    final reordered = visible.toList(growable: true);
    final moved = reordered.removeAt(oldIndex);
    reordered.insert(targetIndex, moved);

    var hasDuplicateOrderInAffectedRange = false;
    final affectedOrders = <int>{};
    for (var i = start; i <= end; i++) {
      if (!affectedOrders.add(reordered[i].customOrder)) {
        hasDuplicateOrderInAffectedRange = true;
        break;
      }
    }
    if (hasDuplicateOrderInAffectedRange) {
      final normalized = reordered
          .asMap()
          .entries
          .map(
            (entry) => entry.value.copyWith(
              customOrder: _sortAscending ? entry.key : -entry.key,
            ),
          )
          .toList(growable: false);
      await _sourceRepo.addSources(normalized);
      return;
    }

    final updated = <BookSource>[];
    for (var i = start; i <= end; i++) {
      final source = reordered[i];
      final nextOrder = originalOrders[i - start];
      if (source.customOrder == nextOrder) continue;
      updated.add(source.copyWith(customOrder: nextOrder));
    }
    if (updated.isEmpty) return;
    await _sourceRepo.addSources(updated);
  }

  Widget _buildBatchActionBar({
    required List<BookSource> visibleSources,
  }) {
    final selectedCount = _selectedSources(visibleSources).length;
    final totalCount = visibleSources.length;
    final allSelected = totalCount > 0 && selectedCount >= totalCount;
    final hasSelection = selectedCount > 0;
    final enabledColor = CupertinoTheme.of(context).primaryColor;
    final disabledColor = CupertinoColors.systemGrey.resolveFrom(context);

    void selectAllOrClearVisible() {
      setState(() {
        final visibleSet =
            visibleSources.map((source) => source.bookSourceUrl).toSet();
        if (allSelected) {
          _selectedUrls.removeAll(visibleSet);
          return;
        }
        _selectedUrls.addAll(visibleSet);
      });
    }

    void invertVisibleSelection() {
      setState(() {
        final visibleSet = visibleSources.map((e) => e.bookSourceUrl).toSet();
        for (final url in visibleSet) {
          _toggleSelection(url);
        }
      });
    }

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
                onPressed: totalCount == 0 ? null : selectAllOrClearVisible,
                child: Text(
                  allSelected
                      ? '取消全选（$selectedCount/$totalCount）'
                      : '全选（$selectedCount/$totalCount）',
                  style: TextStyle(
                    fontSize: 13,
                    color: totalCount == 0 ? disabledColor : enabledColor,
                  ),
                ),
              ),
            ),
            CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              minimumSize: const Size(30, 30),
              onPressed: hasSelection ? invertVisibleSelection : null,
              child: Text(
                '反选',
                style: TextStyle(
                  fontSize: 13,
                  color: hasSelection ? enabledColor : disabledColor,
                ),
              ),
            ),
            CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              minimumSize: const Size(30, 30),
              onPressed: hasSelection
                  ? () => _batchDeleteSelected(visibleSources)
                  : null,
              child: Text(
                '删除',
                style: TextStyle(
                  fontSize: 13,
                  color: hasSelection
                      ? CupertinoColors.systemRed.resolveFrom(context)
                      : disabledColor,
                ),
              ),
            ),
            CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              minimumSize: const Size(30, 30),
              onPressed: hasSelection
                  ? () => _showBatchMoreActions(visibleSources)
                  : null,
              child: Icon(
                CupertinoIcons.ellipsis_circle,
                size: 19,
                color: hasSelection ? enabledColor : disabledColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showBatchMoreActions(List<BookSource> visibleSources) {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (sheetContext) => CupertinoActionSheet(
        title: const Text('批量操作'),
        actions: [
          CupertinoActionSheetAction(
            child: const Text('启用所选'),
            onPressed: () {
              Navigator.pop(sheetContext);
              _batchSetEnabled(visibleSources, true);
            },
          ),
          CupertinoActionSheetAction(
            child: const Text('禁用所选'),
            onPressed: () {
              Navigator.pop(sheetContext);
              _batchSetEnabled(visibleSources, false);
            },
          ),
          CupertinoActionSheetAction(
            child: const Text('加入分组'),
            onPressed: () {
              Navigator.pop(sheetContext);
              _batchAddGroup(visibleSources);
            },
          ),
          CupertinoActionSheetAction(
            child: const Text('移除分组'),
            onPressed: () {
              Navigator.pop(sheetContext);
              _batchRemoveGroup(visibleSources);
            },
          ),
          CupertinoActionSheetAction(
            child: const Text('启用发现'),
            onPressed: () {
              Navigator.pop(sheetContext);
              _batchSetExplore(visibleSources, true);
            },
          ),
          CupertinoActionSheetAction(
            child: const Text('禁用发现'),
            onPressed: () {
              Navigator.pop(sheetContext);
              _batchSetExplore(visibleSources, false);
            },
          ),
          CupertinoActionSheetAction(
            child: const Text('置顶'),
            onPressed: () {
              Navigator.pop(sheetContext);
              _batchMoveToTopBottom(visibleSources, true);
            },
          ),
          CupertinoActionSheetAction(
            child: const Text('置底'),
            onPressed: () {
              Navigator.pop(sheetContext);
              _batchMoveToTopBottom(visibleSources, false);
            },
          ),
          CupertinoActionSheetAction(
            child: const Text('导出所选'),
            onPressed: () {
              Navigator.pop(sheetContext);
              _batchExportSelected(visibleSources);
            },
          ),
          CupertinoActionSheetAction(
            child: const Text('分享所选'),
            onPressed: () {
              Navigator.pop(sheetContext);
              _batchShareSelected(visibleSources);
            },
          ),
          CupertinoActionSheetAction(
            child: const Text('校验所选'),
            onPressed: () {
              Navigator.pop(sheetContext);
              _batchCheckSelected(visibleSources);
            },
          ),
          CupertinoActionSheetAction(
            child: const Text('选中所选区间'),
            onPressed: () {
              Navigator.pop(sheetContext);
              setState(() => _expandSelectionInterval(visibleSources));
            },
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          child: const Text('取消'),
          onPressed: () => Navigator.pop(sheetContext),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final theme = ShadTheme.of(context);
    final scheme = theme.colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            LucideIcons.cloudDownload,
            size: 52,
            color: scheme.mutedForeground,
          ),
          const SizedBox(height: 16),
          Text('暂无书源', style: theme.textTheme.h4),
          const SizedBox(height: 8),
          Text(
            '点击右上角更多导入书源',
            style:
                theme.textTheme.muted.copyWith(color: scheme.mutedForeground),
          ),
        ],
      ),
    );
  }

  void _showMainOptions() {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('更多'),
        actions: [
          CupertinoActionSheetAction(
            child: const Text('新建书源'),
            onPressed: () {
              Navigator.pop(context);
              _createNewSource();
            },
          ),
          CupertinoActionSheetAction(
            child: const Text('本地导入'),
            onPressed: () {
              Navigator.pop(context);
              _importFromFile();
            },
          ),
          CupertinoActionSheetAction(
            child: const Text('网络导入'),
            onPressed: () {
              Navigator.pop(context);
              _importFromUrl();
            },
          ),
          CupertinoActionSheetAction(
            child: const Text('二维码导入'),
            onPressed: () {
              Navigator.pop(context);
              _importFromQrCode();
            },
          ),
          CupertinoActionSheetAction(
            child: Text(
              '${_groupSourcesByDomain ? '✓ ' : ''}按域名分组显示',
            ),
            onPressed: () {
              Navigator.pop(context);
              setState(() => _groupSourcesByDomain = !_groupSourcesByDomain);
            },
          ),
          CupertinoActionSheetAction(
            child: const Text('帮助'),
            onPressed: () {
              Navigator.pop(context);
              _showSourceManageHelp();
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

  void _showSortOptions() {
    void pickSort(_SourceSortMode mode) {
      setState(() => _sortMode = mode);
      Navigator.pop(context);
    }

    showCupertinoModalPopup<void>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('排序'),
        actions: [
          CupertinoActionSheetAction(
            child:
                Text('${_sortMode == _SourceSortMode.manual ? '✓ ' : ''}手动排序'),
            onPressed: () => pickSort(_SourceSortMode.manual),
          ),
          CupertinoActionSheetAction(
            child:
                Text('${_sortMode == _SourceSortMode.weight ? '✓ ' : ''}智能排序'),
            onPressed: () => pickSort(_SourceSortMode.weight),
          ),
          CupertinoActionSheetAction(
            child: Text('${_sortMode == _SourceSortMode.name ? '✓ ' : ''}名称排序'),
            onPressed: () => pickSort(_SourceSortMode.name),
          ),
          CupertinoActionSheetAction(
            child: Text('${_sortMode == _SourceSortMode.url ? '✓ ' : ''}地址排序'),
            onPressed: () => pickSort(_SourceSortMode.url),
          ),
          CupertinoActionSheetAction(
            child: Text(
                '${_sortMode == _SourceSortMode.update ? '✓ ' : ''}更新时间排序'),
            onPressed: () => pickSort(_SourceSortMode.update),
          ),
          CupertinoActionSheetAction(
            child: Text(
                '${_sortMode == _SourceSortMode.respond ? '✓ ' : ''}响应时间排序'),
            onPressed: () => pickSort(_SourceSortMode.respond),
          ),
          CupertinoActionSheetAction(
            child:
                Text('${_sortMode == _SourceSortMode.enabled ? '✓ ' : ''}是否启用'),
            onPressed: () => pickSort(_SourceSortMode.enabled),
          ),
          CupertinoActionSheetAction(
            child: Text('${!_sortAscending ? '✓ ' : ''}反序'),
            onPressed: () {
              setState(() => _sortAscending = !_sortAscending);
              Navigator.pop(context);
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

  void _showGroupFilterOptions() {
    final groups = _buildGroups(_normalizeSources(_sourceRepo.getAllSources()));
    showCupertinoModalPopup<void>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('分组'),
        actions: <Widget>[
          CupertinoActionSheetAction(
            child: const Text('分组管理'),
            onPressed: () {
              Navigator.pop(context);
              _showGroupManageSheet();
            },
          ),
          CupertinoActionSheetAction(
            child: const Text('已启用'),
            onPressed: () => _applySearchQuery('已启用', context),
          ),
          CupertinoActionSheetAction(
            child: const Text('已禁用'),
            onPressed: () => _applySearchQuery('已禁用', context),
          ),
          CupertinoActionSheetAction(
            child: const Text('需要登录'),
            onPressed: () => _applySearchQuery('需要登录', context),
          ),
          CupertinoActionSheetAction(
            child: const Text('未分组'),
            onPressed: () => _applySearchQuery('未分组', context),
          ),
          CupertinoActionSheetAction(
            child: const Text('已启用发现'),
            onPressed: () => _applySearchQuery('已启用发现', context),
          ),
          CupertinoActionSheetAction(
            child: const Text('已禁用发现'),
            onPressed: () => _applySearchQuery('已禁用发现', context),
          ),
          ...groups.map(
            (group) => CupertinoActionSheetAction(
              child: Text(group),
              onPressed: () => _applySearchQuery('group:$group', context),
            ),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          child: const Text('取消'),
          onPressed: () => Navigator.pop(context),
        ),
      ),
    );
  }

  void _applySearchQuery(String query, BuildContext popupContext) {
    setState(() {
      _searchController.text = query;
    });
    Navigator.pop(popupContext);
  }

  Future<void> _showGroupManageSheet() async {
    await showCupertinoModalPopup<void>(
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
                          final name = await _askGroupName('添加分组');
                          if (name == null || name.trim().isEmpty) return;
                          await _assignGroupToNoGroupSources(name.trim());
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
                  child: StreamBuilder<List<BookSource>>(
                    stream: _sourceRepo.watchAllSources(),
                    builder: (context, snapshot) {
                      final all = snapshot.data ?? _sourceRepo.getAllSources();
                      final groups = _buildGroups(_normalizeSources(all));
                      if (groups.isEmpty) {
                        return const SizedBox.shrink();
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
                                    final renamed = await _askGroupName(
                                      '编辑分组',
                                      initialValue: group,
                                    );
                                    if (renamed == null) return;
                                    await _renameGroup(group, renamed.trim());
                                  },
                                  child: const Text('编辑'),
                                ),
                                CupertinoButton(
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 6),
                                  minimumSize: const Size(36, 30),
                                  onPressed: () async {
                                    await _removeGroupEverywhere(group);
                                  },
                                  child: const Text(
                                    '删除',
                                    style: TextStyle(
                                      color: CupertinoColors.systemRed,
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

  Future<void> _showSourceActions(BookSource source) async {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: Text(source.bookSourceName),
        message: Text(source.bookSourceUrl),
        actions: [
          if (_sortMode == _SourceSortMode.manual)
            CupertinoActionSheetAction(
              child: const Text('置顶'),
              onPressed: () {
                Navigator.pop(context);
                _toTop(source);
              },
            ),
          if (_sortMode == _SourceSortMode.manual)
            CupertinoActionSheetAction(
              child: const Text('置底'),
              onPressed: () {
                Navigator.pop(context);
                _toBottom(source);
              },
            ),
          if ((source.loginUrl ?? '').trim().isNotEmpty)
            CupertinoActionSheetAction(
              child: const Text('登录'),
              onPressed: () {
                Navigator.pop(context);
                _openSourceLogin(source.bookSourceUrl);
              },
            ),
          CupertinoActionSheetAction(
            child: const Text('搜索'),
            onPressed: () async {
              Navigator.pop(context);
              await _openSourceScopedSearch(source);
            },
          ),
          CupertinoActionSheetAction(
            child: const Text('调试'),
            onPressed: () async {
              Navigator.pop(context);
              await _openSourceDebug(source);
            },
          ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            child: const Text('删除'),
            onPressed: () async {
              Navigator.pop(context);
              setState(() {
                _selectedUrls.remove(source.bookSourceUrl);
              });
              await _confirmDeleteSource(source);
            },
          ),
          if ((source.exploreUrl ?? '').trim().isNotEmpty)
            CupertinoActionSheetAction(
              child: Text(source.enabledExplore ? '禁用发现' : '启用发现'),
              onPressed: () async {
                Navigator.pop(context);
                await _toggleSourceExploreFromItemAction(source);
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

  Future<void> _confirmDeleteSource(BookSource source) async {
    await showCupertinoDialog<void>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('提醒'),
        content: Text('是否确认删除？\n${source.bookSourceName}'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () async {
              Navigator.pop(ctx);
              await _deleteSourceByLegacyRule(source.bookSourceUrl);
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteSourceByLegacyRule(String sourceUrl) async {
    await _sourceRepo.deleteSource(sourceUrl);
    await SourceVariableStore.removeVariable(sourceUrl);
  }

  Future<void> _toTop(BookSource source) async {
    final toTop = _sortAscending;
    await _moveSourcesToTopBottom([source], toTop: toTop);
  }

  Future<void> _toBottom(BookSource source) async {
    final toTop = !_sortAscending;
    await _moveSourcesToTopBottom([source], toTop: toTop);
  }

  Future<void> _moveSourcesToTopBottom(
    List<BookSource> sources, {
    required bool toTop,
  }) async {
    if (sources.isEmpty) return;
    final moveSourcesHandler = widget.moveSourcesHandler;
    if (moveSourcesHandler != null) {
      await moveSourcesHandler(sources, toTop: toTop);
      return;
    }
    final all = _sourceRepo.getAllSources();
    if (all.isEmpty) return;

    final sorted = sources.toList(growable: false)
      ..sort((a, b) => a.customOrder.compareTo(b.customOrder));

    if (toTop) {
      final minOrder = all.map((e) => e.customOrder).reduce(math.min) - 1;
      final updated = sorted
          .asMap()
          .entries
          .map(
            (entry) => entry.value.copyWith(customOrder: minOrder - entry.key),
          )
          .toList(growable: false);
      await _sourceRepo.addSources(updated);
      return;
    }

    final maxOrder = all.map((e) => e.customOrder).reduce(math.max) + 1;
    final updated = sorted
        .asMap()
        .entries
        .map(
          (entry) => entry.value.copyWith(customOrder: maxOrder + entry.key),
        )
        .toList(growable: false);
    await _sourceRepo.addSources(updated);
  }

  Future<void> _batchMoveToTopBottom(
    List<BookSource> allSources,
    bool toTop,
  ) async {
    final selected = _selectedSources(allSources);
    if (selected.isEmpty) {
      _showMessage('当前未选择书源');
      return;
    }
    await _moveSourcesToTopBottom(selected, toTop: toTop);
    _showMessage('已${toTop ? '置顶' : '置底'} ${selected.length} 条书源');
  }

  Future<void> _batchCheckSelected(List<BookSource> allSources) async {
    final selected = _selectedSources(allSources);
    if (selected.isEmpty) {
      _showMessage('当前未选择书源');
      return;
    }
    final keyword = await _askCheckKeyword();
    if (keyword == null) return;
    final checkSettings = _loadCheckSettings();
    if (!checkSettings.checkSearch && !checkSettings.checkDiscovery) {
      _showMessage('至少启用一种校验方式');
      return;
    }
    final startResult = await _checkTaskService.start(
      SourceCheckTaskConfig(
        includeDisabled: true,
        sourceUrls:
            selected.map((e) => e.bookSourceUrl).toList(growable: false),
        keywordOverride: keyword,
        timeoutMs: checkSettings.timeoutMs,
        checkSearch: checkSettings.checkSearch,
        checkDiscovery: checkSettings.checkDiscovery,
        checkInfo: checkSettings.checkInfo,
        checkCategory: checkSettings.checkCategory,
        checkContent: checkSettings.checkContent,
      ),
      forceRestart: true,
    );
    if (startResult.type == SourceCheckStartType.runningOtherTask) {
      _showMessage(startResult.message);
      return;
    }
    if (startResult.type == SourceCheckStartType.emptySource) {
      _showMessage(startResult.message);
      return;
    }
    if (startResult.type == SourceCheckStartType.attachedExisting) {
      _showMessage(startResult.message);
      return;
    }
    _showMessage('已开始校验（${selected.length} 条）');
  }

  GlobalKey _itemKeyForUrl(String url) {
    return _itemKeyByUrl.putIfAbsent(
      url,
      () => GlobalKey(debugLabel: 'source-item-$url'),
    );
  }

  void _startDragSelection(List<BookSource> visible, int index) {
    if (index < 0 || index >= visible.length) return;
    final url = visible[index].bookSourceUrl;
    final nextValue = !_selectedUrls.contains(url);
    setState(() {
      _dragSelecting = true;
      _dragSelectValue = nextValue;
      _dragLastIndex = -1;
      _applyDragSelectionAt(visible, index);
    });
  }

  void _updateDragSelectionByGlobal(
    List<BookSource> visible,
    Offset globalPosition,
  ) {
    if (!_dragSelecting) return;
    final hitIndex = _hitTestVisibleIndexByGlobal(visible, globalPosition);
    if (hitIndex == null || hitIndex == _dragLastIndex) return;
    setState(() {
      _applyDragSelectionAt(visible, hitIndex);
    });
  }

  void _autoScrollForDragSelection(
    List<BookSource> visible,
    Offset globalPosition,
  ) {
    if (!_dragSelecting || !_listScrollController.hasClients) return;
    final viewportContext = _listViewportKey.currentContext;
    if (viewportContext == null) return;
    final viewportObject = viewportContext.findRenderObject();
    if (viewportObject is! RenderBox ||
        !viewportObject.hasSize ||
        !viewportObject.attached) {
      return;
    }
    final localOffset = viewportObject.globalToLocal(globalPosition);
    final viewportHeight = viewportObject.size.height;
    if (viewportHeight <= 0) return;

    const edgePadding = 64.0;
    const maxStep = 26.0;
    var delta = 0.0;
    if (localOffset.dy < edgePadding) {
      final ratio =
          ((edgePadding - localOffset.dy) / edgePadding).clamp(0.0, 1.0);
      delta = -maxStep * ratio;
    } else if (localOffset.dy > viewportHeight - edgePadding) {
      final ratio =
          ((localOffset.dy - (viewportHeight - edgePadding)) / edgePadding)
              .clamp(0.0, 1.0);
      delta = maxStep * ratio;
    }
    if (delta == 0) return;

    final position = _listScrollController.position;
    final target = (position.pixels + delta).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    if ((target - position.pixels).abs() < 0.5) return;
    _listScrollController.jumpTo(target);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_dragSelecting) return;
      _updateDragSelectionByGlobal(visible, globalPosition);
    });
  }

  void _endDragSelection() {
    if (!_dragSelecting) return;
    setState(() {
      _dragSelecting = false;
      _dragLastIndex = -1;
    });
  }

  int? _hitTestVisibleIndexByGlobal(
    List<BookSource> visible,
    Offset globalPosition,
  ) {
    for (var index = 0; index < visible.length; index++) {
      final url = visible[index].bookSourceUrl;
      final key = _itemKeyForUrl(url);
      final context = key.currentContext;
      if (context == null) continue;
      final object = context.findRenderObject();
      if (object is! RenderBox || !object.hasSize || !object.attached) {
        continue;
      }
      final rect = object.localToGlobal(Offset.zero) & object.size;
      if (rect.contains(globalPosition)) {
        return index;
      }
    }
    return null;
  }

  void _applyDragSelectionAt(List<BookSource> visible, int index) {
    if (index < 0 || index >= visible.length) return;
    final currentIndex = index;
    _dragLastIndex = currentIndex;
    final url = visible[currentIndex].bookSourceUrl;
    if (_dragSelectValue) {
      _selectedUrls.add(url);
      return;
    }
    _selectedUrls.remove(url);
  }

  void _toggleSelection(String url) {
    if (_selectedUrls.contains(url)) {
      _selectedUrls.remove(url);
    } else {
      _selectedUrls.add(url);
    }
  }

  void _expandSelectionInterval(List<BookSource> visible) {
    if (_selectedUrls.isEmpty || visible.isEmpty) return;
    final selectedIndexes = <int>[];
    for (var i = 0; i < visible.length; i++) {
      if (_selectedUrls.contains(visible[i].bookSourceUrl)) {
        selectedIndexes.add(i);
      }
    }
    if (selectedIndexes.isEmpty) return;

    final minIndex = selectedIndexes.reduce(math.min);
    final maxIndex = selectedIndexes.reduce(math.max);
    for (var i = minIndex; i <= maxIndex; i++) {
      _selectedUrls.add(visible[i].bookSourceUrl);
    }
  }

  List<BookSource> _selectedSources(List<BookSource> allSources) {
    return allSources
        .where((source) => _selectedUrls.contains(source.bookSourceUrl))
        .toList(growable: false);
  }

  Future<void> _batchSetEnabled(
      List<BookSource> allSources, bool enabled) async {
    final targets = _selectedSources(allSources)
        .where((s) => s.enabled != enabled)
        .toList(growable: false);
    if (targets.isEmpty) {
      _showMessage(enabled ? '所选书源已全部启用' : '所选书源已全部禁用');
      return;
    }
    await Future.wait(
      targets
          .map((s) => _sourceRepo.updateSource(s.copyWith(enabled: enabled))),
    );
    _showMessage('${enabled ? '已启用' : '已禁用'} ${targets.length} 条书源');
  }

  Future<void> _batchSetExplore(
      List<BookSource> allSources, bool enabled) async {
    final targets = _selectedSources(allSources)
        .where((s) => s.enabledExplore != enabled)
        .toList(growable: false);
    if (targets.isEmpty) {
      _showMessage(enabled ? '所选书源发现已全部启用' : '所选书源发现已全部禁用');
      return;
    }

    await Future.wait(
      targets.map(
        (s) => _sourceRepo.updateSource(s.copyWith(enabledExplore: enabled)),
      ),
    );
    _showMessage('${enabled ? '已启用' : '已禁用'} ${targets.length} 条书源的发现');
  }

  Future<void> _batchAddGroup(List<BookSource> allSources) async {
    final groupInput = await _askGroupName('加入分组');
    if (groupInput == null || groupInput.trim().isEmpty) return;
    final addGroups = _extractGroups(groupInput);
    if (addGroups.isEmpty) return;
    final selected = _selectedSources(allSources);
    if (selected.isEmpty) {
      _showMessage('当前未选择书源');
      return;
    }
    await Future.wait(selected.map((source) async {
      final groups = _extractGroups(source.bookSourceGroup);
      groups.addAll(addGroups);
      await _sourceRepo.updateSource(
        _copySourceWithGroup(source, _joinGroups(groups)),
      );
    }));
    _showMessage('已将 ${selected.length} 条书源加入分组');
  }

  Future<void> _batchRemoveGroup(List<BookSource> allSources) async {
    final groupInput = await _askGroupName('移除分组');
    if (groupInput == null || groupInput.trim().isEmpty) return;
    final removeGroups = _extractGroups(groupInput).toSet();
    if (removeGroups.isEmpty) return;
    final selected = _selectedSources(allSources);
    if (selected.isEmpty) {
      _showMessage('当前未选择书源');
      return;
    }

    await Future.wait(selected.map((source) async {
      final groups = _extractGroups(source.bookSourceGroup);
      groups.removeWhere(removeGroups.contains);
      await _sourceRepo.updateSource(
        _copySourceWithGroup(source, _joinGroups(groups)),
      );
    }));
    _showMessage('已从 ${selected.length} 条书源移除分组');
  }

  Future<void> _batchDeleteSelected(List<BookSource> allSources) async {
    final selected = _selectedSources(allSources);
    if (selected.isEmpty) {
      _showMessage('当前未选择书源');
      return;
    }

    final ok = await showCupertinoDialog<bool>(
          context: context,
          builder: (ctx) => CupertinoAlertDialog(
            title: const Text('批量删除'),
            content: Text('\n将删除 ${selected.length} 条书源，此操作不可撤销。'),
            actions: [
              CupertinoDialogAction(
                isDestructiveAction: true,
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('确认删除'),
              ),
              CupertinoDialogAction(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('取消'),
              ),
            ],
          ),
        ) ??
        false;
    if (!ok) return;

    await Future.wait(
      selected.map((source) => _sourceRepo.deleteSource(source.bookSourceUrl)),
    );

    setState(() {
      _selectedUrls.clear();
    });
    _showMessage('已删除 ${selected.length} 条书源');
  }

  List<BookSource> _resolveExportShareSources(List<BookSource> visibleSources) {
    final selected = _selectedSources(visibleSources);
    if (selected.isEmpty || visibleSources.isEmpty) {
      return const <BookSource>[];
    }

    // 规则：
    // 全选 -> 导出当前筛选集；
    // 低比例选中 -> 导出选中集；
    // 中高比例选中 -> 按当前筛选顺序过滤选中键。
    final selectedRate = selected.length / visibleSources.length;
    if (selected.length == visibleSources.length) {
      return visibleSources;
    }
    if (selectedRate < 0.3) {
      return selected;
    }
    final selectedKeys = selected.map((source) => source.bookSourceUrl).toSet();
    return visibleSources
        .where((source) => selectedKeys.contains(source.bookSourceUrl))
        .toList(growable: false);
  }

  Future<void> _batchExportSelected(List<BookSource> allSources) async {
    final sources = _resolveExportShareSources(allSources);
    if (sources.isEmpty) {
      _showMessage('当前未选择书源');
      return;
    }
    final result = await _importExportService.exportToFile(
      sources,
      defaultFileName: 'bookSource.json',
    );
    if (result.cancelled) {
      return;
    }
    if (!result.success) {
      _showMessage(result.errorMessage ?? '导出失败');
      return;
    }
    final path = (result.outputPath ?? '').trim();
    if (path.isEmpty) {
      _showMessage('导出成功');
      return;
    }
    await _showExportPathDialog(path);
  }

  Future<void> _batchShareSelected(List<BookSource> allSources) async {
    final sources = _resolveExportShareSources(allSources);
    if (sources.isEmpty) {
      _showMessage('当前未选择书源');
      return;
    }
    try {
      final file = await _importExportService.exportToShareFile(sources);
      if (file != null) {
        await SharePlus.instance.share(
          ShareParams(
            files: [XFile(file.path, mimeType: 'application/json')],
            text: 'SoupReader 书源（${sources.length} 条）',
            subject: 'bookSource.json',
          ),
        );
        _showMessage('已打开系统分享（${sources.length} 条书源）');
        return;
      }
    } catch (_) {
      // ignore and fallback
    }

    final text = LegadoJson.encode(sources.map((s) => s.toJson()).toList());
    await Clipboard.setData(ClipboardData(text: text));
    _showMessage('系统分享不可用，已复制 ${sources.length} 条书源 JSON');
  }

  Future<List<BookSource>> _loadAllSourcesForMutation() async {
    final db = _db.driftDb;
    final rows = await db.select(db.sourceRecords).get();
    if (rows.isEmpty) {
      return const <BookSource>[];
    }
    final sources = <BookSource>[];
    for (final row in rows) {
      final raw = (row.rawJson ?? '').trim();
      if (raw.isNotEmpty) {
        try {
          final decoded = jsonDecode(raw);
          if (decoded is Map<String, dynamic>) {
            sources.add(BookSource.fromJson(decoded));
            continue;
          }
          if (decoded is Map) {
            sources.add(
              BookSource.fromJson(
                decoded.map((key, value) => MapEntry('$key', value)),
              ),
            );
            continue;
          }
        } catch (_) {
          // ignore and fallback to table fields
        }
      }
      sources.add(
        BookSource.fromJson({
          'bookSourceUrl': row.bookSourceUrl,
          'bookSourceName': row.bookSourceName,
          'bookSourceGroup': row.bookSourceGroup,
          'bookSourceType': row.bookSourceType,
          'enabled': row.enabled,
          'enabledExplore': row.enabledExplore,
          'enabledCookieJar': row.enabledCookieJar ?? true,
          'weight': row.weight,
          'customOrder': row.customOrder,
          'respondTime': row.respondTime,
          'header': row.header,
          'loginUrl': row.loginUrl,
          'bookSourceComment': row.bookSourceComment,
          'lastUpdateTime': row.lastUpdateTime,
        }),
      );
    }
    return _normalizeSources(sources);
  }

  Future<void> _assignGroupToNoGroupSources(String group) async {
    final all = await _loadAllSourcesForMutation();
    final targets = all
        .where((s) => (s.bookSourceGroup ?? '').trim().isEmpty)
        .toList(growable: false);
    if (targets.isEmpty) return;
    await Future.wait(
      targets.map(
        (s) => _sourceRepo.updateSource(_copySourceWithGroup(s, group)),
      ),
    );
  }

  Future<void> _renameGroup(String oldGroup, String newGroup) async {
    final normalized = newGroup.trim();
    final all = await _loadAllSourcesForMutation();
    final targets = all.where((s) {
      return _extractGroups(s.bookSourceGroup).contains(oldGroup);
    }).toList(growable: false);
    if (targets.isEmpty) return;

    await Future.wait(targets.map((source) async {
      final groups = _extractGroups(source.bookSourceGroup);
      if (!groups.remove(oldGroup)) return;
      if (normalized.isNotEmpty) {
        groups.add(normalized);
      }
      await _sourceRepo.updateSource(
        _copySourceWithGroup(source, _joinGroups(groups)),
      );
    }));
  }

  Future<void> _removeGroupEverywhere(String group) async {
    final all = await _loadAllSourcesForMutation();
    final targets = all.where((s) {
      return _extractGroups(s.bookSourceGroup).contains(group);
    }).toList(growable: false);

    await Future.wait(targets.map((source) async {
      final groups = _extractGroups(source.bookSourceGroup);
      groups.remove(group);
      await _sourceRepo.updateSource(
        _copySourceWithGroup(source, _joinGroups(groups)),
      );
    }));
  }

  BookSource _copySourceWithGroup(BookSource source, String? group) {
    final normalized = (group ?? '').trim();
    return source.copyWith(bookSourceGroup: normalized);
  }

  List<String> _extractGroups(String? raw) {
    final text = raw?.trim();
    if (text == null || text.isEmpty) return <String>[];
    return text
        .split(RegExp(r'[,;，；]'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();
  }

  bool _matchesGroupQueryLegacy(String? rawGroup, String key) {
    final group = rawGroup ?? '';
    if (group == key) return true;
    if (group.startsWith('$key,')) return true;
    if (group.endsWith(',$key')) return true;
    if (group.contains(',$key,')) return true;
    return false;
  }

  String? _joinGroups(List<String> groups) {
    if (groups.isEmpty) return null;
    return groups.toSet().join(',');
  }

  Future<String?> _askGroupName(String title, {String? initialValue}) async {
    final controller = TextEditingController(text: initialValue ?? '');
    final allGroups =
        _buildGroups(_normalizeSources(_sourceRepo.getAllSources()));
    final value = await showCupertinoDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          final q = controller.text.trim().toLowerCase();
          final quickGroups = allGroups
              .where((group) {
                if (q.isEmpty) return true;
                return group.toLowerCase().contains(q);
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
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('取消'),
              ),
              CupertinoDialogAction(
                onPressed: () => Navigator.pop(dialogContext, controller.text),
                child: const Text('确定'),
              ),
            ],
          );
        },
      ),
    );
    controller.dispose();
    return value;
  }

  _CheckSettings _loadCheckSettings() {
    final timeout = _settingsGetInt(
      _prefCheckTimeoutMs,
      defaultValue: 180000,
    );
    final normalizedTimeout = timeout > 0 ? timeout : 180000;
    final checkInfo = _settingsGetBool(_prefCheckInfo, defaultValue: true);
    final checkCategory =
        checkInfo && _settingsGetBool(_prefCheckCategory, defaultValue: true);
    final checkContent = checkCategory &&
        _settingsGetBool(_prefCheckContent, defaultValue: true);
    return _CheckSettings(
      timeoutMs: normalizedTimeout,
      checkSearch: _settingsGetBool(_prefCheckSearch, defaultValue: true),
      checkDiscovery: _settingsGetBool(_prefCheckDiscovery, defaultValue: true),
      checkInfo: checkInfo,
      checkCategory: checkCategory,
      checkContent: checkContent,
    );
  }

  Future<bool> _showCheckSettingsDialog() async {
    if (!_ensureSettingsReady(actionName: '保存校验设置')) {
      return false;
    }
    final current = _loadCheckSettings();
    var checkSearch = current.checkSearch;
    var checkDiscovery = current.checkDiscovery;
    var checkInfo = current.checkInfo;
    var checkCategory = current.checkCategory;
    var checkContent = current.checkContent;
    final timeoutCtrl = TextEditingController(
      text: (current.timeoutMs ~/ 1000).toString(),
    );

    try {
      final saved = await showCupertinoDialog<bool>(
        context: context,
        builder: (ctx) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              return CupertinoAlertDialog(
                title: const Text('校验设置'),
                content: Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Column(
                    children: [
                      CupertinoTextField(
                        controller: timeoutCtrl,
                        keyboardType: TextInputType.number,
                        placeholder: '超时时间（秒）',
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          const Expanded(child: Text('校验搜索')),
                          CupertinoSwitch(
                            value: checkSearch,
                            onChanged: (value) {
                              setDialogState(() {
                                checkSearch = value;
                                if (!checkSearch && !checkDiscovery) {
                                  checkDiscovery = true;
                                }
                              });
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Expanded(child: Text('校验发现')),
                          CupertinoSwitch(
                            value: checkDiscovery,
                            onChanged: (value) {
                              setDialogState(() {
                                checkDiscovery = value;
                                if (!checkSearch && !checkDiscovery) {
                                  checkSearch = true;
                                }
                              });
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Expanded(child: Text('校验详情')),
                          CupertinoSwitch(
                            value: checkInfo,
                            onChanged: (value) {
                              setDialogState(() {
                                checkInfo = value;
                                if (!checkInfo) {
                                  checkCategory = false;
                                  checkContent = false;
                                }
                              });
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Expanded(child: Text('校验目录')),
                          CupertinoSwitch(
                            value: checkCategory,
                            onChanged: !checkInfo
                                ? null
                                : (value) {
                                    setDialogState(() {
                                      checkCategory = value;
                                      if (!checkCategory) {
                                        checkContent = false;
                                      }
                                    });
                                  },
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Expanded(child: Text('校验正文')),
                          CupertinoSwitch(
                            value: checkContent,
                            onChanged: !checkCategory
                                ? null
                                : (value) {
                                    setDialogState(() {
                                      checkContent = value;
                                    });
                                  },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                actions: [
                  CupertinoDialogAction(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('取消'),
                  ),
                  CupertinoDialogAction(
                    onPressed: () async {
                      final timeoutSeconds =
                          int.tryParse(timeoutCtrl.text.trim()) ?? 0;
                      if (timeoutSeconds <= 0) {
                        _showMessage('超时时间需大于0秒');
                        return;
                      }
                      if (!checkSearch && !checkDiscovery) {
                        _showMessage('至少启用一种校验方式');
                        return;
                      }
                      final timeoutSaved = await _settingsPut(
                        _prefCheckTimeoutMs,
                        timeoutSeconds * 1000,
                      );
                      if (!timeoutSaved) return;
                      final searchSaved =
                          await _settingsPut(_prefCheckSearch, checkSearch);
                      if (!searchSaved) return;
                      final discoverySaved = await _settingsPut(
                        _prefCheckDiscovery,
                        checkDiscovery,
                      );
                      if (!discoverySaved) return;
                      final infoSaved =
                          await _settingsPut(_prefCheckInfo, checkInfo);
                      if (!infoSaved) return;
                      final categorySaved = await _settingsPut(
                        _prefCheckCategory,
                        checkInfo && checkCategory,
                      );
                      if (!categorySaved) return;
                      final contentSaved = await _settingsPut(
                        _prefCheckContent,
                        checkInfo && checkCategory && checkContent,
                      );
                      if (!contentSaved) return;
                      if (!ctx.mounted) return;
                      Navigator.pop(ctx, true);
                    },
                    child: const Text('保存'),
                  ),
                ],
              );
            },
          );
        },
      );
      return saved == true;
    } finally {
      timeoutCtrl.dispose();
    }
  }

  Future<_CheckKeywordDialogResult?> _showCheckKeywordDialog(
    String initialKeyword,
  ) async {
    final controller = TextEditingController(text: initialKeyword);
    try {
      return await showCupertinoDialog<_CheckKeywordDialogResult>(
        context: context,
        builder: (ctx) => CupertinoAlertDialog(
          title: const Text('校验关键词'),
          content: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: CupertinoTextField(
              controller: controller,
              placeholder: '输入搜索关键词',
            ),
          ),
          actions: [
            CupertinoDialogAction(
              onPressed: () {
                Navigator.pop(
                  ctx,
                  _CheckKeywordDialogResult(
                    action: _CheckKeywordDialogAction.cancel,
                    keyword: controller.text,
                  ),
                );
              },
              child: const Text('取消'),
            ),
            CupertinoDialogAction(
              onPressed: () {
                Navigator.pop(
                  ctx,
                  _CheckKeywordDialogResult(
                    action: _CheckKeywordDialogAction.openSettings,
                    keyword: controller.text,
                  ),
                );
              },
              child: const Text('校验设置'),
            ),
            CupertinoDialogAction(
              onPressed: () {
                Navigator.pop(
                  ctx,
                  _CheckKeywordDialogResult(
                    action: _CheckKeywordDialogAction.start,
                    keyword: controller.text,
                  ),
                );
              },
              child: const Text('开始校验'),
            ),
          ],
        ),
      );
    } finally {
      controller.dispose();
    }
  }

  Future<String?> _askCheckKeyword() async {
    if (!_ensureSettingsReady(actionName: '保存校验关键词')) {
      return null;
    }
    final cached = (_settingsGet(_prefCheckKeyword, defaultValue: '我的') ?? '我的')
        .toString();
    var draft = cached;
    while (mounted) {
      final dialogResult = await _showCheckKeywordDialog(draft);
      if (dialogResult == null ||
          dialogResult.action == _CheckKeywordDialogAction.cancel) {
        return null;
      }
      draft = dialogResult.keyword;
      if (dialogResult.action == _CheckKeywordDialogAction.openSettings) {
        await _showCheckSettingsDialog();
        continue;
      }
      final normalized = dialogResult.keyword.trim();
      final keyword = normalized.isNotEmpty
          ? normalized
          : (cached.trim().isNotEmpty ? cached.trim() : '我的');
      await _settingsPut(_prefCheckKeyword, keyword);
      return keyword;
    }
    return null;
  }

  Future<void> _showSourceManageHelp() async {
    try {
      final markdownText =
          await rootBundle.loadString('assets/web/help/md/SourceMBookHelp.md');
      if (!mounted) return;
      await showAppHelpDialog(context, markdownText: markdownText);
    } catch (error) {
      if (!mounted) return;
      await showCupertinoDialog<void>(
        context: context,
        builder: (dialogContext) => CupertinoAlertDialog(
          title: const Text('帮助'),
          content: Text('帮助文档加载失败：$error'),
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

  Future<void> _maybeShowSourceManageHelpOnce() async {
    final shown = _settingsGetBool(
      _prefSourceManageHelpShown,
      defaultValue: false,
    );
    if (shown) return;
    await _settingsPut(_prefSourceManageHelpShown, true);
    if (!mounted) return;
    await _showSourceManageHelp();
  }

  Future<void> _createNewSource() async {
    final template = {
      'bookSourceUrl': '',
      'bookSourceName': '',
      'bookSourceGroup': null,
      'bookSourceType': 0,
      'customOrder': 0,
      'enabled': true,
      'enabledExplore': true,
      'enabledCookieJar': true,
      'respondTime': 180000,
      'weight': 0,
      'searchUrl': null,
      'exploreUrl': null,
      'ruleSearch': null,
      'ruleBookInfo': null,
      'ruleToc': null,
      'ruleContent': null,
    };
    await Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (_) => SourceEditLegacyView(
          initialRawJson: LegadoJson.encode(template),
          originalUrl: null,
        ),
      ),
    );
  }

  Future<void> _openEditor(
    String bookSourceUrl, {
    int? initialTab,
    String? initialDebugKey,
  }) async {
    final source = _sourceRepo.getSourceByUrl(bookSourceUrl);
    if (source == null) {
      _showMessage('书源不存在或已被删除');
      return;
    }
    await Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (_) {
          final raw = _sourceRepo.getRawJsonByUrl(source.bookSourceUrl);
          if (initialTab == 3 || (initialDebugKey ?? '').trim().isNotEmpty) {
            return SourceDebugLegacyView(
              source: source,
              initialDebugKey: initialDebugKey,
            );
          }
          return SourceEditLegacyView.fromSource(
            source,
            rawJson: raw,
            initialTab: initialTab,
          );
        },
      ),
    );
  }

  Future<void> _openSourceLogin(String bookSourceUrl) async {
    final source = _sourceRepo.getSourceByUrl(bookSourceUrl);
    if (source == null) {
      _showMessage('未找到书源');
      return;
    }

    if (SourceLoginUiHelper.hasLoginUi(source.loginUi)) {
      await Navigator.of(context).push(
        CupertinoPageRoute<void>(
          builder: (_) => SourceLoginFormView(source: source),
        ),
      );
      return;
    }

    final resolvedUrl = SourceLoginUrlResolver.resolve(
      baseUrl: source.bookSourceUrl,
      loginUrl: source.loginUrl ?? '',
    );
    if (resolvedUrl.isEmpty) {
      _showMessage('当前书源未配置登录地址');
      return;
    }
    final uri = Uri.tryParse(resolvedUrl);
    final scheme = uri?.scheme.toLowerCase();
    if (scheme != 'http' && scheme != 'https') {
      _showMessage('登录地址不是有效网页地址');
      return;
    }

    await Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (_) => SourceWebVerifyView(initialUrl: resolvedUrl),
      ),
    );
  }

  Future<void> _toggleSourceExploreFromItemAction(BookSource source) async {
    final currentSource = _sourceRepo.getSourceByUrl(source.bookSourceUrl);
    if (currentSource == null) {
      return;
    }
    final nextEnabledExplore = !source.enabledExplore;
    if (currentSource.enabledExplore == nextEnabledExplore) {
      return;
    }
    await _sourceRepo.updateSource(
      currentSource.copyWith(enabledExplore: nextEnabledExplore),
    );
  }

  Future<void> _openSourceDebug(BookSource source) async {
    if (!mounted) return;
    await Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (_) => SourceDebugLegacyView(
          source: source,
        ),
      ),
    );
  }

  Future<void> _openSourceScopedSearch(BookSource source) async {
    final nextScope = SearchScope.fromSource(source);
    final currentSettings = _settingsService.appSettings;
    if (currentSettings.searchScope != nextScope) {
      unawaited(
        _settingsService.saveAppSettings(
          currentSettings.copyWith(searchScope: nextScope),
        ),
      );
    }
    if (!mounted) return;
    await Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (_) => const SearchView(),
      ),
    );
  }

  Future<void> _importFromFile() async {
    final result = await _importExportService.importFromFile();
    await _commitImportResult(result);
  }

  Future<void> _importFromQrCode() async {
    final text = await QrScanService.scanText(
      context,
      title: '二维码导入',
    );
    final value = text?.trim();
    if (value == null || value.isEmpty) {
      return;
    }
    final result = await _importExportService.importFromText(value);
    await _commitImportResult(result);
  }

  Future<void> _importFromUrl() async {
    _urlController.clear();
    final history = _loadOnlineImportHistory();
    final url = await showCupertinoModalPopup<String>(
      context: context,
      builder: (context) {
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
                            onPressed: () => Navigator.pop(context),
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
                              controller: _urlController,
                              placeholder: '输入书源网址',
                            ),
                          ),
                          const SizedBox(width: 8),
                          CupertinoButton.filled(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            onPressed: () {
                              Navigator.pop(context, _urlController.text);
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
                          ? Center(
                              child: Text(
                                '暂无历史记录',
                                style: TextStyle(
                                  color: CupertinoColors.secondaryLabel
                                      .resolveFrom(context),
                                ),
                              ),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                              itemCount: history.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 6),
                              itemBuilder: (context, index) {
                                final item = history[index];
                                return Container(
                                  decoration: BoxDecoration(
                                    color: CupertinoColors.systemGrey6
                                        .resolveFrom(context),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  padding:
                                      const EdgeInsets.fromLTRB(10, 8, 8, 8),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: GestureDetector(
                                          onTap: () {
                                            _urlController.text = item;
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
                                        child: const Icon(
                                          CupertinoIcons.delete,
                                          size: 18,
                                          color: CupertinoColors.systemRed,
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

    final normalizedUrl = url?.trim();
    if (normalizedUrl == null || normalizedUrl.isEmpty) return;

    final isHttpUrl = normalizedUrl.startsWith('http://') ||
        normalizedUrl.startsWith('https://');
    if (isHttpUrl) {
      await _pushImportHistory(normalizedUrl);
    }

    final result = isHttpUrl
        ? await _importExportService.importFromUrl(normalizedUrl)
        : await _importExportService.importFromText(normalizedUrl);
    await _commitImportResult(result);
  }

  List<String> _loadOnlineImportHistory() {
    final raw = _settingsGet(_prefImportOnlineHistory);
    if (raw is List) {
      return raw
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toSet()
          .toList(growable: true);
    }
    if (raw is String) {
      return raw
          .split(RegExp(r'[\n,]'))
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toSet()
          .toList(growable: true);
    }
    return <String>[];
  }

  Future<void> _saveOnlineImportHistory(List<String> history) async {
    final normalized = history
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList(growable: true);
    await _settingsPut(_prefImportOnlineHistory, normalized);
  }

  Future<void> _pushImportHistory(String url) async {
    final history = _loadOnlineImportHistory();
    history.remove(url);
    history.insert(0, url);
    await _saveOnlineImportHistory(history);
  }

  String _importStateLabel(SourceImportCandidateState state) {
    return switch (state) {
      SourceImportCandidateState.newSource => '新增',
      SourceImportCandidateState.update => '更新',
      SourceImportCandidateState.existing => '已有',
    };
  }

  Color _importStateColor(SourceImportCandidateState state) {
    return switch (state) {
      SourceImportCandidateState.newSource =>
        CupertinoColors.systemGreen.resolveFrom(context),
      SourceImportCandidateState.update =>
        CupertinoColors.systemOrange.resolveFrom(context),
      SourceImportCandidateState.existing =>
        CupertinoColors.secondaryLabel.resolveFrom(context),
    };
  }

  Future<_ImportSelectionDecision?> _showImportSelectionDialog(
    List<SourceImportCandidate> candidates,
  ) async {
    final dialogCandidates = candidates.toList(growable: true);
    final selectedIndexes = <int>{};
    final defaultUrls =
        SourceImportSelectionHelper.defaultSelectedUrls(dialogCandidates);
    for (var index = 0; index < dialogCandidates.length; index++) {
      final candidate = dialogCandidates[index];
      if (defaultUrls.contains(candidate.url)) {
        selectedIndexes.add(index);
      }
    }
    var keepName = _settingsGetBool(_prefImportKeepName, defaultValue: false);
    var keepGroup = _settingsGetBool(_prefImportKeepGroup, defaultValue: false);
    var keepEnable =
        _settingsGetBool(_prefImportKeepEnable, defaultValue: false);
    var appendCustomGroup = false;
    final groupController = TextEditingController();

    try {
      return await showCupertinoModalPopup<_ImportSelectionDecision>(
        context: context,
        builder: (popupContext) {
          return CupertinoPopupSurface(
            isSurfacePainted: true,
            child: StatefulBuilder(
              builder: (context, setDialogState) {
                final selectedCount = selectedIndexes.length;
                final totalCount = dialogCandidates.length;
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
                                '导入书源',
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
                              onPressed: selectedCount == 0
                                  ? null
                                  : () async {
                                      await Future.wait([
                                        _settingsPut(
                                          _prefImportKeepName,
                                          keepName,
                                        ),
                                        _settingsPut(
                                          _prefImportKeepGroup,
                                          keepGroup,
                                        ),
                                        _settingsPut(
                                          _prefImportKeepEnable,
                                          keepEnable,
                                        ),
                                      ]);
                                      if (!context.mounted) return;
                                      Navigator.pop(
                                        context,
                                        _ImportSelectionDecision(
                                          candidates: dialogCandidates.toList(
                                              growable: false),
                                          policy: SourceImportSelectionPolicy(
                                            selectedUrls: selectedIndexes
                                                .map((index) =>
                                                    dialogCandidates[index].url)
                                                .toSet(),
                                            selectedIndexes:
                                                selectedIndexes.toSet(),
                                            keepName: keepName,
                                            keepGroup: keepGroup,
                                            keepEnabled: keepEnable,
                                            customGroup: groupController.text,
                                            appendCustomGroup:
                                                appendCustomGroup,
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
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            CupertinoButton(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              color: CupertinoColors.systemGrey5
                                  .resolveFrom(context),
                              onPressed: () {
                                setDialogState(() {
                                  if (selectedIndexes.length ==
                                      dialogCandidates.length) {
                                    selectedIndexes.clear();
                                  } else {
                                    selectedIndexes
                                      ..clear()
                                      ..addAll(
                                        List<int>.generate(
                                          dialogCandidates.length,
                                          (index) => index,
                                        ),
                                      );
                                  }
                                });
                              },
                              child: Text(
                                selectedIndexes.length ==
                                        dialogCandidates.length
                                    ? '取消全选'
                                    : '全选',
                              ),
                            ),
                            CupertinoButton(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              color: CupertinoColors.systemGrey5
                                  .resolveFrom(context),
                              onPressed: () {
                                setDialogState(() {
                                  final targetIndexes = <int>{
                                    for (var index = 0;
                                        index < dialogCandidates.length;
                                        index++)
                                      if (dialogCandidates[index].state ==
                                          SourceImportCandidateState.newSource)
                                        index,
                                  };
                                  final allTargetSelected = targetIndexes
                                      .every(selectedIndexes.contains);
                                  if (allTargetSelected) {
                                    selectedIndexes.removeWhere(
                                      targetIndexes.contains,
                                    );
                                  } else {
                                    selectedIndexes.addAll(targetIndexes);
                                  }
                                });
                              },
                              child: const Text('选择新增'),
                            ),
                            CupertinoButton(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              color: CupertinoColors.systemGrey5
                                  .resolveFrom(context),
                              onPressed: () {
                                setDialogState(
                                  () {
                                    final targetIndexes = <int>{
                                      for (var index = 0;
                                          index < dialogCandidates.length;
                                          index++)
                                        if (dialogCandidates[index].state ==
                                            SourceImportCandidateState.update)
                                          index,
                                    };
                                    final allTargetSelected = targetIndexes
                                        .every(selectedIndexes.contains);
                                    if (allTargetSelected) {
                                      selectedIndexes.removeWhere(
                                        targetIndexes.contains,
                                      );
                                    } else {
                                      selectedIndexes.addAll(targetIndexes);
                                    }
                                  },
                                );
                              },
                              child: const Text('选择更新'),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 12),
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                        decoration: BoxDecoration(
                          color:
                              CupertinoColors.systemGrey6.resolveFrom(context),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          children: [
                            _buildPolicySwitchRow(
                              title: '保留本地名称',
                              value: keepName,
                              onChanged: (value) {
                                setDialogState(() => keepName = value);
                              },
                            ),
                            _buildPolicySwitchRow(
                              title: '保留本地分组',
                              value: keepGroup,
                              onChanged: (value) {
                                setDialogState(() => keepGroup = value);
                              },
                            ),
                            _buildPolicySwitchRow(
                              title: '保留启用状态',
                              value: keepEnable,
                              onChanged: (value) {
                                setDialogState(() => keepEnable = value);
                              },
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Expanded(
                                  child: CupertinoTextField(
                                    controller: groupController,
                                    placeholder: '自定义分组（可选）',
                                  ),
                                ),
                                const SizedBox(width: 8),
                                CupertinoButton(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  onPressed: () {
                                    setDialogState(() {
                                      appendCustomGroup = !appendCustomGroup;
                                    });
                                  },
                                  child: Text(
                                    appendCustomGroup ? '追加' : '覆盖',
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
                        child: Row(
                          children: [
                            Text(
                              '待导入：$selectedCount/$totalCount',
                              style: TextStyle(
                                fontSize: 12,
                                color: CupertinoColors.secondaryLabel
                                    .resolveFrom(context),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                          itemCount: dialogCandidates.length,
                          separatorBuilder: (_, __) => Container(
                            height: 0.5,
                            color: CupertinoColors.systemGrey4
                                .resolveFrom(context),
                          ),
                          itemBuilder: (context, index) {
                            final candidate = dialogCandidates[index];
                            final selected = selectedIndexes.contains(index);
                            final stateColor =
                                _importStateColor(candidate.state);
                            return GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () {
                                setDialogState(() {
                                  if (selected) {
                                    selectedIndexes.remove(index);
                                  } else {
                                    selectedIndexes.add(index);
                                  }
                                });
                              },
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 8),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.only(
                                          top: 2, right: 8),
                                      child: Icon(
                                        selected
                                            ? CupertinoIcons
                                                .check_mark_circled_solid
                                            : CupertinoIcons.circle,
                                        color: selected
                                            ? CupertinoTheme.of(context)
                                                .primaryColor
                                            : CupertinoColors.systemGrey,
                                        size: 20,
                                      ),
                                    ),
                                    Expanded(
                                      child: Text(
                                        candidate.incoming.bookSourceName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        left: 8,
                                        top: 2,
                                      ),
                                      child: Text(
                                        _importStateLabel(candidate.state),
                                        style: TextStyle(
                                          color: stateColor,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                    CupertinoButton(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 0,
                                      ),
                                      minimumSize: const Size(40, 28),
                                      onPressed: () async {
                                        final updated =
                                            await _editImportCandidateRawJson(
                                          candidate: candidate,
                                        );
                                        if (updated == null) return;
                                        if (!context.mounted) return;
                                        setDialogState(() {
                                          dialogCandidates[index] = updated;
                                        });
                                      },
                                      child: const Text('打开'),
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
      groupController.dispose();
    }
  }

  Widget _buildPolicySwitchRow({
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

  Future<SourceImportCandidate?> _editImportCandidateRawJson({
    required SourceImportCandidate candidate,
  }) async {
    final editedText = await _editImportRawJsonText(
      title: candidate.incoming.bookSourceName,
      initialText: candidate.rawJson,
    );
    if (editedText == null) return null;
    final updated = SourceImportSelectionHelper.tryReplaceCandidateRawJson(
      candidate: candidate,
      rawJson: editedText,
    );
    return updated;
  }

  Future<String?> _editImportRawJsonText({
    required String title,
    required String initialText,
  }) async {
    final controller = TextEditingController(text: initialText);
    try {
      return await showCupertinoModalPopup<String>(
        context: context,
        builder: (popupContext) {
          return CupertinoPopupSurface(
            isSurfacePainted: true,
            child: SafeArea(
              top: false,
              child: SizedBox(
                height: math.min(
                  MediaQuery.of(popupContext).size.height * 0.88,
                  760,
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 10, 8, 8),
                      child: Row(
                        children: [
                          CupertinoButton(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            onPressed: () => Navigator.pop(popupContext),
                            child: const Text('取消'),
                          ),
                          Expanded(
                            child: Text(
                              title.trim().isEmpty ? '编辑书源' : title,
                              maxLines: 1,
                              textAlign: TextAlign.center,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          CupertinoButton(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            onPressed: () => Navigator.pop(
                              popupContext,
                              controller.text,
                            ),
                            child: const Text('保存'),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      height: 0.5,
                      color:
                          CupertinoColors.separator.resolveFrom(popupContext),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                        child: CupertinoTextField(
                          controller: controller,
                          minLines: null,
                          maxLines: null,
                          expands: true,
                          textAlignVertical: TextAlignVertical.top,
                          placeholder: '输入书源 JSON',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    } finally {
      controller.dispose();
    }
  }

  Future<void> _commitImportResult(SourceImportResult result) async {
    try {
      if (!result.success) {
        if (!result.cancelled) {
          _showImportError(result);
        }
        return;
      }
      final candidates = SourceImportSelectionHelper.buildCandidates(
        result: result,
        localMap: _localSourceMap(),
      );
      if (candidates.isEmpty) {
        _showMessage('没有可导入的书源');
        return;
      }

      final decision = await _showImportSelectionDialog(candidates);
      if (decision == null) return;
      final plan = SourceImportSelectionHelper.buildCommitPlan(
        candidates: decision.candidates,
        policy: decision.policy,
      );
      if (plan.imported <= 0) {
        _showMessage('未选择可导入书源');
        return;
      }

      final commitResult = await _importCommitService.commit(plan.items);
      if (commitResult.imported <= 0) {
        final blockedCount = commitResult.blockedCount;
        if (blockedCount > 0) {
          final blockedPreview = commitResult.blockedNames.take(3).join('、');
          final extra = blockedCount > 3 ? ' 等$blockedCount条' : '';
          _showMessage('未导入书源\n已拦截：$blockedPreview$extra');
          return;
        }
        _showMessage('未选择可导入书源');
        return;
      }

      _showImportSummary(
        result,
        imported: commitResult.imported,
        newCount: commitResult.newCount,
        updateCount: commitResult.updateCount,
        existingCount: commitResult.existingCount,
        blockedNames: commitResult.blockedNames,
      );
    } catch (e, st) {
      debugPrint('[source-import] 导入流程异常: $e');
      ExceptionLogService().record(
        node: 'source.import.commit',
        message: '导入流程异常',
        error: e,
        stackTrace: st,
      );
      debugPrintStack(stackTrace: st);
      _showMessage('导入流程异常：$e');
    }
  }

  Map<String, BookSource> _localSourceMap() {
    final all = _sourceRepo.getAllSources();
    return {for (final source in all) source.bookSourceUrl: source};
  }

  void _showImportError(SourceImportResult result) {
    final lines = <String>[];
    lines.add(result.errorMessage ?? '导入失败');
    if (result.totalInputCount > 0) {
      lines.add('输入条数：${result.totalInputCount}');
      if (result.invalidCount > 0) lines.add('无效条数：${result.invalidCount}');
      if (result.duplicateCount > 0) {
        lines.add('重复URL：${result.duplicateCount}（后项覆盖）');
      }
    }
    if (kIsWeb && (result.errorMessage ?? '').contains('跨域限制')) {
      lines.add('建议：改用“剪贴板导入”或“本地导入”');
    }
    if (result.warnings.isNotEmpty) {
      lines.add('详情：');
      lines.addAll(result.warnings.take(5));
      final more = result.warnings.length - 5;
      if (more > 0) lines.add('…其余 $more 条省略');
    }
    _showMessage(lines.join('\n'));
  }

  void _showImportSummary(
    SourceImportResult result, {
    required int imported,
    required int newCount,
    required int updateCount,
    required int existingCount,
    List<String> blockedNames = const <String>[],
  }) {
    final lines = <String>[
      '成功导入 $imported 条书源',
      '新增：$newCount',
      '更新：$updateCount',
      '已有覆盖：$existingCount',
    ];
    if (blockedNames.isNotEmpty) {
      lines.add('已拦截：${blockedNames.length}');
      lines.add('拦截项：${blockedNames.take(3).join('、')}');
      final more = blockedNames.length - 3;
      if (more > 0) lines.add('…其余 $more 条省略');
    }
    if (result.totalInputCount > 0) {
      lines.add('输入条数：${result.totalInputCount}');
      if (result.invalidCount > 0) lines.add('跳过无效：${result.invalidCount}');
      if (result.duplicateCount > 0) {
        lines.add('导入内容内重复URL：${result.duplicateCount}（后项覆盖）');
      }
    }
    if (result.warnings.isNotEmpty) {
      lines.add('说明：');
      lines.addAll(result.warnings.take(5));
      final more = result.warnings.length - 5;
      if (more > 0) lines.add('…其余 $more 条省略');
    }
    _showMessage(lines.join('\n'));
  }

  bool _ensureSettingsReady({required String actionName}) {
    try {
      _db.driftDb;
      return true;
    } catch (e, st) {
      debugPrint('[source-settings] $actionName 前检查失败: $e');
      ExceptionLogService().record(
        node: 'source.settings.ready',
        message: '$actionName 前检查失败',
        error: e,
        stackTrace: st,
      );
      debugPrintStack(stackTrace: st);
      _showMessage('应用初始化未完成，暂时无法$actionName。请稍后重试。');
      return false;
    }
  }

  dynamic _settingsGet(
    String key, {
    dynamic defaultValue,
  }) {
    try {
      return _db.getSetting(key, defaultValue: defaultValue);
    } catch (e, st) {
      debugPrint('[source-settings] 读取 $key 失败: $e');
      ExceptionLogService().record(
        node: 'source.settings.read',
        message: '读取设置失败',
        error: e,
        stackTrace: st,
        context: <String, dynamic>{'key': key},
      );
      debugPrintStack(stackTrace: st);
      return defaultValue;
    }
  }

  bool _settingsGetBool(
    String key, {
    required bool defaultValue,
  }) {
    final value = _settingsGet(key, defaultValue: defaultValue);
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final lower = value.trim().toLowerCase();
      if (lower == 'true' || lower == '1') return true;
      if (lower == 'false' || lower == '0') return false;
    }
    return defaultValue;
  }

  int _settingsGetInt(
    String key, {
    required int defaultValue,
  }) {
    final value = _settingsGet(key, defaultValue: defaultValue);
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) {
      return int.tryParse(value.trim()) ?? defaultValue;
    }
    return defaultValue;
  }

  Future<bool> _settingsPut(
    String key,
    dynamic value,
  ) async {
    try {
      await _db.putSetting(key, value);
      return true;
    } catch (e, st) {
      debugPrint('[source-settings] 写入 $key 失败: $e');
      ExceptionLogService().record(
        node: 'source.settings.write',
        message: '写入设置失败',
        error: e,
        stackTrace: st,
        context: <String, dynamic>{'key': key},
      );
      debugPrintStack(stackTrace: st);
      _showMessage('设置保存失败：$e');
      return false;
    }
  }

  void _showMessage(String message) {
    showCupertinoDialog<void>(
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

  Future<void> _showExportPathDialog(String outputPath) async {
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
    await showCupertinoDialog<void>(
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
              _showToastMessage('已复制导出路径');
            },
            child: const Text('复制路径'),
          ),
        ],
      ),
    );
  }

  void _showToastMessage(String message) {
    if (!mounted) return;
    showCupertinoModalPopup<void>(
      context: context,
      barrierColor: CupertinoColors.black.withValues(alpha: 0.08),
      builder: (toastContext) {
        final navigator = Navigator.of(toastContext);
        unawaited(Future<void>.delayed(const Duration(milliseconds: 1100), () {
          if (navigator.mounted && navigator.canPop()) {
            navigator.pop();
          }
        }));
        return SafeArea(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              margin: const EdgeInsets.only(bottom: 28),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: CupertinoColors.systemBackground
                    .resolveFrom(context)
                    .withValues(alpha: 0.96),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: CupertinoColors.separator.resolveFrom(context),
                ),
              ),
              child: Text(
                message,
                style: TextStyle(
                  color: CupertinoColors.label.resolveFrom(context),
                  fontSize: 13,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
