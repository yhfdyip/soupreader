import 'package:flutter/cupertino.dart';

/// 阅读设置模型
class ReadingSettings {
  // legacy 旧默认（v1）：用于历史数据识别与一次性迁移。
  static const double legacyV1FontSize = 24.0;
  static const double legacyV1LineHeight = 1.42;
  static const double legacyV1ParagraphSpacing = 6.0;
  static const double legacyV1PaddingHorizontal = 22.0;
  static const double legacyV1PaddingTop = 5.0;
  static const double legacyV1PaddingBottom = 4.0;
  static const double legacyV1MarginVertical = 5.0;

  // legado 对齐默认（v2）：正文更满、同屏信息密度更高。
  static const double legadoV2FontSize = 20.0;
  static const double legadoV2LineHeight = 1.2;
  static const double legadoV2ParagraphSpacing = 2.0;
  static const double legadoV2PaddingHorizontal = 16.0;
  static const double legadoV2PaddingVertical = 6.0;

  static const int layoutPresetVersionLegacy = 1;
  static const int layoutPresetVersionLegadoV2 = 2;

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
  final int keepLightSeconds; // legado keep_light：0/60/300/600/-1
  final bool showStatusBar; // 是否显示系统状态栏
  final bool hideNavigationBar; // 是否隐藏系统导航栏
  final bool paddingDisplayCutouts; // 刘海屏留边（对标 legado paddingDisplayCutouts）
  final bool showBattery;
  final bool showTime;
  final bool showProgress;
  final bool showChapterProgress; // 显示章节内进度
  final double brightness; // 0.0 - 1.0
  final bool useSystemBrightness;
  final bool showBrightnessView; // 是否显示阅读菜单亮度调节栏
  final bool brightnessViewOnRight; // 亮度侧边栏位置（true:右侧，false:左侧）
  final bool showReadTitleAddition; // 显示阅读标题附加信息（对标 showReadTitleAddition）
  final bool readBarStyleFollowPage; // 阅读菜单样式跟随页面（对标 readBarStyleFollowPage）
  final int layoutPresetVersion; // 排版预设版本：用于历史默认值迁移
  final ProgressBarBehavior progressBarBehavior; // 进度条行为（页内/章节）
  final bool confirmSkipChapter; // 章节进度条跳转确认（对标 legado）

  // === 新增字段 ===
  final int textBold; // 0:正常 1:粗体 2:细体
  final String paragraphIndent; // 段落缩进字符，默认"　　"（两个全角空格）
  final int titleMode; // 0:居左 1:居中 2:隐藏
  final int titleSize; // 标题字体大小偏移 (-4 to +8)
  final double titleTopSpacing; // 标题顶部间距
  final double titleBottomSpacing; // 标题底部间距
  final bool textFullJustify; // 两端对齐
  final bool underline; // 下划线
  final bool shareLayout; // 样式面板共享排版布局（对标 legado）
  final List<ReadStyleConfig>
      readStyleConfigs; // 对标 legado configList（样式名+背景类型/背景值/透明度/文字色）

  // 精细化边距
  final double paddingTop;
  final double paddingBottom;
  final double paddingLeft;
  final double paddingRight;
  final double headerPaddingTop;
  final double headerPaddingBottom;
  final double headerPaddingLeft;
  final double headerPaddingRight;
  final double footerPaddingTop;
  final double footerPaddingBottom;
  final double footerPaddingLeft;
  final double footerPaddingRight;

  // 点击区域配置 (9宫格)
  final Map<String, int> clickActions;

  // 自动阅读
  final int autoReadSpeed; // 自动阅读速度 (1-100)

  // === 翻页动画 ===
  final int pageAnimDuration; // 对标 legado：固定 300ms
  final PageDirection pageDirection; // 翻页方向 (水平/垂直)
  final int pageTouchSlop; // 翻页触发阈值（0=系统默认，1-9999=自定义）
  final bool noAnimScrollPage; // 滚动翻页无动画（对标 legado）
  final bool volumeKeyPage; // 音量键翻页
  final bool volumeKeyPageOnPlay; // 朗读时允许音量键翻页（对标 legado）
  final bool mouseWheelPage; // 鼠标滚轮翻页（对标 legado）
  final bool keyPageOnLongPress; // 按键长按翻页（对标 legado）
  final bool disableReturnKey; // 禁用返回键（对标 legado）
  final int screenOrientation; // 屏幕方向（0~4，对标 legado）

  // === 页眉/页脚配置 ===
  final bool hideHeader; // 隐藏页眉
  final bool hideFooter; // 隐藏页脚
  final bool showHeaderLine; // 显示页眉分割线
  final bool showFooterLine; // 显示页脚分割线
  final int headerMode; // 0:显示状态栏时隐藏 1:显示 2:隐藏
  final int footerMode; // 0:显示 1:隐藏
  final int tipColor; // 0:同正文颜色 其它:自定义色(ARGB)
  final int tipDividerColor; // -1:默认 0:同正文颜色 其它:自定义色(ARGB)
  final int headerLeftContent; // 页眉左侧内容：0=书名 1=章节名 2=无
  final int headerCenterContent; // 页眉中间内容
  final int headerRightContent; // 页眉右侧内容
  final int footerLeftContent; // 页脚左侧内容：0=进度 1=页码 2=时间 3=电量 4=无
  final int footerCenterContent; // 页脚中间内容
  final int footerRightContent; // 页脚右侧内容

  // === 其他功能开关 ===
  final int chineseConverterType; // 简繁转换（0=关闭 1=繁转简 2=简转繁）
  final bool cleanChapterTitle; // 净化正文章节名称
  final bool textBottomJustify; // 底部对齐（对标 legado）

  static const int chineseConverterOff = 0;
  static const int chineseConverterTraditionalToSimplified = 1;
  static const int chineseConverterSimplifiedToTraditional = 2;
  static const int legacyPageAnimDuration = 300;
  static const int headerModeHideWhenStatusBarShown = 0;
  static const int headerModeShow = 1;
  static const int headerModeHide = 2;
  static const int footerModeShow = 0;
  static const int footerModeHide = 1;
  static const int tipColorFollowContent = 0;
  static const int tipDividerColorDefault = -1;
  static const int tipDividerColorFollowContent = 0;
  static const int keepLightFollowSystem = 0;
  static const int keepLightOneMinute = 60;
  static const int keepLightFiveMinutes = 300;
  static const int keepLightTenMinutes = 600;
  static const int keepLightAlways = -1;
  static const int screenOrientationUnspecified = 0;
  static const int screenOrientationPortrait = 1;
  static const int screenOrientationLandscape = 2;
  static const int screenOrientationSensor = 3;
  static const int screenOrientationReversePortrait = 4;

  static PageDirection pageDirectionForMode(PageTurnMode mode) {
    return mode == PageTurnMode.scroll
        ? PageDirection.vertical
        : PageDirection.horizontal;
  }

