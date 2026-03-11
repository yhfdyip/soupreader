import 'package:flutter/cupertino.dart';

import '../theme/ui_tokens.dart';
import 'app_squircle_surface.dart';

class AppSheetPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry contentPadding;
  final double? radius;

  const AppSheetPanel({
    super.key,
    required this.child,
    required this.contentPadding,
    this.radius,
  });

  @override
  Widget build(BuildContext context) {
    final ui = AppUiTokens.resolve(context);
    // iOS 17 原生 sheet 风格：纯色背景，无毛玻璃。
    return AppSquircleSurface(
      padding: EdgeInsets.zero,
      backgroundColor: ui.colors.groupedBackground,
      borderColor: CupertinoColors.transparent,
      borderWidth: 0,
      radius: radius ?? ui.radii.sheet,
      blurBackground: false,
      child: Padding(
        padding: contentPadding,
        child: child,
      ),
    );
  }
}
