import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  static const String _keyBookCanUpdateMap = 'book_can_update_map';
  static const String _keyBookSplitLongChapterMap =
      'book_split_long_chapter_map';
  static const String _keyBookTxtTocRuleMap = 'book_txt_toc_rule_map';
  static const String _keyBookUseReplaceRuleMap = 'book_use_replace_rule_map';
  static const String _keyTocUiUseReplace = 'toc_ui_use_replace';
  static const String _keyTocUiLoadWordCount = 'toc_ui_load_word_count';
  static const String _keyBookReSegmentMap = 'book_re_segment_map';
  static const String _keyBookImageStyleMap = 'book_image_style_map';
  static const String _keyChapterSameTitleRemovedMap =
      'chapter_same_title_removed_map';
  static const String _keyBookDelRubyTagMap = 'book_del_ruby_tag_map';
  static const String _keyBookDelHTagMap = 'book_del_h_tag_map';
  static const String _keyBookRemoteUploadUrlMap = 'book_remote_upload_url_map';
  static const String _keyBookReaderImageSizeSnapshotMap =
      'book_reader_image_size_snapshot_map';
  static const String _defaultImageStyle = 'DEFAULT';
  static const Set<String> _validImageStyles = <String>{
    'DEFAULT',
    'FULL',
    'TEXT',
    'SINGLE',
  };
  static const int _readingSettingsSchemaVersion = 3;
  static const int _maxReaderImageSizeSnapshotBytes = 120 * 1024;

  late SharedPreferences _prefs;
  late ReadingSettings _readingSettings;
  late AppSettings _appSettings;
  bool _isInitialized = false;
  Map<String, bool> _bookCanUpdateMap = <String, bool>{};
  Map<String, bool> _bookSplitLongChapterMap = <String, bool>{};
  Map<String, String> _bookTxtTocRuleMap = <String, String>{};
  Map<String, bool> _bookUseReplaceRuleMap = <String, bool>{};
  Map<String, bool> _bookReSegmentMap = <String, bool>{};
  Map<String, String> _bookImageStyleMap = <String, String>{};
  Map<String, bool> _chapterSameTitleRemovedMap = <String, bool>{};
  Map<String, bool> _bookDelRubyTagMap = <String, bool>{};
  Map<String, bool> _bookDelHTagMap = <String, bool>{};
  Map<String, String> _bookRemoteUploadUrlMap = <String, String>{};
  Map<String, String> _bookReaderImageSizeSnapshotMap = <String, String>{};
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

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
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

    final appJson = _prefs.getString(_keyAppSettings);
    if (appJson != null) {
      try {
        _appSettings = AppSettings.fromJson(json.decode(appJson));
      } catch (_) {
        _appSettings = const AppSettings();
      }
    } else {
      _appSettings = const AppSettings();
    }
    _appSettingsNotifier.value = _appSettings;

    _bookCanUpdateMap = _decodeBoolMap(_prefs.getString(_keyBookCanUpdateMap));
    _bookSplitLongChapterMap =
        _decodeBoolMap(_prefs.getString(_keyBookSplitLongChapterMap));
    _bookTxtTocRuleMap =
        _decodeStringMap(_prefs.getString(_keyBookTxtTocRuleMap));
    _bookUseReplaceRuleMap =
        _decodeBoolMap(_prefs.getString(_keyBookUseReplaceRuleMap));
    _bookReSegmentMap = _decodeBoolMap(_prefs.getString(_keyBookReSegmentMap));
    _bookImageStyleMap =
        _decodeStringMap(_prefs.getString(_keyBookImageStyleMap));
    _chapterSameTitleRemovedMap =
        _decodeBoolMap(_prefs.getString(_keyChapterSameTitleRemovedMap));
    _bookDelRubyTagMap =
        _decodeBoolMap(_prefs.getString(_keyBookDelRubyTagMap));
    _bookDelHTagMap = _decodeBoolMap(_prefs.getString(_keyBookDelHTagMap));
    _bookRemoteUploadUrlMap =
        _decodeStringMap(_prefs.getString(_keyBookRemoteUploadUrlMap));
    _bookReaderImageSizeSnapshotMap =
        _decodeStringMap(_prefs.getString(_keyBookReaderImageSizeSnapshotMap));
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

  Future<void> saveBookCanUpdate(String bookId, bool canUpdate) async {
    if (!_isInitialized) return;
    final key = bookId.trim();
    if (key.isEmpty) return;
    _bookCanUpdateMap = Map<String, bool>.from(_bookCanUpdateMap)
      ..[key] = canUpdate;
    await _persistBoolMap(_keyBookCanUpdateMap, _bookCanUpdateMap);
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
    _appSettings = settings;
    _appSettingsNotifier.value = settings;
    await _prefs.setString(_keyAppSettings, json.encode(settings.toJson()));
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
