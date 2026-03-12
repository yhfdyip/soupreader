import 'package:flutter/cupertino.dart';
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';

const Color _kSheetBarrierDynamicColor = CupertinoDynamicColor.withBrightness(
  color: Color(0x1A0B1630),
  darkColor: Color(0x4D000000),
);
const Color _kDialogBarrierDynamicColor = CupertinoDynamicColor.withBrightness(
  color: Color(0x3309142B),
  darkColor: Color(0x73000000),
);

/// 底部弹窗：使用 [showCupertinoModalBottomSheet] 实现 iOS 原生交互。
///
/// 支持：
/// - 无滚动内容：任意位置拖拽控制 sheet 位置，下滑松开关闭
/// - 有滚动内容：滚动到顶部时下滑接管 sheet，否则只滚动内容
/// - 标题栏始终可拖拽关闭
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
  return showCupertinoModalBottomSheet<T>(
    context: context,
    isDismissible: barrierDismissible,
    barrierColor: resolvedBarrierColor,
    backgroundColor: CupertinoColors.transparent,
    elevation: 0,
    builder: (modalContext) => CupertinoTheme(
      data: themeData,
      child: builder(modalContext),
    ),
  );
}

/// 底部对话框（Alert 风格），保持原有实现。
Future<T?> showCupertinoBottomSheetDialogAsAlert<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
}) {
  final themeData = CupertinoTheme.of(context);
  final resolvedBarrierColor = CupertinoDynamicColor.resolve(
    _kDialogBarrierDynamicColor,
    context,
  );
  return showCupertinoModalBottomSheet<T>(
    context: context,
    isDismissible: barrierDismissible,
    barrierColor: resolvedBarrierColor,
    backgroundColor: CupertinoColors.transparent,
    elevation: 0,
    builder: (modalContext) => CupertinoTheme(
      data: themeData,
      child: builder(modalContext),
    ),
  );
}
