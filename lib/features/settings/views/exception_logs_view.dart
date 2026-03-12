import 'dart:async';
import 'package:flutter/cupertino.dart';

import '../../../app/theme/ui_tokens.dart';
import '../../../app/widgets/app_toast.dart';
import '../../../app/widgets/app_cupertino_page_scaffold.dart';
import '../../../app/widgets/app_nav_bar_button.dart';
import '../../../app/widgets/app_ui_kit.dart';
import '../../../app/widgets/cupertino_bottom_dialog.dart';
import '../../../core/services/exception_log_service.dart';
import 'exception_log_detail_view.dart';

class ExceptionLogsView extends StatefulWidget {
  final String title;
  final String emptyHint;

  const ExceptionLogsView({
    super.key,
    this.title = '异常日志',
    this.emptyHint = '暂无异常日志',
  });

  @override
  State<ExceptionLogsView> createState() => _ExceptionLogsViewState();
}

class _ExceptionLogsViewState extends State<ExceptionLogsView> {
  final ExceptionLogService _service = ExceptionLogService();

  Future<void> _clearLogs() async {
    final confirmed = await showCupertinoBottomSheetDialog<bool>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: const Text('清空日志'),
        content: const Text('\n确定清空全部日志吗？'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('清空'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await _service.clear();
      if (!mounted) return;
      unawaited(showAppToast(context, message: '日志已清空'));
    } catch (error) {
      if (!mounted) return;
      await _showMessage('清空失败：$error');
    }
  }

  Future<void> _showMessage(String message) async {
    await showCupertinoBottomSheetDialog<void>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: const Text('提示'),
        content: Text('\n$message'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('好'),
          ),
        ],
      ),
    );
  }

  void _openDetail(ExceptionLogEntry entry) {
    Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (_) => ExceptionLogDetailView(entry: entry),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AppUiTokens.resolve(context);
    return AppCupertinoPageScaffold(
      title: widget.title,
      trailing: AppNavBarButton(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        onPressed: _clearLogs,
        child: const Text('清除'),
      ),
      child: ValueListenableBuilder<List<ExceptionLogEntry>>(
        valueListenable: _service.listenable,
        builder: (context, logs, _) {
          if (logs.isEmpty) {
            return Center(
              child: Text(
                widget.emptyHint,
                style: TextStyle(
                  fontSize: 14,
                  color: tokens.colors.secondaryLabel,
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
            itemCount: logs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final entry = logs[index];
              return GestureDetector(
                onTap: () => _openDetail(entry),
                child: AppCard(
                  padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
                  borderColor: tokens.colors.separator.withValues(alpha: 0.72),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Icon(
                          CupertinoIcons.exclamationmark_circle,
                          size: 18,
                          color: tokens.colors.destructive,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              formatExceptionLogTime(entry.timestampMs),
                              style: TextStyle(
                                fontSize: 12,
                                color: tokens.colors.secondaryLabel,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              entry.node,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              entry.message,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 14),
                            ),
                            if (entry.error != null &&
                                entry.error!.trim().isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                entry.error!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: tokens.colors.destructive,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      Icon(
                        CupertinoIcons.chevron_right,
                        size: 14,
                        color: tokens.colors.tertiaryLabel,
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
