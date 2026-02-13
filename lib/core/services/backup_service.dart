import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

import '../../features/bookshelf/models/book.dart';
import '../../features/reader/models/reading_settings.dart';
import '../../features/source/models/book_source.dart';
import '../database/database_service.dart';
import '../database/repositories/book_repository.dart';
import '../database/repositories/source_repository.dart';
import 'settings_service.dart';
import '../models/app_settings.dart';

/// 备份/恢复服务
///
/// 对标同类阅读器：
/// - 可以导出/导入“设置 + 书源 + 书架（含本地书籍内容）”
/// - 默认不备份在线书籍的章节缓存（体积巨大且可重新拉取）
class BackupService {
  static const int backupVersion = 1;

  final DatabaseService _db;
  final SettingsService _settingsService;
  final BookRepository _bookRepo;
  final ChapterRepository _chapterRepo;
  final SourceRepository _sourceRepo;

  BackupService()
      : _db = DatabaseService(),
        _settingsService = SettingsService(),
        _bookRepo = BookRepository(DatabaseService()),
        _chapterRepo = ChapterRepository(DatabaseService()),
        _sourceRepo = SourceRepository(DatabaseService());

  Future<BackupExportResult> exportToFile({bool includeOnlineCache = false}) async {
    try {
      final data = _buildBackupData(includeOnlineCache: includeOnlineCache);
      final jsonString = const JsonEncoder.withIndent('  ').convert(data);

      final outputPath = await FilePicker.platform.saveFile(
        dialogTitle: '导出备份',
        fileName:
            'soupreader_backup_${DateTime.now().millisecondsSinceEpoch}.json',
        allowedExtensions: ['json'],
        type: FileType.custom,
      );

      if (outputPath == null) {
        return const BackupExportResult(cancelled: true);
      }

      await File(outputPath).writeAsString(jsonString);
      return BackupExportResult(
        success: true,
        filePath: outputPath,
      );
    } catch (e) {
      debugPrint('备份导出失败: $e');
      return BackupExportResult(success: false, errorMessage: '$e');
    }
  }

