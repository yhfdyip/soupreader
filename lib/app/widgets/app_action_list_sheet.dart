import 'package:flutter/cupertino.dart';

/// iOS 原生风格 Action Sheet 封装。
///
/// 所有调用方通过 [showAppActionListSheet] 弹出，内部使用 [CupertinoActionSheet]。
class AppActionListItem<T> {
  final T value;
  final IconData icon;
  final String label;
  final bool enabled;
  final bool isDestructiveAction;

  const AppActionListItem({
    required this.value,
    required this.icon,
    required this.label,
    this.enabled = true,
    this.isDestructiveAction = false,
  });
}

Future<T?> showAppActionListSheet<T>({
  required BuildContext context,
  required String title,
  String? message,
  required List<AppActionListItem<T>> items,
  String cancelText = '取消',
  TextAlign titleAlign = TextAlign.left,
  bool showCancel = false,
  bool barrierDismissible = true,
  Color? accentColor,
}) {
  return showCupertinoModalPopup<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    builder: (ctx) {
      final trimmedMessage = (message ?? '').trim();
      return CupertinoActionSheet(
        title: Text(title),
        message: trimmedMessage.isNotEmpty ? Text(trimmedMessage) : null,
        actions: items.map((item) {
          return CupertinoActionSheetAction(
            isDestructiveAction: item.isDestructiveAction,
            onPressed: item.enabled
                ? () => Navigator.of(ctx).pop(item.value)
                : () {},
            child: Opacity(
              opacity: item.enabled ? 1.0 : 0.4,
              child: Text(item.label),
            ),
          );
        }).toList(),
        cancelButton: showCancel
            ? CupertinoActionSheetAction(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text(cancelText),
              )
            : null,
      );
    },
  );
}
