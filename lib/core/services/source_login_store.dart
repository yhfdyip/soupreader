import 'dart:convert';

import 'preferences_store.dart';

/// 书源登录态存储（按书源键缓存登录信息）
///
/// - loginHeader: 用于请求时自动附加的头部信息
/// - loginInfo:   登录表单或脚本使用的用户信息文本
class SourceLoginStore {
  static const String _headerPrefix = 'loginHeader_';
  static const String _infoPrefix = 'userInfo_';
  static PreferencesStore _preferencesStore = defaultPreferencesStore;

  static void debugReplacePreferencesStore(PreferencesStore store) {
    _preferencesStore = store;
  }

  static void debugResetPreferencesStore() {
    _preferencesStore = defaultPreferencesStore;
  }

  static String _normalizeSourceKey(String sourceKey) {
    return sourceKey.trim();
  }

  static String _headerKey(String sourceKey) {
    return '$_headerPrefix${_normalizeSourceKey(sourceKey)}';
  }

  static String _infoKey(String sourceKey) {
    return '$_infoPrefix${_normalizeSourceKey(sourceKey)}';
  }

  static Future<Map<String, String>?> getLoginHeaderMap(
      String sourceKey) async {
    final key = _normalizeSourceKey(sourceKey);
    if (key.isEmpty) return null;

    final text = (await _preferencesStore.getString(_headerKey(key)))?.trim();
    if (text == null || text.isEmpty) return null;

    try {
      final decoded = jsonDecode(text);
      if (decoded is! Map) return null;
      final out = <String, String>{};
      decoded.forEach((k, v) {
        if (k == null || v == null) return;
        final headerKey = k.toString().trim();
        if (headerKey.isEmpty) return;
        out[headerKey] = v.toString();
      });
      return out.isEmpty ? null : out;
    } catch (_) {
      return null;
    }
  }

  static Future<String?> getLoginHeaderText(String sourceKey) async {
    final key = _normalizeSourceKey(sourceKey);
    if (key.isEmpty) return null;

    final text = await _preferencesStore.getString(_headerKey(key));
    if (text == null || text.trim().isEmpty) return null;
    return text;
  }

  static Future<void> putLoginHeaderMap(
    String sourceKey,
    Map<String, String> headers,
  ) async {
    final key = _normalizeSourceKey(sourceKey);
    if (key.isEmpty) return;

    final normalized = <String, String>{};
    headers.forEach((k, v) {
      final headerKey = k.trim();
      if (headerKey.isEmpty) return;
      normalized[headerKey] = v;
    });

    if (normalized.isEmpty) {
      await _preferencesStore.remove(_headerKey(key));
      return;
    }

    await _preferencesStore.setString(_headerKey(key), jsonEncode(normalized));
  }

  static Future<void> putLoginHeaderJson(
      String sourceKey, String headerJson) async {
    final key = _normalizeSourceKey(sourceKey);
    if (key.isEmpty) return;

    final text = headerJson.trim();
    if (text.isEmpty) {
      await _preferencesStore.remove(_headerKey(key));
      return;
    }

    final decoded = jsonDecode(text);
    if (decoded is! Map) {
      throw const FormatException('登录请求头必须是 JSON 对象');
    }

    final normalized = <String, String>{};
    decoded.forEach((k, v) {
      if (k == null || v == null) return;
      final headerKey = k.toString().trim();
      if (headerKey.isEmpty) return;
      normalized[headerKey] = v.toString();
    });

    if (normalized.isEmpty) {
      await _preferencesStore.remove(_headerKey(key));
      return;
    }

    await _preferencesStore.setString(_headerKey(key), jsonEncode(normalized));
  }

  static Future<void> removeLoginHeader(String sourceKey) async {
    final key = _normalizeSourceKey(sourceKey);
    if (key.isEmpty) return;

    await _preferencesStore.remove(_headerKey(key));
  }

  static Future<String?> getLoginInfo(String sourceKey) async {
    final key = _normalizeSourceKey(sourceKey);
    if (key.isEmpty) return null;

    final value = await _preferencesStore.getString(_infoKey(key));
    if (value == null || value.trim().isEmpty) return null;
    return value;
  }

  static Future<void> putLoginInfo(String sourceKey, String? info) async {
    final key = _normalizeSourceKey(sourceKey);
    if (key.isEmpty) return;

    final text = info?.trim();
    if (text == null || text.isEmpty) {
      await _preferencesStore.remove(_infoKey(key));
      return;
    }

    await _preferencesStore.setString(_infoKey(key), info!);
  }

  static Future<void> removeLoginInfo(String sourceKey) async {
    final key = _normalizeSourceKey(sourceKey);
    if (key.isEmpty) return;

    await _preferencesStore.remove(_infoKey(key));
  }
}
