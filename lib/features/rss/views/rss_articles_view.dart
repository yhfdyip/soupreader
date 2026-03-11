import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/scheduler.dart';

import '../../../app/widgets/app_cupertino_page_scaffold.dart';
import '../../../app/widgets/app_popover_menu.dart';
import '../../../app/widgets/cupertino_bottom_dialog.dart';
import '../../../core/database/database_service.dart';
import '../../../core/database/repositories/rss_article_repository.dart';
import '../../../core/database/repositories/rss_source_repository.dart';
import '../../../core/services/exception_log_service.dart';
import '../../../core/services/source_variable_store.dart';
import '../models/rss_article.dart';
import '../models/rss_source.dart';
import '../services/rss_article_load_more_helper.dart';
import '../services/rss_article_style_helper.dart';
import '../services/rss_article_sync_service.dart';
import '../services/rss_sort_urls_helper.dart';
import 'rss_read_record_view.dart';
import 'rss_read_view.dart';
import 'rss_source_edit_view.dart';
import 'rss_view_helpers.dart';

enum _RssArticlesMenuAction {
  login,
  refreshSort,
  setSourceVariable,
  editSource,
  switchLayout,
  readRecord,
  clear,
}
class RssArticlesPlaceholderView extends StatefulWidget {
  const RssArticlesPlaceholderView({
    super.key,
    required this.sourceName,
    required this.sourceUrl,
    this.repository,
  });

  final String sourceName;
  final String sourceUrl;
  final RssSourceRepository? repository;

  @override
  State<RssArticlesPlaceholderView> createState() =>
      _RssArticlesPlaceholderViewState();
}

