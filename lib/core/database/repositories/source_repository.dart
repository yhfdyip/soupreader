import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../features/source/models/book_source.dart';
import '../../utils/legado_json.dart';
import '../database_service.dart';
import '../drift/source_drift_database.dart';
import '../drift/source_drift_service.dart';

/// 书源存储仓库（drift）
///
/// 对外尽量保持旧接口，避免上层大面积改动：
/// - 同步读取来自内存缓存
/// - 所有写入走 drift
/// - watchAllSources 提供流式更新
class SourceRepository {
  final SourceDriftDatabase _driftDb;

  static final StreamController<List<BookSource>> _watchController =
      StreamController<List<BookSource>>.broadcast();
  static StreamSubscription<List<SourceRecord>>? _watchSub;

  static final Map<String, BookSource> _cacheByUrl = <String, BookSource>{};
  static final Map<String, String> _rawJsonByUrl = <String, String>{};
  static bool _cacheReady = false;

  SourceRepository(DatabaseService _) : _driftDb = SourceDriftService().db {
    _ensureWatchStarted();
  }

  static String _normalizeUrlKey(String? raw) {
    return (raw ?? '').trim();
  }

  static BookSource _normalizeSource(BookSource source) {
    final normalizedUrl = _normalizeUrlKey(source.bookSourceUrl);
    if (normalizedUrl == source.bookSourceUrl) return source;
    return source.copyWith(bookSourceUrl: normalizedUrl);
  }

  static Future<void> bootstrap(DatabaseService db) async {
    final repo = SourceRepository(db);
    await repo._reloadCacheFromDb();
    repo._ensureWatchStarted();
  }

  void _ensureWatchStarted() {
    if (_watchSub != null) return;
    _watchSub = _driftDb.select(_driftDb.sourceRecords).watch().listen((rows) {
      _updateCacheFromRows(rows);
    });
  }

  Future<void> _reloadCacheFromDb() async {
    final rows = await _driftDb.select(_driftDb.sourceRecords).get();
    _updateCacheFromRows(rows);
  }

  static void _updateCacheFromRows(List<SourceRecord> rows) {
    _cacheByUrl
      ..clear()
      ..addEntries(rows.map((row) {
        final source = _rowToSource(row);
        return MapEntry(source.bookSourceUrl, source);
      }));

    _rawJsonByUrl
      ..clear()
      ..addEntries(rows.where((row) {
        final raw = row.rawJson;
        return raw != null && raw.trim().isNotEmpty;
      }).map((row) => MapEntry(row.bookSourceUrl, row.rawJson!.trim())));

    _emitCacheSnapshot();
  }

  static void _emitCacheSnapshot() {
    _cacheReady = true;
    _watchController.add(_cacheByUrl.values.toList(growable: false));
  }

  List<BookSource> getAllSources() {
    if (!_cacheReady) {
      unawaited(_reloadCacheFromDb());
      return const <BookSource>[];
    }
    return _cacheByUrl.values.toList(growable: false);
  }

  Stream<List<BookSource>> watchAllSources() async* {
    if (!_cacheReady) {
      await _reloadCacheFromDb();
    }
    yield getAllSources();
    yield* _watchController.stream;
  }

  BookSource? getSourceByUrl(String url) {
    if (!_cacheReady) {
      unawaited(_reloadCacheFromDb());
    }
    final key = _normalizeUrlKey(url);
    if (key.isEmpty) return null;
    return _cacheByUrl[key];
  }

  String? getRawJsonByUrl(String url) {
    if (!_cacheReady) {
      unawaited(_reloadCacheFromDb());
    }
    final key = _normalizeUrlKey(url);
    if (key.isEmpty) return null;
    return _rawJsonByUrl[key];
  }

  Future<void> addSource(BookSource source) async {
    final normalizedSource = _normalizeSource(source);
    final url = _normalizeUrlKey(normalizedSource.bookSourceUrl);
    if (url.isEmpty) {
      throw const FormatException('bookSourceUrl 不能为空');
    }
    await _driftDb
        .into(_driftDb.sourceRecords)
        .insertOnConflictUpdate(_sourceToCompanion(normalizedSource));
    _cacheByUrl[url] = normalizedSource;
    _rawJsonByUrl[url] = LegadoJson.encode(normalizedSource.toJson());
    _emitCacheSnapshot();
  }

  Future<void> addSources(List<BookSource> sources) async {
    if (sources.isEmpty) return;
    final normalizedSources = sources
        .map(_normalizeSource)
        .where((source) => _normalizeUrlKey(source.bookSourceUrl).isNotEmpty)
        .toList(growable: false);
    final companions =
        normalizedSources.map(_sourceToCompanion).toList(growable: false);
    if (companions.isEmpty) return;

    await _driftDb.batch((batch) {
      batch.insertAllOnConflictUpdate(_driftDb.sourceRecords, companions);
    });

    for (final source in normalizedSources) {
      final url = _normalizeUrlKey(source.bookSourceUrl);
      if (url.isEmpty) continue;
      _cacheByUrl[url] = source;
      _rawJsonByUrl[url] = LegadoJson.encode(source.toJson());
    }
    _emitCacheSnapshot();
  }

  Future<void> updateSource(BookSource source) async {
    await addSource(source);
  }

