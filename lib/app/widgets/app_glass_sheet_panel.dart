import 'package:flutter/cupertino.dart';

import '../theme/design_tokens.dart';
import '../theme/ui_tokens.dart';
import 'app_squircle_surface.dart';

class AppGlassSheetPanel extends StatelessWidget {
  // iOS Action Sheet 背景透明度，配合系统毛玻璃模糊。
  static const double _kBackgroundAlpha = 0.94;

  final Widget child;
  final EdgeInsetsGeometry contentPadding;
  final double? radius;

  const AppGlassSheetPanel({
    super.key,
    required this.child,
    required this.contentPadding,
    this.radius,
  });

  @override
  Widget build(BuildContext context) {
    final ui = AppUiTokens.resolve(context);
    // 使用系统 secondarySystemBackground（浅色白色，深色深灰），与原生 sheet 一致。
    final background = ui.colors.surfaceBackground.withValues(alpha: _kBackgroundAlpha);
    final border = ui.colors.separator;
    return AppSquircleSurface(
      padding: EdgeInsets.zero,
      backgroundColor: background,
      borderColor: border,
      borderWidth: AppDesignTokens.hairlineBorderWidth,
      radius: radius ?? ui.radii.sheet,
      blurBackground: true,
      child: Padding(
        padding: contentPadding,
        child: child,
      ),
    );
  }
}