  Future<BackupImportResult> importFromFile({bool overwrite = false}) async {
    try {
      final pick = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['json', 'txt'],
        allowMultiple: false,
      );
      if (pick == null || pick.files.isEmpty) {
        return const BackupImportResult(cancelled: true);
      }

      final file = pick.files.first;
      String content;

      if (file.bytes != null) {
        content = utf8.decode(file.bytes!);
      } else if (file.path != null) {
        content = await File(file.path!).readAsString();
      } else {
        return const BackupImportResult(
          success: false,
          errorMessage: '无法读取文件内容',
        );
      }

      final raw = json.decode(content);
      if (raw is! Map) {
        return const BackupImportResult(
          success: false,
          errorMessage: '备份格式错误：根节点不是对象',
        );
      }

      final map = raw.map((k, v) => MapEntry('$k', v));
      final version = map['version'];
      if (version is! int || version != backupVersion) {
        return BackupImportResult(
          success: false,
          errorMessage: '备份版本不兼容：$version（当前支持 $backupVersion）',
        );
      }

      if (overwrite) {
        await _db.clearAll();
      }

      final settings = map['settings'];
      if (settings is Map) {
        final settingsMap = settings.map((k, v) => MapEntry('$k', v));
        final appSettings = settingsMap['appSettings'];
        final readingSettings = settingsMap['readingSettings'];

        if (appSettings is Map<String, dynamic>) {
          await _settingsService.saveAppSettings(AppSettings.fromJson(appSettings));
        } else if (appSettings is Map) {
          await _settingsService.saveAppSettings(
            AppSettings.fromJson(appSettings.map((k, v) => MapEntry('$k', v))),
          );
        }

        if (readingSettings is Map<String, dynamic>) {
          await _settingsService.saveReadingSettings(
            ReadingSettings.fromJson(readingSettings),
          );
        } else if (readingSettings is Map) {
          await _settingsService.saveReadingSettings(
            ReadingSettings.fromJson(
              readingSettings.map((k, v) => MapEntry('$k', v)),
            ),
          );
        }
      }

      var sourcesImported = 0;
      final sources = map['sources'];
      if (sources is List) {
        final sourceList = <BookSource>[];
        for (final item in sources) {
          if (item is Map<String, dynamic>) {
            sourceList.add(BookSource.fromJson(item));
          } else if (item is Map) {
            sourceList.add(BookSource.fromJson(item.map((k, v) => MapEntry('$k', v))));
          }
        }
        if (sourceList.isNotEmpty) {
          await _sourceRepo.addSources(sourceList);
          sourcesImported = sourceList.length;
        }
      }

      var booksImported = 0;
      final books = map['books'];
      if (books is List) {
        for (final item in books) {
          Book? book;
          if (item is Map<String, dynamic>) {
            book = Book.fromJson(item);
          } else if (item is Map) {
            book = Book.fromJson(item.map((k, v) => MapEntry('$k', v)));
          }
          if (book != null) {
            await _bookRepo.addBook(book);
            booksImported++;
          }
        }
      }

      var chaptersImported = 0;
      final chapters = map['chapters'];
      if (chapters is List) {
        final chapterList = <Chapter>[];
        for (final item in chapters) {
          if (item is Map<String, dynamic>) {
            chapterList.add(Chapter.fromJson(item));
          } else if (item is Map) {
            chapterList.add(Chapter.fromJson(item.map((k, v) => MapEntry('$k', v))));
          }
        }
        if (chapterList.isNotEmpty) {
          await _chapterRepo.addChapters(chapterList);
          chaptersImported = chapterList.length;
        }
      }

      return BackupImportResult(
        success: true,
        sourcesImported: sourcesImported,
        booksImported: booksImported,
        chaptersImported: chaptersImported,
      );
    } catch (e) {
      debugPrint('备份导入失败: $e');
      return BackupImportResult(success: false, errorMessage: '$e');
    }
  }

  Map<String, dynamic> _buildBackupData({required bool includeOnlineCache}) {
    final books = _bookRepo.getAllBooks();
    final sources = _sourceRepo.getAllSources();

    final localBookIds = books.where((b) => b.isLocal).map((b) => b.id).toSet();
    final allChapters = <Chapter>[];
    for (final chapter in _chapterRepo.getAllChapters()) {
      final isLocalBook = localBookIds.contains(chapter.bookId);
      if (!isLocalBook && !includeOnlineCache) continue;

      allChapters.add(
        Chapter(
          id: chapter.id,
          bookId: chapter.bookId,
          title: chapter.title,
          url: chapter.url,
          index: chapter.index,
          isDownloaded: chapter.isDownloaded,
          content: chapter.content,
        ),
      );
    }

    return {
      'version': backupVersion,
      'exportedAt': DateTime.now().toIso8601String(),
      'settings': {
        'appSettings': _settingsService.appSettings.toJson(),
        'readingSettings': _settingsService.readingSettings.toJson(),
      },
      'sources': sources.map((s) => s.toJson()).toList(),
      'books': books.map((b) => b.toJson()).toList(),
      'chapters': allChapters.map((c) => c.toJson()).toList(),
      'meta': {
        'includeOnlineCache': includeOnlineCache,
      },
    };
  }
}

class BackupExportResult {
  final bool success;
  final bool cancelled;
  final String? filePath;
  final String? errorMessage;

  const BackupExportResult({
    this.success = false,
    this.cancelled = false,
    this.filePath,
    this.errorMessage,
  });
}

class BackupImportResult {
  final bool success;
  final bool cancelled;
  final String? errorMessage;
  final int sourcesImported;
  final int booksImported;
  final int chaptersImported;

  const BackupImportResult({
    this.success = false,
    this.cancelled = false,
    this.errorMessage,
    this.sourcesImported = 0,
    this.booksImported = 0,
    this.chaptersImported = 0,
  });
}
