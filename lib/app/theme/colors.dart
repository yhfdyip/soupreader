import 'package:flutter/material.dart';

import 'design_tokens.dart';

/// SoupReader 颜色系统
/// 基于设计系统：深色模式 + 金色点缀
class AppColors {
  AppColors._();

  // ===== 主色调 =====
  static const Color primary = AppDesignTokens.textStrong;
  static const Color secondary = AppDesignTokens.textNormal;
  static const Color accent = AppDesignTokens.brandPrimary;

  // ===== 背景色 =====
  static const Color backgroundDark = AppDesignTokens.pageBgDark;
  static const Color backgroundLight = AppDesignTokens.pageBgLight;
  static const Color backgroundPaper = Color(0xFFFDFBF7); // 护眼米黄

  // ===== 文字颜色 =====
  static const Color textPrimary = AppDesignTokens.textStrong;
  static const Color textSecondary = AppDesignTokens.textNormal;
  static const Color textLight = AppDesignTokens.textInverse;
  static const Color textMuted = AppDesignTokens.textMuted;

  // ===== 阅读主题颜色 =====

  /// 日间模式
  static final ReadingThemeColors dayTheme = ReadingThemeColors(
    background: ReaderThemeTokens.day.background,
    text: ReaderThemeTokens.day.text,
    name: ReaderThemeTokens.day.name,
  );

  /// 夜间模式
  static final ReadingThemeColors nightTheme = ReadingThemeColors(
    background: ReaderThemeTokens.night.background,
    text: ReaderThemeTokens.night.text,
    name: ReaderThemeTokens.night.name,
  );

  /// 护眼模式（羊皮纸）
  static final ReadingThemeColors sepiaTheme = ReadingThemeColors(
    background: ReaderThemeTokens.sepia.background,
    text: ReaderThemeTokens.sepia.text,
    name: ReaderThemeTokens.sepia.name,
  );

  /// 墨水屏模式
  static final ReadingThemeColors inkTheme = ReadingThemeColors(
    background: ReaderThemeTokens.ink.background,
    text: ReaderThemeTokens.ink.text,
    name: ReaderThemeTokens.ink.name,
  );

  /// 深蓝夜间
  static final ReadingThemeColors midnightTheme = ReadingThemeColors(
    background: ReaderThemeTokens.midnight.background,
    text: ReaderThemeTokens.midnight.text,
    name: ReaderThemeTokens.midnight.name,
  );

  /// 奶酪模式（温暖护眼）
  static final ReadingThemeColors creamTheme = ReadingThemeColors(
    background: ReaderThemeTokens.cream.background,
    text: ReaderThemeTokens.cream.text,
    name: ReaderThemeTokens.cream.name,
  );

  /// 薄荷模式（清新护眼）
  static final ReadingThemeColors mintTheme = ReadingThemeColors(
    background: ReaderThemeTokens.mint.background,
    text: ReaderThemeTokens.mint.text,
    name: ReaderThemeTokens.mint.name,
  );

  /// 玫瑰模式（柔和浪漫）
  static final ReadingThemeColors roseTheme = ReadingThemeColors(
    background: ReaderThemeTokens.rose.background,
    text: ReaderThemeTokens.rose.text,
    name: ReaderThemeTokens.rose.name,
  );

  /// AMOLED 纯黑模式（省电）
  static final ReadingThemeColors amoledTheme = ReadingThemeColors(
    background: ReaderThemeTokens.amoled.background,
    text: ReaderThemeTokens.amoled.text,
    name: ReaderThemeTokens.amoled.name,
  );

  /// 所有阅读主题
  static final List<ReadingThemeColors> readingThemes = [
    dayTheme,
    nightTheme,
    sepiaTheme,
    inkTheme,
    midnightTheme,
    creamTheme,
    mintTheme,
    roseTheme,
    amoledTheme,
  ];

  // ===== 功能色 =====
  static const Color success = AppDesignTokens.success;
  static const Color warning = AppDesignTokens.warning;
  static const Color error = AppDesignTokens.error;
  static const Color info = AppDesignTokens.info;

  // ===== 边框和分割线 =====
  static const Color border = AppDesignTokens.borderLight;
  static const Color borderDark = AppDesignTokens.borderDark;
  static const Color divider = AppDesignTokens.dividerLight;
  static const Color dividerDark = AppDesignTokens.dividerDark;

  // ===== 卡片和表面 =====
  static const Color cardLight = AppDesignTokens.surfaceLight;
  static const Color cardDark = AppDesignTokens.surfaceDark;
  static const Color surfaceLight = Color(0xFFF5F5F5);
  static const Color surfaceDark = Color(0xFF262626);
}

/// 阅读主题颜色配置
class ReadingThemeColors {
  final Color background;
  final Color text;
  final String name;

  const ReadingThemeColors({
    required this.background,
    required this.text,
    required this.name,
  });

  bool get isDark => background.computeLuminance() < 0.5;
}
