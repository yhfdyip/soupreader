import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../../../app/widgets/app_nav_bar_button.dart';
import '../../../app/widgets/cupertino_bottom_dialog.dart';
import '../../../core/services/exception_log_service.dart';

class ReaderContentEditPayload {
  final String title;
  final String content;

  const ReaderContentEditPayload({
    required this.title,
    required this.content,
  });
}

class ReaderContentEditorPage extends StatefulWidget {
  final String initialTitle;
  final String initialContent;
  final Future<String> Function()? onResetContent;

  const ReaderContentEditorPage({
    super.key,
    required this.initialTitle,
    required this.initialContent,
    this.onResetContent,
  });

  @override
  State<ReaderContentEditorPage> createState() =>
      ReaderContentEditorPageState();
}

class ReaderContentEditorPageState extends State<ReaderContentEditorPage> {
  late final TextEditingController _titleController;
  late final TextEditingController _contentController;
  bool _returned = false;
  bool _resetting = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.initialTitle);
    _contentController = TextEditingController(text: widget.initialContent);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  void _popWithPayload() {
    if (_returned || _resetting) return;
    _returned = true;
    Navigator.of(context).pop(
      ReaderContentEditPayload(
        title: _titleController.text,
        content: _contentController.text,
      ),
    );
  }

  Future<void> _copyAll() async {
    final payload = '${_titleController.text}\n${_contentController.text}';
    try {
      await Clipboard.setData(ClipboardData(text: payload));
    } catch (error, stackTrace) {
      ExceptionLogService().record(
        node: 'reader.menu.content_edit.copy_all.failed',
        message: '拷贝所有失败',
        error: error,
        stackTrace: stackTrace,
        context: <String, dynamic>{
          'payloadLength': payload.length,
        },
      );
      return;
    }
    if (!mounted) return;
    _showCopyToast('已拷贝');
  }

  void _showCopyToast(String message) {
    if (!mounted) return;
    showCupertinoBottomSheetDialog<void>(
      context: context,
      barrierColor: CupertinoColors.black.withValues(alpha: 0.08),
      builder: (toastContext) {
        final navigator = Navigator.of(toastContext);
        unawaited(Future<void>.delayed(const Duration(milliseconds: 1100), () {
          if (navigator.mounted && navigator.canPop()) {
            navigator.pop();
          }
        }));
        return SafeArea(
          top: false,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 28),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                  decoration: BoxDecoration(
                    color: CupertinoColors.systemBackground
                        .resolveFrom(context)
                        .withValues(alpha: 0.82),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    message,
                    style: TextStyle(
                      color: CupertinoColors.label.resolveFrom(context),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _moveContentCursorToEnd() {
    _contentController.selection = TextSelection.fromPosition(
      TextPosition(offset: _contentController.text.length),
    );
  }

  Future<void> _resetContent() async {
    if (_resetting) return;
    final handler = widget.onResetContent;
    if (handler == null) {
      _contentController.text = widget.initialContent;
      _moveContentCursorToEnd();
      return;
    }
    setState(() {
      _resetting = true;
    });
    try {
      final content = await handler();
      if (!mounted) return;
      _contentController.text = content;
      _moveContentCursorToEnd();
    } catch (_) {
      // 对齐 legado：重置失败时保持当前编辑内容并静默返回。
    } finally {
      if (!mounted) return;
      setState(() {
        _resetting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop || _resetting) return;
        _popWithPayload();
      },
      child: CupertinoPageScaffold(
        navigationBar: CupertinoNavigationBar(
          middle: const Text('编辑正文'),
          automaticallyImplyLeading: false,
          leading: AppNavBarButton(
            onPressed: _resetting ? null : _popWithPayload,
            child: const Text('关闭'),
          ),
          trailing: AppNavBarButton(
            onPressed: _resetting ? null : _popWithPayload,
            child: const Text('保存'),
          ),
        ),
        child: SafeArea(
          top: false,
          child: Stack(
            fit: StackFit.expand,
            children: [
              IgnorePointer(
                ignoring: _resetting,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
                  child: Column(
                    children: [
                      CupertinoTextField(
                        controller: _titleController,
                        placeholder: '章节标题',
                        enabled: !_resetting,
                        clearButtonMode: OverlayVisibilityMode.editing,
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          CupertinoButton(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            onPressed: _resetting ? null : _resetContent,
                            child: const Text('重置'),
                          ),
                          const SizedBox(width: 8),
                          CupertinoButton(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            onPressed: _resetting ? null : _copyAll,
                            child: const Text('复制全文'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: CupertinoColors.systemBackground.resolveFrom(
                              context,
                            ),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: CupertinoColors.systemGrey4
                                  .resolveFrom(context),
                              width: 0.8,
                            ),
                          ),
                          child: CupertinoTextField(
                            controller: _contentController,
                            enabled: !_resetting,
                            maxLines: null,
                            expands: true,
                            keyboardType: TextInputType.multiline,
                            textAlignVertical: TextAlignVertical.top,
                            clearButtonMode: OverlayVisibilityMode.never,
                            padding: const EdgeInsets.all(12),
                            decoration: null,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (_resetting)
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: CupertinoColors.systemBackground
                          .resolveFrom(context)
                          .withValues(alpha: 0.78),
                    ),
                    child: const Center(
                      child: CupertinoActivityIndicator(radius: 14),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}


