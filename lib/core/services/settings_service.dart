import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../bootstrap/boot_log.dart';
import '../config/migration_exclusions.dart';
import '../models/app_settings.dart';
import '../../features/reader/models/reading_settings.dart';

/// 全局设置服务
class SettingsService {
  static final SettingsService _instance = SettingsService._internal();
  factory SettingsService() => _instance;
  SettingsService._internal();

  static const String _keyReadingSettings = 'reading_settings';
  static const String _keyReadingSettingsSchemaVersion =
      'reading_settings_schema_version';
  static const String _keyAppSettings = 'app_settings';
  static const String _keyReaderChapterUrlOpenInBrowser =
      'reader_chapter_url_open_in_browser';
  static const String _keyReaderFontFolderPath = 'reader_font_folder_path';
  static const String _keyReaderCustomFontPath = 'reader_custom_font_path';
  static const String _keyBookCanUpdateMap = 'book_can_update_map';
  static const String _keyBookSplitLongChapterMap =
      'book_split_long_chapter_map';
  static const String _keyBookTxtTocRuleMap = 'book_txt_toc_rule_map';
  static const String _keyBookUseReplaceRuleMap = 'book_use_replace_rule_map';
  static const String _keyTocUiUseReplace = 'toc_ui_use_replace';
  static const String _keyTocUiLoadWordCount = 'toc_ui_load_word_count';
  static const String _keyChangeSourceCheckAuthor = 'changeSourceCheckAuthor';
  static const String _keyChangeSourceLoadWordCount =
      'changeSourceLoadWordCount';
  static const String _keyChangeSourceLoadInfo = 'changeSourceLoadInfo';
  static const String _keyChangeSourceLoadToc = 'changeSourceLoadToc';
  static const String _keyChangeSourceGroup = 'searchGroup';
  static const String _keyBatchChangeSourceDelay = 'batchChangeSourceDelay';
  static const String _keyOpenBookInfoByClickTitle = 'openBookInfoByClickTitle';
  static const String _keyDeleteBookOriginal = 'deleteBookOriginal';
  static const String _keyBookPageAnimMap = 'book_page_anim_map';
  static const String _keyBookReSegmentMap = 'book_re_segment_map';
  static const String _keyBookImageStyleMap = 'book_image_style_map';
  static const String _keyChapterSameTitleRemovedMap =
      'chapter_same_title_removed_map';
  static const String _keyBookDelRubyTagMap = 'book_del_ruby_tag_map';
  static const String _keyBookDelHTagMap = 'book_del_h_tag_map';
  static const String _keyBookReadSimulatingMap = 'book_read_simulating_map';
  static const String _keyBookSimulatedStartChapterMap =
      'book_simulated_start_chapter_map';
  static const String _keyBookSimulatedDailyChaptersMap =
      'book_simulated_daily_chapters_map';
  static const String _keyBookSimulatedStartDateMap =
      'book_simulated_start_date_map';
  static const String _keyBookRemoteUploadUrlMap = 'book_remote_upload_url_map';
  static const String _keyBookReaderImageSizeSnapshotMap =
      'book_reader_image_size_snapshot_map';
  static const String _keyAudioPlayWakeLock = 'audioPlayWakeLock';
  static const String _keyContentSelectSpeakMod = 'contentSelectSpeakMod';
  static const String _keyEnableReadRecord = 'enableReadRecord';
  static const String _keyReadRecordSort = 'readRecordSort';
  static const String _keyBookReadRecordDurationMap =
      'book_read_record_duration_map';
  static const String _keyLoadCoverOnlyWifi = 'loadCoverOnlyWifi';
  static const String _keyCoverRule = 'coverRule';
  static const String _keyUseDefaultCover = 'useDefaultCover';
  static const String _keyDefaultCoverPath = 'defaultCover';
  static const String _keyDefaultCoverDarkPath = 'defaultCoverDark';
  static const String _keyCoverShowName = 'coverShowName';
  static const String _keyCoverShowAuthor = 'coverShowAuthor';
  static const String _keyCoverShowNameNight = 'coverShowNameN';
  static const String _keyCoverShowAuthorNight = 'coverShowAuthorN';
  static const String _keyCustomWelcome = 'customWelcome';
  static const String _keyWelcomeImagePath = 'welcomeImagePath';
  static const String _keyWelcomeImageDarkPath = 'welcomeImagePathDark';
  static const String _keyWelcomeShowText = 'welcomeShowText';
  static const String _keyWelcomeShowIcon = 'welcomeShowIcon';
  static const String _keyWelcomeShowTextDark = 'welcomeShowTextDark';
  static const String _keyWelcomeShowIconDark = 'welcomeShowIconDark';
  static const String _keyLastSeenWebDavBackupMillis =
      'last_seen_webdav_backup_millis';
  static const String _defaultImageStyle = 'DEFAULT';
  static const Set<String> _validImageStyles = <String>{
    'DEFAULT',
    'FULL',
    'TEXT',
    'SINGLE',
  };
  static const int _readingSettingsSchemaVersion = 4;
  static const int _maxReaderImageSizeSnapshotBytes = 120 * 1024;

  late SharedPreferences _prefs;
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

  ReadingSettings get readingSettings => _readingSettings;
  AppSettings get appSettings => _appSettings;
  ValueListenable<ReadingSettings> get readingSettingsListenable =>
      _readingSettingsNotifier;
  ValueListenable<AppSettings> get appSettingsListenable =>
      _appSettingsNotifier;
  bool get readerChapterUrlOpenInBrowser =>
      _prefs.getBool(_keyReaderChapterUrlOpenInBrowser) ?? false;
  bool get enableReadRecord =>
      !_isInitialized ? true : _prefs.getBool(_keyEnableReadRecord) ?? true;
  bool get coverLoadOnlyWifi =>
      !_isInitialized ? false : _prefs.getBool(_keyLoadCoverOnlyWifi) ?? false;
  bool get useDefaultCover =>
      !_isInitialized ? false : _prefs.getBool(_keyUseDefaultCover) ?? false;
  bool get coverShowName =>
      !_isInitialized ? true : _prefs.getBool(_keyCoverShowName) ?? true;
  bool get coverShowAuthor =>
      !_isInitialized ? true : _prefs.getBool(_keyCoverShowAuthor) ?? true;
  bool get coverShowNameNight =>
      !_isInitialized ? true : _prefs.getBool(_keyCoverShowNameNight) ?? true;
  bool get coverShowAuthorNight =>
      !_isInitialized ? true : _prefs.getBool(_keyCoverShowAuthorNight) ?? true;
  bool get customWelcome =>
      !_isInitialized ? false : _prefs.getBool(_keyCustomWelcome) ?? false;
  bool get welcomeShowText =>
      !_isInitialized ? true : _prefs.getBool(_keyWelcomeShowText) ?? true;
  bool get welcomeShowIcon =>
      !_isInitialized ? true : _prefs.getBool(_keyWelcomeShowIcon) ?? true;
  bool get welcomeShowTextDark =>
      !_isInitialized ? true : _prefs.getBool(_keyWelcomeShowTextDark) ?? true;
  bool get welcomeShowIconDark =>
      !_isInitialized ? true : _prefs.getBool(_keyWelcomeShowIconDark) ?? true;

  String get coverRule =>
      !_isInitialized ? '' : (_prefs.getString(_keyCoverRule) ?? '').trim();
  String get defaultCoverPath => !_isInitialized
      ? ''
      : (_prefs.getString(_keyDefaultCoverPath) ?? '').trim();
  String get defaultCoverDarkPath => !_isInitialized
      ? ''
      : (_prefs.getString(_keyDefaultCoverDarkPath) ?? '').trim();
  String get welcomeImagePath => !_isInitialized
      ? ''
      : (_prefs.getString(_keyWelcomeImagePath) ?? '').trim();
  String get welcomeImageDarkPath => !_isInitialized
      ? ''
      : (_prefs.getString(_keyWelcomeImageDarkPath) ?? '').trim();

