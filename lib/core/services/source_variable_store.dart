import 'preferences_store.dart';

/// 书源变量存储（按书源键持久化）
///
/// 键格式：`sourceVariable_{bookSourceUrl}`
class SourceVariableStore {
  static const String _prefix = 'sourceVariable_';
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

  static String _variableKey(String sourceKey) {
    return '$_prefix${_normalizeSourceKey(sourceKey)}';
  }

  static Future<String?> getVariable(String sourceKey) async {
    final key = _normalizeSourceKey(sourceKey);
    if (key.isEmpty) return null;

    return _preferencesStore.getString(_variableKey(key));
  }

  static Future<void> putVariable(String sourceKey, String? variable) async {
    final key = _normalizeSourceKey(sourceKey);
    if (key.isEmpty) return;

    if (variable == null) {
      await _preferencesStore.remove(_variableKey(key));
      return;
    }

    await _preferencesStore.setString(_variableKey(key), variable);
  }

  static Future<void> removeVariable(String sourceKey) async {
    final key = _normalizeSourceKey(sourceKey);
    if (key.isEmpty) return;

    await _preferencesStore.remove(_variableKey(key));
  }
}
