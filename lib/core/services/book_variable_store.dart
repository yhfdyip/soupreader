import 'package:shared_preferences/shared_preferences.dart';

/// 书籍变量存储（按书籍链接持久化）
///
/// 键格式：`bookVariable_{bookUrl}`
class BookVariableStore {
  static const String _prefix = 'bookVariable_';

  static String _normalizeBookKey(String bookKey) {
    return bookKey.trim();
  }

  static String _variableKey(String bookKey) {
    return '$_prefix${_normalizeBookKey(bookKey)}';
  }

  static Future<String?> getVariable(String bookKey) async {
    final key = _normalizeBookKey(bookKey);
    if (key.isEmpty) return null;

    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_variableKey(key));
  }

  static Future<void> putVariable(String bookKey, String? variable) async {
    final key = _normalizeBookKey(bookKey);
    if (key.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    if (variable == null) {
      await prefs.remove(_variableKey(key));
      return;
    }

    await prefs.setString(_variableKey(key), variable);
  }

  static Future<void> removeVariable(String bookKey) async {
    final key = _normalizeBookKey(bookKey);
    if (key.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_variableKey(key));
  }
}