  /// 以「原始 JSON」形式保存书源（编辑器/对标 legado 推荐用法）
  Future<void> upsertSourceRawJson({
    String? originalUrl,
    required String rawJson,
  }) async {
    final decoded = json.decode(rawJson);
    if (decoded is! Map) {
      throw const FormatException('书源 JSON 必须是对象（Map）');
    }
    final map = decoded is Map<String, dynamic>
        ? decoded
        : decoded.map((key, value) => MapEntry('$key', value));

    final source = _normalizeSource(BookSource.fromJson(map));
    final url = _normalizeUrlKey(source.bookSourceUrl);
    if (url.isEmpty) {
      throw const FormatException('bookSourceUrl 不能为空');
    }

    map['bookSourceUrl'] = url;
    final normalizedRawJson = LegadoJson.encode(map);
    final companion = _sourceToCompanion(
      source,
      rawJsonOverride: normalizedRawJson,
    );
    final normalizedOriginalUrl = _normalizeUrlKey(originalUrl);

    await _driftDb.transaction(() async {
      if (normalizedOriginalUrl.isNotEmpty && normalizedOriginalUrl != url) {
        await (_driftDb.delete(_driftDb.sourceRecords)
              ..where((tbl) => tbl.bookSourceUrl.equals(normalizedOriginalUrl)))
            .go();
      }
      await _driftDb.into(_driftDb.sourceRecords).insertOnConflictUpdate(
            companion,
          );
    });

    if (normalizedOriginalUrl.isNotEmpty && normalizedOriginalUrl != url) {
      _cacheByUrl.remove(normalizedOriginalUrl);
      _rawJsonByUrl.remove(normalizedOriginalUrl);
    }
    _cacheByUrl[url] = source;
    _rawJsonByUrl[url] = normalizedRawJson;
    _emitCacheSnapshot();
  }

  Future<void> deleteSource(String url) async {
    final normalizedUrl = _normalizeUrlKey(url);
    if (normalizedUrl.isEmpty) return;
    await (_driftDb.delete(_driftDb.sourceRecords)
          ..where((tbl) => tbl.bookSourceUrl.equals(normalizedUrl)))
        .go();
    _cacheByUrl.remove(normalizedUrl);
    _rawJsonByUrl.remove(normalizedUrl);
    _emitCacheSnapshot();
  }

  Future<void> deleteDisabledSources() async {
    await (_driftDb.delete(_driftDb.sourceRecords)
          ..where((tbl) => tbl.enabled.equals(false)))
        .go();
    await _reloadCacheFromDb();
  }

  SourceRecordsCompanion _sourceToCompanion(
    BookSource source, {
    String? rawJsonOverride,
  }) {
    final normalizedSource = _normalizeSource(source);
    final url = _normalizeUrlKey(normalizedSource.bookSourceUrl);
    if (url.isEmpty) {
      throw const FormatException('bookSourceUrl 不能为空');
    }
    final normalizedRawJson =
        rawJsonOverride ?? LegadoJson.encode(normalizedSource.toJson());
    final now = DateTime.now().millisecondsSinceEpoch;
    return SourceRecordsCompanion.insert(
      bookSourceUrl: url,
      bookSourceName: Value(normalizedSource.bookSourceName),
      bookSourceGroup: Value(normalizedSource.bookSourceGroup),
      bookSourceType: Value(normalizedSource.bookSourceType),
      enabled: Value(normalizedSource.enabled),
      enabledExplore: Value(normalizedSource.enabledExplore),
      enabledCookieJar: Value(normalizedSource.enabledCookieJar),
      weight: Value(normalizedSource.weight),
      customOrder: Value(normalizedSource.customOrder),
      respondTime: Value(normalizedSource.respondTime),
      header: Value(normalizedSource.header),
      loginUrl: Value(normalizedSource.loginUrl),
      bookSourceComment: Value(normalizedSource.bookSourceComment),
      lastUpdateTime: Value(normalizedSource.lastUpdateTime),
      rawJson: Value(normalizedRawJson),
      updatedAt: Value(now),
    );
  }

  static BookSource _rowToSource(SourceRecord row) {
    final raw = row.rawJson;
    if (raw != null && raw.trim().isNotEmpty) {
      try {
        final decoded = json.decode(raw);
        if (decoded is Map<String, dynamic>) {
          return BookSource.fromJson(decoded);
        }
        if (decoded is Map) {
          return BookSource.fromJson(
            decoded.map((key, value) => MapEntry('$key', value)),
          );
        }
      } catch (_) {
        // fallback
      }
    }

    return BookSource.fromJson({
      'bookSourceUrl': row.bookSourceUrl,
      'bookSourceName': row.bookSourceName,
      'bookSourceGroup': row.bookSourceGroup,
      'bookSourceType': row.bookSourceType,
      'customOrder': row.customOrder,
      'enabled': row.enabled,
      'enabledExplore': row.enabledExplore,
      'enabledCookieJar': row.enabledCookieJar ?? true,
      'respondTime': row.respondTime,
      'weight': row.weight,
      'header': row.header,
      'loginUrl': row.loginUrl,
      'bookSourceComment': row.bookSourceComment,
      'lastUpdateTime': row.lastUpdateTime,
    });
  }
}
