import 'dart:convert';

import '../bootstrap/boot_log.dart';
import '../models/app_settings.dart';
import '../../features/reader/models/reading_settings.dart';
import 'settings_service_context.dart';
import 'settings_service_keys.dart';

mixin SettingsServiceInitMixin on SettingsServiceContext {
  Future<void> init() async {
    BootLog.add('SettingsService.init: preferencesStore.loadInitializedStore start');
    prefsStoreState = await preferencesStoreDriver.loadInitializedStore();
    BootLog.add('SettingsService.init: preferencesStore.loadInitializedStore ok');
    isInitializedState = true;

    var needsReadingSettingsRewrite = false;
    final jsonStr = prefsStoreState.getString(settingsKeyReadingSettings);
    if (jsonStr != null) {
      try {
        final decoded = json.decode(jsonStr);
        if (decoded is Map<String, dynamic>) {
          readingSettingsState = ReadingSettings.fromJson(decoded);
        } else if (decoded is Map) {
          readingSettingsState = ReadingSettings.fromJson(
            decoded.map((key, value) => MapEntry('$key', value)),
          );
        } else {
          readingSettingsState = const ReadingSettings();
          needsReadingSettingsRewrite = true;
        }
      } catch (_) {
        readingSettingsState = const ReadingSettings();
        needsReadingSettingsRewrite = true;
      }
    } else {
      readingSettingsState = const ReadingSettings();
      needsReadingSettingsRewrite = true;
    }

    await _migrateReadingSettingsSchema(forcePersist: needsReadingSettingsRewrite);
    readingSettingsNotifierState.value = readingSettingsState;

    var needsAppSettingsRewrite = false;
    final appJson = prefsStoreState.getString(settingsKeyAppSettings);
    if (appJson != null) {
      try {
        final decoded = json.decode(appJson);
        if (decoded is Map<String, dynamic>) {
          final decodedAppSettings = decodeAppSettings(decoded);
          appSettingsState = decodedAppSettings.settings;
          needsAppSettingsRewrite = decodedAppSettings.needsRewrite;
        } else if (decoded is Map) {
          final decodedAppSettings = decodeAppSettings(
            decoded.map((key, value) => MapEntry('$key', value)),
          );
          appSettingsState = decodedAppSettings.settings;
          needsAppSettingsRewrite = true;
        } else {
          appSettingsState = const AppSettings();
          needsAppSettingsRewrite = true;
        }
      } catch (_) {
        appSettingsState = const AppSettings();
        needsAppSettingsRewrite = true;
      }
    } else {
      appSettingsState = const AppSettings();
      needsAppSettingsRewrite = true;
    }
    if (needsAppSettingsRewrite) {
      await prefsStoreState.setString(
        settingsKeyAppSettings,
        json.encode(appSettingsState.toJson()),
      );
    }
    appSettingsNotifierState.value = appSettingsState;

    bookCanUpdateState = decodeBoolMap(
      prefsStoreState.getString(settingsKeyBookCanUpdateMap),
    );
    bookSplitLongChapterState = decodeBoolMap(
      prefsStoreState.getString(settingsKeyBookSplitLongChapterMap),
    );
    bookTxtTocRuleState = decodeStringMap(
      prefsStoreState.getString(settingsKeyBookTxtTocRuleMap),
    );
    bookUseReplaceRuleState = decodeBoolMap(
      prefsStoreState.getString(settingsKeyBookUseReplaceRuleMap),
    );
    bookPageAnimState = decodeIntMap(
      prefsStoreState.getString(settingsKeyBookPageAnimMap),
    );
    bookReSegmentState = decodeBoolMap(
      prefsStoreState.getString(settingsKeyBookReSegmentMap),
    );
    bookImageStyleState = decodeStringMap(
      prefsStoreState.getString(settingsKeyBookImageStyleMap),
    );
    chapterSameTitleRemovedState = decodeBoolMap(
      prefsStoreState.getString(settingsKeyChapterSameTitleRemovedMap),
    );
    bookDelRubyTagState = decodeBoolMap(
      prefsStoreState.getString(settingsKeyBookDelRubyTagMap),
    );
    bookDelHTagState = decodeBoolMap(
      prefsStoreState.getString(settingsKeyBookDelHTagMap),
    );
    bookReadSimulatingState = decodeBoolMap(
      prefsStoreState.getString(settingsKeyBookReadSimulatingMap),
    );
    bookSimulatedStartChapterState = decodeIntMap(
      prefsStoreState.getString(settingsKeyBookSimulatedStartChapterMap),
    );
    bookSimulatedDailyChaptersState = decodeIntMap(
      prefsStoreState.getString(settingsKeyBookSimulatedDailyChaptersMap),
    );
    bookSimulatedStartDateState = decodeStringMap(
      prefsStoreState.getString(settingsKeyBookSimulatedStartDateMap),
    );
    bookRemoteUploadUrlState = decodeStringMap(
      prefsStoreState.getString(settingsKeyBookRemoteUploadUrlMap),
    );
    bookReaderImageSizeSnapshotState = decodeStringMap(
      prefsStoreState.getString(settingsKeyBookReaderImageSizeSnapshotMap),
    );
    bookReadRecordDurationState = decodeIntMap(
      prefsStoreState.getString(settingsKeyBookReadRecordDurationMap),
    );
  }

  Future<void> _migrateReadingSettingsSchema({
    required bool forcePersist,
  }) async {
    final currentVersion =
        prefsStoreState.getInt(settingsKeyReadingSettingsSchemaVersion) ?? 0;
    final normalized = readingSettingsState.sanitize();
    final normalizedJson = json.encode(normalized.toJson());
    final storedJson = prefsStoreState.getString(settingsKeyReadingSettings);
    final shouldPersist =
        forcePersist ||
        currentVersion < settingsReadingSettingsSchemaVersion ||
        storedJson != normalizedJson;

    readingSettingsState = normalized;

    if (shouldPersist) {
      await prefsStoreState.setString(settingsKeyReadingSettings, normalizedJson);
    }

    await _persistReadingSettingsSchemaVersionIfNeeded();
  }

  Future<void> saveReadingSettings(ReadingSettings settings) async {
    final safeSettings = settings.sanitize();
    readingSettingsState = safeSettings;
    readingSettingsNotifierState.value = safeSettings;
    await prefsStoreState.setString(
      settingsKeyReadingSettings,
      json.encode(safeSettings.toJson()),
    );
    await _persistReadingSettingsSchemaVersionIfNeeded();
  }

  Future<void> _persistReadingSettingsSchemaVersionIfNeeded() async {
    final currentVersion =
        prefsStoreState.getInt(settingsKeyReadingSettingsSchemaVersion) ?? 0;
    if (currentVersion != settingsReadingSettingsSchemaVersion) {
      await prefsStoreState.setInt(
        settingsKeyReadingSettingsSchemaVersion,
        settingsReadingSettingsSchemaVersion,
      );
    }
  }

  Future<void> saveAppSettings(AppSettings settings) async {
    final normalizedAppearanceMode = appAppearanceModeFromLegacyValue(
      appAppearanceModeToLegacyValue(settings.appearanceMode),
    );
    final normalizedUpdateToVariant =
        AppSettings.normalizeUpdateToVariant(settings.updateToVariant);
    final normalizedSettings = settings.copyWith(
      appearanceMode: normalizedAppearanceMode,
      updateToVariant: normalizedUpdateToVariant,
    );
    appSettingsState = normalizedSettings;
    appSettingsNotifierState.value = normalizedSettings;
    await prefsStoreState.setString(
      settingsKeyAppSettings,
      json.encode(normalizedSettings.toJson()),
    );
  }

  Future<void> saveAppSettingsPatch(
    AppSettings Function(AppSettings current) patch,
  ) async {
    if (!isInitializedState) return;
    final next = patch(appSettingsState);
    await saveAppSettings(next);
  }
}
