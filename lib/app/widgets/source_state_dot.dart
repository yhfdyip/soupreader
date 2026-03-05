import 'package:flutter/cupertino.dart';

import '../theme/source_ui_tokens.dart';

/// 书源状态圆点（启用/禁用）。
class SourceStateDot extends StatelessWidget {
  static const double _dotSize = 8;
  static const double _ringSize = 12;

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
    final color = enabled ? activeColor : inactiveColor;
    final ringColor = color.withValues(alpha: enabled ? 0.22 : 0.12);

    return SizedBox(
      width: _ringSize,
      height: _ringSize,
      child: Center(
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: ringColor,
                blurRadius: 6,
                spreadRadius: 1,
              ),
            ],
          ),
          child: SizedBox(
            width: _dotSize,
            height: _dotSize,
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