  const ReadingSettings({
    // 安装后默认值：尽量对齐 Legado 的阅读默认体验
    this.fontSize = legadoV2FontSize,
    this.lineHeight = legadoV2LineHeight,
    this.letterSpacing = 0.0,
    this.paragraphSpacing = legadoV2ParagraphSpacing,
    this.marginHorizontal = legadoV2PaddingHorizontal,
    this.marginVertical = legadoV2PaddingVertical,
    // Legado 默认首套排版的纸色主题（本项目在 AppColors.readingThemes 末尾追加）
    this.themeIndex = 9,
    this.fontFamilyIndex = 0,
    // Legado 默认翻页：覆盖
    this.pageTurnMode = PageTurnMode.cover,
    this.keepScreenOn = false,
    this.keepLightSeconds = keepLightFollowSystem,
    this.showStatusBar = true,
    this.hideNavigationBar = false,
    this.paddingDisplayCutouts = false,
    this.showBattery = true,
    this.showTime = true,
    this.showProgress = true,
    this.showChapterProgress = true,
    this.brightness = 1.0,
    this.useSystemBrightness = true,
    this.showBrightnessView = true,
    this.brightnessViewOnRight = false,
    this.showReadTitleAddition = true,
    this.readBarStyleFollowPage = false,
    this.layoutPresetVersion = layoutPresetVersionLegadoV2,
    this.progressBarBehavior = ProgressBarBehavior.page,
    this.confirmSkipChapter = true,
    // 新增字段默认值
    this.textBold = 0,
    this.paragraphIndent = '　　',
    this.titleMode = 0,
    this.titleSize = 4,
    this.titleTopSpacing = 0,
    this.titleBottomSpacing = 0,
    this.textFullJustify = true,
    this.underline = false,
    this.shareLayout = true,
    this.readStyleConfigs = const <ReadStyleConfig>[],
    this.paddingTop = legadoV2PaddingVertical,
    this.paddingBottom = legadoV2PaddingVertical,
    this.paddingLeft = legadoV2PaddingHorizontal,
    this.paddingRight = legadoV2PaddingHorizontal,
    this.headerPaddingTop = 4.0,
    this.headerPaddingBottom = 4.0,
    this.headerPaddingLeft = legadoV2PaddingHorizontal,
    this.headerPaddingRight = legadoV2PaddingHorizontal,
    this.footerPaddingTop = 4.0,
    this.footerPaddingBottom = 4.0,
    this.footerPaddingLeft = legadoV2PaddingHorizontal,
    this.footerPaddingRight = legadoV2PaddingHorizontal,
    this.clickActions = const {},
    this.autoReadSpeed = 10,
    // 对标 legado：翻页动画时长固定为 300ms
    this.pageAnimDuration = legacyPageAnimDuration,
    // 产品约束：除“滚动”以外的翻页模式一律水平；滚动模式由渲染层决定纵向滚动
    this.pageDirection = PageDirection.horizontal,
    this.pageTouchSlop = 0,
    // 对标 legado：滚动翻页默认保留动画
    this.noAnimScrollPage = false,
    this.volumeKeyPage = true,
    this.volumeKeyPageOnPlay = true,
    this.mouseWheelPage = true,
    this.keyPageOnLongPress = false,
    this.disableReturnKey = false,
    this.screenOrientation = screenOrientationUnspecified,
    // 页眉/页脚配置默认值
    this.hideHeader = false,
    this.hideFooter = false,
    this.showHeaderLine = false,
    this.showFooterLine = true,
    this.headerMode = headerModeHideWhenStatusBarShown,
    this.footerMode = footerModeShow,
    this.tipColor = tipColorFollowContent,
    this.tipDividerColor = tipDividerColorDefault,
    this.headerLeftContent = 3, // 时间
    this.headerCenterContent = 2, // 无
    this.headerRightContent = 4, // 电量
    this.footerLeftContent = 5, // 章节名
    this.footerCenterContent = 4, // 无
    this.footerRightContent = 8, // 页码/总页
    // 其他功能开关
    this.chineseConverterType = chineseConverterOff,
    this.cleanChapterTitle = false,
    this.textBottomJustify = true,
  });

  /// 兼容旧调用：`true` 等价于「简转繁」。
  bool get chineseTraditional =>
      chineseConverterType == chineseConverterSimplifiedToTraditional;

  /// 获取 padding（兼容旧代码）
  EdgeInsets get padding => EdgeInsets.symmetric(
        horizontal: marginHorizontal,
        vertical: marginVertical,
      );

  bool shouldShowHeader({required bool showStatusBar}) {
    switch (headerMode) {
      case headerModeShow:
        return true;
      case headerModeHide:
        return false;
      case headerModeHideWhenStatusBarShown:
      default:
        return !showStatusBar;
    }
  }

  bool shouldShowFooter() {
    return footerMode != footerModeHide;
  }

  Color resolveTipTextColor(Color contentColor) {
    if (tipColor == tipColorFollowContent) {
      return contentColor;
    }
    return Color(_normalizeColorInt(
      tipColor,
      fallback: tipColorFollowContent,
      allowNegativeOne: false,
      allowZero: true,
    ));
  }

  Color resolveTipDividerColor({
    required Color contentColor,
    required Color defaultDividerColor,
  }) {
    final normalized = _normalizeColorInt(
      tipDividerColor,
      fallback: tipDividerColorDefault,
      allowNegativeOne: true,
      allowZero: true,
    );
    if (normalized == tipDividerColorDefault) {
      return defaultDividerColor;
    }
    if (normalized == tipDividerColorFollowContent) {
      return contentColor;
    }
    return Color(normalized);
  }

  static double _toDouble(dynamic raw, double fallback) {
    if (raw is num && raw.isFinite) return raw.toDouble();
    if (raw is String) {
      final parsed = double.tryParse(raw);
      if (parsed != null && parsed.isFinite) return parsed;
    }
    return fallback;
  }

  static int _toInt(dynamic raw, int fallback) {
    if (raw is int) return raw;
    if (raw is num && raw.isFinite) return raw.toInt();
    if (raw is String) {
      final parsed = int.tryParse(raw);
      if (parsed != null) return parsed;
    }
    return fallback;
  }

  static bool _toBool(dynamic raw, bool fallback) {
    if (raw is bool) return raw;
    if (raw is num) return raw != 0;
    if (raw is String) {
      if (raw == '1' || raw.toLowerCase() == 'true') return true;
      if (raw == '0' || raw.toLowerCase() == 'false') return false;
    }
    return fallback;
  }

  static bool _isCloseTo(double value, double target) {
    return (value - target).abs() <= 0.0001;
  }

  static double _safeDouble(
    double raw, {
    required double min,
    required double max,
    required double fallback,
  }) {
    final safeRaw = raw.isFinite ? raw : fallback;
    final safeMin = min.isFinite ? min : 0.0;
    final safeMax = max.isFinite && max >= safeMin ? max : safeMin;
    return safeRaw.clamp(safeMin, safeMax).toDouble();
  }

  static int _safeInt(
    int raw, {
    required int min,
    required int max,
    required int fallback,
  }) {
    final safeMin = min <= max ? min : max;
    final safeMax = max >= min ? max : min;
    final safeRaw = (raw < safeMin || raw > safeMax) ? fallback : raw;
    return safeRaw.clamp(safeMin, safeMax).toInt();
  }

  static int _normalizeColorInt(
    int raw, {
    required int fallback,
    required bool allowNegativeOne,
    required bool allowZero,
  }) {
    if (allowNegativeOne && raw == -1) {
      return -1;
    }
    if (allowZero && raw == 0) {
      return 0;
    }
    var value = raw;
    if (value < 0) {
      value = value & 0xFFFFFFFF;
    }
    if (value < 0 || value > 0xFFFFFFFF) {
      return fallback;
    }
    if (value == 0 && !allowZero) {
      return fallback;
    }
    if (value != 0xFFFFFFFF && (value & 0xFF000000) == 0) {
      value = value | 0xFF000000;
    }
    return value;
  }

  static Map<String, int> _parseClickActions(dynamic raw) {
    if (raw is! Map) {
      return ClickAction.normalizeConfig(const <String, int>{});
    }
    final parsed = <String, int>{};
    for (final entry in raw.entries) {
      parsed[entry.key.toString()] = _toInt(entry.value, ClickAction.showMenu);
    }
    return ClickAction.normalizeConfig(parsed);
  }

  static List<ReadStyleConfig> _parseReadStyleConfigs(dynamic raw) {
    if (raw is! List) {
      return const <ReadStyleConfig>[];
    }
    final parsed = <ReadStyleConfig>[];
    for (final item in raw) {
      if (item is Map<String, dynamic>) {
        parsed.add(ReadStyleConfig.fromJson(item).sanitize());
        continue;
      }
      if (item is Map) {
        parsed.add(
          ReadStyleConfig.fromJson(
            item.map((key, value) => MapEntry('$key', value)),
          ).sanitize(),
        );
      }
    }
    return parsed;
  }

