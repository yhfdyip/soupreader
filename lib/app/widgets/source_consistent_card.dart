import 'package:flutter/cupertino.dart';

import '../theme/source_ui_tokens.dart';
import 'app_squircle_surface.dart';

/// 书源页统一卡片容器。
class SourceConsistentCard extends StatelessWidget {
  static const double _kDarkSurfaceAlpha = 0.86;
  static const double _kLightSurfaceAlpha = 0.9;
  static const double _kShadowDarkAlpha = 0.22;
  static const double _kShadowLightAlpha = 0.1;

  final EdgeInsetsGeometry padding;
  final Widget child;
  final Color? backgroundColor;
  final Color? borderColor;

  const SourceConsistentCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(12),
    this.backgroundColor,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    final style = _resolveStyle(context);
    return _buildSurface(style);
  }

  _SourceCardStyle _resolveStyle(BuildContext context) {
    final theme = CupertinoTheme.of(context);
    final brightness = theme.brightness ??
        MediaQuery.maybeOf(context)?.platformBrightness ??
        Brightness.light;
    final isDark = brightness == Brightness.dark;
    final background = backgroundColor ??
        SourceUiTokens.resolveCardBackgroundColor(context).withValues(
            alpha: isDark ? _kDarkSurfaceAlpha : _kLightSurfaceAlpha);
    final border =
        (borderColor ?? SourceUiTokens.resolveSeparatorColor(context))
            .withValues(alpha: SourceUiTokens.discoveryExpandedCardBorderAlpha);
    final shadow = (isDark ? CupertinoColors.black : const Color(0xFF0A2A5E))
        .withValues(alpha: isDark ? _kShadowDarkAlpha : _kShadowLightAlpha);
    return _SourceCardStyle(
      background: background,
      border: border,
      shadow: shadow,
    );
  }

  Widget _buildSurface(_SourceCardStyle style) {
    return AppSquircleSurface(
      padding: EdgeInsets.zero,
      backgroundColor: style.background,
      borderColor: style.border,
      borderWidth: SourceUiTokens.borderWidth,
      radius: SourceUiTokens.radiusCard,
      blurBackground: true,
      shadows: <BoxShadow>[
        BoxShadow(
          color: style.shadow,
          offset: const Offset(0, 7),
          blurRadius: 20,
          spreadRadius: -11,
        ),
      ],
      child: Padding(
        padding: padding,
        child: child,
      ),
    );
  }

}

@immutable
class _SourceCardStyle {
  const _SourceCardStyle({
    required this.background,
    required this.border,
    required this.shadow,
  });

  final Color background;
  final Color border;
  final Color shadow;
}
