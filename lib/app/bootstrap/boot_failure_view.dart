import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import 'app_bootstrap.dart';

class BootFailureView extends StatelessWidget {
  final BootFailure failure;
  final bool retrying;
  final VoidCallback onRetry;
  final String bootLog;

  const BootFailureView({
    super.key,
    required this.failure,
    required this.retrying,
    required this.onRetry,
    required this.bootLog,
  });

  String _payload() {
    final out = StringBuffer()
      ..writeln('BootFailure')
      ..writeln('step=${failure.stepName}')
      ..writeln('error=${failure.error}')
      ..writeln('')
      ..writeln('stack:')
      ..writeln(failure.stack.toString());
    if (bootLog.trim().isNotEmpty) {
      out
        ..writeln('')
        ..writeln('boot_log:')
        ..writeln(bootLog.trim());
    }
    return out.toString().trim();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('启动异常'),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
          children: [
            const Text(
              '应用初始化失败，已阻止进入主界面以避免后续导入/书源管理出现连锁异常。',
              style: TextStyle(fontSize: 15),
            ),
            const SizedBox(height: 14),
            Text(
              '失败步骤：${failure.stepName}\n错误：${failure.error}',
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 20),
            CupertinoButton.filled(
              onPressed: retrying ? null : onRetry,
              child: Text(retrying ? '重试中…' : '重试初始化'),
            ),
            const SizedBox(height: 10),
            CupertinoButton(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: _payload()));
                if (!context.mounted) return;
                await showCupertinoDialog<void>(
                  context: context,
                  builder: (ctx) => CupertinoAlertDialog(
                    title: const Text('已复制'),
                    content: const Text('启动失败信息已复制到剪贴板。'),
                    actions: [
                      CupertinoDialogAction(
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: const Text('好'),
                      ),
                    ],
                  ),
                );
              },
              child: const Text('复制启动日志'),
            ),
          ],
        ),
      ),
    );
  }
}

