import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../features/source/models/book_source.dart';
import '../../utils/legado_json.dart';
import '../database_service.dart';
import '../drift/source_drift_database.dart';
import '../drift/source_drift_service.dart';
import '../entities/book_entity.dart';

class SourceMigrationResult {
  final bool migrated;
  final int total;
  final int imported;
  final int invalid;
  final int duplicateResolved;

  const SourceMigrationResult({
    required this.migrated,
    required this.total,
    required this.imported,
    required this.invalid,
    required this.duplicateResolved,
  });
}

class SourceHiveToDriftMigrator {
  static const String _flagKey = 'source_migrated_to_drift_v1';
  static const String _resultKey = 'source_migrated_to_drift_v1_result';

  final DatabaseService _db;
  final SourceDriftService _driftService;

  SourceHiveToDriftMigrator({
    required DatabaseService databaseService,
    SourceDriftService? driftService,
  })  : _db = databaseService,
        _driftService = driftService ?? SourceDriftService();

  Future<SourceMigrationResult> migrateIfNeeded() async {
    final alreadyMigrated = _db.settingsBox.get(_flagKey) == true;
    if (alreadyMigrated) {
      return const SourceMigrationResult(
        migrated: false,
        total: 0,
        imported: 0,
        invalid: 0,
        duplicateResolved: 0,
      );
    }

    final entities = _db.sourcesBox.values.toList(growable: false);
    final byUrl = <String, ({BookSource source, String rawJson})>{};

    var invalid = 0;
    var duplicateResolved = 0;

    for (final entity in entities) {
      final parsed = _entityToSource(entity);
      if (parsed == null) {
        invalid++;
        continue;
      }
      final url = parsed.source.bookSourceUrl.trim();
      final name = parsed.source.bookSourceName.trim();
      if (url.isEmpty || name.isEmpty) {
        invalid++;
        continue;
      }

      final prev = byUrl[url];
      if (prev == null) {
        byUrl[url] = parsed;
        continue;
      }

      duplicateResolved++;
      byUrl[url] = _preferMoreComplete(prev, parsed);
    }

    final driftDb = _driftService.db;
    if (byUrl.isNotEmpty) {
      final rows = byUrl.values
          .map((e) => _toCompanion(source: e.source, rawJson: e.rawJson))
          .toList(growable: false);
      await driftDb.batch((batch) {
        batch.insertAllOnConflictUpdate(driftDb.sourceRecords, rows);
      });
    }

    final result = SourceMigrationResult(
      migrated: true,
      total: entities.length,
      imported: byUrl.length,
      invalid: invalid,
      duplicateResolved: duplicateResolved,
    );

    await _db.settingsBox.put(_flagKey, true);
    await _db.settingsBox.put(_resultKey, {
      'migratedAt': DateTime.now().toIso8601String(),
      'total': result.total,
      'imported': result.imported,
      'invalid': result.invalid,
      'duplicateResolved': result.duplicateResolved,
    });

    return result;
  }

  ({BookSource source, String rawJson}) _preferMoreComplete(
    ({BookSource source, String rawJson}) current,
    ({BookSource source, String rawJson}) next,
  ) {
    final currentScore = _score(current.source, current.rawJson);
    final nextScore = _score(next.source, next.rawJson);
    if (nextScore > currentScore) return next;
    if (nextScore < currentScore) return current;

    return next.source.lastUpdateTime >= current.source.lastUpdateTime
        ? next
        : current;
  }

  int _score(BookSource source, String rawJson) {
    var score = 0;
    if (rawJson.trim().isNotEmpty) score += 20;
    if (source.searchUrl?.trim().isNotEmpty == true) score += 5;
    if (source.ruleSearch != null) score += 5;
    if (source.exploreUrl?.trim().isNotEmpty == true) score += 3;
    if (source.ruleExplore != null) score += 3;
    if (source.ruleBookInfo != null) score += 2;
    if (source.ruleToc != null) score += 1;
    if (source.ruleContent != null) score += 1;
    return score;
  }

  ({BookSource source, String rawJson})? _entityToSource(
      BookSourceEntity entity) {
    final raw = entity.rawJson;
    if (raw != null && raw.trim().isNotEmpty) {
      try {
        final decoded = json.decode(raw);
        if (decoded is Map<String, dynamic>) {
          final source = BookSource.fromJson(decoded);
          return (source: source, rawJson: LegadoJson.encode(decoded));
        }
        if (decoded is Map) {
          final map = decoded.map((key, value) => MapEntry('$key', value));
          final source = BookSource.fromJson(map);
          return (source: source, rawJson: LegadoJson.encode(map));
        }
      } catch (_) {
        // fallthrough to legacy mapping
      }
    }

    final map = <String, dynamic>{
      'bookSourceUrl': entity.bookSourceUrl,
      'bookSourceName': entity.bookSourceName,
      'bookSourceGroup': entity.bookSourceGroup,
      'bookSourceType': entity.bookSourceType,
      'customOrder': 0,
      'enabled': entity.enabled,
      'enabledExplore': true,
      'enabledCookieJar': true,
      'header': entity.header,
      'loginUrl': entity.loginUrl,
      'bookSourceComment': entity.bookSourceComment,
      'lastUpdateTime': entity.lastUpdateTime?.millisecondsSinceEpoch ?? 0,
      'respondTime': 180000,
      'weight': entity.weight,
      'searchUrl': null,
      'exploreUrl': null,
      'ruleSearch': _decodeRuleJson(entity.ruleSearchJson),
      'ruleBookInfo': _decodeRuleJson(entity.ruleBookInfoJson),
      'ruleToc': _decodeRuleJson(entity.ruleTocJson),
      'ruleContent': _decodeRuleJson(entity.ruleContentJson),
    };

    try {
      final source = BookSource.fromJson(map);
      return (source: source, rawJson: LegadoJson.encode(map));
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic>? _decodeRuleJson(String? jsonText) {
    if (jsonText == null || jsonText.trim().isEmpty) return null;
    try {
      final decoded = json.decode(jsonText);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) {
        return decoded.map((key, value) => MapEntry('$key', value));
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  SourceRecordsCompanion _toCompanion({
    required BookSource source,
    required String rawJson,
  }) {
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
      rawJson: Value(rawJson),
      updatedAt: Value(now),
    );
  }
}
