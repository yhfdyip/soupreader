import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../app/widgets/app_cupertino_page_scaffold.dart';
import '../../../core/database/database_service.dart';
import '../../../core/database/repositories/source_repository.dart';
import '../../search/views/search_view.dart';
import '../../source/models/book_source.dart';
import '../../source/services/source_explore_kinds_service.dart';
import '../../source/services/source_login_ui_helper.dart';
import '../../source/services/source_login_url_resolver.dart';
import '../../source/views/source_edit_legacy_view.dart';
import '../../source/views/source_login_form_view.dart';
import '../../source/views/source_web_verify_view.dart';
import '../services/discovery_filter_helper.dart';
import 'discovery_explore_results_view.dart';

/// 发现页（对标 legado ExploreFragment）：
/// - 展示支持发现的书源列表
/// - 点击书源展开/收起发现入口
/// - 点击入口进入二级发现书单页
class DiscoveryView extends StatefulWidget {
  final ValueListenable<int>? compressSignal;

  const DiscoveryView({
    super.key,
    this.compressSignal,
  });

  @override
  State<DiscoveryView> createState() => _DiscoveryViewState();
}

class _DiscoveryViewState extends State<DiscoveryView> {
  late final SourceRepository _sourceRepo;
  late final SourceExploreKindsService _exploreKindsService;
  StreamSubscription<List<BookSource>>? _sourceSub;

  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<BookSource> _allSources = <BookSource>[];
  int? _lastExternalCompressVersion;

  String? _expandedSourceUrl;
  final Set<String> _loadingKindsSources = <String>{};
  final Map<String, List<SourceExploreKind>> _sourceKindsCache =
      <String, List<SourceExploreKind>>{};

  @override
  void initState() {
    super.initState();
    final db = DatabaseService();
    _sourceRepo = SourceRepository(db);
    _exploreKindsService = SourceExploreKindsService(databaseService: db);

    _allSources = _sourceRepo.getAllSources();
    _searchController.addListener(_onQueryChanged);
    _lastExternalCompressVersion = widget.compressSignal?.value;
    widget.compressSignal?.addListener(_onExternalCompressSignal);
    _sourceSub = _sourceRepo.watchAllSources().listen((sources) {
      if (!mounted) return;
      setState(() {
        _allSources = sources;
        if (_expandedSourceUrl != null &&
            !_allSources.any((s) => s.bookSourceUrl == _expandedSourceUrl)) {
          _expandedSourceUrl = null;
        }
      });
    });
  }

