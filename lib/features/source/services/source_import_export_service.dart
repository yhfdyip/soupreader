import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import '../models/book_source.dart';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import '../../../core/utils/legado_json.dart';

/// 书源导入导出服务
class SourceImportExportService {
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

  /// 从JSON字符串导入书源
  SourceImportResult importFromJson(String jsonString) {
    try {
      final raw = jsonString.trim();
      if (raw.isEmpty) {
        return const SourceImportResult(
          success: false,
          errorMessage: '内容为空',
        );
      }

      dynamic data = json.decode(raw);
      if (data is String) {
        final nested = data.trim();
        if (nested.startsWith('{') || nested.startsWith('[')) {
          try {
            data = json.decode(nested);
          } catch (_) {}
        }
      }

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

      Map<String, dynamic>? asMap(dynamic item) {
        if (item is Map<String, dynamic>) return item;
        if (item is Map) {
          return item.map((k, v) => MapEntry(k.toString(), v));
        }
        if (item is String) {
          final text = item.trim();
          if (text.isEmpty) return null;
          try {
            final decoded = json.decode(text);
            if (decoded is Map<String, dynamic>) return decoded;
            if (decoded is Map) {
              return decoded.map((k, v) => MapEntry(k.toString(), v));
            }
          } catch (_) {
            return null;
          }
        }
        return null;
      }

      for (var i = 0; i < items.length; i++) {
        final map = asMap(items[i]);
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

      final response = await Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 20),
          receiveTimeout: const Duration(seconds: 20),
          followRedirects: true,
          maxRedirects: 5,
          responseType: ResponseType.plain,
          validateStatus: (_) => true,
        ),
      ).get<String>(uri.toString());

      final status = response.statusCode ?? 0;
      if (status < 200 || status >= 300) {
        return SourceImportResult(
          success: false,
          errorMessage: 'HTTP请求失败: $status',
        );
      }

      final content = (response.data ?? '').trim();
      if (content.isEmpty) {
        return SourceImportResult(
          success: false,
          errorMessage: '返回内容为空',
        );
      }

      return importFromJson(content);
    } catch (e) {
      final err = e.toString();
      if (kIsWeb &&
          (err.contains('XMLHttpRequest') ||
              err.toLowerCase().contains('cors'))) {
        return SourceImportResult(
          success: false,
          errorMessage: '网络导入失败：浏览器跨域限制（CORS）',
        );
      }
      return SourceImportResult(
        success: false,
        errorMessage: '网络请求失败: $err',
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
  });
}
