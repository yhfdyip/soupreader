import 'dart:ui' as ui;
import 'package:flutter/widgets.dart';

class LegacyJustifiedTextBlock extends StatelessWidget {
  final String content;
  final TextStyle style;
  final bool justify;
  final String paragraphIndent;
  final bool applyParagraphIndent;
  final bool preserveEmptyLines;

  const LegacyJustifiedTextBlock({
    super.key,
    required this.content,
    required this.style,
    required this.justify,
    this.paragraphIndent = '　　',
    this.applyParagraphIndent = true,
    this.preserveEmptyLines = true,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (!constraints.maxWidth.isFinite || constraints.maxWidth <= 0) {
          return const SizedBox.shrink();
        }
        final maxWidth = constraints.maxWidth;
        final paragraphs = content.split('\n');
        final lineHeight =
            (style.fontSize ?? 16.0) * (style.height ?? 1.2).clamp(1.0, 2.5);

        final children = <Widget>[];
        for (final paragraph in paragraphs) {
          if (paragraph.trim().isEmpty) {
            if (preserveEmptyLines) {
              children.add(SizedBox(height: lineHeight));
            }
            continue;
          }
          final composed = LegacyJustifyComposer.composeParagraph(
            paragraph: paragraph,
            style: style,
            maxWidth: maxWidth,
            justify: justify,
            paragraphIndent: paragraphIndent,
            applyParagraphIndent: applyParagraphIndent,
          );
          children.addAll(composed.toWidgets(style: style, maxWidth: maxWidth));
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: children,
        );
      },
    );
  }
}

class LegacyComposedParagraph {
  final List<LegacyComposedLine> lines;

  const LegacyComposedParagraph(this.lines);

  List<Widget> toWidgets({
    required TextStyle style,
    required double maxWidth,
  }) {
    return lines
        .map((line) => line.toWidget(style: style, maxWidth: maxWidth))
        .toList();
  }
}

class LegacyComposedLine {
  final String plainText;
  final List<LegacyComposedSegment> segments;
  final bool justified;
  final double height;

  const LegacyComposedLine({
    required this.plainText,
    required this.segments,
    required this.justified,
    required this.height,
  });

  Widget toWidget({
    required TextStyle style,
    required double maxWidth,
  }) {
    if (!justified || segments.length <= 1) {
      return SizedBox(
        width: maxWidth,
        child: Text(
          plainText,
          style: style,
          textAlign: TextAlign.left,
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.clip,
        ),
      );
    }

    final spans = <InlineSpan>[];
    for (final segment in segments) {
      if (segment.text.isNotEmpty) {
        spans.add(TextSpan(text: segment.text));
      }
      if (segment.extraAfter > 0.01) {
        spans.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: SizedBox(width: segment.extraAfter),
          ),
        );
      }
    }

    return SizedBox(
      width: maxWidth,
      child: RichText(
        maxLines: 1,
        overflow: TextOverflow.clip,
        softWrap: false,
        text: TextSpan(style: style, children: spans),
      ),
    );
  }
}

class LegacyComposedSegment {
  final String text;
  final double extraAfter;

  const LegacyComposedSegment({
    required this.text,
    required this.extraAfter,
  });
}