  static ProgressBarBehavior _parseProgressBarBehavior(
    dynamic raw, {
    ProgressBarBehavior fallback = ProgressBarBehavior.page,
  }) {
    if (raw is String) {
      final normalized = raw.trim().toLowerCase();
      if (normalized == 'chapter') return ProgressBarBehavior.chapter;
      if (normalized == 'page') return ProgressBarBehavior.page;
    }
    if (raw is num && raw.isFinite) {
      final index = raw.toInt().clamp(0, ProgressBarBehavior.values.length - 1);
      return ProgressBarBehavior.values[index];
    }
    return fallback;
  }

  static bool _isValidKeepLightSeconds(int value) {
    return value == keepLightFollowSystem ||
        value == keepLightOneMinute ||
        value == keepLightFiveMinutes ||
        value == keepLightTenMinutes ||
        value == keepLightAlways;
  }

  static int _normalizeKeepLightSeconds(int value, {required int fallback}) {
    if (_isValidKeepLightSeconds(value)) {
      return value;
    }
    if (_isValidKeepLightSeconds(fallback)) {
      return fallback;
    }
    return keepLightFollowSystem;
  }

  factory ReadingSettings.fromJson(Map<String, dynamic> json) {
    final rawPageTurnMode = json['pageTurnMode'];
    final pageTurnModeIndex = _toInt(rawPageTurnMode, PageTurnMode.cover.index);
    final safePageTurnModeIndex =
        pageTurnModeIndex.clamp(0, PageTurnMode.values.length - 1);
    final safePageTurnMode = PageTurnMode.values[safePageTurnModeIndex];

    final defaultPageDirectionIndex =
        pageDirectionForMode(safePageTurnMode).index;
    final rawPageDirection = json['pageDirection'];
    final pageDirectionIndex =
        _toInt(rawPageDirection, defaultPageDirectionIndex);
    final safePageDirectionIndex =
        pageDirectionIndex.clamp(0, PageDirection.values.length - 1);
    final legacyKeepScreenOn = _toBool(json['keepScreenOn'], false);
    final keepLightFallback =
        legacyKeepScreenOn ? keepLightAlways : keepLightFollowSystem;
    final rawKeepLightSeconds = json.containsKey('keepLightSeconds')
        ? _toInt(json['keepLightSeconds'], keepLightFallback)
        : keepLightFallback;
    final keepLightSeed =
        legacyKeepScreenOn && rawKeepLightSeconds == keepLightFollowSystem
            ? keepLightAlways
            : rawKeepLightSeconds;
    final parsedKeepLightSeconds = _normalizeKeepLightSeconds(
      keepLightSeed,
      fallback: keepLightFallback,
    );
    final legacyChineseTraditional = _toBool(json['chineseTraditional'], false);
    final chineseConverterType = json.containsKey('chineseConverterType')
        ? _toInt(json['chineseConverterType'], chineseConverterOff)
        : (legacyChineseTraditional
            ? chineseConverterSimplifiedToTraditional
            : chineseConverterOff);
    final hasHeaderMode = json.containsKey('headerMode');
    final hasFooterMode = json.containsKey('footerMode');
    final hasHideHeader = json.containsKey('hideHeader');
    final hasHideFooter = json.containsKey('hideFooter');
    final parsedHeaderMode = hasHeaderMode
        ? _toInt(json['headerMode'], headerModeHideWhenStatusBarShown)
        : (hasHideHeader
            ? (_toBool(json['hideHeader'], false)
                ? headerModeHide
                : headerModeShow)
            : headerModeHideWhenStatusBarShown);
    final parsedFooterMode = hasFooterMode
        ? _toInt(json['footerMode'], footerModeShow)
        : (hasHideFooter
            ? (_toBool(json['hideFooter'], false)
                ? footerModeHide
                : footerModeShow)
            : footerModeShow);

    var layoutPresetVersion = _toInt(
      json['layoutPresetVersion'],
      layoutPresetVersionLegacy,
    );
    var fontSize = _toDouble(json['fontSize'], legacyV1FontSize);
    var lineHeight = _toDouble(json['lineHeight'], legacyV1LineHeight);
    const letterSpacing = 0.0;
    var paragraphSpacing =
        _toDouble(json['paragraphSpacing'], legacyV1ParagraphSpacing);
    var marginHorizontal = json.containsKey('marginHorizontal')
        ? _toDouble(json['marginHorizontal'], legacyV1PaddingHorizontal)
        : _toDouble(json['paddingH'], legacyV1PaddingHorizontal);
    var marginVertical = json.containsKey('marginVertical')
        ? _toDouble(json['marginVertical'], legacyV1MarginVertical)
        : _toDouble(json['paddingV'], legacyV1MarginVertical);
    var paddingTop = _toDouble(json['paddingTop'], legacyV1PaddingTop);
    var paddingBottom = _toDouble(json['paddingBottom'], legacyV1PaddingBottom);
    var paddingLeft = _toDouble(json['paddingLeft'], legacyV1PaddingHorizontal);
    var paddingRight =
        _toDouble(json['paddingRight'], legacyV1PaddingHorizontal);
    var headerPaddingTop = _toDouble(json['headerPaddingTop'], 4.0);
    var headerPaddingBottom = _toDouble(json['headerPaddingBottom'], 4.0);
    var headerPaddingLeft = _toDouble(
      json['headerPaddingLeft'],
      _toDouble(json['paddingLeft'], legacyV1PaddingHorizontal),
    );
    var headerPaddingRight = _toDouble(
      json['headerPaddingRight'],
      _toDouble(json['paddingRight'], legacyV1PaddingHorizontal),
    );
    var footerPaddingTop = _toDouble(json['footerPaddingTop'], 4.0);
    var footerPaddingBottom = _toDouble(json['footerPaddingBottom'], 4.0);
    var footerPaddingLeft = _toDouble(
      json['footerPaddingLeft'],
      _toDouble(json['paddingLeft'], legacyV1PaddingHorizontal),
    );
    var footerPaddingRight = _toDouble(
      json['footerPaddingRight'],
      _toDouble(json['paddingRight'], legacyV1PaddingHorizontal),
    );

    if (layoutPresetVersion < layoutPresetVersionLegadoV2) {
      if (_isCloseTo(fontSize, legacyV1FontSize)) {
        fontSize = legadoV2FontSize;
      }
      if (_isCloseTo(lineHeight, legacyV1LineHeight)) {
        lineHeight = legadoV2LineHeight;
      }
      if (_isCloseTo(paragraphSpacing, legacyV1ParagraphSpacing)) {
        paragraphSpacing = legadoV2ParagraphSpacing;
      }
      if (_isCloseTo(marginHorizontal, legacyV1PaddingHorizontal)) {
        marginHorizontal = legadoV2PaddingHorizontal;
      }
      if (_isCloseTo(marginVertical, legacyV1MarginVertical)) {
        marginVertical = legadoV2PaddingVertical;
      }
      if (_isCloseTo(paddingTop, legacyV1PaddingTop)) {
        paddingTop = legadoV2PaddingVertical;
      }
      if (_isCloseTo(paddingBottom, legacyV1PaddingBottom)) {
        paddingBottom = legadoV2PaddingVertical;
      }
      if (_isCloseTo(paddingLeft, legacyV1PaddingHorizontal)) {
        paddingLeft = legadoV2PaddingHorizontal;
      }
      if (_isCloseTo(paddingRight, legacyV1PaddingHorizontal)) {
        paddingRight = legadoV2PaddingHorizontal;
      }
      if (_isCloseTo(headerPaddingLeft, legacyV1PaddingHorizontal)) {
        headerPaddingLeft = legadoV2PaddingHorizontal;
      }
      if (_isCloseTo(headerPaddingRight, legacyV1PaddingHorizontal)) {
        headerPaddingRight = legadoV2PaddingHorizontal;
      }
      if (_isCloseTo(footerPaddingLeft, legacyV1PaddingHorizontal)) {
        footerPaddingLeft = legadoV2PaddingHorizontal;
      }
      if (_isCloseTo(footerPaddingRight, legacyV1PaddingHorizontal)) {
        footerPaddingRight = legadoV2PaddingHorizontal;
      }
      layoutPresetVersion = layoutPresetVersionLegadoV2;
    }

    return ReadingSettings(
      fontSize: fontSize,
      lineHeight: lineHeight,
      letterSpacing: _toDouble(json['letterSpacing'], letterSpacing),
      paragraphSpacing: paragraphSpacing,
      marginHorizontal: marginHorizontal,
      marginVertical: marginVertical,
      themeIndex: _toInt(json['themeIndex'], 9),
      fontFamilyIndex: _toInt(json['fontFamilyIndex'], 0),
      pageTurnMode: safePageTurnMode,
      keepScreenOn: parsedKeepLightSeconds == keepLightAlways,
      keepLightSeconds: parsedKeepLightSeconds,
      showStatusBar: _toBool(json['showStatusBar'], true),
      hideNavigationBar: _toBool(json['hideNavigationBar'], false),
      paddingDisplayCutouts: _toBool(json['paddingDisplayCutouts'], false),
      showBattery: _toBool(json['showBattery'], true),
      showTime: _toBool(json['showTime'], true),
      showProgress: _toBool(json['showProgress'], true),
      showChapterProgress: _toBool(json['showChapterProgress'], true),
      brightness: _toDouble(json['brightness'], 1.0),
      useSystemBrightness: _toBool(json['useSystemBrightness'], true),
      showBrightnessView: _toBool(json['showBrightnessView'], true),
      brightnessViewOnRight: _toBool(json['brightnessViewOnRight'], false),
      showReadTitleAddition: _toBool(json['showReadTitleAddition'], true),
      readBarStyleFollowPage: _toBool(json['readBarStyleFollowPage'], false),
      layoutPresetVersion: layoutPresetVersion,
      progressBarBehavior:
          _parseProgressBarBehavior(json['progressBarBehavior']),
      confirmSkipChapter: _toBool(json['confirmSkipChapter'], true),
      // 新增字段
      textBold: _toInt(json['textBold'], 0),
      paragraphIndent: json['paragraphIndent'] as String? ?? '　　',
      titleMode: _toInt(json['titleMode'], 0),
      titleSize: _toInt(json['titleSize'], 4),
      titleTopSpacing: _toDouble(json['titleTopSpacing'], 0),
      titleBottomSpacing: _toDouble(json['titleBottomSpacing'], 0),
      textFullJustify: _toBool(json['textFullJustify'], true),
      underline: _toBool(json['underline'], false),
      shareLayout: _toBool(json['shareLayout'], true),
      readStyleConfigs: _parseReadStyleConfigs(json['readStyleConfigs']),
      paddingTop: paddingTop,
      paddingBottom: paddingBottom,
      paddingLeft: paddingLeft,
      paddingRight: paddingRight,
      headerPaddingTop: headerPaddingTop,
      headerPaddingBottom: headerPaddingBottom,
      headerPaddingLeft: headerPaddingLeft,
      headerPaddingRight: headerPaddingRight,
      footerPaddingTop: footerPaddingTop,
      footerPaddingBottom: footerPaddingBottom,
      footerPaddingLeft: footerPaddingLeft,
      footerPaddingRight: footerPaddingRight,
      clickActions: _parseClickActions(json['clickActions']),
      autoReadSpeed: _toInt(json['autoReadSpeed'], 10),
      // 对标 legado：翻页动画时长固定为 300ms（兼容读取旧字段但不生效）
      pageAnimDuration: legacyPageAnimDuration,
      pageDirection: PageDirection.values[safePageDirectionIndex],
      pageTouchSlop: _toInt(json['pageTouchSlop'], 0),
      noAnimScrollPage: _toBool(json['noAnimScrollPage'], false),
      volumeKeyPage: _toBool(json['volumeKeyPage'], true),
      volumeKeyPageOnPlay: _toBool(json['volumeKeyPageOnPlay'], true),
      mouseWheelPage: _toBool(json['mouseWheelPage'], true),
      keyPageOnLongPress: _toBool(json['keyPageOnLongPress'], false),
      disableReturnKey: _toBool(json['disableReturnKey'], false),
      screenOrientation: _toInt(
        json['screenOrientation'],
        screenOrientationUnspecified,
      ),
      // 页眉/页脚配置
      hideHeader:
          _toBool(json['hideHeader'], parsedHeaderMode == headerModeHide),
      hideFooter:
          _toBool(json['hideFooter'], parsedFooterMode == footerModeHide),
      showHeaderLine: _toBool(json['showHeaderLine'], false),
      showFooterLine: _toBool(json['showFooterLine'], true),
      headerMode: parsedHeaderMode,
      footerMode: parsedFooterMode,
      tipColor: _toInt(json['tipColor'], tipColorFollowContent),
      tipDividerColor: _toInt(json['tipDividerColor'], tipDividerColorDefault),
      headerLeftContent: _toInt(json['headerLeftContent'], 3),
      headerCenterContent: _toInt(json['headerCenterContent'], 2),
      headerRightContent: _toInt(json['headerRightContent'], 4),
      footerLeftContent: _toInt(json['footerLeftContent'], 5),
      footerCenterContent: _toInt(json['footerCenterContent'], 4),
      footerRightContent: _toInt(json['footerRightContent'], 8),
      // 其他功能开关
      chineseConverterType: chineseConverterType,
      cleanChapterTitle: _toBool(json['cleanChapterTitle'], false),
      textBottomJustify: _toBool(json['textBottomJustify'], true),
    ).sanitize();
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
      'keepLightSeconds': keepLightSeconds,
      'showStatusBar': showStatusBar,
      'hideNavigationBar': hideNavigationBar,
      'paddingDisplayCutouts': paddingDisplayCutouts,
      'showBattery': showBattery,
      'showTime': showTime,
      'showProgress': showProgress,
      'showChapterProgress': showChapterProgress,
      'brightness': brightness,
      'useSystemBrightness': useSystemBrightness,
      'showBrightnessView': showBrightnessView,
      'brightnessViewOnRight': brightnessViewOnRight,
      'showReadTitleAddition': showReadTitleAddition,
      'readBarStyleFollowPage': readBarStyleFollowPage,
      'layoutPresetVersion': layoutPresetVersion,
      'progressBarBehavior': progressBarBehavior.name,
      'confirmSkipChapter': confirmSkipChapter,
      // 新增字段
      'textBold': textBold,
      'paragraphIndent': paragraphIndent,
      'titleMode': titleMode,
      'titleSize': titleSize,
      'titleTopSpacing': titleTopSpacing,
      'titleBottomSpacing': titleBottomSpacing,
      'textFullJustify': textFullJustify,
      'underline': underline,
      'shareLayout': shareLayout,
      'readStyleConfigs': readStyleConfigs
          .map((config) => config.toJson())
          .toList(growable: false),
      'paddingTop': paddingTop,
      'paddingBottom': paddingBottom,
      'paddingLeft': paddingLeft,
      'paddingRight': paddingRight,
      'headerPaddingTop': headerPaddingTop,
      'headerPaddingBottom': headerPaddingBottom,
      'headerPaddingLeft': headerPaddingLeft,
      'headerPaddingRight': headerPaddingRight,
      'footerPaddingTop': footerPaddingTop,
      'footerPaddingBottom': footerPaddingBottom,
      'footerPaddingLeft': footerPaddingLeft,
      'footerPaddingRight': footerPaddingRight,
      'clickActions': ClickAction.normalizeConfig(clickActions),
      'autoReadSpeed': autoReadSpeed,
      // 对标 legado：翻页动画时长固定 300ms
      'pageAnimDuration': legacyPageAnimDuration,
      'pageDirection': pageDirection.index,
      'pageTouchSlop': pageTouchSlop,
      'noAnimScrollPage': noAnimScrollPage,
      'volumeKeyPage': volumeKeyPage,
      'volumeKeyPageOnPlay': volumeKeyPageOnPlay,
      'mouseWheelPage': mouseWheelPage,
      'keyPageOnLongPress': keyPageOnLongPress,
      'disableReturnKey': disableReturnKey,
      'screenOrientation': screenOrientation,
      // 页眉/页脚配置
      'hideHeader': hideHeader,
      'hideFooter': hideFooter,
      'showHeaderLine': showHeaderLine,
      'showFooterLine': showFooterLine,
      'headerMode': headerMode,
      'footerMode': footerMode,
      'tipColor': tipColor,
      'tipDividerColor': tipDividerColor,
      'headerLeftContent': headerLeftContent,
      'headerCenterContent': headerCenterContent,
      'headerRightContent': headerRightContent,
      'footerLeftContent': footerLeftContent,
      'footerCenterContent': footerCenterContent,
      'footerRightContent': footerRightContent,
      // 其他功能开关
      'chineseConverterType': chineseConverterType,
      'chineseTraditional': chineseTraditional,
      'cleanChapterTitle': cleanChapterTitle,
      'textBottomJustify': textBottomJustify,
    };
  }

  ReadingSettings sanitize() {
    final safeReadStyleConfigs = readStyleConfigs
        .map((config) => config.sanitize())
        .toList(growable: false);
    final safeThemeIndex = safeReadStyleConfigs.isEmpty
        ? (themeIndex < 0 ? 0 : themeIndex)
        : themeIndex.clamp(0, safeReadStyleConfigs.length - 1).toInt();
    final safeHeaderMode = _safeInt(
      headerMode,
      min: headerModeHideWhenStatusBarShown,
      max: headerModeHide,
      fallback: headerModeHideWhenStatusBarShown,
    );
    final safeFooterMode = _safeInt(
      footerMode,
      min: footerModeShow,
      max: footerModeHide,
      fallback: footerModeShow,
    );
    final keepLightSeed =
        keepScreenOn && keepLightSeconds == keepLightFollowSystem
            ? keepLightAlways
            : keepLightSeconds;
    final safeKeepLightSeconds = _normalizeKeepLightSeconds(
      keepLightSeed,
      fallback: keepScreenOn ? keepLightAlways : keepLightFollowSystem,
    );
    final safePageDirection = pageDirectionForMode(pageTurnMode);
    final safeLayoutPresetVersion =
        layoutPresetVersion < layoutPresetVersionLegadoV2
            ? layoutPresetVersionLegadoV2
            : layoutPresetVersion;
    return ReadingSettings(
      fontSize: _safeDouble(
        fontSize,
        min: 10.0,
        max: 60.0,
        fallback: legadoV2FontSize,
      ),
      lineHeight: _safeDouble(
        lineHeight,
        min: 1.0,
        max: 4.0,
        fallback: legadoV2LineHeight,
      ),
      letterSpacing: _safeDouble(
        letterSpacing,
        min: -2.0,
        max: 5.0,
        fallback: 0.0,
      ),
      paragraphSpacing: _safeDouble(
        paragraphSpacing,
        min: 0.0,
        max: 80.0,
        fallback: legadoV2ParagraphSpacing,
      ),
      marginHorizontal: _safeDouble(
        marginHorizontal,
        min: 0.0,
        max: 120.0,
        fallback: legadoV2PaddingHorizontal,
      ),
      marginVertical: _safeDouble(
        marginVertical,
        min: 0.0,
        max: 120.0,
        fallback: legadoV2PaddingVertical,
      ),
      themeIndex: safeThemeIndex,
      fontFamilyIndex: fontFamilyIndex < 0 ? 0 : fontFamilyIndex,
      pageTurnMode: pageTurnMode,
      keepScreenOn: safeKeepLightSeconds == keepLightAlways,
      keepLightSeconds: safeKeepLightSeconds,
      showStatusBar: showStatusBar,
      hideNavigationBar: hideNavigationBar,
      paddingDisplayCutouts: paddingDisplayCutouts,
      showBattery: showBattery,
      showTime: showTime,
      showProgress: showProgress,
      showChapterProgress: showChapterProgress,
      brightness: _safeDouble(
        brightness,
        min: 0.0,
        max: 1.0,
        fallback: 1.0,
      ),
      useSystemBrightness: useSystemBrightness,
      showBrightnessView: showBrightnessView,
      brightnessViewOnRight: brightnessViewOnRight,
      showReadTitleAddition: showReadTitleAddition,
      readBarStyleFollowPage: readBarStyleFollowPage,
      layoutPresetVersion: safeLayoutPresetVersion,
      progressBarBehavior: progressBarBehavior,
      confirmSkipChapter: confirmSkipChapter,
      textBold: _safeInt(textBold, min: 0, max: 2, fallback: 0),
      paragraphIndent: paragraphIndent,
      titleMode: _safeInt(titleMode, min: 0, max: 2, fallback: 0),
      titleSize: _safeInt(titleSize, min: -20, max: 20, fallback: 4),
      titleTopSpacing: _safeDouble(
        titleTopSpacing,
        min: 0.0,
        max: 120.0,
        fallback: 0.0,
      ),
      titleBottomSpacing: _safeDouble(
        titleBottomSpacing,
        min: 0.0,
        max: 120.0,
        fallback: 0.0,
      ),
      textFullJustify: textFullJustify,
      underline: underline,
      shareLayout: shareLayout,
      readStyleConfigs: safeReadStyleConfigs,
      paddingTop: _safeDouble(
        paddingTop,
        min: 0.0,
        max: 120.0,
        fallback: legadoV2PaddingVertical,
      ),
      paddingBottom: _safeDouble(
        paddingBottom,
        min: 0.0,
        max: 120.0,
        fallback: legadoV2PaddingVertical,
      ),
      paddingLeft: _safeDouble(
        paddingLeft,
        min: 0.0,
        max: 120.0,
        fallback: legadoV2PaddingHorizontal,
      ),
      paddingRight: _safeDouble(
        paddingRight,
        min: 0.0,
        max: 120.0,
        fallback: legadoV2PaddingHorizontal,
      ),
      headerPaddingTop: _safeDouble(
        headerPaddingTop,
        min: 0.0,
        max: 120.0,
        fallback: 4.0,
      ),
      headerPaddingBottom: _safeDouble(
        headerPaddingBottom,
        min: 0.0,
        max: 120.0,
        fallback: 4.0,
      ),
      headerPaddingLeft: _safeDouble(
        headerPaddingLeft,
        min: 0.0,
        max: 120.0,
        fallback: legadoV2PaddingHorizontal,
      ),
      headerPaddingRight: _safeDouble(
        headerPaddingRight,
        min: 0.0,
        max: 120.0,
        fallback: legadoV2PaddingHorizontal,
      ),
      footerPaddingTop: _safeDouble(
        footerPaddingTop,
        min: 0.0,
        max: 120.0,
        fallback: 4.0,
      ),
      footerPaddingBottom: _safeDouble(
        footerPaddingBottom,
        min: 0.0,
        max: 120.0,
        fallback: 4.0,
      ),
      footerPaddingLeft: _safeDouble(
        footerPaddingLeft,
        min: 0.0,
        max: 120.0,
        fallback: legadoV2PaddingHorizontal,
      ),
      footerPaddingRight: _safeDouble(
        footerPaddingRight,
        min: 0.0,
        max: 120.0,
        fallback: legadoV2PaddingHorizontal,
      ),
      clickActions: ClickAction.normalizeConfig(
        Map<String, int>.from(clickActions),
      ),
      autoReadSpeed: _safeInt(autoReadSpeed, min: 1, max: 100, fallback: 10),
      pageAnimDuration: legacyPageAnimDuration,
      pageDirection: safePageDirection,
      pageTouchSlop: _safeInt(pageTouchSlop, min: 0, max: 9999, fallback: 0),
      noAnimScrollPage: noAnimScrollPage,
      volumeKeyPage: volumeKeyPage,
      volumeKeyPageOnPlay: volumeKeyPageOnPlay,
      mouseWheelPage: mouseWheelPage,
      keyPageOnLongPress: keyPageOnLongPress,
      disableReturnKey: disableReturnKey,
      screenOrientation: _safeInt(
        screenOrientation,
        min: screenOrientationUnspecified,
        max: screenOrientationReversePortrait,
        fallback: screenOrientationUnspecified,
      ),
      hideHeader: safeHeaderMode == headerModeHide,
      hideFooter: safeFooterMode == footerModeHide,
      showHeaderLine: showHeaderLine,
      showFooterLine: showFooterLine,
      headerMode: safeHeaderMode,
      footerMode: safeFooterMode,
      tipColor: _normalizeColorInt(
        tipColor,
        fallback: tipColorFollowContent,
        allowNegativeOne: false,
        allowZero: true,
      ),
      tipDividerColor: _normalizeColorInt(
        tipDividerColor,
        fallback: tipDividerColorDefault,
        allowNegativeOne: true,
        allowZero: true,
      ),
      headerLeftContent:
          _safeInt(headerLeftContent, min: 0, max: 9, fallback: 3),
      headerCenterContent:
          _safeInt(headerCenterContent, min: 0, max: 9, fallback: 2),
      headerRightContent:
          _safeInt(headerRightContent, min: 0, max: 9, fallback: 4),
      footerLeftContent:
          _safeInt(footerLeftContent, min: 0, max: 9, fallback: 5),
      footerCenterContent:
          _safeInt(footerCenterContent, min: 0, max: 9, fallback: 4),
      footerRightContent:
          _safeInt(footerRightContent, min: 0, max: 9, fallback: 8),
      chineseConverterType: _safeInt(
        chineseConverterType,
        min: chineseConverterOff,
        max: chineseConverterSimplifiedToTraditional,
        fallback: chineseConverterOff,
      ),
      cleanChapterTitle: cleanChapterTitle,
      textBottomJustify: textBottomJustify,
    );
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
    int? keepLightSeconds,
    bool? showStatusBar,
    bool? hideNavigationBar,
    bool? paddingDisplayCutouts,
    bool? showBattery,
    bool? showTime,
    bool? showProgress,
    bool? showChapterProgress,
    double? brightness,
    bool? useSystemBrightness,
    bool? showBrightnessView,
    bool? brightnessViewOnRight,
    bool? showReadTitleAddition,
    bool? readBarStyleFollowPage,
    int? layoutPresetVersion,
    ProgressBarBehavior? progressBarBehavior,
    bool? confirmSkipChapter,
    // 新增字段
    int? textBold,
    String? paragraphIndent,
    int? titleMode,
    int? titleSize,
    double? titleTopSpacing,
    double? titleBottomSpacing,
    bool? textFullJustify,
    bool? underline,
    bool? shareLayout,
    List<ReadStyleConfig>? readStyleConfigs,
    double? paddingTop,
    double? paddingBottom,
    double? paddingLeft,
    double? paddingRight,
    double? headerPaddingTop,
    double? headerPaddingBottom,
    double? headerPaddingLeft,
    double? headerPaddingRight,
    double? footerPaddingTop,
    double? footerPaddingBottom,
    double? footerPaddingLeft,
    double? footerPaddingRight,
    Map<String, int>? clickActions,
    int? autoReadSpeed,
    // 翻页动画增强
    int? pageAnimDuration,
    PageDirection? pageDirection,
    int? pageTouchSlop,
    bool? noAnimScrollPage,
    bool? volumeKeyPage,
    bool? volumeKeyPageOnPlay,
    bool? mouseWheelPage,
    bool? keyPageOnLongPress,
    bool? disableReturnKey,
    int? screenOrientation,
    // 页眉/页脚配置
    int? headerMode,
    int? footerMode,
    int? tipColor,
    int? tipDividerColor,
    bool? hideHeader,
    bool? hideFooter,
    bool? showHeaderLine,
    bool? showFooterLine,
    int? headerLeftContent,
    int? headerCenterContent,
    int? headerRightContent,
    int? footerLeftContent,
    int? footerCenterContent,
    int? footerRightContent,
    // 其他功能开关
    int? chineseConverterType,
    bool? chineseTraditional,
    bool? cleanChapterTitle,
    bool? textBottomJustify,
  }) {
    final resolvedChineseConverterType = chineseConverterType ??
        (chineseTraditional == null
            ? this.chineseConverterType
            : (chineseTraditional
                ? chineseConverterSimplifiedToTraditional
                : chineseConverterOff));
    final resolvedHeaderMode = headerMode ??
        (hideHeader == null
            ? this.headerMode
            : (hideHeader ? headerModeHide : headerModeShow));
    final resolvedFooterMode = footerMode ??
        (hideFooter == null
            ? this.footerMode
            : (hideFooter ? footerModeHide : footerModeShow));
    final resolvedKeepLightSeconds = keepLightSeconds ??
        (keepScreenOn == null
            ? this.keepLightSeconds
            : (keepScreenOn ? keepLightAlways : keepLightFollowSystem));
    final resolvedKeepScreenOn = keepScreenOn ??
        (keepLightSeconds == null
            ? this.keepScreenOn
            : keepLightSeconds == keepLightAlways);

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
      keepScreenOn: resolvedKeepScreenOn,
      keepLightSeconds: resolvedKeepLightSeconds,
      showStatusBar: showStatusBar ?? this.showStatusBar,
      hideNavigationBar: hideNavigationBar ?? this.hideNavigationBar,
      paddingDisplayCutouts:
          paddingDisplayCutouts ?? this.paddingDisplayCutouts,
      showBattery: showBattery ?? this.showBattery,
      showTime: showTime ?? this.showTime,
      showProgress: showProgress ?? this.showProgress,
      showChapterProgress: showChapterProgress ?? this.showChapterProgress,
      brightness: brightness ?? this.brightness,
      useSystemBrightness: useSystemBrightness ?? this.useSystemBrightness,
      showBrightnessView: showBrightnessView ?? this.showBrightnessView,
      brightnessViewOnRight:
          brightnessViewOnRight ?? this.brightnessViewOnRight,
      showReadTitleAddition:
          showReadTitleAddition ?? this.showReadTitleAddition,
      readBarStyleFollowPage:
          readBarStyleFollowPage ?? this.readBarStyleFollowPage,
      layoutPresetVersion: layoutPresetVersion ?? this.layoutPresetVersion,
      progressBarBehavior: progressBarBehavior ?? this.progressBarBehavior,
      confirmSkipChapter: confirmSkipChapter ?? this.confirmSkipChapter,
      // 新增字段
      textBold: textBold ?? this.textBold,
      paragraphIndent: paragraphIndent ?? this.paragraphIndent,
      titleMode: titleMode ?? this.titleMode,
      titleSize: titleSize ?? this.titleSize,
      titleTopSpacing: titleTopSpacing ?? this.titleTopSpacing,
      titleBottomSpacing: titleBottomSpacing ?? this.titleBottomSpacing,
      textFullJustify: textFullJustify ?? this.textFullJustify,
      underline: underline ?? this.underline,
      shareLayout: shareLayout ?? this.shareLayout,
      readStyleConfigs: readStyleConfigs ?? this.readStyleConfigs,
      paddingTop: paddingTop ?? this.paddingTop,
      paddingBottom: paddingBottom ?? this.paddingBottom,
      paddingLeft: paddingLeft ?? this.paddingLeft,
      paddingRight: paddingRight ?? this.paddingRight,
      headerPaddingTop: headerPaddingTop ?? this.headerPaddingTop,
      headerPaddingBottom: headerPaddingBottom ?? this.headerPaddingBottom,
      headerPaddingLeft: headerPaddingLeft ?? this.headerPaddingLeft,
      headerPaddingRight: headerPaddingRight ?? this.headerPaddingRight,
      footerPaddingTop: footerPaddingTop ?? this.footerPaddingTop,
      footerPaddingBottom: footerPaddingBottom ?? this.footerPaddingBottom,
      footerPaddingLeft: footerPaddingLeft ?? this.footerPaddingLeft,
      footerPaddingRight: footerPaddingRight ?? this.footerPaddingRight,
      clickActions: clickActions ?? this.clickActions,
      autoReadSpeed: autoReadSpeed ?? this.autoReadSpeed,
      // 翻页动画增强
      pageAnimDuration: pageAnimDuration ?? this.pageAnimDuration,
      pageDirection: pageDirection ?? this.pageDirection,
      pageTouchSlop: pageTouchSlop ?? this.pageTouchSlop,
      noAnimScrollPage: noAnimScrollPage ?? this.noAnimScrollPage,
      volumeKeyPage: volumeKeyPage ?? this.volumeKeyPage,
      volumeKeyPageOnPlay: volumeKeyPageOnPlay ?? this.volumeKeyPageOnPlay,
      mouseWheelPage: mouseWheelPage ?? this.mouseWheelPage,
      keyPageOnLongPress: keyPageOnLongPress ?? this.keyPageOnLongPress,
      disableReturnKey: disableReturnKey ?? this.disableReturnKey,
      screenOrientation: screenOrientation ?? this.screenOrientation,
      // 页眉/页脚配置
      hideHeader: resolvedHeaderMode == headerModeHide,
      hideFooter: resolvedFooterMode == footerModeHide,
      showHeaderLine: showHeaderLine ?? this.showHeaderLine,
      showFooterLine: showFooterLine ?? this.showFooterLine,
      headerMode: resolvedHeaderMode,
      footerMode: resolvedFooterMode,
      tipColor: tipColor ?? this.tipColor,
      tipDividerColor: tipDividerColor ?? this.tipDividerColor,
      headerLeftContent: headerLeftContent ?? this.headerLeftContent,
      headerCenterContent: headerCenterContent ?? this.headerCenterContent,
      headerRightContent: headerRightContent ?? this.headerRightContent,
      footerLeftContent: footerLeftContent ?? this.footerLeftContent,
      footerCenterContent: footerCenterContent ?? this.footerCenterContent,
      footerRightContent: footerRightContent ?? this.footerRightContent,
      // 其他功能开关
      chineseConverterType: resolvedChineseConverterType,
      cleanChapterTitle: cleanChapterTitle ?? this.cleanChapterTitle,
      textBottomJustify: textBottomJustify ?? this.textBottomJustify,
    ).sanitize();
  }
}

