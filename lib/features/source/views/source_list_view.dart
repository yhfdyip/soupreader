import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart'
    show ReorderableDragStartListener, ReorderableListView;
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../app/widgets/app_cupertino_page_scaffold.dart';
import '../../../core/database/database_service.dart';
import '../../../core/database/repositories/source_repository.dart';
import '../../../core/services/qr_scan_service.dart';
import '../../../core/utils/legado_json.dart';
import '../../search/views/search_view.dart';
import '../constants/source_help_texts.dart';
import '../models/book_source.dart';
import '../services/source_availability_check_task_service.dart';
import '../services/source_availability_summary_store.dart';
import '../services/source_debug_key_parser.dart';
import '../services/source_debug_summary_store.dart';
import '../services/source_filter_helper.dart';
import '../services/source_import_export_service.dart';
import 'source_availability_check_view.dart';
import 'source_edit_view.dart';
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

class _ImportPolicy {
  final bool keepOriginalName;
  final bool keepGroup;
  final bool keepEnabled;
  final String customGroup;
  final bool appendGroup;

  const _ImportPolicy({
    required this.keepOriginalName,
    required this.keepGroup,
    required this.keepEnabled,
    required this.customGroup,
    required this.appendGroup,
  });
}

class _ImportEntry {
  BookSource incoming;
  BookSource? existing;
  String rawJson;
  bool selected;
  bool edited = false;
  bool duplicateInImport = false;

  _ImportEntry({
    required this.incoming,
    required this.existing,
    required this.rawJson,
    required this.selected,
  });

  bool get isNew => existing == null;

  bool get isUpdate {
    final local = existing;
    if (local == null) return false;
    return incoming.lastUpdateTime > local.lastUpdateTime;
  }

  bool get isExisting => !isNew && !isUpdate;

  String get statusLabel {
    if (duplicateInImport) return '重复';
    if (isNew) return '新增';
    if (isUpdate) return '更新';
    return '已有';
  }
}

class _ImportDecision {
  final List<_ImportEntry> entries;
  final _ImportPolicy policy;

  const _ImportDecision({required this.entries, required this.policy});
}

/// 书源管理页面（复刻 legado 管理语义）
class SourceListView extends StatefulWidget {
  const SourceListView({super.key});

  @override
  State<SourceListView> createState() => _SourceListViewState();
}

class _SourceListViewState extends State<SourceListView> {
  String _selectedGroup = '全部';
  SourceEnabledFilter _enabledFilter = SourceEnabledFilter.all;
  _SourceSortMode _sortMode = _SourceSortMode.manual;
  bool _sortAscending = true;
  bool _groupSourcesByDomain = false;
  bool _selectionMode = false;
  Set<String> _checkFailedFilterUrls = <String>{};
  Set<String> _debugFailedFilterUrls = <String>{};

  late final SourceRepository _sourceRepo;
  late final DatabaseService _db;
  final SourceAvailabilityCheckTaskService _checkTaskService =
      SourceAvailabilityCheckTaskService.instance;
  final SourceImportExportService _importExportService =
      SourceImportExportService();

  final TextEditingController _urlController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  final Set<String> _selectedUrls = <String>{};

  static const String _prefImportKeepName = 'source_import_keep_name';
  static const String _prefImportKeepGroup = 'source_import_keep_group';
  static const String _prefImportKeepEnabled = 'source_import_keep_enabled';
  static const String _prefImportCustomGroup = 'source_import_custom_group';
  static const String _prefImportAppendGroup = 'source_import_append_group';
  static const String _prefImportOnlineHistory = 'source_import_online_history';
  static const String _prefCheckKeyword = 'source_check_keyword';

  @override
  void initState() {
    super.initState();
    _db = DatabaseService();
    _sourceRepo = SourceRepository(_db);
  }

