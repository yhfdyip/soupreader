import 'dart:async';

import 'package:flutter/cupertino.dart';

import '../widgets/app_card.dart';
import '../../app/theme/design_tokens.dart';
import '../../core/build/build_info.dart';

class BootingProgressView extends StatelessWidget {
  static const EdgeInsets _kPagePadding = EdgeInsets.fromLTRB(20, 24, 20, 24);
  static const EdgeInsets _kCardPadding = EdgeInsets.fromLTRB(16, 16, 16, 16);
  static const EdgeInsets _kLogCardPadding =
      EdgeInsets.fromLTRB(12, 12, 12, 12);

  final String step;
  final double elapsedSeconds;
  final String latestLogLine;
  final String bootLogTail;
  final bool hasLogs;
  final Future<void> Function(BuildContext context) onCopyLog;

  const BootingProgressView({
    super.key,
    required this.step,
    required this.elapsedSeconds,
    required this.latestLogLine,
    required this.bootLogTail,
    required this.hasLogs,
    required this.onCopyLog,
  });

  @override
  Widget build(BuildContext context) {
    final muted = CupertinoColors.secondaryLabel.resolveFrom(context);
    final tertiary = CupertinoColors.tertiaryLabel.resolveFrom(context);

    return CupertinoPageScaffold(
      child: SafeArea(
        child: ListView(
          padding: _kPagePadding,
          children: [
            _buildBuildInfo(context, muted),
            const SizedBox(height: 12),
            _buildStatusCard(context, muted, tertiary),
            if (hasLogs) ...[
              const SizedBox(height: 12),
              CupertinoButton.filled(
                onPressed: () => unawaited(onCopyLog(context)),
                child: const Text('复制启动日志'),
              ),
              const SizedBox(height: 10),
              _buildLogCard(context),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBuildInfo(BuildContext context, Color color) {
    return Text(
      'BOOT HOST  ref=${BuildInfo.gitRef}  '
      'sha=${BuildInfo.gitShaShort}  '
      'build=${BuildInfo.buildNumber}  '
      '${BuildInfo.isRelease ? 'release' : 'debug'}',
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: color,
      ),
    );
  }

  Widget _buildStatusCard(
    BuildContext context,
    Color muted,
    Color tertiary,
  ) {
    return AppCard(
      padding: _kCardPadding,
      borderRadius: AppDesignTokens.radiusCard,
      child: Column(
        children: [
          const CupertinoActivityIndicator(),
          const SizedBox(height: 12),
          Text(
            '正在初始化…',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: CupertinoColors.label.resolveFrom(context),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '步骤：$step',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: muted),
          ),
          const SizedBox(height: 6),
          if (latestLogLine.isNotEmpty)
            Text(
              '最新：$latestLogLine',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: tertiary),
            ),
          const SizedBox(height: 6),
          Text(
            '已用时：${elapsedSeconds.toStringAsFixed(0)}s',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: tertiary),
          ),
        ],
      ),
    );
  }

  Widget _buildLogCard(BuildContext context) {
    return AppCard(
      padding: _kLogCardPadding,
      borderRadius: AppDesignTokens.radiusControl,
      child: Text(
        bootLogTail,
        style: TextStyle(
          fontSize: 11,
          height: 1.35,
          color: CupertinoColors.label.resolveFrom(context),
        ),
      ),
    );
  }
}
