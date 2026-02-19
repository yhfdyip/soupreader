import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../features/rss/models/rss_source.dart';
import '../../../features/rss/services/rss_source_filter_helper.dart';
import '../../utils/legado_json.dart';
import '../database_service.dart';
import '../drift/source_drift_database.dart';

/// RSS 源仓库（对齐 legado `RssSourceDao` 核心语义）
class RssSourceRepository {
  final SourceDriftDatabase _driftDb;

  static final StreamController<List<RssSource>> _watchController =
      StreamController<List<RssSource>>.broadcast();
  static StreamSubscription<List<RssSourceRecord>>? _watchSub;
  static final Map<String, RssSource> _cacheByUrl = <String, RssSource>{};
  static final Map<String, String> _rawJsonByUrl = <String, String>{};
  static bool _cacheReady = false;

  RssSourceRepository(DatabaseService db) : _driftDb = db.driftDb {
    _ensureWatchStarted();
  }

  static Future<void> bootstrap(DatabaseService db) async {
    final repo = RssSourceRepository(db);
    await repo._reloadCacheFromDb();
    repo._ensureWatchStarted();
  }

  static String _normalizeUrlKey(String? raw) {
    return (raw ?? '').trim();
  }

  static RssSource _normalizeSource(RssSource source) {
    final normalizedUrl = _normalizeUrlKey(source.sourceUrl);
    if (normalizedUrl == source.sourceUrl) return source;
    return source.copyWith(sourceUrl: normalizedUrl);
  }

  static Map<String, dynamic> _decodeRawJsonToMap(String? rawJson) {
    final raw = rawJson?.trim() ?? '';
    if (raw.isEmpty) return <String, dynamic>{};
    try {
      final decoded = json.decode(raw);
      if (decoded is Map<String, dynamic>) return Map<String, dynamic>.of(decoded);
      if (decoded is Map) {
        return decoded.map(
          (key, value) => MapEntry(key.toString(), value),
        );
      }
    } catch (_) {
      // ignore and fallback to empty map
    }
    return <String, dynamic>{};
  }

  static String _buildMergedRawJson({
    required RssSource source,
    String? existingRawJson,
  }) {
    final normalized = _normalizeSource(source);
    final merged = _decodeRawJsonToMap(existingRawJson);
    merged.addAll(normalized.toJson());
    merged['sourceUrl'] = normalized.sourceUrl;
    return LegadoJson.encode(merged);
  }

  void _ensureWatchStarted() {
    if (_watchSub != null) return;
    final query = _driftDb.select(_driftDb.rssSourceRecords)
      ..orderBy([
        (tbl) => OrderingTerm.asc(tbl.customOrder),
      ]);
    _watchSub = query.watch().listen((rows) {
      _updateCacheFromRows(rows);
    });
  }

  Future<void> _reloadCacheFromDb() async {
    final query = _driftDb.select(_driftDb.rssSourceRecords)
      ..orderBy([
        (tbl) => OrderingTerm.asc(tbl.customOrder),
      ]);
    final rows = await query.get();
    _updateCacheFromRows(rows);
  }

  static void _updateCacheFromRows(List<RssSourceRecord> rows) {
    _cacheByUrl
      ..clear()
      ..addEntries(rows.map((row) {
        final source = _rowToModel(row);
        return MapEntry(source.sourceUrl, source);
      }));

    _rawJsonByUrl
      ..clear()
      ..addEntries(rows.where((row) {
        final raw = row.rawJson;
        return raw != null && raw.trim().isNotEmpty;
      }).map((row) {
        return MapEntry(row.sourceUrl, row.rawJson!.trim());
      }));

    _emitCacheSnapshot();
  }

  static void _emitCacheSnapshot() {
    _cacheReady = true;
    final sources = RssSourceFilterHelper.sortByCustomOrder(
      _cacheByUrl.values.toList(growable: false),
    );
    _watchController.add(sources);
  }

  List<RssSource> getAllSources() {
    if (!_cacheReady) {
      unawaited(_reloadCacheFromDb());
      return const <RssSource>[];
    }
    return RssSourceFilterHelper.sortByCustomOrder(_cacheByUrl.values);
  }

  Stream<List<RssSource>> watchAllSources() async* {
    if (!_cacheReady) {
      await _reloadCacheFromDb();
    }
    yield getAllSources();
    yield* _watchController.stream;
  }

