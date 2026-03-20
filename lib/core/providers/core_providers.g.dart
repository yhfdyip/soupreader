// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'core_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 数据库服务（全局单例）。
///
/// 项目中所有需要数据库访问的地方，通过 `ref.watch(databaseServiceProvider)`
/// 获取实例，替代直接调用 `DatabaseService()` 工厂构造函数。

@ProviderFor(databaseService)
final databaseServiceProvider = DatabaseServiceProvider._();

/// 数据库服务（全局单例）。
///
/// 项目中所有需要数据库访问的地方，通过 `ref.watch(databaseServiceProvider)`
/// 获取实例，替代直接调用 `DatabaseService()` 工厂构造函数。

final class DatabaseServiceProvider extends $FunctionalProvider<DatabaseService,
    DatabaseService, DatabaseService> with $Provider<DatabaseService> {
  /// 数据库服务（全局单例）。
  ///
  /// 项目中所有需要数据库访问的地方，通过 `ref.watch(databaseServiceProvider)`
  /// 获取实例，替代直接调用 `DatabaseService()` 工厂构造函数。
  DatabaseServiceProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'databaseServiceProvider',
          isAutoDispose: false,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$databaseServiceHash();

  @$internal
  @override
  $ProviderElement<DatabaseService> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  DatabaseService create(Ref ref) {
    return databaseService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DatabaseService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DatabaseService>(value),
    );
  }
}

String _$databaseServiceHash() => r'8693a6ed3938df4e407223f578143e433758d15a';

/// 应用设置服务（全局单例）。
///
/// 管理 [ReadingSettings] 和 [AppSettings] 两大配置域。
/// View 层推荐通过 [settingsProviders] 中的派生 Provider 精确订阅。

@ProviderFor(settingsService)
final settingsServiceProvider = SettingsServiceProvider._();

/// 应用设置服务（全局单例）。
///
/// 管理 [ReadingSettings] 和 [AppSettings] 两大配置域。
/// View 层推荐通过 [settingsProviders] 中的派生 Provider 精确订阅。

final class SettingsServiceProvider extends $FunctionalProvider<SettingsService,
    SettingsService, SettingsService> with $Provider<SettingsService> {
  /// 应用设置服务（全局单例）。
  ///
  /// 管理 [ReadingSettings] 和 [AppSettings] 两大配置域。
  /// View 层推荐通过 [settingsProviders] 中的派生 Provider 精确订阅。
  SettingsServiceProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'settingsServiceProvider',
          isAutoDispose: false,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$settingsServiceHash();

  @$internal
  @override
  $ProviderElement<SettingsService> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  SettingsService create(Ref ref) {
    return settingsService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SettingsService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SettingsService>(value),
    );
  }
}

String _$settingsServiceHash() => r'663ca645ade0bc64dd9e8f646ef438ad55e37949';

/// 异常日志服务（全局单例）。
///
/// 记录应用运行时异常并提供 UI 查看入口。
/// 业务代码推荐通过 [AppLogger] 门面间接使用。

@ProviderFor(exceptionLogService)
final exceptionLogServiceProvider = ExceptionLogServiceProvider._();

/// 异常日志服务（全局单例）。
///
/// 记录应用运行时异常并提供 UI 查看入口。
/// 业务代码推荐通过 [AppLogger] 门面间接使用。

final class ExceptionLogServiceProvider extends $FunctionalProvider<
    ExceptionLogService,
    ExceptionLogService,
    ExceptionLogService> with $Provider<ExceptionLogService> {
  /// 异常日志服务（全局单例）。
  ///
  /// 记录应用运行时异常并提供 UI 查看入口。
  /// 业务代码推荐通过 [AppLogger] 门面间接使用。
  ExceptionLogServiceProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'exceptionLogServiceProvider',
          isAutoDispose: false,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$exceptionLogServiceHash();

  @$internal
  @override
  $ProviderElement<ExceptionLogService> $createElement(
          $ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ExceptionLogService create(Ref ref) {
    return exceptionLogService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ExceptionLogService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ExceptionLogService>(value),
    );
  }
}

String _$exceptionLogServiceHash() =>
    r'dfa338fb633737ebdcfcefa5b1066edb037b5f3e';
