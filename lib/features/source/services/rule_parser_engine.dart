import 'package:dio/dio.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart';
import 'dart:convert';
import '../models/book_source.dart';
import 'package:flutter/foundation.dart';
import '../../../core/utils/html_text_formatter.dart';

/// 书源规则解析引擎
/// 支持 CSS 选择器、XPath（简化版）和正则表达式
class RuleParserEngine {
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 15),
    headers: {
      'User-Agent': 'Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) '
          'AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.0 Mobile/15E148 Safari/604.1',
    },
  ));

  static final RegExp _httpHeaderTokenRegex =
      RegExp(r"^[!#$%&'*+\-.^_`|~0-9A-Za-z]+$");

  Map<String, String> _parseRequestHeaders(String? header) {
    if (header == null) return const {};
    final raw = header.trim();
    if (raw.isEmpty) return const {};

    // Legado 的 header 常见格式是 JSON 字符串：
    // {"User-Agent":"xxx","Referer":"xxx"}
    if (raw.startsWith('{') && raw.endsWith('}')) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          final m = <String, String>{};
          decoded.forEach((k, v) {
            final key = k.toString().trim();
            if (key.isEmpty) return;
            if (v == null) return;
            if (_httpHeaderTokenRegex.hasMatch(key)) {
              m[key] = v.toString();
            }
          });
          return m;
        }
      } catch (_) {
        // fallthrough: try other formats below
      }

      // 一些导入/编辑路径可能把 Map 变成 Dart 的 toString 形式：
      // {User-Agent: xxx, Referer: yyy}
      // 这种不是 JSON，但我们也尽量解析，避免直接崩溃。
      final inner = raw.substring(1, raw.length - 1).trim();
      if (inner.isNotEmpty && !inner.contains('"')) {
        final m = <String, String>{};
        for (final part in inner.split(',')) {
          final p = part.trim();
          if (p.isEmpty) continue;
          final idx = p.indexOf(':');
          if (idx <= 0) continue;
          final key = p.substring(0, idx).trim();
          final value = p.substring(idx + 1).trim();
          if (key.isEmpty) continue;
          if (!_httpHeaderTokenRegex.hasMatch(key)) continue;
          m[key] = value;
        }
        if (m.isNotEmpty) return m;
      }
    }

    // 兼容编辑器里的“每行 key:value”格式
    final headers = <String, String>{};
    for (final line in raw.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      final idx = trimmed.indexOf(':');
      if (idx <= 0) continue;
      final key = trimmed.substring(0, idx).trim();
      final value = trimmed.substring(idx + 1).trim();
      if (key.isEmpty) continue;
      if (!_httpHeaderTokenRegex.hasMatch(key)) continue;
      headers[key] = value;
    }
    return headers;
  }

  /// 搜索书籍
  Future<List<SearchResult>> search(BookSource source, String keyword) async {
    final searchRule = source.ruleSearch;
    final searchUrlRule = source.searchUrl;
    if (searchRule == null || searchUrlRule == null || searchUrlRule.isEmpty) {
      return [];
    }

    try {
      // 构建搜索URL
      final searchUrl = _buildUrl(
        source.bookSourceUrl,
        searchUrlRule,
        {'key': keyword, 'searchKey': keyword},
      );

      // 发送请求
      final response = await _fetch(
        searchUrl,
        header: source.header,
        timeoutMs: source.respondTime,
      );
      if (response == null) return [];

      // 解析结果
      final document = html_parser.parse(response);
      final results = <SearchResult>[];

      // 获取书籍列表
      final bookListRule = searchRule.bookList ?? '';
      final bookElements = _querySelectorAll(document, bookListRule);

      for (final element in bookElements) {
        final result = SearchResult(
          name: _parseRule(element, searchRule.name, source.bookSourceUrl),
          author: _parseRule(element, searchRule.author, source.bookSourceUrl),
          coverUrl:
              _parseRule(element, searchRule.coverUrl, source.bookSourceUrl),
          intro: _parseRule(element, searchRule.intro, source.bookSourceUrl),
          lastChapter:
              _parseRule(element, searchRule.lastChapter, source.bookSourceUrl),
          bookUrl:
              _parseRule(element, searchRule.bookUrl, source.bookSourceUrl),
          sourceUrl: source.bookSourceUrl,
          sourceName: source.bookSourceName,
        );

        if (result.name.isNotEmpty && result.bookUrl.isNotEmpty) {
          results.add(result);
        }
      }

      return results;
    } catch (e) {
      debugPrint('搜索失败: $e');
      return [];
    }
  }

  /// 对标 Legado 的「书源调试」：按 key 触发不同链路，并以“日志流”方式输出调试信息。
  ///
  /// key 规则（与 legado Debug.startDebug 一致）：
  /// - 绝对 URL（http/https）: 详情页调试（详情→目录→正文）
  /// - 包含 :: : 发现页调试（访问 :: 后面的 url，取第一本书继续）
  /// - ++ 开头: 目录页调试（目录→正文）
  /// - -- 开头: 正文页调试（仅正文）
  /// - 其它: 搜索关键字调试（搜索→详情→目录→正文）
  Future<void> debugRun(
    BookSource source,
    String key, {
    required void Function(SourceDebugEvent event) onEvent,
  }) async {
    final started = DateTime.now();

    String formatTimePrefix() {
      final ms = DateTime.now().difference(started).inMilliseconds;
      final minutes = (ms ~/ 60000) % 60;
      final seconds = (ms ~/ 1000) % 60;
      final millis = ms % 1000;
      final mm = minutes.toString().padLeft(2, '0');
      final ss = seconds.toString().padLeft(2, '0');
      final sss = millis.toString().padLeft(3, '0');
      return '[$mm:$ss.$sss]';
    }

    void log(
      String msg, {
      int state = 1,
      bool showTime = true,
    }) {
      final text = showTime ? '${formatTimePrefix()} $msg' : msg;
      onEvent(SourceDebugEvent(state: state, message: text));
    }

    void rawHtml(int state, String html) {
      onEvent(SourceDebugEvent(state: state, message: html, isRaw: true));
    }

    void rawText(int state, String text) {
      onEvent(SourceDebugEvent(state: state, message: text, isRaw: true));
    }

    bool isAbsUrl(String input) {
      final t = input.trim();
      return t.startsWith('http://') || t.startsWith('https://');
    }

    Future<FetchDebugResult> fetchStage(
      String url, {
      required int rawState,
    }) async {
      final res = await _fetchDebug(
        url,
        header: source.header,
        timeoutMs: source.respondTime,
      );
      final status = res.statusCode;
      final statusText = status != null ? ' ($status)' : '';
      final isBadStatus = status != null && status >= 400;
      if (res.body != null) {
        log(
          '≡获取${isBadStatus ? '完成' : '成功'}:${res.finalUrl ?? res.requestUrl}'
          '$statusText ${res.elapsedMs}ms',
          state: isBadStatus ? -1 : 1,
        );
        rawHtml(rawState, res.body!);
        if (isBadStatus) {
          log('└HTTP 状态码异常：$status', state: -1, showTime: false);
        }
      } else {
        log(
          '≡请求失败:${res.requestUrl}$statusText ${res.elapsedMs}ms',
          state: -1,
        );
        if (res.error != null && res.error!.trim().isNotEmpty) {
          log('└${res.error}', state: -1, showTime: false);
        }
      }
      return res;
    }

    try {
      log('︾开始解析');

      final trimmed = key.trim();
      if (trimmed.isEmpty) {
        log('key 不能为空', state: -1);
        return;
      }

      if (isAbsUrl(trimmed)) {
        log('⇒开始访问详情页:$trimmed');
        final ok = await _debugInfoTocContent(
          source: source,
          bookUrl: trimmed,
          fetchStage: fetchStage,
          emitRaw: rawText,
          log: log,
        );
        if (!ok) return;
        log('︽解析完成', state: 1000);
        return;
      }

      if (trimmed.contains('::')) {
        final url = trimmed.split('::').last.trim();
        log('⇒开始访问发现页:$url');
        final firstBookUrl = await _debugBookListThenPickFirst(
          source: source,
          keyOrUrl: url,
          mode: _DebugListMode.explore,
          fetchStage: fetchStage,
          log: log,
        );
        if (firstBookUrl == null) {
          log('︽未获取到书籍', state: -1);
          return;
        }
        final ok = await _debugInfoTocContent(
          source: source,
          bookUrl: firstBookUrl,
          fetchStage: fetchStage,
          emitRaw: rawText,
          log: log,
        );
        if (!ok) return;
        log('︽解析完成', state: 1000);
        return;
      }

      if (trimmed.startsWith('++')) {
        final url = trimmed.substring(2).trim();
        log('⇒开始访目录页:$url');
        final ok = await _debugTocThenContent(
          source: source,
          tocUrl: url,
          fetchStage: fetchStage,
          emitRaw: rawText,
          log: log,
        );
        if (!ok) return;
        log('︽解析完成', state: 1000);
        return;
      }

      if (trimmed.startsWith('--')) {
        final url = trimmed.substring(2).trim();
        log('⇒开始访正文页:$url');
        final ok = await _debugContentOnly(
          source: source,
          chapterUrl: url,
          fetchStage: fetchStage,
          emitRaw: rawText,
          log: log,
        );
        if (!ok) return;
        log('︽解析完成', state: 1000);
        return;
      }

      log('⇒开始搜索关键字:$trimmed');
      final firstBookUrl = await _debugBookListThenPickFirst(
        source: source,
        keyOrUrl: trimmed,
        mode: _DebugListMode.search,
        fetchStage: fetchStage,
        log: log,
      );
      if (firstBookUrl == null) {
        log('︽未获取到书籍', state: -1);
        return;
      }
      final ok = await _debugInfoTocContent(
        source: source,
        bookUrl: firstBookUrl,
        fetchStage: fetchStage,
        emitRaw: rawText,
        log: log,
      );
      if (!ok) return;
      log('︽解析完成', state: 1000);
    } catch (e, st) {
      log('调试异常: $e', state: -1);
      log(st.toString(), state: -1, showTime: false);
    }
  }

  Future<String?> _debugBookListThenPickFirst({
    required BookSource source,
    required String keyOrUrl,
    required _DebugListMode mode,
    required Future<FetchDebugResult> Function(String url, {required int rawState})
        fetchStage,
    required void Function(String msg, {int state, bool showTime}) log,
  }) async {
    final isSearch = mode == _DebugListMode.search;
    final bookListRule = isSearch ? source.ruleSearch : source.ruleExplore;
    final urlRule = isSearch ? source.searchUrl : source.exploreUrl;

    log(isSearch ? '︾开始解析搜索页' : '︾开始解析发现页');

    if (bookListRule == null || urlRule == null || urlRule.trim().isEmpty) {
      log(isSearch ? '⇒搜索规则为空' : '⇒发现规则为空', state: -1);
      return null;
    }

    final requestUrl = isSearch
        ? _buildUrl(
            source.bookSourceUrl,
            urlRule,
            {'key': keyOrUrl, 'searchKey': keyOrUrl},
          )
        : _buildUrl(
            source.bookSourceUrl,
            urlRule,
            const {},
          );

    final fetch = await fetchStage(requestUrl, rawState: 10);
    final body = fetch.body;
    if (body == null) {
      log('︽列表页解析失败', state: -1);
      return null;
    }

    final document = html_parser.parse(body);
    final listSelector = bookListRule.bookList ?? '';

    log('┌获取书籍列表');
    final elements = _querySelectorAll(document, listSelector);
    log('└列表大小:${elements.length}');

    if (elements.isEmpty) {
      // 对齐 legado：列表为空时可能是“详情页”，这里仅提示，不强行走详情解析（后续可按 bookUrlPattern 补齐）
      log('≡列表为空，可能是详情页或规则不匹配');
    }

    final results = <SearchResult>[];
    for (var i = 0; i < elements.length; i++) {
      final el = elements[i];
      final name = _parseRule(el, bookListRule.name, source.bookSourceUrl);
      final author = _parseRule(el, bookListRule.author, source.bookSourceUrl);
      final coverUrl =
          _parseRule(el, bookListRule.coverUrl, source.bookSourceUrl);
      final intro = _parseRule(el, bookListRule.intro, source.bookSourceUrl);
      final lastChapter =
          _parseRule(el, bookListRule.lastChapter, source.bookSourceUrl);
      var bookUrl = _parseRule(el, bookListRule.bookUrl, source.bookSourceUrl);
      if (bookUrl.isNotEmpty && !bookUrl.startsWith('http')) {
        bookUrl = _absoluteUrl(source.bookSourceUrl, bookUrl);
      }

      // 仅对第一条输出字段级日志，避免刷屏（对齐 legado 的 log 控制）
      if (i == 0) {
        log('┌获取书名');
        log('└$name');
        log('┌获取作者');
        log('└$author');
        log('┌获取封面');
        log('└$coverUrl');
        log('┌获取简介');
        log('└${intro.isEmpty ? '' : intro}');
        log('┌获取最新章节');
        log('└$lastChapter');
        log('┌获取详情链接');
        log('└$bookUrl');
      }

      if (name.isEmpty || bookUrl.isEmpty) continue;
      results.add(
        SearchResult(
          name: name,
          author: author,
          coverUrl: coverUrl,
          intro: intro,
          lastChapter: lastChapter,
          bookUrl: bookUrl,
          sourceUrl: source.bookSourceUrl,
          sourceName: source.bookSourceName,
        ),
      );
    }

    log('◇书籍总数:${results.length}');
    return results.isNotEmpty ? results.first.bookUrl : null;
  }

  Future<bool> _debugInfoTocContent({
    required BookSource source,
    required String bookUrl,
    required Future<FetchDebugResult> Function(String url, {required int rawState})
        fetchStage,
    required void Function(int state, String payload) emitRaw,
    required void Function(String msg, {int state, bool showTime}) log,
  }) async {
    final tocUrl = await _debugBookInfo(
      source: source,
      bookUrl: bookUrl,
      fetchStage: fetchStage,
      log: log,
    );
    if (tocUrl == null || tocUrl.trim().isEmpty) {
      log('≡未获取到目录链接', state: -1);
      return false;
    }
    return _debugTocThenContent(
      source: source,
      tocUrl: tocUrl,
      fetchStage: fetchStage,
      emitRaw: emitRaw,
      log: log,
    );
  }

  Future<String?> _debugBookInfo({
    required BookSource source,
    required String bookUrl,
    required Future<FetchDebugResult> Function(String url, {required int rawState})
        fetchStage,
    required void Function(String msg, {int state, bool showTime}) log,
  }) async {
    log('︾开始解析详情页');

    final rule = source.ruleBookInfo;
    if (rule == null) {
      log('⇒详情规则为空', state: -1);
      return null;
    }

    final fullUrl = _absoluteUrl(source.bookSourceUrl, bookUrl);
    final fetch = await fetchStage(fullUrl, rawState: 20);
    final body = fetch.body;
    if (body == null) {
      log('︽详情页解析失败', state: -1);
      return null;
    }

    final document = html_parser.parse(body);
    Element? root = document.documentElement;
    if (root == null) {
      log('⇒页面无 documentElement', state: -1);
      return null;
    }

    if (rule.init != null && rule.init!.trim().isNotEmpty) {
      log('≡执行详情页初始化规则');
      final initEl = _querySelector(document, rule.init!.trim());
      if (initEl != null) {
        root = initEl;
      } else {
        log('└init 匹配失败（将继续用 documentElement）');
      }
    }

    String getField(String label, String? ruleStr) {
      log('┌$label');
      final value = _parseRule(root!, ruleStr, source.bookSourceUrl);
      log('└$value');
      return value;
    }

    final name = getField('获取书名', rule.name);
    final author = getField('获取作者', rule.author);
    getField('获取分类', rule.kind);
    getField('获取字数', rule.wordCount);
    final lastChapter = getField('获取最新章节', rule.lastChapter);
    getField('获取简介', rule.intro);
    getField('获取封面', rule.coverUrl);
    final tocUrl = getField('获取目录链接', rule.tocUrl);

    if (name.isEmpty && author.isEmpty && lastChapter.isEmpty && tocUrl.isEmpty) {
      log('≡字段全为空，可能 ruleBookInfo 不匹配', state: -1);
    }

    log('︽详情页解析完成', showTime: false);
    log('', showTime: false);

    return tocUrl;
  }

  Future<bool> _debugTocThenContent({
    required BookSource source,
    required String tocUrl,
    required Future<FetchDebugResult> Function(String url, {required int rawState})
        fetchStage,
    required void Function(int state, String payload) emitRaw,
    required void Function(String msg, {int state, bool showTime}) log,
  }) async {
    log('︾开始解析目录页');

    final rule = source.ruleToc;
    if (rule == null) {
      log('⇒目录规则为空', state: -1);
      return false;
    }

    final fullUrl = _absoluteUrl(source.bookSourceUrl, tocUrl);
    final fetch = await fetchStage(fullUrl, rawState: 30);
    final body = fetch.body;
    if (body == null) {
      log('︽目录页解析失败', state: -1);
      return false;
    }

    final document = html_parser.parse(body);

    var listRule = rule.chapterList ?? '';
    var reverse = false;
    if (listRule.startsWith('-')) {
      reverse = true;
      listRule = listRule.substring(1);
    }
    if (listRule.startsWith('+')) {
      listRule = listRule.substring(1);
    }

    log('┌获取章节列表');
    final elements = _querySelectorAll(document, listRule);
    log('└列表大小:${elements.length}');

    var toc = <TocItem>[];
    for (var i = 0; i < elements.length; i++) {
      final el = elements[i];
      final name = _parseRule(el, rule.chapterName, source.bookSourceUrl);
      var url = _parseRule(el, rule.chapterUrl, source.bookSourceUrl);
      if (url.isNotEmpty && !url.startsWith('http')) {
        url = _absoluteUrl(source.bookSourceUrl, url);
      }
      if (i == 0) {
        log('┌获取章节名');
        log('└$name');
        log('┌获取章节链接');
        log('└$url');
      }
      if (name.isEmpty || url.isEmpty) continue;
      toc.add(TocItem(index: i, name: name, url: url));
    }

    if (reverse) toc = toc.reversed.toList(growable: true);
    log('◇章节总数:${toc.length}');

    if (toc.isEmpty) {
      log('≡没有正文章节', state: -1);
      return false;
    }

    log('︽目录页解析完成', showTime: false);
    log('', showTime: false);

    return _debugContentOnly(
      source: source,
      chapterUrl: toc.first.url,
      fetchStage: fetchStage,
      emitRaw: emitRaw,
      log: log,
    );
  }

  Future<bool> _debugContentOnly({
    required BookSource source,
    required String chapterUrl,
    required Future<FetchDebugResult> Function(String url, {required int rawState})
        fetchStage,
    required void Function(int state, String payload) emitRaw,
    required void Function(String msg, {int state, bool showTime}) log,
  }) async {
    log('︾开始解析正文页');

    final rule = source.ruleContent;
    if (rule == null) {
      log('⇒正文规则为空', state: -1);
      return false;
    }

    final fullUrl = _absoluteUrl(source.bookSourceUrl, chapterUrl);
    final fetch = await fetchStage(fullUrl, rawState: 40);
    final body = fetch.body;
    if (body == null) {
      log('︽正文页解析失败', state: -1);
      return false;
    }

    final document = html_parser.parse(body);
    final root = document.documentElement;
    if (root == null) {
      log('⇒页面无 documentElement', state: -1);
      return false;
    }

    String extracted;
    if (rule.content == null || rule.content!.trim().isEmpty) {
      log('⇒内容规则为空，默认获取整个网页');
      extracted = root.text;
    } else {
      extracted = _parseRule(root, rule.content, source.bookSourceUrl);
    }

    var processed = extracted;
    if (rule.replaceRegex != null && rule.replaceRegex!.trim().isNotEmpty) {
      processed = _applyReplaceRegex(processed, rule.replaceRegex!);
    }
    final cleaned = _cleanContent(processed);
    // 额外缓存清理后的正文，便于 UI 查看全文（不依赖控制台截断）。
    // state=41：正文结果（清理后）
    emitRaw(41, cleaned);

    log('◇提取长度:${extracted.length} 清理后长度:${cleaned.length}');
    log('┌获取正文内容');
    final maxLog = 2000;
    final preview = cleaned.length <= maxLog
        ? cleaned
        : '${cleaned.substring(0, maxLog)}\n…（已截断，查看“正文结果”可看全文）';
    log('└\n$preview');

    if (cleaned.trim().isEmpty) {
      log('≡内容为空', state: -1);
      return false;
    }

    log('︽正文页解析完成');
    return true;
  }

  /// 搜索调试：返回「请求/解析」过程的关键诊断信息
  Future<SearchDebugResult> searchDebug(BookSource source, String keyword) async {
    final searchRule = source.ruleSearch;
    final searchUrlRule = source.searchUrl;
    if (searchRule == null || searchUrlRule == null || searchUrlRule.isEmpty) {
      return SearchDebugResult(
        fetch: FetchDebugResult.empty(),
        requestType: DebugRequestType.search,
        requestUrlRule: searchUrlRule,
        listRule: searchRule?.bookList,
        listCount: 0,
        results: const [],
        fieldSample: const {},
        error: 'searchUrl / ruleSearch 为空',
      );
    }

    final requestUrl = _buildUrl(
      source.bookSourceUrl,
      searchUrlRule,
      {'key': keyword, 'searchKey': keyword},
    );

    final fetch = await _fetchDebug(
      requestUrl,
      header: source.header,
      timeoutMs: source.respondTime,
    );
    if (fetch.body == null) {
      return SearchDebugResult(
        fetch: fetch,
        requestType: DebugRequestType.search,
        requestUrlRule: searchUrlRule,
        listRule: searchRule.bookList,
        listCount: 0,
        results: const [],
        fieldSample: const {},
        error: fetch.error ?? '请求失败',
      );
    }

    try {
      final document = html_parser.parse(fetch.body);
      final bookListRule = searchRule.bookList ?? '';
      final bookElements = _querySelectorAll(document, bookListRule);

      final results = <SearchResult>[];
      Map<String, String> fieldSample = const {};

      for (final element in bookElements) {
        final name = _parseRule(element, searchRule.name, source.bookSourceUrl);
        final author =
            _parseRule(element, searchRule.author, source.bookSourceUrl);
        final coverUrl =
            _parseRule(element, searchRule.coverUrl, source.bookSourceUrl);
        final intro =
            _parseRule(element, searchRule.intro, source.bookSourceUrl);
        final lastChapter =
            _parseRule(element, searchRule.lastChapter, source.bookSourceUrl);
        final bookUrl =
            _parseRule(element, searchRule.bookUrl, source.bookSourceUrl);

        final result = SearchResult(
          name: name,
          author: author,
          coverUrl: coverUrl,
          intro: intro,
          lastChapter: lastChapter,
          bookUrl: bookUrl,
          sourceUrl: source.bookSourceUrl,
          sourceName: source.bookSourceName,
        );

        if (results.isEmpty) {
          fieldSample = <String, String>{
            'name': name,
            'author': author,
            'coverUrl': coverUrl,
            'intro': intro,
            'lastChapter': lastChapter,
            'bookUrl': bookUrl,
          };
        }

        if (result.name.isNotEmpty && result.bookUrl.isNotEmpty) {
          results.add(result);
        }
      }

      return SearchDebugResult(
        fetch: fetch,
        requestType: DebugRequestType.search,
        requestUrlRule: searchUrlRule,
        listRule: bookListRule,
        listCount: bookElements.length,
        results: results,
        fieldSample: fieldSample,
        error: null,
      );
    } catch (e) {
      return SearchDebugResult(
        fetch: fetch,
        requestType: DebugRequestType.search,
        requestUrlRule: searchUrlRule,
        listRule: searchRule.bookList,
        listCount: 0,
        results: const [],
        fieldSample: const {},
        error: '解析失败: $e',
      );
    }
  }

  /// 发现书籍
  ///
  /// 对标 Legado：`exploreUrl` + `ruleExplore`
  Future<List<SearchResult>> explore(
    BookSource source, {
    String? exploreUrlOverride,
  }) async {
    final exploreRule = source.ruleExplore;
    final exploreUrlRule = exploreUrlOverride ?? source.exploreUrl;
    if (exploreRule == null ||
        exploreUrlRule == null ||
        exploreUrlRule.trim().isEmpty) {
      return [];
    }

    try {
      final exploreUrl = _buildUrl(
        source.bookSourceUrl,
        exploreUrlRule,
        const {},
      );

      final response = await _fetch(
        exploreUrl,
        header: source.header,
        timeoutMs: source.respondTime,
      );
      if (response == null) return [];

      final document = html_parser.parse(response);
      final results = <SearchResult>[];

      final bookListRule = exploreRule.bookList ?? '';
      final bookElements = _querySelectorAll(document, bookListRule);

      for (final element in bookElements) {
        final result = SearchResult(
          name: _parseRule(element, exploreRule.name, source.bookSourceUrl),
          author: _parseRule(element, exploreRule.author, source.bookSourceUrl),
          coverUrl:
              _parseRule(element, exploreRule.coverUrl, source.bookSourceUrl),
          intro: _parseRule(element, exploreRule.intro, source.bookSourceUrl),
          lastChapter:
              _parseRule(element, exploreRule.lastChapter, source.bookSourceUrl),
          bookUrl:
              _parseRule(element, exploreRule.bookUrl, source.bookSourceUrl),
          sourceUrl: source.bookSourceUrl,
          sourceName: source.bookSourceName,
        );

        if (result.name.isNotEmpty && result.bookUrl.isNotEmpty) {
          results.add(result);
        }
      }

      return results;
    } catch (e) {
      debugPrint('发现失败: $e');
      return [];
    }
  }

  Future<ExploreDebugResult> exploreDebug(
    BookSource source, {
    String? exploreUrlOverride,
  }) async {
    final exploreRule = source.ruleExplore;
    final exploreUrlRule = exploreUrlOverride ?? source.exploreUrl;
    if (exploreRule == null ||
        exploreUrlRule == null ||
        exploreUrlRule.trim().isEmpty) {
      return ExploreDebugResult(
        fetch: FetchDebugResult.empty(),
        requestType: DebugRequestType.explore,
        requestUrlRule: exploreUrlRule,
        listRule: exploreRule?.bookList,
        listCount: 0,
        results: const [],
        fieldSample: const {},
        error: 'exploreUrl / ruleExplore 为空',
      );
    }

    final requestUrl = _buildUrl(
      source.bookSourceUrl,
      exploreUrlRule,
      const {},
    );
    final fetch = await _fetchDebug(
      requestUrl,
      header: source.header,
      timeoutMs: source.respondTime,
    );
    if (fetch.body == null) {
      return ExploreDebugResult(
        fetch: fetch,
        requestType: DebugRequestType.explore,
        requestUrlRule: exploreUrlRule,
        listRule: exploreRule.bookList,
        listCount: 0,
        results: const [],
        fieldSample: const {},
        error: fetch.error ?? '请求失败',
      );
    }

    try {
      final document = html_parser.parse(fetch.body);
      final bookListRule = exploreRule.bookList ?? '';
      final bookElements = _querySelectorAll(document, bookListRule);

      final results = <SearchResult>[];
      Map<String, String> fieldSample = const {};

      for (final element in bookElements) {
        final name = _parseRule(element, exploreRule.name, source.bookSourceUrl);
        final author =
            _parseRule(element, exploreRule.author, source.bookSourceUrl);
        final coverUrl =
            _parseRule(element, exploreRule.coverUrl, source.bookSourceUrl);
        final intro =
            _parseRule(element, exploreRule.intro, source.bookSourceUrl);
        final lastChapter = _parseRule(
          element,
          exploreRule.lastChapter,
          source.bookSourceUrl,
        );
        final bookUrl =
            _parseRule(element, exploreRule.bookUrl, source.bookSourceUrl);

        final result = SearchResult(
          name: name,
          author: author,
          coverUrl: coverUrl,
          intro: intro,
          lastChapter: lastChapter,
          bookUrl: bookUrl,
          sourceUrl: source.bookSourceUrl,
          sourceName: source.bookSourceName,
        );

        if (results.isEmpty) {
          fieldSample = <String, String>{
            'name': name,
            'author': author,
            'coverUrl': coverUrl,
            'intro': intro,
            'lastChapter': lastChapter,
            'bookUrl': bookUrl,
          };
        }

        if (result.name.isNotEmpty && result.bookUrl.isNotEmpty) {
          results.add(result);
        }
      }

      return ExploreDebugResult(
        fetch: fetch,
        requestType: DebugRequestType.explore,
        requestUrlRule: exploreUrlRule,
        listRule: bookListRule,
        listCount: bookElements.length,
        results: results,
        fieldSample: fieldSample,
        error: null,
      );
    } catch (e) {
      return ExploreDebugResult(
        fetch: fetch,
        requestType: DebugRequestType.explore,
        requestUrlRule: exploreUrlRule,
        listRule: exploreRule.bookList,
        listCount: 0,
        results: const [],
        fieldSample: const {},
        error: '解析失败: $e',
      );
    }
  }

  /// 获取书籍详情
  Future<BookDetail?> getBookInfo(BookSource source, String bookUrl) async {
    final bookInfoRule = source.ruleBookInfo;
    if (bookInfoRule == null) return null;

    try {
      final fullUrl = _absoluteUrl(source.bookSourceUrl, bookUrl);
      final response = await _fetch(
        fullUrl,
        header: source.header,
        timeoutMs: source.respondTime,
      );
      if (response == null) return null;

      final document = html_parser.parse(response);
      Element? root = document.documentElement;

      // 如果有 init 规则，先定位根元素
      if (bookInfoRule.init != null && bookInfoRule.init!.isNotEmpty) {
        root = _querySelector(document, bookInfoRule.init!);
      }

      if (root == null) return null;

      return BookDetail(
        name: _parseRule(root, bookInfoRule.name, source.bookSourceUrl),
        author: _parseRule(root, bookInfoRule.author, source.bookSourceUrl),
        coverUrl: _parseRule(root, bookInfoRule.coverUrl, source.bookSourceUrl),
        intro: _parseRule(root, bookInfoRule.intro, source.bookSourceUrl),
        kind: _parseRule(root, bookInfoRule.kind, source.bookSourceUrl),
        lastChapter:
            _parseRule(root, bookInfoRule.lastChapter, source.bookSourceUrl),
        tocUrl: _parseRule(root, bookInfoRule.tocUrl, source.bookSourceUrl),
        bookUrl: fullUrl,
      );
    } catch (e) {
      debugPrint('获取书籍详情失败: $e');
      return null;
    }
  }

  Future<BookInfoDebugResult> getBookInfoDebug(
    BookSource source,
    String bookUrl,
  ) async {
    final bookInfoRule = source.ruleBookInfo;
    if (bookInfoRule == null) {
      return BookInfoDebugResult(
        fetch: FetchDebugResult.empty(),
        requestType: DebugRequestType.bookInfo,
        requestUrlRule: bookUrl,
        initRule: null,
        initMatched: false,
        detail: null,
        fieldSample: const {},
        error: 'ruleBookInfo 为空',
      );
    }

    final fullUrl = _absoluteUrl(source.bookSourceUrl, bookUrl);
    final fetch = await _fetchDebug(
      fullUrl,
      header: source.header,
      timeoutMs: source.respondTime,
    );
    if (fetch.body == null) {
      return BookInfoDebugResult(
        fetch: fetch,
        requestType: DebugRequestType.bookInfo,
        requestUrlRule: bookUrl,
        initRule: bookInfoRule.init,
        initMatched: false,
        detail: null,
        fieldSample: const {},
        error: fetch.error ?? '请求失败',
      );
    }

    try {
      final document = html_parser.parse(fetch.body);
      Element? root = document.documentElement;
      var initMatched = true;

      if (bookInfoRule.init != null && bookInfoRule.init!.isNotEmpty) {
        root = _querySelector(document, bookInfoRule.init!);
        initMatched = root != null;
      }
      if (root == null) {
        return BookInfoDebugResult(
          fetch: fetch,
          requestType: DebugRequestType.bookInfo,
          requestUrlRule: bookUrl,
          initRule: bookInfoRule.init,
          initMatched: initMatched,
          detail: null,
          fieldSample: const {},
          error: 'init 定位失败或页面无 documentElement',
        );
      }

      final name = _parseRule(root, bookInfoRule.name, source.bookSourceUrl);
      final author =
          _parseRule(root, bookInfoRule.author, source.bookSourceUrl);
      final coverUrl =
          _parseRule(root, bookInfoRule.coverUrl, source.bookSourceUrl);
      final intro = _parseRule(root, bookInfoRule.intro, source.bookSourceUrl);
      final kind = _parseRule(root, bookInfoRule.kind, source.bookSourceUrl);
      final lastChapter =
          _parseRule(root, bookInfoRule.lastChapter, source.bookSourceUrl);
      final tocUrl =
          _parseRule(root, bookInfoRule.tocUrl, source.bookSourceUrl);

      final detail = BookDetail(
        name: name,
        author: author,
        coverUrl: coverUrl,
        intro: intro,
        kind: kind,
        lastChapter: lastChapter,
        tocUrl: tocUrl,
        bookUrl: fullUrl,
      );

      return BookInfoDebugResult(
        fetch: fetch,
        requestType: DebugRequestType.bookInfo,
        requestUrlRule: bookUrl,
        initRule: bookInfoRule.init,
        initMatched: initMatched,
        detail: detail,
        fieldSample: <String, String>{
          'name': name,
          'author': author,
          'coverUrl': coverUrl,
          'intro': intro,
          'kind': kind,
          'lastChapter': lastChapter,
          'tocUrl': tocUrl,
        },
        error: null,
      );
    } catch (e) {
      return BookInfoDebugResult(
        fetch: fetch,
        requestType: DebugRequestType.bookInfo,
        requestUrlRule: bookUrl,
        initRule: bookInfoRule.init,
        initMatched: false,
        detail: null,
        fieldSample: const {},
        error: '解析失败: $e',
      );
    }
  }

  /// 获取目录
  Future<List<TocItem>> getToc(BookSource source, String tocUrl) async {
    final tocRule = source.ruleToc;
    if (tocRule == null) return [];

    try {
      final fullUrl = _absoluteUrl(source.bookSourceUrl, tocUrl);
      final response = await _fetch(
        fullUrl,
        header: source.header,
        timeoutMs: source.respondTime,
      );
      if (response == null) return [];

      final document = html_parser.parse(response);
      final chapters = <TocItem>[];

      // 获取章节列表
      final chapterListRule = tocRule.chapterList ?? '';
      final chapterElements = _querySelectorAll(document, chapterListRule);

      for (int i = 0; i < chapterElements.length; i++) {
        final element = chapterElements[i];
        final item = TocItem(
          index: i,
          name: _parseRule(element, tocRule.chapterName, source.bookSourceUrl),
          url: _parseRule(element, tocRule.chapterUrl, source.bookSourceUrl),
        );

        if (item.name.isNotEmpty && item.url.isNotEmpty) {
          chapters.add(item);
        }
      }

      return chapters;
    } catch (e) {
      debugPrint('获取目录失败: $e');
      return [];
    }
  }

  Future<TocDebugResult> getTocDebug(BookSource source, String tocUrl) async {
    final tocRule = source.ruleToc;
    if (tocRule == null) {
      return TocDebugResult(
        fetch: FetchDebugResult.empty(),
        requestType: DebugRequestType.toc,
        requestUrlRule: tocUrl,
        listRule: null,
        listCount: 0,
        toc: const [],
        fieldSample: const {},
        error: 'ruleToc 为空',
      );
    }

    final fullUrl = _absoluteUrl(source.bookSourceUrl, tocUrl);
    final fetch = await _fetchDebug(
      fullUrl,
      header: source.header,
      timeoutMs: source.respondTime,
    );
    if (fetch.body == null) {
      return TocDebugResult(
        fetch: fetch,
        requestType: DebugRequestType.toc,
        requestUrlRule: tocUrl,
        listRule: tocRule.chapterList,
        listCount: 0,
        toc: const [],
        fieldSample: const {},
        error: fetch.error ?? '请求失败',
      );
    }

    try {
      final document = html_parser.parse(fetch.body);
      final chapterListRule = tocRule.chapterList ?? '';
      final chapterElements = _querySelectorAll(document, chapterListRule);

      final chapters = <TocItem>[];
      Map<String, String> sample = const {};
      for (var i = 0; i < chapterElements.length; i++) {
        final element = chapterElements[i];
        final name =
            _parseRule(element, tocRule.chapterName, source.bookSourceUrl);
        final url =
            _parseRule(element, tocRule.chapterUrl, source.bookSourceUrl);
        if (chapters.isEmpty) {
          sample = <String, String>{'name': name, 'url': url};
        }
        if (name.isNotEmpty && url.isNotEmpty) {
          chapters.add(TocItem(index: i, name: name, url: url));
        }
      }

      return TocDebugResult(
        fetch: fetch,
        requestType: DebugRequestType.toc,
        requestUrlRule: tocUrl,
        listRule: chapterListRule,
        listCount: chapterElements.length,
        toc: chapters,
        fieldSample: sample,
        error: null,
      );
    } catch (e) {
      return TocDebugResult(
        fetch: fetch,
        requestType: DebugRequestType.toc,
        requestUrlRule: tocUrl,
        listRule: tocRule.chapterList,
        listCount: 0,
        toc: const [],
        fieldSample: const {},
        error: '解析失败: $e',
      );
    }
  }

  /// 获取正文
  Future<String> getContent(BookSource source, String chapterUrl) async {
    final contentRule = source.ruleContent;
    if (contentRule == null) return '';

    try {
      final fullUrl = _absoluteUrl(source.bookSourceUrl, chapterUrl);
      final response = await _fetch(
        fullUrl,
        header: source.header,
        timeoutMs: source.respondTime,
      );
      if (response == null) return '';

      final document = html_parser.parse(response);
      String content = _parseRule(
        document.documentElement!,
        contentRule.content,
        source.bookSourceUrl,
      );

      // 应用替换规则
      if (contentRule.replaceRegex != null &&
          contentRule.replaceRegex!.isNotEmpty) {
        content = _applyReplaceRegex(content, contentRule.replaceRegex!);
      }

      // 清理内容
      content = _cleanContent(content);

      return content;
    } catch (e) {
      debugPrint('获取正文失败: $e');
      return '';
    }
  }

  Future<ContentDebugResult> getContentDebug(
    BookSource source,
    String chapterUrl,
  ) async {
    final contentRule = source.ruleContent;
    if (contentRule == null) {
      return ContentDebugResult(
        fetch: FetchDebugResult.empty(),
        requestType: DebugRequestType.content,
        requestUrlRule: chapterUrl,
        extractedLength: 0,
        cleanedLength: 0,
        content: '',
        error: 'ruleContent 为空',
      );
    }

    final fullUrl = _absoluteUrl(source.bookSourceUrl, chapterUrl);
    final fetch = await _fetchDebug(
      fullUrl,
      header: source.header,
      timeoutMs: source.respondTime,
    );
    if (fetch.body == null) {
      return ContentDebugResult(
        fetch: fetch,
        requestType: DebugRequestType.content,
        requestUrlRule: chapterUrl,
        extractedLength: 0,
        cleanedLength: 0,
        content: '',
        error: fetch.error ?? '请求失败',
      );
    }

    try {
      final document = html_parser.parse(fetch.body);
      final extracted = _parseRule(
        document.documentElement!,
        contentRule.content,
        source.bookSourceUrl,
      );
      var text = extracted;
      if (contentRule.replaceRegex != null &&
          contentRule.replaceRegex!.isNotEmpty) {
        text = _applyReplaceRegex(text, contentRule.replaceRegex!);
      }
      final cleaned = _cleanContent(text);

      return ContentDebugResult(
        fetch: fetch,
        requestType: DebugRequestType.content,
        requestUrlRule: chapterUrl,
        extractedLength: extracted.length,
        cleanedLength: cleaned.length,
        content: cleaned,
        error: null,
      );
    } catch (e) {
      return ContentDebugResult(
        fetch: fetch,
        requestType: DebugRequestType.content,
        requestUrlRule: chapterUrl,
        extractedLength: 0,
        cleanedLength: 0,
        content: '',
        error: '解析失败: $e',
      );
    }
  }

  /// 发送HTTP请求
  Future<String?> _fetch(
    String url, {
    String? header,
    int? timeoutMs,
  }) async {
    try {
      final timeout =
          (timeoutMs != null && timeoutMs > 0) ? Duration(milliseconds: timeoutMs) : null;
      final options = Options(
        connectTimeout: timeout,
        sendTimeout: timeout,
        receiveTimeout: timeout,
      );
      final requestHeaders = _parseRequestHeaders(header);
      if (requestHeaders.isNotEmpty) options.headers = requestHeaders;

      final response = await _dio.get(url, options: options);
      return response.data?.toString();
    } catch (e) {
      debugPrint('请求失败: $url - $e');
      return null;
    }
  }

  Future<FetchDebugResult> _fetchDebug(
    String url, {
    String? header,
    int? timeoutMs,
  }) async {
    final sw = Stopwatch()..start();
    final requestHeaders = _parseRequestHeaders(header);
    try {
      final timeout =
          (timeoutMs != null && timeoutMs > 0) ? Duration(milliseconds: timeoutMs) : null;
      final options = Options(
        connectTimeout: timeout,
        sendTimeout: timeout,
        receiveTimeout: timeout,
        validateStatus: (_) => true,
      );
      if (requestHeaders.isNotEmpty) {
        options.headers = requestHeaders;
      }

      final response = await _dio.get(url, options: options);
      final body = response.data?.toString();
      sw.stop();
      return FetchDebugResult(
        requestUrl: url,
        finalUrl: response.realUri.toString(),
        statusCode: response.statusCode,
        elapsedMs: sw.elapsedMilliseconds,
        responseLength: body?.length ?? 0,
        responseSnippet: _snippet(body),
        requestHeaders: requestHeaders,
        error: null,
        body: body,
      );
    } catch (e) {
      sw.stop();
      if (e is DioException) {
        final response = e.response;
        final body = response?.data?.toString();
        final statusCode = response?.statusCode;
        final finalUrl = response?.realUri.toString();
        final parts = <String>[
          'DioException(${e.type})',
          if (e.message != null && e.message!.trim().isNotEmpty) e.message!.trim(),
          if (e.error != null) 'error=${e.error}',
        ];
        return FetchDebugResult(
          requestUrl: url,
          finalUrl: finalUrl,
          statusCode: statusCode,
          elapsedMs: sw.elapsedMilliseconds,
          responseLength: body?.length ?? 0,
          responseSnippet: _snippet(body),
          requestHeaders: requestHeaders,
          error: parts.join('：'),
          body: body,
        );
      }
      return FetchDebugResult(
        requestUrl: url,
        finalUrl: null,
        statusCode: null,
        elapsedMs: sw.elapsedMilliseconds,
        responseLength: 0,
        responseSnippet: null,
        requestHeaders: requestHeaders,
        error: e.toString(),
        body: null,
      );
    }
  }

  String? _snippet(String? text) {
    if (text == null) return null;
    final t = text.replaceAll('\r\n', '\n');
    final max = 1200;
    if (t.length <= max) return t;
    return t.substring(0, max);
  }

  /// 构建URL
  String _buildUrl(String baseUrl, String rule, Map<String, String> params) {
    String url = rule;

    // 替换参数
    params.forEach((key, value) {
      url = url.replaceAll('{{$key}}', Uri.encodeComponent(value));
      url = url.replaceAll('{$key}', Uri.encodeComponent(value));
    });

    return _absoluteUrl(baseUrl, url);
  }

  /// 转换为绝对URL
  String _absoluteUrl(String baseUrl, String url) {
    if (url.isEmpty) return '';
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return url;
    }
    if (url.startsWith('//')) {
      return 'https:$url';
    }
    if (url.startsWith('/')) {
      final uri = Uri.parse(baseUrl);
      return '${uri.scheme}://${uri.host}$url';
    }
    return '$baseUrl/$url';
  }

  /// 解析规则
  String _parseRule(Element element, String? rule, String baseUrl) {
    if (rule == null || rule.isEmpty) return '';

    String result = '';

    // 处理多个规则（用 || 分隔，表示备选）
    final rules = rule.split('||');
    for (final r in rules) {
      result = _parseSingleRule(element, r.trim(), baseUrl);
      if (result.isNotEmpty) break;
    }

    return result.trim();
  }

  /// 解析单个规则
  String _parseSingleRule(Element element, String rule, String baseUrl) {
    if (rule.isEmpty) return '';

    // 提取属性规则 @attr 或 @text
    String? attrRule;
    String selectorRule = rule;

    if (rule.contains('@')) {
      final atIndex = rule.lastIndexOf('@');
      selectorRule = rule.substring(0, atIndex).trim();
      attrRule = rule.substring(atIndex + 1).trim();
    }

    // 如果选择器为空，使用当前元素
    Element? target = element;
    if (selectorRule.isNotEmpty) {
      target = _querySelector(element, selectorRule);
    }

    if (target == null) return '';

    // 获取内容
    String result;
    if (attrRule == null || attrRule == 'text') {
      result = target.text;
    } else if (attrRule == 'textNodes') {
      result = target.nodes.whereType<Text>().map((t) => t.text).join('');
    } else if (attrRule == 'ownText') {
      result = target.nodes.whereType<Text>().map((t) => t.text).join('');
    } else if (attrRule == 'html' || attrRule == 'innerHTML') {
      result = target.innerHtml;
    } else if (attrRule == 'outerHtml') {
      result = target.outerHtml;
    } else {
      result = target.attributes[attrRule] ?? '';
    }

    // 如果是URL属性，转换为绝对路径
    if (attrRule == 'href' || attrRule == 'src') {
      result = _absoluteUrl(baseUrl, result);
    }

    return result.trim();
  }

  /// CSS选择器查询单个元素
  Element? _querySelector(dynamic parent, String selector) {
    if (selector.isEmpty) return null;

    try {
      if (parent is Document) {
        return parent.querySelector(selector);
      } else if (parent is Element) {
        return parent.querySelector(selector);
      }
    } catch (e) {
      debugPrint('选择器解析失败: $selector - $e');
    }

    return null;
  }

  /// CSS选择器查询多个元素
  List<Element> _querySelectorAll(dynamic parent, String selector) {
    if (selector.isEmpty) return [];

    try {
      if (parent is Document) {
        return parent.querySelectorAll(selector);
      } else if (parent is Element) {
        return parent.querySelectorAll(selector);
      }
    } catch (e) {
      debugPrint('选择器解析失败: $selector - $e');
    }

    return [];
  }

  /// 应用替换正则
  String _applyReplaceRegex(String content, String replaceRegex) {
    try {
      // 源阅格式: regex##replacement##regex2##replacement2...
      final parts = replaceRegex.split('##');
      for (int i = 0; i < parts.length - 1; i += 2) {
        final regex = RegExp(parts[i]);
        final replacement = parts.length > i + 1 ? parts[i + 1] : '';
        content = content.replaceAll(regex, replacement);
      }
    } catch (e) {
      debugPrint('替换正则失败: $e');
    }
    return content;
  }

  /// 清理正文内容
  String _cleanContent(String content) {
    // 对齐 legado 的 HTML -> 文本清理策略（块级标签换行、不可见字符移除）
    return HtmlTextFormatter.formatToPlainText(content);
  }
}

