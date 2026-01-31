import 'package:file_picker/file_picker.dart';
import '../bookshelf/models/book.dart';
import '../../core/database/database_service.dart';
import '../../core/database/repositories/book_repository.dart';
import 'txt_parser.dart';
import 'epub_parser.dart';

/// 书籍导入服务
class ImportService {
  final BookRepository _bookRepo;
  final ChapterRepository _chapterRepo;

  ImportService()
      : _bookRepo = BookRepository(DatabaseService()),
        _chapterRepo = ChapterRepository(DatabaseService());

  /// 选择并导入本地书籍（支持 TXT 和 EPUB）
  Future<ImportResult> importLocalBook() async {
    try {
      // 打开文件选择器 - 支持 TXT 和 EPUB
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['txt', 'epub'],
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) {
        return ImportResult.cancelled();
      }

      final file = result.files.first;
      final extension = file.extension?.toLowerCase() ?? '';

      if (extension == 'txt') {
        return _importTxt(file);
      } else if (extension == 'epub') {
        return _importEpub(file);
      } else {
        return ImportResult.error('不支持的文件格式: $extension');
      }
    } catch (e) {
      return ImportResult.error(e.toString());
    }
  }

  /// 导入 TXT 文件
  Future<ImportResult> importTxtFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['txt'],
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) {
        return ImportResult.cancelled();
      }

      return _importTxt(result.files.first);
    } catch (e) {
      return ImportResult.error(e.toString());
    }
  }

  /// 导入 EPUB 文件
  Future<ImportResult> importEpubFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['epub'],
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) {
        return ImportResult.cancelled();
      }

      return _importEpub(result.files.first);
    } catch (e) {
      return ImportResult.error(e.toString());
    }
  }

  /// 内部：导入 TXT
  Future<ImportResult> _importTxt(PlatformFile file) async {
    TxtImportResult parseResult;
    if (file.bytes != null) {
      parseResult = TxtParser.importFromBytes(file.bytes!, file.name);
    } else if (file.path != null) {
      parseResult = await TxtParser.importFromFile(file.path!);
    } else {
      return ImportResult.error('无法读取文件');
    }

    // 保存到数据库
    await _bookRepo.addBook(parseResult.book);
    await _chapterRepo.addChapters(parseResult.chapters);

    return ImportResult.success(
      book: parseResult.book,
      chapterCount: parseResult.chapters.length,
    );
  }

  /// 内部：导入 EPUB
  Future<ImportResult> _importEpub(PlatformFile file) async {
    EpubImportResult parseResult;
    if (file.bytes != null) {
      parseResult =
          await EpubParser.importFromBytes(file.bytes!, file.name, null);
    } else if (file.path != null) {
      parseResult = await EpubParser.importFromFile(file.path!);
    } else {
      return ImportResult.error('无法读取文件');
    }

    // 保存到数据库
    await _bookRepo.addBook(parseResult.book);
    await _chapterRepo.addChapters(parseResult.chapters);

    return ImportResult.success(
      book: parseResult.book,
      chapterCount: parseResult.chapters.length,
    );
  }

  /// 检查书籍是否已存在
  bool hasBook(String bookId) => _bookRepo.hasBook(bookId);
}

/// 导入结果
class ImportResult {
  final bool success;
  final bool cancelled;
  final String? errorMessage;
  final Book? book;
  final int chapterCount;

  ImportResult._({
    required this.success,
    this.cancelled = false,
    this.errorMessage,
    this.book,
    this.chapterCount = 0,
  });

  factory ImportResult.success(
      {required Book book, required int chapterCount}) {
    return ImportResult._(
        success: true, book: book, chapterCount: chapterCount);
  }

  factory ImportResult.cancelled() {
    return ImportResult._(success: false, cancelled: true);
  }

  factory ImportResult.error(String message) {
    return ImportResult._(success: false, errorMessage: message);
  }
}
