import 'package:flutter/cupertino.dart';

Future<T?> showCupertinoBottomSheetDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
  Color? barrierColor,
}) {
  final themeData = CupertinoTheme.of(context);
  return showCupertinoModalPopup<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierColor: barrierColor ?? kCupertinoModalBarrierColor,
    builder: (popupContext) => CupertinoTheme(
      data: themeData,
      child: builder(popupContext),
    ),
  );
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
    final resolvedBarrierColor = barrierColor ?? kCupertinoModalBarrierColor;
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
    barrierColor: barrierColor,
    useRootNavigator: useRootNavigator,
    routeSettings: routeSettings,
  );
}
