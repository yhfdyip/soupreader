import 'dart:ui';

/// 全局设计令牌：用于统一品牌、语义色、节奏与交互时长。
class AppDesignTokens {
  AppDesignTokens._();

  // ===== 品牌色（全局仅一套主语义） =====
  static const Color brandPrimary = Color(0xFF0369A1);
  static const Color brandSecondary = Color(0xFF38BDF8);
  static const Color cta = Color(0xFF22C55E);

  // ===== 功能语义色 =====
  static const Color success = Color(0xFF16A34A);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF0EA5E9);

  // ===== 中性色（UI 管理页） =====
  static const Color textStrong = Color(0xFF0F172A);
  static const Color textNormal = Color(0xFF334155);
  static const Color textMuted = Color(0xFF64748B);
  static const Color textInverse = Color(0xFFE2E8F0);

  static const Color pageBgLight = Color(0xFFF8FAFC);
  static const Color pageBgDark = Color(0xFF121212);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color surfaceDark = Color(0xFF1E1E1E);

  static const Color borderLight = Color(0xFFE2E8F0);
  static const Color borderDark = Color(0xFF333333);
  static const Color dividerLight = Color(0xFFEEEEEE);
  static const Color dividerDark = Color(0xFF2A2A2A);

  // ===== 统一圆角 =====
  static const double radiusControl = 8;
  static const double radiusCard = 12;
  static const double radiusPopup = 16;

  // ===== 统一动效节奏 =====
  static const Duration motionQuick = Duration(milliseconds: 150);
  static const Duration motionNormal = Duration(milliseconds: 220);
  static const Duration motionPageTurn = Duration(milliseconds: 300);
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
