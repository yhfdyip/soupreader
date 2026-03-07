import 'package:shared_preferences/shared_preferences.dart';

typedef SharedPreferencesLoader = Future<SharedPreferences> Function();

abstract class InitializedPreferencesStore {
  bool? getBool(String key);

  int? getInt(String key);

  double? getDouble(String key);

  String? getString(String key);

  List<String>? getStringList(String key);

  Future<void> setBool(String key, bool value);

  Future<void> setInt(String key, int value);

  Future<void> setDouble(String key, double value);

  Future<void> setString(String key, String value);

  Future<void> setStringList(String key, List<String> value);

  Future<void> remove(String key);
}

abstract class PreferencesStore {
  Future<InitializedPreferencesStore> loadInitializedStore();

  Future<bool?> getBool(String key);

  Future<void> setBool(String key, bool value);

  Future<int?> getInt(String key);

  Future<void> setInt(String key, int value);

  Future<double?> getDouble(String key);

  Future<void> setDouble(String key, double value);

  Future<String?> getString(String key);

  Future<void> setString(String key, String value);

  Future<List<String>?> getStringList(String key);

  Future<void> setStringList(String key, List<String> value);

  Future<void> remove(String key);
}


final PreferencesStore defaultPreferencesStore = SharedPreferencesStore();

class SharedPreferencesStore implements PreferencesStore {
  SharedPreferencesStore({
    SharedPreferencesLoader? preferencesLoader,
  }) : _preferencesLoader = preferencesLoader ?? SharedPreferences.getInstance;

  final SharedPreferencesLoader _preferencesLoader;
  Future<SharedPreferences>? _cachedPrefs;

  Future<SharedPreferences> get _prefs {
    return _cachedPrefs ??= _preferencesLoader();
  }

  @override
  Future<InitializedPreferencesStore> loadInitializedStore() async {
    return SharedPreferencesInitializedStore(await _prefs);
  }

  @override
  Future<bool?> getBool(String key) async {
    return (await _prefs).getBool(key);
  }

  @override
  Future<void> setBool(String key, bool value) async {
    await (await _prefs).setBool(key, value);
  }

  @override
  Future<int?> getInt(String key) async {
    return (await _prefs).getInt(key);
  }

  @override
  Future<void> setInt(String key, int value) async {
    await (await _prefs).setInt(key, value);
  }

  @override
  Future<double?> getDouble(String key) async {
    return (await _prefs).getDouble(key);
  }

  @override
  Future<void> setDouble(String key, double value) async {
    await (await _prefs).setDouble(key, value);
  }

  @override
  Future<String?> getString(String key) async {
    return (await _prefs).getString(key);
  }

  @override
  Future<void> setString(String key, String value) async {
    await (await _prefs).setString(key, value);
  }

  @override
  Future<List<String>?> getStringList(String key) async {
    return (await _prefs).getStringList(key);
  }

  @override
  Future<void> setStringList(String key, List<String> value) async {
    await (await _prefs).setStringList(key, value);
  }

  @override
  Future<void> remove(String key) async {
    await (await _prefs).remove(key);
  }
}

class SharedPreferencesInitializedStore implements InitializedPreferencesStore {
  const SharedPreferencesInitializedStore(this._prefs);

  final SharedPreferences _prefs;

  @override
  bool? getBool(String key) {
    return _prefs.getBool(key);
  }

  @override
  int? getInt(String key) {
    return _prefs.getInt(key);
  }

  @override
  double? getDouble(String key) {
    return _prefs.getDouble(key);
  }

  @override
  String? getString(String key) {
    return _prefs.getString(key);
  }

  @override
  List<String>? getStringList(String key) {
    return _prefs.getStringList(key);
  }

  @override
  Future<void> setBool(String key, bool value) async {
    await _prefs.setBool(key, value);
  }

  @override
  Future<void> setInt(String key, int value) async {
    await _prefs.setInt(key, value);
  }

  @override
  Future<void> setDouble(String key, double value) async {
    await _prefs.setDouble(key, value);
  }

  @override
  Future<void> setString(String key, String value) async {
    await _prefs.setString(key, value);
  }

  @override
  Future<void> setStringList(String key, List<String> value) async {
    await _prefs.setStringList(key, value);
  }

  @override
  Future<void> remove(String key) async {
    await _prefs.remove(key);
  }
}