  @override
  void didUpdateWidget(covariant DiscoveryView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.compressSignal == widget.compressSignal) return;
    oldWidget.compressSignal?.removeListener(_onExternalCompressSignal);
    _lastExternalCompressVersion = widget.compressSignal?.value;
    widget.compressSignal?.addListener(_onExternalCompressSignal);
  }

  @override
  void dispose() {
    _sourceSub?.cancel();
    widget.compressSignal?.removeListener(_onExternalCompressSignal);
    _searchController
      ..removeListener(_onQueryChanged)
      ..dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onExternalCompressSignal() {
    final version = widget.compressSignal?.value;
    if (version == null) return;
    if (_lastExternalCompressVersion == version) return;
    _lastExternalCompressVersion = version;
    _compressExplore();
  }

  void _onQueryChanged() {
    if (!mounted) return;
    setState(() {});
  }

  List<BookSource> _eligibleSources(List<BookSource> input) {
    // 对齐 legado BookSourceDao.flowExplore：
    // 仅以 enabledExplore + hasExploreUrl 作为发现页可见条件，并按 customOrder 升序。
    final indexed = input.asMap().entries.where((entry) {
      final source = entry.value;
      final hasExploreUrl = (source.exploreUrl ?? '').trim().isNotEmpty;
      return source.enabledExplore && hasExploreUrl;
    }).toList(growable: false);

    indexed.sort((a, b) {
      final byOrder = a.value.customOrder.compareTo(b.value.customOrder);
      if (byOrder != 0) return byOrder;
      // customOrder 相同时保持原输入顺序，避免非 legacy 语义下的额外排序。
      return a.key.compareTo(b.key);
    });
    return indexed.map((entry) => entry.value).toList(growable: false);
  }

  List<String> _buildGroups(List<BookSource> sources) {
    final groups = <String>{};
    for (final source in sources) {
      groups
          .addAll(DiscoveryFilterHelper.extractGroups(source.bookSourceGroup));
    }
    final sorted = groups.toList()..sort();
    return sorted;
  }

  void _setQuery(String query) {
    _searchController.text = query;
    _searchController.selection = TextSelection.fromPosition(
      TextPosition(offset: query.length),
    );
  }

  Future<void> _showGroupFilterMenu() async {
    final groups = _buildGroups(_eligibleSources(_allSources));
    if (groups.isEmpty) {
      _showMessage('当前没有可用分组');
      return;
    }

    showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: const Text('按分组筛选'),
        actions: [
          for (final group in groups)
            CupertinoActionSheetAction(
              child: Text(group),
              onPressed: () {
                Navigator.pop(ctx);
                _setQuery('group:$group');
              },
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          child: const Text('取消'),
          onPressed: () => Navigator.pop(ctx),
        ),
      ),
    );
  }

  void _compressExplore() {
    if (_expandedSourceUrl != null) {
      setState(() => _expandedSourceUrl = null);
      return;
    }
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOut,
    );
  }

  Future<void> _toggleSource(BookSource source) async {
    final sourceUrl = source.bookSourceUrl;
    if (_expandedSourceUrl == sourceUrl) {
      setState(() => _expandedSourceUrl = null);
      return;
    }

    setState(() => _expandedSourceUrl = sourceUrl);
    await _loadKinds(source, forceRefresh: false);
  }

  Future<void> _loadKinds(
    BookSource source, {
    required bool forceRefresh,
  }) async {
    final sourceUrl = source.bookSourceUrl;

    if (!forceRefresh && _sourceKindsCache.containsKey(sourceUrl)) {
      return;
    }

    setState(() => _loadingKindsSources.add(sourceUrl));
    try {
      final kinds = await _exploreKindsService.exploreKinds(
        source,
        forceRefresh: forceRefresh,
      );
      if (!mounted) return;
      setState(() {
        _sourceKindsCache[sourceUrl] = kinds;
        _loadingKindsSources.remove(sourceUrl);
      });
    } catch (e, st) {
      if (!mounted) return;
      setState(() {
        _loadingKindsSources.remove(sourceUrl);
        _sourceKindsCache[sourceUrl] = <SourceExploreKind>[
          SourceExploreKind(
            title: 'ERROR:发现入口解析失败',
            url: '$e\n$st',
          ),
        ];
      });
    }
  }

  Future<void> _openExploreKind(
    BookSource source,
    SourceExploreKind kind,
  ) async {
    final rawUrl = kind.url?.trim() ?? '';
    if (rawUrl.isEmpty) return;

    final title = kind.title.trim().isEmpty ? '发现' : kind.title.trim();
    if (title.startsWith('ERROR:')) {
      _showMessage(rawUrl, title: 'ERROR');
      return;
    }

    await Navigator.of(context, rootNavigator: true).push(
      CupertinoPageRoute<void>(
        builder: (_) => DiscoveryExploreResultsView(
          source: source,
          exploreName: title,
          exploreUrl: rawUrl,
        ),
      ),
    );
  }

  Future<void> _showSourceActions(BookSource source) async {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: Text(source.bookSourceName),
        message: Text(source.bookSourceUrl),
        actions: [
          CupertinoActionSheetAction(
            child: const Text('编辑书源'),
            onPressed: () {
              Navigator.pop(ctx);
              _openEditor(source);
            },
          ),
          CupertinoActionSheetAction(
            child: const Text('置顶'),
            onPressed: () {
              Navigator.pop(ctx);
              _toTop(source);
            },
          ),
          if ((source.loginUrl ?? '').trim().isNotEmpty)
            CupertinoActionSheetAction(
              child: const Text('登录'),
              onPressed: () {
                Navigator.pop(ctx);
                _openSourceLogin(source);
              },
            ),
          CupertinoActionSheetAction(
            child: const Text('搜索'),
            onPressed: () {
              Navigator.pop(ctx);
              _searchInSource(source);
            },
          ),
          CupertinoActionSheetAction(
            child: const Text('刷新发现缓存'),
            onPressed: () {
              Navigator.pop(ctx);
              _refreshSourceKinds(source);
            },
          ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            child: const Text('删除书源'),
            onPressed: () {
              Navigator.pop(ctx);
              _confirmDeleteSource(source);
            },
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          child: const Text('取消'),
          onPressed: () => Navigator.pop(ctx),
        ),
      ),
    );
  }

  Future<void> _openEditor(BookSource source) async {
    await Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (_) => SourceEditLegacyView.fromSource(
          source,
          rawJson: _sourceRepo.getRawJsonByUrl(source.bookSourceUrl),
        ),
      ),
    );
  }

  Future<void> _toTop(BookSource source) async {
    final all = _sourceRepo.getAllSources();
    var minOrder = 0;
    for (final item in all) {
      minOrder = math.min(minOrder, item.customOrder);
    }
    await _sourceRepo.updateSource(
      source.copyWith(customOrder: minOrder - 1),
    );
  }

  Future<void> _openSourceLogin(BookSource source) async {
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

  Future<void> _searchInSource(BookSource source) async {
    await Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (_) => SearchView.scoped(
          sourceUrls: <String>[source.bookSourceUrl],
        ),
      ),
    );
  }

  Future<void> _refreshSourceKinds(BookSource source) async {
    await _exploreKindsService.clearExploreKindsCache(source);
    if (!mounted) return;

    setState(() {
      _sourceKindsCache.remove(source.bookSourceUrl);
    });

    if (_expandedSourceUrl == source.bookSourceUrl) {
      await _loadKinds(source, forceRefresh: true);
    }
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

  void _showMessage(String message, {String title = '提示'}) {
    showShadDialog<void>(
      context: context,
      builder: (dialogContext) => ShadDialog.alert(
        title: Text(title),
        description: Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(message),
        ),
        actions: [
          ShadButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('好'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final scheme = theme.colorScheme;

    final eligible = _eligibleSources(_allSources);
    final visible = DiscoveryFilterHelper.applyQueryFilter(
        eligible, _searchController.text);
    final query = _searchController.text.trim();
    final showEmptyMessage = DiscoveryFilterHelper.shouldShowEmptyMessage(
      visibleCount: visible.length,
      query: query,
    );

    return AppCupertinoPageScaffold(
      title: '发现',
      trailing: CupertinoButton(
        padding: EdgeInsets.zero,
        minimumSize: const Size(28, 28),
        onPressed: _showGroupFilterMenu,
        child: const Icon(CupertinoIcons.square_grid_2x2),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
            child: Column(
              children: [
                ShadInput(
                  controller: _searchController,
                  placeholder: const Text('搜索书源 / 输入 group:分组'),
                  leading: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(LucideIcons.search, size: 16),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      '书源 ${visible.length}',
                      style: theme.textTheme.small.copyWith(
                        color: scheme.mutedForeground,
                      ),
                    ),
                    if (query.startsWith('group:')) ...[
                      const SizedBox(width: 10),
                      Text(
                        '分组筛选',
                        style: theme.textTheme.small.copyWith(
                          color: scheme.primary,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: visible.isEmpty
                ? (showEmptyMessage
                    ? _buildEmptyState(
                        eligibleCount: eligible.length,
                        query: query,
                      )
                    : _buildFilteredNoResultBody())
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    itemCount: visible.length,
                    itemBuilder: (context, index) =>
                        _buildSourceItem(visible[index]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilteredNoResultBody() {
    return ListView(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      children: const <Widget>[],
    );
  }

  Widget _buildEmptyState({
    required int eligibleCount,
    required String query,
  }) {
    final theme = ShadTheme.of(context);
    final scheme = theme.colorScheme;

    String subtitle;
    if (eligibleCount == 0) {
      subtitle = '没有可用的发现书源\n请先导入带 exploreUrl 的 Legado 书源';
    } else if (query.isNotEmpty) {
      subtitle = '当前筛选条件下无书源';
    } else {
      subtitle = '暂无发现书源';
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            LucideIcons.compass,
            size: 52,
            color: scheme.mutedForeground,
          ),
          const SizedBox(height: 16),
          Text('暂无发现内容', style: theme.textTheme.h4),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: theme.textTheme.muted.copyWith(
              color: scheme.mutedForeground,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSourceItem(BookSource source) {
    final theme = ShadTheme.of(context);
    final scheme = theme.colorScheme;

    final sourceUrl = source.bookSourceUrl;
    final expanded = _expandedSourceUrl == sourceUrl;
    final loadingKinds = _loadingKindsSources.contains(sourceUrl);
    final kinds = _sourceKindsCache[sourceUrl] ?? const <SourceExploreKind>[];

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ShadCard(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _toggleSource(source),
              onLongPress: () => _showSourceActions(source),
              child: Row(
                children: [
                  Icon(
                    expanded
                        ? LucideIcons.chevronDown
                        : LucideIcons.chevronRight,
                    size: 16,
                    color: scheme.mutedForeground,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          source.bookSourceName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.p.copyWith(
                            fontWeight: FontWeight.w600,
                            color: scheme.foreground,
                          ),
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
                        if ((source.bookSourceGroup ?? '')
                            .trim()
                            .isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            '分组: ${source.bookSourceGroup!.trim()}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.small.copyWith(
                              color: scheme.mutedForeground,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (expanded) ...[
              const SizedBox(height: 10),
              Container(height: 1, color: scheme.border),
              const SizedBox(height: 10),
              if (loadingKinds)
                Row(
                  children: [
                    const CupertinoActivityIndicator(),
                    const SizedBox(width: 8),
                    Text(
                      '正在加载发现入口…',
                      style: theme.textTheme.small.copyWith(
                        color: scheme.mutedForeground,
                      ),
                    ),
                  ],
                )
              else if (kinds.isEmpty)
                Text(
                  '暂无发现入口',
                  style: theme.textTheme.small.copyWith(
                    color: scheme.mutedForeground,
                  ),
                )
              else
                LayoutBuilder(
                  builder: (context, constraints) {
                    final maxWidth = constraints.maxWidth;
                    final chips = <Widget>[];
                    for (final kind in kinds) {
                      if (kind.style?.layoutWrapBefore == true) {
                        chips.add(SizedBox(width: maxWidth, height: 0));
                      }

                      final width = _kindWidth(kind.style, maxWidth);
                      final child = _buildKindChip(source, kind);
                      if (width == null) {
                        chips.add(child);
                      } else {
                        chips.add(
                          SizedBox(
                            width: width,
                            child: child,
                          ),
                        );
                      }
                    }

                    return Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: chips,
                    );
                  },
                ),
            ],
          ],
        ),
      ),
    );
  }

  double? _kindWidth(SourceExploreKindStyle? style, double maxWidth) {
    if (style == null) return null;
    var basis = style.layoutFlexBasisPercent;
    if (basis > 1 && basis <= 100) {
      basis = basis / 100;
    }
    if (basis > 0 && basis <= 1) {
      return (maxWidth * basis).clamp(64.0, maxWidth).toDouble();
    }
    if (style.layoutFlexGrow > 0) {
      return maxWidth;
    }
    return null;
  }

  Widget _buildKindChip(BookSource source, SourceExploreKind kind) {
    final theme = ShadTheme.of(context);
    final scheme = theme.colorScheme;

    final title = kind.title.trim().isEmpty ? '发现' : kind.title.trim();
    final url = kind.url?.trim() ?? '';
    final isEnabled = url.isNotEmpty;
    final isError = title.startsWith('ERROR:');

    final borderColor = isError
        ? scheme.destructive
        : isEnabled
            ? scheme.primary
            : scheme.border;
    final textColor = isError
        ? scheme.destructive
        : isEnabled
            ? scheme.primary
            : scheme.mutedForeground;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: isEnabled ? () => _openExploreKind(source, kind) : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: textColor.withValues(alpha: 0.09),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: borderColor, width: 1),
        ),
        child: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.small.copyWith(
            color: textColor,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
