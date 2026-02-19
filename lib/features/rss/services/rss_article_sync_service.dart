import '../../../core/database/database_service.dart';
import '../../../core/database/repositories/rss_article_repository.dart';
import '../../source/models/book_source.dart';
import '../../source/services/rule_parser_engine.dart';
import '../models/rss_article.dart';
import '../models/rss_source.dart';
import 'rss_default_xml_parser.dart';

class RssArticleFetchResult {
  final List<RssArticle> articles;
  final String? nextPageUrl;
  final bool hasMore;
  final String? error;

  const RssArticleFetchResult({
    required this.articles,
    required this.nextPageUrl,
    required this.hasMore,
    required this.error,
  });
}

class RssArticleSession {
  static const Object _unset = Object();

  final String sortName;
  final String sortUrl;
  final int page;
  final String? nextPageUrl;
  final int orderCursor;
  final bool hasMore;

  const RssArticleSession({
    required this.sortName,
    required this.sortUrl,
    required this.page,
    required this.nextPageUrl,
    required this.orderCursor,
    required this.hasMore,
  });

  RssArticleSession copyWith({
    String? sortName,
    String? sortUrl,
    int? page,
    Object? nextPageUrl = _unset,
    int? orderCursor,
    bool? hasMore,
  }) {
    return RssArticleSession(
      sortName: sortName ?? this.sortName,
      sortUrl: sortUrl ?? this.sortUrl,
      page: page ?? this.page,
      nextPageUrl: identical(nextPageUrl, _unset)
          ? this.nextPageUrl
          : nextPageUrl as String?,
      orderCursor: orderCursor ?? this.orderCursor,
      hasMore: hasMore ?? this.hasMore,
    );
  }
}

class RssArticleRefreshResult {
  final RssArticleSession session;
  final List<RssArticle> articles;
  final String? error;

  const RssArticleRefreshResult({
    required this.session,
    required this.articles,
    required this.error,
  });
}

class RssArticleLoadMoreResult {
  final RssArticleSession session;
  final List<RssArticle> appendedArticles;
  final String? error;

  const RssArticleLoadMoreResult({
    required this.session,
    required this.appendedArticles,
    required this.error,
  });
}

/// RSS 文章抓取+入库服务（对齐 legado `Rss/RssArticlesViewModel` 语义）
class RssArticleSyncService {
  final RssArticleRepository _articleRepo;
  final RssArticleFetchService _fetchService;

  RssArticleSyncService({
    required DatabaseService db,
    RssArticleRepository? articleRepository,
    RssArticleFetchService? fetchService,
  })  : _articleRepo = articleRepository ?? RssArticleRepository(db),
        _fetchService = fetchService ?? RssArticleFetchService();

  Future<RssArticleRefreshResult> refresh({
    required RssSource source,
    required String sortName,
    required String sortUrl,
  }) async {
    final fetch = await _fetchService.fetchPage(
      source: source,
      sortName: sortName,
      sortUrl: sortUrl,
      page: 1,
    );

    var orderCursor = DateTime.now().millisecondsSinceEpoch;
    final ordered = <RssArticle>[];
    for (final article in fetch.articles) {
      ordered.add(article.copyWith(order: orderCursor--));
    }

    if (ordered.isNotEmpty) {
      await _articleRepo.insert(ordered);
    }

    final hasRuleNextPage = _hasRuleNextPage(source.ruleNextPage);
    if (hasRuleNextPage) {
      await _articleRepo.clearOld(source.sourceUrl, sortName, orderCursor);
    }

    final session = RssArticleSession(
      sortName: sortName,
      sortUrl: sortUrl,
      page: 1,
      nextPageUrl: fetch.nextPageUrl,
      orderCursor: orderCursor,
      hasMore: ordered.isNotEmpty && hasRuleNextPage,
    );

    return RssArticleRefreshResult(
      session: session,
      articles: ordered,
      error: fetch.error,
    );
  }