  RssSource? getByKey(String key) {
    if (!_cacheReady) {
      unawaited(_reloadCacheFromDb());
    }
    final normalized = _normalizeUrlKey(key);
    if (normalized.isEmpty) return null;
    return _cacheByUrl[normalized];
  }

  String? getRawJsonByUrl(String sourceUrl) {
    if (!_cacheReady) {
      unawaited(_reloadCacheFromDb());
    }
    final normalized = _normalizeUrlKey(sourceUrl);
    if (normalized.isEmpty) return null;
    return _rawJsonByUrl[normalized];
  }

  int get size => _cacheByUrl.length;

  int get minOrder {
    if (_cacheByUrl.isEmpty) return 0;
    return _cacheByUrl.values
        .map((source) => source.customOrder)
        .reduce((left, right) => left < right ? left : right);
  }

  int get maxOrder {
    if (_cacheByUrl.isEmpty) return 0;
    return _cacheByUrl.values
        .map((source) => source.customOrder)
        .reduce((left, right) => left > right ? left : right);
  }

  bool has(String key) {
    final normalized = _normalizeUrlKey(key);
    if (normalized.isEmpty) return false;
    return _cacheByUrl.containsKey(normalized);
  }

  Future<void> addSource(RssSource source) async {
    final normalizedSource = _normalizeSource(source);
    final url = _normalizeUrlKey(normalizedSource.sourceUrl);
    if (url.isEmpty) {
      throw const FormatException('sourceUrl 不能为空');
    }
    final mergedRawJson = _buildMergedRawJson(
      source: normalizedSource,
      existingRawJson: _rawJsonByUrl[url],
    );
    await _driftDb
        .into(_driftDb.rssSourceRecords)
        .insertOnConflictUpdate(
          _modelToCompanion(
            normalizedSource,
            rawJsonOverride: mergedRawJson,
          ),
        );
    _cacheByUrl[url] = normalizedSource;
    _rawJsonByUrl[url] = mergedRawJson;
    _emitCacheSnapshot();
  }

  Future<void> addSources(List<RssSource> sources) async {
    if (sources.isEmpty) return;
    final normalizedSources = sources
        .map(_normalizeSource)
        .where((source) => _normalizeUrlKey(source.sourceUrl).isNotEmpty)
        .toList(growable: false);
    if (normalizedSources.isEmpty) return;

    final mergedRawByUrl = <String, String>{};
    final companions = normalizedSources.map((source) {
      final url = _normalizeUrlKey(source.sourceUrl);
      final mergedRaw = _buildMergedRawJson(
        source: source,
        existingRawJson: _rawJsonByUrl[url],
      );
      mergedRawByUrl[url] = mergedRaw;
      return _modelToCompanion(
        source,
        rawJsonOverride: mergedRaw,
      );
    }).toList(growable: false);
    await _driftDb.batch((batch) {
      batch.insertAllOnConflictUpdate(_driftDb.rssSourceRecords, companions);
    });

    for (final source in normalizedSources) {
      final url = _normalizeUrlKey(source.sourceUrl);
      _cacheByUrl[url] = source;
      _rawJsonByUrl[url] = mergedRawByUrl[url]!;
    }
    _emitCacheSnapshot();
  }

  Future<void> updateSource(RssSource source) async {
    await addSource(source);
  }

  Future<void> updateSources(List<RssSource> sources) async {
    await addSources(sources);
  }

