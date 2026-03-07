import 'package:flutter/foundation.dart';

import '../models/app_settings.dart';
import '../../features/reader/models/reading_settings.dart';
import 'preferences_store.dart';
import 'settings_service_context.dart';
import 'settings_service_accessors_mixin.dart';
import 'settings_service_app_mixin.dart';
import 'settings_service_book_primary_mixin.dart';
import 'settings_service_book_secondary_mixin.dart';
import 'settings_service_codec_mixin.dart';
import 'settings_service_init_mixin.dart';
import 'settings_service_reader_progress_mixin.dart';
import 'settings_service_ui_preferences_mixin.dart';

abstract class SettingsServiceBase implements SettingsServiceContext {}

class SettingsService extends SettingsServiceBase
    with
        SettingsServiceAccessorsMixin,
        SettingsServiceInitMixin,
        SettingsServiceCodecMixin,
        SettingsServiceBookPrimaryMixin,
        SettingsServiceBookSecondaryMixin,
        SettingsServiceAppMixin,
        SettingsServiceUiPreferencesMixin,
        SettingsServiceReaderProgressMixin {
  static final SettingsService _instance = SettingsService._internal();

  factory SettingsService() => _instance;

  SettingsService._internal();

  static PreferencesStore _preferencesStore = defaultPreferencesStore;

  static void debugReplacePreferencesStore(PreferencesStore store) {
    _preferencesStore = store;
  }

  static void debugResetPreferencesStore() {
    _preferencesStore = defaultPreferencesStore;
  }

  late InitializedPreferencesStore _prefs;
  late ReadingSettings _readingSettings;
  late AppSettings _appSettings;
  bool _isInitialized = false;
  Map<String, bool> _bookCanUpdateMap = <String, bool>{};
  Map<String, bool> _bookSplitLongChapterMap = <String, bool>{};
  Map<String, String> _bookTxtTocRuleMap = <String, String>{};
  Map<String, bool> _bookUseReplaceRuleMap = <String, bool>{};
  Map<String, int> _bookPageAnimMap = <String, int>{};
  Map<String, bool> _bookReSegmentMap = <String, bool>{};
  Map<String, String> _bookImageStyleMap = <String, String>{};
  Map<String, bool> _chapterSameTitleRemovedMap = <String, bool>{};
  Map<String, bool> _bookDelRubyTagMap = <String, bool>{};
  Map<String, bool> _bookDelHTagMap = <String, bool>{};
  Map<String, bool> _bookReadSimulatingMap = <String, bool>{};
  Map<String, int> _bookSimulatedStartChapterMap = <String, int>{};
  Map<String, int> _bookSimulatedDailyChaptersMap = <String, int>{};
  Map<String, String> _bookSimulatedStartDateMap = <String, String>{};
  Map<String, String> _bookRemoteUploadUrlMap = <String, String>{};
  Map<String, String> _bookReaderImageSizeSnapshotMap = <String, String>{};
  Map<String, int> _bookReadRecordDurationMap = <String, int>{};
  final ValueNotifier<ReadingSettings> _readingSettingsNotifier =
      ValueNotifier(const ReadingSettings());
  final ValueNotifier<AppSettings> _appSettingsNotifier =
      ValueNotifier(const AppSettings());

  @override
  PreferencesStore get preferencesStoreDriver => _preferencesStore;

  @override
  InitializedPreferencesStore get prefsStoreState => _prefs;

  @override
  set prefsStoreState(InitializedPreferencesStore value) => _prefs = value;

  @override
  ReadingSettings get readingSettingsState => _readingSettings;

  @override
  set readingSettingsState(ReadingSettings value) => _readingSettings = value;

  @override
  AppSettings get appSettingsState => _appSettings;

  @override
  set appSettingsState(AppSettings value) => _appSettings = value;

  @override
  bool get isInitializedState => _isInitialized;

  @override
  set isInitializedState(bool value) => _isInitialized = value;

  @override
  Map<String, bool> get bookCanUpdateState => _bookCanUpdateMap;

  @override
  set bookCanUpdateState(Map<String, bool> value) => _bookCanUpdateMap = value;

  @override
  Map<String, bool> get bookSplitLongChapterState => _bookSplitLongChapterMap;

  @override
  set bookSplitLongChapterState(Map<String, bool> value) {
    _bookSplitLongChapterMap = value;
  }

  @override
  Map<String, String> get bookTxtTocRuleState => _bookTxtTocRuleMap;

  @override
  set bookTxtTocRuleState(Map<String, String> value) => _bookTxtTocRuleMap = value;

  @override
  Map<String, bool> get bookUseReplaceRuleState => _bookUseReplaceRuleMap;

  @override
  set bookUseReplaceRuleState(Map<String, bool> value) {
    _bookUseReplaceRuleMap = value;
  }

  @override
  Map<String, int> get bookPageAnimState => _bookPageAnimMap;

  @override
  set bookPageAnimState(Map<String, int> value) => _bookPageAnimMap = value;

  @override
  Map<String, bool> get bookReSegmentState => _bookReSegmentMap;

  @override
  set bookReSegmentState(Map<String, bool> value) => _bookReSegmentMap = value;

  @override
  Map<String, String> get bookImageStyleState => _bookImageStyleMap;

  @override
  set bookImageStyleState(Map<String, String> value) => _bookImageStyleMap = value;

  @override
  Map<String, bool> get chapterSameTitleRemovedState =>
      _chapterSameTitleRemovedMap;

  @override
  set chapterSameTitleRemovedState(Map<String, bool> value) {
    _chapterSameTitleRemovedMap = value;
  }

  @override
  Map<String, bool> get bookDelRubyTagState => _bookDelRubyTagMap;

  @override
  set bookDelRubyTagState(Map<String, bool> value) => _bookDelRubyTagMap = value;

  @override
  Map<String, bool> get bookDelHTagState => _bookDelHTagMap;

  @override
  set bookDelHTagState(Map<String, bool> value) => _bookDelHTagMap = value;

  @override
  Map<String, bool> get bookReadSimulatingState => _bookReadSimulatingMap;

  @override
  set bookReadSimulatingState(Map<String, bool> value) {
    _bookReadSimulatingMap = value;
  }

  @override
  Map<String, int> get bookSimulatedStartChapterState =>
      _bookSimulatedStartChapterMap;

  @override
  set bookSimulatedStartChapterState(Map<String, int> value) {
    _bookSimulatedStartChapterMap = value;
  }

  @override
  Map<String, int> get bookSimulatedDailyChaptersState =>
      _bookSimulatedDailyChaptersMap;

  @override
  set bookSimulatedDailyChaptersState(Map<String, int> value) {
    _bookSimulatedDailyChaptersMap = value;
  }

  @override
  Map<String, String> get bookSimulatedStartDateState =>
      _bookSimulatedStartDateMap;

  @override
  set bookSimulatedStartDateState(Map<String, String> value) {
    _bookSimulatedStartDateMap = value;
  }

  @override
  Map<String, String> get bookRemoteUploadUrlState => _bookRemoteUploadUrlMap;

  @override
  set bookRemoteUploadUrlState(Map<String, String> value) {
    _bookRemoteUploadUrlMap = value;
  }

  @override
  Map<String, String> get bookReaderImageSizeSnapshotState =>
      _bookReaderImageSizeSnapshotMap;

  @override
  set bookReaderImageSizeSnapshotState(Map<String, String> value) {
    _bookReaderImageSizeSnapshotMap = value;
  }

  @override
  Map<String, int> get bookReadRecordDurationState =>
      _bookReadRecordDurationMap;

  @override
  set bookReadRecordDurationState(Map<String, int> value) {
    _bookReadRecordDurationMap = value;
  }

  @override
  ValueNotifier<ReadingSettings> get readingSettingsNotifierState =>
      _readingSettingsNotifier;

  @override
  ValueNotifier<AppSettings> get appSettingsNotifierState =>
      _appSettingsNotifier;
}
