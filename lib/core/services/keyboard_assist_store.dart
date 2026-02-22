import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// 辅助按键配置项（对齐 legado `KeyboardAssist` 语义）。
///
/// - 主键语义：`type + key`
/// - 排序语义：按 `serialNo` 升序
class KeyboardAssistEntry {
  const KeyboardAssistEntry({
    this.type = 0,
    required this.key,
    required this.value,
    this.serialNo = 0,
  });

  final int type;
  final String key;
  final String value;
  final int serialNo;

  KeyboardAssistEntry copyWith({
    int? type,
    String? key,
    String? value,
    int? serialNo,
  }) {
    return KeyboardAssistEntry(
      type: type ?? this.type,
      key: key ?? this.key,
      value: value ?? this.value,
      serialNo: serialNo ?? this.serialNo,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'type': type,
      'key': key,
      'value': value,
      'serialNo': serialNo,
    };
  }

  static KeyboardAssistEntry? fromJson(Map<String, dynamic> json) {
    final key = (json['key'] ?? '').toString().trim();
    if (key.isEmpty) return null;
    final value = (json['value'] ?? '').toString();
    return KeyboardAssistEntry(
      type: _asInt(json['type']) ?? 0,
      key: key,
      value: value,
      serialNo: _asInt(json['serialNo']) ?? 0,
    );
  }

  static int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim());
    return null;
  }
}

class KeyboardAssistStore {
  static const String _prefsKey = 'keyboard_assists';

  Future<List<KeyboardAssistEntry>> loadAll({int type = 0}) async {
    final all = await _loadAllTypes();
    final list = all.where((item) => item.type == type).toList(growable: false)
      ..sort((a, b) {
        final serialCompare = a.serialNo.compareTo(b.serialNo);
        if (serialCompare != 0) return serialCompare;
        return a.key.compareTo(b.key);
      });
    return list;
  }

  Future<void> upsert({
    required String key,
    required String value,
    int type = 0,
    KeyboardAssistEntry? editing,
  }) async {
    final normalizedKey = key.trim();
    if (normalizedKey.isEmpty) return;

    final targetType = editing?.type ?? type;
    final all = await _loadAllTypes();
    final next = <KeyboardAssistEntry>[];
    for (final item in all) {
      if (editing != null &&
          item.type == editing.type &&
          item.key == editing.key) {
        continue;
      }
      if (item.type == targetType && item.key == normalizedKey) {
        continue;
      }
      next.add(item);
    }

    final nextSerialNo =
        editing?.serialNo ?? (_maxSerialNo(next, targetType) + 1);
    next.add(
      KeyboardAssistEntry(
        type: targetType,
        key: normalizedKey,
        value: value,
        serialNo: nextSerialNo,
      ),
    );
    await _saveAllTypes(next);
  }

  Future<void> delete(KeyboardAssistEntry target) async {
    final all = await _loadAllTypes();
    all.removeWhere(
        (item) => item.type == target.type && item.key == target.key);
    await _saveAllTypes(all);
  }

  int _maxSerialNo(List<KeyboardAssistEntry> entries, int type) {
    var max = 0;
    for (final item in entries) {
      if (item.type != type) continue;
      if (item.serialNo > max) {
        max = item.serialNo;
      }
    }
    return max;
  }

  Future<List<KeyboardAssistEntry>> _loadAllTypes() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey)?.trim();
    if (raw == null || raw.isEmpty) return <KeyboardAssistEntry>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return <KeyboardAssistEntry>[];
      final entries = <KeyboardAssistEntry>[];
      for (final item in decoded) {
        if (item is! Map) continue;
        final map = item.map(
          (key, value) => MapEntry(key.toString(), value),
        );
        final entry = KeyboardAssistEntry.fromJson(map);
        if (entry == null) continue;
        entries.add(entry);
      }
      return entries;
    } catch (_) {
      return <KeyboardAssistEntry>[];
    }
  }

  Future<void> _saveAllTypes(List<KeyboardAssistEntry> entries) async {
    final prefs = await SharedPreferences.getInstance();
    if (entries.isEmpty) {
      await prefs.remove(_prefsKey);
      return;
    }
    final encoded = jsonEncode(entries.map((item) => item.toJson()).toList());
    await prefs.setString(_prefsKey, encoded);
  }
}
