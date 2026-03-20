// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'settings_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 当前阅读设置（派生自 [SettingsService]）。
///
/// View 层通过 `ref.watch(readingSettingsProvider)` 精确订阅阅读配置，
/// 避免直接持有整个 [SettingsService] 实例。

@ProviderFor(readingSettings)
final readingSettingsProvider = ReadingSettingsProvider._();

/// 当前阅读设置（派生自 [SettingsService]）。
///
/// View 层通过 `ref.watch(readingSettingsProvider)` 精确订阅阅读配置，
/// 避免直接持有整个 [SettingsService] 实例。

final class ReadingSettingsProvider extends $FunctionalProvider<ReadingSettings,
    ReadingSettings, ReadingSettings> with $Provider<ReadingSettings> {
  /// 当前阅读设置（派生自 [SettingsService]）。
  ///
  /// View 层通过 `ref.watch(readingSettingsProvider)` 精确订阅阅读配置，
  /// 避免直接持有整个 [SettingsService] 实例。
  ReadingSettingsProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'readingSettingsProvider',
          isAutoDispose: false,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$readingSettingsHash();

  @$internal
  @override
  $ProviderElement<ReadingSettings> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ReadingSettings create(Ref ref) {
    return readingSettings(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ReadingSettings value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ReadingSettings>(value),
    );
  }
}

String _$readingSettingsHash() => r'41396d5bbc6260573c3c944748084a792e41932d';

/// 当前应用级设置（派生自 [SettingsService]）。
///
/// View 层通过 `ref.watch(appSettingsProvider)` 精确订阅应用配置。

@ProviderFor(appSettings)
final appSettingsProvider = AppSettingsProvider._();

/// 当前应用级设置（派生自 [SettingsService]）。
///
/// View 层通过 `ref.watch(appSettingsProvider)` 精确订阅应用配置。

final class AppSettingsProvider
    extends $FunctionalProvider<AppSettings, AppSettings, AppSettings>
    with $Provider<AppSettings> {
  /// 当前应用级设置（派生自 [SettingsService]）。
  ///
  /// View 层通过 `ref.watch(appSettingsProvider)` 精确订阅应用配置。
  AppSettingsProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'appSettingsProvider',
          isAutoDispose: false,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$appSettingsHash();

  @$internal
  @override
  $ProviderElement<AppSettings> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AppSettings create(Ref ref) {
    return appSettings(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AppSettings value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AppSettings>(value),
    );
  }
}

String _$appSettingsHash() => r'5e45b777a28e23c4d3e3028d741ae6b63d072fe4';