  Future<void> upsertSourceRawJson({
    String? originalUrl,
    required String rawJson,
  }) async {
    final decoded = json.decode(rawJson);
    if (decoded is! Map) {
      throw const FormatException('RSS 源 JSON 必须是对象（Map）');
    }
    final map = decoded is Map<String, dynamic>
        ? decoded
        : decoded.map((key, value) => MapEntry('$key', value));

    final source = _normalizeSource(RssSource.fromJson(map));
    final url = _normalizeUrlKey(source.sourceUrl);
    if (url.isEmpty) {
      throw const FormatException('sourceUrl 不能为空');
    }

    map['sourceUrl'] = url;
    final normalizedRawJson = LegadoJson.encode(map);
    final companion = _modelToCompanion(
      source,
      rawJsonOverride: normalizedRawJson,
    );
    final normalizedOriginalUrl = _normalizeUrlKey(originalUrl);

    await _driftDb.transaction(() async {
      if (normalizedOriginalUrl.isNotEmpty && normalizedOriginalUrl != url) {
        await (_driftDb.delete(_driftDb.rssSourceRecords)
              ..where((tbl) => tbl.sourceUrl.equals(normalizedOriginalUrl)))
            .go();
      }
      await _driftDb
          .into(_driftDb.rssSourceRecords)
          .insertOnConflictUpdate(companion);
    });

    if (normalizedOriginalUrl.isNotEmpty && normalizedOriginalUrl != url) {
      _cacheByUrl.remove(normalizedOriginalUrl);
      _rawJsonByUrl.remove(normalizedOriginalUrl);
    }
    _cacheByUrl[url] = source;
    _rawJsonByUrl[url] = normalizedRawJson;
    _emitCacheSnapshot();
  }

  Future<void> deleteSource(String sourceUrl) async {
    final normalized = _normalizeUrlKey(sourceUrl);
    if (normalized.isEmpty) return;
    await (_driftDb.delete(_driftDb.rssSourceRecords)
          ..where((tbl) => tbl.sourceUrl.equals(normalized)))
        .go();
    _cacheByUrl.remove(normalized);
    _rawJsonByUrl.remove(normalized);
    _emitCacheSnapshot();
  }

  Future<void> deleteSources(Iterable<String> sourceUrls) async {
    final normalized =
        sourceUrls.map(_normalizeUrlKey).where((url) => url.isNotEmpty).toSet();
    if (normalized.isEmpty) return;
    await (_driftDb.delete(_driftDb.rssSourceRecords)
          ..where((tbl) => tbl.sourceUrl.isIn(normalized)))
        .go();
    for (final url in normalized) {
      _cacheByUrl.remove(url);
      _rawJsonByUrl.remove(url);
    }
    _emitCacheSnapshot();
  }

  Future<void> deleteDefault() async {
    final targets = _cacheByUrl.values.where((source) {
      return (source.sourceGroup ?? '').trim() == 'legado';
    }).toList(growable: false);
    if (targets.isEmpty) return;
    await deleteSources(targets.map((source) => source.sourceUrl));
  }

  Future<void> enable(String sourceUrl, bool enabled) async {
    final normalized = _normalizeUrlKey(sourceUrl);
    if (normalized.isEmpty) return;
    final existing = _cacheByUrl[normalized];
    if (existing == null) return;
    final updated = existing.copyWith(enabled: enabled);
    final mergedRawJson = _buildMergedRawJson(
      source: updated,
      existingRawJson: _rawJsonByUrl[normalized],
    );
    await _driftDb
        .into(_driftDb.rssSourceRecords)
        .insertOnConflictUpdate(
          _modelToCompanion(
            updated,
            rawJsonOverride: mergedRawJson,
          ),
        );
    _cacheByUrl[normalized] = updated;
    _rawJsonByUrl[normalized] = mergedRawJson;
    _emitCacheSnapshot();
  }

  Stream<List<RssSource>> flowAll() => watchAllSources();

  Stream<List<RssSource>> flowSearch(String key) {
    return watchAllSources().map(
      (sources) => RssSourceFilterHelper.filterSearch(sources, key),
    );
  }

  Stream<List<RssSource>> flowGroupSearch(String key) {
    return watchAllSources().map(
      (sources) => RssSourceFilterHelper.filterGroupSearch(sources, key),
    );
  }

  Stream<List<RssSource>> flowEnabled() {
    return watchAllSources().map(
      (sources) => RssSourceFilterHelper.filterEnabled(sources),
    );
  }

  Stream<List<RssSource>> flowDisabled() {
    return watchAllSources().map(RssSourceFilterHelper.filterDisabled);
  }

  Stream<List<RssSource>> flowLogin() {
    return watchAllSources().map(RssSourceFilterHelper.filterLogin);
  }

  Stream<List<RssSource>> flowNoGroup() {
    return watchAllSources().map(RssSourceFilterHelper.filterNoGroup);
  }

  Stream<List<RssSource>> flowEnabledSearch(String searchKey) {
    return watchAllSources().map(
      (sources) =>
          RssSourceFilterHelper.filterEnabled(sources, searchKey: searchKey),
    );
  }

