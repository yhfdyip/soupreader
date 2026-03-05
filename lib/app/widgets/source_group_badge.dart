import 'package:flutter/cupertino.dart';

import '../theme/design_tokens.dart';
import '../theme/source_ui_tokens.dart';
import 'app_squircle_surface.dart';

/// 书源分组标签（统一外观）。
class SourceGroupBadge extends StatelessWidget {
  static const double _kDarkBackgroundAlpha = 0.68;
  static const double _kLightBackgroundAlpha = 0.74;
  static const double _kBorderAlpha = 0.78;
  static const double _kBezelAlpha = 0.5;
  static const double _kShadowDarkAlpha = 0.18;
  static const double _kShadowLightAlpha = 0.08;

  final String text;
  final Color? textColor;
  final Color? backgroundColor;

  const SourceGroupBadge({
    super.key,
    required this.text,
    this.textColor,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final style = _resolveStyle(context);
    return AppSquircleSurface(
      padding: EdgeInsets.zero,
      backgroundColor: style.background,
      borderColor: style.border,
      borderWidth: AppDesignTokens.hairlineBorderWidth,
      radius: SourceUiTokens.radiusControl,
      blurBackground: true,
      shadows: [
        BoxShadow(
          color: style.shadow,
          offset: const Offset(0, 4),
          blurRadius: 10,
          spreadRadius: -6,
        ),
      ],
      child: Stack(
        children: [
          Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              height: AppDesignTokens.hairlineBorderWidth,
              child: ColoredBox(color: style.bezel),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                    fontSize: SourceUiTokens.itemSubMetaSize,
                    color: style.text,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.2,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  _SourceGroupBadgeStyle _resolveStyle(BuildContext context) {
    final theme = CupertinoTheme.of(context);
    final brightness = theme.brightness ??
        MediaQuery.maybeOf(context)?.platformBrightness ??
        Brightness.light;
    final isDark = brightness == Brightness.dark;
    final background = backgroundColor ??
        CupertinoColors.tertiarySystemFill.resolveFrom(context).withValues(
              alpha: isDark ? _kDarkBackgroundAlpha : _kLightBackgroundAlpha,
            );
    final text = textColor ?? SourceUiTokens.resolveSecondaryTextColor(context);
    final border = CupertinoColors.separator
        .resolveFrom(context)
        .withValues(alpha: _kBorderAlpha);
    final bezel = (isDark
            ? AppDesignTokens.glassInnerHighlightDark
            : AppDesignTokens.glassInnerHighlightLight)
        .withValues(alpha: _kBezelAlpha);
    final shadow = (isDark ? CupertinoColors.black : const Color(0xFF0A2A5E))
        .withValues(alpha: isDark ? _kShadowDarkAlpha : _kShadowLightAlpha);
    return _SourceGroupBadgeStyle(
      background: background,
      text: text,
      border: border,
      bezel: bezel,
      shadow: shadow,
    );
  }
}

@immutable
class _SourceGroupBadgeStyle {
  const _SourceGroupBadgeStyle({
    required this.background,
    required this.text,
    required this.border,
    required this.bezel,
    required this.shadow,
  });

  final Color background;
  final Color text;
  final Color border;
  final Color bezel;
  final Color shadow;
}
