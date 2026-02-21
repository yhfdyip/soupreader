import 'package:shared_preferences/shared_preferences.dart';

/// 书源变量存储（按书源键持久化）
///
/// 键格式：`sourceVariable_{bookSourceUrl}`
class SourceVariableStore {
  static const String _prefix = 'sourceVariable_';

  static String _normalizeSourceKey(String sourceKey) {
    return sourceKey.trim();
  }

  static String _variableKey(String sourceKey) {
    return '$_prefix${_normalizeSourceKey(sourceKey)}';
  }

  static Future<String?> getVariable(String sourceKey) async {
    final key = _normalizeSourceKey(sourceKey);
    if (key.isEmpty) return null;

    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_variableKey(key));
  }

  static Future<void> putVariable(String sourceKey, String? variable) async {
    final key = _normalizeSourceKey(sourceKey);
    if (key.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    if (variable == null) {
      await prefs.remove(_variableKey(key));
      return;
    }

    await prefs.setString(_variableKey(key), variable);
  }

  static Future<void> removeVariable(String sourceKey) async {
    final key = _normalizeSourceKey(sourceKey);
    if (key.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_variableKey(key));
  }
}
