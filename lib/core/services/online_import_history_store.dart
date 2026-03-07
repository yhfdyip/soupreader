import 'preferences_store.dart';

class OnlineImportHistoryStore {
  OnlineImportHistoryStore({
    PreferencesStore? preferencesStore,
  }) : _preferencesStore = preferencesStore ?? defaultPreferencesStore;

  static final RegExp _legacySplitPattern = RegExp(r'[\n,]');

  final PreferencesStore _preferencesStore;

  Future<List<String>> load(String key) async {
    final listValue = await _preferencesStore.getStringList(key);
    if (listValue != null) {
      return normalize(listValue);
    }
    final textValue = await _preferencesStore.getString(key);
    if (textValue != null && textValue.trim().isNotEmpty) {
      return normalize(textValue.split(_legacySplitPattern));
    }
    return <String>[];
  }

  Future<void> save(String key, Iterable<String> history) async {
    final normalized = normalize(history);
    await _preferencesStore.setStringList(key, normalized);
  }

  Future<void> push(String key, String value) async {
    final normalized = value.trim();
    if (normalized.isEmpty) {
      return;
    }
    final history = await load(key);
    history.remove(normalized);
    history.insert(0, normalized);
    await save(key, history);
  }

  List<String> normalize(Iterable<String> values) {
    final unique = <String>{};
    final normalized = <String>[];
    for (final value in values) {
      final trimmed = value.trim();
      if (trimmed.isEmpty || !unique.add(trimmed)) {
        continue;
      }
      normalized.add(trimmed);
    }
    return normalized;
  }
}
