import 'package:flutter/cupertino.dart';

import '../theme/source_ui_tokens.dart';

/// 书源状态圆点（启用/禁用）。
class SourceStateDot extends StatelessWidget {
  final bool enabled;
  final Color? enabledColor;
  final Color? disabledColor;

  const SourceStateDot({
    super.key,
    required this.enabled,
    this.enabledColor,
    this.disabledColor,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor =
        enabledColor ?? SourceUiTokens.resolveSuccessColor(context);
    final inactiveColor =
        disabledColor ?? SourceUiTokens.resolveMutedTextColor(context);

    return Container(
      width: 7,
      height: 7,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: enabled ? activeColor : inactiveColor,
      ),
    );
  }
}
