import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/theme/design_tokens.dart';
import '../../../app/widgets/app_toast.dart';
import '../../../app/widgets/app_cupertino_page_scaffold.dart';
import '../../../app/widgets/app_empty_state.dart';
import '../../../app/widgets/app_popover_menu.dart';
import '../../../app/widgets/cupertino_bottom_dialog.dart';
import '../../../core/database/database_service.dart';
import '../../../core/database/repositories/rss_article_repository.dart';
import '../../../core/database/repositories/rss_star_repository.dart';
import '../../../core/database/repositories/rss_source_repository.dart';
import '../../../core/services/exception_log_service.dart';
import '../../../core/services/source_variable_store.dart';
import '../../source/models/book_source.dart';
import '../../source/services/source_login_url_resolver.dart';
import '../../source/views/source_login_form_view.dart';
import '../../source/views/source_login_webview_view.dart';
import '../models/rss_article.dart';
import '../models/rss_star.dart';
import '../models/rss_source.dart';
import '../services/rss_article_load_more_helper.dart';
import '../services/rss_article_style_helper.dart';
import '../services/rss_article_sync_service.dart';
import '../services/rss_sort_urls_helper.dart';
import 'rss_read_record_view.dart';
import 'rss_source_edit_view.dart';

enum _RssArticlesMenuAction {
  login,
  refreshSort,
  setSourceVariable,
  editSource,
  switchLayout,
  readRecord,
  clear,
}

enum _RssReadMenuAction {
  login,
  browserOpen,
}

enum _RssFavoriteDialogAction {
  cancel,
  confirm,
  delete,
}

enum _RssFavoritesMenuAction {
  deleteCurrentGroup,
  deleteAll,
}

BookSource _bookSourceFromRssSource(RssSource source) {
  return BookSource(
    bookSourceUrl: source.sourceUrl,
    bookSourceName: source.sourceName,
    bookSourceGroup: source.sourceGroup,
    customOrder: source.customOrder,
    enabled: source.enabled,
    enabledExplore: false,
    jsLib: source.jsLib,
    enabledCookieJar: source.enabledCookieJar ?? true,
    concurrentRate: source.concurrentRate,
    header: source.header,
    loginUrl: source.loginUrl,
    loginUi: source.loginUi,
    loginCheckJs: source.loginCheckJs,
    coverDecodeJs: source.coverDecodeJs,
    bookSourceComment: source.sourceComment,
    variableComment: source.variableComment,
    lastUpdateTime: source.lastUpdateTime,
    respondTime: 180000,
    weight: 0,
  );
}

RssStar _rssStarFromArticle(
  RssArticle article, {
  int? starTime,
}) {
  return RssStar(
    origin: article.origin,
    sort: article.sort,
    title: article.title,
    starTime: starTime ?? DateTime.now().millisecondsSinceEpoch,
    link: article.link,
    pubDate: article.pubDate,
    description: article.description,
    content: article.content,
    image: article.image,
    group: article.group,
    variable: article.variable,
  );
}

