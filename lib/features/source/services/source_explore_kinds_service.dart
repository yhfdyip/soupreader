import 'dart:convert';

import '../../../core/database/database_service.dart';
import '../../../core/services/js_runtime.dart';
import '../models/book_source.dart';

class SourceExploreKind {
  final String title;
  final String? url;
  final SourceExploreKindStyle? style;

  const SourceExploreKind({
    required this.title,
    required this.url,
    this.style,
  });
}

class SourceExploreKindStyle {
  final double layoutFlexGrow;
  final double layoutFlexShrink;
  final String layoutAlignSelf;
  final double layoutFlexBasisPercent;
  final bool layoutWrapBefore;

  const SourceExploreKindStyle({
    this.layoutFlexGrow = 0,
    this.layoutFlexShrink = 1,
    this.layoutAlignSelf = 'auto',
    this.layoutFlexBasisPercent = -1,
    this.layoutWrapBefore = false,
  });

  bool get isDefault {
    return layoutFlexGrow == 0 &&
        layoutFlexShrink == 1 &&
        layoutAlignSelf.toLowerCase() == 'auto' &&
        layoutFlexBasisPercent < 0 &&
        layoutWrapBefore == false;
  }
}

/// 发现分类解析与缓存：
/// - 支持 `exploreUrl` 普通文本 / JSON 数组 / `@js:` / `<js>`
/// - `@js:` 与 `<js>` 结果持久化缓存（以 sourceUrl+exploreUrl 为键）
/// - `clearExploreKindsCache` 语义：清理持久化 + 内存缓存
class SourceExploreKindsService {
  static const String _cachePrefix = 'source_explore_kinds_cache_v1_';

  final DatabaseService _db;
  final JsRuntime _runtime;
  final Map<String, List<SourceExploreKind>> _memoryCache =
      <String, List<SourceExploreKind>>{};

  SourceExploreKindsService({
    DatabaseService? databaseService,
    JsRuntime? runtime,
  })  : _db = databaseService ?? DatabaseService(),
        _runtime = runtime ?? createJsRuntime();

  Future<List<SourceExploreKind>> exploreKinds(
    BookSource source, {
    bool forceRefresh = false,
  }) async {
    final exploreUrl = (source.exploreUrl ?? '').trim();
    if (exploreUrl.isEmpty) {
      return const <SourceExploreKind>[];
    }

    final key = _buildCacheKey(source.bookSourceUrl, exploreUrl);
    if (!forceRefresh) {
      final cached = _memoryCache[key];
      if (cached != null) {
        return cached;
      }
    } else {
      _memoryCache.remove(key);
    }

    try {
      var ruleText = exploreUrl;
      if (_isJsRule(ruleText)) {
        final cachedRule = _getCachedJsResult(key);
        if (cachedRule != null && cachedRule.trim().isNotEmpty) {
          ruleText = cachedRule.trim();
        } else {
          final jsCode = _extractJsCode(ruleText);
          if (jsCode.isNotEmpty) {
            final evaluated = _evaluateJs(
              jsCode,
              jsLib: source.jsLib,
            ).trim();
            if (evaluated.isNotEmpty) {
              ruleText = evaluated;
              _saveCachedJsResult(key, evaluated);
            }
          }
        }
      }

      final parsed = _parseKinds(ruleText);
      _memoryCache[key] = parsed;
      return parsed;
    } catch (e, stack) {
      final msg = e.toString().trim();
      final kinds = <SourceExploreKind>[
        SourceExploreKind(
          title: 'ERROR:${msg.isEmpty ? '解析失败' : msg}',
          url: '$e\n$stack',
        ),
      ];
      _memoryCache[key] = kinds;
      return kinds;
    }
  }

  Future<void> clearExploreKindsCache(BookSource source) async {
    final exploreUrl = (source.exploreUrl ?? '').trim();
    if (exploreUrl.isEmpty) return;
    final key = _buildCacheKey(source.bookSourceUrl, exploreUrl);
    _memoryCache.remove(key);
    await _safeDeleteSetting(_cacheStoreKey(key));
  }

  bool _isJsRule(String text) {
    final lower = text.toLowerCase();
    return lower.startsWith('@js:') || lower.startsWith('<js>');
  }

  String _extractJsCode(String text) {
    final raw = text.trim();
    final lower = raw.toLowerCase();
    if (lower.startsWith('@js:')) {
      return raw.substring(4).trim();
    }
    if (!lower.startsWith('<js>')) return '';

    final closeIndex = lower.lastIndexOf('</js>');
    if (closeIndex > 4) {
      return raw.substring(4, closeIndex).trim();
    }
    final lastTag = raw.lastIndexOf('<');
    if (lastTag > 4) {
      return raw.substring(4, lastTag).trim();
    }
    return raw.substring(4).trim();
  }

  String _evaluateJs(String jsCode, {String? jsLib}) {
    final safeJs = jsonEncode(jsCode);
    final lib = (jsLib ?? '').trim();
    final safeLib = lib.isEmpty ? '' : '$lib\n';
    final script = '''
      (function(){
        try {
          $safeLib
          var __res = eval($safeJs);
          if (__res === undefined || __res === null) return '';
          if (typeof __res === 'string') return __res;
          try { return JSON.stringify(__res); } catch(e) { return String(__res); }
        } catch(e) {
          try { return String(e && (e.stack || e.message || e)); } catch(_e) { return ''; }
        }
      })()
    ''';
    final output = _runtime.evaluate(script).trim();
    if (output.isEmpty) return '';
    return _decodeJsonString(output);
  }

