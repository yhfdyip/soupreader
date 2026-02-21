import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../../core/models/app_settings.dart';
import '../../../core/services/webdav_service.dart';

class RemoteBookEntry {
  final String displayName;
  final String path;
  final int size;
  final int lastModify;
  final bool isDirectory;

  const RemoteBookEntry({
    required this.displayName,
    required this.path,
    required this.size,
    required this.lastModify,
    required this.isDirectory,
  });
}

typedef RemoteBooksPropfindHandler = Future<Response<dynamic>> Function({
  required Uri uri,
  required AppSettings settings,
  required String payload,
});

/// 对齐 legado `RemoteBookWebDav.getRemoteBookList` 的最小可用实现：
/// - 使用 `PROPFIND + Depth=1` 拉取当前目录；
/// - 过滤目录与可阅读文件；
/// - 刷新时由调用方重载当前目录。
class RemoteBooksService {
  RemoteBooksService({
    Dio? dio,
    WebDavService? webDavService,
    RemoteBooksPropfindHandler? propfindHandler,
  })  : _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 12),
                receiveTimeout: const Duration(seconds: 20),
                sendTimeout: const Duration(seconds: 20),
                responseType: ResponseType.plain,
                validateStatus: (_) => true,
              ),
            ),
        _webDavService = webDavService ?? WebDavService(),
        _propfindHandler = propfindHandler;

  static final RegExp _bookFileRegex = RegExp(
    r'.*\.(txt|epub|umd|pdf|mobi|azw3|azw)$',
    caseSensitive: false,
  );
  static final RegExp _archiveFileRegex = RegExp(
    r'.*\.(zip|rar|7z)$',
    caseSensitive: false,
  );
  static final RegExp _responseRegex = RegExp(
    r'<(?:\w+:)?response\b[\s\S]*?<\/(?:\w+:)?response>',
    caseSensitive: false,
  );

  static const String _propfindBody = '''<?xml version="1.0"?>
<a:propfind xmlns:a="DAV:">
  <a:prop>
    <a:displayname/>
    <a:resourcetype/>
    <a:getcontentlength/>
    <a:creationdate/>
    <a:getlastmodified/>
  </a:prop>
</a:propfind>''';

  final Dio _dio;
  final WebDavService _webDavService;
  final RemoteBooksPropfindHandler? _propfindHandler;

  bool hasValidWebDavConfig(AppSettings settings) {
    return _webDavService.hasValidConfig(settings);
  }

  String buildRootBooksUrl(AppSettings settings) {
    return _webDavService.buildBooksRootUrl(settings);
  }

  Future<List<RemoteBookEntry>> listCurrentDirectory({
    required AppSettings settings,
    String? currentDirectoryUrl,
  }) async {
    if (!hasValidWebDavConfig(settings)) {
      throw const WebDavOperationException('没有配置webDav');
    }
    final requestedUrl =
        (currentDirectoryUrl ?? buildRootBooksUrl(settings)).trim();
    final uri = Uri.tryParse(requestedUrl);
    if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
      throw const WebDavOperationException('WebDav 地址无效，请使用 http/https');
    }
    final response = await _propfind(
      uri: uri,
      settings: settings,
    );
    final status = response.statusCode ?? 0;
    if (status < 200 || status >= 300) {
      throw WebDavOperationException('HTTP $status');
    }
    final body = _responseBodyToText(response.data);
    final entries = _parseRemoteEntries(
      body: body,
      requestUri: uri,
      currentDirectoryUrl: requestedUrl,
    );
    entries.sort((a, b) {
      if (a.isDirectory != b.isDirectory) {
        return a.isDirectory ? -1 : 1;
      }
      return b.lastModify.compareTo(a.lastModify);
    });
    return entries;
  }

  Future<Response<dynamic>> _propfind({
    required Uri uri,
    required AppSettings settings,
  }) async {
    final handler = _propfindHandler;
    if (handler != null) {
      return handler(
        uri: uri,
        settings: settings,
        payload: _propfindBody,
      );
    }
    final authPayload = base64Encode(
        utf8.encode('${settings.webDavAccount}:${settings.webDavPassword}'));
    return _dio.request<dynamic>(
      uri.toString(),
      data: _propfindBody,
      options: Options(
        method: 'PROPFIND',
        responseType: ResponseType.plain,
        headers: <String, String>{
          'Authorization': 'Basic $authPayload',
          'Depth': '1',
          'Content-Type': 'text/xml; charset=utf-8',
        },
      ),
    );
  }

  String _responseBodyToText(dynamic body) {
    if (body is String) return body;
    if (body is List<int>) return utf8.decode(body);
    if (body is Uint8List) return utf8.decode(body);
    if (body == null) return '';
    return body.toString();
  }

  List<RemoteBookEntry> _parseRemoteEntries({
    required String body,
    required Uri requestUri,
    required String currentDirectoryUrl,
  }) {
    final normalizedCurrent = _normalizeUrl(currentDirectoryUrl);
    final entries = <RemoteBookEntry>[];
    for (final match in _responseRegex.allMatches(body)) {
      final responseXml = match.group(0) ?? '';
      if (responseXml.trim().isEmpty) continue;
      final href = _extractTagText(responseXml, 'href');
      if (href.isEmpty) continue;
      final hrefDecoded = Uri.decodeFull(_decodeXmlText(href));
      final fullUrl = _resolveHref(requestUri, hrefDecoded);
      if (fullUrl == null) continue;
      final contentType = _extractTagText(responseXml, 'getcontenttype');
      final resourceType = _extractTagInnerXml(responseXml, 'resourcetype');
      final isDir = _isDirectory(
        contentType: contentType,
        resourceTypeXml: resourceType,
      );
      final normalizedPath =
          isDir && !fullUrl.endsWith('/') ? '$fullUrl/' : fullUrl;
      if (_normalizeUrl(normalizedPath) == normalizedCurrent) {
        continue;
      }
      final fileName = _extractFileName(hrefDecoded);
      final displayName = _extractTagText(responseXml, 'displayname').trim();
      final resolvedName = _decodeXmlText(
        displayName.isNotEmpty ? displayName : fileName,
      );
      if (!isDir &&
          !_bookFileRegex.hasMatch(resolvedName) &&
          !_archiveFileRegex.hasMatch(resolvedName)) {
        continue;
      }
      final size = int.tryParse(
              _extractTagText(responseXml, 'getcontentlength').trim()) ??
          0;
      final lastModify =
          _parseLastModify(_extractTagText(responseXml, 'getlastmodified'));
      entries.add(
        RemoteBookEntry(
          displayName: resolvedName,
          path: normalizedPath,
          size: size,
          lastModify: lastModify,
          isDirectory: isDir,
        ),
      );
    }
    return entries;
  }

  String _normalizeUrl(String value) {
    var normalized = value.trim();
    while (normalized.length > 1 && normalized.endsWith('/')) {
      normalized = normalized.substring(0, normalized.length - 1);
    }
    return normalized;
  }

  bool _isDirectory({
    required String contentType,
    required String resourceTypeXml,
  }) {
    final normalizedType = contentType.trim().toLowerCase();
    if (normalizedType == 'httpd/unix-directory') return true;
    return resourceTypeXml.toLowerCase().contains('collection');
  }

  String _extractTagText(String source, String tag) {
    final exp = RegExp(
      '<(?:\\w+:)?$tag\\b[^>]*>([\\s\\S]*?)<\\/(?:\\w+:)?$tag>',
      caseSensitive: false,
    );
    final raw = exp.firstMatch(source)?.group(1) ?? '';
    return raw.replaceAll(RegExp(r'<[^>]+>'), '').trim();
  }

  String _extractTagInnerXml(String source, String tag) {
    final exp = RegExp(
      '<(?:\\w+:)?$tag\\b[^>]*>([\\s\\S]*?)<\\/(?:\\w+:)?$tag>',
      caseSensitive: false,
    );
    return exp.firstMatch(source)?.group(1)?.trim() ?? '';
  }

  String _decodeXmlText(String value) {
    return value
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&apos;', "'")
        .trim();
  }

  String _extractFileName(String decodedHref) {
    final trimmed = decodedHref.trim();
    if (trimmed.isEmpty) return '';
    final clean = trimmed.endsWith('/')
        ? trimmed.substring(0, trimmed.length - 1)
        : trimmed;
    final slashIndex = clean.lastIndexOf('/');
    if (slashIndex < 0 || slashIndex == clean.length - 1) {
      return clean;
    }
    return clean.substring(slashIndex + 1);
  }

  String? _resolveHref(Uri requestUri, String href) {
    final raw = href.trim();
    if (raw.isEmpty) return null;
    final uri = Uri.tryParse(raw);
    if (uri != null && uri.hasScheme) {
      if (uri.scheme == 'http' || uri.scheme == 'https') {
        return uri.toString();
      }
      if (uri.scheme == 'dav') {
        return uri.replace(scheme: 'http').toString();
      }
      if (uri.scheme == 'davs') {
        return uri.replace(scheme: 'https').toString();
      }
    }
    if (raw.startsWith('/')) {
      return '${requestUri.scheme}://${requestUri.authority}$raw';
    }
    return requestUri.resolve(raw).toString();
  }

  int _parseLastModify(String rawValue) {
    final value = rawValue.trim();
    if (value.isEmpty) return 0;
    try {
      return HttpDate.parse(value).millisecondsSinceEpoch;
    } catch (_) {
      return 0;
    }
  }
}