/// 阅读样式（对标 legado ReadBookConfig.Config 的样式卡片核心可见字段）
class ReadStyleConfig {
  final String name;
  final int backgroundColor;
  final int textColor;
  final int bgType;
  final String bgStr;
  final int bgAlpha;

  /// legado 删除样式时保留最少数量阈值
  static const int minEditableCount = 5;
  static const int legacyDefaultBackgroundColor = 0xFFEEEEEE;
  static const int legacyDefaultTextColor = 0xFF3E3D3B;
  static const int legacyDefaultBgAlpha = 100;
  static const int bgTypeColor = 0;
  static const int bgTypeAsset = 1;
  static const int bgTypeFile = 2;

  const ReadStyleConfig({
    this.name = '',
    this.backgroundColor = legacyDefaultBackgroundColor,
    this.textColor = legacyDefaultTextColor,
    this.bgType = bgTypeColor,
    this.bgStr = '',
    this.bgAlpha = legacyDefaultBgAlpha,
  });

  factory ReadStyleConfig.fromJson(Map<String, dynamic> json) {
    final parsedBgType = _parseInt(json['bgType'], fallback: bgTypeColor)
        .clamp(bgTypeColor, bgTypeFile)
        .toInt();
    final rawBgStr = _stringOrEmpty(json['bgStr']);

    final parsedTextColor = _parseColor(
      json.containsKey('textColor')
          ? json['textColor']
          : (json['textColorInt'] ?? json['fgColor'] ?? json['text']),
      legacyDefaultTextColor,
    );

    int parsedBackgroundColor = _parseColor(
      json.containsKey('backgroundColor')
          ? json['backgroundColor']
          : (json['bgColor'] ?? json['bg']),
      legacyDefaultBackgroundColor,
    );
    if (!json.containsKey('backgroundColor') &&
        !json.containsKey('bgColor') &&
        parsedBgType == bgTypeColor) {
      parsedBackgroundColor = _parseColor(
        rawBgStr,
        legacyDefaultBackgroundColor,
      );
    }

    return ReadStyleConfig(
      name: _stringOrEmpty(json['name']).trim(),
      backgroundColor: parsedBackgroundColor,
      textColor: parsedTextColor,
      bgType: parsedBgType,
      bgStr: rawBgStr,
      bgAlpha: _parseInt(json['bgAlpha'], fallback: legacyDefaultBgAlpha),
    ).sanitize();
  }

