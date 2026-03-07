import 'package:flutter/foundation.dart';

import '../models/app_settings.dart';
import '../../features/reader/models/reading_settings.dart';
import 'preferences_store.dart';

class DecodedAppSettings {
  final AppSettings settings;
  final bool needsRewrite;

  const DecodedAppSettings({
    required this.settings,
    required this.needsRewrite,
  });
}

abstract class SettingsServiceContext {
  PreferencesStore get preferencesStoreDriver;
  InitializedPreferencesStore get prefsStoreState;
  set prefsStoreState(InitializedPreferencesStore value);
  ReadingSettings get readingSettingsState;
  set readingSettingsState(ReadingSettings value);
  AppSettings get appSettingsState;
  set appSettingsState(AppSettings value);
  bool get isInitializedState;
  set isInitializedState(bool value);
  Map<String, bool> get bookCanUpdateState;
  set bookCanUpdateState(Map<String, bool> value);
  Map<String, bool> get bookSplitLongChapterState;
  set bookSplitLongChapterState(Map<String, bool> value);
  Map<String, String> get bookTxtTocRuleState;
  set bookTxtTocRuleState(Map<String, String> value);
  Map<String, bool> get bookUseReplaceRuleState;
  set bookUseReplaceRuleState(Map<String, bool> value);
  Map<String, int> get bookPageAnimState;
  set bookPageAnimState(Map<String, int> value);
  Map<String, bool> get bookReSegmentState;
  set bookReSegmentState(Map<String, bool> value);
  Map<String, String> get bookImageStyleState;
  set bookImageStyleState(Map<String, String> value);
  Map<String, bool> get chapterSameTitleRemovedState;
  set chapterSameTitleRemovedState(Map<String, bool> value);
  Map<String, bool> get bookDelRubyTagState;
  set bookDelRubyTagState(Map<String, bool> value);
  Map<String, bool> get bookDelHTagState;
  set bookDelHTagState(Map<String, bool> value);
  Map<String, bool> get bookReadSimulatingState;
  set bookReadSimulatingState(Map<String, bool> value);
  Map<String, int> get bookSimulatedStartChapterState;
  set bookSimulatedStartChapterState(Map<String, int> value);
  Map<String, int> get bookSimulatedDailyChaptersState;
  set bookSimulatedDailyChaptersState(Map<String, int> value);
  Map<String, String> get bookSimulatedStartDateState;
  set bookSimulatedStartDateState(Map<String, String> value);
  Map<String, String> get bookRemoteUploadUrlState;
  set bookRemoteUploadUrlState(Map<String, String> value);
  Map<String, String> get bookReaderImageSizeSnapshotState;
  set bookReaderImageSizeSnapshotState(Map<String, String> value);
  Map<String, int> get bookReadRecordDurationState;
  set bookReadRecordDurationState(Map<String, int> value);
  ValueNotifier<ReadingSettings> get readingSettingsNotifierState;
  ValueNotifier<AppSettings> get appSettingsNotifierState;

  DecodedAppSettings decodeAppSettings(Map<String, dynamic> rawJson);
  Map<String, bool> decodeBoolMap(String? rawJson);
  Future<void> persistBoolMap(String key, Map<String, bool> value);
  Map<String, int> decodeIntMap(String? rawJson);
  Future<void> persistIntMap(String key, Map<String, int> value);
  Map<String, String> decodeStringMap(String? rawJson);
  Future<void> persistStringMap(String key, Map<String, String> value);
  int normalizeReadRecordSort(int value);
  Future<void> saveAppSettingsPatch(
    AppSettings Function(AppSettings current) patch,
  );
}
