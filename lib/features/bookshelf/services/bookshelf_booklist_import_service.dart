import '../../../core/database/database_service.dart';
import '../../../core/database/repositories/source_repository.dart';
import '../../source/models/book_source.dart';
import '../../source/services/rule_parser_engine.dart';
import 'book_add_service.dart';
import 'bookshelf_import_export_service.dart';

class BooklistImportProgress {
  final int done;
  final int total;
  final String currentName;
  final String currentSource;

  const BooklistImportProgress({
    required this.done,
    required this.total,
    required this.currentName,
    required this.currentSource,
  });
}

class BooklistImportSummary {
  final int total;
  final int added;
  final int skipped;
  final int failed;
  final List<String> errors;

  const BooklistImportSummary({
    required this.total,
    required this.added,
    required this.skipped,
    required this.failed,
    required this.errors,
  });

  String get summaryText {
    return '共 $total 本：新增 $added，本地已存在/跳过 $skipped，失败 $failed';
  }
}

class BookshelfBooklistImportService {
  final RuleParserEngine _engine;
  final SourceRepository _sourceRepo;
  final BookAddService _addService;

  BookshelfBooklistImportService({
    DatabaseService? database,
    RuleParserEngine? engine,
    BookAddService? addService,
  }) : this._(
          database ?? DatabaseService(),
          engine ?? RuleParserEngine(),
          addService,
        );

  BookshelfBooklistImportService._(
    DatabaseService db,
    this._engine,
    BookAddService? addService,
  )   : _sourceRepo = SourceRepository(db),
        _addService = addService ?? BookAddService(database: db, engine: _engine);

  String _compactReason(String text, {int maxLength = 96}) {
    final normalized = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.length <= maxLength) {
      return normalized;
    }
    return '${normalized.substring(0, maxLength)}…';
  }

  Future<BooklistImportSummary> importBySearching(
    List<BooklistItem> items, {
    void Function(BooklistImportProgress progress)? onProgress,
  }) async {
    final enabledSources = _getEnabledSources();
    if (enabledSources.isEmpty) {
      return const BooklistImportSummary(
        total: 0,
        added: 0,
        skipped: 0,
        failed: 0,
        errors: ['没有启用的书源，无法导入书单'],
      );
    }

    var added = 0;
    var skipped = 0;
    var failed = 0;
    final errors = <String>[];

    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      final keyword = item.name.trim();
      if (keyword.isEmpty) continue;

      SearchResult? best;
      String currentSource = '';
      final sourceRunErrors = <String>[];

      for (final source in enabledSources) {
        currentSource = source.bookSourceName;
        onProgress?.call(
          BooklistImportProgress(
            done: i,
            total: items.length,
            currentName: item.name,
            currentSource: currentSource,
          ),
        );

        try {
          final results = await _engine.search(source, keyword);
          if (results.isEmpty) continue;

          final candidate = _pickBestResult(results, item);
          if (candidate != null) {
            best = candidate;
            break;
          }
        } catch (e) {
          sourceRunErrors.add(
            '${source.bookSourceName}: ${_compactReason(e.toString())}',
          );
        }
      }

      if (best == null) {
        failed++;
        final base = '未找到：${item.name}${item.author.isNotEmpty ? ' - ${item.author}' : ''}';
        if (sourceRunErrors.isEmpty) {
          errors.add(base);
        } else {
          final preview = sourceRunErrors.take(2).join('；');
          final remain = sourceRunErrors.length - 2;
          final suffix = remain > 0 ? '；其余 $remain 个书源失败' : '';
          errors.add('$base（部分书源异常：$preview$suffix）');
        }
        continue;
      }

      final addResult = await _addService.addFromSearchResult(best);
      if (addResult.success) {
        added++;
      } else if (addResult.alreadyExists) {
        skipped++;
      } else {
        failed++;
        errors.add('导入失败：${item.name}（${addResult.message}）');
      }
    }

    onProgress?.call(
      BooklistImportProgress(
        done: items.length,
        total: items.length,
        currentName: '',
        currentSource: '',
      ),
    );

    return BooklistImportSummary(
      total: items.length,
      added: added,
      skipped: skipped,
      failed: failed,
      errors: errors,
    );
  }

  List<BookSource> _getEnabledSources() {
    final sources = _sourceRepo.getAllSources();
    final enabled = sources.where((s) => s.enabled == true).toList()
      ..sort((a, b) {
        if (a.weight != b.weight) return b.weight.compareTo(a.weight);
        return a.bookSourceName.compareTo(b.bookSourceName);
      });
    return enabled;
  }

  SearchResult? _pickBestResult(List<SearchResult> results, BooklistItem item) {
    String norm(String s) => s.trim().toLowerCase().replaceAll(' ', '');

    final targetName = norm(item.name);
    final targetAuthor = norm(item.author);

    int score(SearchResult r) {
      final name = norm(r.name);
      final author = norm(r.author);
      var s = 0;
      if (name == targetName) {
        s += 4;
      } else if (name.contains(targetName) || targetName.contains(name)) {
        s += 2;
      }
      if (targetAuthor.isNotEmpty) {
        if (author == targetAuthor) {
          s += 4;
        } else if (author.contains(targetAuthor) || targetAuthor.contains(author)) {
          s += 2;
        }
      }
      return s;
    }

    SearchResult? best;
    var bestScore = -1;
    for (final r in results) {
      final s = score(r);
      if (s > bestScore) {
        best = r;
        bestScore = s;
      }
    }

    // 没有明显匹配时，宁可不导入，避免乱加书
    if (bestScore <= 0) return null;
    return best;
  }
}