  String _decodeJsonString(String text) {
    final trimmed = text.trim();
    if (trimmed.length >= 2 &&
        trimmed.startsWith('"') &&
        trimmed.endsWith('"')) {
      try {
        final decoded = json.decode(trimmed);
        return decoded is String ? decoded : trimmed;
      } catch (_) {
        return trimmed;
      }
    }
    return trimmed;
  }

  List<SourceExploreKind> _parseKinds(String ruleText) {
    final text = ruleText.trim();
    if (text.isEmpty) return const <SourceExploreKind>[];

    if (_looksLikeJsonArray(text)) {
      final decoded = json.decode(text);
      if (decoded is List) {
        final out = <SourceExploreKind>[];
        for (final item in decoded) {
          if (item is Map) {
            final map = item.map((k, v) => MapEntry('$k', v));
            final title = (map['title'] ?? map['name'] ?? '').toString().trim();
            final urlRaw = map['url']?.toString().trim();
            final style = _parseStyle(map['style']);
            out.add(
              SourceExploreKind(
                title: title,
                url: (urlRaw == null || urlRaw.isEmpty) ? null : urlRaw,
                style: style,
              ),
            );
            continue;
          }
          final raw = item?.toString().trim() ?? '';
          if (raw.isEmpty) continue;
          out.add(SourceExploreKind(title: raw, url: null));
        }
        return out;
      }
    }

    final parts = text
        .split(RegExp(r'(?:&&|\r?\n)+'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty);
    final out = <SourceExploreKind>[];
    for (final part in parts) {
      final idx = part.indexOf('::');
      if (idx >= 0) {
        final title = part.substring(0, idx).trim();
        final url = part.substring(idx + 2).trim();
        out.add(
          SourceExploreKind(
            title: title,
            url: url.isEmpty ? null : url,
          ),
        );
      } else {
        out.add(SourceExploreKind(title: part, url: null));
      }
    }
    return out;
  }

  SourceExploreKindStyle? _parseStyle(dynamic raw) {
    if (raw is! Map) return null;
    final map = raw.map((k, v) => MapEntry('$k', v));
    final style = SourceExploreKindStyle(
      layoutFlexGrow: _parseDouble(map['layout_flexGrow'], fallback: 0),
      layoutFlexShrink: _parseDouble(map['layout_flexShrink'], fallback: 1),
      layoutAlignSelf: _parseAlignSelf(map['layout_alignSelf']),
      layoutFlexBasisPercent:
          _parseDouble(map['layout_flexBasisPercent'], fallback: -1),
      layoutWrapBefore: _parseBool(map['layout_wrapBefore'], fallback: false),
    );
    if (style.isDefault) return null;
    return style;
  }

  double _parseDouble(dynamic raw, {required double fallback}) {
    if (raw == null) return fallback;
    if (raw is num) return raw.toDouble();
    final text = raw.toString().trim();
    if (text.isEmpty) return fallback;
    return double.tryParse(text) ?? fallback;
  }

  bool _parseBool(dynamic raw, {required bool fallback}) {
    if (raw == null) return fallback;
    if (raw is bool) return raw;
    if (raw is num) return raw != 0;
    final text = raw.toString().trim().toLowerCase();
    if (text.isEmpty) return fallback;
    if (text == 'true' || text == '1' || text == 'yes') return true;
    if (text == 'false' || text == '0' || text == 'no') return false;
    return fallback;
  }

  String _parseAlignSelf(dynamic raw) {
    final text = raw?.toString().trim();
    if (text == null || text.isEmpty) return 'auto';
    return text;
  }

  bool _looksLikeJsonArray(String value) {
    final text = value.trim();
    return text.startsWith('[') && text.endsWith(']');
  }

  String? _getCachedJsResult(String key) {
    final value = _safeGetSetting(_cacheStoreKey(key));
    final text = value?.toString().trim();
    if (text == null || text.isEmpty) return null;
    return text;
  }

  void _saveCachedJsResult(String key, String value) {
    _safePutSetting(_cacheStoreKey(key), value);
  }

  String _cacheStoreKey(String key) => '$_cachePrefix$key';

  String _buildCacheKey(String sourceUrl, String exploreUrl) {
    final input = '$sourceUrl\n$exploreUrl';
    // 使用 32 位 FNV-1a，避免 Web(JS number) 下 64 位整数字面量精度问题。
    var hash = 0x811c9dc5;
    for (final unit in input.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }

  dynamic _safeGetSetting(String key) {
    try {
      return _db.getSetting(key);
    } catch (_) {
      return null;
    }
  }

  Future<void> _safePutSetting(String key, dynamic value) async {
    try {
      await _db.putSetting(key, value);
    } catch (_) {
      // ignore cache write failures
    }
  }

  Future<void> _safeDeleteSetting(String key) async {
    try {
      await _db.deleteSetting(key);
    } catch (_) {
      // ignore cache delete failures
    }
  }
}
