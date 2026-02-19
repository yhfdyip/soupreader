import 'package:drift/drift.dart';

import '../../../features/rss/models/rss_article.dart';
import '../../../features/rss/models/rss_read_record.dart';
import '../database_service.dart';
import '../drift/source_drift_database.dart';

/// RSS 文章仓储（对齐 legado `RssArticleDao`）
class RssArticleRepository {
  final SourceDriftDatabase _driftDb;

  RssArticleRepository(DatabaseService db) : _driftDb = db.driftDb;

  static Future<void> bootstrap(DatabaseService db) async {
    // 与其它仓储保持一致：预留启动阶段挂载点。
    RssArticleRepository(db);
  }

  static String _normalizeText(String? raw) => (raw ?? '').trim();

  Future<RssArticle?> get(String origin, String link) async {
    final normalizedOrigin = _normalizeText(origin);
    final normalizedLink = _normalizeText(link);
    if (normalizedOrigin.isEmpty || normalizedLink.isEmpty) return null;
    final row = await (_driftDb.select(_driftDb.rssArticleRecords)
          ..where((tbl) =>
              tbl.origin.equals(normalizedOrigin) &
              tbl.link.equals(normalizedLink)))
        .getSingleOrNull();
    if (row == null) return null;
    return _rowToArticle(row);
  }

  Stream<List<RssArticle>> flowByOriginSort(String origin, String sort) {
    final normalizedOrigin = _normalizeText(origin);
    final normalizedSort = _normalizeText(sort);
    if (normalizedOrigin.isEmpty) {
      return Stream<List<RssArticle>>.value(const <RssArticle>[]);
    }

    final query = _driftDb.customSelect(
      '''
      select
        t1.origin as origin,
        t1.sort as sort,
        t1.title as title,
        t1.order_value as order_value,
        t1.link as link,
        t1.pub_date as pub_date,
        t1.description as description,
        t1.content as content,
        t1.image as image,
        t1.group_name as group_name,
        t1.variable as variable,
        ifnull(t2.read, 0) as read
      from rss_article_records as t1
      left join rss_read_record_records as t2
        on t1.link = t2.record
      where t1.origin = ? and t1.sort = ?
      order by t1.order_value desc
      ''',
      variables: <Variable<Object>>[
        Variable.withString(normalizedOrigin),
        Variable.withString(normalizedSort),
      ],
      readsFrom: <ResultSetImplementation<Table, dynamic>>{
        _driftDb.rssArticleRecords,
        _driftDb.rssReadRecordRecords,
      },
    );

    return query.watch().map(
          (rows) => rows
              .map(
                (row) => _customRowToArticle(row),
              )
              .toList(growable: false),
        );
  }

  Future<void> insert(Iterable<RssArticle> articles) async {
    final list = articles.toList(growable: false);
    if (list.isEmpty) return;
    final companions = list.map(_articleToCompanion).toList(growable: false);
    await _driftDb.batch((batch) {
      batch.insertAllOnConflictUpdate(_driftDb.rssArticleRecords, companions);
    });
  }

  Future<void> append(Iterable<RssArticle> articles) async {
    final list = articles.toList(growable: false);
    if (list.isEmpty) return;
    final companions = list.map(_articleToCompanion).toList(growable: false);
    await _driftDb.batch((batch) {
      batch.insertAll(
        _driftDb.rssArticleRecords,
        companions,
        mode: InsertMode.insertOrIgnore,
      );
    });
  }

  Future<void> update(Iterable<RssArticle> articles) async {
    await insert(articles);
  }

  Future<void> clearOld(String origin, String sort, int order) async {
    final normalizedOrigin = _normalizeText(origin);
    final normalizedSort = _normalizeText(sort);
    if (normalizedOrigin.isEmpty) return;
    await (_driftDb.delete(_driftDb.rssArticleRecords)
          ..where((tbl) =>
              tbl.origin.equals(normalizedOrigin) &
              tbl.sort.equals(normalizedSort) &
              tbl.orderValue.isSmallerThanValue(order)))
        .go();
  }

  Future<void> updateOrigin(String origin, String oldOrigin) async {
    final normalizedOrigin = _normalizeText(origin);
    final normalizedOld = _normalizeText(oldOrigin);
    if (normalizedOrigin.isEmpty || normalizedOld.isEmpty) return;
    if (normalizedOrigin == normalizedOld) return;
    await (_driftDb.update(_driftDb.rssArticleRecords)
          ..where((tbl) => tbl.origin.equals(normalizedOld)))
        .write(
      RssArticleRecordsCompanion(
        origin: Value(normalizedOrigin),
      ),
    );
  }

  Future<void> deleteByOrigin(String origin) async {
    final normalizedOrigin = _normalizeText(origin);
    if (normalizedOrigin.isEmpty) return;
    await (_driftDb.delete(_driftDb.rssArticleRecords)
          ..where((tbl) => tbl.origin.equals(normalizedOrigin)))
        .go();
  }

