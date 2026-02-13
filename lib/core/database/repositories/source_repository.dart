import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../features/source/models/book_source.dart';
import '../../utils/legado_json.dart';
import '../database_service.dart';
import '../drift/source_drift_database.dart';
import '../drift/source_drift_service.dart';
import '../entities/book_entity.dart';

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
    return _cacheByUrl[url];
  }

  String? getRawJsonByUrl(String url) {
    if (!_cacheReady) {
      unawaited(_reloadCacheFromDb());
    }
    return _rawJsonByUrl[url];
  }

  Future<void> addSource(BookSource source) async {
    await _driftDb
        .into(_driftDb.sourceRecords)
        .insertOnConflictUpdate(_sourceToCompanion(source));
  }

  Future<void> addSources(List<BookSource> sources) async {
    if (sources.isEmpty) return;
    final companions = sources
        .where((source) => source.bookSourceUrl.trim().isNotEmpty)
        .map(_sourceToCompanion)
        .toList(growable: false);
    if (companions.isEmpty) return;

    await _driftDb.batch((batch) {
      batch.insertAllOnConflictUpdate(_driftDb.sourceRecords, companions);
    });
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

    final source = BookSource.fromJson(map);
    final url = source.bookSourceUrl.trim();
    if (url.isEmpty) {
      throw const FormatException('bookSourceUrl 不能为空');
    }

    final normalizedRawJson = LegadoJson.encode(map);
    final companion = _sourceToCompanion(
      source,
      rawJsonOverride: normalizedRawJson,
    );

    await _driftDb.transaction(() async {
      if (originalUrl != null &&
          originalUrl.trim().isNotEmpty &&
          originalUrl.trim() != url) {
        await (_driftDb.delete(_driftDb.sourceRecords)
              ..where((tbl) => tbl.bookSourceUrl.equals(originalUrl.trim())))
            .go();
      }
      await _driftDb.into(_driftDb.sourceRecords).insertOnConflictUpdate(
            companion,
          );
    });
  }

  Future<void> deleteSource(String url) async {
    await (_driftDb.delete(_driftDb.sourceRecords)
          ..where((tbl) => tbl.bookSourceUrl.equals(url)))
        .go();
  }

  Future<void> deleteDisabledSources() async {
    await (_driftDb.delete(_driftDb.sourceRecords)
          ..where((tbl) => tbl.enabled.equals(false)))
        .go();
  }

  List<BookSource> fromEntities(Iterable<BookSourceEntity> entities) {
    return entities.map(_entityToSource).toList(growable: false);
  }

  SourceRecordsCompanion _sourceToCompanion(
    BookSource source, {
    String? rawJsonOverride,
  }) {
    final normalizedRawJson =
        rawJsonOverride ?? LegadoJson.encode(source.toJson());
    final now = DateTime.now().millisecondsSinceEpoch;
    return SourceRecordsCompanion.insert(
      bookSourceUrl: source.bookSourceUrl,
      bookSourceName: Value(source.bookSourceName),
      bookSourceGroup: Value(source.bookSourceGroup),
      bookSourceType: Value(source.bookSourceType),
      enabled: Value(source.enabled),
      enabledExplore: Value(source.enabledExplore),
      enabledCookieJar: Value(source.enabledCookieJar),
      weight: Value(source.weight),
      customOrder: Value(source.customOrder),
      respondTime: Value(source.respondTime),
      header: Value(source.header),
      loginUrl: Value(source.loginUrl),
      bookSourceComment: Value(source.bookSourceComment),
      lastUpdateTime: Value(source.lastUpdateTime),
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

  BookSource _entityToSource(BookSourceEntity entity) {
    final raw = entity.rawJson;
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
        // fallthrough
      }
    }

    return BookSource.fromJson({
      'bookSourceUrl': entity.bookSourceUrl,
      'bookSourceName': entity.bookSourceName,
      'bookSourceGroup': entity.bookSourceGroup,
      'bookSourceType': entity.bookSourceType,
      'customOrder': 0,
      'enabled': entity.enabled,
      'enabledExplore': true,
      'enabledCookieJar': true,
      'respondTime': 180000,
      'weight': entity.weight,
      'header': entity.header,
      'loginUrl': entity.loginUrl,
      'bookSourceComment': entity.bookSourceComment,
      'lastUpdateTime': entity.lastUpdateTime?.millisecondsSinceEpoch ?? 0,
      'ruleSearch': _decodeRule(entity.ruleSearchJson),
      'ruleBookInfo': _decodeRule(entity.ruleBookInfoJson),
      'ruleToc': _decodeRule(entity.ruleTocJson),
      'ruleContent': _decodeRule(entity.ruleContentJson),
    });
  }

  Map<String, dynamic>? _decodeRule(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final decoded = json.decode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) {
        return decoded.map((key, value) => MapEntry('$key', value));
      }
    } catch (_) {
      return null;
    }
    return null;
  }
}
