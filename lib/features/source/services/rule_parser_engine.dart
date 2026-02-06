import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart';
import 'dart:convert';
import '../models/book_source.dart';
import 'package:flutter/foundation.dart';
import 'package:fast_gbk/fast_gbk.dart';
import 'package:flutter_js/flutter_js.dart';
import 'package:json_path/json_path.dart';
import 'package:xpath_selector_html_parser/xpath_selector_html_parser.dart';
import '../../../core/utils/html_text_formatter.dart';
import '../../../core/services/cookie_store.dart';

/// 书源规则解析引擎
/// 支持 CSS 选择器、XPath（简化版）和正则表达式
class RuleParserEngine {
  static const Map<String, String> _defaultHeaders = {
    'User-Agent': 'Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) '
        'AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.0 Mobile/15E148 Safari/604.1',
    'Accept':
        'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
    'Accept-Language': 'zh-CN,zh;q=0.9,en-US;q=0.8,en;q=0.7',
    'Upgrade-Insecure-Requests': '1',
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

  static CookieJar get _cookieJar {
    // 这里依赖 main() 启动阶段的 CookieStore.setup()，对标 dbss 的 PersistCookieJar 逻辑。
    // 若调用方未初始化，将抛出异常，便于早发现配置问题。
    return CookieStore.jar;
  }

  static final Dio _dioCookie = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      headers: _defaultHeaders,
      followRedirects: true,
      maxRedirects: 8,
    ),
  )..interceptors.add(CookieManager(_cookieJar));

  // URL 选项里的 js（Legado 格式）需要一个 JS 执行环境。
  // iOS 下为 JavaScriptCore；Android/Linux 下为 QuickJS（flutter_js）。
  // 这里只用于“URL 参数处理”，不做复杂脚本引擎承诺。
  static final JavascriptRuntime _jsRuntime = getJavascriptRuntime(xhr: false);

  Dio _selectDio({bool? enabledCookieJar}) {
    final enabled = enabledCookieJar ?? true;
    return enabled ? _dioCookie : _dioPlain;
  }

  static Future<void> saveCookiesForUrl(
    String url,
    List<Cookie> cookies,
  ) async {
    final uri = Uri.parse(url);
    await CookieStore.saveFromResponse(uri, cookies);
  }

  static Future<List<Cookie>> loadCookiesForUrl(String url) async {
    final uri = Uri.parse(url);
    return CookieStore.loadForRequest(uri);
  }

  Map<String, String> _buildEffectiveRequestHeaders(
    String url, {
    required Map<String, String> customHeaders,
  }) {
    final headers = <String, String>{};

    // 先放入通用头，再用书源自定义 header 覆盖同名 key
    headers.addAll(_defaultHeaders);
    // 再保险：无论 header 来自何处，最终写入 Dio 前都做一次 key 过滤，
    // 避免出现 `{"User-Agent"` 这类非法 key 直接触发 dart:io FormatException。
    customHeaders.forEach((k, v) {
      final key = k.trim();
      if (key.isEmpty) return;
      if (!_httpHeaderTokenRegex.hasMatch(key)) return;
      headers[key] = v;
    });

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
        // 调试需要“看得到差异”，但也避免整段泄露：只展示头尾片段。
        final len = value.length;
        if (len <= 160) return value;
        final head = value.substring(0, 120);
        final tail = value.substring(len - 40);
        return '$head…$tail (len=$len)';
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
      if (!_httpHeaderTokenRegex.hasMatch(key)) {
        warning ??= '存在非法 header key（已忽略）: $key';
        continue;
      }
      headers[key] = value;
    }
    return _ParsedHeaders(headers: headers, warning: warning);
  }

  _LegadoUrlParsed _parseLegadoStyleUrl(String rawUrl) {
    final trimmed = rawUrl.trim();
    if (trimmed.isEmpty) return _LegadoUrlParsed(url: '', option: null);

    // Legado 常见：url,{jsonOption}
    // - 用“最后一个 ,{”做分割，尽量避免 url 本身包含逗号时误拆。
    final idx = trimmed.lastIndexOf(',{');
    if (idx <= 0) return _LegadoUrlParsed(url: trimmed, option: null);

    final urlPart = trimmed.substring(0, idx).trim();
    final optPart = trimmed.substring(idx + 1).trim(); // starts with '{'
    if (!optPart.startsWith('{') || !optPart.endsWith('}')) {
      return _LegadoUrlParsed(url: trimmed, option: null);
    }

    try {
      final decoded = jsonDecode(optPart);
      if (decoded is! Map) {
        return _LegadoUrlParsed(url: trimmed, option: null);
      }
      final map = decoded.map((k, v) => MapEntry(k.toString(), v));
      return _LegadoUrlParsed(
        url: urlPart.isEmpty ? trimmed : urlPart,
        option: _LegadoUrlOption.fromJson(map),
      );
    } catch (_) {
      return _LegadoUrlParsed(url: trimmed, option: null);
    }
  }

  _UrlJsPatchResult? _applyLegadoUrlOptionJs({
    required String js,
    required String url,
    required Map<String, String> headerMap,
  }) {
    // 对标 legado 的 url 参数 js：
    // - java.url 可读写
    // - java.headerMap.put(k,v) / putAll({}) 等
    // - 只用于“在请求前修改 url/header”
    final safeUrl = jsonEncode(url);
    final safeHeaders = jsonEncode(headerMap);
    final wrapped = '''
      (function(){
        var java = {};
        java.url = $safeUrl;
        java.headerMap = $safeHeaders;
        java.headerMap.put = function(k,v){ this[String(k)] = String(v); };
        java.headerMap.putAll = function(obj){
          if(!obj) return;
          for (var key in obj) { this[String(key)] = String(obj[key]); }
        };
        java.log = function(){ try { console.log.apply(console, arguments); } catch(e) {} };
        try {
          (function(){ $js })();
        } catch (e) {
          return JSON.stringify({ok:false, error: String(e && (e.stack||e.message||e)), url: java.url, headers: java.headerMap});
        }
        return JSON.stringify({ok:true, url: java.url, headers: java.headerMap});
      })()
    ''';

    try {
      final res = _jsRuntime.evaluate(wrapped);
      final text = res.stringResult.trim();
      if (text.isEmpty || text == 'null' || text == 'undefined') return null;
      final decoded = jsonDecode(text);
      if (decoded is! Map) return null;
      final ok = decoded['ok'] == true;
      final patchedUrl = decoded['url']?.toString() ?? url;
      final headersRaw = decoded['headers'];
      final patchedHeaders = <String, String>{};
      if (headersRaw is Map) {
        headersRaw.forEach((k, v) {
          if (k == null || v == null) return;
          patchedHeaders[k.toString()] = v.toString();
        });
      }
      return _UrlJsPatchResult(
        ok: ok,
        url: patchedUrl,
        headers: patchedHeaders.isEmpty ? headerMap : patchedHeaders,
        error: decoded['error']?.toString(),
      );
    } catch (e) {
      return _UrlJsPatchResult(
        ok: false,
        url: url,
        headers: headerMap,
        error: e.toString(),
      );
    }
  }

  String _normalizeCharset(String raw) {
    final c = raw.trim().toLowerCase();
    if (c.isEmpty) return '';
    if (c == 'utf8') return 'utf-8';
    if (c == 'utf_8') return 'utf-8';
    if (c == 'gb2312' || c == 'gbk' || c == 'gb18030') return 'gbk';
    return c;
  }

  String? _tryParseCharsetFromContentType(String? contentType) {
    final ct = (contentType ?? '').trim();
    if (ct.isEmpty) return null;
    final m = RegExp(r'charset\s*=\s*([^;\s]+)', caseSensitive: false)
        .firstMatch(ct);
    if (m == null) return null;
    final v = m.group(1);
    if (v == null) return null;
    return _normalizeCharset(v.replaceAll('"', '').replaceAll("'", ''));
  }

  String? _tryParseCharsetFromHtmlHead(Uint8List bytes) {
    // 用 latin1 作为“无损映射”，只为查 meta charset（不用于最终文本）
    final headLen = bytes.length < 4096 ? bytes.length : 4096;
    final head = latin1.decode(bytes.sublist(0, headLen), allowInvalid: true);
    final m1 = RegExp(
            r'''<meta[^>]+charset\s*=\s*['"]?\s*([^'"\s/>]+)''',
            caseSensitive: false)
        .firstMatch(head);
    final c1 = m1?.group(1);
    if (c1 != null && c1.trim().isNotEmpty) return _normalizeCharset(c1);

    final m2 = RegExp(
            r'''<meta[^>]+http-equiv\s*=\s*['"]content-type['"][^>]+content\s*=\s*['"][^'"]*charset\s*=\s*([^'"\s;]+)''',
            caseSensitive: false)
        .firstMatch(head);
    final c2 = m2?.group(1);
    if (c2 != null && c2.trim().isNotEmpty) return _normalizeCharset(c2);
    return null;
  }

  _DecodedText _decodeResponseBytes({
    required Uint8List bytes,
    required Map<String, String> responseHeaders,
    String? optionCharset,
  }) {
    final forced = optionCharset != null && optionCharset.trim().isNotEmpty
        ? _normalizeCharset(optionCharset)
        : '';
    final headerCharset = _tryParseCharsetFromContentType(
      responseHeaders['content-type'] ?? responseHeaders['Content-Type'],
    );
    final htmlCharset = _tryParseCharsetFromHtmlHead(bytes);

    final charset = (forced.isNotEmpty
            ? forced
            : (headerCharset?.isNotEmpty == true ? headerCharset! : ''))
        .trim();

    final effective = charset.isNotEmpty ? charset : (htmlCharset ?? 'utf-8');
    final normalized = _normalizeCharset(effective);

    try {
      if (normalized == 'gbk') {
        return _DecodedText(
          text: gbk.decode(bytes, allowMalformed: true),
          charset: 'gbk',
        );
      }
      if (normalized == 'utf-8') {
        return _DecodedText(
          text: utf8.decode(bytes, allowMalformed: true),
          charset: 'utf-8',
        );
      }
      // 其它编码先走 utf-8 容错；失败再回退 latin1
      return _DecodedText(
        text: utf8.decode(bytes, allowMalformed: true),
        charset: normalized,
      );
    } catch (_) {
      return _DecodedText(
        text: latin1.decode(bytes, allowInvalid: true),
        charset: normalized.isEmpty ? 'latin1' : normalized,
      );
    }
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

      final results = <SearchResult>[];

      // 获取书籍列表
      final bookListRule = searchRule.bookList ?? '';
      final trimmed = response.trimLeft();
      final jsonRoot = (trimmed.startsWith('{') || trimmed.startsWith('['))
          ? _tryDecodeJsonValue(response)
          : null;

      // JSONPath 模式（对标 legado：部分源直接返回 JSON）
      if (jsonRoot != null && _looksLikeJsonPath(bookListRule)) {
        final nodes = _selectJsonList(jsonRoot, bookListRule);
        for (final node in nodes) {
          final name = _parseValueOnNode(node, searchRule.name, searchUrl);
          final author = _parseValueOnNode(node, searchRule.author, searchUrl);
          final intro = _parseValueOnNode(node, searchRule.intro, searchUrl);
          final lastChapter =
              _parseValueOnNode(node, searchRule.lastChapter, searchUrl);

          var bookUrl = _parseValueOnNode(node, searchRule.bookUrl, searchUrl);
          if (bookUrl.isNotEmpty && !bookUrl.startsWith('http')) {
            bookUrl = _absoluteUrl(searchUrl, bookUrl);
          }

          var coverUrl =
              _parseValueOnNode(node, searchRule.coverUrl, searchUrl);
          if (coverUrl.isNotEmpty && !coverUrl.startsWith('http')) {
            coverUrl = _absoluteUrl(searchUrl, coverUrl);
          }

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

          if (result.name.isNotEmpty && result.bookUrl.isNotEmpty) {
            results.add(result);
          }
        }
      } else {
        // HTML 模式
        final document = html_parser.parse(response);
        final bookElements = _selectAllElementsByRule(document, bookListRule);

        for (final element in bookElements) {
          var bookUrl = _parseRule(element, searchRule.bookUrl, searchUrl);
          if (bookUrl.isNotEmpty && !bookUrl.startsWith('http')) {
            bookUrl = _absoluteUrl(searchUrl, bookUrl);
          }

          var coverUrl = _parseRule(element, searchRule.coverUrl, searchUrl);
          if (coverUrl.isNotEmpty && !coverUrl.startsWith('http')) {
            coverUrl = _absoluteUrl(searchUrl, coverUrl);
          }

          final result = SearchResult(
            name: _parseRule(element, searchRule.name, searchUrl),
            author: _parseRule(element, searchRule.author, searchUrl),
            coverUrl: coverUrl,
            intro: _parseRule(element, searchRule.intro, searchUrl),
            lastChapter: _parseRule(element, searchRule.lastChapter, searchUrl),
            bookUrl: bookUrl,
            sourceUrl: source.bookSourceUrl,
            sourceName: source.bookSourceName,
          );

          if (result.name.isNotEmpty && result.bookUrl.isNotEmpty) {
            results.add(result);
          }
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
      if (res.requestBodySnippet != null &&
          res.requestBodySnippet!.trim().isNotEmpty) {
        log(
          '└请求体（${res.method}）\n${res.requestBodySnippet}',
          state: 1,
          showTime: false,
        );
      } else {
        log(
          '└请求方法：${res.method}',
          state: 1,
          showTime: false,
        );
      }
      final status = res.statusCode;
      final statusText = status != null ? ' ($status)' : '';
      final isBadStatus = status != null && status >= 400;
      if (res.body != null) {
        log(
          '≡获取${isBadStatus ? '完成' : '成功'}:${res.finalUrl ?? res.requestUrl}'
          '$statusText ${res.elapsedMs}ms',
          state: isBadStatus ? -1 : 1,
        );
        if (res.responseCharset != null &&
            res.responseCharset!.trim().isNotEmpty) {
          log('└响应编码：${res.responseCharset}', state: 1, showTime: false);
        }
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

    final listSelector = bookListRule.bookList ?? '';

    log('┌获取书籍列表');
    final results = <SearchResult>[];
    var loggedSample = false;

    final trimmed = body.trimLeft();
    final jsonRoot = (trimmed.startsWith('{') || trimmed.startsWith('['))
        ? _tryDecodeJsonValue(body)
        : null;

    if (jsonRoot != null && _looksLikeJsonPath(listSelector)) {
      final nodes = _selectJsonList(jsonRoot, listSelector);
      log('└列表大小:${nodes.length}');
      if (nodes.isEmpty) {
        log('≡列表为空，可能是详情页或规则不匹配');
      }

      for (var i = 0; i < nodes.length; i++) {
        final node = nodes[i];
        final name = _parseValueOnNode(node, bookListRule.name, requestUrl);
        final author =
            _parseValueOnNode(node, bookListRule.author, requestUrl);
        var coverUrl =
            _parseValueOnNode(node, bookListRule.coverUrl, requestUrl);
        if (coverUrl.isNotEmpty && !coverUrl.startsWith('http')) {
          coverUrl = _absoluteUrl(requestUrl, coverUrl);
        }
        final intro = _parseValueOnNode(node, bookListRule.intro, requestUrl);
        final lastChapter =
            _parseValueOnNode(node, bookListRule.lastChapter, requestUrl);
        var bookUrl =
            _parseValueOnNode(node, bookListRule.bookUrl, requestUrl);
        if (bookUrl.isNotEmpty && !bookUrl.startsWith('http')) {
          bookUrl = _absoluteUrl(requestUrl, bookUrl);
        }

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
    } else {
      final document = html_parser.parse(body);
      final elements = _selectAllElementsByRule(document, listSelector);
      log('└列表大小:${elements.length}');

      if (elements.isEmpty) {
        // 对齐 legado：列表为空时可能是“详情页”，这里仅提示，不强行走详情解析（后续可按 bookUrlPattern 补齐）
        log('≡列表为空，可能是详情页或规则不匹配');
      }

      for (var i = 0; i < elements.length; i++) {
        final el = elements[i];
        final name = _parseRule(el, bookListRule.name, requestUrl);
        final author = _parseRule(el, bookListRule.author, requestUrl);
        var coverUrl = _parseRule(el, bookListRule.coverUrl, requestUrl);
        if (coverUrl.isNotEmpty && !coverUrl.startsWith('http')) {
          coverUrl = _absoluteUrl(requestUrl, coverUrl);
        }
        final intro = _parseRule(el, bookListRule.intro, requestUrl);
        final lastChapter = _parseRule(el, bookListRule.lastChapter, requestUrl);
        var bookUrl = _parseRule(el, bookListRule.bookUrl, requestUrl);
        if (bookUrl.isNotEmpty && !bookUrl.startsWith('http')) {
          bookUrl = _absoluteUrl(requestUrl, bookUrl);
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

    final trimmed = body.trimLeft();
    final jsonRoot = (trimmed.startsWith('{') || trimmed.startsWith('['))
        ? _tryDecodeJsonValue(body)
        : null;

    // JSON 模式：不支持 init
    if (jsonRoot != null) {
      String getField(String label, String? ruleStr) {
        log('┌$label');
        final value = _parseValueOnNode(jsonRoot, ruleStr, fullUrl);
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
        log('≡目录链接为空，将使用详情页作为目录页', showTime: false);
        tocUrl = fullUrl;
      } else if (!tocUrl.startsWith('http')) {
        tocUrl = _absoluteUrl(fullUrl, tocUrl);
      }

      if (name.isEmpty && author.isEmpty && lastChapter.isEmpty && tocUrl.isEmpty) {
        log('≡字段全为空，可能 ruleBookInfo 不匹配', state: -1);
      }

      log('︽详情页解析完成', showTime: false);
      log('', showTime: false);

      return tocUrl;
    }

    final document = html_parser.parse(body);
    Element? root = document.documentElement;
    if (root == null) {
      log('⇒页面无 documentElement', state: -1);
      return null;
    }

    if (rule.init != null && rule.init!.trim().isNotEmpty) {
      log('≡执行详情页初始化规则');
      final initEl = _selectFirstElementByRule(document, rule.init!.trim());
      if (initEl != null) {
        root = initEl;
      } else {
        log('└init 匹配失败（将继续用 documentElement）');
      }
    }

    String getField(String label, String? ruleStr) {
      log('┌$label');
      final value = _parseRule(root!, ruleStr, fullUrl);
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
    } else if (!tocUrl.startsWith('http')) {
      tocUrl = _absoluteUrl(fullUrl, tocUrl);
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

    final tocRule = source.ruleToc;
    if (tocRule == null) {
      log('⇒目录规则为空', state: -1);
      return false;
    }

    final normalized = _normalizeListRule(tocRule.chapterList);
    final toc = <TocItem>[];

    final visited = <String>{};
    var currentUrl = _absoluteUrl(source.bookSourceUrl, tocUrl);
    var page = 0;
    const maxPages = 12;

    while (currentUrl.trim().isNotEmpty &&
        !visited.contains(currentUrl) &&
        page < maxPages) {
      visited.add(currentUrl);

      log('≡目录页请求:${page + 1}');
      final fetch = await fetchStage(currentUrl, rawState: 30);
      final body = fetch.body!;

      final trimmed = body.trimLeft();
      final jsonRoot = (trimmed.startsWith('{') || trimmed.startsWith('['))
          ? _tryDecodeJsonValue(body)
          : null;

      String? nextUrl;

      log('┌获取章节列表');
      if (jsonRoot != null && _looksLikeJsonPath(normalized.selector)) {
        final nodes = _selectJsonList(jsonRoot, normalized.selector);
        log('└列表大小:${nodes.length}');
        for (var i = 0; i < nodes.length; i++) {
          final node = nodes[i];
          final name = _parseValueOnNode(node, tocRule.chapterName, currentUrl);
          var url = _parseValueOnNode(node, tocRule.chapterUrl, currentUrl);
          if (url.isNotEmpty && !url.startsWith('http')) {
            url = _absoluteUrl(currentUrl, url);
          }
          if (toc.isEmpty && i == 0) {
            log('┌获取章节名');
            log('└$name');
            log('┌获取章节链接');
            log('└$url');
          }
          if (name.isEmpty || url.isEmpty) continue;
          toc.add(TocItem(index: toc.length, name: name, url: url));
        }
        if (tocRule.nextTocUrl != null &&
            tocRule.nextTocUrl!.trim().isNotEmpty) {
          nextUrl = _parseValueOnNode(jsonRoot, tocRule.nextTocUrl, currentUrl);
        }
      } else {
        final document = html_parser.parse(body);
        final elements = _selectAllElementsByRule(document, normalized.selector);
        log('└列表大小:${elements.length}');
        for (var i = 0; i < elements.length; i++) {
          final el = elements[i];
          final name = _parseRule(el, tocRule.chapterName, currentUrl);
          var url = _parseRule(el, tocRule.chapterUrl, currentUrl);
          if (url.isNotEmpty && !url.startsWith('http')) {
            url = _absoluteUrl(currentUrl, url);
          }
          if (toc.isEmpty && i == 0) {
            log('┌获取章节名');
            log('└$name');
            log('┌获取章节链接');
            log('└$url');
          }
          if (name.isEmpty || url.isEmpty) continue;
          toc.add(TocItem(index: toc.length, name: name, url: url));
        }
        if (tocRule.nextTocUrl != null &&
            tocRule.nextTocUrl!.trim().isNotEmpty) {
          final root = document.documentElement;
          if (root != null) {
            nextUrl = _parseRule(root, tocRule.nextTocUrl, currentUrl);
          }
        }
      }

      if (nextUrl == null || nextUrl.trim().isEmpty) break;
      var resolved = nextUrl.trim();
      if (!resolved.startsWith('http')) {
        resolved = _absoluteUrl(currentUrl, resolved);
      }
      if (resolved == currentUrl) break;
      currentUrl = resolved;
      page++;
    }

    var out = toc;
    if (normalized.reverse) out = out.reversed.toList(growable: true);
    log('◇章节总数:${out.length}');

    if (out.isEmpty) {
      log('≡没有正文章节', state: -1);
      return false;
    }

    log('︽目录页解析完成', showTime: false);
    log('', showTime: false);

    return _debugContentOnly(
      source: source,
      chapterUrl: out.first.url,
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

    final visited = <String>{};
    var currentUrl = _absoluteUrl(source.bookSourceUrl, chapterUrl);
    var page = 0;
    const maxPages = 8;

    final parts = <String>[];
    var totalExtracted = 0;

    while (currentUrl.trim().isNotEmpty &&
        !visited.contains(currentUrl) &&
        page < maxPages) {
      visited.add(currentUrl);

      log('≡正文页请求:${page + 1}');
      final fetch = await fetchStage(currentUrl, rawState: 40);
      final body = fetch.body!;

      final trimmed = body.trimLeft();
      final jsonRoot = (trimmed.startsWith('{') || trimmed.startsWith('['))
          ? _tryDecodeJsonValue(body)
          : null;

      String extracted;
      String? nextUrl;

      if (jsonRoot != null && rule.content != null && _looksLikeJsonPath(rule.content!)) {
        extracted = _parseValueOnNode(jsonRoot, rule.content, currentUrl);
        if (rule.nextContentUrl != null && rule.nextContentUrl!.trim().isNotEmpty) {
          nextUrl = _parseValueOnNode(jsonRoot, rule.nextContentUrl, currentUrl);
        }
      } else {
        final document = html_parser.parse(body);
        final root = document.documentElement;
        if (root == null) {
          log('⇒页面无 documentElement', state: -1);
          return false;
        }

        if (rule.content == null || rule.content!.trim().isEmpty) {
          if (page == 0) log('⇒内容规则为空，默认获取整个网页');
          extracted = root.text;
        } else {
          extracted = _parseRule(root, rule.content, currentUrl);
        }

        if (rule.nextContentUrl != null && rule.nextContentUrl!.trim().isNotEmpty) {
          nextUrl = _parseRule(root, rule.nextContentUrl, currentUrl);
        }
      }

      totalExtracted += extracted.length;

      var processed = extracted;
      if (rule.replaceRegex != null && rule.replaceRegex!.trim().isNotEmpty) {
        processed = _applyReplaceRegex(processed, rule.replaceRegex!);
      }
      final cleaned = _cleanContent(processed);
      if (cleaned.trim().isNotEmpty) parts.add(cleaned);

      if (nextUrl == null || nextUrl.trim().isEmpty) break;
      var resolved = nextUrl.trim();
      if (!resolved.startsWith('http')) {
        resolved = _absoluteUrl(currentUrl, resolved);
      }
      if (resolved == currentUrl) break;
      currentUrl = resolved;
      page++;
    }

    final cleanedAll = parts.join('\n');
    emitRaw(41, cleanedAll);

    log('◇分页:${parts.length} 提取总长:$totalExtracted 清理后总长:${cleanedAll.length}');
    log('┌获取正文内容');
    final maxLog = 2000;
    final preview = cleanedAll.length <= maxLog
        ? cleanedAll
        : '${cleanedAll.substring(0, maxLog)}\n…（已截断，查看“正文结果”可看全文）';
    log('└\n$preview');

    if (cleanedAll.trim().isEmpty) {
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
      final bookListRule = searchRule.bookList ?? '';
      final results = <SearchResult>[];
      Map<String, String> fieldSample = const {};
      var listCount = 0;

      final body = fetch.body!;
      final trimmed = body.trimLeft();
      final jsonRoot = (trimmed.startsWith('{') || trimmed.startsWith('['))
          ? _tryDecodeJsonValue(body)
          : null;

      if (jsonRoot != null && _looksLikeJsonPath(bookListRule)) {
        final nodes = _selectJsonList(jsonRoot, bookListRule);
        listCount = nodes.length;
        for (final node in nodes) {
          final name = _parseValueOnNode(node, searchRule.name, requestUrl);
          final author = _parseValueOnNode(node, searchRule.author, requestUrl);
          var coverUrl =
              _parseValueOnNode(node, searchRule.coverUrl, requestUrl);
          if (coverUrl.isNotEmpty && !coverUrl.startsWith('http')) {
            coverUrl = _absoluteUrl(requestUrl, coverUrl);
          }
          final intro = _parseValueOnNode(node, searchRule.intro, requestUrl);
          final lastChapter =
              _parseValueOnNode(node, searchRule.lastChapter, requestUrl);
          var bookUrl = _parseValueOnNode(node, searchRule.bookUrl, requestUrl);
          if (bookUrl.isNotEmpty && !bookUrl.startsWith('http')) {
            bookUrl = _absoluteUrl(requestUrl, bookUrl);
          }

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
      } else {
        final document = html_parser.parse(body);
        final bookElements = _selectAllElementsByRule(document, bookListRule);
        listCount = bookElements.length;

        for (final element in bookElements) {
          final name = _parseRule(element, searchRule.name, requestUrl);
          final author = _parseRule(element, searchRule.author, requestUrl);
          var coverUrl = _parseRule(element, searchRule.coverUrl, requestUrl);
          if (coverUrl.isNotEmpty && !coverUrl.startsWith('http')) {
            coverUrl = _absoluteUrl(requestUrl, coverUrl);
          }
          final intro = _parseRule(element, searchRule.intro, requestUrl);
          final lastChapter =
              _parseRule(element, searchRule.lastChapter, requestUrl);
          var bookUrl = _parseRule(element, searchRule.bookUrl, requestUrl);
          if (bookUrl.isNotEmpty && !bookUrl.startsWith('http')) {
            bookUrl = _absoluteUrl(requestUrl, bookUrl);
          }

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
      }

      return SearchDebugResult(
        fetch: fetch,
        requestType: DebugRequestType.search,
        requestUrlRule: searchUrlRule,
        listRule: bookListRule,
        listCount: listCount,
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

      final results = <SearchResult>[];

      final bookListRule = exploreRule.bookList ?? '';
      final trimmed = response.trimLeft();
      final jsonRoot = (trimmed.startsWith('{') || trimmed.startsWith('['))
          ? _tryDecodeJsonValue(response)
          : null;

      if (jsonRoot != null && _looksLikeJsonPath(bookListRule)) {
        final nodes = _selectJsonList(jsonRoot, bookListRule);
        for (final node in nodes) {
          final name = _parseValueOnNode(node, exploreRule.name, exploreUrl);
          final author =
              _parseValueOnNode(node, exploreRule.author, exploreUrl);
          final intro = _parseValueOnNode(node, exploreRule.intro, exploreUrl);
          final lastChapter =
              _parseValueOnNode(node, exploreRule.lastChapter, exploreUrl);

          var bookUrl = _parseValueOnNode(node, exploreRule.bookUrl, exploreUrl);
          if (bookUrl.isNotEmpty && !bookUrl.startsWith('http')) {
            bookUrl = _absoluteUrl(exploreUrl, bookUrl);
          }

          var coverUrl =
              _parseValueOnNode(node, exploreRule.coverUrl, exploreUrl);
          if (coverUrl.isNotEmpty && !coverUrl.startsWith('http')) {
            coverUrl = _absoluteUrl(exploreUrl, coverUrl);
          }

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

          if (result.name.isNotEmpty && result.bookUrl.isNotEmpty) {
            results.add(result);
          }
        }
      } else {
        final document = html_parser.parse(response);
        final bookElements = _selectAllElementsByRule(document, bookListRule);

        for (final element in bookElements) {
          var bookUrl = _parseRule(element, exploreRule.bookUrl, exploreUrl);
          if (bookUrl.isNotEmpty && !bookUrl.startsWith('http')) {
            bookUrl = _absoluteUrl(exploreUrl, bookUrl);
          }
          var coverUrl = _parseRule(element, exploreRule.coverUrl, exploreUrl);
          if (coverUrl.isNotEmpty && !coverUrl.startsWith('http')) {
            coverUrl = _absoluteUrl(exploreUrl, coverUrl);
          }
          final result = SearchResult(
            name: _parseRule(element, exploreRule.name, exploreUrl),
            author: _parseRule(element, exploreRule.author, exploreUrl),
            coverUrl: coverUrl,
            intro: _parseRule(element, exploreRule.intro, exploreUrl),
            lastChapter: _parseRule(element, exploreRule.lastChapter, exploreUrl),
            bookUrl: bookUrl,
            sourceUrl: source.bookSourceUrl,
            sourceName: source.bookSourceName,
          );

          if (result.name.isNotEmpty && result.bookUrl.isNotEmpty) {
            results.add(result);
          }
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
      final bookListRule = exploreRule.bookList ?? '';
      final results = <SearchResult>[];
      Map<String, String> fieldSample = const {};
      var listCount = 0;

      final body = fetch.body!;
      final trimmed = body.trimLeft();
      final jsonRoot = (trimmed.startsWith('{') || trimmed.startsWith('['))
          ? _tryDecodeJsonValue(body)
          : null;

      if (jsonRoot != null && _looksLikeJsonPath(bookListRule)) {
        final nodes = _selectJsonList(jsonRoot, bookListRule);
        listCount = nodes.length;
        for (final node in nodes) {
          final name = _parseValueOnNode(node, exploreRule.name, requestUrl);
          final author = _parseValueOnNode(node, exploreRule.author, requestUrl);
          var coverUrl =
              _parseValueOnNode(node, exploreRule.coverUrl, requestUrl);
          if (coverUrl.isNotEmpty && !coverUrl.startsWith('http')) {
            coverUrl = _absoluteUrl(requestUrl, coverUrl);
          }
          final intro = _parseValueOnNode(node, exploreRule.intro, requestUrl);
          final lastChapter =
              _parseValueOnNode(node, exploreRule.lastChapter, requestUrl);
          var bookUrl =
              _parseValueOnNode(node, exploreRule.bookUrl, requestUrl);
          if (bookUrl.isNotEmpty && !bookUrl.startsWith('http')) {
            bookUrl = _absoluteUrl(requestUrl, bookUrl);
          }

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
      } else {
        final document = html_parser.parse(body);
        final bookElements = _selectAllElementsByRule(document, bookListRule);
        listCount = bookElements.length;

        for (final element in bookElements) {
          final name = _parseRule(element, exploreRule.name, requestUrl);
          final author = _parseRule(element, exploreRule.author, requestUrl);
          var coverUrl = _parseRule(element, exploreRule.coverUrl, requestUrl);
          if (coverUrl.isNotEmpty && !coverUrl.startsWith('http')) {
            coverUrl = _absoluteUrl(requestUrl, coverUrl);
          }
          final intro = _parseRule(element, exploreRule.intro, requestUrl);
          final lastChapter =
              _parseRule(element, exploreRule.lastChapter, requestUrl);
          var bookUrl = _parseRule(element, exploreRule.bookUrl, requestUrl);
          if (bookUrl.isNotEmpty && !bookUrl.startsWith('http')) {
            bookUrl = _absoluteUrl(requestUrl, bookUrl);
          }

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
      }

      return ExploreDebugResult(
        fetch: fetch,
        requestType: DebugRequestType.explore,
        requestUrlRule: exploreUrlRule,
        listRule: bookListRule,
        listCount: listCount,
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

      final trimmed = response.trimLeft();
      final jsonRoot = (trimmed.startsWith('{') || trimmed.startsWith('['))
          ? _tryDecodeJsonValue(response)
          : null;

      // JSON 模式
      if (jsonRoot != null) {
        var tocUrl = _parseValueOnNode(jsonRoot, bookInfoRule.tocUrl, fullUrl);
        if (tocUrl.trim().isEmpty && source.ruleToc != null) {
          tocUrl = fullUrl;
        } else if (tocUrl.isNotEmpty && !tocUrl.startsWith('http')) {
          tocUrl = _absoluteUrl(fullUrl, tocUrl);
        }

        var coverUrl =
            _parseValueOnNode(jsonRoot, bookInfoRule.coverUrl, fullUrl);
        if (coverUrl.isNotEmpty && !coverUrl.startsWith('http')) {
          coverUrl = _absoluteUrl(fullUrl, coverUrl);
        }

        return BookDetail(
          name: _parseValueOnNode(jsonRoot, bookInfoRule.name, fullUrl),
          author: _parseValueOnNode(jsonRoot, bookInfoRule.author, fullUrl),
          coverUrl: coverUrl,
          intro: _parseValueOnNode(jsonRoot, bookInfoRule.intro, fullUrl),
          kind: _parseValueOnNode(jsonRoot, bookInfoRule.kind, fullUrl),
          lastChapter:
              _parseValueOnNode(jsonRoot, bookInfoRule.lastChapter, fullUrl),
          tocUrl: tocUrl,
          bookUrl: fullUrl,
        );
      }

      // HTML 模式
      final document = html_parser.parse(response);
      Element? root = document.documentElement;

      // 如果有 init 规则，先定位根元素
      if (bookInfoRule.init != null && bookInfoRule.init!.isNotEmpty) {
        root = _selectFirstElementByRule(document, bookInfoRule.init!);
      }

      if (root == null) return null;

      var tocUrl = _parseRule(root, bookInfoRule.tocUrl, fullUrl);
      if (tocUrl.trim().isEmpty && source.ruleToc != null) {
        // 兼容 legado 常见用法：部分站点“详情页即目录页”，未配置 tocUrl 时默认使用当前详情页。
        tocUrl = fullUrl;
      } else if (tocUrl.isNotEmpty && !tocUrl.startsWith('http')) {
        tocUrl = _absoluteUrl(fullUrl, tocUrl);
      }

      var coverUrl = _parseRule(root, bookInfoRule.coverUrl, fullUrl);
      if (coverUrl.isNotEmpty && !coverUrl.startsWith('http')) {
        coverUrl = _absoluteUrl(fullUrl, coverUrl);
      }

      return BookDetail(
        name: _parseRule(root, bookInfoRule.name, fullUrl),
        author: _parseRule(root, bookInfoRule.author, fullUrl),
        coverUrl: coverUrl,
        intro: _parseRule(root, bookInfoRule.intro, fullUrl),
        kind: _parseRule(root, bookInfoRule.kind, fullUrl),
        lastChapter: _parseRule(root, bookInfoRule.lastChapter, fullUrl),
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
      final body = fetch.body!;
      final trimmed = body.trimLeft();
      final jsonRoot = (trimmed.startsWith('{') || trimmed.startsWith('['))
          ? _tryDecodeJsonValue(body)
          : null;

      // JSON 模式（响应为 JSON 时 init 不适用）
      if (jsonRoot != null) {
        final initRule = bookInfoRule.init;
        final initMatched = initRule == null || initRule.trim().isEmpty;

        final name = _parseValueOnNode(jsonRoot, bookInfoRule.name, fullUrl);
        final author =
            _parseValueOnNode(jsonRoot, bookInfoRule.author, fullUrl);
        var coverUrl =
            _parseValueOnNode(jsonRoot, bookInfoRule.coverUrl, fullUrl);
        if (coverUrl.isNotEmpty && !coverUrl.startsWith('http')) {
          coverUrl = _absoluteUrl(fullUrl, coverUrl);
        }
        final intro = _parseValueOnNode(jsonRoot, bookInfoRule.intro, fullUrl);
        final kind = _parseValueOnNode(jsonRoot, bookInfoRule.kind, fullUrl);
        final lastChapter =
            _parseValueOnNode(jsonRoot, bookInfoRule.lastChapter, fullUrl);
        var tocUrl = _parseValueOnNode(jsonRoot, bookInfoRule.tocUrl, fullUrl);
        if (tocUrl.trim().isEmpty && source.ruleToc != null) {
          tocUrl = fullUrl;
        } else if (tocUrl.isNotEmpty && !tocUrl.startsWith('http')) {
          tocUrl = _absoluteUrl(fullUrl, tocUrl);
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
          initRule: initRule,
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
          error: initMatched ? null : '响应为 JSON：init 规则不适用',
        );
      }

      // HTML 模式
      final document = html_parser.parse(body);
      Element? root = document.documentElement;
      var initMatched = true;

      if (bookInfoRule.init != null && bookInfoRule.init!.isNotEmpty) {
        root = _selectFirstElementByRule(document, bookInfoRule.init!);
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

      final name = _parseRule(root, bookInfoRule.name, fullUrl);
      final author = _parseRule(root, bookInfoRule.author, fullUrl);
      var coverUrl = _parseRule(root, bookInfoRule.coverUrl, fullUrl);
      if (coverUrl.isNotEmpty && !coverUrl.startsWith('http')) {
        coverUrl = _absoluteUrl(fullUrl, coverUrl);
      }
      final intro = _parseRule(root, bookInfoRule.intro, fullUrl);
      final kind = _parseRule(root, bookInfoRule.kind, fullUrl);
      final lastChapter = _parseRule(root, bookInfoRule.lastChapter, fullUrl);
      var tocUrl = _parseRule(root, bookInfoRule.tocUrl, fullUrl);
      if (tocUrl.trim().isEmpty && source.ruleToc != null) {
        tocUrl = fullUrl;
      } else if (tocUrl.isNotEmpty && !tocUrl.startsWith('http')) {
        tocUrl = _absoluteUrl(fullUrl, tocUrl);
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
      final normalized = _normalizeListRule(tocRule.chapterList);
      final chapters = <TocItem>[];

      final visited = <String>{};
      var currentUrl = _absoluteUrl(source.bookSourceUrl, tocUrl);
      var page = 0;
      const maxPages = 12;

      while (currentUrl.trim().isNotEmpty &&
          !visited.contains(currentUrl) &&
          page < maxPages) {
        visited.add(currentUrl);

        final response = await _fetch(
          currentUrl,
          header: source.header,
          timeoutMs: source.respondTime,
          enabledCookieJar: source.enabledCookieJar,
        );
        if (response == null) break;

        final trimmed = response.trimLeft();
        final jsonRoot =
            (trimmed.startsWith('{') || trimmed.startsWith('['))
                ? _tryDecodeJsonValue(response)
                : null;

        String? nextUrl;

        if (jsonRoot != null && _looksLikeJsonPath(normalized.selector)) {
          final nodes = _selectJsonList(jsonRoot, normalized.selector);
          for (final node in nodes) {
            final name =
                _parseValueOnNode(node, tocRule.chapterName, currentUrl);
            var url = _parseValueOnNode(node, tocRule.chapterUrl, currentUrl);
            if (url.isNotEmpty && !url.startsWith('http')) {
              url = _absoluteUrl(currentUrl, url);
            }
            if (name.isEmpty || url.isEmpty) continue;
            chapters.add(TocItem(index: chapters.length, name: name, url: url));
          }

          if (tocRule.nextTocUrl != null &&
              tocRule.nextTocUrl!.trim().isNotEmpty) {
            nextUrl =
                _parseValueOnNode(jsonRoot, tocRule.nextTocUrl, currentUrl);
          }
        } else {
          final document = html_parser.parse(response);
          final root = document.documentElement;
          if (root == null) break;

          final chapterElements =
              _selectAllElementsByRule(document, normalized.selector);

          for (final element in chapterElements) {
            final name = _parseRule(element, tocRule.chapterName, currentUrl);
            var url = _parseRule(element, tocRule.chapterUrl, currentUrl);
            if (url.isNotEmpty && !url.startsWith('http')) {
              url = _absoluteUrl(currentUrl, url);
            }
            if (name.isEmpty || url.isEmpty) continue;
            chapters.add(TocItem(index: chapters.length, name: name, url: url));
          }

          if (tocRule.nextTocUrl != null &&
              tocRule.nextTocUrl!.trim().isNotEmpty) {
            nextUrl = _parseRule(root, tocRule.nextTocUrl, currentUrl);
          }
        }

        if (nextUrl == null || nextUrl.trim().isEmpty) break;
        var resolved = nextUrl.trim();
        if (!resolved.startsWith('http')) {
          resolved = _absoluteUrl(currentUrl, resolved);
        }
        if (resolved == currentUrl) break;
        currentUrl = resolved;
        page++;
      }

      final out = normalized.reverse
          ? chapters.reversed.toList(growable: false)
          : chapters;
      return out;
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
      final normalized = _normalizeListRule(tocRule.chapterList);
      final chapters = <TocItem>[];
      Map<String, String> sample = const {};
      var listCount = 0;

      final body = fetch.body!;
      final trimmed = body.trimLeft();
      final jsonRoot = (trimmed.startsWith('{') || trimmed.startsWith('['))
          ? _tryDecodeJsonValue(body)
          : null;

      if (jsonRoot != null && _looksLikeJsonPath(normalized.selector)) {
        final nodes = _selectJsonList(jsonRoot, normalized.selector);
        listCount = nodes.length;
        for (final node in nodes) {
          final name =
              _parseValueOnNode(node, tocRule.chapterName, fullUrl);
          var url = _parseValueOnNode(node, tocRule.chapterUrl, fullUrl);
          if (url.isNotEmpty && !url.startsWith('http')) {
            url = _absoluteUrl(fullUrl, url);
          }
          if (chapters.isEmpty) {
            sample = <String, String>{'name': name, 'url': url};
          }
          if (name.isNotEmpty && url.isNotEmpty) {
            chapters.add(TocItem(index: chapters.length, name: name, url: url));
          }
        }
        if (tocRule.nextTocUrl != null && tocRule.nextTocUrl!.trim().isNotEmpty) {
          final next = _parseValueOnNode(jsonRoot, tocRule.nextTocUrl, fullUrl);
          if (next.trim().isNotEmpty) {
            sample = <String, String>{...sample, 'nextTocUrl': next};
          }
        }
      } else {
        final document = html_parser.parse(body);
        final chapterElements =
            _selectAllElementsByRule(document, normalized.selector);
        listCount = chapterElements.length;

        for (var i = 0; i < chapterElements.length; i++) {
          final element = chapterElements[i];
          final name = _parseRule(element, tocRule.chapterName, fullUrl);
          var url = _parseRule(element, tocRule.chapterUrl, fullUrl);
          if (url.isNotEmpty && !url.startsWith('http')) {
            url = _absoluteUrl(fullUrl, url);
          }
          if (chapters.isEmpty) {
            sample = <String, String>{'name': name, 'url': url};
          }
          if (name.isNotEmpty && url.isNotEmpty) {
            chapters.add(TocItem(index: chapters.length, name: name, url: url));
          }
        }

        if (tocRule.nextTocUrl != null && tocRule.nextTocUrl!.trim().isNotEmpty) {
          final root = document.documentElement;
          if (root != null) {
            final next = _parseRule(root, tocRule.nextTocUrl, fullUrl);
            if (next.trim().isNotEmpty) {
              sample = <String, String>{...sample, 'nextTocUrl': next};
            }
          }
        }
      }

      return TocDebugResult(
        fetch: fetch,
        requestType: DebugRequestType.toc,
        requestUrlRule: tocUrl,
        listRule: normalized.selector,
        listCount: listCount,
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
      final visited = <String>{};
      var currentUrl = _absoluteUrl(source.bookSourceUrl, chapterUrl);
      var page = 0;
      const maxPages = 8;

      final parts = <String>[];

      while (currentUrl.trim().isNotEmpty &&
          !visited.contains(currentUrl) &&
          page < maxPages) {
        visited.add(currentUrl);

        final response = await _fetch(
          currentUrl,
          header: source.header,
          timeoutMs: source.respondTime,
          enabledCookieJar: source.enabledCookieJar,
        );
        if (response == null) break;

        final trimmed = response.trimLeft();
        final jsonRoot =
            (trimmed.startsWith('{') || trimmed.startsWith('['))
                ? _tryDecodeJsonValue(response)
                : null;

        String extracted;
        String? nextUrl;

        if (jsonRoot != null && contentRule.content != null && _looksLikeJsonPath(contentRule.content!)) {
          extracted = _parseValueOnNode(jsonRoot, contentRule.content, currentUrl);
          if (contentRule.nextContentUrl != null &&
              contentRule.nextContentUrl!.trim().isNotEmpty) {
            nextUrl = _parseValueOnNode(
              jsonRoot,
              contentRule.nextContentUrl,
              currentUrl,
            );
          }
        } else {
          final document = html_parser.parse(response);
          final root = document.documentElement;
          if (root == null) break;
          if (contentRule.content == null || contentRule.content!.trim().isEmpty) {
            extracted = root.text;
          } else {
            extracted = _parseRule(root, contentRule.content, currentUrl);
          }
          if (contentRule.nextContentUrl != null &&
              contentRule.nextContentUrl!.trim().isNotEmpty) {
            nextUrl = _parseRule(root, contentRule.nextContentUrl, currentUrl);
          }
        }

        var processed = extracted;
        if (contentRule.replaceRegex != null &&
            contentRule.replaceRegex!.trim().isNotEmpty) {
          processed = _applyReplaceRegex(processed, contentRule.replaceRegex!);
        }
        final cleaned = _cleanContent(processed);
        if (cleaned.trim().isNotEmpty) parts.add(cleaned);

        if (nextUrl == null || nextUrl.trim().isEmpty) break;
        var resolved = nextUrl.trim();
        if (!resolved.startsWith('http')) {
          resolved = _absoluteUrl(currentUrl, resolved);
        }
        if (resolved == currentUrl) break;
        currentUrl = resolved;
        page++;
      }

      return parts.join('\n');
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
      final visited = <String>{};
      var currentUrl = fullUrl;
      var page = 0;
      const maxPages = 8;

      var totalExtracted = 0;
      final parts = <String>[];

      while (currentUrl.trim().isNotEmpty &&
          !visited.contains(currentUrl) &&
          page < maxPages) {
        visited.add(currentUrl);

        // 第一页用 fetch（含请求/响应调试信息），后续页用普通请求即可
        final body = (currentUrl == fullUrl) ? fetch.body! : await _fetch(
              currentUrl,
              header: source.header,
              timeoutMs: source.respondTime,
              enabledCookieJar: source.enabledCookieJar,
            );
        if (body == null) break;

        final trimmed = body.trimLeft();
        final jsonRoot = (trimmed.startsWith('{') || trimmed.startsWith('['))
            ? _tryDecodeJsonValue(body)
            : null;

        String extracted;
        String? nextUrl;

        if (jsonRoot != null &&
            contentRule.content != null &&
            _looksLikeJsonPath(contentRule.content!)) {
          extracted =
              _parseValueOnNode(jsonRoot, contentRule.content, currentUrl);
          if (contentRule.nextContentUrl != null &&
              contentRule.nextContentUrl!.trim().isNotEmpty) {
            nextUrl = _parseValueOnNode(
              jsonRoot,
              contentRule.nextContentUrl,
              currentUrl,
            );
          }
        } else {
          final document = html_parser.parse(body);
          final root = document.documentElement;
          if (root == null) break;
          if (contentRule.content == null || contentRule.content!.trim().isEmpty) {
            extracted = root.text;
          } else {
            extracted = _parseRule(root, contentRule.content, currentUrl);
          }
          if (contentRule.nextContentUrl != null &&
              contentRule.nextContentUrl!.trim().isNotEmpty) {
            nextUrl = _parseRule(root, contentRule.nextContentUrl, currentUrl);
          }
        }

        totalExtracted += extracted.length;

        var text = extracted;
        if (contentRule.replaceRegex != null &&
            contentRule.replaceRegex!.isNotEmpty) {
          text = _applyReplaceRegex(text, contentRule.replaceRegex!);
        }
        final cleaned = _cleanContent(text);
        if (cleaned.trim().isNotEmpty) parts.add(cleaned);

        if (nextUrl == null || nextUrl.trim().isEmpty) break;
        var resolved = nextUrl.trim();
        if (!resolved.startsWith('http')) {
          resolved = _absoluteUrl(currentUrl, resolved);
        }
        if (resolved == currentUrl) break;
        currentUrl = resolved;
        page++;
      }

      final cleanedAll = parts.join('\n');

      return ContentDebugResult(
        fetch: fetch,
        requestType: DebugRequestType.content,
        requestUrlRule: chapterUrl,
        extractedLength: totalExtracted,
        cleanedLength: cleanedAll.length,
        content: cleanedAll,
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
      final parsedHeaders = _parseRequestHeaders(header);
      final parsedUrl = _parseLegadoStyleUrl(url);

      // URL option headers 覆盖书源 headers
      final mergedCustomHeaders = <String, String>{}
        ..addAll(parsedHeaders.headers)
        ..addAll(parsedUrl.option?.headers ?? const <String, String>{});

      // URL option js 允许二次修改 url/header
      var finalUrl = parsedUrl.url;
      if (parsedUrl.option?.js != null && parsedUrl.option!.js!.trim().isNotEmpty) {
        final patched = _applyLegadoUrlOptionJs(
          js: parsedUrl.option!.js!.trim(),
          url: finalUrl,
          headerMap: mergedCustomHeaders,
        );
        if (patched != null) {
          finalUrl = patched.url;
          mergedCustomHeaders
            ..clear()
            ..addAll(patched.headers);
        }
      }

      final requestHeaders = _buildEffectiveRequestHeaders(
        finalUrl,
        customHeaders: mergedCustomHeaders,
      );

      final method = (parsedUrl.option?.method ?? 'GET').trim().toUpperCase();
      final body = parsedUrl.option?.body;

      if ((method == 'POST' || method == 'PUT' || method == 'PATCH') &&
          body != null &&
          body.isNotEmpty &&
          !requestHeaders.keys.any((k) => k.toLowerCase() == 'content-type')) {
        requestHeaders['Content-Type'] =
            'application/x-www-form-urlencoded; charset=UTF-8';
      }

      final timeout = (timeoutMs != null && timeoutMs > 0)
          ? Duration(milliseconds: timeoutMs)
          : null;

      final opts = Options(
        method: method,
        connectTimeout: timeout,
        sendTimeout: timeout,
        receiveTimeout: timeout,
        responseType: ResponseType.bytes,
        validateStatus: (_) => true,
        headers: requestHeaders,
      );

      final dio = _selectDio(enabledCookieJar: enabledCookieJar);
      final resp = await dio.request<List<int>>(
        finalUrl,
        data: (method == 'POST' || method == 'PUT' || method == 'PATCH')
            ? (body ?? '')
            : null,
        options: opts,
      );
      final bytes = Uint8List.fromList(resp.data ?? const <int>[]);
      final respHeaders =
          resp.headers.map.map((k, v) => MapEntry(k, v.join(', ')));
      final decoded = _decodeResponseBytes(
        bytes: bytes,
        responseHeaders: respHeaders,
        optionCharset: parsedUrl.option?.charset,
      );
      return decoded.text;
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
    final parsedUrl = _parseLegadoStyleUrl(url);

    final mergedCustomHeaders = <String, String>{}
      ..addAll(parsedHeaders.headers)
      ..addAll(parsedUrl.option?.headers ?? const <String, String>{});

    var finalUrl = parsedUrl.url;
    _UrlJsPatchResult? urlJsPatch;
    if (parsedUrl.option?.js != null && parsedUrl.option!.js!.trim().isNotEmpty) {
      urlJsPatch = _applyLegadoUrlOptionJs(
        js: parsedUrl.option!.js!.trim(),
        url: finalUrl,
        headerMap: mergedCustomHeaders,
      );
      if (urlJsPatch != null) {
        finalUrl = urlJsPatch.url;
        mergedCustomHeaders
          ..clear()
          ..addAll(urlJsPatch.headers);
      }
    }

    final requestHeaders = _buildEffectiveRequestHeaders(
      finalUrl,
      customHeaders: mergedCustomHeaders,
    );
    final forLog = Map<String, String>.from(requestHeaders);
    final cookieJarOn = enabledCookieJar ?? true;
    if (cookieJarOn) {
      try {
        final cookies = await RuleParserEngine.loadCookiesForUrl(finalUrl);
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
      final method = (parsedUrl.option?.method ?? 'GET').trim().toUpperCase();
      final body = parsedUrl.option?.body;

      // 若需要 body 且未指定 content-type，按 legado 默认补 urlencoded
      if ((method == 'POST' || method == 'PUT' || method == 'PATCH') &&
          body != null &&
          body.isNotEmpty &&
          !requestHeaders.keys.any((k) => k.toLowerCase() == 'content-type')) {
        requestHeaders['Content-Type'] =
            'application/x-www-form-urlencoded; charset=UTF-8';
        forLog['Content-Type'] = requestHeaders['Content-Type']!;
      }

      final timeout = (timeoutMs != null && timeoutMs > 0)
          ? Duration(milliseconds: timeoutMs)
          : null;
      final options = Options(
        method: method,
        connectTimeout: timeout,
        sendTimeout: timeout,
        receiveTimeout: timeout,
        validateStatus: (_) => true,
        responseType: ResponseType.bytes,
        headers: requestHeaders,
      );

      final response = await _selectDio(enabledCookieJar: enabledCookieJar)
          .request<List<int>>(
        finalUrl,
        data: (method == 'POST' || method == 'PUT' || method == 'PATCH')
            ? (body ?? '')
            : null,
        options: options,
      );
      final respHeaders = response.headers.map.map(
        (k, v) => MapEntry(k, v.join(', ')),
      );
      final bytes = Uint8List.fromList(response.data ?? const <int>[]);
      final decoded = _decodeResponseBytes(
        bytes: bytes,
        responseHeaders: respHeaders,
        optionCharset: parsedUrl.option?.charset,
      );
      sw.stop();
      return FetchDebugResult(
        requestUrl: parsedUrl.url,
        finalUrl: response.realUri.toString(),
        statusCode: response.statusCode,
        elapsedMs: sw.elapsedMilliseconds,
        method: method,
        requestBodySnippet: _snippet(body),
        responseCharset: decoded.charset,
        responseLength: decoded.text.length,
        responseSnippet: _snippet(decoded.text),
        requestHeaders: forLog,
        headersWarning: parsedHeaders.warning,
        responseHeaders: respHeaders,
        error: urlJsPatch?.error,
        body: decoded.text,
      );
    } catch (e) {
      sw.stop();
      if (e is DioException) {
        final response = e.response;
        String? bodyText;
        final statusCode = response?.statusCode;
        final finalUrl = response?.realUri.toString();
        final respHeaders = response?.headers.map.map(
              (k, v) => MapEntry(k, v.join(', ')),
            ) ??
            const <String, String>{};
        if (response?.data is List<int>) {
          final decoded = _decodeResponseBytes(
            bytes: Uint8List.fromList(response?.data ?? const <int>[]),
            responseHeaders: respHeaders,
            optionCharset: parsedUrl.option?.charset,
          );
          bodyText = decoded.text;
        } else {
          bodyText = response?.data?.toString();
        }
        final parts = <String>[
          'DioException(${e.type})',
          if (parsedHeaders.warning != null) 'header警告=${parsedHeaders.warning}',
          if (e.message != null && e.message!.trim().isNotEmpty) e.message!.trim(),
          if (e.error != null) 'error=${e.error}',
        ];
        return FetchDebugResult(
          requestUrl: parsedUrl.url,
          finalUrl: finalUrl,
          statusCode: statusCode,
          elapsedMs: sw.elapsedMilliseconds,
          method: (parsedUrl.option?.method ?? 'GET').trim().toUpperCase(),
          requestBodySnippet: _snippet(parsedUrl.option?.body),
          responseCharset: null,
          responseLength: bodyText?.length ?? 0,
          responseSnippet: _snippet(bodyText),
          requestHeaders: forLog,
          headersWarning: parsedHeaders.warning,
          responseHeaders: respHeaders,
          error: parts.join('：'),
          body: bodyText,
        );
      }
      return FetchDebugResult(
        requestUrl: parsedUrl.url,
        finalUrl: null,
        statusCode: null,
        elapsedMs: sw.elapsedMilliseconds,
        method: (parsedUrl.option?.method ?? 'GET').trim().toUpperCase(),
        requestBodySnippet: _snippet(parsedUrl.option?.body),
        responseCharset: null,
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
    try {
      final base = Uri.parse(baseUrl);
      return base.resolve(url).toString();
    } catch (_) {
      if (url.startsWith('/')) {
        final uri = Uri.tryParse(baseUrl);
        if (uri != null && uri.scheme.isNotEmpty && uri.host.isNotEmpty) {
          return '${uri.scheme}://${uri.host}$url';
        }
      }
      final trimmedBase = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
      final trimmedUrl = url.startsWith('/') ? url.substring(1) : url;
      return '$trimmedBase/$trimmedUrl';
    }
  }

  bool _looksLikeXPath(String rule) {
    final t = rule.trimLeft();
    return t.startsWith('@XPath:') || t.startsWith('//');
  }

  bool _looksLikeJsonPath(String rule) {
    final t = rule.trimLeft();
    return t.startsWith('@Json:') ||
        t == r'$' ||
        t.startsWith(r'$.') ||
        t.startsWith(r'$[') ||
        t.startsWith(r'$..');
  }

  bool _looksLikeRegexRule(String rule) {
    final t = rule.trimLeft();
    return t.startsWith(':');
  }

  ({String expr, List<_LegadoReplacePair> replacements}) _splitExprAndReplacements(
    String raw,
  ) {
    final parts = raw.split('##');
    final expr = parts.first.trim();
    final reps = <_LegadoReplacePair>[];
    if (parts.length > 1) {
      final rep = parts.sublist(1);
      for (var i = 0; i < rep.length; i += 2) {
        final pattern = rep[i].trim();
        final replacement = (i + 1) < rep.length ? rep[i + 1] : '';
        if (pattern.isEmpty) continue;
        reps.add(_LegadoReplacePair(pattern: pattern, replacement: replacement));
      }
    }
    return (expr: expr, replacements: reps);
  }

  String _parseXPathRule(Element element, String raw, String baseUrl) {
    final split = _splitExprAndReplacements(raw);
    var expr = split.expr;
    if (expr.startsWith('@XPath:')) {
      expr = expr.substring('@XPath:'.length).trim();
    }
    if (expr.isEmpty) return '';

    try {
      final result = HtmlXPath.node(element).query(expr);
      var text = result.attr ??
          (result.node?.text ?? (result.node?.toString() ?? ''));
      text = _applyInlineReplacements(text, split.replacements);
      return text.trim();
    } catch (e) {
      debugPrint('XPath 解析失败: $expr - $e');
      return '';
    }
  }

  String _parseJsonPathRule(dynamic json, String raw) {
    final split = _splitExprAndReplacements(raw);
    var expr = split.expr;
    if (expr.startsWith('@Json:')) {
      expr = expr.substring('@Json:'.length).trim();
    }
    if (expr.isEmpty) return '';

    dynamic value;
    try {
      final matches = JsonPath(expr).read(json).toList(growable: false);
      if (matches.isEmpty) return '';
      value = matches.first.value;
    } catch (e) {
      // 兼容少量源写法：直接给 key（不带 $.）
      if (json is Map && json.containsKey(expr)) {
        value = json[expr];
      } else {
        debugPrint('JsonPath 解析失败: $expr - $e');
        return '';
      }
    }

    String text;
    if (value == null) {
      text = '';
    } else if (value is String) {
      text = value;
    } else if (value is num || value is bool) {
      text = value.toString();
    } else {
      try {
        text = jsonEncode(value);
      } catch (_) {
        text = value.toString();
      }
    }
    text = _applyInlineReplacements(text, split.replacements);
    return text.trim();
  }

  dynamic _tryDecodeJsonValue(String text) {
    final t = text.trim();
    if (t.isEmpty) return null;
    try {
      return jsonDecode(t);
    } catch (_) {
      return null;
    }
  }

  String _parseValueOnNode(dynamic node, String? rule, String baseUrl) {
    if (rule == null || rule.trim().isEmpty) return '';
    if (node is Element) {
      return _parseRule(node, rule, baseUrl);
    }
    // JSON 节点：支持 @Json / $. / 简单 key
    final trimmed = rule.trim();
    // 处理多个规则（用 || 分隔，表示备选）
    for (final r in trimmed.split('||')) {
      final one = r.trim();
      if (one.isEmpty) continue;
      if (_looksLikeJsonPath(one)) {
        final v = _parseJsonPathRule(node, one);
        if (v.isNotEmpty) return v;
      } else if (node is Map && node.containsKey(one)) {
        final v = node[one];
        if (v == null) continue;
        final s = v.toString().trim();
        if (s.isNotEmpty) return s;
      }
    }
    return '';
  }

  List<dynamic> _selectJsonList(dynamic json, String rawRule) {
    final split = _splitExprAndReplacements(rawRule);
    var expr = split.expr.trim();
    if (expr.startsWith('@Json:')) {
      expr = expr.substring('@Json:'.length).trim();
    }
    if (expr.isEmpty) return const <dynamic>[];

    try {
      final matches = JsonPath(expr).read(json).toList(growable: false);
      if (matches.isEmpty) return const <dynamic>[];
      // 如果命中的是数组节点，优先展开成 item 列表
      final first = matches.first.value;
      if (first is List) return first;
      // 否则返回每个 match 的 value
      return matches.map((m) => m.value).toList(growable: false);
    } catch (e) {
      debugPrint('JsonPath 列表解析失败: $expr - $e');
      return const <dynamic>[];
    }
  }

  String _parseRegexRuleOnText(String text, String raw) {
    final split = _splitExprAndReplacements(raw);
    var expr = split.expr.trimLeft();
    if (!expr.startsWith(':')) return '';
    expr = expr.substring(1).trim();
    if (expr.isEmpty) return '';

    try {
      final re = RegExp(expr, dotAll: true, multiLine: true);
      final m = re.firstMatch(text);
      if (m == null) return '';
      final v = (m.groupCount >= 1 ? m.group(1) : m.group(0)) ?? '';
      final out = _applyInlineReplacements(v, split.replacements);
      return out.trim();
    } catch (e) {
      debugPrint('Regex 解析失败: $expr - $e');
      return '';
    }
  }

  /// 解析规则
  String _parseRule(Element element, String? rule, String baseUrl) {
    if (rule == null || rule.isEmpty) return '';

    String result = '';

    // 处理多个规则（用 || 分隔，表示备选）
    final rules = rule.split('||');
    for (final r in rules) {
      final trimmed = r.trim();
      if (trimmed.isEmpty) continue;
      if (_looksLikeXPath(trimmed)) {
        result = _parseXPathRule(element, trimmed, baseUrl);
      } else if (_looksLikeRegexRule(trimmed)) {
        result = _parseRegexRuleOnText(element.outerHtml, trimmed);
      } else {
        result = _parseSingleRule(element, trimmed, baseUrl);
      }
      if (result.isNotEmpty) break;
    }

    return result.trim();
  }

  static const Set<String> _specialExtractors = {
    'text',
    'textnodes',
    'owntext',
    'html',
    'innerhtml',
    'outerhtml',
  };

  static const Set<String> _commonAttrExtractors = {
    'href',
    'src',
    'title',
    'alt',
    'value',
    'content',
    'data-src',
    'data-original',
    'data-url',
  };

  bool _looksLikeCssSelector(String token) {
    // 命中常见 selector 结构（伪类/组合器/属性选择器等）
    return token.contains(RegExp(r'[ #.:\[\]\(\)>+~*,]')) ||
        token.startsWith('.') ||
        token.startsWith('#') ||
        token.startsWith('class.') ||
        token.startsWith('id.') ||
        token.startsWith('tag.') ||
        token.startsWith('css.');
  }

  bool _isExtractorToken(String token) {
    final t = token.trim();
    if (t.isEmpty) return false;
    // 像 selector 的一律不当 extractor（例如 li:not(...)）
    if (_looksLikeCssSelector(t)) return false;
    final lower = t.toLowerCase();
    if (_specialExtractors.contains(lower)) return true;
    if (_commonAttrExtractors.contains(lower)) return true;
    if (lower.startsWith('data-') || lower.startsWith('aria-')) return true;
    // 自定义属性一般会带连接符/下划线/命名空间（尽量别把 img/a/p 这类 tag 误判为属性）
    if (t.contains('-') || t.contains('_') || t.contains(':')) return true;
    return false;
  }

  /// 解析单个规则（对标 Legado 规则链：selector@selector@index@attr@text + ##replace）
  String _parseSingleRule(Element element, String rule, String baseUrl) {
    if (rule.isEmpty) return '';

    final parsed = _LegadoTextRule.parse(
      rule,
      isExtractor: _isExtractorToken,
    );

    final target = parsed.selectors.isEmpty
        ? element
        : _selectFirstBySelectors(element, parsed.selectors);
    if (target == null) return '';

    var result = _extractWithFallbacks(
      target,
      parsed.extractors,
      baseUrl: baseUrl,
    );
    result = _applyInlineReplacements(result, parsed.replacements);
    return result.trim();
  }

  Element? _selectFirstBySelectors(
    dynamic parent,
    List<_LegadoSelectorStep> steps,
  ) {
    final all = _selectAllBySelectors(parent, steps);
    return all.isEmpty ? null : all.first;
  }

  List<Element> _selectAllBySelectors(
    dynamic parent,
    List<_LegadoSelectorStep> steps,
  ) {
    List<dynamic> contexts = <dynamic>[parent];

    List<Element> queryAll(dynamic ctx, String css) {
      if (css.trim().isEmpty) return const <Element>[];
      try {
        if (ctx is Document) return ctx.querySelectorAll(css);
        if (ctx is Element) return ctx.querySelectorAll(css);
      } catch (e) {
        debugPrint('选择器解析失败: $css - $e');
      }
      return const <Element>[];
    }

    for (final step in steps) {
      final css = step.cssSelector.trim();
      if (css.isEmpty) continue;

      final matched = <Element>[];
      for (final ctx in contexts) {
        matched.addAll(queryAll(ctx, css));
      }

      final idx = step.index;
      if (idx != null) {
        if (matched.isEmpty) return const <Element>[];
        var effective = idx >= 0 ? idx : matched.length + idx;
        if (effective < 0 || effective >= matched.length) {
          return const <Element>[];
        }
        contexts = <dynamic>[matched[effective]];
      } else {
        contexts = matched;
      }
    }

    return contexts.whereType<Element>().toList(growable: false);
  }

  List<Element> _selectAllElementsByRule(
    dynamic parent,
    String selectorRule, {
    String? rawHtml,
  }) {
    final raw = selectorRule.trim();
    if (raw.isEmpty) return const <Element>[];

    if (_looksLikeXPath(raw)) {
      final split = _splitExprAndReplacements(raw);
      var expr = split.expr;
      if (expr.startsWith('@XPath:')) {
        expr = expr.substring('@XPath:'.length).trim();
      }
      if (expr.isEmpty) return const <Element>[];
      try {
        final root = parent is Document
            ? parent.documentElement
            : parent is Element
                ? parent
                : null;
        if (root == null) return const <Element>[];
        final result = HtmlXPath.node(root).query(expr);
        return result.nodes
            .where((n) => n.isElement)
            .map((n) => (n as HtmlNodeTree).element)
            .toList(growable: false);
      } catch (e) {
        debugPrint('XPath 列表解析失败: $expr - $e');
        return const <Element>[];
      }
    }

    if (_looksLikeRegexRule(raw)) {
      final split = _splitExprAndReplacements(raw);
      var expr = split.expr.trimLeft();
      expr = expr.startsWith(':') ? expr.substring(1).trim() : expr;
      if (expr.isEmpty) return const <Element>[];

      final htmlText = rawHtml ??
          (parent is Document
              ? parent.documentElement?.outerHtml
              : parent is Element
                  ? parent.outerHtml
                  : null) ??
          '';
      if (htmlText.isEmpty) return const <Element>[];

      try {
        final re = RegExp(expr, dotAll: true, multiLine: true);
        final out = <Element>[];
        for (final m in re.allMatches(htmlText)) {
          final snippet =
              (m.groupCount >= 1 ? m.group(1) : m.group(0)) ?? '';
          if (snippet.trim().isEmpty) continue;
          final wrapper = html_parser
              .parse('<div>$snippet</div>')
              .documentElement
              ?.querySelector('div');
          if (wrapper != null) out.add(wrapper);
        }
        return out;
      } catch (e) {
        debugPrint('Regex 列表解析失败: $expr - $e');
        return const <Element>[];
      }
    }

    final parsed = _LegadoTextRule.parse(
      raw,
      isExtractor: _isExtractorToken,
    );
    return _selectAllBySelectors(parent, parsed.selectors);
  }

  Element? _selectFirstElementByRule(dynamic parent, String selectorRule) {
    final all = _selectAllElementsByRule(parent, selectorRule);
    return all.isEmpty ? null : all.first;
  }

  String _extractWithFallbacks(
    Element target,
    List<String> extractors, {
    required String baseUrl,
  }) {
    for (final ex in extractors) {
      final token = ex.trim();
      if (token.isEmpty) continue;
      final lower = token.toLowerCase();

      String value;
      if (lower == 'text') {
        value = target.text;
      } else if (lower == 'textnodes' || lower == 'owntext') {
        value = target.nodes.whereType<Text>().map((t) => t.text).join('');
      } else if (lower == 'html' || lower == 'innerhtml') {
        value = target.innerHtml;
      } else if (lower == 'outerhtml') {
        value = target.outerHtml;
      } else {
        value = target.attributes[token] ??
            target.attributes[lower] ??
            target.attributes[token.toLowerCase()] ??
            '';
      }

      value = value.trim();
      if (value.isEmpty) continue;

      // 常见 URL 属性：自动转绝对链接
      if (lower == 'href' || lower == 'src') {
        value = _absoluteUrl(baseUrl, value);
      }
      return value;
    }
    return '';
  }

  String _applyInlineReplacements(
    String input,
    List<_LegadoReplacePair> replacements,
  ) {
    var result = input;
    for (final r in replacements) {
      final pattern = r.pattern;
      final replacement = r.replacement;
      if (pattern.isEmpty) continue;
      try {
        result = result.replaceAll(RegExp(pattern), replacement);
      } catch (_) {
        result = result.replaceAll(pattern, replacement);
      }
    }
    return result;
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

class _LegadoTextRule {
  final List<_LegadoSelectorStep> selectors;
  final List<String> extractors;
  final List<_LegadoReplacePair> replacements;

  const _LegadoTextRule({
    required this.selectors,
    required this.extractors,
    required this.replacements,
  });

  static _LegadoTextRule parse(
    String raw, {
    required bool Function(String token) isExtractor,
  }) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return const _LegadoTextRule(
        selectors: <_LegadoSelectorStep>[],
        extractors: <String>['text'],
        replacements: <_LegadoReplacePair>[],
      );
    }

    final parts = trimmed.split('##');
    final pipeline = parts.first.trim();

    final replacements = <_LegadoReplacePair>[];
    if (parts.length > 1) {
      final rep = parts.sublist(1).map((e) => e).toList(growable: false);
      for (var i = 0; i < rep.length; i += 2) {
        final pattern = rep[i].trim();
        final replacement = (i + 1) < rep.length ? rep[i + 1] : '';
        if (pattern.isEmpty) continue;
        replacements.add(
          _LegadoReplacePair(pattern: pattern, replacement: replacement),
        );
      }
    }

    final tokens = pipeline
        .split('@')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList(growable: false);

    // 从末尾识别 extractor（对标 legado：h1@title@text 表示 title 为空则取 text）
    final startsWithAt = pipeline.startsWith('@');
    var cut = tokens.length;
    final extractors = <String>[];
    if (startsWithAt) {
      // 兼容 legado 写法：@href / @textNodes 等表示“当前元素取属性/文本”
      for (final t in tokens) {
        if (isExtractor(t)) extractors.add(t);
      }
      cut = 0;
    } else if (tokens.length >= 2) {
      while (cut > 0) {
        final candidate = tokens[cut - 1];
        if (!isExtractor(candidate)) break;
        extractors.insert(0, candidate);
        cut--;
      }
    }

    final selectors = <_LegadoSelectorStep>[];
    for (final t in tokens.take(cut)) {
      final step = _LegadoSelectorStep.tryParse(t);
      if (step != null) selectors.add(step);
    }

    return _LegadoTextRule(
      selectors: selectors,
      extractors: extractors.isEmpty ? const <String>['text'] : extractors,
      replacements: replacements,
    );
  }
}

class _LegadoSelectorStep {
  final String cssSelector;
  final int? index;

  const _LegadoSelectorStep({
    required this.cssSelector,
    required this.index,
  });

  static _LegadoSelectorStep? tryParse(String token) {
    final t = token.trim();
    if (t.isEmpty) return null;

    int? index;
    var base = t;
    final lastDot = t.lastIndexOf('.');
    if (lastDot > 0 && lastDot < t.length - 1) {
      final maybeIndex = t.substring(lastDot + 1);
      final parsed = int.tryParse(maybeIndex);
      if (parsed != null) {
        index = parsed;
        base = t.substring(0, lastDot);
      }
    }

    final css = _toCssSelector(base);
    if (css.trim().isEmpty) return null;
    return _LegadoSelectorStep(cssSelector: css, index: index);
  }

  static String _toCssSelector(String raw) {
    final t = raw.trim();
    if (t.startsWith('class.')) {
      return '.${t.substring('class.'.length)}';
    }
    if (t.startsWith('id.')) {
      return '#${t.substring('id.'.length)}';
    }
    if (t.startsWith('tag.')) {
      return t.substring('tag.'.length);
    }
    if (t.startsWith('css.')) {
      return t.substring('css.'.length);
    }
    return t;
  }
}

class _LegadoReplacePair {
  final String pattern;
  final String replacement;

  const _LegadoReplacePair({
    required this.pattern,
    required this.replacement,
  });
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
  final String method;
  final String? requestBodySnippet;
  final String? responseCharset;
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
    this.method = 'GET',
    this.requestBodySnippet,
    this.responseCharset,
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
      method: 'GET',
      requestBodySnippet: null,
      responseCharset: null,
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

class _LegadoUrlParsed {
  final String url;
  final _LegadoUrlOption? option;

  const _LegadoUrlParsed({
    required this.url,
    required this.option,
  });
}

class _LegadoUrlOption {
  final String? method;
  final String? body;
  final String? charset;
  final Map<String, String> headers;
  final String? js;

  const _LegadoUrlOption({
    required this.method,
    required this.body,
    required this.charset,
    required this.headers,
    required this.js,
  });

  factory _LegadoUrlOption.fromJson(Map<String, dynamic> json) {
    String? getString(String key) {
      final v = json[key];
      if (v == null) return null;
      final t = v.toString().trim();
      return t.isEmpty ? null : t;
    }

    final headers = <String, String>{};
    final h = json['headers'];
    if (h is Map) {
      h.forEach((k, v) {
        if (k == null || v == null) return;
        headers[k.toString()] = v.toString();
      });
    }

    return _LegadoUrlOption(
      method: getString('method'),
      body: getString('body'),
      charset: getString('charset'),
      headers: headers,
      js: getString('js'),
    );
  }
}

class _UrlJsPatchResult {
  final bool ok;
  final String url;
  final Map<String, String> headers;
  final String? error;

  const _UrlJsPatchResult({
    required this.ok,
    required this.url,
    required this.headers,
    required this.error,
  });
}

class _DecodedText {
  final String text;
  final String charset;

  const _DecodedText({
    required this.text,
    required this.charset,
  });
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
