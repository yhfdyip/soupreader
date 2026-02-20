import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;

import '../../features/bookshelf/models/book.dart';
import '../models/app_settings.dart';

class WebDavOperationException implements Exception {
  final String message;

  const WebDavOperationException(this.message);

  @override
  String toString() => message;
}

class WebDavUploadResult {
  final String remoteUrl;

  const WebDavUploadResult({required this.remoteUrl});
}

class WebDavService {
  WebDavService({Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 12),
                receiveTimeout: const Duration(seconds: 20),
                sendTimeout: const Duration(seconds: 120),
                responseType: ResponseType.bytes,
                validateStatus: (_) => true,
              ),
            );

  final Dio _dio;

  bool hasValidConfig(AppSettings settings) {
    final account = settings.webDavAccount.trim();
    final password = settings.webDavPassword.trim();
    return account.isNotEmpty && password.isNotEmpty;
  }

  String buildRootUrl(AppSettings settings) {
    final rawUrl = settings.webDavUrl.trim().isEmpty
        ? AppSettings.defaultWebDavUrl
        : settings.webDavUrl.trim();
    var normalized = rawUrl;
    if (!normalized.endsWith('/')) {
      normalized = '$normalized/';
    }

    var dir = settings.webDavDir.trim();
    if (dir.isEmpty) return normalized;
    dir = dir.replaceAll('\\', '/');
    dir = dir.replaceAll(RegExp(r'^/+'), '');
    dir = dir.replaceAll(RegExp(r'/+$'), '');
    if (dir.isEmpty) return normalized;
    return '$normalized$dir/';
  }

  String buildBooksRootUrl(AppSettings settings) {
    return '${buildRootUrl(settings)}books/';
  }

  String buildBookUploadUrl(
    AppSettings settings, {
    required String fileName,
  }) {
    final encodedName = Uri.encodeComponent(fileName.trim());
    return '${buildBooksRootUrl(settings)}$encodedName';
  }

  Future<void> validateConfig(AppSettings settings) async {
    final rootUri = Uri.tryParse(buildRootUrl(settings));
    if (rootUri == null ||
        (rootUri.scheme != 'http' && rootUri.scheme != 'https')) {
      throw const WebDavOperationException('WebDav 地址无效，请使用 http/https');
    }
    if (!hasValidConfig(settings)) {
      throw const WebDavOperationException('请先配置 WebDav 账号和密码');
    }
  }

  Future<void> ensureUploadDirectories(AppSettings settings) async {
    await validateConfig(settings);
    final rootUri = Uri.parse(buildRootUrl(settings));
    final booksUri = Uri.parse(buildBooksRootUrl(settings));
    await _ensureDirectory(rootUri, settings);
    await _ensureDirectory(booksUri, settings);
  }

  Future<WebDavUploadResult> uploadLocalBook({
    required Book book,
    required AppSettings settings,
  }) async {
    if (!book.isLocal) {
      throw const WebDavOperationException('当前书籍不是本地书籍，无法上传');
    }

    final localPath = (book.localPath ?? '').trim();
    if (localPath.isEmpty) {
      throw const WebDavOperationException('本地文件路径缺失，无法上传');
    }

    final file = File(localPath);
    if (!await file.exists()) {
      throw WebDavOperationException('本地文件不存在：$localPath');
    }

    await ensureUploadDirectories(settings);

    final fileName = p.basename(localPath);
    if (fileName.trim().isEmpty) {
      throw const WebDavOperationException('无法识别上传文件名');
    }

    final uploadUri = Uri.parse(
      buildBookUploadUrl(settings, fileName: fileName),
    );
    final bytes = await file.readAsBytes();
    final response = await _request(
      method: 'PUT',
      uri: uploadUri,
      settings: settings,
      data: bytes,
      extraHeaders: const <String, String>{
        'Content-Type': 'application/octet-stream',
      },
    );

    if (_isSuccessStatus(response.statusCode)) {
      return WebDavUploadResult(remoteUrl: uploadUri.toString());
    }

    throw _buildStatusException(
      action: '上传',
      uri: uploadUri,
      response: response,
    );
  }

  Future<void> _ensureDirectory(Uri uri, AppSettings settings) async {
    final response = await _request(
      method: 'MKCOL',
      uri: uri,
      settings: settings,
    );

    final code = response.statusCode ?? 0;
    if (code == 201 ||
        code == 200 ||
        code == 204 ||
        code == 301 ||
        code == 302 ||
        code == 405) {
      return;
    }

    throw _buildStatusException(
      action: '创建远程目录',
      uri: uri,
      response: response,
    );
  }

  Future<Response<dynamic>> _request({
    required String method,
    required Uri uri,
    required AppSettings settings,
    Object? data,
    Map<String, String>? extraHeaders,
  }) async {
    final headers = <String, String>{
      ..._buildAuthHeaders(settings),
      if (extraHeaders != null) ...extraHeaders,
    };

    try {
      return await _dio.requestUri(
        uri,
        data: data,
        options: Options(
          method: method,
          headers: headers,
          responseType: ResponseType.bytes,
          followRedirects: false,
        ),
      );
    } on DioException catch (e) {
      throw WebDavOperationException(
          _formatDioError(method: method, uri: uri, error: e));
    }
  }

  Map<String, String> _buildAuthHeaders(AppSettings settings) {
    final account = settings.webDavAccount.trim();
    final password = settings.webDavPassword.trim();
    final token = base64Encode(utf8.encode('$account:$password'));
    return <String, String>{
      'Authorization': 'Basic $token',
    };
  }

  bool _isSuccessStatus(int? statusCode) {
    if (statusCode == null) return false;
    return statusCode >= 200 && statusCode < 300;
  }

  WebDavOperationException _buildStatusException({
    required String action,
    required Uri uri,
    required Response<dynamic> response,
  }) {
    final status = response.statusCode ?? -1;
    final reason = _firstNonEmpty(<String?>[
      response.statusMessage,
      _compactBodySnippet(response.data),
    ]);
    final headerHint = _importantHeaders(response.headers.map);
    final tail = reason == null ? '' : '，$reason';
    return WebDavOperationException(
      '$action失败（HTTP $status）$tail$headerHint\n$urlLabel: ${uri.toString()}',
    );
  }

  String _formatDioError({
    required String method,
    required Uri uri,
    required DioException error,
  }) {
    final response = error.response;
    if (response != null) {
      final status = response.statusCode ?? -1;
      final reason = _firstNonEmpty(<String?>[
        response.statusMessage,
        _compactBodySnippet(response.data),
      ]);
      final headerHint = _importantHeaders(response.headers.map);
      final tail = reason == null ? '' : '，$reason';
      return '$method 请求失败（HTTP $status）$tail$headerHint\n$urlLabel: ${uri.toString()}';
    }

    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return '$method 请求超时：${uri.toString()}';
      case DioExceptionType.connectionError:
        return '$method 连接失败：${error.message ?? '网络异常'}';
      case DioExceptionType.badCertificate:
        return '$method 证书校验失败：${uri.toString()}';
      case DioExceptionType.cancel:
        return '$method 请求已取消：${uri.toString()}';
      case DioExceptionType.badResponse:
      case DioExceptionType.unknown:
        return '$method 请求异常：${error.message ?? '未知错误'}';
    }
  }

  String _importantHeaders(Map<String, List<String>> headers) {
    const keys = <String>['www-authenticate', 'dav', 'allow', 'content-type'];
    final parts = <String>[];
    for (final key in keys) {
      final values = headers[key];
      if (values == null || values.isEmpty) continue;
      parts.add('$key=${values.join(',')}');
    }
    if (parts.isEmpty) return '';
    return '，关键响应头：${parts.join('; ')}';
  }

  String? _compactBodySnippet(Object? data) {
    if (data == null) return null;
    if (data is List<int>) {
      if (data.isEmpty) return null;
      final text = utf8.decode(data, allowMalformed: true).trim();
      if (text.isEmpty) return null;
      return _trimLength(text);
    }
    final text = data.toString().trim();
    if (text.isEmpty) return null;
    return _trimLength(text);
  }

  String _trimLength(String text, {int max = 120}) {
    final normalized = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.length <= max) return normalized;
    return '${normalized.substring(0, max)}…';
  }

  String? _firstNonEmpty(List<String?> values) {
    for (final raw in values) {
      final text = raw?.trim() ?? '';
      if (text.isNotEmpty) return text;
    }
    return null;
  }
}

const String urlLabel = 'URL';
