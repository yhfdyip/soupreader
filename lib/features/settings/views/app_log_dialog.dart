import 'dart:math' as math;

import 'package:flutter/cupertino.dart';

import '../../../app/theme/ui_tokens.dart';
import '../../../app/widgets/app_card.dart';
import '../../../app/widgets/app_sheet_panel.dart';
import '../../../app/widgets/cupertino_bottom_dialog.dart';
import '../../../core/services/exception_log_service.dart';

Future<void> showAppLogDialog(BuildContext context) {
  return showCupertinoBottomDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (_) => const _AppLogDialog(),
  );
}

class _AppLogDialog extends StatelessWidget {
  static const double _kWidthFactor = 0.92;
  static const double _kHeightFactor = 0.78;
  static const double _kMaxWidth = 560;
  static const double _kMaxHeight = 640;

  const _AppLogDialog();

  @override
  Widget build(BuildContext context) {
    final service = ExceptionLogService();
    final ui = AppUiTokens.resolve(context);
    final screenSize = MediaQuery.sizeOf(context);
    final width = math.min(screenSize.width * _kWidthFactor, _kMaxWidth);
    final height = math.min(screenSize.height * _kHeightFactor, _kMaxHeight);
    final separator = ui.colors.separator.withValues(alpha: 0.78);

    return Center(
      child: SizedBox(
        width: width,
        height: height,
        child: AppSheetPanel(
          contentPadding: EdgeInsets.zero,
          radius: ui.radii.sheet,
          child: SafeArea(
            bottom: false,
            child: Column(
              children: [
                _AppLogHeader(onClear: service.clear),
                Container(height: ui.sizes.dividerThickness, color: separator),
                Expanded(
                  child: ValueListenableBuilder<List<ExceptionLogEntry>>(
                    valueListenable: service.listenable,
                    builder: (context, logs, _) => _AppLogList(logs: logs),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AppLogHeader extends StatelessWidget {
  final VoidCallback onClear;

  const _AppLogHeader({required this.onClear});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 8),
      child: Row(
        children: [
          const SizedBox(width: 48),
          const Expanded(
            child: Text(
              '日志',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            onPressed: onClear,
            minimumSize: const Size(30, 30),
            child: const Text('清除'),
          ),
        ],
      ),
    );
  }
}

class _AppLogList extends StatelessWidget {
  final List<ExceptionLogEntry> logs;

  const _AppLogList({required this.logs});

  @override
  Widget build(BuildContext context) {
    if (logs.isEmpty) {
      return const SizedBox.shrink();
    }

    return ListView.separated(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
      itemCount: logs.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) => _AppLogTile(entry: logs[index]),
    );
  }
}

class _AppLogTile extends StatelessWidget {
  final ExceptionLogEntry entry;

  const _AppLogTile({required this.entry});

  Future<void> _showStackTrace(BuildContext context) async {
    final stack = entry.stackTrace?.trim() ?? '';
    if (stack.isEmpty) return;
    await showCupertinoBottomDialog<void>(
      context: context,
      builder: (_) => _AppLogStackTraceDialog(stackTrace: stack),
    );
  }

  @override
  Widget build(BuildContext context) {
    final secondaryLabel = CupertinoColors.secondaryLabel.resolveFrom(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _showStackTrace(context),
      child: AppCard(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 9),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _formatTime(entry.timestampMs),
              style: TextStyle(
                fontSize: 12,
                color: secondaryLabel,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              entry.message,
              style: const TextStyle(fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}

class _AppLogStackTraceDialog extends StatelessWidget {
  static const double _kWidthFactor = 0.9;
  static const double _kHeightFactor = 0.72;
  static const double _kMaxWidth = 760;
  static const double _kMaxHeight = 560;

  final String stackTrace;

  const _AppLogStackTraceDialog({required this.stackTrace});

  @override
  Widget build(BuildContext context) {
    final ui = AppUiTokens.resolve(context);
    final screenSize = MediaQuery.sizeOf(context);
    final width = math.min(screenSize.width * _kWidthFactor, _kMaxWidth);
    final height = math.min(screenSize.height * _kHeightFactor, _kMaxHeight);
    final separator = ui.colors.separator.withValues(alpha: 0.78);

    return Center(
      child: SizedBox(
        width: width,
        height: height,
        child: AppSheetPanel(
          contentPadding: EdgeInsets.zero,
          radius: ui.radii.sheet,
          child: SafeArea(
            bottom: false,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 8, 8),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          '日志堆栈',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ),
                      CupertinoButton(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        onPressed: () => Navigator.of(context).pop(),
                        minimumSize: const Size(30, 30),
                        child: const Text('关闭'),
                      ),
                    ],
                  ),
                ),
                Container(height: ui.sizes.dividerThickness, color: separator),
                Expanded(
                  child: CupertinoScrollbar(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
                      child: Text(
                        stackTrace,
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.4,
                          color: ui.colors.label,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
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