  Map<String, dynamic> toJson() {
    final safe = sanitize();
    return <String, dynamic>{
      'name': safe.name,
      'backgroundColor': safe.backgroundColor,
      'textColor': safe.textColor,
      'bgType': safe.bgType,
      'bgStr': safe.bgStr,
      'bgAlpha': safe.bgAlpha,
    };
  }

  ReadStyleConfig sanitize() {
    final safeName = name.trim();
    final safeTextColor =
        _normalizeColor(textColor, fallback: legacyDefaultTextColor);
    final safeBgAlpha = _parseInt(bgAlpha, fallback: legacyDefaultBgAlpha)
        .clamp(0, 100)
        .toInt();
    final safeBgType = _parseInt(bgType, fallback: bgTypeColor)
        .clamp(bgTypeColor, bgTypeFile)
        .toInt();
    final safeRawBgStr = bgStr.trim();
    var safeBackgroundColor = _normalizeColor(
      backgroundColor,
      fallback: legacyDefaultBackgroundColor,
    );

    if (safeBgType == bgTypeColor) {
      safeBackgroundColor = _parseColor(
        safeRawBgStr,
        safeBackgroundColor,
      );
      return ReadStyleConfig(
        name: safeName,
        backgroundColor: safeBackgroundColor,
        textColor: safeTextColor,
        bgType: bgTypeColor,
        bgStr: '#${_hexRgb(safeBackgroundColor)}',
        bgAlpha: safeBgAlpha,
      );
    }

    if (safeRawBgStr.isEmpty) {
      return ReadStyleConfig(
        name: safeName,
        backgroundColor: safeBackgroundColor,
        textColor: safeTextColor,
        bgType: bgTypeColor,
        bgStr: '#${_hexRgb(safeBackgroundColor)}',
        bgAlpha: safeBgAlpha,
      );
    }

    return ReadStyleConfig(
      name: safeName,
      backgroundColor: safeBackgroundColor,
      textColor: safeTextColor,
      bgType: safeBgType,
      bgStr: safeRawBgStr,
      bgAlpha: safeBgAlpha,
    );
  }

