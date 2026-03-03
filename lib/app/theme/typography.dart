import 'package:flutter/painting.dart';

/// SoupReader 字体样式系统
/// 对齐 legado 系统字体语义：默认/衬线/无衬线/等宽。
class AppTypography {
  AppTypography._();

  // ===== 字体族 =====
  static const String fontFamilySystem = '.SF Pro Text'; // iOS 系统字体
  // 按 AGENTS 规范：UI 默认统一使用 SF 字体族。
  static const String fontFamilySans = fontFamilySystem;
  static const String fontFamilySerif = fontFamilySystem;
  // 仅用于规则编辑/调试日志等代码文本场景。
  static const String fontFamilyMonospace = 'monospace';

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
  // 对齐 legado 的系统字体语义，避免引用未注册字体导致回退失效。
  static const String notoSerif = 'Noto Serif CJK SC';
  static const String notoSans = 'Noto Sans CJK SC';
  static const String sourceHanMono = 'Roboto Mono';
  static const List<String> serifFallback = <String>[
    'Noto Serif CJK TC',
    'Songti SC',
    'STSong',
    'serif',
  ];
  static const List<String> sansFallback = <String>[
    'Noto Sans CJK TC',
    'PingFang SC',
    'Heiti SC',
    'sans-serif',
  ];
  static const List<String> monoFallback = <String>[
    'Noto Sans Mono CJK SC',
    'Menlo',
    'Courier New',
    'monospace',
  ];

  static const List<ReadingFontConfig> presets = [
    ReadingFontConfig(name: '系统默认', fontFamily: system),
    ReadingFontConfig(
      name: '衬线字体',
      fontFamily: notoSerif,
      fontFamilyFallback: serifFallback,
    ),
    ReadingFontConfig(
      name: '无衬线字体',
      fontFamily: notoSans,
      fontFamilyFallback: sansFallback,
    ),
    ReadingFontConfig(
      name: '等宽字体',
      fontFamily: sourceHanMono,
      fontFamilyFallback: monoFallback,
    ),
  ];

  static String getFontFamily(int index) {
    if (index < 0 || index >= presets.length) return system;
    return presets[index].fontFamily;
  }

  static List<String> getFontFamilyFallback(int index) {
    if (index < 0 || index >= presets.length) return const <String>[];
    return presets[index].fontFamilyFallback;
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
  final List<String> fontFamilyFallback;

  const ReadingFontConfig({
    required this.name,
    required this.fontFamily,
    this.fontFamilyFallback = const <String>[],
  });
}
