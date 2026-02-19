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
  final ValueNotifier<AppSettings> _appSettingsNotifier =
      ValueNotifier(const AppSettings());

  ReadingSettings get readingSettings => _readingSettings;
  AppSettings get appSettings => _appSettings;
  ValueListenable<AppSettings> get appSettingsListenable =>
      _appSettingsNotifier;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();

    final jsonStr = _prefs.getString(_keyReadingSettings);
    if (jsonStr != null) {
      try {
        _readingSettings = ReadingSettings.fromJson(json.decode(jsonStr));
      } catch (e) {
        _readingSettings = const ReadingSettings();
      }
    } else {
      _readingSettings = const ReadingSettings();
    }

    await _migrateReadingSettingsSchema();
    await _normalizePageDirectionByMode();

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

  Future<void> _migrateReadingSettingsSchema() async {
    final currentVersion = _prefs.getInt(_keyReadingSettingsSchemaVersion) ?? 0;
    if (currentVersion >= _readingSettingsSchemaVersion) {
      return;
    }
    // 对齐 legado：对现网用户做一次性全量阅读设置重置。
    _readingSettings = const ReadingSettings();
    await _prefs.setString(
      _keyReadingSettings,
      json.encode(_readingSettings.toJson()),
    );
    await _prefs.setInt(
      _keyReadingSettingsSchemaVersion,
      _readingSettingsSchemaVersion,
    );
  }

  Future<void> _normalizePageDirectionByMode() async {
    final target = _readingSettings.pageTurnMode == PageTurnMode.scroll
        ? PageDirection.vertical
        : PageDirection.horizontal;
    if (_readingSettings.pageDirection != target) {
      _readingSettings = _readingSettings.copyWith(pageDirection: target);
      await _prefs.setString(
        _keyReadingSettings,
        json.encode(_readingSettings.toJson()),
      );
    }
  }

  Future<void> saveReadingSettings(ReadingSettings settings) async {
    final safeSettings = settings.sanitize();
    _readingSettings = safeSettings;
    await _prefs.setString(
      _keyReadingSettings,
      json.encode(safeSettings.toJson()),
    );
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