enum _DebugListMode { search, explore }

class SourceDebugEvent {
  final int state;
  final String message;
  final bool isRaw;

  const SourceDebugEvent({
    required this.state,
    required this.message,
    this.isRaw = false,
  });
}

enum DebugRequestType { search, explore, bookInfo, toc, content }

class FetchDebugResult {
  final String requestUrl;
  final String? finalUrl;
  final int? statusCode;
  final int elapsedMs;
  final int responseLength;
  final String? responseSnippet;
  final Map<String, String> requestHeaders;
  final String? error;

  /// 原始响应体（仅用于编辑器调试；不要在普通 UI 中到处传递）
  final String? body;

  const FetchDebugResult({
    required this.requestUrl,
    required this.finalUrl,
    required this.statusCode,
    required this.elapsedMs,
    required this.responseLength,
    required this.responseSnippet,
    required this.requestHeaders,
    required this.error,
    required this.body,
  });

  factory FetchDebugResult.empty() {
    return const FetchDebugResult(
      requestUrl: '',
      finalUrl: null,
      statusCode: null,
      elapsedMs: 0,
      responseLength: 0,
      responseSnippet: null,
      requestHeaders: {},
      error: null,
      body: null,
    );
  }
}

class SearchDebugResult {
  final FetchDebugResult fetch;
  final DebugRequestType requestType;
  final String? requestUrlRule;
  final String? listRule;
  final int listCount;
  final List<SearchResult> results;
  final Map<String, String> fieldSample;
  final String? error;

