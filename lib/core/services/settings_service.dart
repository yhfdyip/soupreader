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
  static const String _keyAppSettings = 'app_settings';

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

    // 迁移：翻页方向对用户隐藏，统一采用“垂直”。
    // - 防止 UI 隐藏后用户还停留在水平导致体验不一致
    await _migratePageDirectionToVertical();

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

  Future<void> _migratePageDirectionToVertical() async {
    const target = PageDirection.vertical;

    if (_readingSettings.pageDirection != target) {
      _readingSettings = _readingSettings.copyWith(pageDirection: target);
      await _prefs.setString(
        _keyReadingSettings,
        json.encode(_readingSettings.toJson()),
      );
    }
  }

  Future<void> saveReadingSettings(ReadingSettings settings) async {
    _readingSettings = settings;
    await _prefs.setString(_keyReadingSettings, json.encode(settings.toJson()));
  }

  Future<void> saveAppSettings(AppSettings settings) async {
    _appSettings = settings;
    _appSettingsNotifier.value = settings;
    await _prefs.setString(_keyAppSettings, json.encode(settings.toJson()));
  }

  /// 保存特定书籍的滚动偏移量 (临时方案，可考虑存入 Hive)
  Future<void> saveScrollOffset(String bookId, double offset) async {
    await _prefs.setDouble('scroll_offset_$bookId', offset);
  }

  double getScrollOffset(String bookId) {
    return _prefs.getDouble('scroll_offset_$bookId') ?? 0.0;
  }
}
