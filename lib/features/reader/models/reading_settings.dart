import 'package:flutter/material.dart';

/// 阅读设置模型
class ReadingSettings {
  final double fontSize;
  final double lineHeight;
  final double letterSpacing;
  final double paragraphSpacing;
  final double marginHorizontal; // 左右页边距
  final double marginVertical; // 上下页边距
  final int themeIndex; // 阅读主题索引
  final int fontFamilyIndex; // 字体选择索引
  final PageTurnMode pageTurnMode;
  final bool keepScreenOn;
  final bool showStatusBar; // 是否显示底部状态栏
  final bool showBattery;
  final bool showTime;
  final bool showProgress;
  final bool showChapterProgress; // 显示章节内进度
  final double brightness; // 0.0 - 1.0
  final bool useSystemBrightness;

  // === 新增字段 ===
  final int textBold; // 0:正常 1:粗体 2:细体
  final String paragraphIndent; // 段落缩进字符，默认"　　"（两个全角空格）
  final int titleMode; // 0:居左 1:居中 2:隐藏
  final int titleSize; // 标题字体大小偏移 (-4 to +8)
  final bool textFullJustify; // 两端对齐
  final bool underline; // 下划线

  // 精细化边距
  final double paddingTop;
  final double paddingBottom;
  final double paddingLeft;
  final double paddingRight;

  // 点击区域配置 (9宫格)
  final Map<String, int> clickActions;

  // 自动阅读
  final int autoReadSpeed; // 自动阅读速度 (1-100)

  const ReadingSettings({
    this.fontSize = 18.0,
    this.lineHeight = 1.8,
    this.letterSpacing = 0.5,
    this.paragraphSpacing = 16.0,
    this.marginHorizontal = 20.0,
    this.marginVertical = 16.0,
    this.themeIndex = 0,
    this.fontFamilyIndex = 0,
    this.pageTurnMode = PageTurnMode.scroll,
    this.keepScreenOn = true,
    this.showStatusBar = true,
    this.showBattery = true,
    this.showTime = true,
    this.showProgress = true,
    this.showChapterProgress = true,
    this.brightness = 0.8,
    this.useSystemBrightness = true,
    // 新增字段默认值
    this.textBold = 0,
    this.paragraphIndent = '　　',
    this.titleMode = 0,
    this.titleSize = 0,
    this.textFullJustify = false,
    this.underline = false,
    this.paddingTop = 16.0,
    this.paddingBottom = 16.0,
    this.paddingLeft = 20.0,
    this.paddingRight = 20.0,
    this.clickActions = const {},
    this.autoReadSpeed = 50,
  });

  /// 获取 padding（兼容旧代码）
  EdgeInsets get padding => EdgeInsets.symmetric(
        horizontal: marginHorizontal,
        vertical: marginVertical,
      );

