import 'package:flutter/cupertino.dart';

import 'design_tokens.dart';

/// 全局 Cupertino 视觉主题（作用于全页面）。
class AppCupertinoTheme {
  AppCupertinoTheme._();

  static const double _kNavBarGlassAlpha = 0.9;
  static const double _kTabBarGlassAlpha = 0.92;

  static CupertinoThemeData build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final scaffoldBackground =
        isDark ? AppDesignTokens.pageBgDark : AppDesignTokens.pageBgLight;
    // iOS label 色：浅色 #000000，深色 #FFFFFF。
    final textColor =
        isDark ? CupertinoColors.white : CupertinoColors.black;
    // iOS secondaryLabel：浅色 60% 黑，深色 60% 白。
    final secondaryText = isDark
        ? CupertinoColors.white.withValues(alpha: 0.6)
        : CupertinoColors.black.withValues(alpha: 0.6);
    // iOS 蓝色在深浅模式下均为 #0A84FF（深色）/ #007AFF（浅色）。
    final actionColor =
        isDark ? AppDesignTokens.brandPrimary : const Color(0xFF007AFF);

    return CupertinoThemeData(
      brightness: brightness,
      primaryColor: actionColor,
      scaffoldBackgroundColor: scaffoldBackground,
      barBackgroundColor: navBarBackground(brightness, scaffoldBackground),
      textTheme: CupertinoTextThemeData(
        // 不指定 fontFamily，让系统在 iOS 上自动使用 SF Pro。
        textStyle: TextStyle(
          color: textColor,
          fontSize: 17,
          height: 1.35,
          letterSpacing: -0.41,
        ),
        navTitleTextStyle: TextStyle(
          color: textColor,
          fontSize: 17,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.41,
        ),
        navLargeTitleTextStyle: TextStyle(
          color: textColor,
          fontSize: 34,
          fontWeight: FontWeight.w700,
          height: 1.18,
          letterSpacing: 0.37,
        ),
        actionTextStyle: TextStyle(
          color: actionColor,
          fontSize: 17,
          fontWeight: FontWeight.w400,
          letterSpacing: -0.41,
        ),
        tabLabelTextStyle: TextStyle(
          color: secondaryText,
          fontSize: 10,
          fontWeight: FontWeight.w500,
          letterSpacing: -0.24,
        ),
      ),
    );
  }

  static Color navBarBackground(
    Brightness brightness,
    Color _,
  ) {
    // 保持半透明以触发 Cupertino 导航栏系统模糊，不做 alphaBlend 覆盖底层。
    return brightness == Brightness.dark
        ? AppDesignTokens.glassDarkMaterial
            .withValues(alpha: _kNavBarGlassAlpha)
        : AppDesignTokens.glassLightMaterial
            .withValues(alpha: _kNavBarGlassAlpha);
  }

  static Color tabBarBackground(Brightness brightness) {
    // 保持半透明以触发 Cupertino 底栏系统模糊，不做 alphaBlend 覆盖底层。
    return brightness == Brightness.dark
        ? AppDesignTokens.glassDarkMaterial
            .withValues(alpha: _kTabBarGlassAlpha)
        : AppDesignTokens.glassLightMaterial
            .withValues(alpha: _kTabBarGlassAlpha);
  }

  static Color tabBarActive(Brightness brightness) {
    // 与 iOS 系统 TabBar 激活色对齐。
    return brightness == Brightness.dark
        ? AppDesignTokens.brandPrimary
        : const Color(0xFF007AFF);
  }

  static Color tabBarInactive(Brightness brightness) {
    // iOS tabBar inactive：systemGray（约 60% 不透明）。
    return brightness == Brightness.dark
        ? CupertinoColors.white.withValues(alpha: 0.6)
        : CupertinoColors.black.withValues(alpha: 0.6);
  }

  static Border tabBarBorder(Brightness brightness) {
    // 原生 iOS TabBar 只有顶部一条分隔线，无底部 bezel。
    final separator = brightness == Brightness.dark
        ? AppDesignTokens.borderDark
        : AppDesignTokens.borderLight;
    return Border(
      top: BorderSide(
        color: separator,
        width: AppDesignTokens.hairlineBorderWidth,
      ),
    );
  }
}