  String? getReaderFontFolderPath() {
    if (!_isInitialized) return null;
    final value = _prefs.getString(_keyReaderFontFolderPath)?.trim();
    if (value == null || value.isEmpty) return null;
    return value;
  }

  Future<void> saveReaderFontFolderPath(String? path) async {
    if (!_isInitialized) return;
    final normalized = (path ?? '').trim();
    if (normalized.isEmpty) {
      await _prefs.remove(_keyReaderFontFolderPath);
      return;
    }
    await _prefs.setString(_keyReaderFontFolderPath, normalized);
  }

  String? getReaderCustomFontPath() {
    if (!_isInitialized) return null;
    final value = _prefs.getString(_keyReaderCustomFontPath)?.trim();
    if (value == null || value.isEmpty) return null;
    return value;
  }

  Future<void> saveReaderCustomFontPath(String? path) async {
    if (!_isInitialized) return;
    final normalized = (path ?? '').trim();
    if (normalized.isEmpty) {
      await _prefs.remove(_keyReaderCustomFontPath);
      return;
    }
    await _prefs.setString(_keyReaderCustomFontPath, normalized);
  }

  Future<void> init() async {
    BootLog.add('SettingsService.init: SharedPreferences.getInstance start');
    _prefs = await SharedPreferences.getInstance();
    BootLog.add('SettingsService.init: SharedPreferences.getInstance ok');
    _isInitialized = true;

    var needsReadingSettingsRewrite = false;
    final jsonStr = _prefs.getString(_keyReadingSettings);
    if (jsonStr != null) {
      try {
        final decoded = json.decode(jsonStr);
        if (decoded is Map<String, dynamic>) {
          _readingSettings = ReadingSettings.fromJson(decoded);
        } else if (decoded is Map) {
          _readingSettings = ReadingSettings.fromJson(
            decoded.map((key, value) => MapEntry('$key', value)),
          );
        } else {
          _readingSettings = const ReadingSettings();
          needsReadingSettingsRewrite = true;
        }
      } catch (_) {
        _readingSettings = const ReadingSettings();
        needsReadingSettingsRewrite = true;
      }
    } else {
      _readingSettings = const ReadingSettings();
      needsReadingSettingsRewrite = true;
    }

    await _migrateReadingSettingsSchema(
      forcePersist: needsReadingSettingsRewrite,
    );
    _readingSettingsNotifier.value = _readingSettings;

    var needsAppSettingsRewrite = false;
    final appJson = _prefs.getString(_keyAppSettings);
    if (appJson != null) {
      try {
        final decoded = json.decode(appJson);
        if (decoded is Map<String, dynamic>) {
          final decodedAppSettings = _decodeAppSettings(decoded);
          _appSettings = decodedAppSettings.settings;
          needsAppSettingsRewrite = decodedAppSettings.needsRewrite;
        } else if (decoded is Map) {
          final decodedAppSettings = _decodeAppSettings(
            decoded.map((key, value) => MapEntry('$key', value)),
          );
          _appSettings = decodedAppSettings.settings;
          needsAppSettingsRewrite = true;
        } else {
          _appSettings = const AppSettings();
          needsAppSettingsRewrite = true;
        }
      } catch (_) {
        _appSettings = const AppSettings();
        needsAppSettingsRewrite = true;
      }
    } else {
      _appSettings = const AppSettings();
      needsAppSettingsRewrite = true;
    }
    if (needsAppSettingsRewrite) {
      await _prefs.setString(
        _keyAppSettings,
        json.encode(_appSettings.toJson()),
      );
    }
    _appSettingsNotifier.value = _appSettings;

    _bookCanUpdateMap = _decodeBoolMap(_prefs.getString(_keyBookCanUpdateMap));
    _bookSplitLongChapterMap =
        _decodeBoolMap(_prefs.getString(_keyBookSplitLongChapterMap));
    _bookTxtTocRuleMap =
        _decodeStringMap(_prefs.getString(_keyBookTxtTocRuleMap));
    _bookUseReplaceRuleMap =
        _decodeBoolMap(_prefs.getString(_keyBookUseReplaceRuleMap));
    _bookPageAnimMap = _decodeIntMap(_prefs.getString(_keyBookPageAnimMap));
    _bookReSegmentMap = _decodeBoolMap(_prefs.getString(_keyBookReSegmentMap));
    _bookImageStyleMap =
        _decodeStringMap(_prefs.getString(_keyBookImageStyleMap));
    _chapterSameTitleRemovedMap =
        _decodeBoolMap(_prefs.getString(_keyChapterSameTitleRemovedMap));
    _bookDelRubyTagMap =
        _decodeBoolMap(_prefs.getString(_keyBookDelRubyTagMap));
    _bookDelHTagMap = _decodeBoolMap(_prefs.getString(_keyBookDelHTagMap));
    _bookReadSimulatingMap =
        _decodeBoolMap(_prefs.getString(_keyBookReadSimulatingMap));
    _bookSimulatedStartChapterMap =
        _decodeIntMap(_prefs.getString(_keyBookSimulatedStartChapterMap));
    _bookSimulatedDailyChaptersMap =
        _decodeIntMap(_prefs.getString(_keyBookSimulatedDailyChaptersMap));
    _bookSimulatedStartDateMap =
        _decodeStringMap(_prefs.getString(_keyBookSimulatedStartDateMap));
    _bookRemoteUploadUrlMap =
        _decodeStringMap(_prefs.getString(_keyBookRemoteUploadUrlMap));
    _bookReaderImageSizeSnapshotMap =
        _decodeStringMap(_prefs.getString(_keyBookReaderImageSizeSnapshotMap));
    _bookReadRecordDurationMap =
        _decodeIntMap(_prefs.getString(_keyBookReadRecordDurationMap));
  }

  _DecodedAppSettings _decodeAppSettings(Map<String, dynamic> rawJson) {
    final settings = AppSettings.fromJson(rawJson);
    final rawUpdateToVariant = rawJson['updateToVariant']?.toString().trim() ??
        AppSettings.defaultUpdateToVariant;
    final normalizedUpdateToVariant =
        AppSettings.normalizeUpdateToVariant(rawUpdateToVariant);
    final normalizedModeValue =
        resolveAppAppearanceModeLegacyValueFromJson(rawJson);
    final parsedThemeMode =
        tryParseAppAppearanceModeLegacyValue(rawJson['themeMode']);
    final parsedAppearanceMode =
        tryParseAppAppearanceModeLegacyValue(rawJson['appearanceMode']);
    final hasThemeMode = rawJson.containsKey('themeMode');
    final hasAppearanceMode = rawJson.containsKey('appearanceMode');
    final isValidThemeMode = parsedThemeMode != null &&
        isValidAppAppearanceModeLegacyValue(parsedThemeMode);
    final isValidAppearanceMode = parsedAppearanceMode != null &&
        isValidAppAppearanceModeLegacyValue(parsedAppearanceMode);
    final validThemeModeValue = isValidThemeMode ? parsedThemeMode : null;
    final validAppearanceModeValue =
        isValidAppearanceMode ? parsedAppearanceMode : null;
    final isLegacyThreeValueConfig = !hasThemeMode &&
        validAppearanceModeValue != null &&
        validAppearanceModeValue <= appAppearanceModeLegacyTriValueMax;
    final themeModeNeedsNormalize = !hasThemeMode ||
        validThemeModeValue == null ||
        validThemeModeValue != normalizedModeValue;
    final appearanceModeNeedsNormalize = !hasAppearanceMode ||
        validAppearanceModeValue == null ||
        validAppearanceModeValue != normalizedModeValue;

    return _DecodedAppSettings(
      settings: settings,
      needsRewrite: isLegacyThreeValueConfig ||
          themeModeNeedsNormalize ||
          appearanceModeNeedsNormalize ||
          rawUpdateToVariant != normalizedUpdateToVariant,
    );
  }

