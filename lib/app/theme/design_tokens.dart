import 'package:flutter/cupertino.dart';

/// 全局设计令牌：用于统一品牌、语义色、节奏与交互时长。
class AppDesignTokens {
  AppDesignTokens._();

  // ===== 品牌色（全局仅一套主语义） =====
  static const Color brandPrimary = Color(0xFF0A84FF);
  static const Color brandSecondary = Color(0xFF64D2FF);
  static const Color cta = Color(0xFF30D158);

  // ===== 功能语义色 =====
  static const Color success = Color(0xFF34C759);
  static const Color warning = Color(0xFFFF9F0A);
  static const Color error = Color(0xFFFF3B30);
  static const Color info = Color(0xFF0A84FF);

  // ===== 中性色（UI 管理页） =====
  static const Color textStrong = Color(0xFF15171C);
  static const Color textNormal = Color(0xFF2C3442);
  static const Color textMuted = Color(0xFF6D7482);
  static const Color textInverse = Color(0xFFEFF2FF);

  static const Color pageBgLight = Color(0xFFF2F2F7); // iOS systemGroupedBackground
  static const Color pageBgDark = Color(0xFF1C1C1E); // iOS systemGroupedBackground dark
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color surfaceDark = Color(0xFF2C2C2E); // iOS secondarySystemBackground dark

  static const Color borderLight = Color(0xFFC6C6C8); // iOS separator light
  static const Color borderDark = Color(0xFF38383A); // iOS separator dark
  static const Color dividerLight = Color(0xFFC6C6C8);
  static const Color dividerDark = Color(0xFF38383A);

  // ===== 玻璃材质 =====
  static const Color glassLightMaterial = Color(0x99FFFFFF);
  static const Color glassDarkMaterial = Color(0x991C1C1E);
  static const Color glassInnerHighlightLight = Color(0x66FFFFFF);
  static const Color glassInnerHighlightDark = Color(0x33FFFFFF);
  static const Color ambientTopLight = Color(0x66B3DBFF);
  static const Color ambientBottomLight = Color(0x4D8FE7D9);
  static const Color ambientTopDark = Color(0x404A8CFF);
  static const Color ambientBottomDark = Color(0x3356D8BA);

  // ===== 统一几何 =====
  static const double radiusControl = 10;
  static const double radiusCard = 13; // iOS insetGrouped section radius
  static const double radiusPopup = 14;
  static const double radiusSheet = 13; // iOS action sheet radius
  static const double hairlineBorderWidth = 0.5;
  static const double glassBlurSigma = 20;

  // ===== 统一动效节奏 =====
  static const Duration motionQuick = Duration(milliseconds: 150);
  static const Duration motionNormal = Duration(milliseconds: 220);
  static const Duration motionPageTurn = Duration(milliseconds: 300);
  static const Duration motionSpring = Duration(milliseconds: 420);
}

/// 阅读菜单与浮层的统一色板（对标 legado「正文优先」配色语义）。
class ReaderOverlayTokens {
  ReaderOverlayTokens._();

  // 夜间：弱化纯黑穿透感，减少多层透明叠加导致的噪点。
  static const Color panelDark = Color(0xFF17191D);
  static const Color cardDark = Color(0xFF24272C);
  static const Color borderDark = Color(0xFF3B414A);
  static const Color textStrongDark = Color(0xFFE8ECF2);
  static const Color textNormalDark = Color(0xFFB7C0CC);
  static const Color textSubtleDark = Color(0xFF929CAA);

  // 日间：拉开正文与操作层层级，避免“整屏泛白”。
  static const Color panelLight = Color(0xFFFFFFFF);
  static const Color cardLight = Color(0xFFF4F6FA);
  static const Color borderLight = Color(0xFFD7DEE8);
  static const Color textStrongLight = Color(0xFF1F2328);
  static const Color textNormalLight = Color(0xFF5C6773);
  static const Color textSubtleLight = Color(0xFF7A8592);
}

/// 阅读主题令牌：用于沉浸式阅读页面的核心颜色语义。
class ReaderThemeToken {
  final String name;
  final Color background;
  final Color text;
  final Color subText;
  final Color divider;
  final Color accent;

  const ReaderThemeToken({
    required this.name,
    required this.background,
    required this.text,
    required this.subText,
    required this.divider,
    required this.accent,
  });
}

/// 阅读主题主轴 + 协调扩展。
class ReaderThemeTokens {
  ReaderThemeTokens._();

  // ===== 三主轴（推荐） =====

  /// 纸墨沉浸（日间）
  static const ReaderThemeToken day = ReaderThemeToken(
    name: '日间',
    background: Color(0xFFF7F4EE),
    text: Color(0xFF1F2328),
    subText: Color(0xFF5C6773),
    divider: Color(0xFFDFE4EA),
    accent: AppDesignTokens.brandPrimary,
  );