  const SearchDebugResult({
    required this.fetch,
    required this.requestType,
    required this.requestUrlRule,
    required this.listRule,
    required this.listCount,
    required this.results,
    required this.fieldSample,
    required this.error,
  });
}

class ExploreDebugResult {
  final FetchDebugResult fetch;
  final DebugRequestType requestType;
  final String? requestUrlRule;
  final String? listRule;
  final int listCount;
  final List<SearchResult> results;
  final Map<String, String> fieldSample;
  final String? error;

  const ExploreDebugResult({
    required this.fetch,
    required this.requestType,
    required this.requestUrlRule,
    required this.listRule,
    required this.listCount,
    required this.results,
    required this.fieldSample,
    required this.error,
  });
}

class BookInfoDebugResult {
  final FetchDebugResult fetch;
  final DebugRequestType requestType;
  final String? requestUrlRule;
  final String? initRule;
  final bool initMatched;
  final BookDetail? detail;
  final Map<String, String> fieldSample;
  final String? error;

  const BookInfoDebugResult({
    required this.fetch,
    required this.requestType,
    required this.requestUrlRule,
    required this.initRule,
    required this.initMatched,
    required this.detail,
    required this.fieldSample,
    required this.error,
  });
}

class TocDebugResult {
  final FetchDebugResult fetch;
  final DebugRequestType requestType;
  final String? requestUrlRule;
  final String? listRule;
  final int listCount;
  final List<TocItem> toc;
  final Map<String, String> fieldSample;
  final String? error;