  Map<String, bool> _decodeBoolMap(String? rawJson) {
    if (rawJson == null || rawJson.trim().isEmpty) {
      return <String, bool>{};
    }
    try {
      final decoded = json.decode(rawJson);
      if (decoded is! Map) return <String, bool>{};
      final out = <String, bool>{};
      decoded.forEach((rawKey, rawValue) {
        final key = '$rawKey'.trim();
        if (key.isEmpty) return;
        if (rawValue is bool) {
          out[key] = rawValue;
          return;
        }
        if (rawValue is num) {
          out[key] = rawValue != 0;
          return;
        }
        if (rawValue is String) {
          final normalized = rawValue.trim().toLowerCase();
          if (normalized == 'true' || normalized == '1') {
            out[key] = true;
            return;
          }
          if (normalized == 'false' || normalized == '0') {
            out[key] = false;
          }
        }
      });
      return out;
    } catch (_) {
      return <String, bool>{};
    }
  }

  Future<void> _persistBoolMap(String key, Map<String, bool> value) async {
    if (!_isInitialized) return;
    await _prefs.setString(key, json.encode(value));
  }

  Map<String, int> _decodeIntMap(String? rawJson) {
    if (rawJson == null || rawJson.trim().isEmpty) {
      return <String, int>{};
    }
    try {
      final decoded = json.decode(rawJson);
      if (decoded is! Map) return <String, int>{};
      final out = <String, int>{};
      decoded.forEach((rawKey, rawValue) {
        final key = '$rawKey'.trim();
        if (key.isEmpty) return;
        if (rawValue is int) {
          out[key] = rawValue;
          return;
        }
        if (rawValue is num) {
          out[key] = rawValue.round();
          return;
        }
        if (rawValue is String) {
          final parsed = int.tryParse(rawValue.trim());
          if (parsed != null) {
            out[key] = parsed;
          }
        }
      });
      return out;
    } catch (_) {
      return <String, int>{};
    }
  }

  Future<void> _persistIntMap(String key, Map<String, int> value) async {
    if (!_isInitialized) return;
    await _prefs.setString(key, json.encode(value));
  }

  Map<String, String> _decodeStringMap(String? rawJson) {
    if (rawJson == null || rawJson.trim().isEmpty) {
      return <String, String>{};
    }
    try {
      final decoded = json.decode(rawJson);
      if (decoded is! Map) return <String, String>{};
      final out = <String, String>{};
      decoded.forEach((rawKey, rawValue) {
        final key = '$rawKey'.trim();
        final value = '$rawValue'.trim();
        if (key.isEmpty || value.isEmpty) return;
        out[key] = value;
      });
      return out;
    } catch (_) {
      return <String, String>{};
    }
  }

  Future<void> _persistStringMap(String key, Map<String, String> value) async {
    if (!_isInitialized) return;
    await _prefs.setString(key, json.encode(value));
  }

  bool getBookCanUpdate(String bookId, {bool fallback = true}) {
    if (!_isInitialized) return fallback;
    final key = bookId.trim();
    if (key.isEmpty) return fallback;
    return _bookCanUpdateMap[key] ?? fallback;
  }

  Future<void> saveBooksCanUpdate(
      Iterable<String> bookIds, bool canUpdate) async {
    if (!_isInitialized) return;
    final normalizedIds = <String>{};
    for (final rawId in bookIds) {
      final key = rawId.trim();
      if (key.isEmpty) continue;
      normalizedIds.add(key);
    }
    if (normalizedIds.isEmpty) return;
    final nextMap = Map<String, bool>.from(_bookCanUpdateMap);
    for (final id in normalizedIds) {
      nextMap[id] = canUpdate;
    }
    _bookCanUpdateMap = nextMap;
    await _persistBoolMap(_keyBookCanUpdateMap, _bookCanUpdateMap);
  }

  Future<void> saveBookCanUpdate(String bookId, bool canUpdate) async {
    await saveBooksCanUpdate(<String>[bookId], canUpdate);
  }

  bool getBookSplitLongChapter(String bookId, {bool fallback = true}) {
    if (!_isInitialized) return fallback;
    final key = bookId.trim();
    if (key.isEmpty) return fallback;
    return _bookSplitLongChapterMap[key] ?? fallback;
  }

  Future<void> saveBookSplitLongChapter(
    String bookId,
    bool splitLongChapter,
  ) async {
    if (!_isInitialized) return;
    final key = bookId.trim();
    if (key.isEmpty) return;
    _bookSplitLongChapterMap = Map<String, bool>.from(_bookSplitLongChapterMap)
      ..[key] = splitLongChapter;
    await _persistBoolMap(
      _keyBookSplitLongChapterMap,
      _bookSplitLongChapterMap,
    );
  }

  String? getBookTxtTocRule(String bookId) {
    if (!_isInitialized) return null;
    final key = bookId.trim();
    if (key.isEmpty) return null;
    final value = _bookTxtTocRuleMap[key];
    if (value == null) return null;
    final normalized = value.trim();
    if (normalized.isEmpty) return null;
    return normalized;
  }

  Future<void> saveBookTxtTocRule(String bookId, String? tocRuleRegex) async {
    if (!_isInitialized) return;
    final key = bookId.trim();
    if (key.isEmpty) return;
    final normalized = (tocRuleRegex ?? '').trim();
    final nextMap = Map<String, String>.from(_bookTxtTocRuleMap);
    if (normalized.isEmpty) {
      nextMap.remove(key);
    } else {
      nextMap[key] = normalized;
    }
    _bookTxtTocRuleMap = nextMap;
    await _persistStringMap(_keyBookTxtTocRuleMap, _bookTxtTocRuleMap);
  }

  bool getBookUseReplaceRule(String bookId, {bool fallback = true}) {
    if (!_isInitialized) return fallback;
    final key = bookId.trim();
    if (key.isEmpty) return fallback;
    return _bookUseReplaceRuleMap[key] ?? fallback;
  }

  Future<void> saveBookUseReplaceRule(
    String bookId,
    bool useReplaceRule,
  ) async {
    if (!_isInitialized) return;
    final key = bookId.trim();
    if (key.isEmpty) return;
    _bookUseReplaceRuleMap = Map<String, bool>.from(_bookUseReplaceRuleMap)
      ..[key] = useReplaceRule;
    await _persistBoolMap(
      _keyBookUseReplaceRuleMap,
      _bookUseReplaceRuleMap,
    );
  }

  int? getBookPageAnim(String bookId) {
    if (!_isInitialized) return null;
    final key = bookId.trim();
    if (key.isEmpty) return null;
    final value = _bookPageAnimMap[key];
    if (value == null) return null;
    if (value < 0 || value > 4) return null;
    return value;
  }

  Future<void> saveBookPageAnim(String bookId, int? pageAnim) async {
    if (!_isInitialized) return;
    final key = bookId.trim();
    if (key.isEmpty) return;
    final nextMap = Map<String, int>.from(_bookPageAnimMap);
    if (pageAnim == null) {
      nextMap.remove(key);
    } else {
      final normalized = pageAnim.clamp(0, 4).toInt();
      nextMap[key] = normalized;
    }
    _bookPageAnimMap = nextMap;
    await _persistIntMap(_keyBookPageAnimMap, _bookPageAnimMap);
  }

