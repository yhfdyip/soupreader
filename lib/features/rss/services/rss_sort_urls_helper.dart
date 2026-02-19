import 'dart:convert';

import '../../../core/database/database_service.dart';
import '../../../core/services/js_runtime.dart';
import '../models/rss_source.dart';

class RssSortTab {
  final String name;
  final String url;

  const RssSortTab({
    required this.name,
    required this.url,
  });

  String get key => '$name::$url';
}

typedef RssSortCacheRead = Future<String?> Function(String key);
typedef RssSortCacheWrite = Future<void> Function(String key, String value);
typedef RssSortCacheDelete = Future<void> Function(String key);

/// RSS 分类 URL 解析（对齐 legado `RssSource.sortUrls`）
class RssSortUrlsHelper {
  const RssSortUrlsHelper._();

  static const String _cachePrefix = 'rss_sort_urls_cache:';
  static final RegExp _splitRegex = RegExp(r'(&&|\n)+');
  static const String _jsOkPrefix = '__SR_RSS_SORT_JS_OK__';
  static const String _jsErrPrefix = '__SR_RSS_SORT_JS_ERR__';

  static String buildCacheKey(RssSource source) {
    final sourceUrl = source.sourceUrl.trim();
    final sortUrl = (source.sortUrl ?? '').trim();
    return '$_cachePrefix$sourceUrl::$sortUrl';
  }

  static Future<List<RssSortTab>> resolveSortTabs(
    RssSource source, {
    JsRuntime? runtime,
    RssSortCacheRead? readCache,
    RssSortCacheWrite? writeCache,
  }) async {
    final fallbackUrl = source.sourceUrl.trim();
    if (fallbackUrl.isEmpty) {
      return const <RssSortTab>[];
    }

    final cacheKey = buildCacheKey(source);
    var raw = (source.sortUrl ?? '').trim();
    final isJsRule = _isJsRule(raw);
    if (isJsRule) {
      final cached = (await _readCache(cacheKey, readCache: readCache))?.trim();
      if (cached != null && cached.isNotEmpty) {
        raw = cached;
      } else {
        final evaluated = _evaluateSortUrlJs(
          source: source,
          jsCode: _extractJsCode(raw),
          runtime: runtime ?? createJsRuntime(),
        );
        if (evaluated != null && evaluated.isNotEmpty) {
          raw = evaluated;
          await _writeCache(
            cacheKey,
            raw,
            writeCache: writeCache,
          );
        }
      }
    }

    final tabs = _parseSortTabs(
      sourceUrl: fallbackUrl,
      rawSort: raw,
    );
    if (tabs.isNotEmpty) return tabs;
    return <RssSortTab>[
      RssSortTab(name: '', url: fallbackUrl),
    ];
  }

  static Future<void> clearSortCache(
    RssSource source, {
    RssSortCacheDelete? deleteCache,
  }) async {
    final key = buildCacheKey(source);
    await _deleteCache(key, deleteCache: deleteCache);
  }

  static List<RssSortTab> _parseSortTabs({
    required String sourceUrl,
    required String rawSort,
  }) {
    final text = rawSort.trim();
    if (text.isEmpty) {
      return const <RssSortTab>[];
    }
    final tabs = <RssSortTab>[];
    for (final block in text.split(_splitRegex)) {
      final entry = block.trim();
      if (entry.isEmpty) continue;
      final name = entry.split('::').first.trim();
      final url = _extractUrl(entry);
      if (url.isEmpty) continue;
      if (url.startsWith('{{')) {
        tabs.add(RssSortTab(name: name, url: url));
        continue;
      }
      tabs.add(
        RssSortTab(name: name, url: _absoluteUrl(sourceUrl, url)),
      );
    }
    return tabs;
  }

  static String _extractUrl(String entry) {
    final tokenIndex = entry.indexOf('::');
    if (tokenIndex < 0) return '';
    final value = entry.substring(tokenIndex + 2).trim();
    return value;
  }

  static bool _isJsRule(String text) {
    final lower = text.trim().toLowerCase();
    return lower.startsWith('@js:') || lower.startsWith('<js>');
  }

  static String _extractJsCode(String rawRule) {
    final raw = rawRule.trim();
    final lower = raw.toLowerCase();
    if (lower.startsWith('@js:')) {
      return raw.substring(4).trim();
    }
    if (!lower.startsWith('<js>')) return '';
    final closeIndex = lower.lastIndexOf('</js>');
    if (closeIndex > 4) {
      return raw.substring(4, closeIndex).trim();
    }
    final lastTagIndex = raw.lastIndexOf('<');
    if (lastTagIndex > 4) {
      return raw.substring(4, lastTagIndex).trim();
    }
    return raw.substring(4).trim();
  }

  static String? _evaluateSortUrlJs({
    required RssSource source,
    required String jsCode,
    required JsRuntime runtime,
  }) {
    if (jsCode.trim().isEmpty) return null;
    final lib = (source.jsLib ?? '').trim();
    final libScript = lib.isEmpty ? '' : '$lib\n';
    final script = '''
      (function() {
        try {
          var source = ${jsonEncode(source.toJson())};
          var java = source;
          var baseUrl = ${jsonEncode(source.sourceUrl)};
          $libScript
          var __res = eval(${jsonEncode(jsCode)});
          if (__res === undefined || __res === null) {
            return "$_jsOkPrefix";
          }
          var __text = "";
          if (typeof __res === "string") {
            __text = __res;
          } else {
            try {
              __text = JSON.stringify(__res);
            } catch (_jsonErr) {
              __text = String(__res);
            }
          }
          return "$_jsOkPrefix" + encodeURIComponent(__text);
        } catch (e) {
          var __err = "";
          try {
            __err = String(e && (e.message || e.stack || e));
          } catch (_err) {}
          return "$_jsErrPrefix" + encodeURIComponent(__err);
        }
      })()
    ''';

    final output = _decodeMaybeJsonString(runtime.evaluate(script).trim());
    if (output.isEmpty) return null;
    if (output.startsWith(_jsErrPrefix)) return null;
    if (output.startsWith(_jsOkPrefix)) {
      final encoded = output.substring(_jsOkPrefix.length);
      if (encoded.isEmpty) return null;
      return Uri.decodeComponent(encoded).trim();
    }
    return output.trim();
  }

  static Future<String?> _readCache(
    String key, {
    RssSortCacheRead? readCache,
  }) async {
    if (readCache != null) return readCache(key);
    final raw = DatabaseService().getSetting(key);
    if (raw is String) return raw;
    if (raw == null) return null;
    return raw.toString();
  }

  static Future<void> _writeCache(
    String key,
    String value, {
    RssSortCacheWrite? writeCache,
  }) async {
    if (writeCache != null) {
      await writeCache(key, value);
      return;
    }
    await DatabaseService().putSetting(key, value);
  }

  static Future<void> _deleteCache(
    String key, {
    RssSortCacheDelete? deleteCache,
  }) async {
    if (deleteCache != null) {
      await deleteCache(key);
      return;
    }
    await DatabaseService().deleteSetting(key);
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

  static String _decodeMaybeJsonString(String raw) {
    final text = raw.trim();
    if (text.length >= 2 && text.startsWith('"') && text.endsWith('"')) {
      try {
        final decoded = json.decode(text);
        if (decoded is String) return decoded;
      } catch (_) {
        return text;
      }
    }
    return text;
  }
}