  const TocDebugResult({
    required this.fetch,
    required this.requestType,
    required this.requestUrlRule,
    required this.listRule,
    required this.listCount,
    required this.toc,
    required this.fieldSample,
    required this.error,
  });
}

class ContentDebugResult {
  final FetchDebugResult fetch;
  final DebugRequestType requestType;
  final String? requestUrlRule;
  final int extractedLength;
  final int cleanedLength;
  final String content;
  final String? error;

  const ContentDebugResult({
    required this.fetch,
    required this.requestType,
    required this.requestUrlRule,
    required this.extractedLength,
    required this.cleanedLength,
    required this.content,
    required this.error,
  });
}

/// 搜索结果
class SearchResult {
  final String name;
  final String author;
  final String coverUrl;
  final String intro;
  final String lastChapter;
  final String bookUrl;
  final String sourceUrl;
  final String sourceName;

  const SearchResult({
    required this.name,
    required this.author,
    required this.coverUrl,
    required this.intro,
    required this.lastChapter,
    required this.bookUrl,
    required this.sourceUrl,
    required this.sourceName,
  });
}

/// 书籍详情
class BookDetail {
  final String name;
  final String author;
  final String coverUrl;
  final String intro;
  final String kind;
  final String lastChapter;
  final String tocUrl;
  final String bookUrl;

  const BookDetail({
    required this.name,
    required this.author,
    required this.coverUrl,
    required this.intro,
    required this.kind,
    required this.lastChapter,
    required this.tocUrl,
    required this.bookUrl,
  });
}

/// 目录项
class TocItem {
  final int index;
  final String name;
  final String url;

  const TocItem({
    required this.index,
    required this.name,
    required this.url,
  });
}