Future<void> _showRssLoginMessage(
  BuildContext context,
  String message,
) async {
  if (!context.mounted) return;
  await showCupertinoBottomDialog<void>(
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

Future<void> _openRssSourceLogin({
  required BuildContext context,
  required RssSourceRepository repository,
  required RssSource source,
}) async {
  final current = repository.getByKey(source.sourceUrl) ?? source;
  final loginSource = _bookSourceFromRssSource(current);
  final hasLoginUi = (current.loginUi ?? '').trim().isNotEmpty;

  if (hasLoginUi) {
    if (!context.mounted) return;
    await Navigator.of(context).push<void>(
      CupertinoPageRoute<void>(
        builder: (_) => SourceLoginFormView(source: loginSource),
      ),
    );
    return;
  }

  final resolvedUrl = SourceLoginUrlResolver.resolve(
    baseUrl: current.sourceUrl,
    loginUrl: current.loginUrl ?? '',
  );
  if (resolvedUrl.isEmpty) {
    await _showRssLoginMessage(context, '当前源未配置登录地址');
    return;
  }
  final uri = Uri.tryParse(resolvedUrl);
  final scheme = uri?.scheme.toLowerCase();
  if (scheme != 'http' && scheme != 'https') {
    await _showRssLoginMessage(context, '登录地址不是有效网页地址');
    return;
  }

  if (!context.mounted) return;
  await Navigator.of(context).push<void>(
    CupertinoPageRoute<void>(
      builder: (_) => SourceLoginWebViewView(
        source: loginSource,
        initialUrl: resolvedUrl,
      ),
    ),
  );
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

  int _resolveArticleStyle(RssSource? source) {
    final style = source?.articleStyle ?? _fallbackArticleStyle;
    return RssArticleStyleHelper.normalize(style);
  }

  String _buildLayoutStatus(RssSource? source) {
    final style = _resolveArticleStyle(source);
    final layout = RssArticleStyleHelper.isGridStyle(style) ? '网格布局' : '列表布局';
    return 'articleStyle=$style（$layout）';
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
      await _showRssLoginMessage(context, '源不存在');
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
                            color: CupertinoColors.secondaryLabel
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
    await _openRssSourceLogin(
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
                          color: CupertinoColors.secondaryLabel
                              .resolveFrom(context),
                          fontSize: 14,
                        ),
                      ),
                    )
                  : Text(
                      '暂无文章',
                      style: TextStyle(
                        color: CupertinoColors.secondaryLabel
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

class RssReadPlaceholderView extends StatefulWidget {
  const RssReadPlaceholderView({
    super.key,
    required this.title,
    required this.origin,
    this.link,
    this.repository,
  });

  final String title;
  final String origin;
  final String? link;
  final RssSourceRepository? repository;

  @override
  State<RssReadPlaceholderView> createState() => _RssReadPlaceholderViewState();
}

class _RssReadPlaceholderViewState extends State<RssReadPlaceholderView> {
  late final RssSourceRepository _repo;
  late final RssArticleRepository _articleRepo;
  late final RssStarRepository _starRepo;
  int _refreshVersion = 0;
  DateTime? _lastRefreshAt;
  RssArticle? _rssArticle;
  RssStar? _rssStar;
  int _favoriteLoadVersion = 0;
  bool _favoriteActionRunning = false;
  FlutterTts? _readAloudTts;
  bool _readAloudTtsReady = false;
  bool _readAloudPlaying = false;

  @override
  void initState() {
    super.initState();
    _repo = widget.repository ?? RssSourceRepository(DatabaseService());
    _articleRepo = RssArticleRepository(DatabaseService());
    _starRepo = RssStarRepository(DatabaseService());
    _reloadFavoriteContext();
  }

  @override
  void dispose() {
    unawaited(_disposeReadAloudTts());
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant RssReadPlaceholderView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldOrigin = oldWidget.origin.trim();
    final oldLink = (oldWidget.link ?? '').trim();
    if (oldOrigin != _originKey || oldLink != _linkKey) {
      _reloadFavoriteContext();
    }
  }

  String get _originKey => widget.origin.trim();
  String get _linkKey => (widget.link ?? '').trim();

  RssSource? _resolveCurrentSource(List<RssSource>? sources) {
    final key = _originKey;
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

  bool _canOpenLogin(RssSource? source) {
    return (source?.loginUrl ?? '').trim().isNotEmpty;
  }

  bool get _canShowFavoriteAction => _rssArticle != null;
  bool get _isInFavorites => _rssStar != null;

  String _buildLoginStatus(RssSource? source) {
    return _canOpenLogin(source) ? '可见（loginUrl 已配置）' : '隐藏（loginUrl 为空或源未命中）';
  }

  String _buildFavoriteStatus() {
    if (!_canShowFavoriteAction) {
      return '隐藏（当前页面未命中文章）';
    }
    if (_isInFavorites) {
      final group = _rssStar!.group.trim();
      final normalizedGroup = group.isEmpty ? '默认分组' : group;
      return '已收藏（$normalizedGroup）';
    }
    return '未收藏';
  }

  String? _resolveShareTarget() {
    final currentLink = _linkKey;
    if (currentLink.isNotEmpty) {
      return currentLink;
    }
    final articleLink = (_rssArticle?.link ?? '').trim();
    if (articleLink.isNotEmpty) {
      return articleLink;
    }
    return null;
  }

  String _buildShareStatus() {
    return _resolveShareTarget() ?? '不可用（Null url）';
  }

  String? _resolveBrowserOpenTarget() {
    final currentLink = _linkKey;
    if (currentLink.isNotEmpty) {
      return currentLink;
    }
    final articleLink = (_rssArticle?.link ?? '').trim();
    if (articleLink.isNotEmpty) {
      return articleLink;
    }
    final origin = _originKey;
    if (origin.isNotEmpty) {
      return origin;
    }
    return null;
  }

  String _buildBrowserOpenStatus() {
    return _resolveBrowserOpenTarget() ?? '不可用（url null）';
  }

  String _normalizeReadAloudText(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return '';
    final parsed = html_parser.parse(trimmed);
    final bodyText = parsed.body?.text ?? '';
    final documentText = parsed.documentElement?.text ?? '';
    final source = bodyText.trim().isNotEmpty ? bodyText : documentText;
    final lines = source
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList(growable: false);
    if (lines.isNotEmpty) {
      return lines.join('\n');
    }
    return trimmed;
  }

  String _resolveReadAloudText() {
    final candidates = <String?>[
      _rssArticle?.description,
      _rssArticle?.content,
      _rssArticle?.title,
      widget.title,
    ];
    for (final candidate in candidates) {
      final normalized = _normalizeReadAloudText(candidate ?? '');
      if (normalized.isNotEmpty) {
        return normalized;
      }
    }
    return '';
  }

  String _buildReadAloudStatus() {
    if (_readAloudPlaying) {
      return '朗读中（点击顶栏朗读按钮可停止）';
    }
    final text = _resolveReadAloudText();
    if (text.isEmpty) {
      return '未朗读（当前无可朗读文本）';
    }
    return '未朗读（可用文本 ${text.length} 字）';
  }

  void _showToast(String message) {
    if (!mounted) return;
    unawaited(showAppToast(context, message: message));
  }

  Future<void> _reloadFavoriteContext() async {
    final loadVersion = ++_favoriteLoadVersion;
    final origin = _originKey;
    final link = _linkKey;
    if (origin.isEmpty || link.isEmpty) {
      if (!mounted || loadVersion != _favoriteLoadVersion) return;
      setState(() {
        _rssArticle = null;
        _rssStar = null;
      });
      return;
    }
    try {
      final star = await _starRepo.get(origin, link);
      final article =
          star?.toRssArticle() ?? await _articleRepo.get(origin, link);
      if (!mounted || loadVersion != _favoriteLoadVersion) return;
      setState(() {
        _rssStar = star;
        _rssArticle = article;
      });
    } catch (error, stackTrace) {
      if (!mounted || loadVersion != _favoriteLoadVersion) return;
      setState(() {
        _rssStar = null;
        _rssArticle = null;
      });
      ExceptionLogService().record(
        node: 'rss_read.menu_rss_star',
        message: '加载 RSS 收藏状态失败',
        error: error,
        stackTrace: stackTrace,
        context: <String, dynamic>{
          'origin': origin,
          'link': link,
        },
      );
    }
  }

  void _handleRefresh() {
    if (!mounted) return;
    setState(() {
      _refreshVersion += 1;
      _lastRefreshAt = DateTime.now();
    });
  }

  Future<void> _handleShare() async {
    final target = _resolveShareTarget();
    if (target == null) {
      _showToast('Null url');
      return;
    }
    try {
      await SharePlus.instance.share(
        ShareParams(
          text: target,
          subject: '分享',
        ),
      );
    } catch (_) {
      // 对齐 legado Context.share(text)：分享异常静默吞掉，不追加提示。
    }
  }

  Future<void> _handleBrowserOpen() async {
    final target = _resolveBrowserOpenTarget();
    if (target == null) {
      _showToast('url null');
      return;
    }
    final uri = Uri.tryParse(target);
    if (uri == null) {
      ExceptionLogService().record(
        node: 'rss_read.menu_browser_open',
        message: 'RSS 阅读页浏览器打开失败（URL 解析失败）',
        context: <String, dynamic>{
          'origin': _originKey,
          'link': _linkKey,
          'target': target,
        },
      );
      _showToast('open url error');
      return;
    }
    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (launched) {
        return;
      }
      ExceptionLogService().record(
        node: 'rss_read.menu_browser_open',
        message: 'RSS 阅读页浏览器打开失败（launchUrl=false）',
        context: <String, dynamic>{
          'origin': _originKey,
          'link': _linkKey,
          'target': target,
        },
      );
      _showToast('open url error');
    } catch (error, stackTrace) {
      ExceptionLogService().record(
        node: 'rss_read.menu_browser_open',
        message: 'RSS 阅读页浏览器打开失败',
        error: error,
        stackTrace: stackTrace,
        context: <String, dynamic>{
          'origin': _originKey,
          'link': _linkKey,
          'target': target,
        },
      );
      _showToast('open url error');
    }
  }

  Future<FlutterTts> _ensureReadAloudTtsReady() async {
    final existing = _readAloudTts;
    if (existing != null && _readAloudTtsReady) {
      return existing;
    }
    final tts = existing ?? FlutterTts();
    _readAloudTts ??= tts;
    if (!_readAloudTtsReady) {
      tts.setStartHandler(() {
        if (!mounted) return;
        setState(() {
          _readAloudPlaying = true;
        });
      });
      tts.setCompletionHandler(() {
        if (!mounted) return;
        setState(() {
          _readAloudPlaying = false;
        });
      });
      tts.setCancelHandler(() {
        if (!mounted) return;
        setState(() {
          _readAloudPlaying = false;
        });
      });
      tts.setErrorHandler((_) {
        if (!mounted) return;
        setState(() {
          _readAloudPlaying = false;
        });
      });
      await tts.awaitSpeakCompletion(true);
      _readAloudTtsReady = true;
    }
    return tts;
  }

  Future<void> _stopReadAloud() async {
    final tts = _readAloudTts;
    if (tts == null) return;
    try {
      await tts.stop();
    } catch (error, stackTrace) {
      ExceptionLogService().record(
        node: 'rss_read.menu_aloud',
        message: '停止 RSS 朗读失败',
        error: error,
        stackTrace: stackTrace,
        context: <String, dynamic>{
          'origin': _originKey,
          'link': _linkKey,
        },
      );
    }
    if (!mounted) return;
    setState(() {
      _readAloudPlaying = false;
    });
  }

  Future<void> _handleReadAloud() async {
    if (_readAloudPlaying) {
      await _stopReadAloud();
      return;
    }
    final text = _resolveReadAloudText();
    if (text.isEmpty) {
      return;
    }
    try {
      final tts = await _ensureReadAloudTtsReady();
      await tts.stop();
      final result = await tts.speak(text);
      final success = result == null || result == 1 || result == true;
      if (!success) {
        ExceptionLogService().record(
          node: 'rss_read.menu_aloud',
          message: '启动 RSS 朗读失败',
          context: <String, dynamic>{
            'origin': _originKey,
            'link': _linkKey,
            'ttsResult': result.toString(),
          },
        );
        return;
      }
      if (!mounted) return;
      setState(() {
        _readAloudPlaying = true;
      });
    } catch (error, stackTrace) {
      ExceptionLogService().record(
        node: 'rss_read.menu_aloud',
        message: '启动 RSS 朗读失败',
        error: error,
        stackTrace: stackTrace,
        context: <String, dynamic>{
          'origin': _originKey,
          'link': _linkKey,
        },
      );
    }
  }

  Future<void> _disposeReadAloudTts() async {
    final tts = _readAloudTts;
    _readAloudTts = null;
    _readAloudTtsReady = false;
    _readAloudPlaying = false;
    if (tts == null) return;
    try {
      await tts.stop();
    } catch (_) {
      // 页面销毁阶段与 legado 同义静默清理，不额外提示。
    }
  }

  Future<void> _handleFavoriteAction() async {
    final article = _rssArticle;
    if (article == null || _favoriteActionRunning) return;
    setState(() {
      _favoriteActionRunning = true;
    });
    try {
      if (_rssStar == null) {
        final createdStar = _rssStarFromArticle(article);
        await _starRepo.upsert(createdStar);
        if (!mounted) return;
        setState(() {
          _rssStar = createdStar;
          _rssArticle = article.copyWith(
            title: createdStar.title,
            group: createdStar.group,
          );
        });
      }
    } catch (error, stackTrace) {
      ExceptionLogService().record(
        node: 'rss_read.menu_rss_star',
        message: '添加 RSS 收藏失败',
        error: error,
        stackTrace: stackTrace,
        context: <String, dynamic>{
          'origin': article.origin,
          'link': article.link,
        },
      );
      return;
    } finally {
      if (mounted) {
        setState(() {
          _favoriteActionRunning = false;
        });
      }
    }
    if (!mounted) return;
    await _openFavoriteDialog();
  }

  Future<void> _openFavoriteDialog() async {
    final article = _rssArticle;
    if (article == null || !mounted) return;
    final titleController = TextEditingController(text: article.title);
    final groupController = TextEditingController(text: article.group);
    try {
      final action = await showCupertinoBottomDialog<_RssFavoriteDialogAction>(
        context: context,
        builder: (dialogContext) => CupertinoAlertDialog(
          title: const Text('收藏设置'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              CupertinoTextField(
                controller: titleController,
                placeholder: '标题',
              ),
              const SizedBox(height: 8),
              CupertinoTextField(
                controller: groupController,
                placeholder: '分组',
              ),
            ],
          ),
          actions: [
            CupertinoDialogAction(
              isDestructiveAction: true,
              onPressed: () {
                Navigator.of(dialogContext)
                    .pop(_RssFavoriteDialogAction.delete);
              },
              child: const Text('删除收藏'),
            ),
            CupertinoDialogAction(
              onPressed: () {
                Navigator.of(dialogContext)
                    .pop(_RssFavoriteDialogAction.cancel);
              },
              child: const Text('取消'),
            ),
            CupertinoDialogAction(
              onPressed: () {
                Navigator.of(dialogContext)
                    .pop(_RssFavoriteDialogAction.confirm);
              },
              child: const Text('确定'),
            ),
          ],
        ),
      );
      switch (action) {
        case _RssFavoriteDialogAction.delete:
          await _deleteFavorite();
          break;
        case _RssFavoriteDialogAction.confirm:
          final current = _rssArticle;
          if (current == null) return;
          var nextTitle = current.title;
          final editedTitle = titleController.text;
          if (editedTitle.trim().isNotEmpty) {
            nextTitle = editedTitle;
          }
          var nextGroup = current.group;
          final editedGroup = groupController.text;
          if (editedGroup.trim().isNotEmpty) {
            nextGroup = editedGroup;
          }
          await _updateFavorite(title: nextTitle, group: nextGroup);
          break;
        case _RssFavoriteDialogAction.cancel:
        case null:
          break;
      }
    } finally {
      titleController.dispose();
      groupController.dispose();
    }
  }

  Future<void> _updateFavorite({
    required String title,
    required String group,
  }) async {
    final current = _rssArticle;
    if (current == null) return;
    final updatedArticle = current.copyWith(
      title: title,
      group: group,
    );
    final updatedStar = _rssStarFromArticle(updatedArticle);
    try {
      await _starRepo.update(updatedStar);
      if (!mounted) return;
      setState(() {
        _rssArticle = updatedArticle;
        _rssStar = updatedStar;
      });
    } catch (error, stackTrace) {
      ExceptionLogService().record(
        node: 'rss_read.menu_rss_star',
        message: '更新 RSS 收藏失败',
        error: error,
        stackTrace: stackTrace,
        context: <String, dynamic>{
          'origin': updatedArticle.origin,
          'link': updatedArticle.link,
        },
      );
    }
  }

  Future<void> _deleteFavorite() async {
    final star = _rssStar;
    if (star == null) return;
    try {
      await _starRepo.delete(star.origin, star.link);
      if (!mounted) return;
      setState(() {
        _rssStar = null;
      });
    } catch (error, stackTrace) {
      ExceptionLogService().record(
        node: 'rss_read.menu_rss_star',
        message: '删除 RSS 收藏失败',
        error: error,
        stackTrace: stackTrace,
        context: <String, dynamic>{
          'origin': star.origin,
          'link': star.link,
        },
      );
    }
  }

  String _buildRefreshStatus() {
    final at = _lastRefreshAt;
    if (at == null) return '尚未刷新';
    final hour = at.hour.toString().padLeft(2, '0');
    final minute = at.minute.toString().padLeft(2, '0');
    final second = at.second.toString().padLeft(2, '0');
    return '最近刷新 $hour:$minute:$second（第 $_refreshVersion 次）';
  }

  String _readMenuActionText(_RssReadMenuAction action) {
    switch (action) {
      case _RssReadMenuAction.login:
        return '登录';
      case _RssReadMenuAction.browserOpen:
        return '浏览器打开';
    }
  }

  List<_RssReadMenuAction> _buildReadMenuActions(RssSource? source) {
    final actions = <_RssReadMenuAction>[];
    if (_canOpenLogin(source)) {
      actions.add(_RssReadMenuAction.login);
    }
    actions.add(_RssReadMenuAction.browserOpen);
    return actions;
  }

  Future<void> _showMoreMenu(RssSource? source) async {
    if (!mounted) return;
    final actions = _buildReadMenuActions(source);
    final selected = await showCupertinoBottomDialog<_RssReadMenuAction>(
      context: context,
      barrierDismissible: true,
      builder: (sheetContext) => CupertinoActionSheet(
        actions: actions
            .map(
              (action) => CupertinoActionSheetAction(
                onPressed: () {
                  Navigator.pop(sheetContext, action);
                },
                child: Text(_readMenuActionText(action)),
              ),
            )
            .toList(growable: false),
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(sheetContext),
          child: const Text('取消'),
        ),
      ),
    );
    if (selected == null) return;
    switch (selected) {
      case _RssReadMenuAction.login:
        if (source == null) return;
        await _openSourceLogin(source);
        break;
      case _RssReadMenuAction.browserOpen:
        await _handleBrowserOpen();
        break;
    }
  }

  Future<void> _openSourceLogin(RssSource source) async {
    if (!mounted) return;
    await _openRssSourceLogin(
      context: context,
      repository: _repo,
      source: source,
    );
  }

  Widget _buildTrailingAction(RssSource? source) {
    final showFavorite = _canShowFavoriteAction;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CupertinoButton(
          padding: EdgeInsets.zero,
          minimumSize: const Size(28, 28),
          onPressed: _handleRefresh,
          child: const Icon(
            CupertinoIcons.refresh,
            size: 19,
          ),
        ),
        if (showFavorite) ...[
          const SizedBox(width: 6),
          CupertinoButton(
            padding: EdgeInsets.zero,
            minimumSize: const Size(28, 28),
            onPressed: _favoriteActionRunning ? null : _handleFavoriteAction,
            child: Icon(
              _isInFavorites ? CupertinoIcons.star_fill : CupertinoIcons.star,
              size: 19,
            ),
          ),
        ],
        const SizedBox(width: 6),
        CupertinoButton(
          padding: EdgeInsets.zero,
          minimumSize: const Size(28, 28),
          onPressed: _handleShare,
          child: const Icon(
            CupertinoIcons.share,
            size: 19,
          ),
        ),
        const SizedBox(width: 6),
        CupertinoButton(
          padding: EdgeInsets.zero,
          minimumSize: const Size(28, 28),
          onPressed: _handleReadAloud,
          child: Icon(
            _readAloudPlaying
                ? CupertinoIcons.stop_circle
                : CupertinoIcons.volume_up,
            size: 19,
          ),
        ),
        const SizedBox(width: 6),
        CupertinoButton(
          padding: EdgeInsets.zero,
          minimumSize: const Size(28, 28),
          onPressed: () => _showMoreMenu(source),
          child: const Icon(CupertinoIcons.ellipsis_circle, size: 20),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<RssSource>>(
      stream: _repo.watchAllSources(),
      builder: (context, snapshot) {
        final source = _resolveCurrentSource(snapshot.data);
        return AppCupertinoPageScaffold(
          title: widget.title.isEmpty ? 'RSS 阅读' : widget.title,
          trailing: _buildTrailingAction(source),
          child: _RssReadContentView(
            refreshVersion: _refreshVersion,
            article: _rssArticle,
            link: _linkKey,
            origin: _originKey,
          ),
        );
      },
    );
  }
}

/// RSS 阅读内容视图：优先用 WebView 加载 link；无 link 时渲染 HTML 内容。
class _RssReadContentView extends StatefulWidget {
  const _RssReadContentView({
    required this.refreshVersion,
    required this.article,
    required this.link,
    required this.origin,
  });

  final int refreshVersion;
  final RssArticle? article;
  final String link;
  final String origin;

  @override
  State<_RssReadContentView> createState() => _RssReadContentViewState();
}

class _RssReadContentViewState extends State<_RssReadContentView> {
  late final WebViewController _controller;
  bool _isLoading = true;
  String? _lastLoadedKey;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) {
          if (mounted) setState(() => _isLoading = true);
        },
        onPageFinished: (_) {
          if (mounted) setState(() => _isLoading = false);
        },
        onWebResourceError: (_) {
          if (mounted) setState(() => _isLoading = false);
        },
      ));
    _loadContent();
  }

  @override
  void didUpdateWidget(covariant _RssReadContentView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newKey =
        '${widget.refreshVersion}::${widget.link}::${widget.article?.link}';
    if (_lastLoadedKey != newKey) _loadContent();
  }

  void _loadContent() {
    final key =
        '${widget.refreshVersion}::${widget.link}::${widget.article?.link}';
    _lastLoadedKey = key;
    final link = widget.link.trim();
    if (link.isNotEmpty) {
      _controller.loadRequest(Uri.parse(link));
      return;
    }
    final article = widget.article;
    if (article == null) {
      _controller.loadHtmlString('<html><body></body></html>');
      return;
    }
    final content = (article.content?.trim().isNotEmpty == true
            ? article.content!
            : article.description) ??
        '';
    final html = _buildHtml(
      title: article.title,
      content: content,
      baseUrl: widget.origin,
    );
    _controller.loadHtmlString(
      html,
      baseUrl: widget.origin.isNotEmpty ? widget.origin : null,
    );
  }

  String _buildHtml({
    required String title,
    required String content,
    required String baseUrl,
  }) {
    final escapedTitle = title
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;');
    return '''
<!DOCTYPE html><html><head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1.0,user-scalable=yes">
<style>
body{font-family:-apple-system,sans-serif;font-size:16px;line-height:1.6;color:#1c1c1e;padding:16px;margin:0;word-wrap:break-word;}
h1{font-size:20px;font-weight:700;margin-bottom:12px;}
img{max-width:100%;height:auto;border-radius:6px;}
a{color:#007aff;}
@media(prefers-color-scheme:dark){body{background:#1c1c1e;color:#e5e5ea;}a{color:#0a84ff;}}
</style></head><body>
${title.isNotEmpty ? '<h1>$escapedTitle</h1>' : ''}
$content
</body></html>''';
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        WebViewWidget(controller: _controller),
        if (_isLoading)
          const Positioned(
            top: 12,
            left: 0,
            right: 0,
            child: Center(child: CupertinoActivityIndicator()),
          ),
      ],
    );
  }
}