  @override
  void dispose() {
    _urlController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = _selectionMode ? '已选 ${_selectedUrls.length}' : '书源管理';

    return AppCupertinoPageScaffold(
      title: title,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: _showImportOptions,
            child: const Icon(CupertinoIcons.add),
          ),
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: _showManageOptions,
            child: const Icon(CupertinoIcons.ellipsis),
          ),
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: () {
              setState(() {
                _selectionMode = !_selectionMode;
                if (!_selectionMode) {
                  _selectedUrls.clear();
                }
              });
            },
            child: Icon(
              _selectionMode
                  ? CupertinoIcons.checkmark_circle_fill
                  : CupertinoIcons.checkmark_circle,
            ),
          ),
        ],
      ),
      child: StreamBuilder<List<BookSource>>(
        stream: _sourceRepo.watchAllSources(),
        builder: (context, snapshot) {
          final allSources = snapshot.data ?? _sourceRepo.getAllSources();
          final cleanedAll = _normalizeSources(allSources);
          _cleanupSelection(cleanedAll);

          final groups = _buildGroups(cleanedAll);
          final activeGroup =
              groups.contains(_selectedGroup) ? _selectedGroup : '全部';

          final filtered = _buildVisibleList(cleanedAll, activeGroup);

          return Column(
            children: [
              _buildSearchBar(),
              _buildGroupFilter(groups, activeGroup),
              _buildEnabledFilter(),
              _buildSortSummary(filtered.length),
              _buildCheckTaskStrip(),
              _buildCheckSummaryStrip(),
              _buildDebugSummaryStrip(),
              Expanded(
                child: filtered.isEmpty
                    ? _buildEmptyState()
                    : _buildSourceList(cleanedAll, filtered),
              ),
              if (_selectionMode)
                _buildBatchActionBar(
                  allSources: cleanedAll,
                  visibleSources: filtered,
                ),
            ],
          );
        },
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
    if (_checkFailedFilterUrls.isNotEmpty) {
      _checkFailedFilterUrls =
          _checkFailedFilterUrls.where((url) => urls.contains(url)).toSet();
    }
    if (_debugFailedFilterUrls.isNotEmpty) {
      _debugFailedFilterUrls =
          _debugFailedFilterUrls.where((url) => urls.contains(url)).toSet();
    }
    if (_selectedUrls.isEmpty) return;
    final toRemove = _selectedUrls.where((url) => !urls.contains(url)).toList();
    if (toRemove.isEmpty) return;
    _selectedUrls.removeAll(toRemove);
    if (_selectedUrls.isEmpty && _selectionMode) {
      _selectionMode = false;
    }
  }

  List<String> _buildGroups(List<BookSource> sources) {
    return SourceFilterHelper.buildGroups(sources);
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: CupertinoSearchTextField(
        controller: _searchController,
        placeholder: '搜索书源 / 输入 group:分组',
        onChanged: (_) => setState(() {}),
      ),
    );
  }

  Widget _buildEnabledFilter() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: CupertinoSlidingSegmentedControl<SourceEnabledFilter>(
        groupValue: _enabledFilter,
        children: const {
          SourceEnabledFilter.all: Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: Text('全部状态'),
          ),
          SourceEnabledFilter.enabled: Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: Text('仅启用'),
          ),
          SourceEnabledFilter.disabled: Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: Text('仅禁用'),
          ),
        },
        onValueChanged: (value) {
          if (value == null) return;
          setState(() => _enabledFilter = value);
        },
      ),
    );
  }

  Widget _buildGroupFilter(List<String> groups, String activeGroup) {
    return SizedBox(
      height: 42,
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
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: isSelected
                    ? CupertinoTheme.of(context).primaryColor
                    : CupertinoColors.systemGrey5.resolveFrom(context),
                borderRadius: BorderRadius.circular(20),
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

  Widget _buildSortSummary(int count) {
    final sortText = _sortLabel(_sortMode);
    final orderText = _sortAscending ? '升序' : '降序';
    final domainText = _groupSourcesByDomain ? '按域名分组' : '普通列表';
    final checkFailedFilterText = _checkFailedFilterUrls.isEmpty
        ? ''
        : ' · 校验筛选 ${_checkFailedFilterUrls.length}';
    final debugFailedFilterText = _debugFailedFilterUrls.isEmpty
        ? ''
        : ' · 调试筛选 ${_debugFailedFilterUrls.length}';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '共 $count 条 · $sortText · $orderText · $domainText'
              '$checkFailedFilterText$debugFailedFilterText',
              style: TextStyle(
                fontSize: 12,
                color: CupertinoColors.secondaryLabel.resolveFrom(context),
              ),
            ),
          ),
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: _showSortOptions,
            child: const Text('排序'),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckSummaryStrip() {
    return ValueListenableBuilder<SourceAvailabilitySummary?>(
      valueListenable: SourceAvailabilitySummaryStore.instance.listenable,
      builder: (context, summary, _) {
        if (summary == null) {
          return const SizedBox.shrink();
        }
        final failedCount = summary.failedLikeCount;
        final hasFailedFilter = _checkFailedFilterUrls.isNotEmpty;
        final accent = CupertinoTheme.of(context).primaryColor;
        final finishedAt = _formatDateTime(summary.finishedAt);
        final keyword = (summary.keyword ?? '').trim();

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            decoration: BoxDecoration(
              color: CupertinoColors.systemGrey6.resolveFrom(context),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: accent.withValues(alpha: 0.22),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '最近校验：$finishedAt',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  '总 ${summary.total} · 可用 ${summary.available} · 失败 ${summary.failed} · 空列表 ${summary.empty} · '
                  '超时 ${summary.timeout} · 跳过 ${summary.skipped}',
                  style: TextStyle(
                    fontSize: 12,
                    color: CupertinoColors.secondaryLabel.resolveFrom(context),
                  ),
                ),
                if (keyword.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      '关键词：$keyword',
                      style: TextStyle(
                        fontSize: 12,
                        color: CupertinoColors.secondaryLabel.resolveFrom(
                          context,
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 10,
                  runSpacing: 6,
                  children: [
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: failedCount == 0
                          ? null
                          : () => _applyFailedSummaryFilter(summary),
                      child: Text('筛选失败源($failedCount)'),
                    ),
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed:
                          hasFailedFilter ? _clearFailedSummaryFilter : null,
                      child: const Text('清除失败筛选'),
                    ),
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: _showLatestCheckSummary,
                      child: const Text('详情'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCheckTaskStrip() {
    return ValueListenableBuilder<SourceCheckTaskSnapshot?>(
      valueListenable: _checkTaskService.listenable,
      builder: (context, snapshot, _) {
        if (snapshot == null || snapshot.items.isEmpty) {
          return const SizedBox.shrink();
        }
        final total = snapshot.items.length;
        final done = snapshot.items
            .where((item) =>
                item.status != SourceCheckStatus.pending &&
                item.status != SourceCheckStatus.running)
            .length;
        final runningCount = snapshot.items
            .where((item) => item.status == SourceCheckStatus.running)
            .length;
        final failedLike = snapshot.items
            .where((item) =>
                item.status == SourceCheckStatus.fail ||
                item.status == SourceCheckStatus.empty)
            .length;
        final running = snapshot.running;
        final accent = running
            ? CupertinoTheme.of(context).primaryColor
            : CupertinoColors.secondaryLabel.resolveFrom(context);

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            decoration: BoxDecoration(
              color: CupertinoColors.systemGrey6.resolveFrom(context),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: accent.withValues(alpha: 0.25),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  running ? '检测任务运行中' : '最近检测任务',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  '进度 $done/$total · 运行中 $runningCount · 失败/空 $failedLike'
                  '${snapshot.stopRequested ? ' · 停止中' : ''}',
                  style: TextStyle(
                    fontSize: 12,
                    color: CupertinoColors.secondaryLabel.resolveFrom(context),
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 10,
                  runSpacing: 6,
                  children: [
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: () => _openCurrentCheckTask(snapshot),
                      child: Text(running ? '恢复任务页' : '查看任务结果'),
                    ),
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: (!running || snapshot.stopRequested)
                          ? null
                          : _checkTaskService.requestStop,
                      child: const Text('停止任务'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openCurrentCheckTask(SourceCheckTaskSnapshot snapshot) async {
    if (!mounted) return;
    await Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (_) => SourceAvailabilityCheckView(
          includeDisabled: snapshot.config.includeDisabled,
          sourceUrls: snapshot.config.sourceUrls,
          keywordOverride: snapshot.config.keywordOverride,
        ),
      ),
    );
  }

  Widget _buildDebugSummaryStrip() {
    return ValueListenableBuilder<List<SourceDebugSummary>>(
      valueListenable: SourceDebugSummaryStore.instance.listenable,
      builder: (context, history, _) {
        if (history.isEmpty) {
          return const SizedBox.shrink();
        }
        final latest = history.first;
        final failedUrls = SourceDebugSummaryStore.instance.failedSourceUrls();
        final failedCount = failedUrls.length;
        final hasFailedFilter = _debugFailedFilterUrls.isNotEmpty;
        final accent = latest.success
            ? CupertinoColors.systemGreen.resolveFrom(context)
            : CupertinoColors.systemRed.resolveFrom(context);

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            decoration: BoxDecoration(
              color: CupertinoColors.systemGrey6.resolveFrom(context),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: accent.withValues(alpha: 0.3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '最近调试：${_formatDateTime(latest.finishedAt)}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  '${latest.sourceName} · ${_debugIntentLabel(latest.intentType)} · '
                  '${latest.success ? '成功' : '失败'} · ${latest.primaryDiagnosis}',
                  style: TextStyle(
                    fontSize: 12,
                    color: CupertinoColors.secondaryLabel.resolveFrom(context),
                  ),
                ),
                if ((latest.debugError ?? '').trim().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      '错误：${latest.debugError!.trim()}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: CupertinoColors.systemRed.resolveFrom(context),
                      ),
                    ),
                  ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 10,
                  runSpacing: 6,
                  children: [
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: failedCount == 0
                          ? null
                          : () => _applyDebugFailedSummaryFilter(failedUrls),
                      child: Text('筛选调试失败源($failedCount)'),
                    ),
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: hasFailedFilter
                          ? _clearDebugFailedSummaryFilter
                          : null,
                      child: const Text('清除调试筛选'),
                    ),
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: _showLatestDebugSummary,
                      child: const Text('详情'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatDateTime(DateTime value) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${value.year}-${two(value.month)}-${two(value.day)} '
        '${two(value.hour)}:${two(value.minute)}:${two(value.second)}';
  }

  String _debugIntentLabel(SourceDebugIntentType type) {
    switch (type) {
      case SourceDebugIntentType.search:
        return '搜索';
      case SourceDebugIntentType.bookInfo:
        return '详情';
      case SourceDebugIntentType.explore:
        return '发现';
      case SourceDebugIntentType.toc:
        return '目录';
      case SourceDebugIntentType.content:
        return '正文';
    }
  }

  List<BookSource> _buildVisibleList(
      List<BookSource> allSources, String activeGroup) {
    var filtered = SourceFilterHelper.filterByGroup(allSources, activeGroup);
    filtered = SourceFilterHelper.filterByEnabled(filtered, _enabledFilter);

    final query = _searchController.text.trim();
    if (query.isNotEmpty) {
      filtered = _applyQueryFilter(filtered, query);
    }
    if (_checkFailedFilterUrls.isNotEmpty) {
      filtered = filtered
          .where((s) => _checkFailedFilterUrls.contains(s.bookSourceUrl))
          .toList(growable: false);
    }
    if (_debugFailedFilterUrls.isNotEmpty) {
      filtered = filtered
          .where((s) => _debugFailedFilterUrls.contains(s.bookSourceUrl))
          .toList(growable: false);
    }

    final sorted = filtered.toList(growable: false);
    _sortSources(sorted);
    return sorted;
  }

  List<BookSource> _applyQueryFilter(List<BookSource> input, String query) {
    final q = query.toLowerCase();
    if (q == '启用' || q == 'enabled') {
      return input.where((s) => s.enabled).toList(growable: false);
    }
    if (q == '禁用' || q == 'disabled') {
      return input.where((s) => !s.enabled).toList(growable: false);
    }
    if (q == '需登录' || q == 'need_login') {
      return input
          .where((s) => (s.loginUrl ?? '').trim().isNotEmpty)
          .toList(growable: false);
    }
    if (q == '无分组' || q == 'no_group') {
      return input
          .where((s) => (s.bookSourceGroup ?? '').trim().isEmpty)
          .toList(growable: false);
    }
    if (q == '启用发现' || q == 'enabled_explore') {
      return input
          .where(
            (s) => (s.exploreUrl ?? '').trim().isNotEmpty && s.enabledExplore,
          )
          .toList(growable: false);
    }
    if (q == '禁用发现' || q == 'disabled_explore') {
      return input
          .where(
            (s) => (s.exploreUrl ?? '').trim().isNotEmpty && !s.enabledExplore,
          )
          .toList(growable: false);
    }
    if (q.startsWith('group:')) {
      final key = query.substring(6).trim();
      if (key.isEmpty) return input;
      return input
          .where((s) => _extractGroups(s.bookSourceGroup).contains(key))
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
          final c = a.customOrder.compareTo(b.customOrder);
          if (c != 0) return c;
          return b.weight.compareTo(a.weight);
        case _SourceSortMode.weight:
          return a.weight.compareTo(b.weight);
        case _SourceSortMode.name:
          return a.bookSourceName
              .toLowerCase()
              .compareTo(b.bookSourceName.toLowerCase());
        case _SourceSortMode.url:
          return a.bookSourceUrl.compareTo(b.bookSourceUrl);
        case _SourceSortMode.update:
          return a.lastUpdateTime.compareTo(b.lastUpdateTime);
        case _SourceSortMode.respond:
          return a.respondTime.compareTo(b.respondTime);
        case _SourceSortMode.enabled:
          final enabledCmp =
              (a.enabled == b.enabled) ? 0 : (a.enabled ? -1 : 1);
          if (enabledCmp != 0) return enabledCmp;
          return a.bookSourceName
              .toLowerCase()
              .compareTo(b.bookSourceName.toLowerCase());
      }
    }

    list.sort((a, b) {
      final c = compareByMode(a, b);
      return _sortAscending ? c : -c;
    });
  }

  String _hostOf(String url) {
    final uri = Uri.tryParse(url);
    final host = uri?.host.trim() ?? '';
    if (host.isEmpty) return '#';
    return host;
  }

  bool get _canManualReorder {
    return _sortMode == _SourceSortMode.manual &&
        !_groupSourcesByDomain &&
        !_selectionMode &&
        _enabledFilter == SourceEnabledFilter.all &&
        _selectedGroup == '全部' &&
        _searchController.text.trim().isEmpty;
  }

  Widget _buildSourceList(
      List<BookSource> allSources, List<BookSource> visible) {
    final reorderEnabled = _canManualReorder;
    final theme = ShadTheme.of(context);
    final scheme = theme.colorScheme;

    Widget buildItem(BookSource source, int index) {
      final selected = _selectedUrls.contains(source.bookSourceUrl);
      final showHeader = _groupSourcesByDomain &&
          (index == 0 ||
              _hostOf(visible[index - 1].bookSourceUrl) !=
                  _hostOf(source.bookSourceUrl));

      final exploreTag = (source.exploreUrl ?? '').trim().isEmpty
          ? null
          : source.enabledExplore
              ? '发现已启用'
              : '发现已禁用';

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showHeader)
            Padding(
              padding: const EdgeInsets.only(left: 2, bottom: 4),
              child: Text(
                _hostOf(source.bookSourceUrl),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: CupertinoColors.secondaryLabel.resolveFrom(context),
                ),
              ),
            ),
          ShadCard(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onLongPress: reorderEnabled
                  ? null
                  : () {
                      setState(() {
                        _selectionMode = true;
                        _toggleSelection(source.bookSourceUrl);
                      });
                    },
              onTap: () {
                if (_selectionMode) {
                  setState(() => _toggleSelection(source.bookSourceUrl));
                } else {
                  _showSourceActions(source);
                }
              },
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_selectionMode)
                    Padding(
                      padding: const EdgeInsets.only(top: 10, right: 8),
                      child: Icon(
                        selected
                            ? CupertinoIcons.check_mark_circled_solid
                            : CupertinoIcons.circle,
                        color: selected
                            ? CupertinoTheme.of(context).primaryColor
                            : CupertinoColors.systemGrey,
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
                                source.bookSourceName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.p.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: scheme.foreground,
                                ),
                              ),
                            ),
                            if (exploreTag != null)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: source.enabledExplore
                                      ? CupertinoColors.systemGreen
                                          .resolveFrom(context)
                                          .withValues(alpha: 0.15)
                                      : CupertinoColors.systemRed
                                          .resolveFrom(context)
                                          .withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  exploreTag,
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: source.enabledExplore
                                        ? CupertinoColors.systemGreen
                                        : CupertinoColors.systemRed,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          source.bookSourceUrl,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.small.copyWith(
                            color: scheme.mutedForeground,
                          ),
                        ),
                        if ((source.bookSourceGroup ?? '').trim().isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              '分组：${source.bookSourceGroup}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                color: CupertinoColors.secondaryLabel
                                    .resolveFrom(context),
                              ),
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
                  Column(
                    children: [
                      ShadSwitch(
                        value: source.enabled,
                        onChanged: (value) async {
                          await _sourceRepo
                              .updateSource(source.copyWith(enabled: value));
                        },
                      ),
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(28, 28),
                        onPressed: () => _showSourceActions(source),
                        child: const Icon(
                          CupertinoIcons.ellipsis_circle,
                          size: 19,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    if (reorderEnabled) {
      return ReorderableListView.builder(
        buildDefaultDragHandles: false,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        itemCount: visible.length,
        onReorder: (oldIndex, newIndex) async {
          await _onReorderVisible(visible, oldIndex, newIndex);
        },
        itemBuilder: (context, index) {
          final source = visible[index];
          return Container(
            key: ValueKey(source.bookSourceUrl),
            margin: const EdgeInsets.only(bottom: 8),
            child: buildItem(source, index),
          );
        },
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      itemCount: visible.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
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
    var targetIndex = newIndex;
    if (oldIndex < targetIndex) {
      targetIndex -= 1;
    }
    if (oldIndex == targetIndex) return;

    final reordered = visible.toList(growable: true);
    final moved = reordered.removeAt(oldIndex);
    reordered.insert(targetIndex, moved);

    final updated = reordered.asMap().entries.map((entry) {
      final index = entry.key;
      final source = entry.value;
      return source.copyWith(
        customOrder: _sortAscending ? index : -index,
      );
    }).toList(growable: false);
    await _sourceRepo.addSources(updated);
  }

  Widget _buildBatchActionBar({
    required List<BookSource> allSources,
    required List<BookSource> visibleSources,
  }) {
    final selectedCount = _selectedUrls.length;

    Widget action(String text, VoidCallback onTap, {bool destructive = false}) {
      return Padding(
        padding: const EdgeInsets.only(right: 6),
        child: CupertinoButton(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          minimumSize: const Size(30, 30),
          color: destructive
              ? CupertinoColors.systemRed.resolveFrom(context)
              : CupertinoTheme.of(context).primaryColor,
          onPressed: onTap,
          child: Text(
            text,
            style: const TextStyle(fontSize: 12, color: CupertinoColors.white),
          ),
        ),
      );
    }

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
        decoration: BoxDecoration(
          color: CupertinoColors.systemGroupedBackground.resolveFrom(context),
          border: Border(
            top: BorderSide(
              color: CupertinoColors.systemGrey4.resolveFrom(context),
              width: 0.5,
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '已选 $selectedCount 条',
              style: TextStyle(
                fontSize: 12,
                color: CupertinoColors.secondaryLabel.resolveFrom(context),
              ),
            ),
            const SizedBox(height: 6),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  action('全选', () {
                    setState(() {
                      _selectedUrls
                        ..clear()
                        ..addAll(visibleSources.map((s) => s.bookSourceUrl));
                    });
                  }),
                  action('反选', () {
                    setState(() {
                      final visibleSet =
                          visibleSources.map((e) => e.bookSourceUrl).toSet();
                      for (final url in visibleSet) {
                        _toggleSelection(url);
                      }
                    });
                  }),
                  action('区间补选', () {
                    setState(() => _expandSelectionInterval(visibleSources));
                  }),
                  action('启用', () => _batchSetEnabled(allSources, true)),
                  action('禁用', () => _batchSetEnabled(allSources, false)),
                  action('启发现', () => _batchSetExplore(allSources, true)),
                  action('停发现', () => _batchSetExplore(allSources, false)),
                  action('置顶', () => _batchMoveToTopBottom(allSources, true)),
                  action('置底', () => _batchMoveToTopBottom(allSources, false)),
                  action('加分组', () => _batchAddGroup(allSources)),
                  action('移分组', () => _batchRemoveGroup(allSources)),
                  action('校验', () => _batchCheckSelected(allSources)),
                  action('导出', () => _batchExportSelected(allSources)),
                  action('分享', () => _batchShareSelected(allSources)),
                  action(
                    '删除',
                    () => _batchDeleteSelected(allSources),
                    destructive: true,
                  ),
                ],
              ),
            ),
          ],
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
            '点击右上角 + 导入书源',
            style:
                theme.textTheme.muted.copyWith(color: scheme.mutedForeground),
          ),
        ],
      ),
    );
  }

  void _showImportOptions() {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('导入书源'),
        message: const Text('支持新建、剪贴板、文件、网络导入。'),
        actions: [
          CupertinoActionSheetAction(
            child: const Text('新建书源'),
            onPressed: () {
              Navigator.pop(context);
              _createNewSource();
            },
          ),
          CupertinoActionSheetAction(
            child: const Text('扫码导入'),
            onPressed: () {
              Navigator.pop(context);
              _importFromQrCode();
            },
          ),
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
        ],
        cancelButton: CupertinoActionSheetAction(
          child: const Text('取消'),
          onPressed: () => Navigator.pop(context),
        ),
      ),
    );
  }

  void _showManageOptions() {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('管理菜单'),
        actions: [
          CupertinoActionSheetAction(
            child: const Text('排序与分组选项'),
            onPressed: () {
              Navigator.pop(context);
              _showSortOptions();
            },
          ),
          CupertinoActionSheetAction(
            child: const Text('快捷筛选'),
            onPressed: () {
              Navigator.pop(context);
              _showQuickQueryOptions();
            },
          ),
          CupertinoActionSheetAction(
            child: Text(
              _checkFailedFilterUrls.isEmpty ? '清除失败筛选（未启用）' : '清除失败筛选',
            ),
            onPressed: () {
              Navigator.pop(context);
              _clearFailedSummaryFilter();
            },
          ),
          CupertinoActionSheetAction(
            child: Text(
              _debugFailedFilterUrls.isEmpty ? '清除调试筛选（未启用）' : '清除调试筛选',
            ),
            onPressed: () {
              Navigator.pop(context);
              _clearDebugFailedSummaryFilter();
            },
          ),
          CupertinoActionSheetAction(
            child: const Text('分组管理'),
            onPressed: () {
              Navigator.pop(context);
              _showGroupManageSheet();
            },
          ),
          CupertinoActionSheetAction(
            child: const Text('导出全部书源'),
            onPressed: () {
              Navigator.pop(context);
              _exportSources();
            },
          ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            child: const Text('删除禁用书源'),
            onPressed: () {
              Navigator.pop(context);
              _confirmDeleteDisabledSources();
            },
          ),
          CupertinoActionSheetAction(
            child: const Text('检查可用性'),
            onPressed: () {
              Navigator.pop(context);
              _openAvailabilityCheck();
            },
          ),
          if (_checkTaskService.snapshot != null)
            CupertinoActionSheetAction(
              child: Text(
                _checkTaskService.isRunning ? '恢复检测任务' : '查看最近检测任务',
              ),
              onPressed: () {
                final snapshot = _checkTaskService.snapshot;
                Navigator.pop(context);
                if (snapshot == null) return;
                _openCurrentCheckTask(snapshot);
              },
            ),
          CupertinoActionSheetAction(
            child: const Text('最近校验摘要'),
            onPressed: () {
              Navigator.pop(context);
              _showLatestCheckSummary();
            },
          ),
          CupertinoActionSheetAction(
            child: const Text('最近调试摘要'),
            onPressed: () {
              Navigator.pop(context);
              _showLatestDebugSummary();
            },
          ),
          CupertinoActionSheetAction(
            child: const Text('帮助（书源管理）'),
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
        title: const Text('排序选项'),
        actions: [
          CupertinoActionSheetAction(
            child:
                Text('${_sortMode == _SourceSortMode.manual ? '✓ ' : ''}手动排序'),
            onPressed: () => pickSort(_SourceSortMode.manual),
          ),
          CupertinoActionSheetAction(
            child: Text('${_sortMode == _SourceSortMode.weight ? '✓ ' : ''}权重'),
            onPressed: () => pickSort(_SourceSortMode.weight),
          ),
          CupertinoActionSheetAction(
            child: Text('${_sortMode == _SourceSortMode.name ? '✓ ' : ''}名称'),
            onPressed: () => pickSort(_SourceSortMode.name),
          ),
          CupertinoActionSheetAction(
            child: Text('${_sortMode == _SourceSortMode.url ? '✓ ' : ''}地址'),
            onPressed: () => pickSort(_SourceSortMode.url),
          ),
          CupertinoActionSheetAction(
            child:
                Text('${_sortMode == _SourceSortMode.update ? '✓ ' : ''}更新时间'),
            onPressed: () => pickSort(_SourceSortMode.update),
          ),
          CupertinoActionSheetAction(
            child:
                Text('${_sortMode == _SourceSortMode.respond ? '✓ ' : ''}响应时间'),
            onPressed: () => pickSort(_SourceSortMode.respond),
          ),
          CupertinoActionSheetAction(
            child:
                Text('${_sortMode == _SourceSortMode.enabled ? '✓ ' : ''}启用状态'),
            onPressed: () => pickSort(_SourceSortMode.enabled),
          ),
          CupertinoActionSheetAction(
            child: Text(_sortAscending ? '切换为降序' : '切换为升序'),
            onPressed: () {
              setState(() => _sortAscending = !_sortAscending);
              Navigator.pop(context);
            },
          ),
          CupertinoActionSheetAction(
            child: Text(_groupSourcesByDomain ? '关闭按域名分组' : '按域名分组显示'),
            onPressed: () {
              setState(() => _groupSourcesByDomain = !_groupSourcesByDomain);
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

  void _showQuickQueryOptions() {
    void applyQuery(String text) {
      setState(() {
        _searchController.text = text;
      });
      Navigator.pop(context);
    }

    showCupertinoModalPopup<void>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('快捷筛选'),
        actions: [
          CupertinoActionSheetAction(
            child: const Text('启用'),
            onPressed: () => applyQuery('启用'),
          ),
          CupertinoActionSheetAction(
            child: const Text('禁用'),
            onPressed: () => applyQuery('禁用'),
          ),
          CupertinoActionSheetAction(
            child: const Text('需登录'),
            onPressed: () => applyQuery('需登录'),
          ),
          CupertinoActionSheetAction(
            child: const Text('无分组'),
            onPressed: () => applyQuery('无分组'),
          ),
          CupertinoActionSheetAction(
            child: const Text('启用发现'),
            onPressed: () => applyQuery('启用发现'),
          ),
          CupertinoActionSheetAction(
            child: const Text('禁用发现'),
            onPressed: () => applyQuery('禁用发现'),
          ),
          CupertinoActionSheetAction(
            child: const Text('清空搜索'),
            onPressed: () => applyQuery(''),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          child: const Text('取消'),
          onPressed: () => Navigator.pop(context),
        ),
      ),
    );
  }

  Future<void> _showGroupManageSheet() async {
    final allSources = _sourceRepo.getAllSources();
    final groups = _buildGroups(allSources)
      ..remove('全部')
      ..remove('失效');

    await showCupertinoModalPopup<void>(
      context: context,
      builder: (context) {
        return CupertinoPopupSurface(
          isSurfacePainted: true,
          child: SizedBox(
            height: math.min(MediaQuery.of(context).size.height * 0.78, 560),
            child: StatefulBuilder(
              builder: (context, setSheetState) {
                Future<void> refreshAfter(
                    Future<void> Function() action) async {
                  await action();
                  final latest = _buildGroups(_sourceRepo.getAllSources())
                    ..remove('全部')
                    ..remove('失效');
                  setSheetState(() {
                    groups
                      ..clear()
                      ..addAll(latest);
                  });
                  if (mounted) setState(() {});
                }

                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 12, 8),
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
                            onPressed: () => Navigator.pop(context),
                            child: const Text('关闭'),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: CupertinoButton.filled(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              onPressed: () async {
                                await refreshAfter(() async {
                                  final name = await _askGroupName('新增分组');
                                  if (name == null || name.trim().isEmpty) {
                                    return;
                                  }
                                  await _assignGroupToNoGroupSources(
                                      name.trim());
                                });
                              },
                              child: const Text('新增分组（应用到无分组）'),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: groups.isEmpty
                          ? Center(
                              child: Text(
                                '暂无可管理分组',
                                style: TextStyle(
                                  color: CupertinoColors.secondaryLabel
                                      .resolveFrom(context),
                                ),
                              ),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                              itemCount: groups.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 6),
                              itemBuilder: (context, index) {
                                final group = groups[index];
                                return Container(
                                  decoration: BoxDecoration(
                                    color: CupertinoColors.systemGrey6
                                        .resolveFrom(context),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Padding(
                                    padding:
                                        const EdgeInsets.fromLTRB(10, 6, 10, 6),
                                    child: Row(
                                      children: [
                                        Expanded(child: Text(group)),
                                        CupertinoButton(
                                          padding: EdgeInsets.zero,
                                          minimumSize: const Size(28, 28),
                                          onPressed: () async {
                                            await refreshAfter(() async {
                                              final renamed =
                                                  await _askGroupName(
                                                '重命名分组',
                                                initialValue: group,
                                              );
                                              if (renamed == null) return;
                                              await _renameGroup(
                                                  group, renamed.trim());
                                            });
                                          },
                                          child: const Text('编辑'),
                                        ),
                                        CupertinoButton(
                                          padding: EdgeInsets.zero,
                                          minimumSize: const Size(28, 28),
                                          onPressed: () async {
                                            await refreshAfter(() async {
                                              await _removeGroupEverywhere(
                                                  group);
                                            });
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
  }

  Future<void> _showSourceActions(BookSource source) async {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: Text(source.bookSourceName),
        message: Text(source.bookSourceUrl),
        actions: [
          CupertinoActionSheetAction(
            child: const Text('编辑'),
            onPressed: () {
              Navigator.pop(context);
              _openEditor(source.bookSourceUrl);
            },
          ),
          CupertinoActionSheetAction(
            child: const Text('置顶'),
            onPressed: () {
              Navigator.pop(context);
              _toTop(source);
            },
          ),
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
                _openSourceLogin(source);
              },
            ),
          CupertinoActionSheetAction(
            child: const Text('调试'),
            onPressed: () {
              Navigator.pop(context);
              _openEditor(source.bookSourceUrl, initialTab: 3);
            },
          ),
          CupertinoActionSheetAction(
            child: const Text('搜索测试'),
            onPressed: () async {
              Navigator.pop(context);
              final keyword = await _askSearchKeyword(source);
              if (keyword == null || keyword.trim().isEmpty) return;
              if (!mounted) return;
              await Navigator.of(this.context).push(
                CupertinoPageRoute<void>(
                  builder: (_) => SearchView.scoped(
                    sourceUrls: [source.bookSourceUrl],
                    initialKeyword: keyword.trim(),
                    autoSearchOnOpen: true,
                  ),
                ),
              );
            },
          ),
          if ((source.exploreUrl ?? '').trim().isNotEmpty)
            CupertinoActionSheetAction(
              child: Text(source.enabledExplore ? '禁用发现' : '启用发现'),
              onPressed: () async {
                Navigator.pop(context);
                await _sourceRepo.updateSource(
                  source.copyWith(enabledExplore: !source.enabledExplore),
                );
              },
            ),
          CupertinoActionSheetAction(
            child: const Text('分享（复制 JSON）'),
            onPressed: () {
              Navigator.pop(context);
              final raw = _sourceRepo.getRawJsonByUrl(source.bookSourceUrl) ??
                  LegadoJson.encode(source.toJson());
              Clipboard.setData(ClipboardData(text: raw));
              _showMessage('已复制书源 JSON');
            },
          ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            child: const Text('删除'),
            onPressed: () {
              Navigator.pop(context);
              _confirmDeleteSource(source);
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
    final ok = await showCupertinoDialog<bool>(
          context: context,
          builder: (ctx) => CupertinoAlertDialog(
            title: const Text('删除书源'),
            content: Text('\n确定删除 ${source.bookSourceName} ？'),
            actions: [
              CupertinoDialogAction(
                isDestructiveAction: true,
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('删除'),
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
    await _sourceRepo.deleteSource(source.bookSourceUrl);
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
    final all = _sourceRepo.getAllSources();
    if (all.isEmpty) return;

    final sorted = sources.toList(growable: false)
      ..sort((a, b) => a.customOrder.compareTo(b.customOrder));

    if (toTop) {
      final minOrder = all.map((e) => e.customOrder).fold<int>(0, math.min) - 1;
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

    final maxOrder = all.map((e) => e.customOrder).fold<int>(0, math.max) + 1;
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
    if (!mounted) return;
    await Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (_) => SourceAvailabilityCheckView(
          includeDisabled: true,
          sourceUrls:
              selected.map((e) => e.bookSourceUrl).toList(growable: false),
          keywordOverride: keyword,
        ),
      ),
    );
  }

  void _toggleSelection(String url) {
    if (_selectedUrls.contains(url)) {
      _selectedUrls.remove(url);
    } else {
      _selectedUrls.add(url);
    }
    if (_selectionMode && _selectedUrls.isEmpty) {
      _selectionMode = false;
    }
  }

  void _expandSelectionInterval(List<BookSource> visible) {
    if (_selectedUrls.length < 2 || visible.isEmpty) return;
    final selectedIndexes = <int>[];
    for (var i = 0; i < visible.length; i++) {
      if (_selectedUrls.contains(visible[i].bookSourceUrl)) {
        selectedIndexes.add(i);
      }
    }
    if (selectedIndexes.length < 2) return;

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
        .where((s) => (s.exploreUrl ?? '').trim().isNotEmpty)
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
    final group = await _askGroupName('加入分组');
    if (group == null || group.trim().isEmpty) return;
    final selected = _selectedSources(allSources);
    if (selected.isEmpty) {
      _showMessage('当前未选择书源');
      return;
    }
    await Future.wait(selected.map((source) async {
      final groups = _extractGroups(source.bookSourceGroup);
      groups.add(group.trim());
      await _sourceRepo.updateSource(
        source.copyWith(bookSourceGroup: _joinGroups(groups)),
      );
    }));
    _showMessage('已将 ${selected.length} 条书源加入分组“${group.trim()}”');
  }

  Future<void> _batchRemoveGroup(List<BookSource> allSources) async {
    final group = await _askGroupName('移除分组');
    if (group == null || group.trim().isEmpty) return;
    final selected = _selectedSources(allSources);
    if (selected.isEmpty) {
      _showMessage('当前未选择书源');
      return;
    }

    await Future.wait(selected.map((source) async {
      final groups = _extractGroups(source.bookSourceGroup);
      groups.remove(group.trim());
      await _sourceRepo.updateSource(
        source.copyWith(bookSourceGroup: _joinGroups(groups)),
      );
    }));
    _showMessage('已从 ${selected.length} 条书源移除分组“${group.trim()}”');
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
      _selectionMode = false;
    });
    _showMessage('已删除 ${selected.length} 条书源');
  }

  Future<void> _batchExportSelected(List<BookSource> allSources) async {
    final selected = _selectedSources(allSources);
    if (selected.isEmpty) {
      _showMessage('当前未选择书源');
      return;
    }
    final ok = await _importExportService.exportToFile(selected);
    _showMessage(ok ? '导出成功' : '导出取消');
  }

  Future<void> _batchShareSelected(List<BookSource> allSources) async {
    final selected = _selectedSources(allSources);
    if (selected.isEmpty) {
      _showMessage('当前未选择书源');
      return;
    }
    try {
      final file = await _importExportService.exportToShareFile(selected);
      if (file != null) {
        await SharePlus.instance.share(
          ShareParams(
            files: [XFile(file.path, mimeType: 'application/json')],
            text: 'SoupReader 书源（${selected.length} 条）',
            subject: 'bookSource.json',
          ),
        );
        _showMessage('已打开系统分享（${selected.length} 条书源）');
        return;
      }
    } catch (_) {
      // ignore and fallback
    }

    final text = LegadoJson.encode(selected.map((s) => s.toJson()).toList());
    await Clipboard.setData(ClipboardData(text: text));
    _showMessage('系统分享不可用，已复制 ${selected.length} 条书源 JSON');
  }

  Future<void> _assignGroupToNoGroupSources(String group) async {
    final all = _sourceRepo.getAllSources();
    final targets = all
        .where((s) => (s.bookSourceGroup ?? '').trim().isEmpty)
        .toList(growable: false);
    if (targets.isEmpty) {
      _showMessage('当前没有“无分组”书源');
      return;
    }
    await Future.wait(
      targets.map(
          (s) => _sourceRepo.updateSource(s.copyWith(bookSourceGroup: group))),
    );
  }

  Future<void> _renameGroup(String oldGroup, String newGroup) async {
    if (newGroup.isEmpty) return;
    final all = _sourceRepo.getAllSources();
    final targets = all.where((s) {
      return _extractGroups(s.bookSourceGroup).contains(oldGroup);
    }).toList(growable: false);
    if (targets.isEmpty) return;

    await Future.wait(targets.map((source) async {
      final groups = _extractGroups(source.bookSourceGroup);
      if (!groups.remove(oldGroup)) return;
      groups.add(newGroup);
      await _sourceRepo.updateSource(
        source.copyWith(bookSourceGroup: _joinGroups(groups)),
      );
    }));
  }

  Future<void> _removeGroupEverywhere(String group) async {
    final all = _sourceRepo.getAllSources();
    final targets = all.where((s) {
      return _extractGroups(s.bookSourceGroup).contains(group);
    }).toList(growable: false);

    await Future.wait(targets.map((source) async {
      final groups = _extractGroups(source.bookSourceGroup);
      groups.remove(group);
      await _sourceRepo.updateSource(
        source.copyWith(bookSourceGroup: _joinGroups(groups)),
      );
    }));
  }

  List<String> _extractGroups(String? raw) {
    final text = raw?.trim();
    if (text == null || text.isEmpty) return <String>[];
    return text
        .split(RegExp(r'[,;，；]'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList(growable: false);
  }

  String? _joinGroups(List<String> groups) {
    if (groups.isEmpty) return null;
    return groups.toSet().join(',');
  }

  Future<String?> _askGroupName(String title, {String? initialValue}) async {
    final controller = TextEditingController(text: initialValue ?? '');
    final value = await showCupertinoDialog<String>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(title),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: CupertinoTextField(
            controller: controller,
            placeholder: '输入分组名',
          ),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('确定'),
          ),
        ],
      ),
    );
    controller.dispose();
    return value;
  }

  Future<void> _openAvailabilityCheck() async {
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('书源可用性检测'),
        message: const Text('建议先检测启用书源；开始前可指定校验关键词。'),
        actions: [
          CupertinoActionSheetAction(
            child: const Text('检测启用的（推荐）'),
            onPressed: () async {
              Navigator.pop(context);
              final keyword = await _askCheckKeyword();
              if (keyword == null || !mounted) return;
              await Navigator.of(this.context).push(
                CupertinoPageRoute<void>(
                  builder: (_) => SourceAvailabilityCheckView(
                    includeDisabled: false,
                    keywordOverride: keyword,
                  ),
                ),
              );
            },
          ),
          CupertinoActionSheetAction(
            child: const Text('检测全部（含禁用）'),
            onPressed: () async {
              Navigator.pop(context);
              final keyword = await _askCheckKeyword();
              if (keyword == null || !mounted) return;
              await Navigator.of(this.context).push(
                CupertinoPageRoute<void>(
                  builder: (_) => SourceAvailabilityCheckView(
                    includeDisabled: true,
                    keywordOverride: keyword,
                  ),
                ),
              );
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

  Future<String?> _askCheckKeyword() async {
    final cached = (_db.settingsBox.get(
              _prefCheckKeyword,
              defaultValue: '我的',
            ) ??
            '我的')
        .toString();
    final controller = TextEditingController(text: cached);
    final value = await showCupertinoDialog<String>(
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
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('开始校验'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value == null) return null;

    final normalized = value.trim();
    final keyword = normalized.isNotEmpty
        ? normalized
        : (cached.trim().isNotEmpty ? cached.trim() : '我的');
    await _db.settingsBox.put(_prefCheckKeyword, keyword);
    return keyword;
  }

  void _applyFailedSummaryFilter(SourceAvailabilitySummary summary) {
    final urls = summary.failedSourceUrls
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet();
    if (urls.isEmpty) {
      _showMessage('最近一次校验没有失败/空列表书源');
      return;
    }
    setState(() {
      _selectedGroup = '全部';
      _enabledFilter = SourceEnabledFilter.all;
      _searchController.clear();
      _checkFailedFilterUrls = urls;
    });
    _showMessage('已筛选最近校验失败书源（${urls.length} 条）');
  }

  void _clearFailedSummaryFilter() {
    if (_checkFailedFilterUrls.isEmpty) return;
    setState(() => _checkFailedFilterUrls = <String>{});
    _showMessage('已清除失败书源筛选');
  }

  void _applyDebugFailedSummaryFilter(Set<String> urls) {
    final normalized =
        urls.map((e) => e.trim()).where((e) => e.isNotEmpty).toSet();
    if (normalized.isEmpty) {
      _showMessage('最近调试没有失败书源');
      return;
    }
    setState(() {
      _selectedGroup = '全部';
      _enabledFilter = SourceEnabledFilter.all;
      _searchController.clear();
      _debugFailedFilterUrls = normalized;
    });
    _showMessage('已筛选调试失败书源（${normalized.length} 条）');
  }

  void _clearDebugFailedSummaryFilter() {
    if (_debugFailedFilterUrls.isEmpty) return;
    setState(() => _debugFailedFilterUrls = <String>{});
    _showMessage('已清除调试失败筛选');
  }

  Future<void> _showLatestCheckSummary() async {
    final summary = SourceAvailabilitySummaryStore.instance.latest;
    if (summary == null) {
      _showMessage('暂无最近校验摘要');
      return;
    }
    final failedCount = summary.failedLikeCount;
    final scope = summary.includeDisabled ? '全部（含禁用）' : '仅启用';
    final keyword = (summary.keyword ?? '').trim();
    final lines = <String>[
      '时间：${_formatDateTime(summary.finishedAt)}',
      '范围：$scope',
      if (keyword.isNotEmpty) '关键词：$keyword',
      '总计：${summary.total}',
      '可用：${summary.available}',
      '失败：${summary.failed}',
      '空列表：${summary.empty}',
      '超时：${summary.timeout}',
      '跳过：${summary.skipped}',
      '失败/空列表 URL：${summary.failedSourceUrls.length}',
    ];

    await showCupertinoDialog<void>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('最近校验摘要'),
        content: Text('\n${lines.join('\n')}'),
        actions: [
          CupertinoDialogAction(
            onPressed: () {
              Navigator.pop(ctx);
              _applyFailedSummaryFilter(summary);
            },
            child: Text('筛选失败源($failedCount)'),
          ),
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  Future<void> _showLatestDebugSummary() async {
    final latest = SourceDebugSummaryStore.instance.latest;
    if (latest == null) {
      _showMessage('暂无最近调试摘要');
      return;
    }
    final failedUrls = SourceDebugSummaryStore.instance.failedSourceUrls();
    final lines = <String>[
      '时间：${_formatDateTime(latest.finishedAt)}',
      '书源：${latest.sourceName}',
      'URL：${latest.sourceUrl}',
      '模式：${_debugIntentLabel(latest.intentType)}',
      'Key：${latest.key}',
      '结果：${latest.success ? '成功' : '失败'}',
      '诊断：${latest.primaryDiagnosis}',
      if ((latest.debugError ?? '').trim().isNotEmpty)
        '错误：${latest.debugError!.trim()}',
      '失败书源（最近状态）：${failedUrls.length}',
    ];

    await showCupertinoDialog<void>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('最近调试摘要'),
        content: Text('\n${lines.join('\n')}'),
        actions: [
          CupertinoDialogAction(
            onPressed: () {
              Navigator.pop(ctx);
              _applyDebugFailedSummaryFilter(failedUrls);
            },
            child: Text('筛选失败源(${failedUrls.length})'),
          ),
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  void _showSourceManageHelp() {
    _showMessage(SourceHelpTexts.manage);
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
        builder: (_) => SourceEditView(
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
        builder: (_) => SourceEditView.fromSource(
          source,
          rawJson: _sourceRepo.getRawJsonByUrl(source.bookSourceUrl),
          initialTab: initialTab,
          initialDebugKey: initialDebugKey,
        ),
      ),
    );
  }

  Future<void> _openSourceLogin(BookSource source) async {
    final url = source.loginUrl?.trim() ?? '';
    if (url.isEmpty) {
      _showMessage('当前书源未配置 loginUrl');
      return;
    }
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      _showMessage('loginUrl 不是有效网页地址');
      return;
    }

    await Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (_) => SourceWebVerifyView(initialUrl: url),
      ),
    );
  }

  Future<String?> _askSearchKeyword(BookSource source) async {
    final defaultKeyword = source.ruleSearch?.checkKeyWord?.trim();
    final controller = TextEditingController(
      text: (defaultKeyword == null || defaultKeyword.isEmpty)
          ? '我的'
          : defaultKeyword,
    );
    final value = await showCupertinoDialog<String>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('单源搜索测试'),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: CupertinoTextField(
            controller: controller,
            placeholder: '输入搜索关键词',
          ),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('开始搜索'),
          ),
        ],
      ),
    );
    controller.dispose();
    return value;
  }

  Future<void> _importFromFile() async {
    final result = await _importExportService.importFromFile();
    await _commitImportResult(result);
  }

  Future<void> _importFromClipboard() async {
    final data = await Clipboard.getData('text/plain');
    final text = data?.text?.trim();
    if (text == null || text.isEmpty) {
      _showMessage('剪贴板为空');
      return;
    }
    final result = await _importExportService.importFromText(text);
    await _commitImportResult(result);
  }

  Future<void> _importFromQrCode() async {
    final text = await QrScanService.scanText(
      context,
      title: '扫码导入书源',
    );
    final value = text?.trim();
    if (value == null || value.isEmpty) {
      return;
    }

    if (value.startsWith('http://') || value.startsWith('https://')) {
      await _pushImportHistory(value);
      final result = await _importExportService.importFromUrl(value);
      await _commitImportResult(result);
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
                              '在线导入',
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
                              placeholder: '输入书源链接（http/https）',
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
                          CupertinoButton(
                            padding: EdgeInsets.zero,
                            onPressed: history.isEmpty
                                ? null
                                : () async {
                                    history.clear();
                                    await _saveOnlineImportHistory(history);
                                    if (mounted) {
                                      setDialogState(() {});
                                    }
                                  },
                            child: const Text('清空'),
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
    if (!normalizedUrl.startsWith('http://') &&
        !normalizedUrl.startsWith('https://')) {
      _showMessage('链接格式无效，请输入 http:// 或 https:// 开头');
      return;
    }

    await _pushImportHistory(normalizedUrl);
    final result = await _importExportService.importFromUrl(normalizedUrl);
    await _commitImportResult(result);
  }

  List<String> _loadOnlineImportHistory() {
    final raw = _db.settingsBox.get(_prefImportOnlineHistory);
    if (raw is List) {
      return raw
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toSet()
          .toList(growable: false);
    }
    if (raw is String) {
      return raw
          .split(RegExp(r'[\n,]'))
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toSet()
          .toList(growable: false);
    }
    return <String>[];
  }

  Future<void> _saveOnlineImportHistory(List<String> history) async {
    final normalized = history
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList(growable: false);
    await _db.settingsBox.put(_prefImportOnlineHistory, normalized);
  }

  Future<void> _pushImportHistory(String url) async {
    final history = _loadOnlineImportHistory();
    history.remove(url);
    history.insert(0, url);
    final capped = history.take(20).toList(growable: false);
    await _saveOnlineImportHistory(capped);
  }

  Future<void> _confirmDeleteDisabledSources() async {
    final count = _sourceRepo.getAllSources().where((s) => !s.enabled).length;
    if (count <= 0) {
      _showMessage('当前没有禁用书源可删除');
      return;
    }

    final confirmed = await showCupertinoDialog<bool>(
          context: context,
          builder: (dialogContext) => CupertinoAlertDialog(
            title: const Text('删除禁用书源'),
            content: Text('\n将删除 $count 条已禁用书源，此操作不可撤销。'),
            actions: [
              CupertinoDialogAction(
                isDestructiveAction: true,
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('确认删除'),
              ),
              CupertinoDialogAction(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('取消'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;
    await _sourceRepo.deleteDisabledSources();
    _showMessage('已删除 $count 条禁用书源');
  }

  Future<void> _commitImportResult(SourceImportResult result) async {
    if (!result.success) {
      if (!result.cancelled) {
        _showImportError(result);
      }
      return;
    }

    final entries = <_ImportEntry>[];
    final localMap = _localSourceMap();
    for (final source in result.sources) {
      final url = source.bookSourceUrl.trim();
      if (url.isEmpty) continue;
      final rawJson =
          result.rawJsonForSourceUrl(url) ?? LegadoJson.encode(source.toJson());
      entries.add(
        _ImportEntry(
          incoming: source,
          existing: localMap[url],
          rawJson: rawJson,
          selected: true,
        ),
      );
    }

    _refreshImportEntries(entries, localMap);

    if (entries.isEmpty) {
      _showMessage('没有可导入的书源');
      return;
    }

    final decision = await _showImportSelectionDialog(entries);
    if (decision == null) {
      _showMessage('已取消导入');
      return;
    }

    final selectedEntries = decision.entries.where((e) => e.selected).toList();
    if (selectedEntries.isEmpty) {
      _showMessage('未选择任何书源，导入取消');
      return;
    }

    // 导入时按 URL 去重，保留最后一个被选中的条目（与 legado 重复覆盖语义一致）。
    final dedupSelected = <String, _ImportEntry>{};
    for (final entry in selectedEntries) {
      dedupSelected[entry.incoming.bookSourceUrl.trim()] = entry;
    }
    final finalEntries = dedupSelected.values.toList(growable: false);

    var imported = 0;
    var newCount = 0;
    var updateCount = 0;
    var keepCount = 0;

    for (final entry in finalEntries) {
      final isNew = entry.isNew;
      if (isNew) {
        newCount++;
      } else if (entry.isUpdate) {
        updateCount++;
      } else {
        keepCount++;
      }

      final mergedRaw = _buildMergedRawJson(entry, decision.policy);
      await _sourceRepo.upsertSourceRawJson(rawJson: mergedRaw);
      imported++;
    }

    _showImportSummary(
      result,
      imported: imported,
      newCount: newCount,
      updateCount: updateCount,
      existingCount: keepCount,
    );
  }

  BookSource _mergeWithPolicy(_ImportEntry entry, _ImportPolicy policy) {
    var merged = entry.incoming;
    final local = entry.existing;

    if (local != null) {
      if (policy.keepOriginalName) {
        merged = merged.copyWith(bookSourceName: local.bookSourceName);
      }
      if (policy.keepGroup) {
        merged = merged.copyWith(bookSourceGroup: local.bookSourceGroup);
      }
      if (policy.keepEnabled) {
        merged = merged.copyWith(
          enabled: local.enabled,
          enabledExplore: local.enabledExplore,
        );
      }
    }

    final customGroup = policy.customGroup.trim();
    if (customGroup.isNotEmpty) {
      if (policy.appendGroup) {
        final groups = _extractGroups(merged.bookSourceGroup);
        groups.add(customGroup);
        merged = merged.copyWith(bookSourceGroup: _joinGroups(groups));
      } else {
        merged = merged.copyWith(bookSourceGroup: customGroup);
      }
    }

    return merged;
  }

  Map<String, BookSource> _localSourceMap() {
    final all = _sourceRepo.getAllSources();
    return {for (final source in all) source.bookSourceUrl: source};
  }

  void _refreshImportEntries(
    List<_ImportEntry> entries,
    Map<String, BookSource> localMap,
  ) {
    final urlCount = <String, int>{};
    for (final entry in entries) {
      final url = entry.incoming.bookSourceUrl.trim();
      if (url.isEmpty) continue;
      urlCount[url] = (urlCount[url] ?? 0) + 1;
    }

    for (final entry in entries) {
      final url = entry.incoming.bookSourceUrl.trim();
      entry.existing = localMap[url];
      entry.duplicateInImport = url.isNotEmpty && (urlCount[url] ?? 0) > 1;
    }
  }

  Map<String, dynamic>? _decodeJsonMap(String text) {
    try {
      final decoded = json.decode(text);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) {
        return decoded.map((key, value) => MapEntry('$key', value));
      }
    } catch (_) {}
    return null;
  }

  String _buildMergedRawJson(_ImportEntry entry, _ImportPolicy policy) {
    final merged = _mergeWithPolicy(entry, policy);
    final map = _decodeJsonMap(entry.rawJson) ?? merged.toJson();
    map['bookSourceUrl'] = merged.bookSourceUrl;
    map['bookSourceName'] = merged.bookSourceName;
    map['bookSourceGroup'] = merged.bookSourceGroup;
    map['enabled'] = merged.enabled;
    map['enabledExplore'] = merged.enabledExplore;
    return LegadoJson.encode(map);
  }

  Future<bool> _editImportEntryJson(_ImportEntry entry) async {
    final controller = TextEditingController(text: _prettyJson(entry.rawJson));
    String? errorText;

    final saved = await showCupertinoModalPopup<bool>(
      context: context,
      builder: (context) {
        return CupertinoPopupSurface(
          isSurfacePainted: true,
          child: SizedBox(
            height: math.min(MediaQuery.of(context).size.height * 0.88, 760),
            child: StatefulBuilder(
              builder: (context, setDialogState) {
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 12, 10, 8),
                      child: Row(
                        children: [
                          const Expanded(
                            child: Text(
                              '编辑导入 JSON',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          CupertinoButton(
                            padding: EdgeInsets.zero,
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('取消'),
                          ),
                        ],
                      ),
                    ),
                    if (errorText != null)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            errorText!,
                            style: TextStyle(
                              fontSize: 13,
                              color: CupertinoColors.systemRed.resolveFrom(
                                context,
                              ),
                            ),
                          ),
                        ),
                      ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                        child: CupertinoTextField(
                          controller: controller,
                          maxLines: null,
                          minLines: 18,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: CupertinoButton(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              onPressed: () {
                                final map = _decodeJsonMap(controller.text);
                                if (map == null) {
                                  setDialogState(() => errorText = 'JSON 格式错误');
                                  return;
                                }
                                final normalized = LegadoJson.encode(map);
                                controller.text = _prettyJson(normalized);
                                controller.selection =
                                    TextSelection.fromPosition(
                                  TextPosition(offset: controller.text.length),
                                );
                                setDialogState(() => errorText = null);
                              },
                              child: const Text('格式化'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: CupertinoButton.filled(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              onPressed: () {
                                final map = _decodeJsonMap(controller.text);
                                if (map == null) {
                                  setDialogState(() => errorText = 'JSON 格式错误');
                                  return;
                                }
                                final source = BookSource.fromJson(map);
                                if (source.bookSourceUrl.trim().isEmpty) {
                                  setDialogState(
                                    () => errorText = 'bookSourceUrl 不能为空',
                                  );
                                  return;
                                }
                                if (source.bookSourceName.trim().isEmpty) {
                                  setDialogState(
                                    () => errorText = 'bookSourceName 不能为空',
                                  );
                                  return;
                                }
                                entry.incoming = source;
                                entry.rawJson = LegadoJson.encode(map);
                                entry.edited = true;
                                Navigator.pop(context, true);
                              },
                              child: const Text('保存'),
                            ),
                          ),
                        ],
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

    controller.dispose();
    return saved == true;
  }

  String _prettyJson(String text) {
    try {
      final decoded = json.decode(text);
      return const JsonEncoder.withIndent('  ').convert(decoded);
    } catch (_) {
      return text;
    }
  }

  Future<_ImportDecision?> _showImportSelectionDialog(
    List<_ImportEntry> entries,
  ) async {
    final localMap = _localSourceMap();
    _refreshImportEntries(entries, localMap);
    var keepName =
        _db.settingsBox.get(_prefImportKeepName, defaultValue: false) == true;
    var keepGroup =
        _db.settingsBox.get(_prefImportKeepGroup, defaultValue: false) == true;
    var keepEnabled =
        _db.settingsBox.get(_prefImportKeepEnabled, defaultValue: false) ==
            true;
    var customGroup =
        (_db.settingsBox.get(_prefImportCustomGroup, defaultValue: '') ?? '')
            .toString();
    var appendGroup =
        _db.settingsBox.get(_prefImportAppendGroup, defaultValue: true) == true;

    void markAll(bool selected) {
      for (final entry in entries) {
        entry.selected = selected;
      }
    }

    void markNewOnly() {
      for (final entry in entries) {
        entry.selected = entry.isNew;
      }
    }

    void markUpdateOnly() {
      for (final entry in entries) {
        entry.selected = entry.isUpdate;
      }
    }

    final customGroupCtrl = TextEditingController(text: customGroup);
    final result = await showCupertinoModalPopup<_ImportDecision>(
      context: context,
      builder: (context) {
        return CupertinoPopupSurface(
          isSurfacePainted: true,
          child: SizedBox(
            height: math.min(MediaQuery.of(context).size.height * 0.85, 680),
            child: StatefulBuilder(
              builder: (context, setDialogState) {
                final selectedCount = entries.where((e) => e.selected).length;
                final totalCount = entries.length;
                final newCount = entries.where((e) => e.isNew).length;
                final updateCount = entries.where((e) => e.isUpdate).length;

                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 12, 10, 8),
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
                            padding: EdgeInsets.zero,
                            onPressed: () => Navigator.pop(context),
                            child: const Text('取消'),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '已选 $selectedCount / $totalCount · 新增 $newCount · 更新 $updateCount',
                          style: TextStyle(
                            fontSize: 12,
                            color: CupertinoColors.secondaryLabel
                                .resolveFrom(context),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          CupertinoButton(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            color: CupertinoTheme.of(context).primaryColor,
                            onPressed: () =>
                                setDialogState(() => markAll(true)),
                            child: const Text('全选'),
                          ),
                          CupertinoButton(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            color: CupertinoTheme.of(context).primaryColor,
                            onPressed: () =>
                                setDialogState(() => markAll(false)),
                            child: const Text('全不选'),
                          ),
                          CupertinoButton(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            color: CupertinoTheme.of(context).primaryColor,
                            onPressed: () => setDialogState(markNewOnly),
                            child: const Text('仅新增'),
                          ),
                          CupertinoButton(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            color: CupertinoTheme.of(context).primaryColor,
                            onPressed: () => setDialogState(markUpdateOnly),
                            child: const Text('仅更新'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: CupertinoColors.systemGrey6.resolveFrom(context),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        children: [
                          _buildPolicySwitch(
                            title: '保留原名称',
                            value: keepName,
                            onChanged: (v) =>
                                setDialogState(() => keepName = v),
                          ),
                          _buildPolicySwitch(
                            title: '保留原分组',
                            value: keepGroup,
                            onChanged: (v) =>
                                setDialogState(() => keepGroup = v),
                          ),
                          _buildPolicySwitch(
                            title: '保留原启用状态',
                            value: keepEnabled,
                            onChanged: (v) =>
                                setDialogState(() => keepEnabled = v),
                          ),
                          _buildPolicySwitch(
                            title: '分组追加模式',
                            value: appendGroup,
                            onChanged: (v) =>
                                setDialogState(() => appendGroup = v),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(12, 2, 12, 10),
                            child: CupertinoTextField(
                              controller: customGroupCtrl,
                              placeholder: '自定义分组（可选）',
                              onChanged: (value) {
                                customGroup = value;
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                        itemCount: entries.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 6),
                        itemBuilder: (context, index) {
                          final entry = entries[index];
                          final statusColor = entry.duplicateInImport
                              ? CupertinoColors.systemRed
                              : entry.isNew
                                  ? CupertinoColors.systemGreen
                                  : entry.isUpdate
                                      ? CupertinoColors.systemOrange
                                      : CupertinoColors.systemGrey;
                          return GestureDetector(
                            onTap: () {
                              setDialogState(
                                  () => entry.selected = !entry.selected);
                            },
                            child: Container(
                              padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                              decoration: BoxDecoration(
                                color: CupertinoColors.systemGrey6
                                    .resolveFrom(context),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    entry.selected
                                        ? CupertinoIcons
                                            .check_mark_circled_solid
                                        : CupertinoIcons.circle,
                                    color: entry.selected
                                        ? CupertinoTheme.of(context)
                                            .primaryColor
                                        : CupertinoColors.systemGrey,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          entry.incoming.bookSourceName,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          entry.incoming.bookSourceUrl,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: CupertinoColors
                                                .secondaryLabel
                                                .resolveFrom(context),
                                          ),
                                        ),
                                        if (entry.duplicateInImport)
                                          Padding(
                                            padding:
                                                const EdgeInsets.only(top: 2),
                                            child: Text(
                                              '与导入列表其他条目 URL 重复（后项会覆盖前项）',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: CupertinoColors.systemRed
                                                    .resolveFrom(context),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: statusColor
                                              .resolveFrom(context)
                                              .withValues(alpha: 0.15),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          entry.statusLabel,
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: statusColor.resolveFrom(
                                              context,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      CupertinoButton(
                                        padding: EdgeInsets.zero,
                                        minimumSize: const Size(28, 28),
                                        onPressed: () async {
                                          final changed =
                                              await _editImportEntryJson(entry);
                                          if (!changed) return;
                                          _refreshImportEntries(
                                            entries,
                                            localMap,
                                          );
                                          if (mounted) {
                                            setDialogState(() {});
                                          }
                                        },
                                        child: Text(
                                          entry.edited ? '已编辑' : '编辑JSON',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: entry.edited
                                                ? CupertinoColors.systemGreen
                                                    .resolveFrom(context)
                                                : CupertinoColors.activeBlue
                                                    .resolveFrom(context),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: CupertinoButton.filled(
                              onPressed: () async {
                                await _db.settingsBox.put(
                                  _prefImportKeepName,
                                  keepName,
                                );
                                await _db.settingsBox.put(
                                  _prefImportKeepGroup,
                                  keepGroup,
                                );
                                await _db.settingsBox.put(
                                  _prefImportKeepEnabled,
                                  keepEnabled,
                                );
                                await _db.settingsBox.put(
                                  _prefImportCustomGroup,
                                  customGroup,
                                );
                                await _db.settingsBox.put(
                                  _prefImportAppendGroup,
                                  appendGroup,
                                );

                                if (!context.mounted) return;
                                Navigator.pop(
                                  context,
                                  _ImportDecision(
                                    entries: entries,
                                    policy: _ImportPolicy(
                                      keepOriginalName: keepName,
                                      keepGroup: keepGroup,
                                      keepEnabled: keepEnabled,
                                      customGroup: customGroup,
                                      appendGroup: appendGroup,
                                    ),
                                  ),
                                );
                              },
                              child: const Text('开始导入'),
                            ),
                          ),
                        ],
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
    customGroupCtrl.dispose();
    return result;
  }

  Widget _buildPolicySwitch({
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Row(
        children: [
          Expanded(child: Text(title)),
          CupertinoSwitch(value: value, onChanged: onChanged),
        ],
      ),
    );
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
      lines.add('建议：改用“剪贴板导入”或“文件导入”');
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
  }) {
    final lines = <String>[
      '成功导入 $imported 条书源',
      '新增：$newCount',
      '更新：$updateCount',
      '已有覆盖：$existingCount',
    ];
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

  Future<void> _exportSources() async {
    final sources = _sourceRepo.getAllSources();
    if (sources.isEmpty) {
      _showMessage('暂无可导出的书源');
      return;
    }
    final success = await _importExportService.exportToFile(sources);
    _showMessage(success ? '导出成功' : '导出取消');
  }

  String _sortLabel(_SourceSortMode mode) {
    switch (mode) {
      case _SourceSortMode.manual:
        return '手动排序';
      case _SourceSortMode.weight:
        return '权重';
      case _SourceSortMode.name:
        return '名称';
      case _SourceSortMode.url:
        return '地址';
      case _SourceSortMode.update:
        return '更新时间';
      case _SourceSortMode.respond:
        return '响应时间';
      case _SourceSortMode.enabled:
        return '启用状态';
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
}