  bool getTocUiUseReplace({bool fallback = false}) {
    if (!_isInitialized) return fallback;
    return _prefs.getBool(_keyTocUiUseReplace) ?? fallback;
  }

  Future<void> saveTocUiUseReplace(bool enabled) async {
    if (!_isInitialized) return;
    await _prefs.setBool(_keyTocUiUseReplace, enabled);
  }

  bool getTocUiLoadWordCount({bool fallback = true}) {
    if (!_isInitialized) return fallback;
    return _prefs.getBool(_keyTocUiLoadWordCount) ?? fallback;
  }

  Future<void> saveTocUiLoadWordCount(bool enabled) async {
    if (!_isInitialized) return;
    await _prefs.setBool(_keyTocUiLoadWordCount, enabled);
  }

  bool getChangeSourceLoadToc({bool fallback = false}) {
    if (!_isInitialized) return fallback;
    return _prefs.getBool(_keyChangeSourceLoadToc) ?? fallback;
  }

  bool getChangeSourceLoadInfo({bool fallback = false}) {
    if (!_isInitialized) return fallback;
    return _prefs.getBool(_keyChangeSourceLoadInfo) ?? fallback;
  }

  bool getChangeSourceLoadWordCount({bool fallback = false}) {
    if (!_isInitialized) return fallback;
    return _prefs.getBool(_keyChangeSourceLoadWordCount) ?? fallback;
  }

  Future<void> saveChangeSourceLoadWordCount(bool enabled) async {
    if (!_isInitialized) return;
    await _prefs.setBool(_keyChangeSourceLoadWordCount, enabled);
  }

  bool getChangeSourceCheckAuthor({bool fallback = false}) {
    if (!_isInitialized) return fallback;
    return _prefs.getBool(_keyChangeSourceCheckAuthor) ?? fallback;
  }

  String getChangeSourceGroup({String fallback = ''}) {
    if (!_isInitialized) return fallback.trim();
    final value = _prefs.getString(_keyChangeSourceGroup) ?? fallback;
    return value.trim();
  }

  Future<void> saveChangeSourceCheckAuthor(bool enabled) async {
    if (!_isInitialized) return;
    await _prefs.setBool(_keyChangeSourceCheckAuthor, enabled);
  }

  Future<void> saveChangeSourceGroup(String group) async {
    if (!_isInitialized) return;
    await _prefs.setString(_keyChangeSourceGroup, group.trim());
  }

  Future<void> saveChangeSourceLoadInfo(bool enabled) async {
    if (!_isInitialized) return;
    await _prefs.setBool(_keyChangeSourceLoadInfo, enabled);
  }

  Future<void> saveChangeSourceLoadToc(bool enabled) async {
    if (!_isInitialized) return;
    await _prefs.setBool(_keyChangeSourceLoadToc, enabled);
  }

  int getBatchChangeSourceDelay({int fallback = 0}) {
    if (!_isInitialized) return fallback.clamp(0, 9999).toInt();
    final value = _prefs.getInt(_keyBatchChangeSourceDelay) ?? fallback;
    return value.clamp(0, 9999).toInt();
  }

  Future<void> saveBatchChangeSourceDelay(int seconds) async {
    if (!_isInitialized) return;
    final normalized = seconds.clamp(0, 9999).toInt();
    await _prefs.setInt(_keyBatchChangeSourceDelay, normalized);
  }

  bool getOpenBookInfoByClickTitle({bool fallback = true}) {
    if (!_isInitialized) return fallback;
    return _prefs.getBool(_keyOpenBookInfoByClickTitle) ?? fallback;
  }

  Future<void> saveOpenBookInfoByClickTitle(bool enabled) async {
    if (!_isInitialized) return;
    await _prefs.setBool(_keyOpenBookInfoByClickTitle, enabled);
  }

  bool getDeleteBookOriginal({bool fallback = false}) {
    if (!_isInitialized) return fallback;
    return _prefs.getBool(_keyDeleteBookOriginal) ?? fallback;
  }

  Future<void> saveDeleteBookOriginal(bool enabled) async {
    if (!_isInitialized) return;
    await _prefs.setBool(_keyDeleteBookOriginal, enabled);
  }

  bool getAudioPlayUseWakeLock({bool fallback = false}) {
    if (!_isInitialized) return fallback;
    return _prefs.getBool(_keyAudioPlayWakeLock) ?? fallback;
  }

  Future<void> saveAudioPlayUseWakeLock(bool enabled) async {
    if (!_isInitialized) return;
    await _prefs.setBool(_keyAudioPlayWakeLock, enabled);
  }

  int getContentSelectSpeakMode({int fallback = 0}) {
    if (!_isInitialized) return fallback;
    final value = _prefs.getInt(_keyContentSelectSpeakMod) ?? fallback;
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
    if (!_isInitialized) return;
    await _prefs.setInt(_keyContentSelectSpeakMod, mode == 1 ? 1 : 0);
  }

  Future<void> saveEnableReadRecord(bool enabled) async {
    if (!_isInitialized) return;
    await _prefs.setBool(_keyEnableReadRecord, enabled);
  }

  int getReadRecordSort({int fallback = 0}) {
    final normalizedFallback = _normalizeReadRecordSort(fallback);
    if (!_isInitialized) return normalizedFallback;
    final value = _prefs.getInt(_keyReadRecordSort) ?? normalizedFallback;
    return _normalizeReadRecordSort(value);
  }

  Future<void> saveReadRecordSort(int sortMode) async {
    if (!_isInitialized) return;
    await _prefs.setInt(_keyReadRecordSort, _normalizeReadRecordSort(sortMode));
  }

  int _normalizeReadRecordSort(int value) {
    if (value == 1 || value == 2) return value;
    return 0;
  }

  int getBookReadRecordDurationMs(String bookId, {int fallback = 0}) {
    if (!_isInitialized) return fallback < 0 ? 0 : fallback;
    final key = bookId.trim();
    if (key.isEmpty) return fallback < 0 ? 0 : fallback;
    final value = _bookReadRecordDurationMap[key];
    if (value == null) return fallback < 0 ? 0 : fallback;
    return value < 0 ? 0 : value;
  }

  Map<String, int> getBookReadRecordDurationSnapshot() {
    if (!_isInitialized || _bookReadRecordDurationMap.isEmpty) {
      return const <String, int>{};
    }
    return Map<String, int>.unmodifiable(_bookReadRecordDurationMap);
  }

  int getTotalBookReadRecordDurationMs() {
    if (!_isInitialized || _bookReadRecordDurationMap.isEmpty) {
      return 0;
    }
    var total = 0;
    for (final value in _bookReadRecordDurationMap.values) {
      if (value <= 0) continue;
      total += value;
    }
    return total;
  }

  Future<void> addBookReadRecordDurationMs(
    String bookId,
    int durationMs,
  ) async {
    if (!_isInitialized) return;
    final key = bookId.trim();
    if (key.isEmpty) return;
    final safeDuration = durationMs < 0 ? 0 : durationMs;
    if (safeDuration == 0) return;
    final current = _bookReadRecordDurationMap[key] ?? 0;
    _bookReadRecordDurationMap = Map<String, int>.from(
      _bookReadRecordDurationMap,
    )..[key] = current + safeDuration;
    await _persistIntMap(
      _keyBookReadRecordDurationMap,
      _bookReadRecordDurationMap,
    );
  }

  Future<void> clearBookReadRecordDuration(String bookId) async {
    if (!_isInitialized) return;
    final key = bookId.trim();
    if (key.isEmpty || !_bookReadRecordDurationMap.containsKey(key)) return;
    _bookReadRecordDurationMap = Map<String, int>.from(
      _bookReadRecordDurationMap,
    )..remove(key);
    await _persistIntMap(
      _keyBookReadRecordDurationMap,
      _bookReadRecordDurationMap,
    );
  }