class LegacyJustifyComposer {
  static LegacyComposedParagraph composeParagraph({
    required String paragraph,
    required TextStyle style,
    required double maxWidth,
    required bool justify,
    required String paragraphIndent,
    required bool applyParagraphIndent,
  }) {
    final normalized = paragraph.trimRight();
    if (normalized.isEmpty) {
      return const LegacyComposedParagraph(<LegacyComposedLine>[]);
    }

    final source = (applyParagraphIndent && paragraphIndent.isNotEmpty)
        ? '$paragraphIndent${normalized.trimLeft()}'
        : normalized;

    final painter = TextPainter(
      text: TextSpan(text: source, style: style),
      textDirection: ui.TextDirection.ltr,
    )..layout(maxWidth: maxWidth);

    final lineMetrics = painter.computeLineMetrics();
    if (lineMetrics.isEmpty) {
      return const LegacyComposedParagraph(<LegacyComposedLine>[]);
    }

    final widthCache = <String, double>{};
    final lines = <LegacyComposedLine>[];
    var offset = 0;
    final indentLen = paragraphIndent.length;

    for (var i = 0; i < lineMetrics.length; i++) {
      final metric = lineMetrics[i];
      var range = painter.getLineBoundary(
        TextPosition(offset: offset.clamp(0, source.length)),
      );
      if (range.end <= offset && offset < source.length) {
        final next = (offset + 1).clamp(0, source.length);
        range = TextRange(start: offset, end: next);
      }

      var lineText = source.substring(range.start, range.end);
      offset = range.end;
      if (lineText.endsWith('\n')) {
        lineText = lineText.substring(0, lineText.length - 1);
      }

      final isLastLine = i == lineMetrics.length - 1;
      final canJustify = justify &&
          !isLastLine &&
          lineText.trim().isNotEmpty &&
          lineText.runes.length > 1;

      if (!canJustify) {
        lines.add(
          LegacyComposedLine(
            plainText: lineText,
            segments: <LegacyComposedSegment>[
              LegacyComposedSegment(text: lineText, extraAfter: 0),
            ],
            justified: false,
            height: metric.height,
          ),
        );
        continue;
      }

      var prefix = '';
      var body = lineText;
      if (indentLen > 0 && i == 0 && body.startsWith(paragraphIndent)) {
        prefix = paragraphIndent;
        body = body.substring(paragraphIndent.length);
      }

      final lineNaturalWidth = _measureWidth(
        text: lineText,
        style: style,
        cache: widthCache,
      );
      final residualWidth = maxWidth - lineNaturalWidth;
      if (residualWidth <= 0.01) {
        lines.add(
          LegacyComposedLine(
            plainText: lineText,
            segments: <LegacyComposedSegment>[
              LegacyComposedSegment(text: lineText, extraAfter: 0),
            ],
            justified: false,
            height: metric.height,
          ),
        );
        continue;
      }

      final chars = body.runes.map(String.fromCharCode).toList(growable: false);
      if (chars.length <= 1) {
        lines.add(
          LegacyComposedLine(
            plainText: lineText,
            segments: <LegacyComposedSegment>[
              LegacyComposedSegment(text: lineText, extraAfter: 0),
            ],
            justified: false,
            height: metric.height,
          ),
        );
        continue;
      }

      final spaceCount = chars.where((c) => c == ' ').length;
      final segments = <LegacyComposedSegment>[];
      if (prefix.isNotEmpty) {
        segments.add(LegacyComposedSegment(text: prefix, extraAfter: 0));
      }

      if (spaceCount > 1) {
        final gap = residualWidth / spaceCount;
        for (var idx = 0; idx < chars.length; idx++) {
          final isLastChar = idx == chars.length - 1;
          final extra = (chars[idx] == ' ' && !isLastChar) ? gap : 0.0;
          segments
              .add(LegacyComposedSegment(text: chars[idx], extraAfter: extra));
        }
      } else {
        final gapCount = chars.length - 1;
        if (gapCount <= 0) {
          segments.add(LegacyComposedSegment(text: body, extraAfter: 0));
        } else {
          final gap = residualWidth / gapCount;
          for (var idx = 0; idx < chars.length; idx++) {
            final extra = idx < chars.length - 1 ? gap : 0.0;
            segments.add(
                LegacyComposedSegment(text: chars[idx], extraAfter: extra));
          }
        }
      }

      lines.add(
        LegacyComposedLine(
          plainText: lineText,
          segments: segments,
          justified: true,
          height: metric.height,
        ),
      );
    }

    return LegacyComposedParagraph(lines);
  }

  static double paintContentOnCanvas({
    required Canvas canvas,
    required Offset origin,
    required String content,
    required TextStyle style,
    required double maxWidth,
    required bool justify,
    required String paragraphIndent,
    required bool applyParagraphIndent,
    required bool preserveEmptyLines,
    required double maxHeight,
  }) {
    final paragraphs = content.split('\n');
    final lineHeight =
        (style.fontSize ?? 16.0) * (style.height ?? 1.2).clamp(1.0, 2.5);
    var y = origin.dy;

    for (final paragraph in paragraphs) {
      if (y - origin.dy > maxHeight) break;
      if (paragraph.trim().isEmpty) {
        if (preserveEmptyLines) {
          y += lineHeight;
        }
        continue;
      }

      final composed = composeParagraph(
        paragraph: paragraph,
        style: style,
        maxWidth: maxWidth,
        justify: justify,
        paragraphIndent: paragraphIndent,
        applyParagraphIndent: applyParagraphIndent,
      );

      for (final line in composed.lines) {
        if (y - origin.dy > maxHeight) break;
        var x = origin.dx;
        for (final segment in line.segments) {
          if (segment.text.isNotEmpty) {
            final tp = TextPainter(
              text: TextSpan(text: segment.text, style: style),
              textDirection: ui.TextDirection.ltr,
              maxLines: 1,
            )..layout();
            tp.paint(canvas, Offset(x, y));
            x += tp.width;
          }
          if (segment.extraAfter > 0) {
            x += segment.extraAfter;
          }
        }
        y += line.height;
      }
    }

    return y - origin.dy;
  }

  static double _measureWidth({
    required String text,
    required TextStyle style,
    required Map<String, double> cache,
  }) {
    if (text.isEmpty) return 0;
    final key = '${style.fontSize}|${style.height}|${style.letterSpacing}|'
        '${style.fontWeight}|${style.fontFamily}|$text';
    final cached = cache[key];
    if (cached != null) return cached;
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: ui.TextDirection.ltr,
      maxLines: 1,
    )..layout();
    cache[key] = tp.width;
    return tp.width;
  }
}
