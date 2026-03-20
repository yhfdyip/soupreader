// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_router.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 应用全局路由配置。
///
/// 使用 [StatefulShellRoute.indexedStack] 实现 Tab 导航，
/// 每个 Tab 独立维护 Navigator 栈。

@ProviderFor(appRouter)
final appRouterProvider = AppRouterProvider._();

/// 应用全局路由配置。
///
/// 使用 [StatefulShellRoute.indexedStack] 实现 Tab 导航，
/// 每个 Tab 独立维护 Navigator 栈。

final class AppRouterProvider
    extends $FunctionalProvider<GoRouter, GoRouter, GoRouter>
    with $Provider<GoRouter> {
  /// 应用全局路由配置。
  ///
  /// 使用 [StatefulShellRoute.indexedStack] 实现 Tab 导航，
  /// 每个 Tab 独立维护 Navigator 栈。
  AppRouterProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'appRouterProvider',
          isAutoDispose: false,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$appRouterHash();

  @$internal
  @override
  $ProviderElement<GoRouter> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  GoRouter create(Ref ref) {
    return appRouter(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(GoRouter value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<GoRouter>(value),
    );
  }
}

String _$appRouterHash() => r'36f185ee960c46cc7ac78947186ef422a7d38b20';