  Future<void> clearAllBookReadRecordDuration() async {
    if (!_isInitialized) return;
    _bookReadRecordDurationMap = <String, int>{};
    await _prefs.remove(_keyBookReadRecordDurationMap);
  }

  bool getBookReSegment(String bookId, {bool fallback = false}) {
    if (!_isInitialized) return fallback;
    final key = bookId.trim();
    if (key.isEmpty) return fallback;
    return _bookReSegmentMap[key] ?? fallback;
  }

  Future<void> saveBookReSegment(String bookId, bool enabled) async {
    if (!_isInitialized) return;
    final key = bookId.trim();
    if (key.isEmpty) return;
    _bookReSegmentMap = Map<String, bool>.from(_bookReSegmentMap)
      ..[key] = enabled;
    await _persistBoolMap(_keyBookReSegmentMap, _bookReSegmentMap);
  }

  String getBookImageStyle(
    String bookId, {
    String fallback = _defaultImageStyle,
  }) {
    if (!_isInitialized) return _normalizeImageStyle(fallback);
    final key = bookId.trim();
    if (key.isEmpty) return _normalizeImageStyle(fallback);
    final value = _bookImageStyleMap[key];
    if (value == null || value.trim().isEmpty) {
      return _normalizeImageStyle(fallback);
    }
    return _normalizeImageStyle(value);
  }

  Future<void> saveBookImageStyle(String bookId, String style) async {
    if (!_isInitialized) return;
    final key = bookId.trim();
    if (key.isEmpty) return;
    final normalized = _normalizeImageStyle(style);
    _bookImageStyleMap = Map<String, String>.from(_bookImageStyleMap)
      ..[key] = normalized;
    await _persistStringMap(_keyBookImageStyleMap, _bookImageStyleMap);
  }

  String _normalizeImageStyle(String raw) {
    final normalized = raw.trim().toUpperCase();
    if (_validImageStyles.contains(normalized)) {
      return normalized;
    }
    return _defaultImageStyle;
  }

  String? _chapterSameTitleRemovedKey(String bookId, String chapterId) {
    final safeBookId = bookId.trim();
    final safeChapterId = chapterId.trim();
    if (safeBookId.isEmpty || safeChapterId.isEmpty) return null;
    return '$safeBookId::$safeChapterId';
  }

  bool getChapterSameTitleRemoved(
    String bookId,
    String chapterId, {
    bool fallback = false,
  }) {
    if (!_isInitialized) return fallback;
    final key = _chapterSameTitleRemovedKey(bookId, chapterId);
    if (key == null) return fallback;
    return _chapterSameTitleRemovedMap[key] ?? fallback;
  }

  Future<void> saveChapterSameTitleRemoved(
    String bookId,
    String chapterId,
    bool removed,
  ) async {
    if (!_isInitialized) return;
    final key = _chapterSameTitleRemovedKey(bookId, chapterId);
    if (key == null) return;
    _chapterSameTitleRemovedMap = Map<String, bool>.from(
      _chapterSameTitleRemovedMap,
    )..[key] = removed;
    await _persistBoolMap(
      _keyChapterSameTitleRemovedMap,
      _chapterSameTitleRemovedMap,
    );
  }

  bool getBookDelRubyTag(String bookId, {bool fallback = false}) {
    if (!_isInitialized) return fallback;
    final key = bookId.trim();
    if (key.isEmpty) return fallback;
    return _bookDelRubyTagMap[key] ?? fallback;
  }

  Future<void> saveBookDelRubyTag(String bookId, bool enabled) async {
    if (!_isInitialized) return;
    final key = bookId.trim();
    if (key.isEmpty) return;
    _bookDelRubyTagMap = Map<String, bool>.from(_bookDelRubyTagMap)
      ..[key] = enabled;
    await _persistBoolMap(_keyBookDelRubyTagMap, _bookDelRubyTagMap);
  }

  bool getBookDelHTag(String bookId, {bool fallback = false}) {
    if (!_isInitialized) return fallback;
    final key = bookId.trim();
    if (key.isEmpty) return fallback;
    return _bookDelHTagMap[key] ?? fallback;
  }

  Future<void> saveBookDelHTag(String bookId, bool enabled) async {
    if (!_isInitialized) return;
    final key = bookId.trim();
    if (key.isEmpty) return;
    _bookDelHTagMap = Map<String, bool>.from(_bookDelHTagMap)..[key] = enabled;
    await _persistBoolMap(_keyBookDelHTagMap, _bookDelHTagMap);
  }

  bool getBookReadSimulating(String bookId, {bool fallback = false}) {
    if (!_isInitialized) return fallback;
    final key = bookId.trim();
    if (key.isEmpty) return fallback;
    return _bookReadSimulatingMap[key] ?? fallback;
  }

  Future<void> saveBookReadSimulating(String bookId, bool enabled) async {
    if (!_isInitialized) return;
    final key = bookId.trim();
    if (key.isEmpty) return;
    _bookReadSimulatingMap = Map<String, bool>.from(_bookReadSimulatingMap)
      ..[key] = enabled;
    await _persistBoolMap(_keyBookReadSimulatingMap, _bookReadSimulatingMap);
  }

  int getBookSimulatedStartChapter(String bookId, {int fallback = 0}) {
    if (!_isInitialized) return fallback;
    final key = bookId.trim();
    if (key.isEmpty) return fallback;
    final value = _bookSimulatedStartChapterMap[key];
    if (value == null) return fallback;
    if (value < 0) return 0;
    return value;
  }

  Future<void> saveBookSimulatedStartChapter(
    String bookId,
    int startChapter,
  ) async {
    if (!_isInitialized) return;
    final key = bookId.trim();
    if (key.isEmpty) return;
    final normalized = startChapter < 0 ? 0 : startChapter;
    _bookSimulatedStartChapterMap =
        Map<String, int>.from(_bookSimulatedStartChapterMap)
          ..[key] = normalized;
    await _persistIntMap(
      _keyBookSimulatedStartChapterMap,
      _bookSimulatedStartChapterMap,
    );
  }

  int getBookSimulatedDailyChapters(String bookId, {int fallback = 3}) {
    if (!_isInitialized) return fallback;
    final key = bookId.trim();
    if (key.isEmpty) return fallback;
    final value = _bookSimulatedDailyChaptersMap[key];
    if (value == null) return fallback;
    if (value < 0) return 0;
    return value;
  }

  Future<void> saveBookSimulatedDailyChapters(
    String bookId,
    int dailyChapters,
  ) async {
    if (!_isInitialized) return;
    final key = bookId.trim();
    if (key.isEmpty) return;
    final normalized = dailyChapters < 0 ? 0 : dailyChapters;
    _bookSimulatedDailyChaptersMap =
        Map<String, int>.from(_bookSimulatedDailyChaptersMap)
          ..[key] = normalized;
    await _persistIntMap(
      _keyBookSimulatedDailyChaptersMap,
      _bookSimulatedDailyChaptersMap,
    );
  }

  DateTime? getBookSimulatedStartDate(String bookId) {
    if (!_isInitialized) return null;
    final key = bookId.trim();
    if (key.isEmpty) return null;
    final value = _bookSimulatedStartDateMap[key]?.trim();
    if (value == null || value.isEmpty) return null;
    final parsed = DateTime.tryParse(value);
    if (parsed == null) return null;
    return DateTime(parsed.year, parsed.month, parsed.day);
  }

