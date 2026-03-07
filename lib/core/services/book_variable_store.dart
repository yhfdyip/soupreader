import 'preferences_store.dart';

/// 书籍变量存储（按书籍链接持久化）
///
/// 键格式：`bookVariable_{bookUrl}`
class BookVariableStore {
  static const String _prefix = 'bookVariable_';
  static PreferencesStore _preferencesStore = defaultPreferencesStore;

  static void debugReplacePreferencesStore(PreferencesStore store) {
    _preferencesStore = store;
  }

  static void debugResetPreferencesStore() {
    _preferencesStore = defaultPreferencesStore;
  }

  static String _normalizeBookKey(String bookKey) {
    return bookKey.trim();
  }

  static String _variableKey(String bookKey) {
    return '$_prefix${_normalizeBookKey(bookKey)}';
  }

  static Future<String?> getVariable(String bookKey) async {
    final key = _normalizeBookKey(bookKey);
    if (key.isEmpty) return null;

    return _preferencesStore.getString(_variableKey(key));
  }

  static Future<void> putVariable(String bookKey, String? variable) async {
    final key = _normalizeBookKey(bookKey);
    if (key.isEmpty) return;

    if (variable == null) {
      await _preferencesStore.remove(_variableKey(key));
      return;
    }

    await _preferencesStore.setString(_variableKey(key), variable);
  }

  static Future<void> removeVariable(String bookKey) async {
    final key = _normalizeBookKey(bookKey);
    if (key.isEmpty) return;

    await _preferencesStore.remove(_variableKey(key));
  }
}
