import 'package:flutter/cupertino.dart';

import 'design_tokens.dart';

/// 管理页 UI Token（列表/分组/浮层等基础风格的单一真源）。
///
/// 约定：
/// - 仅用于“管理页/设置页/书源页/搜索页”等非沉浸阅读页面。
/// - 读取颜色时优先使用 CupertinoDynamicColor.resolveFrom(context)，避免平台差异。
/// - 不在业务页面散写 padding/radius/alpha；改为从 token 获取或使用 UI Kit 封装组件。
@immutable
class AppUiTokens {
  final Brightness brightness;
  final AppUiColors colors;
  final AppUiRadii radii;
  final AppUiSpacings spacings;
  final AppUiIconSizes iconSizes;
  final AppUiSizes sizes;

  const AppUiTokens({
    required this.brightness,
    required this.colors,
    required this.radii,
    required this.spacings,
    required this.iconSizes,
    required this.sizes,
  });

  bool get isDark => brightness == Brightness.dark;

  factory AppUiTokens.resolve(BuildContext context) {
    final theme = CupertinoTheme.of(context);
    final brightness = theme.brightness ??
        MediaQuery.maybeOf(context)?.platformBrightness ??
        Brightness.light;

    return AppUiTokens(
      brightness: brightness,
      colors: AppUiColors.resolve(context),
      radii: const AppUiRadii(),
      spacings: const AppUiSpacings(),
      iconSizes: const AppUiIconSizes(),
      sizes: const AppUiSizes(),
    );
  }
}

@immutable
class AppUiColors {
  final Color pageBackground;
  final Color groupedBackground;
  final Color sectionBackground;
  final Color surfaceBackground;
  final Color separator;
  final Color label;
  final Color secondaryLabel;
  final Color tertiaryLabel;
  final Color accent;
  final Color destructive;

  /// 主前景色（等同于 label，与旧 AppThemeTokens.foreground 对齐）。
  Color get foreground => label;

  /// 弱化前景色（与旧 AppThemeTokens.mutedForeground 对齐）。
  Color get mutedForeground => secondaryLabel;

  /// 卡片/分组内背景色（与旧 AppThemeTokens.card 对齐）。
  Color get card => sectionBackground;

  /// 卡片前景色（与旧 AppThemeTokens.cardForeground 对齐）。
  Color get cardForeground => label;

  const AppUiColors({
    required this.pageBackground,
    required this.groupedBackground,
    required this.sectionBackground,
    required this.surfaceBackground,
    required this.separator,
    required this.label,
    required this.secondaryLabel,
    required this.tertiaryLabel,
    required this.accent,
    required this.destructive,
  });

  factory AppUiColors.resolve(BuildContext context) {
    final theme = CupertinoTheme.of(context);
    return AppUiColors(
      pageBackground: theme.scaffoldBackgroundColor,
      groupedBackground:
          CupertinoColors.systemGroupedBackground.resolveFrom(context),
      sectionBackground:
          CupertinoColors.secondarySystemGroupedBackground.resolveFrom(context),
      surfaceBackground: CupertinoColors.systemBackground.resolveFrom(context),
      separator: CupertinoColors.separator.resolveFrom(context),
      label: CupertinoColors.label.resolveFrom(context),
      secondaryLabel: CupertinoColors.secondaryLabel.resolveFrom(context),
      tertiaryLabel: CupertinoColors.tertiaryLabel.resolveFrom(context),
      accent: theme.primaryColor,
      destructive: CupertinoColors.systemRed.resolveFrom(context),
    );
  }
}

@immutable
class AppUiRadii {
  final double control;
  final double card;
  final double popover;
  final double sheet;

  const AppUiRadii({
    this.control = AppDesignTokens.radiusControl,
    this.card = AppDesignTokens.radiusCard,
    this.popover = 12,
    this.sheet = 18,
  });
}

@immutable
class AppUiSpacings {
  /// 管理页常用 ListView/Column 外层 padding（全仓最高频）。
  final EdgeInsets pageListPadding;

  const AppUiSpacings({
    this.pageListPadding = const EdgeInsets.only(top: 8, bottom: 20),
  });
}

@immutable
class AppUiIconSizes {
  /// 列表 leading 图标的“实际视觉”尺寸（不是 leading 占位）。
  final double listLeading;

  /// 列表 trailing 图标尺寸（chevron/check 等）。
  final double listTrailing;

  /// 导航栏/工具栏图标尺寸。
  final double navBar;

  const AppUiIconSizes({
    this.listLeading = 20,
    this.listTrailing = 18,
    this.navBar = 22,
  });
}

@immutable
class AppUiSizes {
  /// 交互最小热区（iOS 人体工学）。
  final double minTapSize;

  /// 紧凑控件的最小热区（用于 chip/popover row 等高密度场景）。
  final double compactTapSize;

  /// 分隔线高度（iOS 细分隔线）。
  final double dividerThickness;

  const AppUiSizes({
    this.minTapSize = kMinInteractiveDimensionCupertino,
    this.compactTapSize = 32,
    this.dividerThickness = 0.5,
  });

  Size get compactTapSquare => Size.square(compactTapSize);
}
