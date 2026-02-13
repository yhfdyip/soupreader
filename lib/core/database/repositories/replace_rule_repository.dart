import 'dart:async';

import 'package:drift/drift.dart';

import '../../utils/legado_json.dart';
import '../../../features/replace/models/replace_rule.dart';
import '../database_service.dart';
import '../drift/source_drift_database.dart';

class ReplaceRuleRepository {
  final SourceDriftDatabase _driftDb;

  static final StreamController<List<ReplaceRule>> _watchController =
      StreamController<List<ReplaceRule>>.broadcast();
  static StreamSubscription<List<ReplaceRuleRecord>>? _watchSub;
  static final Map<int, ReplaceRule> _cacheById = <int, ReplaceRule>{};
  static bool _cacheReady = false;

  ReplaceRuleRepository(DatabaseService db) : _driftDb = db.driftDb {
    _ensureWatchStarted();
  }

  static Future<void> bootstrap(DatabaseService db) async {
    final repo = ReplaceRuleRepository(db);
    await repo._reloadCacheFromDb();
    repo._ensureWatchStarted();
  }

  void _ensureWatchStarted() {
    if (_watchSub != null) return;
    _watchSub =
        _driftDb.select(_driftDb.replaceRuleRecords).watch().listen((rows) {
      _updateCacheFromRows(rows);
    });
  }

  Future<void> _reloadCacheFromDb() async {
    final rows = await _driftDb.select(_driftDb.replaceRuleRecords).get();
    _updateCacheFromRows(rows);
  }

  static void _updateCacheFromRows(List<ReplaceRuleRecord> rows) {
    _cacheById
      ..clear()
      ..addEntries(rows.map((row) {
        final model = _rowToModel(row);
        return MapEntry(model.id, model);
      }));
    _cacheReady = true;
    _watchController.add(_cacheById.values.toList(growable: false));
  }

  List<ReplaceRule> getAllRules() {
    if (!_cacheReady) return const <ReplaceRule>[];
    return _cacheById.values.toList(growable: false);
  }

  Stream<List<ReplaceRule>> watchAllRules() async* {
    if (!_cacheReady) {
      await _reloadCacheFromDb();
    }
    yield getAllRules();
    yield* _watchController.stream;
  }

  List<ReplaceRule> getEnabledRulesSorted() {
    final list = getAllRules().where((r) => r.isEnabled).toList(growable: false);
    list.sort((a, b) => a.order.compareTo(b.order));
    return list;
  }

  Future<void> addRule(ReplaceRule rule) async {
    await _driftDb
        .into(_driftDb.replaceRuleRecords)
        .insertOnConflictUpdate(_modelToCompanion(rule));
  }

  Future<void> addRules(List<ReplaceRule> rules) async {
    if (rules.isEmpty) return;
    final companions =
        rules.map(_modelToCompanion).toList(growable: false);
    await _driftDb.batch((batch) {
      batch.insertAllOnConflictUpdate(_driftDb.replaceRuleRecords, companions);
    });
  }

  Future<void> updateRule(ReplaceRule rule) async {
    await addRule(rule);
  }

  Future<void> deleteRule(int id) async {
    await (_driftDb.delete(_driftDb.replaceRuleRecords)
          ..where((r) => r.id.equals(id)))
        .go();
  }

  Future<void> deleteDisabledRules() async {
    await (_driftDb.delete(_driftDb.replaceRuleRecords)
          ..where((r) => r.isEnabled.equals(false)))
        .go();
  }

  String exportToJson(List<ReplaceRule> rules) {
    final payload = rules.map((r) => r.toJson()).toList(growable: false);
    return LegadoJson.encode(payload);
  }

  ReplaceRuleRecordsCompanion _modelToCompanion(ReplaceRule rule) {
    final now = DateTime.now().millisecondsSinceEpoch;
    return ReplaceRuleRecordsCompanion.insert(
      id: Value(rule.id),
      name: Value(rule.name),
      groupName: Value(rule.group),
      pattern: Value(rule.pattern),
      replacement: Value(rule.replacement),
      scope: Value(rule.scope),
      scopeTitle: Value(rule.scopeTitle),
      scopeContent: Value(rule.scopeContent),
      excludeScope: Value(rule.excludeScope),
      isEnabled: Value(rule.isEnabled),
      isRegex: Value(rule.isRegex),
      timeoutMillisecond: Value(rule.timeoutMillisecond),
      orderValue: Value(rule.order),
      updatedAt: Value(now),
    );
  }

  static ReplaceRule _rowToModel(ReplaceRuleRecord row) {
    return ReplaceRule(
      id: row.id,
      name: row.name,
      group: row.groupName,
      pattern: row.pattern,
      replacement: row.replacement,
      scope: row.scope,
      scopeTitle: row.scopeTitle,
      scopeContent: row.scopeContent,
      excludeScope: row.excludeScope,
      isEnabled: row.isEnabled,
      isRegex: row.isRegex,
      timeoutMillisecond: row.timeoutMillisecond,
      order: row.orderValue,
    );
  }
}
