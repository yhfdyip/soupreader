import 'dart:collection';

import 'package:flutter/material.dart';

import 'scroll_text_layout_engine.dart';

class ScrollSegmentPaintView extends StatelessWidget {
  final ScrollTextLayout layout;
  final TextStyle style;

  const ScrollSegmentPaintView({
    super.key,
    required this.layout,
    required this.style,
  });

  @override
  Widget build(BuildContext context) {
    final safeHeight = layout.bodyHeight <= 0 ? 1.0 : layout.bodyHeight;
    return RepaintBoundary(
      child: SizedBox(
        width: double.infinity,
        height: safeHeight,
        child: CustomPaint(
          isComplex: true,
          willChange: false,
          painter: _ScrollTextLayoutPainter(
            layout: layout,
            style: style,
          ),
        ),
      ),
    );
  }
}

class _ScrollTextLayoutPainter extends CustomPainter {
  final ScrollTextLayout layout;
  final TextStyle style;

  _ScrollTextLayoutPainter({
    required this.layout,
    required this.style,
  });

  static const int _maxPainterCacheEntries = 4096;
  static final LinkedHashMap<String, TextPainter> _textPainterCache =
      LinkedHashMap<String, TextPainter>();

  @override
  void paint(Canvas canvas, Size size) {
    if (layout.lines.isEmpty) {
      return;
    }

    var clipBounds = canvas.getLocalClipBounds();
    if (!clipBounds.isFinite) {
      clipBounds = Offset.zero & size;
    }
    final visibleTop =
        (clipBounds.top - 2.0).clamp(0.0, size.height).toDouble();
    final visibleBottom =
        (clipBounds.bottom + 2.0).clamp(0.0, size.height).toDouble();
    if (visibleBottom <= visibleTop) {
      return;
    }

    canvas.save();
    canvas.clipRect(Offset.zero & size);

    var lineIndex = _findFirstVisibleLineIndex(visibleTop);
    while (lineIndex < layout.lines.length) {
      final line = layout.lines[lineIndex];
      var x = 0.0;
      final y = line.y;
      if (y > visibleBottom) {
        break;
      }
      if (y + line.height >= visibleTop) {
        for (final run in line.runs) {
          if (run.text.isNotEmpty) {
            final painter = _painterFor(run.text);
            painter.paint(canvas, Offset(x, y));
          }
          x += run.width + run.extraAfter;
        }
      }
      lineIndex++;
    }

    canvas.restore();
  }

  int _findFirstVisibleLineIndex(double visibleTop) {
    var low = 0;
    var high = layout.lines.length - 1;
    var answer = layout.lines.length;
    while (low <= high) {
      final mid = low + ((high - low) >> 1);
      final line = layout.lines[mid];
      final lineBottom = line.y + line.height;
      if (lineBottom >= visibleTop) {
        answer = mid;
        high = mid - 1;
      } else {
        low = mid + 1;
      }
    }
    if (answer >= layout.lines.length) {
      return layout.lines.length;
    }
    return answer;
  }

  TextPainter _painterFor(String text) {
    final key = '${style.hashCode}|$text';
    final cached = _textPainterCache[key];
    if (cached != null) {
      _textPainterCache.remove(key);
      _textPainterCache[key] = cached;
      return cached;
    }

    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout(minWidth: 0, maxWidth: double.infinity);

    _textPainterCache[key] = painter;
    while (_textPainterCache.length > _maxPainterCacheEntries) {
      _textPainterCache.remove(_textPainterCache.keys.first);
    }
    return painter;
  }

  @override
  bool shouldRepaint(covariant _ScrollTextLayoutPainter oldDelegate) {
    return oldDelegate.layout.key != layout.key || oldDelegate.style != style;
  }
}
