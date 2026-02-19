import 'package:flutter/cupertino.dart';

import 'settings_ui_tokens.dart';

class SettingsPlaceholders {
  static void showNotImplemented(BuildContext context, {String? title}) {
    final raw = title ?? '该功能暂未实现';
    final normalized = SettingsUiTokens.normalizePlannedText(raw);

    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('扩展阶段'),
        content: Text('\n$normalized'),
        actions: [
          CupertinoDialogAction(
            child: const Text('好'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }
}
