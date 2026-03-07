import '../../../core/services/preferences_store.dart';

class SourceEditRuleHelpStore {
  static const String _prefsKey = 'source_edit_rule_help_shown_v1';

  SourceEditRuleHelpStore({
    PreferencesStore? preferencesStore,
  }) : _preferencesStore = preferencesStore ?? defaultPreferencesStore;

  final PreferencesStore _preferencesStore;

  Future<bool> isShown() async {
    return await _preferencesStore.getBool(_prefsKey) ?? false;
  }

  Future<void> markShown() async {
    await _preferencesStore.setBool(_prefsKey, true);
  }
}
