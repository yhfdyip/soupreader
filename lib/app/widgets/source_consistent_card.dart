import 'package:flutter/cupertino.dart';

import '../theme/source_ui_tokens.dart';

/// 书源页统一卡片容器。
class SourceConsistentCard extends StatelessWidget {
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
    final resolvedBackground =
        backgroundColor ?? SourceUiTokens.resolveCardBackgroundColor(context);
    final resolvedBorder =
        borderColor ?? SourceUiTokens.resolveSeparatorColor(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: resolvedBackground,
        borderRadius: BorderRadius.circular(SourceUiTokens.radiusCard),
        border: Border.all(
          color: resolvedBorder,
          width: SourceUiTokens.borderWidth,
        ),
      ),
      child: Padding(
        padding: padding,
        child: child,
      ),
    );
  }
}