  ReadStyleConfig copyWith({
    String? name,
    int? backgroundColor,
    int? textColor,
    int? bgType,
    String? bgStr,
    int? bgAlpha,
  }) {
    return ReadStyleConfig(
      name: name ?? this.name,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      textColor: textColor ?? this.textColor,
      bgType: bgType ?? this.bgType,
      bgStr: bgStr ?? this.bgStr,
      bgAlpha: bgAlpha ?? this.bgAlpha,
    ).sanitize();
  }

  static String _stringOrEmpty(dynamic raw) {
    if (raw == null) return '';
    if (raw is String) return raw.trim();
    return '$raw'.trim();
  }

  static int _parseInt(dynamic raw, {required int fallback}) {
    if (raw is int) return raw;
    if (raw is num && raw.isFinite) return raw.toInt();
    if (raw is String) {
      final text = raw.trim();
      if (text.isEmpty) return fallback;
      final parsed = int.tryParse(text);
      if (parsed != null) return parsed;
    }
    return fallback;
  }

  static int _parseColor(dynamic raw, int fallback) {
    if (raw is int) {
      return _normalizeColor(raw, fallback: fallback);
    }
    if (raw is num && raw.isFinite) {
      return _normalizeColor(raw.toInt(), fallback: fallback);
    }
    if (raw is! String) {
      return fallback;
    }
    var text = raw.trim();
    if (text.isEmpty) {
      return fallback;
    }
    if (text.startsWith('#')) {
      text = text.substring(1);
    }
    if (text.startsWith('0x') || text.startsWith('0X')) {
      text = text.substring(2);
    }
    if (text.length == 6 || text.length == 8) {
      final parsed = int.tryParse(text, radix: 16);
      if (parsed == null) {
        return fallback;
      }
      return _normalizeColor(parsed, fallback: fallback);
    }
    final parsedInt = int.tryParse(text);
    if (parsedInt == null) {
      return fallback;
    }
    return _normalizeColor(parsedInt, fallback: fallback);
  }

