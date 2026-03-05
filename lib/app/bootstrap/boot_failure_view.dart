import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../widgets/app_squircle_surface.dart';
import '../widgets/cupertino_bottom_dialog.dart';
import '../../app/theme/design_tokens.dart';
import '../../core/build/build_info.dart';
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
      ..writeln(
        'build: ref=${BuildInfo.gitRef} sha=${BuildInfo.gitSha} '
        'build=${BuildInfo.buildNumber} '
        '${BuildInfo.isRelease ? 'release' : 'debug'}',
      )
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
    final isDark =
        (CupertinoTheme.of(context).brightness ?? Brightness.light) ==
            Brightness.dark;
    final pageBackground =
        isDark ? AppDesignTokens.pageBgDark : AppDesignTokens.pageBgLight;

    return CupertinoPageScaffold(
      backgroundColor: pageBackground,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: (isDark
                ? AppDesignTokens.glassDarkMaterial
                : AppDesignTokens.glassLightMaterial)
            .withValues(alpha: 0.9),
        middle: const Text('启动异常'),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
          children: [
            _buildBuildInfo(context),
            const SizedBox(height: 14),
            _buildFailureCard(context, isDark),
            const SizedBox(height: 18),
            CupertinoButton.filled(
              onPressed: retrying ? null : onRetry,
              child: Text(retrying ? '重试中…' : '重试初始化'),
            ),
            const SizedBox(height: 10),
            CupertinoButton(
              onPressed: () => _copyPayload(context),
              child: const Text('复制启动日志'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBuildInfo(BuildContext context) {
    return Text(
      'ref=${BuildInfo.gitRef}  sha=${BuildInfo.gitShaShort}  '
      'build=${BuildInfo.buildNumber}  '
      '${BuildInfo.isRelease ? 'release' : 'debug'}',
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: CupertinoColors.secondaryLabel.resolveFrom(context),
      ),
    );
  }

  Widget _buildFailureCard(BuildContext context, bool isDark) {
    final panelColor = (isDark
            ? AppDesignTokens.glassDarkMaterial
            : AppDesignTokens.glassLightMaterial)
        .withValues(alpha: isDark ? 0.9 : 0.92);
    return AppSquircleSurface(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      backgroundColor: panelColor,
      borderColor: CupertinoColors.separator.resolveFrom(context).withValues(
            alpha: 0.72,
          ),
      radius: AppDesignTokens.radiusCard,
      borderWidth: AppDesignTokens.hairlineBorderWidth,
      blurBackground: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '应用初始化失败，已阻止进入主界面以避免后续导入/书源管理出现连锁异常。',
            style: TextStyle(
              fontSize: 14,
              height: 1.35,
              color: CupertinoColors.label.resolveFrom(context),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '失败步骤：${failure.stepName}\n错误：${failure.error}',
            style: TextStyle(
              fontSize: 12,
              height: 1.4,
              color: CupertinoColors.secondaryLabel.resolveFrom(context),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _copyPayload(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: _payload()));
    if (!context.mounted) return;
    await showCupertinoBottomDialog<void>(
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
  }
}
