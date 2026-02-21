import 'dart:math' as math;

import 'package:flutter/cupertino.dart';

Future<void> showAppHelpDialog(
  BuildContext context, {
  required String markdownText,
}) {
  return showCupertinoDialog<void>(
    context: context,
    builder: (_) => _AppHelpDialog(markdownText: markdownText),
  );
}

class _AppHelpDialog extends StatelessWidget {
  final String markdownText;

  const _AppHelpDialog({required this.markdownText});

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.sizeOf(context);
    final width = math.min(screenSize.width * 0.92, 680.0);
    final height = math.min(screenSize.height * 0.82, 760.0);
    final separator = CupertinoColors.separator.resolveFrom(context);
    final bodyColor = CupertinoColors.label.resolveFrom(context);

    return Center(
      child: CupertinoPopupSurface(
        child: SizedBox(
          width: width,
          height: height,
          child: CupertinoPageScaffold(
            backgroundColor:
                CupertinoColors.systemBackground.resolveFrom(context),
            child: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 8, 8),
                    child: Row(
                      children: [
                        const SizedBox(width: 34),
                        const Expanded(
                          child: Text(
                            '帮助',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        CupertinoButton(
                          padding: const EdgeInsets.all(4),
                          minSize: 30,
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Icon(CupertinoIcons.xmark),
                        ),
                      ],
                    ),
                  ),
                  Container(height: 0.5, color: separator),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(14, 10, 14, 18),
                      child: Text(
                        markdownText,
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.48,
                          color: bodyColor,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