class _RssArticlesPlaceholderViewState
    extends State<RssArticlesPlaceholderView> {
  late final RssSourceRepository _repo;
  late final RssArticleRepository _articleRepo;
  late final RssArticleSyncService _syncService;
  int _sortReloadVersion = 0;
  int _fallbackArticleStyle = RssArticleStyleHelper.minStyle;
  String _sortFutureKey = '';
  Future<List<RssSortTab>>? _sortTabsFuture;
  final GlobalKey _moreMenuKey = GlobalKey();

  // 文章列表状态
  int _selectedSortIndex = 0;
  List<RssArticle> _articles = const <RssArticle>[];
  bool _isRefreshing = false;
  bool _isLoadingMore = false;
  String? _refreshError;
  RssArticleSession? _session;
  StreamSubscription<List<RssArticle>>? _articleStreamSub;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    final db = DatabaseService();
    _repo = widget.repository ?? RssSourceRepository(db);
    _articleRepo = RssArticleRepository(db);
    _syncService = RssArticleSyncService(db: db, articleRepository: _articleRepo);
  }

  @override
  void dispose() {
    _articleStreamSub?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _subscribeArticles(String sourceUrl, String sortName) {
    _articleStreamSub?.cancel();
    _articleStreamSub = _articleRepo
        .flowByOriginSort(sourceUrl, sortName)
        .listen((articles) {
      if (!mounted) return;
      setState(() => _articles = articles);
    });
  }

  Future<void> _onSortTabSelected(
    int index,
    List<RssSortTab> tabs,
    RssSource? source,
  ) async {
    if (_selectedSortIndex == index && _session != null) return;
    setState(() {
      _selectedSortIndex = index;
      _articles = const <RssArticle>[];
      _session = null;
      _refreshError = null;
    });
    final tab = tabs.isNotEmpty ? tabs[index] : null;
    final sortName = tab?.name ?? '';
    final sourceUrl = source?.sourceUrl.trim() ?? '';
    if (sourceUrl.isNotEmpty) {
      _subscribeArticles(sourceUrl, sortName);
    }
    if (source != null && tab != null) {
      await _doRefresh(source: source, tab: tab);
    }
  }

  Future<void> _doRefresh({
    required RssSource source,
    required RssSortTab tab,
  }) async {
    if (_isRefreshing) return;
    setState(() {
      _isRefreshing = true;
      _refreshError = null;
    });
    try {
      final result = await _syncService.refresh(
        source: source,
        sortName: tab.name,
        sortUrl: tab.url,
      );
      if (!mounted) return;
      setState(() {
        _session = result.session;
        _isRefreshing = false;
        if (result.error != null) _refreshError = result.error;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isRefreshing = false;
        _refreshError = e.toString();
      });
    }
  }

  Future<void> _doLoadMore(RssSource source) async {
    final session = _session;
    if (session == null || !session.hasMore || _isLoadingMore) return;
    setState(() => _isLoadingMore = true);
    try {
      final result = await _syncService.loadMore(
        source: source,
        session: session,
      );
      if (!mounted) return;
      setState(() {
        _session = result.session;
        _isLoadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingMore = false);
    }
  }

  String get _sourceUrlKey => widget.sourceUrl.trim();

  RssSource? _buildFallbackSource() {
    final sourceUrl = _sourceUrlKey;
    if (sourceUrl.isEmpty) return null;
    return RssSource(
      sourceUrl: sourceUrl,
      sourceName: widget.sourceName.trim(),
      articleStyle: _fallbackArticleStyle,
    );
  }

  RssSource? _resolveCurrentSource(List<RssSource>? sources) {
    final key = _sourceUrlKey;
    if (key.isEmpty) return null;
    if (sources != null) {
      for (final source in sources) {
        if (source.sourceUrl.trim() == key) {
          return source;
        }
      }
    }
    return _repo.getByKey(key);
  }

  RssSource? _resolveMenuSource(RssSource? source) {
    return source ?? _buildFallbackSource();
  }

  String _buildSortFutureKey(RssSource? source) {
    final sourceUrl = source?.sourceUrl.trim() ?? '';
    final sortUrl = (source?.sortUrl ?? '').trim();
    return '$sourceUrl::$sortUrl::$_sortReloadVersion';
  }

  void _ensureSortTabsFuture(RssSource? source) {
    final key = _buildSortFutureKey(source);
    if (_sortTabsFuture != null && _sortFutureKey == key) {
      return;
    }
    _sortFutureKey = key;
    _sortTabsFuture = _loadSortTabs(source);
  }

  Future<List<RssSortTab>> _loadSortTabs(RssSource? source) async {
    if (source == null) return const <RssSortTab>[];
    try {
      return await RssSortUrlsHelper.resolveSortTabs(source);
    } catch (error, stackTrace) {
      ExceptionLogService().record(
        node: 'rss_articles.sort_tabs',
        message: 'RSS 分类解析失败',
        error: error,
        stackTrace: stackTrace,
        context: <String, dynamic>{
          'sourceUrl': source.sourceUrl,
        },
      );
      return const <RssSortTab>[];
    }
  }

  String _resolvePageTitle(RssSource? source) {
    final sourceName = source?.sourceName.trim() ?? '';
    if (sourceName.isNotEmpty) return sourceName;
    final initialName = widget.sourceName.trim();
    if (initialName.isNotEmpty) return initialName;
    return 'RSS 文章列表';
  }

  bool _canOpenLogin(RssSource? source) {
    return (source?.loginUrl ?? '').trim().isNotEmpty;
  }

  Widget? _buildTrailingAction(RssSource? source) {
    if (source == null) return null;
    final actions = _buildMenuActions(source);
    if (actions.isEmpty) return null;
    return CupertinoButton(
      key: _moreMenuKey,
      padding: EdgeInsets.zero,
      minimumSize: const Size(28, 28),
      onPressed: () => _showMoreMenu(
        source: source,
        actions: actions,
      ),
      child: const Icon(CupertinoIcons.ellipsis_circle, size: 20),
    );
  }

  List<_RssArticlesMenuAction> _buildMenuActions(RssSource source) {
    final actions = <_RssArticlesMenuAction>[
      _RssArticlesMenuAction.refreshSort,
      _RssArticlesMenuAction.setSourceVariable,
      _RssArticlesMenuAction.editSource,
      _RssArticlesMenuAction.switchLayout,
      _RssArticlesMenuAction.readRecord,
      _RssArticlesMenuAction.clear,
    ];
    if (_canOpenLogin(source)) {
      actions.insert(0, _RssArticlesMenuAction.login);
    }
    return actions;
  }

  String _menuActionText(_RssArticlesMenuAction action) {
    switch (action) {
      case _RssArticlesMenuAction.login:
        return '登录';
      case _RssArticlesMenuAction.refreshSort:
        return '刷新分类';
      case _RssArticlesMenuAction.setSourceVariable:
        return '设置源变量';
      case _RssArticlesMenuAction.editSource:
        return '编辑源';
      case _RssArticlesMenuAction.switchLayout:
        return '切换布局';
      case _RssArticlesMenuAction.readRecord:
        return '阅读记录';
      case _RssArticlesMenuAction.clear:
        return '清除';
    }
  }

  IconData _menuActionIcon(_RssArticlesMenuAction action) {
    switch (action) {
      case _RssArticlesMenuAction.login:
        return CupertinoIcons.person;
      case _RssArticlesMenuAction.refreshSort:
        return CupertinoIcons.refresh;
      case _RssArticlesMenuAction.setSourceVariable:
        return CupertinoIcons.slider_horizontal_3;
      case _RssArticlesMenuAction.editSource:
        return CupertinoIcons.pencil;
      case _RssArticlesMenuAction.switchLayout:
        return CupertinoIcons.square_grid_2x2;
      case _RssArticlesMenuAction.readRecord:
        return CupertinoIcons.clock;
      case _RssArticlesMenuAction.clear:
        return CupertinoIcons.delete;
    }
  }

  Future<void> _showMoreMenu({
    required RssSource source,
    required List<_RssArticlesMenuAction> actions,
  }) async {
    if (!mounted) return;
    final selected = await showAppPopoverMenu<_RssArticlesMenuAction>(
      context: context,
      anchorKey: _moreMenuKey,
      items: actions
          .map(
            (action) => AppPopoverMenuItem(
              value: action,
              icon: _menuActionIcon(action),
              label: _menuActionText(action),
              isDestructiveAction: action == _RssArticlesMenuAction.clear,
            ),
          )
          .toList(growable: false),
    );
    if (selected == null) return;
    switch (selected) {
      case _RssArticlesMenuAction.login:
        await _openSourceLogin(source);
      case _RssArticlesMenuAction.refreshSort:
        await _refreshSort(source);
      case _RssArticlesMenuAction.setSourceVariable:
        await _setSourceVariable(source);
      case _RssArticlesMenuAction.editSource:
        await _openEditSource(source);
      case _RssArticlesMenuAction.switchLayout:
        await _switchLayout(source);
      case _RssArticlesMenuAction.readRecord:
        await _openReadRecord();
      case _RssArticlesMenuAction.clear:
        await _clearArticles(source);
    }
  }

  Future<void> _openReadRecord() async {
    if (!mounted) return;
    await Navigator.of(context).push<void>(
      CupertinoPageRoute<void>(
        builder: (_) => const RssReadRecordView(),
      ),
    );
  }

  Future<void> _clearArticles(RssSource source) async {
    final sourceUrl = source.sourceUrl.trim();
    if (sourceUrl.isEmpty) return;
    try {
      await _articleRepo.deleteByOrigin(sourceUrl);
    } catch (error, stackTrace) {
      ExceptionLogService().record(
        node: 'rss_articles.menu_clear',
        message: '清除 RSS 文章缓存失败',
        error: error,
        stackTrace: stackTrace,
        context: <String, dynamic>{
          'sourceUrl': sourceUrl,
        },
      );
    }
  }

  Future<void> _refreshSort(RssSource source) async {
    final sourceUrl = source.sourceUrl.trim();
    if (sourceUrl.isEmpty) return;
    final current = _repo.getByKey(sourceUrl) ?? source;
    try {
      await RssSortUrlsHelper.clearSortCache(current);
    } catch (error, stackTrace) {
      ExceptionLogService().record(
        node: 'rss_articles.menu_refresh_sort',
        message: '刷新 RSS 分类缓存失败',
        error: error,
        stackTrace: stackTrace,
        context: <String, dynamic>{
          'sourceUrl': current.sourceUrl,
          'sortUrl': current.sortUrl,
        },
      );
      return;
    }
    if (!mounted) return;
    setState(() {
      _sortReloadVersion += 1;
    });
  }

  Future<void> _switchLayout(RssSource source) async {
    final sourceUrl = source.sourceUrl.trim();
    if (sourceUrl.isEmpty) return;
    final cached = _repo.getByKey(sourceUrl);
    final current = cached ?? source;
    final nextStyle = RssArticleStyleHelper.nextStyle(current.articleStyle);

    if (cached == null) {
      if (!mounted) return;
      setState(() {
        _fallbackArticleStyle = nextStyle;
        _sortReloadVersion += 1;
      });
      return;
    }

    try {
      await _repo.updateSource(
        cached.copyWith(articleStyle: nextStyle),
      );
    } catch (error, stackTrace) {
      ExceptionLogService().record(
        node: 'rss_articles.menu_switch_layout',
        message: '切换 RSS 文章布局失败',
        error: error,
        stackTrace: stackTrace,
        context: <String, dynamic>{
          'sourceUrl': sourceUrl,
          'fromStyle': cached.articleStyle,
          'toStyle': nextStyle,
        },
      );
      return;
    }

    if (!mounted) return;
    setState(() {
      _fallbackArticleStyle = nextStyle;
      _sortReloadVersion += 1;
    });
  }

  String _displaySourceVariableComment(RssSource source) {
    const defaultComment = '源变量可在js中通过source.getVariable()获取';
    return source.getDisplayVariableComment(defaultComment);
  }

  Future<void> _setSourceVariable(RssSource source) async {
    final sourceUrl = source.sourceUrl.trim();
    if (sourceUrl.isEmpty) {
      await showRssLoginMessage(context, '源不存在');
      return;
    }
    final current = _repo.getByKey(sourceUrl) ?? source;
    final note = _displaySourceVariableComment(current);
    final initial = await SourceVariableStore.getVariable(sourceUrl) ?? '';
    if (!mounted) return;

    final controller = TextEditingController(text: initial);
    final result = await showCupertinoBottomSheetDialog<String>(
      context: context,
      builder: (popupContext) => CupertinoPopupSurface(
        isSurfacePainted: true,
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: MediaQuery.of(popupContext).size.height * 0.78,
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
                      const Expanded(
                        child: Text(
                          '设置源变量',
                          maxLines: 1,
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      CupertinoButton(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        onPressed: () =>
                            Navigator.pop(popupContext, controller.text),
                        child: const Text('保存'),
                      ),
                    ],
                  ),
                ),
                Container(
                  height: 0.5,
                  color: CupertinoColors.separator.resolveFrom(popupContext),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          note,
                          style: TextStyle(
                            fontSize: 12,
                            color: CupertinoColors.secondaryLabel.resolveFrom(context)
                                .resolveFrom(popupContext),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Expanded(
                          child: CupertinoTextField(
                            controller: controller,
                            minLines: null,
                            maxLines: null,
                            expands: true,
                            textAlignVertical: TextAlignVertical.top,
                            placeholder: '输入变量 JSON 或文本',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    controller.dispose();
    if (result == null) return;

    await SourceVariableStore.putVariable(sourceUrl, result);
  }

  Future<void> _openSourceLogin(RssSource source) async {
    if (!mounted) return;
    await openRssSourceLogin(
      context: context,
      repository: _repo,
      source: source,
    );
  }

  Future<void> _openEditSource(RssSource source) async {
    final sourceUrl = source.sourceUrl.trim();
    if (sourceUrl.isEmpty || !mounted) return;
    try {
      final saved = await Navigator.of(context).push<bool>(
        CupertinoPageRoute<bool>(
          builder: (_) => RssSourceEditView(sourceUrl: sourceUrl),
        ),
      );
      if (!mounted || saved != true) return;
      setState(() {
        _sortReloadVersion += 1;
      });
    } catch (error, stackTrace) {
      ExceptionLogService().record(
        node: 'rss_articles.menu_edit_source',
        message: '打开 RSS 源编辑页失败',
        error: error,
        stackTrace: stackTrace,
        context: <String, dynamic>{
          'sourceUrl': sourceUrl,
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<RssSource>>(
      stream: _repo.watchAllSources(),
      builder: (context, snapshot) {
        final source = _resolveCurrentSource(snapshot.data);
        final menuSource = _resolveMenuSource(source);
        final title = _resolvePageTitle(menuSource);
        _ensureSortTabsFuture(menuSource);

        return AppCupertinoPageScaffold(
          title: title,
          trailing: _buildTrailingAction(menuSource),
          child: FutureBuilder<List<RssSortTab>>(
            future: _sortTabsFuture,
            builder: (context, sortSnapshot) {
              final tabs = sortSnapshot.data ?? const <RssSortTab>[];
              // 首次加载完 tabs 后自动触发刷新
              if (sortSnapshot.connectionState == ConnectionState.done &&
                  _session == null &&
                  !_isRefreshing &&
                  tabs.isNotEmpty &&
                  menuSource != null) {
                final idx = _selectedSortIndex.clamp(0, tabs.length - 1);
                final tab = tabs[idx];
                SchedulerBinding.instance.addPostFrameCallback((_) {
                  if (mounted && _session == null && !_isRefreshing) {
                    _onSortTabSelected(idx, tabs, menuSource);
                  }
                });
                // 初始化流订阅（避免重复）
                final sourceUrl = menuSource.sourceUrl.trim();
                if (_articleStreamSub == null && sourceUrl.isNotEmpty) {
                  _subscribeArticles(sourceUrl, tab.name);
                }
              }

              final isGridView = RssArticleStyleHelper.isGridStyle(
                menuSource?.articleStyle ?? _fallbackArticleStyle,
              );
              final separatorColor =
                  CupertinoColors.separator.resolveFrom(context);

              return Column(
                children: [
                  // 分类 Tab 栏
                  if (tabs.length > 1)
                    _RssSortTabBar(
                      tabs: tabs,
                      selectedIndex:
                          _selectedSortIndex.clamp(0, tabs.length - 1),
                      onTap: (idx) =>
                          _onSortTabSelected(idx, tabs, menuSource),
                    ),
                  if (tabs.length > 1)
                    Container(height: 0.5, color: separatorColor),
                  // 文章列表
                  Expanded(
                    child: _buildArticleBody(
                      context: context,
                      source: menuSource,
                      tabs: tabs,
                      isGridView: isGridView,
                      isLoadingTabs: sortSnapshot.connectionState ==
                          ConnectionState.waiting,
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildArticleBody({
    required BuildContext context,
    required RssSource? source,
    required List<RssSortTab> tabs,
    required bool isGridView,
    required bool isLoadingTabs,
  }) {
    if (isLoadingTabs && _articles.isEmpty) {
      return const Center(child: CupertinoActivityIndicator());
    }

    final articles = _articles;
    final hasMore = RssArticleLoadMoreHelper.shouldShowManualLoadMore(
      isLoading: _isLoadingMore,
      hasMore: _session?.hasMore ?? false,
      articleCount: articles.length,
    );

    if (articles.isEmpty && !_isRefreshing) {
      return CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          CupertinoSliverRefreshControl(
            onRefresh: source != null && tabs.isNotEmpty
                ? () => _doRefresh(
                      source: source,
                      tab: tabs[
                          _selectedSortIndex.clamp(0, tabs.length - 1)],
                    )
                : null,
          ),
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: _refreshError != null
                  ? Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        _refreshError!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: CupertinoColors.secondaryLabel.resolveFrom(context)
                              .resolveFrom(context),
                          fontSize: 14,
                        ),
                      ),
                    )
                  : Text(
                      '暂无文章',
                      style: TextStyle(
                        color: CupertinoColors.secondaryLabel.resolveFrom(context)
                            .resolveFrom(context),
                      ),
                    ),
            ),
          ),
        ],
      );
    }

    if (isGridView) {
      return _buildGridList(
        context: context,
        articles: articles,
        source: source,
        tabs: tabs,
        hasMore: hasMore,
      );
    }
    return _buildArticleList(
      context: context,
      articles: articles,
      source: source,
      tabs: tabs,
      hasMore: hasMore,
    );
  }

  Widget _buildArticleList({
    required BuildContext context,
    required List<RssArticle> articles,
    required RssSource? source,
    required List<RssSortTab> tabs,
    required bool hasMore,
  }) {
    return CustomScrollView(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        CupertinoSliverRefreshControl(
          onRefresh: source != null && tabs.isNotEmpty
              ? () => _doRefresh(
                    source: source,
                    tab: tabs[_selectedSortIndex.clamp(0, tabs.length - 1)],
                  )
              : null,
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                if (index == articles.length) {
                  return hasMore
                      ? _buildLoadMoreButton(source!)
                      : _isLoadingMore
                          ? const Padding(
                              padding: EdgeInsets.all(16),
                              child: Center(
                                  child: CupertinoActivityIndicator()),
                            )
                          : const SizedBox.shrink();
                }
                final article = articles[index];
                return _RssArticleListTile(
                  article: article,
                  onTap: () => _openArticle(article),
                );
              },
              childCount: articles.length + 1,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGridList({
    required BuildContext context,
    required List<RssArticle> articles,
    required RssSource? source,
    required List<RssSortTab> tabs,
    required bool hasMore,
  }) {
    return CustomScrollView(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        CupertinoSliverRefreshControl(
          onRefresh: source != null && tabs.isNotEmpty
              ? () => _doRefresh(
                    source: source,
                    tab: tabs[_selectedSortIndex.clamp(0, tabs.length - 1)],
                  )
              : null,
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.72,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final article = articles[index];
                return _RssArticleGridCard(
                  article: article,
                  onTap: () => _openArticle(article),
                );
              },
              childCount: articles.length,
            ),
          ),
        ),
        if (hasMore)
          SliverToBoxAdapter(
            child: _buildLoadMoreButton(source!),
          ),
        if (_isLoadingMore)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CupertinoActivityIndicator()),
            ),
          ),
      ],
    );
  }

  Widget _buildLoadMoreButton(RssSource source) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: CupertinoButton(
        onPressed: () => _doLoadMore(source),
        child: const Text('加载更多'),
      ),
    );
  }

  Future<void> _openArticle(RssArticle article) async {
    if (!mounted) return;
    await Navigator.of(context).push<void>(
      CupertinoPageRoute<void>(
        builder: (_) => RssReadPlaceholderView(
          title: article.title,
          origin: article.origin,
          link: article.link,
          repository: _repo,
        ),
      ),
    );
  }
}

class _RssSortTabBar extends StatelessWidget {
  const _RssSortTabBar({
    required this.tabs,
    required this.selectedIndex,
    required this.onTap,
  });

  final List<RssSortTab> tabs;
  final int selectedIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final activeColor = CupertinoTheme.of(context).primaryColor;
    final separatorColor = CupertinoColors.separator.resolveFrom(context);
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: tabs.length,
        separatorBuilder: (_, __) => const SizedBox(width: 4),
        itemBuilder: (context, index) {
          final tab = tabs[index];
          final selected = index == selectedIndex;
          final label =
              tab.name.trim().isEmpty ? '默认' : tab.name.trim();
          return GestureDetector(
            onTap: () => onTap(index),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOut,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: selected
                    ? activeColor.withValues(alpha: 0.12)
                    : CupertinoColors.tertiarySystemGroupedBackground.resolveFrom(context)
                        .resolveFrom(context),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: selected
                      ? activeColor.withValues(alpha: 0.4)
                      : separatorColor.withValues(alpha: 0.6),
                  width: 0.5,
                ),
              ),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight:
                      selected ? FontWeight.w600 : FontWeight.w400,
                  color: selected
                      ? activeColor
                      : CupertinoColors.label.resolveFrom(context),
                  letterSpacing: -0.2,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _RssArticleListTile extends StatelessWidget {
  const _RssArticleListTile({
    required this.article,
    required this.onTap,
  });

  final RssArticle article;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final secondaryLabel =
        CupertinoColors.secondaryLabel.resolveFrom(context);
    final separatorColor = CupertinoColors.separator.resolveFrom(context);
    final imageUrl = (article.image ?? '').trim();
    final hasImage = imageUrl.isNotEmpty;
    final isRead = article.read;
    final titleColor = isRead
        ? CupertinoColors.secondaryLabel.resolveFrom(context)
        : CupertinoColors.label.resolveFrom(context);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 上方大图（全宽 220dp，对应 legado item_rss_article_2.xml）
          if (hasImage)
            SizedBox(
              height: 180,
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => Container(
                  height: 180,
                  color: CupertinoColors.systemGrey5.resolveFrom(context),
                ),
              ),
            ),
          // 标题 + 日期
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  article.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: titleColor,
                    height: 1.35,
                  ),
                ),
                if ((article.pubDate ?? '').isNotEmpty) ...
                  [
                    const SizedBox(height: 6),
                    Text(
                      article.pubDate!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: secondaryLabel,
                      ),
                    ),
                  ],
              ],
            ),
          ),
          Container(height: 0.5, color: separatorColor),
        ],
      ),
    );
  }
}

class _RssArticleGridCard extends StatelessWidget {
  const _RssArticleGridCard({
    required this.article,
    required this.onTap,
  });

  final RssArticle article;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final secondaryLabel =
        CupertinoColors.secondaryLabel.resolveFrom(context);
    final cardBg = CupertinoColors.secondarySystemGroupedBackground.resolveFrom(context)
        .resolveFrom(context);
    final imageUrl = (article.image ?? '').trim();
    final hasImage = imageUrl.isNotEmpty;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Container(
          color: cardBg,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (hasImage)
                Expanded(
                  child: CachedNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => Container(
                      color: CupertinoColors.systemGrey5.resolveFrom(context),
                    ),
                  ),
                )
              else
                Expanded(
                  child: Container(
                    color: CupertinoColors.systemGrey5.resolveFrom(context),
                    child: Icon(
                      CupertinoIcons.photo,
                      size: 32,
                      color: CupertinoColors.systemGrey.resolveFrom(context),
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
                child: Text(
                  article.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                  ),
                ),
              ),
              if ((article.pubDate ?? '').isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 6),
                  child: Text(
                    article.pubDate!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: secondaryLabel,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
