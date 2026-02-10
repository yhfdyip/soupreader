import 'package:flutter/cupertino.dart';

import 'design_tokens.dart';
import 'typography.dart';

/// 全局 Cupertino 视觉主题（作用于全页面）。
class AppCupertinoTheme {
  AppCupertinoTheme._();

  static CupertinoThemeData build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    final bg =
        isDark ? AppDesignTokens.pageBgDark : AppDesignTokens.pageBgLight;
    final barBg = isDark
        ? AppDesignTokens.surfaceDark.withValues(alpha: 0.92)
        : AppDesignTokens.surfaceLight.withValues(alpha: 0.92);
    final textColor =
        isDark ? AppDesignTokens.textInverse : AppDesignTokens.textStrong;
    final secondaryText = isDark
        ? AppDesignTokens.textMuted.withValues(alpha: 0.9)
        : AppDesignTokens.textNormal.withValues(alpha: 0.9);

    return CupertinoThemeData(
      brightness: brightness,
      primaryColor: isDark
          ? AppDesignTokens.brandSecondary
          : AppDesignTokens.brandPrimary,
      scaffoldBackgroundColor: bg,
      barBackgroundColor: barBg,
      textTheme: CupertinoTextThemeData(
        textStyle: TextStyle(
          fontFamily: AppTypography.fontFamilySans,
          color: textColor,
          fontSize: 15,
          height: 1.45,
        ),
        navTitleTextStyle: TextStyle(
          fontFamily: AppTypography.fontFamilySans,
          color: textColor,
          fontSize: 17,
          fontWeight: FontWeight.w600,
        ),
        navLargeTitleTextStyle: TextStyle(
          fontFamily: AppTypography.fontFamilySerif,
          color: textColor,
          fontSize: 31,
          fontWeight: FontWeight.w700,
          height: 1.15,
        ),
        actionTextStyle: TextStyle(
          fontFamily: AppTypography.fontFamilySans,
          color: isDark
              ? AppDesignTokens.brandSecondary
              : AppDesignTokens.brandPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
        tabLabelTextStyle: TextStyle(
          fontFamily: AppTypography.fontFamilySans,
          color: secondaryText,
          fontSize: 10,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  static Color tabBarBackground(Brightness brightness) {
    if (brightness == Brightness.dark) {
      return AppDesignTokens.surfaceDark.withValues(alpha: 0.94);
    }
    return AppDesignTokens.surfaceLight.withValues(alpha: 0.94);
  }

  static Color tabBarActive(Brightness brightness) {
    return brightness == Brightness.dark
        ? AppDesignTokens.brandSecondary
        : AppDesignTokens.brandPrimary;
  }

  static Color tabBarInactive(Brightness brightness) {
    return brightness == Brightness.dark
        ? AppDesignTokens.textMuted.withValues(alpha: 0.92)
        : AppDesignTokens.textNormal.withValues(alpha: 0.74);
  }

  static Border tabBarBorder(Brightness brightness) {
    final color = brightness == Brightness.dark
        ? AppDesignTokens.borderDark.withValues(alpha: 0.85)
        : AppDesignTokens.borderLight;
    return Border(top: BorderSide(color: color, width: 0.5));
  }
}
