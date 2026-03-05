import 'package:flutter/cupertino.dart';

import '../theme/design_tokens.dart';
import '../theme/source_ui_tokens.dart';

/// 书源分组标签（统一外观）。
class SourceGroupBadge extends StatelessWidget {
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
    final resolvedBackground = backgroundColor ??
        CupertinoColors.tertiarySystemFill
            .resolveFrom(context)
            .withValues(alpha: 0.72);
    final resolvedTextColor =
        textColor ?? SourceUiTokens.resolveSecondaryTextColor(context);
    final borderColor =
        CupertinoColors.separator.resolveFrom(context).withValues(alpha: 0.78);

    return DecoratedBox(
      decoration: ShapeDecoration(
        color: resolvedBackground,
        shape: ContinuousRectangleBorder(
          borderRadius: BorderRadius.all(
            Radius.circular(SourceUiTokens.radiusControl),
          ),
          side: BorderSide(
            color: borderColor,
            width: AppDesignTokens.hairlineBorderWidth,
          ),
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
                color: resolvedTextColor,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.2,
              ),
        ),
      ),
    );
  }
}
