import 'package:flutter/cupertino.dart';

enum ScrollStepReason {
  preserveLine,
  fallbackViewport,
}

class ScrollStepResult {
  final double step;
  final ScrollStepReason reason;

  const ScrollStepResult({
    required this.step,
    required this.reason,
  });
}

class ScrollLineFrame {
  final double top;
  final double bottom;

  const ScrollLineFrame({
    required this.top,
    required this.bottom,
  });

  double get height => (bottom - top).clamp(0.0, double.infinity);
}

class ScrollLayoutSnapshot {
  final List<ScrollLineFrame> lines;
  final double contentHeight;
  final double estimatedLineHeight;

  const ScrollLayoutSnapshot({
    required this.lines,
    required this.contentHeight,
    required this.estimatedLineHeight,
  });

  const ScrollLayoutSnapshot.empty()
      : lines = const [],
        contentHeight = 0,
        estimatedLineHeight = 0;

  bool get hasLines => lines.isNotEmpty;
}

class ScrollPageStepCalculator {
  const ScrollPageStepCalculator._();

  static ScrollLayoutSnapshot buildLayoutSnapshot({
    required String title,
    required String content,
    required bool showTitle,
    required double maxWidth,
    required double paddingTop,
    required double paddingBottom,
    required double paragraphSpacing,
    required double titleTopSpacing,
    required double titleBottomSpacing,
    required double trailingSpacing,
    required TextStyle paragraphStyle,
    required TextStyle titleStyle,
    required TextAlign paragraphTextAlign,
    required TextAlign titleTextAlign,
  }) {
    if (maxWidth <= 1) {
      return const ScrollLayoutSnapshot.empty();
    }

    final lines = <ScrollLineFrame>[];
    var cursorY = paddingTop.clamp(0.0, double.infinity).toDouble();
    var lineHeightTotal = 0.0;
    var lineCount = 0;

    if (showTitle && title.trim().isNotEmpty) {
      cursorY += titleTopSpacing.clamp(0.0, double.infinity);
      cursorY = _appendTextLines(
        text: title,
        style: titleStyle,
        textAlign: titleTextAlign,
        maxWidth: maxWidth,
        startY: cursorY,
        output: lines,
      );
      cursorY += titleBottomSpacing.clamp(0.0, double.infinity);
    }

    final paragraphs = content.split(RegExp(r'\n\s*\n|\n'));
    for (final paragraph in paragraphs) {
      final paragraphText = paragraph.trimRight();
      if (paragraphText.trim().isEmpty) {
        continue;
      }
      final beforeCount = lines.length;
      cursorY = _appendTextLines(
        text: paragraphText,
        style: paragraphStyle,
        textAlign: paragraphTextAlign,
        maxWidth: maxWidth,
        startY: cursorY,
        output: lines,
      );
      final newLines = lines.length - beforeCount;
      if (newLines > 0) {
        for (var i = lines.length - newLines; i < lines.length; i++) {
          lineHeightTotal += lines[i].height;
        }
        lineCount += newLines;
      }
      cursorY += paragraphSpacing.clamp(0.0, double.infinity);
    }

    cursorY += paddingBottom.clamp(0.0, double.infinity);
    cursorY += trailingSpacing.clamp(0.0, double.infinity);

    final estimated = lineCount == 0 ? 0.0 : lineHeightTotal / lineCount;
    return ScrollLayoutSnapshot(
      lines: lines,
      contentHeight: cursorY,
      estimatedLineHeight: estimated,
    );
  }

  static ScrollStepResult computeNextStep({
    required ScrollLayoutSnapshot snapshot,
    required double visibleTop,
    required double viewportHeight,
  }) {
    return _computeStep(
      snapshot: snapshot,
      visibleTop: visibleTop,
      viewportHeight: viewportHeight,
      next: true,
    );
  }

  static ScrollStepResult computePrevStep({
    required ScrollLayoutSnapshot snapshot,
    required double visibleTop,
    required double viewportHeight,
  }) {
    return _computeStep(
      snapshot: snapshot,
      visibleTop: visibleTop,
      viewportHeight: viewportHeight,
      next: false,
    );
  }

  static ScrollStepResult _computeStep({
    required ScrollLayoutSnapshot snapshot,
    required double visibleTop,
    required double viewportHeight,
    required bool next,
  }) {
    final safeViewport = viewportHeight.clamp(1.0, double.infinity).toDouble();
    final visibleBottom = visibleTop + safeViewport;
    final fallback = _fallbackStep(
      viewportHeight: safeViewport,
      estimatedLineHeight: snapshot.estimatedLineHeight,
    );

    if (!snapshot.hasLines) {
      return ScrollStepResult(
        step: safeViewport,
        reason: ScrollStepReason.fallbackViewport,
      );
    }

    ScrollLineFrame? anchor;
    if (next) {
      for (var i = snapshot.lines.length - 1; i >= 0; i--) {
        final line = snapshot.lines[i];
        if (_isVisible(line, visibleTop, visibleBottom)) {
          anchor = line;
          break;
        }
      }
    } else {
      for (final line in snapshot.lines) {
        if (_isVisible(line, visibleTop, visibleBottom)) {
          anchor = line;
          break;
        }
      }
    }

    if (anchor == null) {
      return ScrollStepResult(
        step: safeViewport,
        reason: ScrollStepReason.fallbackViewport,
      );
    }

    final rawStep =
        next ? anchor.top - visibleTop : visibleBottom - anchor.bottom;
    final normalized = rawStep.clamp(0.0, safeViewport).toDouble();
    if (normalized <= 1.0) {
      return ScrollStepResult(
        step: fallback,
        reason: ScrollStepReason.fallbackViewport,
      );
    }

    return ScrollStepResult(
      step: normalized,
      reason: ScrollStepReason.preserveLine,
    );
  }

  static bool _isVisible(ScrollLineFrame line, double top, double bottom) {
    return line.bottom > top && line.top < bottom;
  }

  static double _fallbackStep({
    required double viewportHeight,
    required double estimatedLineHeight,
  }) {
    if (estimatedLineHeight <= 1) {
      return viewportHeight;
    }
    return (viewportHeight - estimatedLineHeight)
        .clamp(viewportHeight * 0.5, viewportHeight)
        .toDouble();
  }

  static double _appendTextLines({
    required String text,
    required TextStyle style,
    required TextAlign textAlign,
    required double maxWidth,
    required double startY,
    required List<ScrollLineFrame> output,
  }) {
    if (text.trim().isEmpty) {
      return startY;
    }
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textAlign: textAlign,
      textDirection: TextDirection.ltr,
      maxLines: null,
    )..layout(maxWidth: maxWidth);

    final metrics = painter.computeLineMetrics();
    if (metrics.isEmpty) {
      return startY + painter.height;
    }

    for (final metric in metrics) {
      final lineTop = startY + metric.baseline - metric.ascent;
      final lineBottom = startY + metric.baseline + metric.descent;
      output.add(
        ScrollLineFrame(
          top: lineTop,
          bottom: lineBottom,
        ),
      );
    }
    return startY + painter.height;
  }
}
