import 'dart:collection';
import 'dart:convert';
import 'dart:ui' show Size;

import 'reader_image_request_parser.dart';

class ReaderImageMarkerMeta {
  final String src;
  final double? width;
  final double? height;

  const ReaderImageMarkerMeta({
    required this.src,
    this.width,
    this.height,
  });

  bool get hasDimensionHints =>
      width != null && width! > 0 && height != null && height! > 0;
}

/// 阅读器图片标记编码器：
/// - 在“文本分页链路”中用可逆标记承载 `<img src="...">`；
/// - 进入渲染层后再解码为真实图片地址。
class ReaderImageMarkerCodec {
  static const String prefix = '[[[SR_IMG:';
  static const String suffix = ']]]';
  static const String textFallbackPlaceholder = '▣';

  static final RegExp _markerRegex = RegExp(
    r'\[\[\[SR_IMG:([A-Za-z0-9\-_]+=*)\]\]\]',
  );

  static final RegExp markerLineRegex = RegExp(
    r'^\s*\[\[\[SR_IMG:([A-Za-z0-9\-_]+=*)\]\]\]\s*$',
  );

  static const int _maxResolvedSizeEntries = 480;
  static final LinkedHashMap<String, Size> _resolvedSizeCache =
      LinkedHashMap<String, Size>();

  static String encode(
    String src, {
    double? width,
    double? height,
  }) {
    final normalized = src.trim();
    if (normalized.isEmpty) {
      return textFallbackPlaceholder;
    }
    final payloadMap = <String, dynamic>{
      'u': normalized,
    };
    if (_isValidPositiveDimension(width) && _isValidPositiveDimension(height)) {
      payloadMap['w'] = width!.toDouble();
      payloadMap['h'] = height!.toDouble();
    }
    final payload = base64UrlEncode(utf8.encode(jsonEncode(payloadMap)));
    return '$prefix$payload$suffix';
  }

  static ReaderImageMarkerMeta? decodeMeta(String marker) {
    final match = _markerRegex.firstMatch(marker.trim());
    if (match == null) {
      return null;
    }
    final payload = match.group(1);
    return _decodePayload(payload);
  }

  static ReaderImageMarkerMeta? decodeMetaLine(String line) {
    final match = markerLineRegex.firstMatch(line);
    if (match == null) {
      return null;
    }
    final payload = match.group(1);
    return _decodePayload(payload);
  }

  static String? decode(String marker) {
    return decodeMeta(marker)?.src;
  }

  static String? decodeLine(String line) {
    return decodeMetaLine(line)?.src;
  }

  static Size? lookupResolvedSize(String src) {
    final key = _normalizeCacheKey(src);
    if (key.isEmpty) return null;
    final cached = _resolvedSizeCache.remove(key);
    if (cached == null) return null;
    _resolvedSizeCache[key] = cached;
    return cached;
  }

  /// 返回值：是否发生变更（新增或尺寸变化）。
  static bool rememberResolvedSize(
    String src, {
    required double width,
    required double height,
  }) {
    final key = _normalizeCacheKey(src);
    if (key.isEmpty) return false;
    if (!_isValidPositiveDimension(width) ||
        !_isValidPositiveDimension(height)) {
      return false;
    }
    final next = Size(width, height);
    final prev = _resolvedSizeCache.remove(key);
    if (prev != null &&
        (prev.width - next.width).abs() < 0.5 &&
        (prev.height - next.height).abs() < 0.5) {
      // LRU 命中回插，保持最近使用顺序。
      _resolvedSizeCache[key] = prev;
      return false;
    }
    _resolvedSizeCache[key] = next;
    _trimResolvedSizeCache();
    return true;
  }

  static void clearResolvedSizeCache() {
    _resolvedSizeCache.clear();
  }

  static String normalizeResolvedSizeKey(String src) {
    return _normalizeCacheKey(src);
  }

  static Map<String, List<double>> snapshotResolvedSizeCache({
    Iterable<String>? keys,
    int maxEntries = 180,
  }) {
    final limit = maxEntries.clamp(1, _maxResolvedSizeEntries);
    final normalizedFilter = keys == null
        ? null
        : keys.map(_normalizeCacheKey).where((key) => key.isNotEmpty).toSet();

    final out = <String, List<double>>{};
    final entries = _resolvedSizeCache.entries.toList(growable: false).reversed;
    for (final entry in entries) {
      if (out.length >= limit) break;
      if (normalizedFilter != null && !normalizedFilter.contains(entry.key)) {
        continue;
      }
      out[entry.key] = <double>[entry.value.width, entry.value.height];
    }
    return out;
  }

