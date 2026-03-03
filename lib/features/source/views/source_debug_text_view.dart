import 'package:flutter/cupertino.dart';

import '../../../app/theme/typography.dart';
import '../../../app/widgets/app_cupertino_page_scaffold.dart';
import '../../../app/widgets/app_nav_bar_button.dart';

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
    return AppCupertinoPageScaffold(
      title: widget.title,
      trailing: AppNavBarButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('关闭'),
      ),
      child: CupertinoScrollbar(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: SelectableRegion(
            focusNode: _focusNode,
            selectionControls: cupertinoTextSelectionControls,
            child: Text(
              widget.text,
              style: const TextStyle(
                fontFamily: AppTypography.fontFamilyMonospace,
                fontSize: 12.5,
                height: 1.25,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
