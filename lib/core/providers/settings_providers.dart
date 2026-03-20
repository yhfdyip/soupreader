import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../features/reader/models/reading_settings.dart';
import '../models/app_settings.dart';
import '../services/settings_service.dart';
import 'core_providers.dart';

part 'settings_providers.g.dart';

/// 当前阅读设置（派生自 [SettingsService]）。
///
/// View 层通过 `ref.watch(readingSettingsProvider)` 精确订阅阅读配置，
/// 避免直接持有整个 [SettingsService] 实例。
@Riverpod(keepAlive: true)
ReadingSettings readingSettings(Ref ref) {
  final service = ref.watch(settingsServiceProvider);
  return service.readingSettingsState;
}

/// 当前应用级设置（派生自 [SettingsService]）。
///
/// View 层通过 `ref.watch(appSettingsProvider)` 精确订阅应用配置。
@Riverpod(keepAlive: true)
AppSettings appSettings(Ref ref) {
  final service = ref.watch(settingsServiceProvider);
  return service.appSettingsState;
}
