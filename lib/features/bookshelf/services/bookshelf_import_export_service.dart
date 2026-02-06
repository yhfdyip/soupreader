import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/book.dart';

class BooklistItem {
  final String name;
  final String author;
  final String? intro;

  const BooklistItem({
    required this.name,
    required this.author,
    this.intro,
  });

  factory BooklistItem.fromJson(Map<String, dynamic> json) {
    final name = (json['name'] ?? json['title'] ?? '').toString().trim();
    final author = (json['author'] ?? '').toString().trim();
    final intro = json['intro']?.toString();
    return BooklistItem(name: name, author: author, intro: intro);
  }

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      // 对标 Legado 的书单导出字段
      'name': name,
      'author': author,
    };
    if (intro != null) {
      json['intro'] = intro;
    }
    return json;
  }
}

class BookshelfExportResult {
  final bool success;
  final bool cancelled;
  final String? errorMessage;
  final String? outputPathOrHint;

  const BookshelfExportResult({
    required this.success,
    required this.cancelled,
    required this.errorMessage,
    required this.outputPathOrHint,
  });

  factory BookshelfExportResult.success({String? hint}) {
    return BookshelfExportResult(
      success: true,
      cancelled: false,
      errorMessage: null,
      outputPathOrHint: hint,
    );
  }

  factory BookshelfExportResult.cancelled() {
    return const BookshelfExportResult(
      success: false,
      cancelled: true,
      errorMessage: null,
      outputPathOrHint: null,
    );
  }

  factory BookshelfExportResult.error(String message) {
    return BookshelfExportResult(
      success: false,
      cancelled: false,
      errorMessage: message,
      outputPathOrHint: null,
    );
  }
}

class BookshelfImportParseResult {
  final bool success;
  final bool cancelled;
  final String? errorMessage;
  final List<BooklistItem> items;

  const BookshelfImportParseResult({
    required this.success,
    required this.cancelled,
    required this.errorMessage,
    required this.items,
  });

  factory BookshelfImportParseResult.success(List<BooklistItem> items) {
    return BookshelfImportParseResult(
      success: true,
      cancelled: false,
      errorMessage: null,
      items: items,
    );
  }

  factory BookshelfImportParseResult.cancelled() {
    return const BookshelfImportParseResult(
      success: false,
      cancelled: true,
      errorMessage: null,
      items: [],
    );
  }

  factory BookshelfImportParseResult.error(String message) {
    return BookshelfImportParseResult(
      success: false,
      cancelled: false,
      errorMessage: message,
      items: const [],
    );
  }
}

/// 书单导入导出（对标 Legado: `[{name, author, intro}]`）
class BookshelfImportExportService {
  String exportToJson(List<Book> books) {
    final payload = books
        .map((b) => BooklistItem(name: b.title, author: b.author, intro: b.intro))
        .map((item) => item.toJson())
        .toList(growable: false);
    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  Future<BookshelfExportResult> exportToFile(List<Book> books) async {
    try {
      final jsonString = exportToJson(books);

      if (kIsWeb) {
        await Clipboard.setData(ClipboardData(text: jsonString));
        return BookshelfExportResult.success(hint: '已复制到剪贴板');
      }

      final outputPath = await FilePicker.platform.saveFile(
        dialogTitle: '导出书单',
        fileName: 'bookshelf.json',
        allowedExtensions: ['json'],
        type: FileType.custom,
      );

      if (outputPath == null) {
        return BookshelfExportResult.cancelled();
      }

      await File(outputPath).writeAsString(jsonString);
      return BookshelfExportResult.success(hint: outputPath);
    } catch (e) {
      return BookshelfExportResult.error('导出失败: $e');
    }
  }

  Future<BookshelfImportParseResult> importFromFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json', 'txt'],
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) {
        return BookshelfImportParseResult.cancelled();
      }

      final file = result.files.first;
      String content;
      if (file.bytes != null) {
        content = utf8.decode(file.bytes!);
      } else if (file.path != null) {
        content = await File(file.path!).readAsString();
      } else {
        return BookshelfImportParseResult.error('无法读取文件内容');
      }

      return importFromJson(content);
    } catch (e) {
      return BookshelfImportParseResult.error('导入失败: $e');
    }
  }

  BookshelfImportParseResult importFromJson(String jsonString) {
    try {
      final text = jsonString.trim();
      if (text.isEmpty) {
        return BookshelfImportParseResult.error('内容为空');
      }

      final dynamic data = json.decode(text);
      final items = <BooklistItem>[];

      if (data is List) {
        for (final item in data) {
          if (item is Map) {
            final map = item.map((k, v) => MapEntry(k.toString(), v));
            final parsed = BooklistItem.fromJson(map);
            if (parsed.name.isNotEmpty) {
              items.add(parsed);
            }
          }
        }
      } else if (data is Map) {
        // 容错：有人把单本书当成对象导出
        final map = data.map((k, v) => MapEntry(k.toString(), v));
        final parsed = BooklistItem.fromJson(map);
        if (parsed.name.isNotEmpty) {
          items.add(parsed);
        }
      } else {
        return BookshelfImportParseResult.error('JSON 格式不支持');
      }

      if (items.isEmpty) {
        return BookshelfImportParseResult.error('未解析到任何书籍条目');
      }

      return BookshelfImportParseResult.success(items);
    } catch (e) {
      return BookshelfImportParseResult.error('JSON 解析失败: $e');
    }
  }
}
