import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../../../app/theme/ui_tokens.dart';
import '../../../app/widgets/app_cupertino_page_scaffold.dart';
import '../../../app/widgets/app_nav_bar_button.dart';
import '../../../app/widgets/app_ui_kit.dart';
import '../../../app/widgets/cupertino_bottom_dialog.dart';
import '../../../core/services/exception_log_service.dart';

String formatExceptionLogTime(int timestampMs) {
  final date = DateTime.fromMillisecondsSinceEpoch(timestampMs).toLocal();
  String two(int value) => value.toString().padLeft(2, '0');
  String three(int value) => value.toString().padLeft(3, '0');
  return '${date.year}-${two(date.month)}-${two(date.day)} '
      '${two(date.hour)}:${two(date.minute)}:${two(date.second)}.${three(date.millisecond)}';
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
      ..writeln('时间: ${formatExceptionLogTime(entry.timestampMs)}')
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
    await showCupertinoBottomDialog<void>(
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
      trailing: AppNavBarButton(
        onPressed: () => _copy(context),
        child: const Icon(CupertinoIcons.doc_on_doc),
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
        children: [
          _buildBlock(context, '时间', formatExceptionLogTime(entry.timestampMs)),
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
    final tokens = AppUiTokens.resolve(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        borderColor: tokens.colors.separator.withValues(alpha: 0.72),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: tokens.colors.secondaryLabel,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              content,
              style: TextStyle(
                fontSize: 14,
                height: 1.35,
                color: tokens.colors.label,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