  static String _hexRgb(int colorValue) {
    final rgb = colorValue & 0x00FFFFFF;
    return rgb.toRadixString(16).padLeft(6, '0').toUpperCase();
  }

  static int _normalizeColor(
    int raw, {
    required int fallback,
  }) {
    var value = raw;
    if (value < 0) {
      value = value & 0xFFFFFFFF;
    }
    if (value < 0 || value > 0xFFFFFFFF) {
      return fallback;
    }
    if ((value & 0xFF000000) == 0) {
      value = value | 0xFF000000;
    }
    return value;
  }
}

enum ProgressBarBehavior {
  page, // 进度条拖动定位到章节内页
  chapter, // 进度条拖动切换章节
}

extension ProgressBarBehaviorExtension on ProgressBarBehavior {
  String get label {
    switch (this) {
      case ProgressBarBehavior.page:
        return '页内进度';
      case ProgressBarBehavior.chapter:
        return '章节进度';
    }
  }
}

class ChineseConverterType {
  static const int off = ReadingSettings.chineseConverterOff;
  static const int traditionalToSimplified =
      ReadingSettings.chineseConverterTraditionalToSimplified;
  static const int simplifiedToTraditional =
      ReadingSettings.chineseConverterSimplifiedToTraditional;

  static const List<int> values = <int>[
    off,
    traditionalToSimplified,
    simplifiedToTraditional,
  ];

