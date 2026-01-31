import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../features/reader/models/reading_settings.dart';

/// 全局设置服务
class SettingsService {
  static final SettingsService _instance = SettingsService._internal();
  factory SettingsService() => _instance;
  SettingsService._internal();

  static const String _keyReadingSettings = 'reading_settings';

  late SharedPreferences _prefs;
  late ReadingSettings _readingSettings;

  ReadingSettings get readingSettings => _readingSettings;

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
  }

  Future<void> saveReadingSettings(ReadingSettings settings) async {
    _readingSettings = settings;
    await _prefs.setString(_keyReadingSettings, json.encode(settings.toJson()));
  }

  /// 保存特定书籍的滚动偏移量 (临时方案，可考虑存入 Hive)
  Future<void> saveScrollOffset(String bookId, double offset) async {
    await _prefs.setDouble('scroll_offset_$bookId', offset);
  }

  double getScrollOffset(String bookId) {
    return _prefs.getDouble('scroll_offset_$bookId') ?? 0.0;
  }
}
