import 'package:flutter/cupertino.dart';
import '../widgets/app_squircle_surface.dart';
import '../../app/theme/design_tokens.dart';
import 'boot_action_text.dart';
import 'boot_build_info_label.dart';
import 'boot_failure_payload.dart';
import 'app_bootstrap.dart';
import 'boot_copy_feedback.dart';

/// 展示应用启动失败信息，并允许用户复制日志或重试。
class BootFailureView extends StatelessWidget {
  /// 启动失败详情。
  final BootFailure failure;

  /// 当前是否处于重试中。
  final bool retrying;

  /// 点击重试按钮时触发的回调。
  final VoidCallback onRetry;

  /// 启动过程中的附加日志文本。
  final String bootLog;

  const BootFailureView({
    super.key,
    required this.failure,
    required this.retrying,
    required this.onRetry,
    required this.bootLog,
  });

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
            const BootBuildInfoLabel(),
            const SizedBox(height: 14),
            _buildFailureCard(context),
            const SizedBox(height: 18),
            CupertinoButton.filled(
              onPressed: retrying ? null : onRetry,
              child: Text(retrying ? bootRetryingLabel : bootRetryLabel),
            ),
            const SizedBox(height: 10),
            CupertinoButton(
              onPressed: () => _copyPayload(context),
              child: const Text(bootCopyLogLabel),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFailureCard(BuildContext context) {
    final panelColor =
        CupertinoColors.secondarySystemGroupedBackground.resolveFrom(context);
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

  Future<void> _copyPayload(BuildContext context) {
    return copyTextWithFeedback(
      context,
      text: buildBootFailurePayload(
        failure: failure,
        bootLog: bootLog,
      ),
      successMessage: bootFailureCopiedMessage,
    );
  }
}
