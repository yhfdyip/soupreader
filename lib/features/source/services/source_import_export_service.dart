import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import '../models/book_source.dart';
import 'package:flutter/foundation.dart';
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
        content = utf8.decode(file.bytes!);
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
      final dynamic data = json.decode(jsonString);
      final sources = <BookSource>[];

      if (data is List) {
        // 源阅格式：JSON数组
        for (final item in data) {
          if (item is Map<String, dynamic>) {
            try {
              sources.add(BookSource.fromJson(item));
            } catch (e) {
              debugPrint('解析书源失败: $e');
            }
          }
        }
      } else if (data is Map<String, dynamic>) {
        // 单个书源
        sources.add(BookSource.fromJson(data));
      }

      return SourceImportResult(
        success: true,
        sources: sources,
        importCount: sources.length,
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
      final httpClient = HttpClient();
      final request = await httpClient.getUrl(Uri.parse(url));
      final response = await request.close();

      if (response.statusCode != 200) {
        return SourceImportResult(
          success: false,
          errorMessage: 'HTTP请求失败: ${response.statusCode}',
        );
      }

      final content = await response.transform(utf8.decoder).join();
      return importFromJson(content);
    } catch (e) {
      return SourceImportResult(
        success: false,
        errorMessage: '网络请求失败: $e',
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

  const SourceImportResult({
    this.success = false,
    this.cancelled = false,
    this.errorMessage,
    this.sources = const [],
    this.importCount = 0,
  });
}
