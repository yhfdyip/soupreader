import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:path/path.dart' as p;

import 'reader_image_request_parser.dart';

/// 负责解析阅读器图片地址、请求头与图片提供器。
class ReaderImageResolver {
  static const int _defaultHttpPort = 80;
  static const int _defaultHttpsPort = 443;

  /// 创建一个阅读器图片解析器。
  const ReaderImageResolver({required this.isWeb});

  /// 当前是否运行在 Web 平台。
  final bool isWeb;

  /// 规范化图片原始地址。
  String normalizeSrc(String raw) => raw.trim();

  /// 根据请求信息与请求头解析可用的图片提供器。
  ImageProvider<Object>? resolveProvider(
    ReaderImageRequest request, {
    required Map<String, String> headers,
  }) {
    final value = request.url.trim();
    if (value.isEmpty) return null;

    final inlineImage = _resolveInlineImage(value);
    if (inlineImage != null) return inlineImage;

    final uri = _tryParseHttpUri(value);
    if (uri == null) return null;
    if (headers.isEmpty) {
      return NetworkImage(value);
    }
    return NetworkImage(value, headers: headers);
  }

  /// 合成图片请求头，包括源站 header、显式 header、Cookie 与 Referer。
  Map<String, String> composeHeaders({
    required ReaderImageRequest request,
    required String? sourceHeaderText,
    required String? referer,
    required Map<String, String> cachedCookieHeaders,
    Uri? uri,
  }) {
    final out = <String, String>{};
    if (sourceHeaderText != null) {
      out.addAll(ReaderImageRequestParser.parseHeaderText(sourceHeaderText));
    }
    out.addAll(request.headers);

    final targetUri = uri ?? _tryParseHttpUri(request.url);
    if (targetUri == null) return out;

    _appendCookieHeader(out, targetUri, cachedCookieHeaders);
    _appendRefererHeaders(out, referer);
    return out;
  }

  /// 生成按协议、主机和端口隔离的 Cookie 缓存键。
  String cookieCacheKey(Uri uri) {
    final host = uri.host.toLowerCase();
    final scheme = uri.scheme.toLowerCase();
    final port = uri.hasPort
        ? uri.port
        : (scheme == 'https' ? _defaultHttpsPort : _defaultHttpPort);
    return '$scheme://$host:$port';
  }

  /// 判断一个地址是否属于 HTTP/HTTPS。
  bool isHttpLikeUri(Uri uri) {
    final scheme = uri.scheme.toLowerCase();
    return scheme == 'http' || scheme == 'https';
  }

  /// 判断 header 中是否已存在指定键名，忽略大小写。
  bool containsHeaderKey(Map<String, String> headers, String name) {
    final lower = name.toLowerCase();
    return headers.keys.any((key) => key.toLowerCase() == lower);
  }

  /// 优先返回章节地址，否则回退到书源地址。
  String? resolveReferer({
    required String? chapterUrl,
    required String? sourceUrl,
  }) {
    final normalizedChapterUrl = _normalizeHttpUrl(chapterUrl);
    if (normalizedChapterUrl != null) {
      return normalizedChapterUrl;
    }
    return _normalizeHttpUrl(sourceUrl);
  }

  ImageProvider<Object>? _resolveInlineImage(String value) {
    final memoryImage = _resolveMemoryImage(value);
    if (memoryImage != null) return memoryImage;
    return _resolveFileImage(value);
  }

  MemoryImage? _resolveMemoryImage(String value) {
    if (!value.toLowerCase().startsWith('data:image')) {
      return null;
    }
    final commaIndex = value.indexOf(',');
    if (commaIndex <= 0 || commaIndex >= value.length - 1) {
      return null;
    }
    try {
      return MemoryImage(base64Decode(value.substring(commaIndex + 1)));
    } catch (_) {
      return null;
    }
  }

  FileImage? _resolveFileImage(String value) {
    if (isWeb) return null;

    if (value.startsWith('file://')) {
      final uri = Uri.tryParse(value);
      if (uri != null) {
        return FileImage(File(uri.toFilePath()));
      }
    }
    if (!p.isAbsolute(value)) return null;

    final file = File(value);
    if (!file.existsSync()) return null;
    return FileImage(file);
  }

  String? _normalizeHttpUrl(String? raw) {
    final value = raw?.trim() ?? '';
    if (value.isEmpty) return null;

    return _tryParseHttpUri(value)?.toString();
  }

  Uri? _tryParseHttpUri(String raw) {
    final uri = Uri.tryParse(raw);
    if (uri == null || !isHttpLikeUri(uri)) {
      return null;
    }
    return uri;
  }

  void _appendCookieHeader(
    Map<String, String> headers,
    Uri uri,
    Map<String, String> cachedCookieHeaders,
  ) {
    final cookieKey = cookieCacheKey(uri);
    final cachedCookie = cachedCookieHeaders[cookieKey];
    if (cachedCookie == null || cachedCookie.isEmpty) {
      return;
    }
    if (!containsHeaderKey(headers, 'Cookie')) {
      headers['Cookie'] = cachedCookie;
    }
  }

  void _appendRefererHeaders(Map<String, String> headers, String? referer) {
    if (referer == null || referer.isEmpty) return;

    if (!containsHeaderKey(headers, 'Referer')) {
      headers['Referer'] = referer;
    }
    if (containsHeaderKey(headers, 'Origin')) return;

    final refererUri = Uri.tryParse(referer);
    if (refererUri != null && isHttpLikeUri(refererUri)) {
      headers['Origin'] = refererUri.origin;
    }
  }
}