  Future<void> saveBookSimulatedStartDate(
    String bookId,
    DateTime? startDate,
  ) async {
    if (!_isInitialized) return;
    final key = bookId.trim();
    if (key.isEmpty) return;
    final nextMap = Map<String, String>.from(_bookSimulatedStartDateMap);
    if (startDate == null) {
      nextMap.remove(key);
    } else {
      nextMap[key] = _formatDateOnly(_normalizeDateOnly(startDate));
    }
    _bookSimulatedStartDateMap = nextMap;
    await _persistStringMap(
      _keyBookSimulatedStartDateMap,
      _bookSimulatedStartDateMap,
    );
  }

  Future<void> saveBookSimulatedReadingConfig(
    String bookId, {
    required bool enabled,
    required int startChapter,
    required int dailyChapters,
    required DateTime startDate,
  }) async {
    if (!_isInitialized) return;
    final key = bookId.trim();
    if (key.isEmpty) return;

    final safeStartChapter = startChapter < 0 ? 0 : startChapter;
    final safeDailyChapters = dailyChapters < 0 ? 0 : dailyChapters;
    final safeDate = _normalizeDateOnly(startDate);

    _bookReadSimulatingMap = Map<String, bool>.from(_bookReadSimulatingMap)
      ..[key] = enabled;
    _bookSimulatedStartChapterMap =
        Map<String, int>.from(_bookSimulatedStartChapterMap)
          ..[key] = safeStartChapter;
    _bookSimulatedDailyChaptersMap =
        Map<String, int>.from(_bookSimulatedDailyChaptersMap)
          ..[key] = safeDailyChapters;
    _bookSimulatedStartDateMap = Map<String, String>.from(
      _bookSimulatedStartDateMap,
    )..[key] = _formatDateOnly(safeDate);

    await Future.wait<void>([
      _persistBoolMap(_keyBookReadSimulatingMap, _bookReadSimulatingMap),
      _persistIntMap(
        _keyBookSimulatedStartChapterMap,
        _bookSimulatedStartChapterMap,
      ),
      _persistIntMap(
        _keyBookSimulatedDailyChaptersMap,
        _bookSimulatedDailyChaptersMap,
      ),
      _persistStringMap(
        _keyBookSimulatedStartDateMap,
        _bookSimulatedStartDateMap,
      ),
    ]);
  }

  DateTime _normalizeDateOnly(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }

  String _formatDateOnly(DateTime value) {
    final yyyy = value.year.toString().padLeft(4, '0');
    final mm = value.month.toString().padLeft(2, '0');
    final dd = value.day.toString().padLeft(2, '0');
    return '$yyyy-$mm-$dd';
  }

  String? getBookRemoteUploadUrl(String bookId) {
    if (!_isInitialized) return null;
    final key = bookId.trim();
    if (key.isEmpty) return null;
    final value = _bookRemoteUploadUrlMap[key]?.trim();
    if (value == null || value.isEmpty) return null;
    return value;
  }

  Future<void> saveBookRemoteUploadUrl(
    String bookId,
    String remoteUrl,
  ) async {
    if (!_isInitialized) return;
    final key = bookId.trim();
    final value = remoteUrl.trim();
    if (key.isEmpty || value.isEmpty) return;
    _bookRemoteUploadUrlMap = Map<String, String>.from(_bookRemoteUploadUrlMap)
      ..[key] = value;
    await _persistStringMap(
        _keyBookRemoteUploadUrlMap, _bookRemoteUploadUrlMap);
  }

  String? getBookReaderImageSizeSnapshot(String bookId) {
    if (!_isInitialized) return null;
    final key = bookId.trim();
    if (key.isEmpty) return null;
    final value = _bookReaderImageSizeSnapshotMap[key]?.trim();
    if (value == null || value.isEmpty) return null;
    return value;
  }

  Future<void> saveBookReaderImageSizeSnapshot(
    String bookId,
    String snapshotJson,
  ) async {
    if (!_isInitialized) return;
    final key = bookId.trim();
    if (key.isEmpty) return;
    final value = snapshotJson.trim();
    if (value.isEmpty) {
      if (_bookReaderImageSizeSnapshotMap.containsKey(key)) {
        _bookReaderImageSizeSnapshotMap =
            Map<String, String>.from(_bookReaderImageSizeSnapshotMap)
              ..remove(key);
        await _persistStringMap(
          _keyBookReaderImageSizeSnapshotMap,
          _bookReaderImageSizeSnapshotMap,
        );
      }
      return;
    }
    if (value.length > _maxReaderImageSizeSnapshotBytes) {
      return;
    }
    _bookReaderImageSizeSnapshotMap =
        Map<String, String>.from(_bookReaderImageSizeSnapshotMap)
          ..[key] = value;
    await _persistStringMap(
      _keyBookReaderImageSizeSnapshotMap,
      _bookReaderImageSizeSnapshotMap,
    );
  }

  Future<void> _migrateReadingSettingsSchema({
    required bool forcePersist,
  }) async {
    final currentVersion = _prefs.getInt(_keyReadingSettingsSchemaVersion) ?? 0;
    final normalized = _readingSettings.sanitize();
    final normalizedJson = json.encode(normalized.toJson());
    final storedJson = _prefs.getString(_keyReadingSettings);
    final shouldPersist = forcePersist ||
        currentVersion < _readingSettingsSchemaVersion ||
        storedJson != normalizedJson;

    _readingSettings = normalized;

    if (shouldPersist) {
      await _prefs.setString(_keyReadingSettings, normalizedJson);
    }

    if (currentVersion != _readingSettingsSchemaVersion) {
      await _prefs.setInt(
        _keyReadingSettingsSchemaVersion,
        _readingSettingsSchemaVersion,
      );
    }
  }

