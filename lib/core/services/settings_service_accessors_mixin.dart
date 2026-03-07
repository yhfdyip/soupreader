import 'package:flutter/foundation.dart';

import '../models/app_settings.dart';
import '../../features/reader/models/reading_settings.dart';
import 'settings_service_context.dart';
import 'settings_service_keys.dart';

mixin SettingsServiceAccessorsMixin on SettingsServiceContext {
  ReadingSettings get readingSettings => readingSettingsState;
  AppSettings get appSettings => appSettingsState;
  ValueListenable<ReadingSettings> get readingSettingsListenable =>
      readingSettingsNotifierState;
  ValueListenable<AppSettings> get appSettingsListenable =>
      appSettingsNotifierState;
  bool get readerChapterUrlOpenInBrowser =>
      prefsStoreState.getBool(settingsKeyReaderChapterUrlOpenInBrowser) ?? false;
  bool get enableReadRecord =>
      !isInitializedState ? true : prefsStoreState.getBool(settingsKeyEnableReadRecord) ?? true;
  bool get coverLoadOnlyWifi =>
      !isInitializedState ? false : prefsStoreState.getBool(settingsKeyLoadCoverOnlyWifi) ?? false;
  bool get useDefaultCover =>
      !isInitializedState ? false : prefsStoreState.getBool(settingsKeyUseDefaultCover) ?? false;
  bool get coverShowName =>
      !isInitializedState ? true : prefsStoreState.getBool(settingsKeyCoverShowName) ?? true;
  bool get coverShowAuthor =>
      !isInitializedState ? true : prefsStoreState.getBool(settingsKeyCoverShowAuthor) ?? true;
  bool get coverShowNameNight =>
      !isInitializedState ? true : prefsStoreState.getBool(settingsKeyCoverShowNameNight) ?? true;
  bool get coverShowAuthorNight =>
      !isInitializedState ? true : prefsStoreState.getBool(settingsKeyCoverShowAuthorNight) ?? true;
  bool get customWelcome =>
      !isInitializedState ? false : prefsStoreState.getBool(settingsKeyCustomWelcome) ?? false;
  bool get welcomeShowText =>
      !isInitializedState ? true : prefsStoreState.getBool(settingsKeyWelcomeShowText) ?? true;
  bool get welcomeShowIcon =>
      !isInitializedState ? true : prefsStoreState.getBool(settingsKeyWelcomeShowIcon) ?? true;
  bool get welcomeShowTextDark =>
      !isInitializedState ? true : prefsStoreState.getBool(settingsKeyWelcomeShowTextDark) ?? true;
  bool get welcomeShowIconDark =>
      !isInitializedState ? true : prefsStoreState.getBool(settingsKeyWelcomeShowIconDark) ?? true;

  String get coverRule =>
      !isInitializedState ? '' : (prefsStoreState.getString(settingsKeyCoverRule) ?? '').trim();
  String get defaultCoverPath => !isInitializedState
      ? ''
      : (prefsStoreState.getString(settingsKeyDefaultCoverPath) ?? '').trim();
  String get defaultCoverDarkPath => !isInitializedState
      ? ''
      : (prefsStoreState.getString(settingsKeyDefaultCoverDarkPath) ?? '').trim();
  String get welcomeImagePath => !isInitializedState
      ? ''
      : (prefsStoreState.getString(settingsKeyWelcomeImagePath) ?? '').trim();
  String get welcomeImageDarkPath => !isInitializedState
      ? ''
      : (prefsStoreState.getString(settingsKeyWelcomeImageDarkPath) ?? '').trim();

  String? getReaderFontFolderPath() {
    if (!isInitializedState) return null;
    final value = prefsStoreState.getString(settingsKeyReaderFontFolderPath)?.trim();
    if (value == null || value.isEmpty) return null;
    return value;
  }

  Future<void> saveReaderFontFolderPath(String? path) async {
    if (!isInitializedState) return;
    final normalized = (path ?? '').trim();
    if (normalized.isEmpty) {
      await prefsStoreState.remove(settingsKeyReaderFontFolderPath);
      return;
    }
    await prefsStoreState.setString(settingsKeyReaderFontFolderPath, normalized);
  }

  String? getReaderCustomFontPath() {
    if (!isInitializedState) return null;
    final value = prefsStoreState.getString(settingsKeyReaderCustomFontPath)?.trim();
    if (value == null || value.isEmpty) return null;
    return value;
  }

  Future<void> saveReaderCustomFontPath(String? path) async {
    if (!isInitializedState) return;
    final normalized = (path ?? '').trim();
    if (normalized.isEmpty) {
      await prefsStoreState.remove(settingsKeyReaderCustomFontPath);
      return;
    }
    await prefsStoreState.setString(settingsKeyReaderCustomFontPath, normalized);
  }

}