  /// 夜航纯黑（夜间）
  static const ReaderThemeToken night = ReaderThemeToken(
    name: '夜间',
    background: Color(0xFF000000),
    text: Color(0xFFADADAD),
    subText: Color(0xFF8A94A0),
    divider: Color(0xFF2F3440),
    accent: AppDesignTokens.brandSecondary,
  );

  /// 自然护眼（护眼）
  static const ReaderThemeToken sepia = ReaderThemeToken(
    name: '护眼',
    background: Color(0xFFFFF8E1),
    text: Color(0xFF3E2723),
    subText: Color(0xFF5D4037),
    divider: Color(0xFFEED9B7),
    accent: Color(0xFF2E7D32),
  );

  // ===== 协调扩展（保持现有主题数量与习惯） =====
  static const ReaderThemeToken ink = ReaderThemeToken(
    name: '墨水',
    background: Color(0xFFF5F5F5),
    text: Color(0xFF1F2937),
    subText: Color(0xFF4B5563),
    divider: Color(0xFFDADADA),
    accent: AppDesignTokens.brandPrimary,
  );

  static const ReaderThemeToken midnight = ReaderThemeToken(
    name: '深蓝',
    background: Color(0xFF0A0E27),
    text: Color(0xFFCCCCCC),
    subText: Color(0xFF9CA3AF),
    divider: Color(0xFF1F2937),
    accent: AppDesignTokens.brandSecondary,
  );

  static const ReaderThemeToken cream = ReaderThemeToken(
    name: '奶酪',
    background: Color(0xFFFFF8E1),
    text: Color(0xFF3E2723),
    subText: Color(0xFF6D4C41),
    divider: Color(0xFFF1E1B7),
    accent: Color(0xFF8D6E63),
  );

  static const ReaderThemeToken mint = ReaderThemeToken(
    name: '薄荷',
    background: Color(0xFFE0F2F1),
    text: Color(0xFF004D40),
    subText: Color(0xFF2E7D73),
    divider: Color(0xFFB2DFDB),
    accent: Color(0xFF00695C),
  );

  static const ReaderThemeToken rose = ReaderThemeToken(
    name: '玫瑰',
    background: Color(0xFFFCE4EC),
    text: Color(0xFF880E4F),
    subText: Color(0xFFAD1457),
    divider: Color(0xFFF8BBD0),
    accent: Color(0xFFC2185B),
  );

  static const ReaderThemeToken amoled = ReaderThemeToken(
    name: '纯黑',
    background: Color(0xFF000000),
    text: Color(0xFFADADAD),
    subText: Color(0xFF6B7280),
    divider: Color(0xFF1F1F1F),
    accent: AppDesignTokens.brandSecondary,
  );

  /// Legado 默认首套主题（微信读书纸色）
  static const ReaderThemeToken legadoClassic = ReaderThemeToken(
    name: '经典纸色',
    background: Color(0xFFC0EDC6),
    text: Color(0xFF0B0B0B),
    subText: Color(0xFF3E3D3B),
    divider: Color(0xFF9FD8AE),
    accent: Color(0xFF2E7D32),
  );

  static const List<ReaderThemeToken> core = [day, sepia, night];

  /// 保持既有主题顺序，避免 `themeIndex` 历史数据失配。
  static const List<ReaderThemeToken> all = [
    day,
    night,
    sepia,
    ink,
    midnight,
    cream,
    mint,
    rose,
    amoled,
    legadoClassic,
  ];
}

/// 阅读设置页与阅读设置弹层统一视觉令牌。
class ReaderSettingsTokens {
  ReaderSettingsTokens._();

  static const double sectionRadius = 14;
  static const double sectionTitleSize = 13;
  static const double rowTitleSize = 14;
  static const double rowMetaSize = 12;

  static Color sheetBackground({required bool isDark}) {
    return isDark
        ? const Color(0xFF1B1D21)
        : AppDesignTokens.surfaceLight.withValues(alpha: 0.98);
  }

  static Color sectionBackground({required bool isDark}) {
    return isDark
        ? CupertinoColors.white.withValues(alpha: 0.1)
        : AppDesignTokens.surfaceLight.withValues(alpha: 0.9);
  }

  static Color sectionBorder({required bool isDark}) {
    return isDark
        ? CupertinoColors.white.withValues(alpha: 0.14)
        : AppDesignTokens.borderLight;
  }

  static Color titleColor({required bool isDark}) {
    return isDark
        ? CupertinoColors.white.withValues(alpha: 0.64)
        : AppDesignTokens.textMuted;
  }

  static Color rowTitleColor({required bool isDark}) {
    return isDark ? CupertinoColors.white : AppDesignTokens.textStrong;
  }

  static Color rowMetaColor({required bool isDark}) {
    return isDark
        ? CupertinoColors.white.withValues(alpha: 0.72)
        : AppDesignTokens.textNormal;
  }

  static Color accent({required bool isDark}) {
    return isDark
        ? AppDesignTokens.brandSecondary
        : AppDesignTokens.brandPrimary;
  }
}