  Future<void> saveReadingSettings(ReadingSettings settings) async {
    final safeSettings = settings.sanitize();
    _readingSettings = safeSettings;
    _readingSettingsNotifier.value = safeSettings;
    await _prefs.setString(
      _keyReadingSettings,
      json.encode(safeSettings.toJson()),
    );
    final currentVersion = _prefs.getInt(_keyReadingSettingsSchemaVersion) ?? 0;
    if (currentVersion != _readingSettingsSchemaVersion) {
      await _prefs.setInt(
        _keyReadingSettingsSchemaVersion,
        _readingSettingsSchemaVersion,
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
    _appSettings = normalizedSettings;
    _appSettingsNotifier.value = normalizedSettings;
    await _prefs.setString(
      _keyAppSettings,
      json.encode(normalizedSettings.toJson()),
    );
  }

  Future<void> _saveAppSettingsPatch(
    AppSettings Function(AppSettings current) patch,
  ) async {
    if (!_isInitialized) return;
    final next = patch(_appSettings);
    await saveAppSettings(next);
  }

  Future<void> saveAutoRefresh(bool enabled) async {
    await _saveAppSettingsPatch(
      (current) => current.copyWith(autoRefresh: enabled),
    );
  }

  Future<void> saveDefaultToRead(bool enabled) async {
    await _saveAppSettingsPatch(
      (current) => current.copyWith(defaultToRead: enabled),
    );
  }

  Future<void> saveShowDiscovery(bool enabled) async {
    await _saveAppSettingsPatch(
      (current) => current.copyWith(showDiscovery: enabled),
    );
  }

  Future<void> saveShowRss(bool enabled) async {
    // 迁移排除（EX-02）：RSS 在当前构建为 blocked，禁止写入开关避免误开放入口。
    if (MigrationExclusions.excludeRss) {
      debugPrint('[settings] 迁移排除：阻断 saveShowRss（excludeRss=true），不写入');
      return;
    }
    await _saveAppSettingsPatch(
      (current) => current.copyWith(showRss: enabled),
    );
  }

  Future<void> saveDefaultHomePage(MainDefaultHomePage value) async {
    // 迁移排除（EX-02）：RSS 在当前构建为 blocked，默认主页选择仅保留锚点，不允许写入为 rss。
    if (MigrationExclusions.excludeRss && value == MainDefaultHomePage.rss) {
      debugPrint(
        '[settings] 迁移排除：阻断 saveDefaultHomePage（excludeRss=true, value=rss），不写入',
      );
      return;
    }
    await _saveAppSettingsPatch(
      (current) => current.copyWith(defaultHomePage: value),
    );
  }

  Future<void> savePreDownloadNum(int value) async {
    await _saveAppSettingsPatch(
      (current) => current.copyWith(preDownloadNum: value),
    );
  }

  Future<void> saveThreadCount(int value) async {
    await _saveAppSettingsPatch(
      (current) => current.copyWith(threadCount: value),
    );
  }

  Future<void> saveBitmapCacheSize(int value) async {
    await _saveAppSettingsPatch(
      (current) => current.copyWith(bitmapCacheSize: value),
    );
  }

  Future<void> saveImageRetainNum(int value) async {
    // 迁移排除（EX-04）：漫画模块 blocked，相关配置仅保留锚点与回显，不允许持久化改动。
    if (MigrationExclusions.excludeManga) {
      debugPrint(
        '[settings] 迁移排除：阻断 saveImageRetainNum（excludeManga=true），不写入',
      );
      return;
    }
    await _saveAppSettingsPatch(
      (current) => current.copyWith(imageRetainNum: value),
    );
  }

  Future<void> saveReplaceEnableDefault(bool enabled) async {
    await _saveAppSettingsPatch(
      (current) => current.copyWith(replaceEnableDefault: enabled),
    );
  }

  Future<void> saveCronet(bool enabled) async {
    await _saveAppSettingsPatch(
      (current) => current.copyWith(cronet: enabled),
    );
  }

  Future<void> saveAntiAlias(bool enabled) async {
    await _saveAppSettingsPatch(
      (current) => current.copyWith(antiAlias: enabled),
    );
  }

  Future<void> saveMediaButtonOnExit(bool enabled) async {
    // 迁移排除（EX-03）：TTS 在当前构建为 blocked，避免耳机按键相关开关被误写入。
    if (MigrationExclusions.excludeTts) {
      debugPrint(
        '[settings] 迁移排除：阻断 saveMediaButtonOnExit（excludeTts=true），不写入',
      );
      return;
    }
    await _saveAppSettingsPatch(
      (current) => current.copyWith(mediaButtonOnExit: enabled),
    );
  }

  Future<void> saveReadAloudByMediaButton(bool enabled) async {
    // 迁移排除（EX-03）：TTS 在当前构建为 blocked，避免形成“开关可改但功能不可用”的状态错觉。
    if (MigrationExclusions.excludeTts) {
      debugPrint(
        '[settings] 迁移排除：阻断 saveReadAloudByMediaButton（excludeTts=true），不写入',
      );
      return;
    }
    await _saveAppSettingsPatch(
      (current) => current.copyWith(readAloudByMediaButton: enabled),
    );
  }

  Future<void> saveIgnoreAudioFocus(bool enabled) async {
    // 迁移排除（EX-03）：TTS 在当前构建为 blocked，相关音频焦点配置不允许写入。
    if (MigrationExclusions.excludeTts) {
      debugPrint(
        '[settings] 迁移排除：阻断 saveIgnoreAudioFocus（excludeTts=true），不写入',
      );
      return;
    }
    await _saveAppSettingsPatch(
      (current) => current.copyWith(ignoreAudioFocus: enabled),
    );
  }

  Future<void> saveAutoClearExpired(bool enabled) async {
    await _saveAppSettingsPatch(
      (current) => current.copyWith(autoClearExpired: enabled),
    );
  }

  Future<void> saveShowAddToShelfAlert(bool enabled) async {
    await _saveAppSettingsPatch(
      (current) => current.copyWith(showAddToShelfAlert: enabled),
    );
  }

  Future<void> saveUpdateToVariant(String value) async {
    final updateToVariant = AppSettings.normalizeUpdateToVariant(value);
    await _saveAppSettingsPatch(
      (current) => current.copyWith(
        updateToVariant: updateToVariant,
      ),
    );
  }

  Future<void> saveShowMangaUi(bool enabled) async {
    // 迁移排除（EX-04）：漫画模块 blocked，禁止写入漫画浏览开关，避免业务链路回流。
    if (MigrationExclusions.excludeManga) {
      debugPrint(
        '[settings] 迁移排除：阻断 saveShowMangaUi（excludeManga=true），不写入',
      );
      return;
    }
    await _saveAppSettingsPatch(
      (current) => current.copyWith(showMangaUi: enabled),
    );
  }

  Future<void> saveProcessText(bool enabled) async {
    await _saveAppSettingsPatch(
      (current) => current.copyWith(processText: enabled),
    );
  }

  Future<void> saveRecordLog(bool enabled) async {
    await _saveAppSettingsPatch(
      (current) => current.copyWith(recordLog: enabled),
    );
  }

  Future<void> saveRecordHeapDump(bool enabled) async {
    await _saveAppSettingsPatch(
      (current) => current.copyWith(recordHeapDump: enabled),
    );
  }

  Future<void> saveLauncherIcon(String value) async {
    final normalized = value.trim();
    await _saveAppSettingsPatch(
      (current) => current.copyWith(
        launcherIcon:
            normalized.isEmpty ? AppSettings.defaultLauncherIcon : normalized,
      ),
    );
  }

  Future<void> saveTransparentStatusBar(bool enabled) async {
    await _saveAppSettingsPatch(
      (current) => current.copyWith(transparentStatusBar: enabled),
    );
  }

  Future<void> saveImmNavigationBar(bool enabled) async {
    await _saveAppSettingsPatch(
      (current) => current.copyWith(immNavigationBar: enabled),
    );
  }

  Future<void> saveBarElevation(int value) async {
    await _saveAppSettingsPatch(
      (current) => current.copyWith(barElevation: value),
    );
  }

  Future<void> saveFontScale(int value) async {
    await _saveAppSettingsPatch(
      (current) => current.copyWith(fontScale: value),
    );
  }

  Future<void> saveBackgroundImage(String? path) async {
    final normalized = (path ?? '').trim();
    await _saveAppSettingsPatch(
      (current) => current.copyWith(backgroundImage: normalized),
    );
  }

  Future<void> saveBackgroundImageNight(String? path) async {
    final normalized = (path ?? '').trim();
    await _saveAppSettingsPatch(
      (current) => current.copyWith(backgroundImageNight: normalized),
    );
  }

  Future<void> saveBackgroundImageBlurring(int value) async {
    await _saveAppSettingsPatch(
      (current) => current.copyWith(backgroundImageBlurring: value),
    );
  }

  Future<void> saveBackgroundImageNightBlurring(int value) async {
    await _saveAppSettingsPatch(
      (current) => current.copyWith(backgroundImageNightBlurring: value),
    );
  }

  Future<void> saveSyncBookProgress(bool enabled) async {
    await _saveAppSettingsPatch(
      (current) => current.copyWith(syncBookProgress: enabled),
    );
  }

  Future<void> saveSyncBookProgressPlus(bool enabled) async {
    await _saveAppSettingsPatch(
      (current) => current.copyWith(syncBookProgressPlus: enabled),
    );
  }

  Future<void> saveWebDavDeviceName(String value) async {
    await _saveAppSettingsPatch(
      (current) => current.copyWith(webDavDeviceName: value.trim()),
    );
  }

  Future<void> saveBackupPath(String path) async {
    await _saveAppSettingsPatch(
      (current) => current.copyWith(backupPath: path.trim()),
    );
  }

  Future<void> saveOnlyLatestBackup(bool enabled) async {
    await _saveAppSettingsPatch(
      (current) => current.copyWith(onlyLatestBackup: enabled),
    );
  }

  Future<void> saveAutoCheckNewBackup(bool enabled) async {
    await _saveAppSettingsPatch(
      (current) => current.copyWith(autoCheckNewBackup: enabled),
    );
  }

  /// 读取“自动检查新备份”的本地对照时间（毫秒时间戳）。
  ///
  /// 说明：
  /// - 该值用于和远端最新备份时间比较，判断是否需要提示“发现新备份”；
  /// - 兼容 legado `LocalConfig.lastBackup` 语义：可能来自“已提示远端时间”
  ///   或“本地备份/恢复完成时间”；
  /// - 读取失败或未初始化时返回 [fallback]；
  /// - 返回值始终保证 `>= 0`。
  int getLastSeenWebDavBackupMillis({int fallback = 0}) {
    if (!_isInitialized) {
      return fallback < 0 ? 0 : fallback;
    }
    final value = _prefs.getInt(_keyLastSeenWebDavBackupMillis);
    if (value == null || value < 0) {
      return fallback < 0 ? 0 : fallback;
    }
    return value;
  }

  /// 保存“自动检查新备份”的本地对照时间（毫秒时间戳）。
  ///
  /// 约束：负值会被强制归零，避免脏数据导致重复弹窗判断异常。
  Future<void> saveLastSeenWebDavBackupMillis(int millis) async {
    if (!_isInitialized) return;
    final normalized = millis < 0 ? 0 : millis;
    await _prefs.setInt(_keyLastSeenWebDavBackupMillis, normalized);
  }

  Future<void> saveCoverLoadOnlyWifi(bool enabled) async {
    if (!_isInitialized) return;
    await _prefs.setBool(_keyLoadCoverOnlyWifi, enabled);
  }

  Future<void> saveUseDefaultCover(bool enabled) async {
    if (!_isInitialized) return;
    await _prefs.setBool(_keyUseDefaultCover, enabled);
  }

  Future<void> saveCoverRule(String value) async {
    if (!_isInitialized) return;
    final normalized = value.trim();
    if (normalized.isEmpty) {
      await _prefs.remove(_keyCoverRule);
      return;
    }
    await _prefs.setString(_keyCoverRule, normalized);
  }

  Future<void> saveDefaultCoverPath(String? path) async {
    if (!_isInitialized) return;
    final normalized = (path ?? '').trim();
    if (normalized.isEmpty) {
      await _prefs.remove(_keyDefaultCoverPath);
      return;
    }
    await _prefs.setString(_keyDefaultCoverPath, normalized);
  }

  Future<void> saveDefaultCoverDarkPath(String? path) async {
    if (!_isInitialized) return;
    final normalized = (path ?? '').trim();
    if (normalized.isEmpty) {
      await _prefs.remove(_keyDefaultCoverDarkPath);
      return;
    }
    await _prefs.setString(_keyDefaultCoverDarkPath, normalized);
  }

  Future<void> saveCoverShowName(bool enabled) async {
    if (!_isInitialized) return;
    await _prefs.setBool(_keyCoverShowName, enabled);
  }

  Future<void> saveCoverShowAuthor(bool enabled) async {
    if (!_isInitialized) return;
    await _prefs.setBool(_keyCoverShowAuthor, enabled);
  }

  Future<void> saveCoverShowNameNight(bool enabled) async {
    if (!_isInitialized) return;
    await _prefs.setBool(_keyCoverShowNameNight, enabled);
  }

  Future<void> saveCoverShowAuthorNight(bool enabled) async {
    if (!_isInitialized) return;
    await _prefs.setBool(_keyCoverShowAuthorNight, enabled);
  }

  Future<void> saveCustomWelcome(bool enabled) async {
    if (!_isInitialized) return;
    await _prefs.setBool(_keyCustomWelcome, enabled);
  }

  Future<void> saveWelcomeImagePath(String? path) async {
    if (!_isInitialized) return;
    final normalized = (path ?? '').trim();
    if (normalized.isEmpty) {
      await _prefs.remove(_keyWelcomeImagePath);
      return;
    }
    await _prefs.setString(_keyWelcomeImagePath, normalized);
  }

  Future<void> saveWelcomeImageDarkPath(String? path) async {
    if (!_isInitialized) return;
    final normalized = (path ?? '').trim();
    if (normalized.isEmpty) {
      await _prefs.remove(_keyWelcomeImageDarkPath);
      return;
    }
    await _prefs.setString(_keyWelcomeImageDarkPath, normalized);
  }

  Future<void> saveWelcomeShowText(bool enabled) async {
    if (!_isInitialized) return;
    await _prefs.setBool(_keyWelcomeShowText, enabled);
  }

  Future<void> saveWelcomeShowIcon(bool enabled) async {
    if (!_isInitialized) return;
    await _prefs.setBool(_keyWelcomeShowIcon, enabled);
  }

  Future<void> saveWelcomeShowTextDark(bool enabled) async {
    if (!_isInitialized) return;
    await _prefs.setBool(_keyWelcomeShowTextDark, enabled);
  }

  Future<void> saveWelcomeShowIconDark(bool enabled) async {
    if (!_isInitialized) return;
    await _prefs.setBool(_keyWelcomeShowIconDark, enabled);
  }

  Future<void> saveReaderChapterUrlOpenInBrowser(bool value) async {
    await _prefs.setBool(_keyReaderChapterUrlOpenInBrowser, value);
  }

  String _scrollOffsetKey(String bookId, {int? chapterIndex}) {
    if (chapterIndex == null) {
      return 'scroll_offset_$bookId';
    }
    return 'scroll_offset_${bookId}_c$chapterIndex';
  }

  String _chapterPageProgressKey(String bookId, int chapterIndex) {
    return 'page_progress_${bookId}_c$chapterIndex';
  }

  /// 保存特定书籍的滚动偏移量（当前落盘到 SharedPreferences）
  Future<void> saveScrollOffset(
    String bookId,
    double offset, {
    int? chapterIndex,
  }) async {
    if (chapterIndex == null) {
      await _prefs.setDouble(_scrollOffsetKey(bookId), offset);
      return;
    }
    await _prefs.setDouble(
      _scrollOffsetKey(bookId, chapterIndex: chapterIndex),
      offset,
    );
    // 向前兼容：章节级偏移写入时，同步更新书籍级偏移。
    await _prefs.setDouble(_scrollOffsetKey(bookId), offset);
  }

  double getScrollOffset(String bookId, {int? chapterIndex}) {
    if (chapterIndex == null) {
      return _prefs.getDouble(_scrollOffsetKey(bookId)) ?? 0.0;
    }
    final chapterOffset =
        _prefs.getDouble(_scrollOffsetKey(bookId, chapterIndex: chapterIndex));
    if (chapterOffset != null) {
      return chapterOffset;
    }
    // 兼容旧键与未命中章节：回退到书籍级偏移。
    return _prefs.getDouble(_scrollOffsetKey(bookId)) ?? 0.0;
  }

  Future<void> saveChapterPageProgress(
    String bookId, {
    required int chapterIndex,
    required double progress,
  }) async {
    final normalized = progress.clamp(0.0, 1.0).toDouble();
    await _prefs.setDouble(
      _chapterPageProgressKey(bookId, chapterIndex),
      normalized,
    );
  }

  double getChapterPageProgress(
    String bookId, {
    required int chapterIndex,
  }) {
    final value =
        _prefs.getDouble(_chapterPageProgressKey(bookId, chapterIndex));
    if (value == null) return 0.0;
    return value.clamp(0.0, 1.0).toDouble();
  }
}

class _DecodedAppSettings {
  final AppSettings settings;
  final bool needsRewrite;

  const _DecodedAppSettings({
    required this.settings,
    required this.needsRewrite,
  });
}