  static int restoreResolvedSizeCache(
    Map<String, dynamic> snapshot, {
    bool clearBeforeRestore = false,
    int maxEntries = 180,
  }) {
    if (clearBeforeRestore) {
      clearResolvedSizeCache();
    }
    final limit = maxEntries.clamp(1, _maxResolvedSizeEntries);
    var restored = 0;
    for (final entry in snapshot.entries) {
      if (restored >= limit) break;
      final key = _normalizeCacheKey(entry.key);
      if (key.isEmpty) continue;
      final size = _coerceSize(entry.value);
      if (size == null) continue;
      final changed = rememberResolvedSize(
        key,
        width: size.width,
        height: size.height,
      );
      if (changed) {
        restored++;
      }
    }
    return restored;
  }

  static ReaderImageMarkerMeta? _decodePayload(String? payload) {
    if (payload == null || payload.isEmpty) {
      return null;
    }
    try {
      final decoded = utf8.decode(base64Url.decode(payload));
      final trimmed = decoded.trim();
      if (trimmed.isEmpty) return null;

      // 新格式：JSON payload {"u": "...", "w": 123, "h": 456}
      final dynamic raw = jsonDecode(trimmed);
      if (raw is Map<String, dynamic>) {
        final src = (raw['u'] ?? '').toString().trim();
        if (src.isEmpty) return null;
        final width = _coercePositiveDouble(raw['w']);
        final height = _coercePositiveDouble(raw['h']);
        return ReaderImageMarkerMeta(
          src: src,
          width: width,
          height: height,
        );
      }
    } catch (_) {
      // 兼容旧格式：payload 仅包含原始 src 文本（非 JSON）。
      try {
        final decoded = utf8.decode(base64Url.decode(payload));
        final value = decoded.trim();
        if (value.isEmpty) {
          return null;
        }
        return ReaderImageMarkerMeta(src: value);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  static bool containsMarker(String content) {
    if (content.isEmpty) {
      return false;
    }
    return _markerRegex.hasMatch(content);
  }

  static String _normalizeCacheKey(String src) {
    final request = ReaderImageRequestParser.parse(src);
    final fromRequest = request.url.trim();
    final raw = fromRequest.isNotEmpty ? fromRequest : request.raw.trim();
    if (raw.isEmpty) return '';
    if (raw.toLowerCase().startsWith('data:image')) {
      return raw;
    }
    final uri = Uri.tryParse(raw);
    if (uri == null || !uri.hasScheme) {
      return raw;
    }
    final scheme = uri.scheme.toLowerCase();
    if (scheme != 'http' && scheme != 'https') {
      return raw;
    }
    final host = uri.host.toLowerCase();
    final defaultPort = scheme == 'https' ? 443 : 80;
    final portPart =
        uri.hasPort && uri.port != defaultPort ? ':${uri.port}' : '';
    final path = uri.path.isEmpty ? '/' : uri.path;
    final query = uri.hasQuery ? '?${uri.query}' : '';
    return '$scheme://$host$portPart$path$query';
  }

  static bool _isValidPositiveDimension(double? value) {
    return value != null && value.isFinite && value > 0;
  }

  static double? _coercePositiveDouble(dynamic raw) {
    if (raw is num) {
      final value = raw.toDouble();
      return _isValidPositiveDimension(value) ? value : null;
    }
    if (raw is String) {
      final value = double.tryParse(raw.trim());
      return _isValidPositiveDimension(value) ? value : null;
    }
    return null;
  }

  static Size? _coerceSize(dynamic raw) {
    if (raw is List && raw.length >= 2) {
      final width = _coercePositiveDouble(raw[0]);
      final height = _coercePositiveDouble(raw[1]);
      if (width != null && height != null) {
        return Size(width, height);
      }
      return null;
    }
    if (raw is Map) {
      final width = _coercePositiveDouble(raw['w'] ?? raw['width']);
      final height = _coercePositiveDouble(raw['h'] ?? raw['height']);
      if (width != null && height != null) {
        return Size(width, height);
      }
      return null;
    }
    return null;
  }

  static void _trimResolvedSizeCache() {
    while (_resolvedSizeCache.length > _maxResolvedSizeEntries) {
      _resolvedSizeCache.remove(_resolvedSizeCache.keys.first);
    }
  }
}
