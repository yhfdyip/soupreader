import 'package:flutter/cupertino.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/cupertino_theme.dart';

/// 提供统一的启动阶段应用壳，避免重复配置 `CupertinoApp`。
///
/// 支持两种模式：
/// - 启动阶段：使用 [home] 展示进度/失败页。
/// - 主界面：使用 [routerConfig] 接入 go_router 声明式路由。
class BootAppShell extends StatelessWidget {
  /// 当前壳层的唯一键，用于区分启动页与主界面。
  final String shellKey;

  /// 壳层使用的主题亮度。
  final Brightness brightness;

  /// 启动阶段使用的首页（与 [routerConfig] 互斥）。
  final Widget? home;

  /// 主界面使用的 go_router 配置（与 [home] 互斥）。
  final GoRouter? routerConfig;

  /// 启动阶段壳：展示进度或失败页。
  const BootAppShell({
    super.key,
    required this.shellKey,
    required this.brightness,
    required Widget this.home,
  }) : routerConfig = null;

  /// 主界面壳：接入 go_router 声明式路由。
  const BootAppShell.router({
    super.key,
    required this.shellKey,
    required this.brightness,
    required GoRouter this.routerConfig,
  }) : home = null;

  static const _localizationsDelegates = [
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  static const _supportedLocales = [
    Locale('zh', 'CN'),
    Locale('en', 'US'),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = AppCupertinoTheme.build(brightness);

    Widget appBuilder(BuildContext context, Widget? child) =>
        child ?? const SizedBox.shrink();

    if (routerConfig != null) {
      return CupertinoApp.router(
        key: ValueKey<String>(shellKey),
        title: 'SoupReader',
        debugShowCheckedModeBanner: false,
        theme: theme,
        builder: appBuilder,
        localizationsDelegates: _localizationsDelegates,
        supportedLocales: _supportedLocales,
        routerConfig: routerConfig!,
      );
    }

    return CupertinoApp(
      key: ValueKey<String>(shellKey),
      title: 'SoupReader',
      debugShowCheckedModeBanner: false,
      theme: theme,
      builder: appBuilder,
      localizationsDelegates: _localizationsDelegates,
      supportedLocales: _supportedLocales,
      home: home!,
    );
  }
}
