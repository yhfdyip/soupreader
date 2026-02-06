import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

import '../../../core/utils/legado_json.dart';
import '../models/replace_rule.dart';

class ReplaceRuleImportResult {
  final bool success;
  final bool cancelled;
  final String? errorMessage;
  final List<ReplaceRule> rules;

  const ReplaceRuleImportResult({
    required this.success,
    required this.cancelled,
    required this.errorMessage,
    required this.rules,
  });

  factory ReplaceRuleImportResult.cancelled() {
    return const ReplaceRuleImportResult(
      success: false,
      cancelled: true,
      errorMessage: null,
      rules: [],
    );
  }

  factory ReplaceRuleImportResult.error(String message) {
    return ReplaceRuleImportResult(
      success: false,
      cancelled: false,
      errorMessage: message,
      rules: const [],
    );
  }

  factory ReplaceRuleImportResult.success(List<ReplaceRule> rules) {
    return ReplaceRuleImportResult(
      success: true,
      cancelled: false,
      errorMessage: null,
      rules: rules,
    );
  }
}

class ReplaceRuleImportExportService {
  ReplaceRuleImportResult importFromJson(String jsonString) {
    try {
      final dynamic data = json.decode(jsonString);
      final rules = <ReplaceRule>[];

      if (data is List) {
        for (final item in data) {
          if (item is Map<String, dynamic>) {
            rules.add(ReplaceRule.fromJson(item));
          } else if (item is Map) {
            rules.add(
              ReplaceRule.fromJson(
                item.map((k, v) => MapEntry(k.toString(), v)),
              ),
            );
          }
        }
      } else if (data is Map<String, dynamic>) {
        rules.add(ReplaceRule.fromJson(data));
      } else if (data is Map) {
        rules.add(
          ReplaceRule.fromJson(
            data.map((k, v) => MapEntry(k.toString(), v)),
          ),
        );
      } else {
        return ReplaceRuleImportResult.error('JSON 格式不支持');
      }

      if (rules.isEmpty) {
        return ReplaceRuleImportResult.error('未解析到任何规则');
      }

      return ReplaceRuleImportResult.success(rules);
    } catch (e) {
      return ReplaceRuleImportResult.error('JSON 解析失败: $e');
    }
  }

  Future<ReplaceRuleImportResult> importFromFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json', 'txt'],
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) {
        return ReplaceRuleImportResult.cancelled();
      }

      final file = result.files.first;
      String content;
      if (file.bytes != null) {
        content = utf8.decode(file.bytes!);
      } else if (file.path != null) {
        content = await File(file.path!).readAsString();
      } else {
        return ReplaceRuleImportResult.error('无法读取文件内容');
      }

      return importFromJson(content);
    } catch (e) {
      return ReplaceRuleImportResult.error('导入失败: $e');
    }
  }

  Future<ReplaceRuleImportResult> importFromUrl(String url) async {
    try {
      final httpClient = HttpClient();
      final request = await httpClient.getUrl(Uri.parse(url));
      final response = await request.close();
      if (response.statusCode != 200) {
        return ReplaceRuleImportResult.error('HTTP 请求失败: ${response.statusCode}');
      }
      final content = await response.transform(utf8.decoder).join();
      return importFromJson(content);
    } catch (e) {
      return ReplaceRuleImportResult.error('网络请求失败: $e');
    }
  }

  String exportToJson(List<ReplaceRule> rules) {
    final payload = rules.map((r) => r.toJson()).toList(growable: false);
    return LegadoJson.encode(payload);
  }

  Future<String?> exportToFile(List<ReplaceRule> rules) async {
    try {
      final jsonString = exportToJson(rules);

      if (kIsWeb) {
        // Web 端不写文件；交由上层复制到剪贴板
        return null;
      }

      final outputPath = await FilePicker.platform.saveFile(
        dialogTitle: '导出替换净化规则',
        fileName: 'replaceRule.json',
        allowedExtensions: ['json'],
        type: FileType.custom,
      );
      if (outputPath == null) return null;

      await File(outputPath).writeAsString(jsonString);
      return outputPath;
    } catch (_) {
      return null;
    }
  }
}