  Future<RssArticleLoadMoreResult> loadMore({
    required RssSource source,
    required RssArticleSession session,
  }) async {
    if (!session.hasMore) {
      return RssArticleLoadMoreResult(
        session: session,
        appendedArticles: const <RssArticle>[],
        error: null,
      );
    }
    final pageUrl = (session.nextPageUrl ?? '').trim();
    if (pageUrl.isEmpty) {
      return RssArticleLoadMoreResult(
        session: session.copyWith(hasMore: false),
        appendedArticles: const <RssArticle>[],
        error: null,
      );
    }

    final nextPage = session.page + 1;
    final fetch = await _fetchService.fetchPage(
      source: source,
      sortName: session.sortName,
      sortUrl: pageUrl,
      page: nextPage,
    );

    if (fetch.error != null && fetch.articles.isEmpty) {
      return RssArticleLoadMoreResult(
        session: session.copyWith(
          page: nextPage,
          nextPageUrl: fetch.nextPageUrl,
          hasMore: false,
        ),
        appendedArticles: const <RssArticle>[],
        error: fetch.error,
      );
    }

    if (fetch.articles.isEmpty) {
      return RssArticleLoadMoreResult(
        session: session.copyWith(
          page: nextPage,
          nextPageUrl: fetch.nextPageUrl,
          hasMore: false,
        ),
        appendedArticles: const <RssArticle>[],
        error: fetch.error,
      );
    }

    final first = fetch.articles.first;
    final last = fetch.articles.last;
    final dbFirst = await _articleRepo.get(first.origin, first.link);
    final dbLast = await _articleRepo.get(last.origin, last.link);
    if (dbFirst != null && dbLast != null) {
      return RssArticleLoadMoreResult(
        session: session.copyWith(
          page: nextPage,
          nextPageUrl: fetch.nextPageUrl,
          hasMore: false,
        ),
        appendedArticles: const <RssArticle>[],
        error: fetch.error,
      );
    }

    var orderCursor = session.orderCursor;
    final appendList = <RssArticle>[];
    for (final article in fetch.articles) {
      appendList.add(article.copyWith(order: orderCursor--));
    }
    await _articleRepo.append(appendList);

    final nextSession = session.copyWith(
      page: nextPage,
      nextPageUrl: fetch.nextPageUrl,
      orderCursor: orderCursor,
      // 对齐 legado：loadMoreSuccess 仅在“空列表/重复首尾”时置 false。
      hasMore: true,
    );

    return RssArticleLoadMoreResult(
      session: nextSession,
      appendedArticles: appendList,
      error: fetch.error,
    );
  }

  static bool _hasRuleNextPage(String? ruleNextPage) {
    return (ruleNextPage ?? '').trim().isNotEmpty;
  }
}

class RssArticleFetchService {
  final RssArticleRuleGateway _gateway;

  RssArticleFetchService({
    RssArticleRuleGateway? gateway,
  }) : _gateway = gateway ?? RuleParserEngineRssArticleGateway();

  Future<RssArticleFetchResult> fetchPage({
    required RssSource source,
    required String sortName,
    required String sortUrl,
    required int page,
  }) async {
    final requestUrl = sortUrl.trim();
    if (requestUrl.isEmpty) {
      return const RssArticleFetchResult(
        articles: <RssArticle>[],
        nextPageUrl: null,
        hasMore: false,
        error: '分类 URL 为空',
      );
    }

    if ((source.ruleArticles ?? '').trim().isEmpty) {
      return _fetchWithDefaultParser(
        source: source,
        sortName: sortName,
        sortUrl: requestUrl,
      );
    }

    return _fetchWithRuleParser(
      source: source,
      sortName: sortName,
      sortUrl: requestUrl,
      page: page,
    );
  }

  Future<RssArticleFetchResult> _fetchWithDefaultParser({
    required RssSource source,
    required String sortName,
    required String sortUrl,
  }) async {
    final fetchSource = _buildBaseBookSource(source);
    final fetch = await _gateway.fetchForLoginScript(
      source: fetchSource,
      requestUrl: sortUrl,
    );
    final body = fetch.body.trim();
    if (body.isEmpty) {
      return const RssArticleFetchResult(
        articles: <RssArticle>[],
        nextPageUrl: null,
        hasMore: false,
        error: 'RSS 响应为空',
      );
    }

    final articles = RssDefaultXmlParser.parse(
      sortName: sortName,
      xml: body,
      sourceUrl: source.sourceUrl,
    );

    final nextPageUrl = await _resolveNextPageUrl(
      source: source,
      sortUrl: sortUrl,
    );
    final hasMore =
        articles.isNotEmpty && _hasRuleNextPage(source.ruleNextPage);
    return RssArticleFetchResult(
      articles: articles,
      nextPageUrl: nextPageUrl,
      hasMore: hasMore,
      error: null,
    );
  }

  Future<RssArticleFetchResult> _fetchWithRuleParser({
    required RssSource source,
    required String sortName,
    required String sortUrl,
    required int page,
  }) async {
    final parserSource = _buildRuleSearchBookSource(
      source: source,
      sortUrl: sortUrl,
      nextPageRule: source.ruleNextPage,
    );

    final debug = await _gateway.searchDebug(
      source: parserSource,
      keyword: '',
      page: page,
    );
    if (debug.fetch.body == null) {
      return RssArticleFetchResult(
        articles: const <RssArticle>[],
        nextPageUrl: null,
        hasMore: false,
        error: debug.error ?? 'RSS 列表请求失败',
      );
    }

    final articles = debug.results
        .map(
          (item) => _searchResultToArticle(
            source: source,
            sortName: sortName,
            item: item,
          ),
        )
        .whereType<RssArticle>()
        .toList(growable: false);

    final nextPageUrl = await _resolveNextPageUrl(
      source: source,
      sortUrl: sortUrl,
    );

    final hasMore =
        articles.isNotEmpty && _hasRuleNextPage(source.ruleNextPage);
    final error =
        (debug.error != null && articles.isEmpty) ? debug.error : null;
    return RssArticleFetchResult(
      articles: articles,
      nextPageUrl: nextPageUrl,
      hasMore: hasMore,
      error: error,
    );
  }

