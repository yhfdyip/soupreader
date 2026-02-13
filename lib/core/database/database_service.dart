import 'dart:convert';

import 'package:drift/drift.dart';

import 'drift/source_drift_database.dart';
import 'drift/source_drift_service.dart';

/// 数据库服务（统一走 Drift）
class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  final SourceDriftService _driftService = SourceDriftService();
  bool _isInitialized = false;

  final Map<String, dynamic> _settingsCache = <String, dynamic>{};
  late final DriftSettingsBox _settingsBox = DriftSettingsBox._(this);

  Future<void> init() async {
    if (_isInitialized) return;
    await _driftService.init();
    await _reloadSettingsCache();
    _isInitialized = true;
  }

  SourceDriftDatabase get driftDb {
    _checkInitialized();
    return _driftService.db;
  }

  DriftSettingsBox get settingsBox {
    _checkInitialized();
    return _settingsBox;
  }

  dynamic getSetting(
    String key, {
    dynamic defaultValue,
  }) {
    _checkInitialized();
    if (_settingsCache.containsKey(key)) {
      final value = _settingsCache[key];
      return value ?? defaultValue;
    }
    return defaultValue;
  }

  Future<void> putSetting(String key, dynamic value) async {
    _checkInitialized();
    final db = _driftService.db;
    final now = DateTime.now().millisecondsSinceEpoch;
    final encoded = value == null ? null : jsonEncode(value);
    await db.into(db.appKeyValueRecords).insertOnConflictUpdate(
          AppKeyValueRecordsCompanion.insert(
            key: key,
            value: Value(encoded),
            updatedAt: Value(now),
          ),
        );
    _settingsCache[key] = value;
  }

  Future<void> deleteSetting(String key) async {
    _checkInitialized();
    final db = _driftService.db;
    await (db.delete(db.appKeyValueRecords)
          ..where((tbl) => tbl.key.equals(key)))
        .go();
    _settingsCache.remove(key);
  }

  Future<void> clearAll() async {
    _checkInitialized();
    await _driftService.clearAll();
    _settingsCache.clear();
  }

  Future<void> close() async {
    await _driftService.close();
    _settingsCache.clear();
    _isInitialized = false;
  }

  Future<void> _reloadSettingsCache() async {
    _settingsCache.clear();
    final db = _driftService.db;
    final rows = await db.select(db.appKeyValueRecords).get();
    for (final row in rows) {
      final raw = row.value?.trim();
      if (raw == null || raw.isEmpty) {
        _settingsCache[row.key] = null;
        continue;
      }
      try {
        _settingsCache[row.key] = jsonDecode(raw);
      } catch (_) {
        _settingsCache[row.key] = raw;
      }
    }
  }

  void _checkInitialized() {
    if (!_isInitialized) {
      throw StateError('DatabaseService 未初始化，请先调用 init()');
    }
  }
}

/// 兼容旧调用形态：`settingsBox.get/put/delete`
class DriftSettingsBox {
  final DatabaseService _service;

  DriftSettingsBox._(this._service);

  dynamic get(String key, {dynamic defaultValue}) {
    return _service.getSetting(key, defaultValue: defaultValue);
  }

  Future<void> put(String key, dynamic value) {
    return _service.putSetting(key, value);
  }

  Future<void> delete(String key) {
    return _service.deleteSetting(key);
  }
}
