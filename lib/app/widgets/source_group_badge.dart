import 'package:flutter/cupertino.dart';

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
        CupertinoColors.tertiarySystemFill.resolveFrom(context);
    final resolvedTextColor =
        textColor ?? SourceUiTokens.resolveSecondaryTextColor(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: resolvedBackground,
        borderRadius: BorderRadius.circular(SourceUiTokens.radiusControl),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                fontSize: SourceUiTokens.itemSubMetaSize,
                color: resolvedTextColor,
                fontWeight: FontWeight.w600,
              ),
        ),
      ),
    );
  }
}