  factory ReadingSettings.fromJson(Map<String, dynamic> json) {
    return ReadingSettings(
      fontSize: (json['fontSize'] as num?)?.toDouble() ?? 18.0,
      lineHeight: (json['lineHeight'] as num?)?.toDouble() ?? 1.8,
      letterSpacing: (json['letterSpacing'] as num?)?.toDouble() ?? 0.5,
      paragraphSpacing: (json['paragraphSpacing'] as num?)?.toDouble() ?? 16.0,
      marginHorizontal: (json['marginHorizontal'] as num?)?.toDouble() ??
          (json['paddingH'] as num?)?.toDouble() ??
          20.0,
      marginVertical: (json['marginVertical'] as num?)?.toDouble() ??
          (json['paddingV'] as num?)?.toDouble() ??
          16.0,
      themeIndex: json['themeIndex'] as int? ?? 0,
      fontFamilyIndex: json['fontFamilyIndex'] as int? ?? 0,
      pageTurnMode: PageTurnMode.values[json['pageTurnMode'] as int? ?? 4],
      keepScreenOn: json['keepScreenOn'] as bool? ?? true,
      showStatusBar: json['showStatusBar'] as bool? ?? true,
      showBattery: json['showBattery'] as bool? ?? true,
      showTime: json['showTime'] as bool? ?? true,
      showProgress: json['showProgress'] as bool? ?? true,
      showChapterProgress: json['showChapterProgress'] as bool? ?? true,
      brightness: (json['brightness'] as num?)?.toDouble() ?? 0.8,
      useSystemBrightness: json['useSystemBrightness'] as bool? ?? true,
      // 新增字段
      textBold: json['textBold'] as int? ?? 0,
      paragraphIndent: json['paragraphIndent'] as String? ?? '　　',
      titleMode: json['titleMode'] as int? ?? 0,
      titleSize: json['titleSize'] as int? ?? 0,
      textFullJustify: json['textFullJustify'] as bool? ?? false,
      underline: json['underline'] as bool? ?? false,
      paddingTop: (json['paddingTop'] as num?)?.toDouble() ?? 16.0,
      paddingBottom: (json['paddingBottom'] as num?)?.toDouble() ?? 16.0,
      paddingLeft: (json['paddingLeft'] as num?)?.toDouble() ?? 20.0,
      paddingRight: (json['paddingRight'] as num?)?.toDouble() ?? 20.0,
      clickActions: (json['clickActions'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(k, v as int),
          ) ??
          const {},
      autoReadSpeed: json['autoReadSpeed'] as int? ?? 50,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'fontSize': fontSize,
      'lineHeight': lineHeight,
      'letterSpacing': letterSpacing,
      'paragraphSpacing': paragraphSpacing,
      'marginHorizontal': marginHorizontal,
      'marginVertical': marginVertical,
      'themeIndex': themeIndex,
      'fontFamilyIndex': fontFamilyIndex,
      'pageTurnMode': pageTurnMode.index,
      'keepScreenOn': keepScreenOn,
      'showStatusBar': showStatusBar,
      'showBattery': showBattery,
      'showTime': showTime,
      'showProgress': showProgress,
      'showChapterProgress': showChapterProgress,
      'brightness': brightness,
      'useSystemBrightness': useSystemBrightness,
      // 新增字段
      'textBold': textBold,
      'paragraphIndent': paragraphIndent,
      'titleMode': titleMode,
      'titleSize': titleSize,
      'textFullJustify': textFullJustify,
      'underline': underline,
      'paddingTop': paddingTop,
      'paddingBottom': paddingBottom,
      'paddingLeft': paddingLeft,
      'paddingRight': paddingRight,
      'clickActions': clickActions,
      'autoReadSpeed': autoReadSpeed,
    };
  }

  ReadingSettings copyWith({
    double? fontSize,
    double? lineHeight,
    double? letterSpacing,
    double? paragraphSpacing,
    double? marginHorizontal,
    double? marginVertical,
    int? themeIndex,
    int? fontFamilyIndex,
    PageTurnMode? pageTurnMode,
    bool? keepScreenOn,
    bool? showStatusBar,
    bool? showBattery,
    bool? showTime,
    bool? showProgress,
    bool? showChapterProgress,
    double? brightness,
    bool? useSystemBrightness,
    // 新增字段
    int? textBold,
    String? paragraphIndent,
    int? titleMode,
    int? titleSize,
    bool? textFullJustify,
    bool? underline,
    double? paddingTop,
    double? paddingBottom,
    double? paddingLeft,
    double? paddingRight,
    Map<String, int>? clickActions,
    int? autoReadSpeed,
  }) {
    return ReadingSettings(
      fontSize: fontSize ?? this.fontSize,
      lineHeight: lineHeight ?? this.lineHeight,
      letterSpacing: letterSpacing ?? this.letterSpacing,
      paragraphSpacing: paragraphSpacing ?? this.paragraphSpacing,
      marginHorizontal: marginHorizontal ?? this.marginHorizontal,
      marginVertical: marginVertical ?? this.marginVertical,
      themeIndex: themeIndex ?? this.themeIndex,
      fontFamilyIndex: fontFamilyIndex ?? this.fontFamilyIndex,
      pageTurnMode: pageTurnMode ?? this.pageTurnMode,
      keepScreenOn: keepScreenOn ?? this.keepScreenOn,
      showStatusBar: showStatusBar ?? this.showStatusBar,
      showBattery: showBattery ?? this.showBattery,
      showTime: showTime ?? this.showTime,
      showProgress: showProgress ?? this.showProgress,
      showChapterProgress: showChapterProgress ?? this.showChapterProgress,
      brightness: brightness ?? this.brightness,
      useSystemBrightness: useSystemBrightness ?? this.useSystemBrightness,
      // 新增字段
      textBold: textBold ?? this.textBold,
      paragraphIndent: paragraphIndent ?? this.paragraphIndent,
      titleMode: titleMode ?? this.titleMode,
      titleSize: titleSize ?? this.titleSize,
      textFullJustify: textFullJustify ?? this.textFullJustify,
      underline: underline ?? this.underline,
      paddingTop: paddingTop ?? this.paddingTop,
      paddingBottom: paddingBottom ?? this.paddingBottom,
      paddingLeft: paddingLeft ?? this.paddingLeft,
      paddingRight: paddingRight ?? this.paddingRight,
      clickActions: clickActions ?? this.clickActions,
      autoReadSpeed: autoReadSpeed ?? this.autoReadSpeed,
    );
  }
}

/// 点击动作类型
class ClickAction {
  static const int showMenu = 0;
  static const int nextPage = 1;
  static const int prevPage = 2;
  static const int nextChapter = 3;
  static const int prevChapter = 4;
  static const int addBookmark = 7;
  static const int openChapterList = 10;

  static String getName(int action) {
    switch (action) {
      case showMenu:
        return '菜单';
      case nextPage:
        return '下一页';
      case prevPage:
        return '上一页';
      case nextChapter:
        return '下一章';
      case prevChapter:
        return '上一章';
      case addBookmark:
        return '书签';
      case openChapterList:
        return '目录';
      default:
        return '菜单';
    }
  }

  static List<int> get allActions => [
        showMenu,
        nextPage,
        prevPage,
        nextChapter,
        prevChapter,
        addBookmark,
        openChapterList,
      ];
}

/// 翻页模式
enum PageTurnMode {
  slide, // 滑动
  simulation, // 仿真翻页
  cover, // 覆盖
  none, // 无动画
  scroll, // 滚动
}

extension PageTurnModeExtension on PageTurnMode {
  String get name {
    switch (this) {
      case PageTurnMode.slide:
        return '滑动';
      case PageTurnMode.simulation:
        return '仿真';
      case PageTurnMode.cover:
        return '覆盖';
      case PageTurnMode.none:
        return '无';
      case PageTurnMode.scroll:
        return '滚动';
    }
  }

  IconData get icon {
    switch (this) {
      case PageTurnMode.slide:
        return Icons.swipe;
      case PageTurnMode.simulation:
        return Icons.auto_stories;
      case PageTurnMode.cover:
        return Icons.layers;
      case PageTurnMode.none:
        return Icons.block;
      case PageTurnMode.scroll:
        return Icons.unfold_more;
    }
  }
}
