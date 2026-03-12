import 'dart:math' as math;

import 'package:flutter/cupertino.dart';

import '../../../app/theme/ui_tokens.dart';
import '../../../app/widgets/app_sheet_panel.dart';
import '../../../app/widgets/cupertino_bottom_dialog.dart';

Future<void> showAppHelpDialog(
  BuildContext context, {
  required String markdownText,
  String title = '帮助',
}) {
  return showCupertinoBottomSheetDialog<void>(
    context: context,
    builder: (_) => _AppHelpDialog(
      title: title,
      markdownText: markdownText,
    ),
  );
}

class _AppHelpDialog extends StatefulWidget {
  final String title;
  final String markdownText;

  const _AppHelpDialog({
    required this.title,
    required this.markdownText,
  });

  @override
  State<_AppHelpDialog> createState() => _AppHelpDialogState();
}

class _AppHelpDialogState extends State<_AppHelpDialog> {
  static const double _kWidthFactor = 0.92;
  static const double _kHeightFactor = 0.82;
  static const double _kMaxWidth = 680;
  static const double _kMaxHeight = 760;

  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.sizeOf(context);
    final width = math.min(screenSize.width * _kWidthFactor, _kMaxWidth);
    final height = math.min(screenSize.height * _kHeightFactor, _kMaxHeight);

    return Center(
      child: SizedBox(
        width: width,
        height: height,
        child: _HelpDialogBody(
          title: widget.title,
          markdownText: widget.markdownText,
          focusNode: _focusNode,
        ),
      ),
    );
  }
}

class _HelpDialogBody extends StatelessWidget {
  final String title;
  final String markdownText;
  final FocusNode focusNode;

  const _HelpDialogBody({
    required this.title,
    required this.markdownText,
    required this.focusNode,
  });

  @override
  Widget build(BuildContext context) {
    final ui = AppUiTokens.resolve(context);
    final separator = ui.colors.separator.withValues(alpha: 0.78);
    final text = markdownText.trim();

    return AppSheetPanel(
      contentPadding: EdgeInsets.zero,
      radius: ui.radii.sheet,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _HelpDialogHeader(title: title),
            Container(height: ui.sizes.dividerThickness, color: separator),
            Expanded(
              child: CupertinoScrollbar(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 18),
                  child: SelectableRegion(
                    focusNode: focusNode,
                    selectionControls: cupertinoTextSelectionControls,
                    child: Text(
                      text.isEmpty ? '暂无内容' : markdownText,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.48,
                        color: ui.colors.label,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HelpDialogHeader extends StatelessWidget {
  final String title;

  const _HelpDialogHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 8),
      child: Row(
        children: [
          const SizedBox(width: 48),
          Expanded(
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
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
    );
  }
}
