import 'package:flutter/cupertino.dart';

import '../theme/design_tokens.dart';
import '../theme/ui_tokens.dart';
import 'app_squircle_surface.dart';

class AppCard extends StatelessWidget {
  static const double _kDarkSurfaceAlpha = 0.86;
  static const double _kLightSurfaceAlpha = 0.88;
  static const double _kBorderAlpha = 0.74;
  static const double _kShadowDarkAlpha = 0.22;
  static const double _kShadowLightAlpha = 0.08;

  final EdgeInsetsGeometry padding;
  final Widget child;
  final Color? backgroundColor;
  final Color? borderColor;
  final double borderWidth;
  final double? borderRadius;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(12),
    this.backgroundColor,
    this.borderColor,
    this.borderWidth = 0,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AppUiTokens.resolve(context);
    final style = _resolveStyle(tokens);
    return _buildCard(tokens, style);
  }

  _AppCardStyle _resolveStyle(AppUiTokens tokens) {
    final isDark = tokens.isDark;
    final background = backgroundColor ??
        tokens.colors.sectionBackground.withValues(
          alpha: isDark ? _kDarkSurfaceAlpha : _kLightSurfaceAlpha,
        );
    final border = (borderColor ?? tokens.colors.separator)
        .withValues(alpha: _kBorderAlpha);
    final shadow = (isDark ? CupertinoColors.black : const Color(0xFF042852))
        .withValues(alpha: isDark ? _kShadowDarkAlpha : _kShadowLightAlpha);
    return _AppCardStyle(
      background: background,
      border: border,
      shadow: shadow,
    );
  }

  Widget _buildCard(AppUiTokens tokens, _AppCardStyle style) {
    final radius = borderRadius ?? tokens.radii.card;
    final resolvedBorderWidth =
        borderWidth <= 0 ? AppDesignTokens.hairlineBorderWidth : borderWidth;
    return AppSquircleSurface(
      padding: EdgeInsets.zero,
      backgroundColor: style.background,
      borderColor: style.border,
      borderWidth: resolvedBorderWidth,
      radius: radius,
      blurBackground: true,
      shadows: <BoxShadow>[
        BoxShadow(
          color: style.shadow,
          offset: const Offset(0, 8),
          blurRadius: 24,
          spreadRadius: -12,
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
class _AppCardStyle {
  const _AppCardStyle({
    required this.background,
    required this.border,
    required this.shadow,
  });

  final Color background;
  final Color border;
  final Color shadow;
}
