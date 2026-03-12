import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../widgets/cupertino_bottom_dialog.dart';

/// 复制文本后展示统一的成功提示弹窗。
///
/// `text` 为写入剪贴板的内容，`successMessage` 为复制成功后的提示文案。
Future<void> copyTextWithFeedback(
  BuildContext context, {
  required String text,
  required String successMessage,
}) async {
  await Clipboard.setData(ClipboardData(text: text));
  if (!context.mounted) return;
  await showCupertinoBottomSheetDialog<void>(
    context: context,
    builder: (dialogContext) => CupertinoAlertDialog(
      title: const Text('已复制'),
      content: Text(successMessage),
      actions: [
        CupertinoDialogAction(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('好'),
        ),
      ],
    ),
  );
}
