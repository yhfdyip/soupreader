import 'package:flutter/material.dart';

/// SoupReader 字体样式系统
/// 使用 Noto Serif TC (标题) + Noto Sans TC (正文)
class AppTypography {
  AppTypography._();

  // ===== 字体族 =====
  static const String fontFamilySerif = 'NotoSerifTC';
  static const String fontFamilySans = 'NotoSansTC';
  static const String fontFamilySystem = '.SF Pro Text'; // iOS系统字体

  // ===== 标题样式 =====
  static const TextStyle displayLarge = TextStyle(
    fontFamily: fontFamilySerif,
    fontSize: 32,
    fontWeight: FontWeight.w700,
    height: 1.3,
  );

  static const TextStyle displayMedium = TextStyle(
    fontFamily: fontFamilySerif,
    fontSize: 28,
    fontWeight: FontWeight.w600,
    height: 1.3,
  );

  static const TextStyle displaySmall = TextStyle(
    fontFamily: fontFamilySerif,
    fontSize: 24,
    fontWeight: FontWeight.w600,
    height: 1.3,
  );

  static const TextStyle headlineLarge = TextStyle(
    fontFamily: fontFamilySerif,
    fontSize: 22,
    fontWeight: FontWeight.w600,
    height: 1.4,
  );

  static const TextStyle headlineMedium = TextStyle(
    fontFamily: fontFamilySerif,
    fontSize: 20,
    fontWeight: FontWeight.w500,
    height: 1.4,
  );

  static const TextStyle headlineSmall = TextStyle(
    fontFamily: fontFamilySans,
    fontSize: 18,
    fontWeight: FontWeight.w500,
    height: 1.4,
  );

  // ===== 正文样式 =====
  static const TextStyle bodyLarge = TextStyle(
    fontFamily: fontFamilySans,
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.6,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontFamily: fontFamilySans,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.5,
  );

  static const TextStyle bodySmall = TextStyle(
    fontFamily: fontFamilySans,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.5,
  );

  // ===== 标签样式 =====
  static const TextStyle labelLarge = TextStyle(
    fontFamily: fontFamilySans,
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 1.4,
  );

  static const TextStyle labelMedium = TextStyle(
    fontFamily: fontFamilySans,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 1.4,
  );

  static const TextStyle labelSmall = TextStyle(
    fontFamily: fontFamilySans,
    fontSize: 10,
    fontWeight: FontWeight.w500,
    height: 1.4,
  );

  // ===== 阅读样式 =====
  /// 获取阅读文本样式
  static TextStyle readingStyle({
    double fontSize = 18,
    double lineHeight = 1.8,
    double letterSpacing = 0.5,
    Color? color,
  }) {
    return TextStyle(
      fontFamily: fontFamilySans,
      fontSize: fontSize,
      fontWeight: FontWeight.w400,
      height: lineHeight,
      letterSpacing: letterSpacing,
      color: color,
    );
  }

  /// 章节标题样式
  static TextStyle chapterTitle({Color? color}) {
    return TextStyle(
      fontFamily: fontFamilySerif,
      fontSize: 22,
      fontWeight: FontWeight.w600,
      height: 1.4,
      color: color,
    );
  }
}

/// 阅读字体大小预设
class ReadingFontSize {
  static const double small = 14;
  static const double medium = 16;
  static const double normal = 18;
  static const double large = 20;
  static const double extraLarge = 22;
  static const double huge = 24;

  static const List<double> presets = [
    small,
    medium,
    normal,
    large,
    extraLarge,
    huge,
  ];

  static String getName(double size) {
    switch (size) {
      case small:
        return '小';
      case medium:
        return '中';
      case normal:
        return '标准';
      case large:
        return '大';
      case extraLarge:
        return '特大';
      case huge:
        return '超大';
      default:
        return '${size.toInt()}';
    }
  }
}

/// 阅读字体预设
class ReadingFontFamily {
  static const String system = ''; // 系统默认
  static const String notoSerif = 'NotoSerifTC';
  static const String notoSans = 'NotoSansTC';
  static const String sourceHanMono = 'SourceHanMono';

  static const List<ReadingFontConfig> presets = [
    ReadingFontConfig(name: '系统默认', fontFamily: system),
    ReadingFontConfig(name: '思源宋体', fontFamily: notoSerif),
    ReadingFontConfig(name: '思源黑体', fontFamily: notoSans),
    ReadingFontConfig(name: '等宽字体', fontFamily: sourceHanMono),
  ];

  static String getFontFamily(int index) {
    if (index < 0 || index >= presets.length) return system;
    return presets[index].fontFamily;
  }

  static String getFontName(int index) {
    if (index < 0 || index >= presets.length) return '系统默认';
    return presets[index].name;
  }
}

/// 字体配置
class ReadingFontConfig {
  final String name;
  final String fontFamily;

  const ReadingFontConfig({
    required this.name,
    required this.fontFamily,
  });
}
