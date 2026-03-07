import 'package:flutter/foundation.dart';

import '../config/migration_exclusions.dart';
import 'settings_service_context.dart';
import 'settings_service_keys.dart';

mixin SettingsServiceUiPreferencesMixin on SettingsServiceContext {
  bool getTocUiUseReplace({bool fallback = false}) {
    if (!isInitializedState) return fallback;
    return prefsStoreState.getBool(settingsKeyTocUiUseReplace) ?? fallback;
  }

  Future<void> saveTocUiUseReplace(bool enabled) async {
    if (!isInitializedState) return;
    await prefsStoreState.setBool(settingsKeyTocUiUseReplace, enabled);
  }

  bool getTocUiLoadWordCount({bool fallback = true}) {
    if (!isInitializedState) return fallback;
    return prefsStoreState.getBool(settingsKeyTocUiLoadWordCount) ?? fallback;
  }

  Future<void> saveTocUiLoadWordCount(bool enabled) async {
    if (!isInitializedState) return;
    await prefsStoreState.setBool(settingsKeyTocUiLoadWordCount, enabled);
  }

  bool getChangeSourceLoadToc({bool fallback = false}) {
    if (!isInitializedState) return fallback;
    return prefsStoreState.getBool(settingsKeyChangeSourceLoadToc) ?? fallback;
  }

  bool getChangeSourceLoadInfo({bool fallback = false}) {
    if (!isInitializedState) return fallback;
    return prefsStoreState.getBool(settingsKeyChangeSourceLoadInfo) ?? fallback;
  }

  bool getChangeSourceLoadWordCount({bool fallback = false}) {
    if (!isInitializedState) return fallback;
    return prefsStoreState.getBool(settingsKeyChangeSourceLoadWordCount) ?? fallback;
  }

  Future<void> saveChangeSourceLoadWordCount(bool enabled) async {
    if (!isInitializedState) return;
    await prefsStoreState.setBool(settingsKeyChangeSourceLoadWordCount, enabled);
  }

  bool getChangeSourceCheckAuthor({bool fallback = false}) {
    if (!isInitializedState) return fallback;
    return prefsStoreState.getBool(settingsKeyChangeSourceCheckAuthor) ?? fallback;
  }

  String getChangeSourceGroup({String fallback = ''}) {
    if (!isInitializedState) return fallback.trim();
    final value = prefsStoreState.getString(settingsKeyChangeSourceGroup) ?? fallback;
    return value.trim();
  }

  Future<void> saveChangeSourceCheckAuthor(bool enabled) async {
    if (!isInitializedState) return;
    await prefsStoreState.setBool(settingsKeyChangeSourceCheckAuthor, enabled);
  }

  Future<void> saveChangeSourceGroup(String group) async {
    if (!isInitializedState) return;
    await prefsStoreState.setString(settingsKeyChangeSourceGroup, group.trim());
  }

  Future<void> saveChangeSourceLoadInfo(bool enabled) async {
    if (!isInitializedState) return;
    await prefsStoreState.setBool(settingsKeyChangeSourceLoadInfo, enabled);
  }

  Future<void> saveChangeSourceLoadToc(bool enabled) async {
    if (!isInitializedState) return;
    await prefsStoreState.setBool(settingsKeyChangeSourceLoadToc, enabled);
  }

  int getBatchChangeSourceDelay({int fallback = 0}) {
    if (!isInitializedState) return fallback.clamp(0, 9999).toInt();
    final value = prefsStoreState.getInt(settingsKeyBatchChangeSourceDelay) ?? fallback;
    return value.clamp(0, 9999).toInt();
  }

  Future<void> saveBatchChangeSourceDelay(int seconds) async {
    if (!isInitializedState) return;
    final normalized = seconds.clamp(0, 9999).toInt();
    await prefsStoreState.setInt(settingsKeyBatchChangeSourceDelay, normalized);
  }

  bool getOpenBookInfoByClickTitle({bool fallback = true}) {
    if (!isInitializedState) return fallback;
    return prefsStoreState.getBool(settingsKeyOpenBookInfoByClickTitle) ?? fallback;
  }

  Future<void> saveOpenBookInfoByClickTitle(bool enabled) async {
    if (!isInitializedState) return;
    await prefsStoreState.setBool(settingsKeyOpenBookInfoByClickTitle, enabled);
  }

  bool getDeleteBookOriginal({bool fallback = false}) {
    if (!isInitializedState) return fallback;
    return prefsStoreState.getBool(settingsKeyDeleteBookOriginal) ?? fallback;
  }

  Future<void> saveDeleteBookOriginal(bool enabled) async {
    if (!isInitializedState) return;
    await prefsStoreState.setBool(settingsKeyDeleteBookOriginal, enabled);
  }

  bool getAudioPlayUseWakeLock({bool fallback = false}) {
    if (!isInitializedState) return fallback;
    return prefsStoreState.getBool(settingsKeyAudioPlayWakeLock) ?? fallback;
  }

  Future<void> saveAudioPlayUseWakeLock(bool enabled) async {
    if (!isInitializedState) return;
    await prefsStoreState.setBool(settingsKeyAudioPlayWakeLock, enabled);
  }

  int getContentSelectSpeakMode({int fallback = 0}) {
    if (!isInitializedState) return fallback;
    final value = prefsStoreState.getInt(settingsKeyContentSelectSpeakMod) ?? fallback;
    return value == 1 ? 1 : 0;
  }

  Future<void> saveContentSelectSpeakMode(int mode) async {
    // 迁移排除（EX-03）：TTS 在当前构建为 blocked，避免误写入形成“伪可用”。
    if (MigrationExclusions.excludeTts) {
      debugPrint(
        '[settings] 迁移排除：阻断 saveContentSelectSpeakMode（excludeTts=true），不写入',
      );
      return;
    }
    if (!isInitializedState) return;
    await prefsStoreState.setInt(settingsKeyContentSelectSpeakMod, mode == 1 ? 1 : 0);
  }

  Future<void> saveEnableReadRecord(bool enabled) async {
    if (!isInitializedState) return;
    await prefsStoreState.setBool(settingsKeyEnableReadRecord, enabled);
  }

  int getReadRecordSort({int fallback = 0}) {
    final normalizedFallback = normalizeReadRecordSort(fallback);
    if (!isInitializedState) return normalizedFallback;
    final value = prefsStoreState.getInt(settingsKeyReadRecordSort) ?? normalizedFallback;
    return normalizeReadRecordSort(value);
  }

  Future<void> saveReadRecordSort(int sortMode) async {
    if (!isInitializedState) return;
    await prefsStoreState.setInt(settingsKeyReadRecordSort, normalizeReadRecordSort(sortMode));
  }

  int getLastSeenWebDavBackupMillis({int fallback = 0}) {
    if (!isInitializedState) {
      return fallback < 0 ? 0 : fallback;
    }
    final value = prefsStoreState.getInt(settingsKeyLastSeenWebDavBackupMillis);
    if (value == null || value < 0) {
      return fallback < 0 ? 0 : fallback;
    }
    return value;
  }

  /// 保存“自动检查新备份”的本地对照时间（毫秒时间戳）。
  ///
  /// 约束：负值会被强制归零，避免脏数据导致重复弹窗判断异常。
  Future<void> saveLastSeenWebDavBackupMillis(int millis) async {
    if (!isInitializedState) return;
    final normalized = millis < 0 ? 0 : millis;
    await prefsStoreState.setInt(settingsKeyLastSeenWebDavBackupMillis, normalized);
  }

  Future<void> saveCoverLoadOnlyWifi(bool enabled) async {
    if (!isInitializedState) return;
    await prefsStoreState.setBool(settingsKeyLoadCoverOnlyWifi, enabled);
  }

  Future<void> saveUseDefaultCover(bool enabled) async {
    if (!isInitializedState) return;
    await prefsStoreState.setBool(settingsKeyUseDefaultCover, enabled);
  }

  Future<void> saveCoverRule(String value) async {
    if (!isInitializedState) return;
    final normalized = value.trim();
    if (normalized.isEmpty) {
      await prefsStoreState.remove(settingsKeyCoverRule);
      return;
    }
    await prefsStoreState.setString(settingsKeyCoverRule, normalized);
  }

  Future<void> saveDefaultCoverPath(String? path) async {
    await _saveOptionalStringPref(settingsKeyDefaultCoverPath, path);
  }

  Future<void> saveDefaultCoverDarkPath(String? path) async {
    await _saveOptionalStringPref(settingsKeyDefaultCoverDarkPath, path);
  }

  Future<void> saveCoverShowName(bool enabled) async {
    if (!isInitializedState) return;
    await prefsStoreState.setBool(settingsKeyCoverShowName, enabled);
  }

  Future<void> saveCoverShowAuthor(bool enabled) async {
    if (!isInitializedState) return;
    await prefsStoreState.setBool(settingsKeyCoverShowAuthor, enabled);
  }

  Future<void> saveCoverShowNameNight(bool enabled) async {
    if (!isInitializedState) return;
    await prefsStoreState.setBool(settingsKeyCoverShowNameNight, enabled);
  }

  Future<void> saveCoverShowAuthorNight(bool enabled) async {
    if (!isInitializedState) return;
    await prefsStoreState.setBool(settingsKeyCoverShowAuthorNight, enabled);
  }

  Future<void> saveCustomWelcome(bool enabled) async {
    if (!isInitializedState) return;
    await prefsStoreState.setBool(settingsKeyCustomWelcome, enabled);
  }

  Future<void> saveWelcomeImagePath(String? path) async {
    await _saveOptionalStringPref(settingsKeyWelcomeImagePath, path);
  }

  Future<void> saveWelcomeImageDarkPath(String? path) async {
    await _saveOptionalStringPref(settingsKeyWelcomeImageDarkPath, path);
  }

  Future<void> saveWelcomeShowText(bool enabled) async {
    if (!isInitializedState) return;
    await prefsStoreState.setBool(settingsKeyWelcomeShowText, enabled);
  }

  Future<void> saveWelcomeShowIcon(bool enabled) async {
    if (!isInitializedState) return;
    await prefsStoreState.setBool(settingsKeyWelcomeShowIcon, enabled);
  }

  Future<void> saveWelcomeShowTextDark(bool enabled) async {
    if (!isInitializedState) return;
    await prefsStoreState.setBool(settingsKeyWelcomeShowTextDark, enabled);
  }

  Future<void> saveWelcomeShowIconDark(bool enabled) async {
    if (!isInitializedState) return;
    await prefsStoreState.setBool(settingsKeyWelcomeShowIconDark, enabled);
  }

  Future<void> saveReaderChapterUrlOpenInBrowser(bool value) async {
    await prefsStoreState.setBool(settingsKeyReaderChapterUrlOpenInBrowser, value);
  }

  Future<void> _saveOptionalStringPref(String key, String? value) async {
    if (!isInitializedState) return;
    final normalized = (value ?? '').trim();
    if (normalized.isEmpty) {
      await prefsStoreState.remove(key);
      return;
    }
    await prefsStoreState.setString(key, normalized);
  }
}
