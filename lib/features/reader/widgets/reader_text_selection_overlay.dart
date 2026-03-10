import 'package:flutter/cupertino.dart';

/// 正文选区高亮覆盖层：绘制高亮矩形、拖拽手柄、操作菜单。
class ReaderTextSelectionOverlay extends StatefulWidget {
  const ReaderTextSelectionOverlay({
    super.key,
    required this.selectionRects,
    required this.startHandlePos,
    required this.endHandlePos,
    required this.selectedText,
    required this.highlightColor,
    required this.handleColor,
    required this.onDismiss,
    required this.onStartHandleDragUpdate,
    required this.onEndHandleDragUpdate,
    required this.onHandleDragEnd,
    this.onCopy,
    this.onBookmark,
    this.onReadAloud,
    this.onDict,
    this.onSearchContent,
    this.onShare,
  });

  final List<Rect> selectionRects;
  final Offset startHandlePos;
  final Offset endHandlePos;
  final String selectedText;
  final Color highlightColor;
  final Color handleColor;
  final VoidCallback onDismiss;
  final ValueChanged<Offset> onStartHandleDragUpdate;
  final ValueChanged<Offset> onEndHandleDragUpdate;
  final VoidCallback onHandleDragEnd;
  final VoidCallback? onCopy;
  final VoidCallback? onBookmark;
  final VoidCallback? onReadAloud;
  final VoidCallback? onDict;
  final VoidCallback? onSearchContent;
  final VoidCallback? onShare;

  @override
  State<ReaderTextSelectionOverlay> createState() =>
      ReaderTextSelectionOverlayState();
}

class ReaderTextSelectionOverlayState
    extends State<ReaderTextSelectionOverlay> {
  bool _menuVisible = false;

  static const double _handleRadius = 6.0;
  static const double _handleHitSize = 44.0;

  void _showMenu() {
    setState(() => _menuVisible = true);
  }

  void _hideMenu() {
    setState(() => _menuVisible = false);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 点击空白区域取消选区
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: widget.onDismiss,
          ),
        ),
        // 高亮矩形
        Positioned.fill(
          child: CustomPaint(
            painter: _SelectionHighlightPainter(
              rects: widget.selectionRects,
              color: widget.highlightColor,
            ),
          ),
        ),
        // 起始手柄
        _buildHandle(
          pos: widget.startHandlePos,
          isStart: true,
        ),
        // 结束手柄
        _buildHandle(
          pos: widget.endHandlePos,
          isStart: false,
        ),
        // 操作菜单
        if (_menuVisible) _buildMenu(context),
      ],
    );
  }

  Widget _buildHandle({
    required Offset pos,
    required bool isStart,
  }) {
    return Positioned(
      left: pos.dx - _handleHitSize / 2,
      top: pos.dy - _handleHitSize / 2,
      width: _handleHitSize,
      height: _handleHitSize,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {}, // 消耗点击事件，防止触发底层 onDismiss
        onPanUpdate: (details) {
          if (isStart) {
            widget.onStartHandleDragUpdate(details.globalPosition);
          } else {
            widget.onEndHandleDragUpdate(details.globalPosition);
          }
        },
        onPanEnd: (_) => widget.onHandleDragEnd(),
        child: Center(
          child: Container(
            width: _handleRadius * 2,
            height: _handleRadius * 2,
            decoration: BoxDecoration(
              color: widget.handleColor,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: widget.handleColor.withValues(alpha: 0.3),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMenu(BuildContext context) {
    final rects = widget.selectionRects;
    if (rects.isEmpty) return const SizedBox.shrink();

    // 菜单显示在选区上方居中
    final firstRect = rects.first;
    final lastRect = rects.last;
    final centerX = (firstRect.left + lastRect.right) / 2;
    final topY = firstRect.top - 8;

    final items = <_MenuAction>[
      if (widget.onCopy != null)
        _MenuAction('复制', CupertinoIcons.doc_on_doc, widget.onCopy!),
      if (widget.onBookmark != null)
        _MenuAction('书签', CupertinoIcons.bookmark, widget.onBookmark!),
      if (widget.onReadAloud != null)
        _MenuAction('朗读', CupertinoIcons.speaker_2, widget.onReadAloud!),
      if (widget.onDict != null)
        _MenuAction('查词', CupertinoIcons.book, widget.onDict!),
      if (widget.onSearchContent != null)
        _MenuAction('书内搜索', CupertinoIcons.search, widget.onSearchContent!),
      if (widget.onShare != null)
        _MenuAction('分享', CupertinoIcons.share, widget.onShare!),
    ];

    if (items.isEmpty) return const SizedBox.shrink();

    const menuWidth = 260.0;
    const menuHeight = 44.0;
    final screenSize = MediaQuery.sizeOf(context);
    final menuLeft = (centerX - menuWidth / 2).clamp(8.0, screenSize.width - menuWidth - 8.0);
    // 优先显示在选区上方，空间不足时显示在选区下方
    final topAbove = topY - menuHeight - 4;
    final topBelow = lastRect.bottom + 8;
    final menuTop = topAbove >= 8.0 ? topAbove : topBelow.clamp(8.0, screenSize.height - menuHeight - 8.0);

    return Positioned(
      left: menuLeft,
      top: menuTop,
      width: menuWidth,
      child: _SelectionMenu(
        items: items,
        onDismiss: _hideMenu,
      ),
    );
  }

  void showMenu() => _showMenu();
}

class _MenuAction {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _MenuAction(this.label, this.icon, this.onTap);
}

class _SelectionMenu extends StatelessWidget {
  const _SelectionMenu({
    required this.items,
    required this.onDismiss,
  });

  final List<_MenuAction> items;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;
    final bg = isDark
        ? const Color(0xFF2C2C2E)
        : CupertinoColors.white;
    final textColor = isDark
        ? CupertinoColors.white
        : CupertinoColors.label.resolveFrom(context);

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: CupertinoColors.black.withValues(alpha: 0.18),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: items.asMap().entries.map((entry) {
            final item = entry.value;
            return Expanded(
              child: CupertinoButton(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                onPressed: () {
                  onDismiss();
                  item.onTap();
                },
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(item.icon, size: 16, color: textColor),
                    const SizedBox(height: 2),
                    Text(
                      item.label,
                      style: TextStyle(
                        fontSize: 10,
                        color: textColor,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _SelectionHighlightPainter extends CustomPainter {
  const _SelectionHighlightPainter({
    required this.rects,
    required this.color,
  });

  final List<Rect> rects;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    for (final rect in rects) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(2)),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SelectionHighlightPainter old) =>
      old.rects != rects || old.color != color;
}
