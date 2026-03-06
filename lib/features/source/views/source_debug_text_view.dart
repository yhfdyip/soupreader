import 'package:flutter/cupertino.dart';

import '../../../app/theme/ui_tokens.dart';
import '../../../app/theme/typography.dart';
import '../../../app/widgets/app_cupertino_page_scaffold.dart';
import '../../../app/widgets/app_nav_bar_button.dart';
import '../../../app/widgets/app_ui_kit.dart';

class SourceDebugTextView extends StatefulWidget {
  final String title;
  final String text;

  const SourceDebugTextView({
    super.key,
    required this.title,
    required this.text,
  });

  @override
  State<SourceDebugTextView> createState() => _SourceDebugTextViewState();
}

class _SourceDebugTextViewState extends State<SourceDebugTextView> {
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
    final tokens = AppUiTokens.resolve(context);
    return AppCupertinoPageScaffold(
      title: widget.title,
      trailing: AppNavBarButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('关闭'),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
        child: AppCard(
          padding: const EdgeInsets.all(12),
          borderColor: tokens.colors.separator.withValues(alpha: 0.72),
          child: CupertinoScrollbar(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: SelectableRegion(
                focusNode: _focusNode,
                selectionControls: cupertinoTextSelectionControls,
                child: Text(
                  widget.text,
                  style: TextStyle(
                    fontFamily: AppTypography.fontFamilyMonospace,
                    fontSize: 12.5,
                    height: 1.25,
                    color: tokens.colors.label,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
