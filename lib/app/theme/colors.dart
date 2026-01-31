import 'package:flutter/material.dart';

/// SoupReader 颜色系统
/// 基于设计系统：深色模式 + 金色点缀
class AppColors {
  AppColors._();

  // ===== 主色调 =====
  static const Color primary = Color(0xFF171717);
  static const Color secondary = Color(0xFF404040);
  static const Color accent = Color(0xFFD4AF37); // 金色点缀

  // ===== 背景色 =====
  static const Color backgroundDark = Color(0xFF121212);
  static const Color backgroundLight = Color(0xFFFFFFFF);
  static const Color backgroundPaper = Color(0xFFFDFBF7); // 护眼米黄

  // ===== 文字颜色 =====
  static const Color textPrimary = Color(0xFF1A1A1A);
  static const Color textSecondary = Color(0xFF666666);
  static const Color textLight = Color(0xFFE0E0E0);
  static const Color textMuted = Color(0xFF999999);

  // ===== 阅读主题颜色 =====

  /// 日间模式
  static const ReadingThemeColors dayTheme = ReadingThemeColors(
    background: Color(0xFFFFFFFF),
    text: Color(0xFF1A1A1A),
    name: '日间',
  );

  /// 夜间模式
  static const ReadingThemeColors nightTheme = ReadingThemeColors(
    background: Color(0xFF121212),
    text: Color(0xFFE0E0E0),
    name: '夜间',
  );

  /// 护眼模式（羊皮纸）
  static const ReadingThemeColors sepiaTheme = ReadingThemeColors(
    background: Color(0xFFFDFBF7),
    text: Color(0xFF3D3D3D),
    name: '护眼',
  );

  /// 墨水屏模式
  static const ReadingThemeColors inkTheme = ReadingThemeColors(
    background: Color(0xFFF5F5F5),
    text: Color(0xFF000000),
    name: '墨水',
  );

  /// 深蓝夜间
  static const ReadingThemeColors midnightTheme = ReadingThemeColors(
    background: Color(0xFF0A0E27),
    text: Color(0xFFCCCCCC),
    name: '深蓝',
  );

  /// 奶酪模式（温暖护眼）
  static const ReadingThemeColors creamTheme = ReadingThemeColors(
    background: Color(0xFFFFF8E1),
    text: Color(0xFF3E2723),
    name: '奶酪',
  );

  /// 薄荷模式（清新护眼）
  static const ReadingThemeColors mintTheme = ReadingThemeColors(
    background: Color(0xFFE0F2F1),
    text: Color(0xFF004D40),
    name: '薄荷',
  );

  /// 玫瑰模式（柔和浪漫）
  static const ReadingThemeColors roseTheme = ReadingThemeColors(
    background: Color(0xFFFCE4EC),
    text: Color(0xFF880E4F),
    name: '玫瑰',
  );

  /// AMOLED 纯黑模式（省电）
  static const ReadingThemeColors amoledTheme = ReadingThemeColors(
    background: Color(0xFF000000),
    text: Color(0xFFAAAAAA),
    name: '纯黑',
  );

  /// 所有阅读主题
  static const List<ReadingThemeColors> readingThemes = [
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
  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFFF9800);
  static const Color error = Color(0xFFF44336);
  static const Color info = Color(0xFF2196F3);

  // ===== 边框和分割线 =====
  static const Color border = Color(0xFFE2E8F0);
  static const Color borderDark = Color(0xFF333333);
  static const Color divider = Color(0xFFEEEEEE);
  static const Color dividerDark = Color(0xFF2A2A2A);

  // ===== 卡片和表面 =====
  static const Color cardLight = Color(0xFFFFFFFF);
  static const Color cardDark = Color(0xFF1E1E1E);
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
}
