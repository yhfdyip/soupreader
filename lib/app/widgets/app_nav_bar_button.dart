import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../theme/ui_tokens.dart';

/// 导航栏按钮统一封装：收敛 padding、最小热区与常见按钮形态。
///
/// 约定：
/// - 仅用于 `CupertinoNavigationBar` / `AppCupertinoPageScaffold` 的 leading/trailing。
/// - 默认最小热区使用 `kMinInteractiveDimensionCupertino`（通过 `AppUiTokens` 统一）。
class AppNavBarButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Size? minimumSize;

  const AppNavBarButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.padding = EdgeInsets.zero,
    this.minimumSize,
  });

  @override
  Widget build(BuildContext context) {
    final ui = AppUiTokens.resolve(context);
    final resolvedMinimumSize =
        minimumSize ?? Size(ui.sizes.minTapSize, ui.sizes.minTapSize);
    final onTap = onPressed == null
        ? null
        : () {
            HapticFeedback.lightImpact();
            onPressed?.call();
          };

    return CupertinoButton(
      padding: padding,
      minimumSize: resolvedMinimumSize,
      onPressed: onTap,
      child: child,
    );
  }
}
