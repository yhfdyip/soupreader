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
  static const int _readingSettingsSchemaVersion = 2;

  late SharedPreferences _prefs;
  late ReadingSettings _readingSettings;
  late AppSettings _appSettings;
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

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();

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