  Future<String?> _resolveNextPageUrl({
    required RssSource source,
    required String sortUrl,
  }) async {
    final rule = (source.ruleNextPage ?? '').trim();
    if (rule.isEmpty) return null;
    if (rule.toUpperCase() == 'PAGE') return sortUrl;

    final parserSource = _buildRuleSearchBookSource(
      source: source,
      sortUrl: sortUrl,
      nextPageRule: rule,
    );
    final info = await _gateway.getBookInfoDebug(
      source: parserSource,
      bookUrl: sortUrl,
    );
    final next = info.detail?.tocUrl?.trim() ?? '';
    if (next.isEmpty) return null;
    return _absoluteUrl(sortUrl, next);
  }

  static RssArticle? _searchResultToArticle({
    required RssSource source,
    required String sortName,
    required SearchResult item,
  }) {
    final title = item.name.trim();
    if (title.isEmpty) return null;
    final link = _absoluteUrl(source.sourceUrl, item.bookUrl.trim());
    if (link.isEmpty) return null;
    final pubDate = _emptyAsNull(item.updateTime);
    final description = _emptyAsNull(item.intro);
    final image = _emptyAsNull(item.coverUrl);
    return RssArticle(
      origin: source.sourceUrl,
      sort: sortName,
      title: title,
      link: link,
      pubDate: pubDate,
      description: description,
      image: image,
      variable: null,
    );
  }

  static bool _hasRuleNextPage(String? ruleNextPage) {
    return (ruleNextPage ?? '').trim().isNotEmpty;
  }

  static String? _emptyAsNull(String? raw) {
    final text = raw?.trim();
    if (text == null || text.isEmpty) return null;
    return text;
  }

  static String _absoluteUrl(String baseUrl, String target) {
    final raw = target.trim();
    if (raw.isEmpty) return '';
    final uri = Uri.tryParse(raw);
    if (uri != null && uri.hasScheme) return raw;
    final base = Uri.tryParse(baseUrl.trim());
    if (base == null) return raw;
    return base.resolve(raw).toString();
  }

  static BookSource _buildBaseBookSource(RssSource source) {
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

  static BookSource _buildRuleSearchBookSource({
    required RssSource source,
    required String sortUrl,
    required String? nextPageRule,
  }) {
    return _buildBaseBookSource(source).copyWith(
      // 禁止 SearchRule 空列表时走详情 fallback，避免 RSS 列表被错误降级。
      bookUrlPattern: '#rss#',
      searchUrl: sortUrl,
      ruleSearch: SearchRule(
        bookList: source.ruleArticles,
        name: source.ruleTitle,
        updateTime: source.rulePubDate,
        intro: source.ruleDescription,
        coverUrl: source.ruleImage,
        bookUrl: source.ruleLink,
      ),
      ruleBookInfo: BookInfoRule(
        tocUrl: nextPageRule,
      ),
    );
  }
}

abstract class RssArticleRuleGateway {
  const RssArticleRuleGateway();

  Future<SearchDebugResult> searchDebug({
    required BookSource source,
    required String keyword,
    required int page,
  });

  Future<BookInfoDebugResult> getBookInfoDebug({
    required BookSource source,
    required String bookUrl,
  });

  Future<ScriptHttpResponse> fetchForLoginScript({
    required BookSource source,
    required String requestUrl,
  });
}

class RuleParserEngineRssArticleGateway implements RssArticleRuleGateway {
  final RuleParserEngine _engine;

  RuleParserEngineRssArticleGateway({
    RuleParserEngine? engine,
  }) : _engine = engine ?? RuleParserEngine();

  @override
  Future<SearchDebugResult> searchDebug({
    required BookSource source,
    required String keyword,
    required int page,
  }) {
    return _engine.searchDebug(
      source,
      keyword,
      page: page,
    );
  }

  @override
  Future<BookInfoDebugResult> getBookInfoDebug({
    required BookSource source,
    required String bookUrl,
  }) {
    return _engine.getBookInfoDebug(source, bookUrl);
  }

  @override
  Future<ScriptHttpResponse> fetchForLoginScript({
    required BookSource source,
    required String requestUrl,
  }) {
    return _engine.fetchForLoginScript(
      source: source,
      requestUrl: requestUrl,
    );
  }
}
