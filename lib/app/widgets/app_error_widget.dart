import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../theme/design_tokens.dart';
import 'app_squircle_surface.dart';
import 'cupertino_bottom_dialog.dart';

/// 在 Release 模式下，Flutter 默认的 ErrorWidget 往往只是一块灰色区域，
/// 导致真正在构建期发生的异常无法被用户感知与回传。
///
/// 该组件用于把异常信息直接渲染到屏幕上，方便截图/复制定位根因。
class AppErrorWidget extends StatelessWidget {
  final String title;
  final String message;
  final String? stackTrace;

  const AppErrorWidget({
    super.key,
    this.title = '页面异常',
    required this.message,
    this.stackTrace,
  });

  String _payload() {
    final parts = <String>[
      message.trim(),
      if ((stackTrace ?? '').trim().isNotEmpty) '\n$stackTrace',
    ];
    return parts.join('\n').trim();
  }

  @override
  Widget build(BuildContext context) {
    final payload = _payload();
    final isDark =
        (CupertinoTheme.of(context).brightness ?? Brightness.light) ==
            Brightness.dark;
    final panelColor = isDark
        ? AppDesignTokens.glassDarkMaterial.withValues(alpha: 0.88)
        : AppDesignTokens.glassLightMaterial.withValues(alpha: 0.9);
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemBackground.resolveFrom(context),
      navigationBar: CupertinoNavigationBar(
        middle: Text(title),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            const Text(
              '发生了构建期异常（Release 下默认会显示灰屏）。\n'
              '请点击“复制”并把内容发我。',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 12),
            CupertinoButton.filled(
              onPressed: () async {
                HapticFeedback.lightImpact();
                await Clipboard.setData(ClipboardData(text: payload));
                if (!context.mounted) return;
                await showCupertinoBottomDialog<void>(
                  context: context,
                  builder: (ctx) => CupertinoAlertDialog(
                    title: const Text('已复制'),
                    content: const Text('异常信息已复制到剪贴板。'),
                    actions: [
                      CupertinoDialogAction(
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: const Text('好'),
                      ),
                    ],
                  ),
                );
              },
              child: const Text('复制异常信息'),
            ),
            const SizedBox(height: 12),
            AppSquircleSurface(
              padding: const EdgeInsets.all(12),
              backgroundColor: panelColor,
              borderColor: CupertinoColors.separator
                  .resolveFrom(context)
                  .withValues(alpha: 0.72),
              radius: AppDesignTokens.radiusCard,
              borderWidth: AppDesignTokens.hairlineBorderWidth,
              blurBackground: true,
              child: Text(
                payload,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.35,
                  color: CupertinoColors.label.resolveFrom(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
