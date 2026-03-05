import 'package:flutter/cupertino.dart';

const Color _kSheetBarrierDynamicColor = CupertinoDynamicColor.withBrightness(
  color: Color(0x1A0B1630),
  darkColor: Color(0x4D000000),
);
const Color _kDialogBarrierDynamicColor = CupertinoDynamicColor.withBrightness(
  color: Color(0x3309142B),
  darkColor: Color(0x73000000),
);

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