  static String label(int value) {
    switch (value) {
      case traditionalToSimplified:
        return '繁转简';
      case simplifiedToTraditional:
        return '简转繁';
      case off:
      default:
        return '关闭';
    }
  }
}

class ReaderScreenOrientation {
  static const int unspecified = ReadingSettings.screenOrientationUnspecified;
  static const int portrait = ReadingSettings.screenOrientationPortrait;
  static const int landscape = ReadingSettings.screenOrientationLandscape;
  static const int sensor = ReadingSettings.screenOrientationSensor;
  static const int reversePortrait =
      ReadingSettings.screenOrientationReversePortrait;

  static const List<int> values = <int>[
    unspecified,
    portrait,
    landscape,
    sensor,
    reversePortrait,
  ];

  static String label(int value) {
    switch (value) {
      case portrait:
        return '竖屏';
      case landscape:
        return '横屏';
      case sensor:
        return '自动旋转';
      case reversePortrait:
        return '反向竖屏';
      case unspecified:
      default:
        return '跟随系统';
    }
  }
}

/// 点击动作类型
class ClickAction {
  static const int off = -1;
  static const int showMenu = 0;
  static const int nextPage = 1;
  static const int prevPage = 2;
  static const int nextChapter = 3;
  static const int prevChapter = 4;
  static const int readAloudPrevParagraph = 5;
  static const int readAloudNextParagraph = 6;
  static const int addBookmark = 7;
  static const int editContent = 8;
  static const int toggleReplaceRule = 9;
  static const int openChapterList = 10;
  static const int searchContent = 11;
  static const int syncBookProgress = 12;
  static const int readAloudPauseResume = 13;

  static const List<String> zoneOrder = <String>[
    'tl',
    'tc',
    'tr',
    'ml',
    'mc',
    'mr',
    'bl',
    'bc',
    'br',
  ];

  static const Map<String, int> defaultZoneConfig = <String, int>{
    'tl': prevPage,
    'tc': prevPage,
    'tr': nextPage,
    'ml': prevPage,
    'mc': showMenu,
    'mr': nextPage,
    'bl': prevPage,
    'bc': nextPage,
    'br': nextPage,
  };

  static const List<int> allActions = <int>[
    off,
    showMenu,
    nextPage,
    prevPage,
    nextChapter,
    prevChapter,
    readAloudPrevParagraph,
    readAloudNextParagraph,
    addBookmark,
    editContent,
    toggleReplaceRule,
    openChapterList,
    searchContent,
    syncBookProgress,
    readAloudPauseResume,
  ];

  static bool isValidAction(int action) => allActions.contains(action);

  static bool hasMenuZone(Map<String, int> config) {
    for (final zone in zoneOrder) {
      if ((config[zone] ?? defaultZoneConfig[zone] ?? showMenu) == showMenu) {
        return true;
      }
    }
    return false;
  }

  static Map<String, int> normalizeConfig(Map<String, int> rawConfig) {
    final normalized = <String, int>{...defaultZoneConfig};
    for (final zone in zoneOrder) {
      if (!rawConfig.containsKey(zone)) continue;
      final action = rawConfig[zone];
      if (action == null) continue;
      normalized[zone] = isValidAction(action) ? action : showMenu;
    }
    if (!hasMenuZone(normalized)) {
      normalized['mc'] = showMenu;
    }
    return normalized;
  }

  static String getName(int action) {
    switch (action) {
      case off:
        return '无';
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
      case readAloudPrevParagraph:
        return '朗读上一段';
      case readAloudNextParagraph:
        return '朗读下一段';
      case addBookmark:
        return '书签';
      case editContent:
        return '编辑正文';
      case toggleReplaceRule:
        return '替换开关';
      case openChapterList:
        return '目录';
      case searchContent:
        return '搜索正文';
      case syncBookProgress:
        return '同步进度';
      case readAloudPauseResume:
        return '朗读暂停/继续';
      default:
        return '无';
    }
  }
}

/// 翻页模式
enum PageTurnMode {
  slide, // 滑动
  simulation, // 仿真翻页 (Shader)
  cover, // 覆盖
  none, // 无动画
  scroll, // 滚动
  simulation2, // 仿真翻页2 (贝塞尔曲线，参考 flutter_novel)
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
      case PageTurnMode.simulation2:
        return '仿真2';
    }
  }

  IconData get icon {
    switch (this) {
      case PageTurnMode.slide:
        return CupertinoIcons.arrow_left_right;
      case PageTurnMode.simulation:
        return CupertinoIcons.book;
      case PageTurnMode.cover:
        return CupertinoIcons.square_stack;
      case PageTurnMode.none:
        return CupertinoIcons.stop;
      case PageTurnMode.scroll:
        return CupertinoIcons.arrow_up_arrow_down;
      case PageTurnMode.simulation2:
        return CupertinoIcons.book;
    }
  }
}

/// 翻页模式在 UI 中的展示顺序（对标 legado）
///
/// 约定：
/// - `simulation2` 默认隐藏（不出现在可选项里）
/// - `none`（无动画）永远放在最后
class PageTurnModeUi {
  static bool isHidden(PageTurnMode mode) => mode == PageTurnMode.simulation2;

  /// 返回用于 UI 展示/选择的翻页模式列表。
  ///
  /// - 当当前模式为隐藏项（`simulation2`）时，会把它插入到列表中（但 UI 应禁用点击）
  ///   以避免“当前选中值在 UI 里消失”的困惑。
  static List<PageTurnMode> values({required PageTurnMode current}) {
    final list = <PageTurnMode>[
      PageTurnMode.cover,
      PageTurnMode.slide,
      PageTurnMode.simulation,
      PageTurnMode.scroll,
      PageTurnMode.none, // 放最后
    ];

    if (current == PageTurnMode.simulation2) {
      list.insert(3, PageTurnMode.simulation2);
    }

    return list;
  }
}

/// 翻页方向
enum PageDirection {
  horizontal, // 水平（左右）
  vertical, // 垂直（上下）
}

extension PageDirectionExtension on PageDirection {
  String get name {
    switch (this) {
      case PageDirection.horizontal:
        return '水平';
      case PageDirection.vertical:
        return '垂直';
    }
  }

  IconData get icon {
    switch (this) {
      case PageDirection.horizontal:
        return CupertinoIcons.arrow_left_right;
      case PageDirection.vertical:
        return CupertinoIcons.arrow_up_arrow_down;
    }
  }
}