  Stream<List<RssSource>> flowEnabledByGroup(String searchKey) {
    return watchAllSources().map(
      (sources) => RssSourceFilterHelper.filterEnabledByGroup(
        sources,
        searchKey,
      ),
    );
  }

  List<String> get allGroupsUnProcessed {
    final groups = <String>{};
    for (final source in getAllSources()) {
      final raw = source.sourceGroup?.trim();
      if (raw == null || raw.isEmpty) continue;
      groups.add(raw);
    }
    return groups.toList(growable: false);
  }

  Stream<List<String>> flowGroupsUnProcessed() {
    return watchAllSources().map((sources) {
      final groups = <String>{};
      for (final source in sources) {
        final raw = source.sourceGroup?.trim();
        if (raw == null || raw.isEmpty) continue;
        groups.add(raw);
      }
      return groups.toList(growable: false);
    });
  }

  Stream<List<String>> flowEnabledGroupsUnProcessed() {
    return flowEnabled().map((sources) {
      final groups = <String>{};
      for (final source in sources) {
        final raw = source.sourceGroup?.trim();
        if (raw == null || raw.isEmpty) continue;
        groups.add(raw);
      }
      return groups.toList(growable: false);
    });
  }

  List<String> allGroups() {
    return RssSourceFilterHelper.dealGroups(allGroupsUnProcessed);
  }

  Stream<List<String>> flowGroups() {
    return flowGroupsUnProcessed().map(
      RssSourceFilterHelper.dealGroups,
    );
  }

  Stream<List<String>> flowEnabledGroups() {
    return flowEnabledGroupsUnProcessed().map(
      RssSourceFilterHelper.dealGroups,
    );
  }

  List<RssSource> getNoGroup() {
    return RssSourceFilterHelper.filterNoGroup(getAllSources());
  }

  List<RssSource> getByGroup(String group) {
    final key = group.trim();
    if (key.isEmpty) return const <RssSource>[];
    return getAllSources().where((source) {
      final raw = source.sourceGroup;
      if (raw == null || raw.isEmpty) return false;
      return raw.contains(key);
    }).toList(growable: false);
  }

  RssSourceRecordsCompanion _modelToCompanion(
    RssSource source, {
    String? rawJsonOverride,
  }) {
    final normalized = _normalizeSource(source);
    final url = _normalizeUrlKey(normalized.sourceUrl);
    if (url.isEmpty) {
      throw const FormatException('sourceUrl 不能为空');
    }
    final rawJson = rawJsonOverride ?? LegadoJson.encode(normalized.toJson());
    final now = DateTime.now().millisecondsSinceEpoch;
    return RssSourceRecordsCompanion.insert(
      sourceUrl: url,
      sourceName: Value(normalized.sourceName),
      sourceIcon: Value(normalized.sourceIcon),
      sourceGroup: Value(normalized.sourceGroup),
      sourceComment: Value(normalized.sourceComment),
      enabled: Value(normalized.enabled),
      loginUrl: Value(normalized.loginUrl),
      sortUrl: Value(normalized.sortUrl),
      singleUrl: Value(normalized.singleUrl),
      customOrder: Value(normalized.customOrder),
      lastUpdateTime: Value(normalized.lastUpdateTime),
      rawJson: Value(rawJson),
      updatedAt: Value(now),
    );
  }

  static RssSource _rowToModel(RssSourceRecord row) {
    final raw = row.rawJson;
    if (raw != null && raw.trim().isNotEmpty) {
      try {
        final decoded = json.decode(raw);
        if (decoded is Map<String, dynamic>) {
          return RssSource.fromJson(decoded);
        }
        if (decoded is Map) {
          return RssSource.fromJson(
            decoded.map((key, value) => MapEntry('$key', value)),
          );
        }
      } catch (_) {
        // ignore and fallback
      }
    }

    return RssSource(
      sourceUrl: row.sourceUrl,
      sourceName: row.sourceName,
      sourceIcon: row.sourceIcon ?? '',
      sourceGroup: row.sourceGroup,
      sourceComment: row.sourceComment,
      enabled: row.enabled,
      loginUrl: row.loginUrl,
      sortUrl: row.sortUrl,
      singleUrl: row.singleUrl,
      customOrder: row.customOrder,
      lastUpdateTime: row.lastUpdateTime,
    );
  }
}
