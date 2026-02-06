import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart';
import 'dart:convert';
import '../models/book_source.dart';
import 'package:flutter/foundation.dart';
import '../../../core/utils/html_text_formatter.dart';

/// 书源规则解析引擎
/// 支持 CSS 选择器、XPath（简化版）和正则表达式
class RuleParserEngine {
  static const Map<String, String> _defaultHeaders = {
    'User-Agent': 'Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) '
        'AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.0 Mobile/15E148 Safari/604.1',
    'Accept':
        'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
    'Accept-Language': 'zh-CN,zh;q=0.9,en-US;q=0.8,en;q=0.7',
  };

  static final Dio _dioPlain = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      headers: _defaultHeaders,
      // 书源站点很常见 30x 跳转（尤其从 http -> https）
      followRedirects: true,
      maxRedirects: 8,
    ),
  );

  static final CookieJar _cookieJar = CookieJar();
  static final Dio _dioCookie = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      headers: _defaultHeaders,
      followRedirects: true,
      maxRedirects: 8,
    ),
  )..interceptors.add(CookieManager(_cookieJar));

  Dio _selectDio({bool? enabledCookieJar}) {
    final enabled = enabledCookieJar ?? true;
    return enabled ? _dioCookie : _dioPlain;
  }

  static Future<void> saveCookiesForUrl(
    String url,
    List<Cookie> cookies,
  ) async {
    final uri = Uri.parse(url);
    await _cookieJar.saveFromResponse(uri, cookies);
  }

  static Future<List<Cookie>> loadCookiesForUrl(String url) async {
    final uri = Uri.parse(url);
    return _cookieJar.loadForRequest(uri);
  }

  Map<String, String> _buildEffectiveRequestHeaders(
    String url, {
    required Map<String, String> customHeaders,
  }) {
    final headers = <String, String>{};

    // 先放入通用头，再用书源自定义 header 覆盖同名 key
    headers.addAll(_defaultHeaders);
    headers.addAll(customHeaders);

    // 自动补齐 Referer/Origin（对标 legado 常见用法）
    // - 防盗链/反爬站点常见会校验 Referer / Origin
    // - 若书源里显式指定了 Referer/Origin，则不覆盖
    Uri? uri;
    try {
      uri = Uri.parse(url);
    } catch (_) {
      uri = null;
    }
    if (uri != null && uri.scheme.isNotEmpty && uri.host.isNotEmpty) {
      final isDefaultPort = (uri.scheme == 'http' && uri.port == 80) ||
          (uri.scheme == 'https' && uri.port == 443);
      final origin = isDefaultPort || !uri.hasPort
          ? '${uri.scheme}://${uri.host}'
          : '${uri.scheme}://${uri.host}:${uri.port}';

      bool hasKey(String key) {
        final lower = key.toLowerCase();
        return headers.keys.any((k) => k.toLowerCase() == lower);
      }

      if (!hasKey('Origin')) {
        headers['Origin'] = origin;
      }
      if (!hasKey('Referer')) {
        headers['Referer'] = '$origin/';
      }
    }

    return headers;
  }

  String _formatRequestHeadersForLog(Map<String, String> headers) {
    if (headers.isEmpty) return '—';

    String redactIfSensitive(String key, String value) {
      final k = key.toLowerCase();
      if (k == 'cookie' || k == 'authorization') {
        return '<redacted ${value.length} chars>';
      }
      if (value.length <= 220) return value;
      return '${value.substring(0, 220)}…';
    }

    const preferredOrder = <String>[
      'User-Agent',
      'Accept',
      'Accept-Language',
      'Referer',
      'Origin',
      'Cookie',
    ];

    final entries = headers.entries.toList(growable: false);

    String? getByName(String name) {
      final lower = name.toLowerCase();
      for (final e in entries) {
        if (e.key.toLowerCase() == lower) {
          return '${e.key}: ${redactIfSensitive(e.key, e.value)}';
        }
      }
      return null;
    }

    final lines = <String>[];
    final takenLower = <String>{};

    for (final k in preferredOrder) {
      final line = getByName(k);
      if (line != null) {
        lines.add(line);
        takenLower.add(k.toLowerCase());
      }
    }

    final rest = entries
        .where((e) => !takenLower.contains(e.key.toLowerCase()))
        .toList(growable: false)
      ..sort((a, b) => a.key.toLowerCase().compareTo(b.key.toLowerCase()));

    for (final e in rest) {
      lines.add('${e.key}: ${redactIfSensitive(e.key, e.value)}');
    }

    const maxLines = 18;
    if (lines.length > maxLines) {
      final head = lines.take(maxLines).toList(growable: false);
      head.add('…（${lines.length - maxLines} 行已省略）');
      return head.join('\n');
    }
    return lines.join('\n');
  }

  static final RegExp _httpHeaderTokenRegex =
      RegExp(r"^[!#$%&'*+\-.^_`|~0-9A-Za-z]+$");

  _ParsedHeaders _parseRequestHeaders(String? header) {
    if (header == null) return _ParsedHeaders.empty;
    final raw = header.trim();
    if (raw.isEmpty) return _ParsedHeaders.empty;

    String? warning;

    Map<String, String> mapToHeaders(Map decoded) {
      final m = <String, String>{};
      decoded.forEach((k, v) {
        final key = k.toString().trim();
        if (key.isEmpty) return;
        if (v == null) return;
        if (_httpHeaderTokenRegex.hasMatch(key)) {
          m[key] = v.toString();
        } else {
          warning ??= '存在非法 header key（已忽略）: $key';
        }
      });
      return m;
    }

    String? normalizeMaybeDoubleEncoded(String text) {
      final t = text.trim();
      if (t.length >= 2 && t.startsWith('"') && t.endsWith('"')) {
        try {
          final decoded = jsonDecode(t);
          if (decoded is String) return decoded;
        } catch (_) {
          // ignore
        }
      }
      return null;
    }

    String? unescapeWeirdJsonObjectText(String text) {
      final t = text.trim();
      // 兼容少见情况：header 被“多转了一次字符串”，变成：
      // {\"User-Agent\":\"xxx\"}
      // 或 {\\\"User-Agent\\\":\\\"xxx\\\"}
      if (!(t.startsWith('{') && t.contains(r'\"'))) return null;
      var fixed = t;
      // 先把 \\ -> \（避免后续 \" 仍然带双斜杠）
      fixed = fixed.replaceAll(r'\\', '\\');
      // 再把 \" -> "
      fixed = fixed.replaceAll(r'\"', '"');
      return fixed == t ? null : fixed;
    }

    // Legado 的 header 常见格式是 JSON 字符串：
    // {"User-Agent":"xxx","Referer":"xxx"}
    final doubleDecoded = normalizeMaybeDoubleEncoded(raw);
    final normalizedRaw = doubleDecoded ?? raw;
    if (normalizedRaw.startsWith('{') && normalizedRaw.endsWith('}')) {
      try {
        final decoded = jsonDecode(normalizedRaw);
        if (decoded is Map) {
          return _ParsedHeaders(
            headers: mapToHeaders(decoded),
            warning: warning,
          );
        }
      } catch (_) {
        // fallthrough: try other formats below
      }

      // 兼容部分“二次转义”的 JSON 文本（常见于导入/粘贴路径）
      final fixed = unescapeWeirdJsonObjectText(normalizedRaw);
      if (fixed != null) {
        try {
          final decoded = jsonDecode(fixed);
          if (decoded is Map) {
            warning ??= 'header 似乎被二次转义，已自动修复解析';
            return _ParsedHeaders(
              headers: mapToHeaders(decoded),
              warning: warning,
            );
          }
        } catch (_) {
          warning ??= 'header 看起来像 JSON，但解析失败（将尝试其它格式）';
        }
      } else {
        warning ??= 'header 看起来像 JSON，但解析失败（将尝试其它格式）';
      }

      // 一些导入/编辑路径可能把 Map 变成 Dart 的 toString 形式：
      // {User-Agent: xxx, Referer: yyy}
      // 这种不是 JSON，但我们也尽量解析，避免直接崩溃。
      final inner = normalizedRaw.substring(1, normalizedRaw.length - 1).trim();
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
        if (m.isNotEmpty) {
          return _ParsedHeaders(headers: m, warning: warning);
        }
      }
    }

    // 兼容编辑器里的“每行 key:value”格式
    final headers = <String, String>{};
    for (final line in normalizedRaw.split('\n')) {
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
    return _ParsedHeaders(headers: headers, warning: warning);
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
        enabledCookieJar: source.enabledCookieJar,
      );
      if (response == null) return [];

      // 解析结果
      final document = html_parser.parse(response);
      final results = <SearchResult>[];

      // 获取书籍列表
      final bookListRule = searchRule.bookList ?? '';
      final bookElements = _querySelectorAll(document, bookListRule);

      for (final element in bookElements) {
        var bookUrl =
            _parseRule(element, searchRule.bookUrl, source.bookSourceUrl);
        if (bookUrl.isNotEmpty && !bookUrl.startsWith('http')) {
          bookUrl = _absoluteUrl(source.bookSourceUrl, bookUrl);
        }
        var coverUrl =
            _parseRule(element, searchRule.coverUrl, source.bookSourceUrl);
        if (coverUrl.isNotEmpty && !coverUrl.startsWith('http')) {
          coverUrl = _absoluteUrl(source.bookSourceUrl, coverUrl);
        }
        final result = SearchResult(
          name: _parseRule(element, searchRule.name, source.bookSourceUrl),
          author: _parseRule(element, searchRule.author, source.bookSourceUrl),
          coverUrl: coverUrl,
          intro: _parseRule(element, searchRule.intro, source.bookSourceUrl),
          lastChapter:
              _parseRule(element, searchRule.lastChapter, source.bookSourceUrl),
          bookUrl: bookUrl,
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
        enabledCookieJar: source.enabledCookieJar,
      );
      if (res.headersWarning != null && res.headersWarning!.trim().isNotEmpty) {
        log('└请求头解析提示：${res.headersWarning}', state: 1, showTime: false);
      }
      final cookieJarEnabled = source.enabledCookieJar ?? true;
      log(
        '└请求头（CookieJar=${cookieJarEnabled ? '开' : '关'}）\n'
        '${_formatRequestHeadersForLog(res.requestHeaders)}',
        state: 1,
        showTime: false,
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
          final headerHint = _importantResponseHeaders(res.responseHeaders);
          if (headerHint.isNotEmpty) {
            log('└响应头：$headerHint', state: -1, showTime: false);
          }
          if (status == 403) {
            log(
              '└提示：403 多为反爬/需要 Referer/Cookie。可在书源 header 里补 Referer/Origin/Cookie，或开启 enabledCookieJar。',
              state: -1,
              showTime: false,
            );
          }
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
    var loggedSample = false;
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

      // 对齐 legado：仅输出“一条有效样本”，避免 selector 命中广告/空节点导致样本全空而误导排查。
      if (!loggedSample && name.isNotEmpty && bookUrl.isNotEmpty) {
        loggedSample = true;
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
    var tocUrl = getField('获取目录链接', rule.tocUrl);
    if (tocUrl.trim().isEmpty) {
      // 对齐 legado 的容错：部分站点“详情页就是目录页”，tocUrl 规则为空/不匹配时允许直接用当前详情页继续。
      log('≡目录链接为空，将使用详情页作为目录页', showTime: false);
      tocUrl = fullUrl;
    }

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

    final normalized = _normalizeListRule(rule.chapterList);

    log('┌获取章节列表');
    final elements = _querySelectorAll(document, normalized.selector);
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

    if (normalized.reverse) toc = toc.reversed.toList(growable: true);
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
      enabledCookieJar: source.enabledCookieJar,
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
        enabledCookieJar: source.enabledCookieJar,
      );
      if (response == null) return [];

      final document = html_parser.parse(response);
      final results = <SearchResult>[];

      final bookListRule = exploreRule.bookList ?? '';
      final bookElements = _querySelectorAll(document, bookListRule);

      for (final element in bookElements) {
        var bookUrl =
            _parseRule(element, exploreRule.bookUrl, source.bookSourceUrl);
        if (bookUrl.isNotEmpty && !bookUrl.startsWith('http')) {
          bookUrl = _absoluteUrl(source.bookSourceUrl, bookUrl);
        }
        var coverUrl =
            _parseRule(element, exploreRule.coverUrl, source.bookSourceUrl);
        if (coverUrl.isNotEmpty && !coverUrl.startsWith('http')) {
          coverUrl = _absoluteUrl(source.bookSourceUrl, coverUrl);
        }
        final result = SearchResult(
          name: _parseRule(element, exploreRule.name, source.bookSourceUrl),
          author: _parseRule(element, exploreRule.author, source.bookSourceUrl),
          coverUrl: coverUrl,
          intro: _parseRule(element, exploreRule.intro, source.bookSourceUrl),
          lastChapter:
              _parseRule(element, exploreRule.lastChapter, source.bookSourceUrl),
          bookUrl: bookUrl,
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
      enabledCookieJar: source.enabledCookieJar,
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
        enabledCookieJar: source.enabledCookieJar,
      );
      if (response == null) return null;

      final document = html_parser.parse(response);
      Element? root = document.documentElement;

      // 如果有 init 规则，先定位根元素
      if (bookInfoRule.init != null && bookInfoRule.init!.isNotEmpty) {
        root = _querySelector(document, bookInfoRule.init!);
      }

      if (root == null) return null;

      var tocUrl = _parseRule(root, bookInfoRule.tocUrl, source.bookSourceUrl);
      if (tocUrl.trim().isEmpty && source.ruleToc != null) {
        // 兼容 legado 常见用法：部分站点“详情页即目录页”，未配置 tocUrl 时默认使用当前详情页。
        tocUrl = fullUrl;
      } else if (tocUrl.isNotEmpty && !tocUrl.startsWith('http')) {
        tocUrl = _absoluteUrl(source.bookSourceUrl, tocUrl);
      }

      var coverUrl =
          _parseRule(root, bookInfoRule.coverUrl, source.bookSourceUrl);
      if (coverUrl.isNotEmpty && !coverUrl.startsWith('http')) {
        coverUrl = _absoluteUrl(source.bookSourceUrl, coverUrl);
      }

      return BookDetail(
        name: _parseRule(root, bookInfoRule.name, source.bookSourceUrl),
        author: _parseRule(root, bookInfoRule.author, source.bookSourceUrl),
        coverUrl: coverUrl,
        intro: _parseRule(root, bookInfoRule.intro, source.bookSourceUrl),
        kind: _parseRule(root, bookInfoRule.kind, source.bookSourceUrl),
        lastChapter:
            _parseRule(root, bookInfoRule.lastChapter, source.bookSourceUrl),
        tocUrl: tocUrl,
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
      enabledCookieJar: source.enabledCookieJar,
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
      var coverUrl =
          _parseRule(root, bookInfoRule.coverUrl, source.bookSourceUrl);
      if (coverUrl.isNotEmpty && !coverUrl.startsWith('http')) {
        coverUrl = _absoluteUrl(source.bookSourceUrl, coverUrl);
      }
      final intro = _parseRule(root, bookInfoRule.intro, source.bookSourceUrl);
      final kind = _parseRule(root, bookInfoRule.kind, source.bookSourceUrl);
      final lastChapter =
          _parseRule(root, bookInfoRule.lastChapter, source.bookSourceUrl);
      var tocUrl = _parseRule(root, bookInfoRule.tocUrl, source.bookSourceUrl);
      if (tocUrl.trim().isEmpty && source.ruleToc != null) {
        tocUrl = fullUrl;
      } else if (tocUrl.isNotEmpty && !tocUrl.startsWith('http')) {
        tocUrl = _absoluteUrl(source.bookSourceUrl, tocUrl);
      }

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
        enabledCookieJar: source.enabledCookieJar,
      );
      if (response == null) return [];

      final document = html_parser.parse(response);
      final chapters = <TocItem>[];

      // 获取章节列表
      final normalized = _normalizeListRule(tocRule.chapterList);
      final chapterElements = _querySelectorAll(document, normalized.selector);

      for (int i = 0; i < chapterElements.length; i++) {
        final element = chapterElements[i];
        var url =
            _parseRule(element, tocRule.chapterUrl, source.bookSourceUrl);
        if (url.isNotEmpty && !url.startsWith('http')) {
          url = _absoluteUrl(source.bookSourceUrl, url);
        }
        final item = TocItem(
          index: i,
          name: _parseRule(element, tocRule.chapterName, source.bookSourceUrl),
          url: url,
        );

        if (item.name.isNotEmpty && item.url.isNotEmpty) {
          chapters.add(item);
        }
      }

      return normalized.reverse
          ? chapters.reversed.toList(growable: false)
          : chapters;
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
      enabledCookieJar: source.enabledCookieJar,
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
      final normalized = _normalizeListRule(tocRule.chapterList);
      final chapterElements = _querySelectorAll(document, normalized.selector);

      final chapters = <TocItem>[];
      Map<String, String> sample = const {};
      for (var i = 0; i < chapterElements.length; i++) {
        final element = chapterElements[i];
        final name =
            _parseRule(element, tocRule.chapterName, source.bookSourceUrl);
        var url =
            _parseRule(element, tocRule.chapterUrl, source.bookSourceUrl);
        if (url.isNotEmpty && !url.startsWith('http')) {
          url = _absoluteUrl(source.bookSourceUrl, url);
        }
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
        listRule: normalized.selector,
        listCount: chapterElements.length,
        toc: normalized.reverse
            ? chapters.reversed.toList(growable: false)
            : chapters,
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

  _NormalizedListRule _normalizeListRule(String? rawRule) {
    var rule = (rawRule ?? '').trim();
    var reverse = false;
    if (rule.startsWith('-')) {
      reverse = true;
      rule = rule.substring(1);
    }
    if (rule.startsWith('+')) {
      rule = rule.substring(1);
    }
    return _NormalizedListRule(selector: rule.trim(), reverse: reverse);
  }

  String _importantResponseHeaders(Map<String, String> headers) {
    if (headers.isEmpty) return '';
    final normalized = <String, String>{};
    headers.forEach((k, v) => normalized[k.toLowerCase()] = v);

    const keys = <String>[
      'content-type',
      'location',
      'set-cookie',
      'server',
      'via',
      'x-powered-by',
      'cf-ray',
      'cf-cache-status',
      'x-cache',
      'x-served-by',
    ];

    final parts = <String>[];
    for (final k in keys) {
      final v = normalized[k];
      if (v == null || v.trim().isEmpty) continue;
      final safe = v.length <= 200 ? v : '${v.substring(0, 200)}…';
      parts.add('$k=$safe');
    }
    return parts.join('; ');
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
        enabledCookieJar: source.enabledCookieJar,
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
      enabledCookieJar: source.enabledCookieJar,
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
    bool? enabledCookieJar,
  }) async {
    try {
      final timeout =
          (timeoutMs != null && timeoutMs > 0) ? Duration(milliseconds: timeoutMs) : null;
      final options = Options(
        connectTimeout: timeout,
        sendTimeout: timeout,
        receiveTimeout: timeout,
      );
      final parsedHeaders = _parseRequestHeaders(header);
      final requestHeaders = _buildEffectiveRequestHeaders(
        url,
        customHeaders: parsedHeaders.headers,
      );
      options.headers = requestHeaders;

      final response = await _selectDio(enabledCookieJar: enabledCookieJar)
          .get(url, options: options);
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
    bool? enabledCookieJar,
  }) async {
    final sw = Stopwatch()..start();
    final parsedHeaders = _parseRequestHeaders(header);
    final requestHeaders = _buildEffectiveRequestHeaders(
      url,
      customHeaders: parsedHeaders.headers,
    );
    final forLog = Map<String, String>.from(requestHeaders);
    final cookieJarOn = enabledCookieJar ?? true;
    if (cookieJarOn) {
      try {
        final cookies = await RuleParserEngine.loadCookiesForUrl(url);
        if (cookies.isNotEmpty &&
            !forLog.keys.any((k) => k.toLowerCase() == 'cookie')) {
          forLog['Cookie'] =
              cookies.map((c) => '${c.name}=${c.value}').join('; ');
        }
      } catch (_) {
        // ignore cookie load failure
      }
    }
    try {
      final timeout =
          (timeoutMs != null && timeoutMs > 0) ? Duration(milliseconds: timeoutMs) : null;
      final options = Options(
        connectTimeout: timeout,
        sendTimeout: timeout,
        receiveTimeout: timeout,
        validateStatus: (_) => true,
      );
      options.headers = requestHeaders;

      final response = await _selectDio(enabledCookieJar: enabledCookieJar)
          .get(url, options: options);
      final body = response.data?.toString();
      final respHeaders = response.headers.map.map(
        (k, v) => MapEntry(k, v.join(', ')),
      );
      sw.stop();
      return FetchDebugResult(
        requestUrl: url,
        finalUrl: response.realUri.toString(),
        statusCode: response.statusCode,
        elapsedMs: sw.elapsedMilliseconds,
        responseLength: body?.length ?? 0,
        responseSnippet: _snippet(body),
        requestHeaders: forLog,
        headersWarning: parsedHeaders.warning,
        responseHeaders: respHeaders,
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
        final respHeaders = response?.headers.map.map(
              (k, v) => MapEntry(k, v.join(', ')),
            ) ??
            const <String, String>{};
        final parts = <String>[
          'DioException(${e.type})',
          if (parsedHeaders.warning != null) 'header警告=${parsedHeaders.warning}',
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
          requestHeaders: forLog,
          headersWarning: parsedHeaders.warning,
          responseHeaders: respHeaders,
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
        requestHeaders: forLog,
        headersWarning: parsedHeaders.warning,
        responseHeaders: const <String, String>{},
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
  final String? headersWarning;
  final Map<String, String> responseHeaders;
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
    required this.headersWarning,
    required this.responseHeaders,
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
      headersWarning: null,
      responseHeaders: {},
      error: null,
      body: null,
    );
  }
}

class _ParsedHeaders {
  final Map<String, String> headers;
  final String? warning;

  const _ParsedHeaders({
    required this.headers,
    required this.warning,
  });

  static const empty = _ParsedHeaders(headers: {}, warning: null);

  @override
  String toString() => 'headers=$headers warning=$warning';
}

class _NormalizedListRule {
  final String selector;
  final bool reverse;

  const _NormalizedListRule({
    required this.selector,
    required this.reverse,
  });

  @override
  String toString() => 'selector=$selector reverse=$reverse';
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
