import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import '../models/book_source.dart';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import '../../../core/utils/legado_json.dart';

typedef SourceImportHttpFetcher = Future<Response<String>> Function(Uri uri);

/// 书源导入导出服务
class SourceImportExportService {
  static const String _requestWithoutUaSuffix = '#requestWithoutUA';
  static const int _maxImportDepth = 3;

  final SourceImportHttpFetcher? _httpFetcher;
  final bool _isWeb;

  SourceImportExportService({
    SourceImportHttpFetcher? httpFetcher,
    bool? isWeb,
  })  : _httpFetcher = httpFetcher,
        _isWeb = isWeb ?? kIsWeb;

  Future<Response<String>> _defaultFetch(
    Uri uri, {
    required bool requestWithoutUa,
  }) {
    return Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 20),
        receiveTimeout: const Duration(seconds: 20),
        followRedirects: true,
        maxRedirects: 5,
        responseType: ResponseType.plain,
        validateStatus: (_) => true,
      ),
    ).get<String>(
      uri.toString(),
      options: Options(
        headers: requestWithoutUa ? const {'User-Agent': 'null'} : null,
      ),
    );
  }

  Future<Response<String>> _fetchFromUrl(
    Uri uri, {
    required bool requestWithoutUa,
  }) {
    final fetcher = _httpFetcher;
    if (fetcher != null) {
      return fetcher(uri);
    }
    return _defaultFetch(
      uri,
      requestWithoutUa: requestWithoutUa,
    );
  }

  SourceImportResult _copyWithWarnings(
    SourceImportResult source,
    List<String> extraWarnings,
  ) {
    if (extraWarnings.isEmpty) return source;
    final merged = <String>[
      ...source.warnings,
      ...extraWarnings.where((w) => w.trim().isNotEmpty),
    ];
    return SourceImportResult(
      success: source.success,
      cancelled: source.cancelled,
      errorMessage: source.errorMessage,
      sources: source.sources,
      importCount: source.importCount,
      totalInputCount: source.totalInputCount,
      invalidCount: source.invalidCount,
      duplicateCount: source.duplicateCount,
      warnings: merged,
      sourceRawJsonByUrl: source.sourceRawJsonByUrl,
    );
  }

  String? _buildRedirectHint({
    required Uri requested,
    required Uri? resolved,
  }) {
    if (resolved == null) return null;
    final from = requested.toString().trim();
    final to = resolved.toString().trim();
    if (from.isEmpty || to.isEmpty || from == to) {
      return null;
    }
    return '已跟随重定向：$from -> $to';
  }

  bool _isLikelyCorsError(String text) {
    final lower = text.toLowerCase();
    return lower.contains('xmlhttprequest') ||
        lower.contains('cors') ||
        lower.contains('cross-origin') ||
        lower.contains('access-control-allow-origin');
  }

  String _networkErrorMessage(Object error) {
    if (error is DioException) {
      switch (error.type) {
        case DioExceptionType.connectionTimeout:
          return '网络请求失败：连接超时';
        case DioExceptionType.sendTimeout:
          return '网络请求失败：发送超时';
        case DioExceptionType.receiveTimeout:
          return '网络请求失败：接收超时';
        case DioExceptionType.badCertificate:
          return '网络请求失败：证书异常';
        case DioExceptionType.cancel:
          return '网络请求已取消';
        case DioExceptionType.badResponse:
          final status = error.response?.statusCode;
          if (status != null) {
            return '网络请求失败（HTTP $status）';
          }
          break;
        case DioExceptionType.connectionError:
        case DioExceptionType.unknown:
          break;
      }
      final message = error.message?.trim();
      if (message != null && message.isNotEmpty) {
        return '网络请求失败: $message';
      }
    }
    return '网络请求失败: $error';
  }

  bool _isHttpUrl(String value) {
    final uri = Uri.tryParse(value);
    if (uri == null || uri.host.isEmpty) return false;
    return uri.scheme == 'http' || uri.scheme == 'https';
  }

  List<String>? _extractSourceUrls(dynamic decoded) {
    if (decoded is! Map) return null;
    if (!decoded.containsKey('sourceUrls')) return null;

    final urls = <String>[];
    void addUrl(dynamic value) {
      final text = value?.toString().trim();
      if (text == null || text.isEmpty) return;
      urls.add(text);
    }

    final raw = _decodeNestedJsonValue(decoded['sourceUrls']);
    if (raw is List) {
      for (final item in raw) {
        addUrl(item);
      }
    } else if (raw is String) {
      final normalized = _sanitizeJsonInput(raw);
      if (normalized.startsWith('[')) {
        final nested = _decodeNestedJsonValue(normalized);
        if (nested is List) {
          for (final item in nested) {
            addUrl(item);
          }
        } else {
          addUrl(normalized);
        }
      } else {
        final parts = normalized.split(RegExp(r'[\n,]'));
        for (final part in parts) {
          addUrl(part);
        }
      }
    } else {
      addUrl(raw);
    }

    return urls;
  }

  Future<SourceImportResult> _importFromSourceUrls(
    List<String> sourceUrls, {
    required int depth,
  }) async {
    final warnings = <String>[];
    var invalidCount = 0;
    var duplicateCount = 0;
    final sourceByUrl = <String, BookSource>{};
    final sourceRawJsonByUrl = <String, String>{};

    for (var i = 0; i < sourceUrls.length; i++) {
      final targetUrl = sourceUrls[i].trim();
      if (targetUrl.isEmpty) {
        invalidCount++;
        warnings.add('sourceUrls 第${i + 1}项为空，已跳过');
        continue;
      }
      if (!_isHttpUrl(targetUrl)) {
        invalidCount++;
        warnings.add('sourceUrls 第${i + 1}项不是有效 http/https 链接：$targetUrl');
        continue;
      }

      final result = await _importFromUrl(targetUrl, depth: depth + 1);
      if (!result.success) {
        invalidCount++;
        final reason = result.errorMessage?.trim();
        warnings.add(
          'sourceUrls 第${i + 1}项导入失败：$targetUrl${(reason == null || reason.isEmpty) ? '' : '（$reason）'}',
        );
        continue;
      }

      warnings.addAll(
        result.warnings.map((warning) => '[$targetUrl] $warning'),
      );

      for (final source in result.sources) {
        final url = source.bookSourceUrl.trim();
        if (url.isEmpty) continue;
        if (sourceByUrl.containsKey(url)) {
          duplicateCount++;
          sourceByUrl.remove(url);
        }
        sourceByUrl[url] = source;
        sourceRawJsonByUrl[url] = result.rawJsonForSourceUrl(url) ??
            LegadoJson.encode(source.toJson());
      }
    }

    final sources = sourceByUrl.values.toList(growable: false);
    if (sources.isEmpty) {
      return SourceImportResult(
        success: false,
        errorMessage: '未识别到有效书源（sourceUrls）',
        totalInputCount: sourceUrls.length,
        invalidCount: invalidCount,
        duplicateCount: duplicateCount,
        warnings: warnings,
      );
    }

    return SourceImportResult(
      success: true,
      sources: sources,
      importCount: sources.length,
      totalInputCount: sourceUrls.length,
      invalidCount: invalidCount,
      duplicateCount: duplicateCount,
      warnings: warnings,
      sourceRawJsonByUrl: sourceRawJsonByUrl,
    );
  }

  Future<SourceImportResult> _importFromText(
    String text, {
    required int depth,
  }) async {
    if (depth > _maxImportDepth) {
      return const SourceImportResult(
        success: false,
        errorMessage: '导入层级过深，请检查输入内容是否循环引用',
      );
    }

    final raw = _sanitizeJsonInput(text);
    if (raw.isEmpty) {
      return const SourceImportResult(
        success: false,
        errorMessage: '内容为空',
      );
    }

    if (_isHttpUrl(raw)) {
      return _importFromUrl(raw, depth: depth + 1);
    }

    dynamic decoded;
    try {
      decoded = json.decode(raw);
      decoded = _decodeNestedJsonValue(decoded);
    } catch (_) {
      return const SourceImportResult(
        success: false,
        errorMessage: '格式错误：需为书源 JSON、sourceUrls JSON 或 http/https 链接',
      );
    }

    final sourceUrls = _extractSourceUrls(decoded);
    if (sourceUrls != null) {
      if (sourceUrls.isEmpty) {
        return const SourceImportResult(
          success: false,
          errorMessage: 'sourceUrls 为空',
        );
      }
      return _importFromSourceUrls(sourceUrls, depth: depth + 1);
    }

    return importFromJson(raw);
  }

  /// 从JSON文件导入书源
  Future<SourceImportResult> importFromFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json', 'txt'],
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) {
        return SourceImportResult(cancelled: true);
      }

      final file = result.files.first;
      String content;

      if (file.bytes != null) {
        // Web/iOS 使用 bytes
        content = utf8.decode(file.bytes!, allowMalformed: true);
      } else if (file.path != null) {
        // 其他平台使用路径
        content = await File(file.path!).readAsString();
      } else {
        return SourceImportResult(
          success: false,
          errorMessage: '无法读取文件内容',
        );
      }

      return importFromText(content);
    } catch (e) {
      return SourceImportResult(
        success: false,
        errorMessage: '导入失败: $e',
      );
    }
  }

  String _sanitizeJsonInput(String input) {
    var value = input;
    if (value.startsWith('﻿')) {
      value = value.replaceFirst(RegExp(r'^﻿+'), '');
    }
    return value.trim();
  }

  dynamic _decodeNestedJsonValue(dynamic data, {int maxDepth = 5}) {
    var current = data;
    var depth = 0;

    while (depth < maxDepth && current is String) {
      final text = _sanitizeJsonInput(current);
      if (text.isEmpty) return '';

      final maybeJson = text.startsWith('{') ||
          text.startsWith('[') ||
          (text.startsWith('"') && text.endsWith('"'));
      if (!maybeJson) return current;

      try {
        current = json.decode(text);
        depth++;
      } catch (_) {
        return current;
      }
    }

    return current;
  }

  Map<String, dynamic>? _toSourceMap(dynamic item) {
    final decoded = _decodeNestedJsonValue(item);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) {
      return decoded.map((k, v) => MapEntry(k.toString(), v));
    }
    return null;
  }

  /// 从JSON字符串导入书源
  SourceImportResult importFromJson(String jsonString) {
    try {
      final raw = _sanitizeJsonInput(jsonString);
      if (raw.isEmpty) {
        return const SourceImportResult(
          success: false,
          errorMessage: '内容为空',
        );
      }

      dynamic data = json.decode(raw);
      data = _decodeNestedJsonValue(data);

      final items = <dynamic>[];
      if (data is List) {
        items.addAll(data);
      } else if (data is Map) {
        items.add(data);
      } else {
        return const SourceImportResult(
          success: false,
          errorMessage: 'JSON格式不支持（需对象或数组）',
        );
      }

      final warnings = <String>[];
      var invalidCount = 0;
      var duplicateCount = 0;
      final sourceByUrl = <String, BookSource>{};
      final sourceRawJsonByUrl = <String, String>{};

      for (var i = 0; i < items.length; i++) {
        final map = _toSourceMap(items[i]);
        if (map == null) {
          invalidCount++;
          warnings.add('第${i + 1}条不是有效书源对象，已跳过');
          continue;
        }

        try {
          final source = BookSource.fromJson(map);
          final url = source.bookSourceUrl.trim();
          final name = source.bookSourceName.trim();

          if (url.isEmpty || name.isEmpty) {
            invalidCount++;
            warnings.add('第${i + 1}条缺少 bookSourceUrl/bookSourceName，已跳过');
            continue;
          }

          if (sourceByUrl.containsKey(url)) {
            duplicateCount++;
            sourceByUrl.remove(url);
            warnings.add('发现重复书源URL：$url（已使用后出现项覆盖）');
          }
          sourceByUrl[url] = source;
          sourceRawJsonByUrl[url] = LegadoJson.encode(map);
        } catch (e) {
          invalidCount++;
          warnings.add('第${i + 1}条解析失败：$e');
        }
      }

      final sources = sourceByUrl.values.toList(growable: false);
      if (sources.isEmpty) {
        final error =
            warnings.isNotEmpty ? '未识别到有效书源（共${items.length}条）' : '未识别到有效书源';
        return SourceImportResult(
          success: false,
          errorMessage: error,
          totalInputCount: items.length,
          invalidCount: invalidCount,
          duplicateCount: duplicateCount,
          warnings: warnings,
          sourceRawJsonByUrl: sourceRawJsonByUrl,
        );
      }

      return SourceImportResult(
        success: true,
        sources: sources,
        importCount: sources.length,
        totalInputCount: items.length,
        invalidCount: invalidCount,
        duplicateCount: duplicateCount,
        warnings: warnings,
        sourceRawJsonByUrl: sourceRawJsonByUrl,
      );
    } catch (e) {
      return SourceImportResult(
        success: false,
        errorMessage: 'JSON解析失败: $e',
      );
    }
  }

  /// 从文本导入书源（支持 URL / JSON / {sourceUrls:[...]}）
  Future<SourceImportResult> importFromText(String text) {
    return _importFromText(text, depth: 0);
  }

  /// 从URL导入书源
  Future<SourceImportResult> importFromUrl(String url) async {
    return _importFromUrl(url, depth: 0);
  }

  Future<SourceImportResult> _importFromUrl(
    String url, {
    required int depth,
  }) async {
    if (depth > _maxImportDepth) {
      return const SourceImportResult(
        success: false,
        errorMessage: '导入层级过深，请检查输入内容是否循环引用',
      );
    }

    try {
      var normalizedUrl = url.trim();
      var requestWithoutUa = false;
      if (normalizedUrl.endsWith(_requestWithoutUaSuffix)) {
        requestWithoutUa = true;
        normalizedUrl = normalizedUrl
            .substring(0, normalizedUrl.length - _requestWithoutUaSuffix.length)
            .trim();
      }

      final uri = Uri.tryParse(normalizedUrl);
      if (uri == null || uri.scheme.isEmpty || uri.host.isEmpty) {
        return SourceImportResult(
          success: false,
          errorMessage: '无效链接',
        );
      }

      final response = await _fetchFromUrl(
        uri,
        requestWithoutUa: requestWithoutUa,
      );
      final redirectHint = _buildRedirectHint(
        requested: uri,
        resolved: response.realUri,
      );
      final warnings = <String>[];
      if (requestWithoutUa) {
        warnings.add('已按 #requestWithoutUA 导入（User-Agent=null）');
        if (_httpFetcher != null) {
          warnings.add('当前为自定义网络抓取器，可能未处理 User-Agent 置空语义');
        }
      }
      if (redirectHint != null) {
        warnings.add(redirectHint);
      }

      final status = response.statusCode ?? 0;
      if (status < 200 || status >= 300) {
        return SourceImportResult(
          success: false,
          errorMessage: 'HTTP请求失败: $status',
          warnings: warnings,
        );
      }

      final content = (response.data ?? '').trim();
      if (content.isEmpty) {
        return SourceImportResult(
          success: false,
          errorMessage: '返回内容为空',
          warnings: warnings,
        );
      }

      final parsed = await _importFromText(content, depth: depth + 1);
      return _copyWithWarnings(parsed, warnings);
    } catch (e) {
      final err = e.toString();
      if (_isWeb && _isLikelyCorsError(err)) {
        return SourceImportResult(
          success: false,
          errorMessage: '网络导入失败：浏览器跨域限制（CORS），请改用“从剪贴板导入”或“从文件导入”',
        );
      }
      return SourceImportResult(
        success: false,
        errorMessage: _networkErrorMessage(e),
      );
    }
  }

  /// 导出书源为JSON
  String exportToJson(List<BookSource> sources) {
    final jsonList = sources.map((s) => s.toJson()).toList(growable: false);
    return LegadoJson.encode(jsonList);
  }

  /// 导出书源到文件
  Future<bool> exportToFile(List<BookSource> sources) async {
    try {
      final jsonString = exportToJson(sources);

      // 尝试保存文件
      final outputPath = await FilePicker.platform.saveFile(
        dialogTitle: '导出书源',
        fileName:
            'soupreader_sources_${DateTime.now().millisecondsSinceEpoch}.json',
        allowedExtensions: ['json'],
        type: FileType.custom,
      );

      if (outputPath == null) {
        return false; // 用户取消
      }

      await File(outputPath).writeAsString(jsonString);
      return true;
    } catch (e) {
      debugPrint('导出失败: $e');
      return false;
    }
  }

  /// 生成用于系统分享的临时 JSON 文件（移动端/桌面端）
  Future<File?> exportToShareFile(List<BookSource> sources) async {
    if (_isWeb) return null;
    try {
      final dir = await getTemporaryDirectory();
      final path =
          '${dir.path}/share_book_source_${DateTime.now().millisecondsSinceEpoch}.json';
      final file = File(path);
      await file.writeAsString(exportToJson(sources));
      return file;
    } catch (e) {
      debugPrint('生成分享文件失败: $e');
      return null;
    }
  }
}

/// 导入结果
class SourceImportResult {
  final bool success;
  final bool cancelled;
  final String? errorMessage;
  final List<BookSource> sources;
  final int importCount;
  final int totalInputCount;
  final int invalidCount;
  final int duplicateCount;
  final List<String> warnings;

  /// 导入阶段保留每个书源的原始 JSON（已按 LegadoJson 归一）。
  /// key = bookSourceUrl
  final Map<String, String> sourceRawJsonByUrl;

  bool get hasWarnings => warnings.isNotEmpty;

  const SourceImportResult({
    this.success = false,
    this.cancelled = false,
    this.errorMessage,
    this.sources = const [],
    this.importCount = 0,
    this.totalInputCount = 0,
    this.invalidCount = 0,
    this.duplicateCount = 0,
    this.warnings = const [],
    this.sourceRawJsonByUrl = const <String, String>{},
  });

  String? rawJsonForSourceUrl(String url) {
    final key = url.trim();
    if (key.isEmpty) return null;
    return sourceRawJsonByUrl[key];
  }
}
