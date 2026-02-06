import '../../../core/database/database_service.dart';
import '../../../core/database/repositories/replace_rule_repository.dart';
import '../../../core/database/repositories/source_repository.dart';
import '../../source/models/book_source.dart';
import '../models/replace_rule.dart';
import 'replace_rule_engine.dart';

class ReplaceRuleService {
  final ReplaceRuleRepository _repo;
  final SourceRepository _sourceRepo;
  final ReplaceRuleEngine _engine = ReplaceRuleEngine();

  ReplaceRuleService(DatabaseService db)
      : _repo = ReplaceRuleRepository(db),
        _sourceRepo = SourceRepository(db);

  List<ReplaceRule> getEffectiveRules({
    required String bookName,
    required String? sourceUrl,
  }) {
    String? sourceName;
    if (sourceUrl != null && sourceUrl.trim().isNotEmpty) {
      final BookSource? source = _sourceRepo.getSourceByUrl(sourceUrl);
      sourceName = source?.bookSourceName;
    }
    final all = _repo.getAllRules();
    return _engine.effectiveRules(
      all,
      bookName: bookName,
      sourceName: sourceName,
      sourceUrl: sourceUrl,
    );
  }

  Future<String> applyTitle(
    String title, {
    required String bookName,
    required String? sourceUrl,
  }) async {
    final rules = getEffectiveRules(bookName: bookName, sourceUrl: sourceUrl);
    return _engine.applyToTitle(title, rules);
  }

  Future<String> applyContent(
    String content, {
    required String bookName,
    required String? sourceUrl,
  }) async {
    final rules = getEffectiveRules(bookName: bookName, sourceUrl: sourceUrl);
    return _engine.applyToContent(content, rules);
  }
}
