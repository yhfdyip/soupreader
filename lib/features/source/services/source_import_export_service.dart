import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import '../models/book_source.dart';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import '../../../core/utils/legado_json.dart';

typedef SourceImportHttpFetcher = Future<Response<String>> Function(Uri uri);

/// 书源导入导出服务
class SourceImportExportService {
  final SourceImportHttpFetcher? _httpFetcher;
  final bool _isWeb;

  SourceImportExportService({
    SourceImportHttpFetcher? httpFetcher,
    bool? isWeb,
  })  : _httpFetcher = httpFetcher,
        _isWeb = isWeb ?? kIsWeb;

  Future<Response<String>> _defaultFetch(Uri uri) {
    return Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 20),
        receiveTimeout: const Duration(seconds: 20),
        followRedirects: true,
        maxRedirects: 5,
        responseType: ResponseType.plain,
        validateStatus: (_) => true,
      ),
    ).get<String>(uri.toString());
  }

  Future<Response<String>> _fetchFromUrl(Uri uri) {
    final fetcher = _httpFetcher;
    if (fetcher != null) {
      return fetcher(uri);
    }
    return _defaultFetch(uri);
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

      return importFromJson(content);
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

  /// 从URL导入书源
  Future<SourceImportResult> importFromUrl(String url) async {
    try {
      final uri = Uri.tryParse(url);
      if (uri == null || uri.scheme.isEmpty || uri.host.isEmpty) {
        return SourceImportResult(
          success: false,
          errorMessage: '无效链接',
        );
      }

      final response = await _fetchFromUrl(uri);
      final redirectHint = _buildRedirectHint(
        requested: uri,
        resolved: response.realUri,
      );
      final warnings = <String>[];
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

      final parsed = importFromJson(content);
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
