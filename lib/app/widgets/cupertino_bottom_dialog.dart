import 'package:flutter/cupertino.dart';

const Color _kSheetBarrierDynamicColor = CupertinoDynamicColor.withBrightness(
  color: Color(0x1A0B1630),
  darkColor: Color(0x4D000000),
);
const Color _kDialogBarrierDynamicColor = CupertinoDynamicColor.withBrightness(
  color: Color(0x3309142B),
  darkColor: Color(0x73000000),
);

/// 下滑速度阈值（px/s），超过此值触发关闭。
const double _kDismissVelocityThreshold = 600.0;

Future<T?> showCupertinoBottomSheetDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
  Color? barrierColor,
}) {
  final themeData = CupertinoTheme.of(context);
  final resolvedBarrierColor = CupertinoDynamicColor.resolve(
    barrierColor ?? _kSheetBarrierDynamicColor,
    context,
  );
  return showCupertinoModalPopup<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierColor: resolvedBarrierColor,
    builder: (popupContext) => CupertinoTheme(
      data: themeData,
      child: _SwipeDownToDismiss(child: builder(popupContext)),
    ),
  );
}

/// 包装 bottom sheet 内容，支持下滑快速关闭。
///
/// 使用 [HitTestBehavior.translucent]，内部滚动组件不受影响。
/// 当下滑速度超过阈值时调用 [Navigator.pop]。
class _SwipeDownToDismiss extends StatelessWidget {
  final Widget child;

  const _SwipeDownToDismiss({required this.child});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onVerticalDragEnd: (details) {
        final velocity = details.primaryVelocity ?? 0;
        if (velocity > _kDismissVelocityThreshold) {
          Navigator.of(context).pop();
        }
      },
      child: child,
    );
  }
}

Future<T?> showCupertinoBottomDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = false,
  String? barrierLabel,
  Color? barrierColor,
  bool useRootNavigator = true,
  RouteSettings? routeSettings,
}) {
  final themeData = CupertinoTheme.of(context);
  final probeContext =
      Navigator.of(context, rootNavigator: useRootNavigator).context;
  final probeWidget = builder(probeContext);

  Widget themedBuilder(BuildContext popupContext) {
    return CupertinoTheme(
      data: themeData,
      child: builder(popupContext),
    );
  }

  if (probeWidget is CupertinoActionSheet) {
    final resolvedBarrierColor = barrierColor ?? _kSheetBarrierDynamicColor;
    final resolvedBarrierLabel = barrierLabel ??
        CupertinoLocalizations.of(context).modalBarrierDismissLabel;

    return Navigator.of(context, rootNavigator: useRootNavigator).push<T>(
      CupertinoModalPopupRoute<T>(
        builder: themedBuilder,
        barrierColor:
            CupertinoDynamicColor.resolve(resolvedBarrierColor, context),
        barrierDismissible: barrierDismissible,
        semanticsDismissible: barrierDismissible,
        settings: routeSettings,
        barrierLabel: resolvedBarrierLabel,
      ),
    );
  }

  return showCupertinoDialog<T>(
    context: context,
    builder: themedBuilder,
    barrierDismissible: barrierDismissible,
    barrierLabel: barrierLabel,
    barrierColor: barrierColor ?? _kDialogBarrierDynamicColor,
    useRootNavigator: useRootNavigator,
    routeSettings: routeSettings,
  );
}
