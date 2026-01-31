import 'package:file_picker/file_picker.dart';
import '../bookshelf/models/book.dart';
import '../../core/database/database_service.dart';
import '../../core/database/repositories/book_repository.dart';
import 'txt_parser.dart';

/// 书籍导入服务
class ImportService {
  final BookRepository _bookRepo;
  final ChapterRepository _chapterRepo;

  ImportService()
      : _bookRepo = BookRepository(DatabaseService()),
        _chapterRepo = ChapterRepository(DatabaseService());

  /// 选择并导入 TXT 文件
  Future<ImportResult> importTxtFile() async {
    try {
      // 打开文件选择器
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['txt'],
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) {
        return ImportResult.cancelled();
      }

      final file = result.files.first;

      // iOS 使用 bytes，其他平台使用 path
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
    } catch (e) {
      return ImportResult.error(e.toString());
    }
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
