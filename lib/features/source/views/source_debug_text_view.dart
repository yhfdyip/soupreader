import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

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
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text(widget.title),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: widget.text));
            if (!context.mounted) return;
            showCupertinoDialog(
              context: context,
              builder: (dialogContext) => CupertinoAlertDialog(
                title: const Text('提示'),
                content: const Text('\n已复制到剪贴板'),
                actions: [
                  CupertinoDialogAction(
                    child: const Text('好'),
                    onPressed: () => Navigator.pop(dialogContext),
                  ),
                ],
              ),
            );
          },
          child: const Text('复制'),
        ),
      ),
      child: SafeArea(
        child: CupertinoScrollbar(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: SelectableRegion(
              focusNode: _focusNode,
              selectionControls: cupertinoTextSelectionControls,
              child: Text(
                widget.text,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12.5,
                  height: 1.25,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
