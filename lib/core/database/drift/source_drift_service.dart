import 'source_drift_database.dart';

class SourceDriftService {
  static final SourceDriftService _instance = SourceDriftService._internal();

  factory SourceDriftService() => _instance;

  SourceDriftService._internal();

  SourceDriftDatabase? _db;

  Future<void> init() async {
    _db ??= SourceDriftDatabase();
  }

  SourceDriftDatabase get db {
    final database = _db;
    if (database == null) {
      throw StateError('SourceDriftService 未初始化，请先调用 init()');
    }
    return database;
  }

  bool get isInitialized => _db != null;

  Future<void> clearAll() async {
    if (_db == null) return;
    await _db!.transaction(() async {
      await _db!.delete(_db!.sourceRecords).go();
      await _db!.delete(_db!.rssSourceRecords).go();
      await _db!.delete(_db!.rssArticleRecords).go();
      await _db!.delete(_db!.rssReadRecordRecords).go();
      await _db!.delete(_db!.bookRecords).go();
      await _db!.delete(_db!.chapterRecords).go();
      await _db!.delete(_db!.replaceRuleRecords).go();
      await _db!.delete(_db!.appKeyValueRecords).go();
      await _db!.delete(_db!.bookmarkRecords).go();
    });
  }

  Future<void> close() async {
    if (_db == null) return;
    await _db!.close();
    _db = null;
  }
}
