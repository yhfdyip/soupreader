import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../../../app/widgets/app_cupertino_page_scaffold.dart';
import '../../../core/services/exception_log_service.dart';

class ExceptionLogsView extends StatefulWidget {
  const ExceptionLogsView({super.key});

  @override
  State<ExceptionLogsView> createState() => _ExceptionLogsViewState();
}

class _ExceptionLogsViewState extends State<ExceptionLogsView> {
  final ExceptionLogService _service = ExceptionLogService();

  Future<void> _clearLogs() async {
    final confirm = await showCupertinoDialog<bool>(
          context: context,
          builder: (ctx) => CupertinoAlertDialog(
            title: const Text('清空异常日志'),
            content: const Text('\n确定清空所有异常日志吗？'),
            actions: [
              CupertinoDialogAction(
                isDestructiveAction: true,
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('清空'),
              ),
              CupertinoDialogAction(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('取消'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirm) return;
    await _service.clear();
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
    return AppCupertinoPageScaffold(
      title: '异常日志',
      trailing: CupertinoButton(
        padding: EdgeInsets.zero,
        minimumSize: const Size(30, 30),
        onPressed: _clearLogs,
        child: const Icon(CupertinoIcons.trash),
      ),
      child: ValueListenableBuilder<List<ExceptionLogEntry>>(
        valueListenable: _service.listenable,
        builder: (context, logs, _) {
          if (logs.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    CupertinoIcons.exclamationmark_triangle,
                    size: 42,
                    color: CupertinoColors.secondaryLabel.resolveFrom(context),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '暂无异常日志',
                    style: TextStyle(
                      color: CupertinoColors.secondaryLabel.resolveFrom(context),
                    ),
                  ),
                ],
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
                child: Container(
                  decoration: BoxDecoration(
                    color: CupertinoColors.systemBackground.resolveFrom(context),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: CupertinoColors.separator.resolveFrom(context),
                    ),
                  ),
                  padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 2),
                        child: Icon(
                          CupertinoIcons.exclamationmark_circle,
                          size: 18,
                          color: CupertinoColors.systemRed,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _formatTime(entry.timestampMs),
                              style: TextStyle(
                                fontSize: 12,
                                color: CupertinoColors.secondaryLabel
                                    .resolveFrom(context),
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
                                  color: CupertinoColors.systemRed
                                      .resolveFrom(context),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const Icon(
                        CupertinoIcons.chevron_right,
                        size: 14,
                        color: CupertinoColors.tertiaryLabel,
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

class ExceptionLogDetailView extends StatelessWidget {
  final ExceptionLogEntry entry;

  const ExceptionLogDetailView({
    super.key,
    required this.entry,
  });

  String _formatContext(Map<String, dynamic>? context) {
    if (context == null || context.isEmpty) return '—';
    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(context);
  }

  String _fullText() {
    final buffer = StringBuffer()
      ..writeln('时间: ${_formatTime(entry.timestampMs)}')
      ..writeln('节点: ${entry.node}')
      ..writeln('消息: ${entry.message}')
      ..writeln('错误: ${entry.error ?? '—'}')
      ..writeln('上下文: ${_formatContext(entry.context)}')
      ..writeln('堆栈:')
      ..writeln(entry.stackTrace ?? '—');
    return buffer.toString();
  }

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: _fullText()));
    if (!context.mounted) return;
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('已复制'),
        content: const Text('\n日志详情已复制到剪贴板'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('好'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppCupertinoPageScaffold(
      title: '异常详情',
      trailing: CupertinoButton(
        padding: EdgeInsets.zero,
        minimumSize: const Size(30, 30),
        onPressed: () => _copy(context),
        child: const Icon(CupertinoIcons.doc_on_doc),
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
        children: [
          _buildBlock(context, '时间', _formatTime(entry.timestampMs)),
          _buildBlock(context, '节点', entry.node),
          _buildBlock(context, '消息', entry.message),
          _buildBlock(context, '错误', entry.error ?? '—'),
          _buildBlock(context, '上下文', _formatContext(entry.context)),
          _buildBlock(context, '堆栈', entry.stackTrace ?? '—'),
        ],
      ),
    );
  }

  Widget _buildBlock(BuildContext context, String title, String content) {
    final borderColor = CupertinoColors.separator.resolveFrom(context);
    final panelColor = CupertinoColors.systemGrey6.resolveFrom(context);
    final labelColor = CupertinoColors.secondaryLabel.resolveFrom(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          color: panelColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor),
        ),
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: labelColor,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              content,
              style: const TextStyle(fontSize: 14, height: 1.35),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatTime(int timestampMs) {
  final date = DateTime.fromMillisecondsSinceEpoch(timestampMs).toLocal();
  String two(int value) => value.toString().padLeft(2, '0');
  String three(int value) => value.toString().padLeft(3, '0');
  return '${date.year}-${two(date.month)}-${two(date.day)} '
      '${two(date.hour)}:${two(date.minute)}:${two(date.second)}.${three(date.millisecond)}';
}