class RssFavoritesPlaceholderView extends StatefulWidget {
  const RssFavoritesPlaceholderView({super.key});

  @override
  State<RssFavoritesPlaceholderView> createState() =>
      _RssFavoritesPlaceholderViewState();
}

class _RssFavoritesPlaceholderViewState
    extends State<RssFavoritesPlaceholderView> {
  late final RssStarRepository _repo;
  String _selectedGroup = '';

  @override
  void initState() {
    super.initState();
    _repo = RssStarRepository(DatabaseService());
  }

  String _resolveCurrentGroup(List<String> groups) {
    if (groups.isEmpty) return '';
    final selected = _selectedGroup.trim();
    if (selected.isNotEmpty && groups.contains(selected)) {
      return selected;
    }
    return groups.first;
  }

  void _selectGroup(String group) {
    final next = group.trim();
    if (next.isEmpty || next == _selectedGroup) return;
    setState(() {
      _selectedGroup = next;
    });
  }

  Future<void> _openGroupMenu({
    required List<String> groups,
    required String currentGroup,
  }) async {
    if (!mounted || groups.isEmpty) return;
    await showCupertinoBottomDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (sheetContext) {
        return CupertinoActionSheet(
          title: const Text('分组'),
          actions: [
            for (final group in groups)
              CupertinoActionSheetAction(
                isDefaultAction: group == currentGroup,
                onPressed: () {
                  Navigator.of(sheetContext).pop();
                  _selectGroup(group);
                },
                child: Text(group),
              ),
          ],
          cancelButton: CupertinoActionSheetAction(
            onPressed: () => Navigator.of(sheetContext).pop(),
            child: const Text('取消'),
          ),
        );
      },
    );
  }

  Future<void> _openMoreMenu({
    required String currentGroup,
  }) async {
    if (!mounted) return;
    final selected = await showCupertinoBottomDialog<_RssFavoritesMenuAction>(
      context: context,
      barrierDismissible: true,
      builder: (sheetContext) {
        return CupertinoActionSheet(
          actions: [
            CupertinoActionSheetAction(
              isDestructiveAction: true,
              onPressed: () {
                Navigator.of(sheetContext).pop(
                  _RssFavoritesMenuAction.deleteCurrentGroup,
                );
              },
              child: const Text('删除当前分组'),
            ),
            CupertinoActionSheetAction(
              isDestructiveAction: true,
              onPressed: () {
                Navigator.of(sheetContext).pop(
                  _RssFavoritesMenuAction.deleteAll,
                );
              },
              child: const Text('删除所有'),
            ),
          ],
          cancelButton: CupertinoActionSheetAction(
            onPressed: () => Navigator.of(sheetContext).pop(),
            child: const Text('取消'),
          ),
        );
      },
    );
    if (selected == null) return;
    switch (selected) {
      case _RssFavoritesMenuAction.deleteCurrentGroup:
        await _deleteCurrentGroup(currentGroup);
        break;
      case _RssFavoritesMenuAction.deleteAll:
        await _deleteAllFavorites();
        break;
    }
  }

  Future<void> _deleteCurrentGroup(String currentGroup) async {
    final group = currentGroup.trim();
    if (group.isEmpty || !mounted) return;
    final confirmed = await showCupertinoBottomDialog<bool>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: const Text('提示'),
        content: Text('确定删除\n<$group>分组'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('确定'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _repo.deleteByGroup(group);
    } catch (error, stackTrace) {
      ExceptionLogService().record(
        node: 'rss_favorites.menu_del_group',
        message: '删除 RSS 收藏分组失败',
        error: error,
        stackTrace: stackTrace,
        context: <String, dynamic>{
          'group': group,
        },
      );
    }
  }

  Future<void> _deleteAllFavorites() async {
    if (!mounted) return;
    final confirmed = await showCupertinoBottomDialog<bool>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: const Text('提示'),
        content: const Text('确定删除\n<全部>收藏'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('确定'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _repo.deleteAll();
    } catch (error, stackTrace) {
      ExceptionLogService().record(
        node: 'rss_favorites.menu_del_all',
        message: '删除全部 RSS 收藏失败',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Widget _buildTrailingActions({
    required List<String> groups,
    required String currentGroup,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CupertinoButton(
          padding: EdgeInsets.zero,
          minimumSize: const Size(28, 28),
          onPressed: groups.isEmpty
              ? null
              : () => _openGroupMenu(
                    groups: groups,
                    currentGroup: currentGroup,
                  ),
          child: const Icon(CupertinoIcons.square_grid_2x2, size: 20),
        ),
        CupertinoButton(
          padding: EdgeInsets.zero,
          minimumSize: const Size(28, 28),
          onPressed: () => _openMoreMenu(currentGroup: currentGroup),
          child: const Icon(CupertinoIcons.ellipsis_circle, size: 20),
        ),
      ],
    );
  }

  Future<void> _openRead(RssStar star) async {
    if (!mounted) return;
    await Navigator.of(context).push<void>(
      CupertinoPageRoute<void>(
        builder: (_) => RssReadPlaceholderView(
          title: star.title,
          origin: star.origin,
          link: star.link,
        ),
      ),
    );
  }

  Widget _buildGroupSegmentedControl(
    List<String> groups,
    String currentGroup,
  ) {
    if (groups.length <= 1) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      child: CupertinoSlidingSegmentedControl<String>(
        groupValue: currentGroup,
        children: {
          for (final group in groups)
            group: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Text(
                group,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12),
              ),
            ),
        },
        onValueChanged: (value) {
          if (value == null) return;
          _selectGroup(value);
        },
      ),
    );
  }

  Widget _buildGroupList(String group) {
    return StreamBuilder<List<RssStar>>(
      stream: _repo.watchByGroup(group),
      builder: (context, snapshot) {
        final stars = snapshot.data ?? const <RssStar>[];
        if (stars.isEmpty) {
          return const AppEmptyState(
            illustration: AppEmptyPlanetIllustration(size: 82),
            title: '当前分组暂无收藏',
            message: '可切换其它分组查看',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 20),
          itemCount: stars.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final star = stars[index];
            return GestureDetector(
              onTap: () => _openRead(star),
              child: _RssFavoriteItemCard(star: star),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<String>>(
      stream: _repo.watchGroups(),
      builder: (context, snapshot) {
        final groups = snapshot.data ?? const <String>[];
        final currentGroup = _resolveCurrentGroup(groups);
        return AppCupertinoPageScaffold(
          title: '收藏夹',
          trailing: _buildTrailingActions(
            groups: groups,
            currentGroup: currentGroup,
          ),
          child: Column(
            children: [
              _buildGroupSegmentedControl(groups, currentGroup),
              if (currentGroup.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '当前分组：$currentGroup',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: CupertinoColors.secondaryLabel
                                .resolveFrom(context),
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: currentGroup.isEmpty
                    ? const AppEmptyState(
                        illustration: AppEmptyPlanetIllustration(size: 82),
                        title: '暂无收藏',
                        message: '添加收藏后会显示在这里',
                      )
                    : _buildGroupList(currentGroup),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _RssFavoriteItemCard extends StatelessWidget {
  const _RssFavoriteItemCard({
    required this.star,
  });

  final RssStar star;

  @override
  Widget build(BuildContext context) {
    final imageUrl = (star.image ?? '').trim();
    final pubDate = (star.pubDate ?? '').trim();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: CupertinoColors.secondarySystemGroupedBackground.resolveFrom(
          context,
        ),
        borderRadius: BorderRadius.circular(AppDesignTokens.radiusCard),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (imageUrl.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                imageUrl,
                width: 52,
                height: 52,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _buildFallbackImage(context),
              ),
            )
          else
            _buildFallbackImage(context),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  star.title.trim().isEmpty ? '(无标题)' : star.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  pubDate.isEmpty ? '无发布时间' : pubDate,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: CupertinoColors.secondaryLabel.resolveFrom(context),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFallbackImage(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: CupertinoColors.systemGrey5.resolveFrom(context),
        borderRadius: BorderRadius.circular(8),
      ),
      alignment: Alignment.center,
      child: const Icon(CupertinoIcons.news, size: 18),
    );
  }
}

/// RSS 分类 Tab 栏
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
                    : CupertinoColors.tertiarySystemGroupedBackground
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

/// RSS 文章列表项（style 0/1，对应 legado item_rss_article_2.xml）
/// legado 布局：上方大图（全宽）+ 下方标题（2行）+ 日期 + 分割线
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

/// RSS 文章网格卡片（style 2，对应 legado item_rss_article_1.xml）
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
    final cardBg = CupertinoColors.secondarySystemGroupedBackground
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
                    child: const Icon(
                      CupertinoIcons.photo,
                      size: 32,
                      color: CupertinoColors.systemGrey,
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

class _PlaceholderCard extends StatelessWidget {
  const _PlaceholderCard({
    required this.title,
    required this.message,
  });

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: CupertinoColors.secondarySystemGroupedBackground.resolveFrom(
          context,
        ),
        borderRadius: BorderRadius.circular(AppDesignTokens.radiusCard),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: TextStyle(
              fontSize: 13,
              color: CupertinoColors.secondaryLabel.resolveFrom(context),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: CupertinoColors.systemGroupedBackground.resolveFrom(context),
        borderRadius: BorderRadius.circular(AppDesignTokens.radiusCard),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: CupertinoColors.secondaryLabel.resolveFrom(context),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _SortPreviewCard extends StatelessWidget {
  const _SortPreviewCard({
    required this.loading,
    required this.tabNames,
  });

  final bool loading;
  final List<String> tabNames;

  @override
  Widget build(BuildContext context) {
    final subtitle = loading
        ? '加载中...'
        : tabNames.isEmpty
            ? '暂无分类'
            : tabNames.join(' / ');
    final tabVisibility = tabNames.length <= 1 ? '隐藏（≤1）' : '显示（>1）';
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: CupertinoColors.systemGroupedBackground.resolveFrom(context),
        borderRadius: BorderRadius.circular(AppDesignTokens.radiusCard),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '分类预览',
            style: TextStyle(
              fontSize: 12,
              color: CupertinoColors.secondaryLabel.resolveFrom(context),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '分类数量：${tabNames.length}（Tab 栏$tabVisibility）',
            style: const TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 12,
              color: CupertinoColors.secondaryLabel.resolveFrom(context),
            ),
          ),
        ],
      ),
    );
  }
}
