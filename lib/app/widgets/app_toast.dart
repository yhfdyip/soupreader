import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';

import '../theme/design_tokens.dart';

/// 展示底部悬浮 toast 提示，自动在指定时长后消失。
///
/// 通过 [showAppToast] 触发，不需要手动管理 overlay。
Future<void> showAppToast(
  BuildContext context, {
  required String message,
  Duration duration = const Duration(milliseconds: 1800),
}) {
  final overlay = Overlay.of(context);
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _AppToastOverlay(
      message: message,
      duration: duration,
      onDismiss: () => entry.remove(),
    ),
  );
  overlay.insert(entry);
  return Future<void>.delayed(duration + const Duration(milliseconds: 200));
}

class _AppToastOverlay extends StatefulWidget {
  final String message;
  final Duration duration;
  final VoidCallback onDismiss;

  const _AppToastOverlay({
    required this.message,
    required this.duration,
    required this.onDismiss,
  });

  @override
  State<_AppToastOverlay> createState() => _AppToastOverlayState();
}

class _AppToastOverlayState extends State<_AppToastOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );
    _opacity = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _controller.forward();
    Future.delayed(widget.duration, _dismiss);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _dismiss() async {
    if (!mounted) return;
    await _controller.reverse();
    widget.onDismiss();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: MediaQuery.paddingOf(context).bottom + 28,
      left: 0,
      right: 0,
      child: SafeArea(
        top: false,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: FadeTransition(
            opacity: _opacity,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppDesignTokens.radiusToast),
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: CupertinoColors.systemBackground.resolveFrom(context)
                        .resolveFrom(context)
                        .withValues(alpha: 0.82),
                    borderRadius:
                        BorderRadius.circular(AppDesignTokens.radiusToast),
                  ),
                  child: Text(
                    widget.message,
                    style: TextStyle(
                      color: CupertinoColors.label.resolveFrom(context),
                      fontSize: 13,
                    ),
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
