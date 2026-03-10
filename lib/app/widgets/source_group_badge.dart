import 'package:flutter/cupertino.dart';

import '../theme/design_tokens.dart';
import '../theme/source_ui_tokens.dart';

/// 书源分组标签（统一外观）。
class SourceGroupBadge extends StatelessWidget {
  static const double _kDarkBackgroundAlpha = 0.68;
  static const double _kLightBackgroundAlpha = 0.74;
  static const double _kBorderAlpha = 0.78;

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
    return DecoratedBox(
      decoration: BoxDecoration(
        color: style.background,
        borderRadius: BorderRadius.circular(SourceUiTokens.radiusControl),
        border: Border.all(
          color: style.border,
          width: AppDesignTokens.hairlineBorderWidth,
        ),
      ),
      child: Padding(
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
    final border = CupertinoColors.separator.resolveFrom(context)
        .withValues(alpha: _kBorderAlpha);
    return _SourceGroupBadgeStyle(
      background: background,
      text: text,
      border: border,
    );
  }
}

@immutable
class _SourceGroupBadgeStyle {
  const _SourceGroupBadgeStyle({
    required this.background,
    required this.text,
    required this.border,
  });

  final Color background;
  final Color text;
  final Color border;
}