  RssArticleRecordsCompanion _articleToCompanion(RssArticle article) {
    final now = DateTime.now().millisecondsSinceEpoch;
    return RssArticleRecordsCompanion.insert(
      origin: article.origin,
      link: article.link,
      sort: Value(article.sort),
      title: Value(article.title),
      orderValue: Value(article.order),
      pubDate: Value(article.pubDate),
      description: Value(article.description),
      content: Value(article.content),
      image: Value(article.image),
      groupName: Value(article.group),
      variable: Value(article.variable),
      updatedAt: Value(now),
    );
  }

  static RssArticle _rowToArticle(RssArticleRecord row) {
    return RssArticle(
      origin: row.origin,
      sort: row.sort,
      title: row.title,
      order: row.orderValue,
      link: row.link,
      pubDate: row.pubDate,
      description: row.description,
      content: row.content,
      image: row.image,
      group: row.groupName,
      read: false,
      variable: row.variable,
    );
  }

  static RssArticle _customRowToArticle(QueryRow row) {
    final data = row.data;
    return RssArticle(
      origin: (data['origin'] ?? '').toString(),
      sort: (data['sort'] ?? '').toString(),
      title: (data['title'] ?? '').toString(),
      order: _parseInt(data['order_value']),
      link: (data['link'] ?? '').toString(),
      pubDate: _toNullableString(data['pub_date']),
      description: _toNullableString(data['description']),
      content: _toNullableString(data['content']),
      image: _toNullableString(data['image']),
      group: (_toNullableString(data['group_name']) ?? '默认分组'),
      read: _parseBool(data['read'], fallback: false),
      variable: _toNullableString(data['variable']),
    );
  }

  static int _parseInt(dynamic raw) {
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    if (raw is String) return int.tryParse(raw.trim()) ?? 0;
    return 0;
  }

  static bool _parseBool(dynamic raw, {required bool fallback}) {
    if (raw is bool) return raw;
    if (raw is num) return raw != 0;
    if (raw is String) {
      final text = raw.trim().toLowerCase();
      if (text == 'true' || text == '1') return true;
      if (text == 'false' || text == '0') return false;
    }
    return fallback;
  }

  static String? _toNullableString(dynamic raw) {
    if (raw == null) return null;
    final text = raw.toString();
    return text;
  }
}

/// RSS 阅读记录仓储（对齐 legado `RssReadRecordDao`）
class RssReadRecordRepository {
  final SourceDriftDatabase _driftDb;

  RssReadRecordRepository(DatabaseService db) : _driftDb = db.driftDb;

  static Future<void> bootstrap(DatabaseService db) async {
    RssReadRecordRepository(db);
  }

  Future<void> insertRecord(Iterable<RssReadRecord> records) async {
    final list = records.toList(growable: false);
    if (list.isEmpty) return;
    final companions = list
        .map(
          (record) => _recordToCompanion(record),
        )
        .toList(growable: false);
    await _driftDb.batch((batch) {
      batch.insertAll(
        _driftDb.rssReadRecordRecords,
        companions,
        mode: InsertMode.insertOrIgnore,
      );
    });
  }

  Future<List<RssReadRecord>> getRecords() async {
    final query = _driftDb.select(_driftDb.rssReadRecordRecords)
      ..orderBy([
        (tbl) => OrderingTerm.desc(tbl.readTime),
      ]);
    final rows = await query.get();
    return rows.map(_rowToModel).toList(growable: false);
  }

  Future<int> countRecords() async {
    final countExp = _driftDb.rssReadRecordRecords.record.count();
    final query = _driftDb.selectOnly(_driftDb.rssReadRecordRecords)
      ..addColumns([countExp]);
    final row = await query.getSingleOrNull();
    if (row == null) return 0;
    return row.read(countExp) ?? 0;
  }

  Future<void> deleteAllRecord() async {
    await _driftDb.delete(_driftDb.rssReadRecordRecords).go();
  }

  Future<RssReadRecord?> getByRecord(String record) async {
    final key = record.trim();
    if (key.isEmpty) return null;
    final row = await (_driftDb.select(_driftDb.rssReadRecordRecords)
          ..where((tbl) => tbl.record.equals(key)))
        .getSingleOrNull();
    if (row == null) return null;
    return _rowToModel(row);
  }

  RssReadRecordRecordsCompanion _recordToCompanion(RssReadRecord record) {
    final now = DateTime.now().millisecondsSinceEpoch;
    return RssReadRecordRecordsCompanion.insert(
      record: record.record,
      title: Value(record.title),
      readTime: Value(record.readTime),
      read: Value(record.read),
      updatedAt: Value(now),
    );
  }

  static RssReadRecord _rowToModel(RssReadRecordRecord row) {
    return RssReadRecord(
      record: row.record,
      title: row.title,
      readTime: row.readTime,
      read: row.read,
    );
  }
}
