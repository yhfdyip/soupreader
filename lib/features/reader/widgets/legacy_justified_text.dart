import 'dart:ui' as ui;
import 'package:flutter/widgets.dart';

class LegacyJustifiedTextBlock extends StatelessWidget {
  final String content;
  final TextStyle style;
  final bool justify;
  final bool bottomJustify;
  final String paragraphIndent;
  final bool applyParagraphIndent;
  final bool preserveEmptyLines;
  /// 预排版行缓存（由分页器提供）。不为 null 时跳过重新排版，直接复用。
  final List<LegacyComposedLine>? precomposedLines;

  const LegacyJustifiedTextBlock({
    super.key,
    required this.content,
    required this.style,
    required this.justify,
    this.bottomJustify = false,
    this.paragraphIndent = '　　',
    this.applyParagraphIndent = true,
    this.preserveEmptyLines = true,
    this.precomposedLines,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (!constraints.maxWidth.isFinite || constraints.maxWidth <= 0) {
          return const SizedBox.shrink();
        }
        final maxWidth = constraints.maxWidth;
        final lines = precomposedLines ??
            LegacyJustifyComposer.composeContentLines(
              content: content,
              style: style,
              maxWidth: maxWidth,
              justify: justify,
              paragraphIndent: paragraphIndent,
              applyParagraphIndent: applyParagraphIndent,
              preserveEmptyLines: preserveEmptyLines,
            );
        if (lines.isEmpty) {
          return const SizedBox.shrink();
        }
        final maxHeight =
            constraints.maxHeight.isFinite && constraints.maxHeight > 0
                ? constraints.maxHeight
                : null;
        final extraGap = LegacyJustifyComposer.computeBottomJustifyGap(
          bottomJustify: bottomJustify,
          lines: lines,
          maxHeight: maxHeight,
        );
        final children = <Widget>[];
        var usedHeight = 0.0;
        for (var i = 0; i < lines.length; i++) {
          final line = lines[i];
          if (maxHeight != null && usedHeight + line.renderHeight > maxHeight) break;
          if (i > 0 && extraGap > 0.01) {
            children.add(SizedBox(height: extraGap));
            usedHeight += extraGap;
          }
          children.add(line.toWidget(style: style, maxWidth: maxWidth));
          usedHeight += line.height;
        }

        return ClipRect(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: children,
          ),
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
  /// 步进高度（含行距间隙），用于累加 currentY
  final double height;
  /// 渲染高度（字体基准高度，不含行距间隙），用于截断判断。
  /// 对标 legado: lineBottom - lineTop = textHeight（不含行距）
  final double renderHeight;
  /// 行在页面内容区的起始 y 坐标（相对于 bodyOriginY），由 composeContentLines 填入
  final double lineStartY;

  const LegacyComposedLine({
    required this.plainText,
    required this.segments,
    required this.justified,
    required this.height,
    double? renderHeight,
    this.lineStartY = 0.0,
  }) : renderHeight = renderHeight ?? height;

  factory LegacyComposedLine.empty({required double height, double? renderHeight, double lineStartY = 0.0}) {
    return LegacyComposedLine(
      plainText: '',
      segments: const <LegacyComposedSegment>[],
      justified: false,
      height: height,
      renderHeight: renderHeight ?? height,
      lineStartY: lineStartY,
    );
  }

  bool get isVisualEmpty {
    if (plainText.trim().isNotEmpty) return false;
    return segments.every((segment) => segment.text.trim().isEmpty);
  }

  Widget toWidget({
    required TextStyle style,
    required double maxWidth,
  }) {
    if (isVisualEmpty) {
      return SizedBox(
        width: maxWidth,
        height: height,
      );
    }
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
  static List<LegacyComposedLine> composeContentLines({
    required String content,
    required TextStyle style,
    required double maxWidth,
    required bool justify,
    required String paragraphIndent,
    required bool applyParagraphIndent,
    required bool preserveEmptyLines,
  }) {
    final paragraphs = content.split('\n');
    final fontSize = style.fontSize ?? 16.0;
    final lineHeight =
        fontSize * (style.height ?? 1.2).clamp(1.0, 2.5);
    final lines = <LegacyComposedLine>[];
    var currentY = 0.0;
    for (final paragraph in paragraphs) {
      if (paragraph.trim().isEmpty) {
        if (preserveEmptyLines) {
          lines.add(LegacyComposedLine.empty(
            height: lineHeight,
            renderHeight: fontSize,
            lineStartY: currentY,
          ));
          currentY += lineHeight;
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
        lines.add(LegacyComposedLine(
          plainText: line.plainText,
          segments: line.segments,
          justified: line.justified,
          height: line.height,
          renderHeight: fontSize,
          lineStartY: currentY,
        ));
        currentY += line.height;
      }
    }
    return lines;
  }

  static double computeBottomJustifyGap({
    required bool bottomJustify,
    required List<LegacyComposedLine> lines,
    required double? maxHeight,
  }) {
    if (!bottomJustify) return 0;
    if (maxHeight == null || !maxHeight.isFinite || maxHeight <= 0) return 0;
    if (lines.length <= 1) return 0;
    final lastLine = lines.last;
    if (lastLine.isVisualEmpty) return 0;
    final contentHeight =
        lines.fold<double>(0, (sum, line) => sum + line.height);
    final surplus = maxHeight - contentHeight;
    if (surplus <= 0.01) return 0;
    if (surplus >= lastLine.height) return 0;
    final gapCount = lines.length - 1;
    if (gapCount <= 0) return 0;
    return surplus / gapCount;
  }

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
    // 字体基准高度（不含行距间隙），对标 legado textHeight
    final fontSizeForRender = style.fontSize ?? 16.0;

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
            renderHeight: fontSizeForRender,
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
            renderHeight: fontSizeForRender,
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
            renderHeight: fontSizeForRender,
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
          renderHeight: fontSizeForRender,
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
    bool bottomJustify = false,
    String? highlightQuery,
    Color? highlightBackgroundColor,
    Color? highlightTextColor,
    List<LegacyComposedLine>? precomposedLines,
  }) {
    final renderLines = precomposedLines ??
        composeContentLines(
          content: content,
          style: style,
          maxWidth: maxWidth,
          justify: justify,
          paragraphIndent: paragraphIndent,
          applyParagraphIndent: applyParagraphIndent,
          preserveEmptyLines: preserveEmptyLines,
        );
    if (renderLines.isEmpty) {
      return 0;
    }
    final extraGap = computeBottomJustifyGap(
      bottomJustify: bottomJustify,
      lines: renderLines,
      maxHeight: maxHeight,
    );
    var y = origin.dy;
    final normalizedQuery = highlightQuery?.trim() ?? '';
    final hasHighlight = normalizedQuery.isNotEmpty;

    for (var lineIndex = 0; lineIndex < renderLines.length; lineIndex++) {
      if (lineIndex > 0 && extraGap > 0.01) {
        y += extraGap;
      }
      final line = renderLines[lineIndex];
      if (y - origin.dy + line.renderHeight > maxHeight) break;
      if (line.segments.isEmpty || line.isVisualEmpty) {
        y += line.height;
        continue;
      }

      final lineRanges = hasHighlight
          ? _resolveMatchRanges(line.plainText, normalizedQuery)
          : const <TextRange>[];
      var x = origin.dx;
      var cursor = 0;
      for (final segment in line.segments) {
        if (segment.text.isNotEmpty) {
          final segmentStart = cursor;
          final segmentEnd = segmentStart + segment.text.length;
          final overlaps = hasHighlight
              ? _resolveSegmentRanges(
                  lineRanges,
                  segmentStart: segmentStart,
                  segmentEnd: segmentEnd,
                )
              : const <TextRange>[];
          if (overlaps.isEmpty) {
            x += _paintTextPiece(
              canvas: canvas,
              text: segment.text,
              style: style,
              x: x,
              y: y,
              lineHeight: line.height,
            );
          } else {
            var localCursor = 0;
            for (final range in overlaps) {
              final localStart = range.start - segmentStart;
              final localEnd = range.end - segmentStart;
              if (localStart > localCursor) {
                final before = segment.text.substring(localCursor, localStart);
                x += _paintTextPiece(
                  canvas: canvas,
                  text: before,
                  style: style,
                  x: x,
                  y: y,
                  lineHeight: line.height,
                );
              }
              final hitText = segment.text.substring(localStart, localEnd);
              x += _paintTextPiece(
                canvas: canvas,
                text: hitText,
                style: style.copyWith(
                  color: highlightTextColor ?? style.color,
                ),
                x: x,
                y: y,
                lineHeight: line.height,
                highlighted: true,
                highlightBackgroundColor: highlightBackgroundColor,
              );
              localCursor = localEnd;
            }
            if (localCursor < segment.text.length) {
              final tail = segment.text.substring(localCursor);
              x += _paintTextPiece(
                canvas: canvas,
                text: tail,
                style: style,
                x: x,
                y: y,
                lineHeight: line.height,
              );
            }
          }
          cursor = segmentEnd;
        }
        if (segment.extraAfter > 0) {
          x += segment.extraAfter;
        }
      }
      y += line.height;
    }

    return y - origin.dy;
  }

  static List<TextRange> _resolveMatchRanges(String text, String query) {
    if (text.isEmpty || query.isEmpty) return const <TextRange>[];
    final ranges = <TextRange>[];
    var from = 0;
    while (from < text.length) {
      final found = text.indexOf(query, from);
      if (found == -1) break;
      final end = found + query.length;
      ranges.add(TextRange(start: found, end: end));
      from = end;
    }
    return ranges;
  }

  static List<TextRange> _resolveSegmentRanges(
    List<TextRange> ranges, {
    required int segmentStart,
    required int segmentEnd,
  }) {
    if (ranges.isEmpty || segmentEnd <= segmentStart) {
      return const <TextRange>[];
    }
    final result = <TextRange>[];
    for (final range in ranges) {
      if (range.end <= segmentStart) continue;
      if (range.start >= segmentEnd) break;
      final start = range.start.clamp(segmentStart, segmentEnd).toInt();
      final end = range.end.clamp(segmentStart, segmentEnd).toInt();
      if (end > start) {
        result.add(TextRange(start: start, end: end));
      }
    }
    return result;
  }

  static double _paintTextPiece({
    required Canvas canvas,
    required String text,
    required TextStyle style,
    required double x,
    required double y,
    required double lineHeight,
    bool highlighted = false,
    Color? highlightBackgroundColor,
  }) {
    if (text.isEmpty) return 0;
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: ui.TextDirection.ltr,
      maxLines: 1,
    )..layout(minWidth: 0, maxWidth: double.infinity);
    if (highlighted) {
      final highlightColor =
          highlightBackgroundColor ?? const Color(0x66FFD54F);
      final rectHeight = (painter.height + 3).clamp(0.0, lineHeight);
      final rectTop = y + (lineHeight - rectHeight) / 2;
      final rRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, rectTop, painter.width, rectHeight),
        const Radius.circular(2),
      );
      canvas.drawRRect(
        rRect,
        Paint()
          ..color = highlightColor
          ..style = PaintingStyle.fill,
      );
    }
    painter.paint(canvas, Offset(x, y));
    return painter.width;
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

  /// 计算选区内每行的高亮矩形（相对于 [origin] 的绝对坐标）。
  ///
  /// [startLineIndex]/[startCharIndex] 为选区起点，[endLineIndex]/[endCharIndex] 为终点。
  /// 返回的 [Rect] 列表可直接用于 Canvas 绘制高亮。
  static List<Rect> resolveSelectionRects({
    required List<LegacyComposedLine> lines,
    required int startLineIndex,
    required int startCharIndex,
    required int endLineIndex,
    required int endCharIndex,
    required TextStyle style,
    required double maxWidth,
    required Offset origin,
    bool bottomJustify = false,
    double? maxHeight,
  }) {
    if (lines.isEmpty) return const <Rect>[];
    final safeStart = startLineIndex.clamp(0, lines.length - 1);
    final safeEnd = endLineIndex.clamp(0, lines.length - 1);
    if (safeStart > safeEnd) return const <Rect>[];

    // 对标 paintContentOnCanvas：底部对齐时行间加 extraGap
    final extraGap = computeBottomJustifyGap(
      bottomJustify: bottomJustify,
      lines: lines,
      maxHeight: maxHeight,
    );

    final rects = <Rect>[];
    for (var i = safeStart; i <= safeEnd; i++) {
      final line = lines[i];
      if (line.isVisualEmpty) continue;
      final text = line.plainText;
      if (text.isEmpty) continue;

      final charStart = (i == safeStart) ? startCharIndex.clamp(0, text.length) : 0;
      final charEnd = (i == safeEnd) ? endCharIndex.clamp(0, text.length) : text.length;
      if (charStart >= charEnd) continue;

      final x0 = _resolveCharX(line: line, charIndex: charStart, style: style, maxWidth: maxWidth);
      final x1 = _resolveCharX(line: line, charIndex: charEnd, style: style, maxWidth: maxWidth);
      if (x1 <= x0) continue;

      // lineStartY 不含 extraGap，需补加（第 i 行前累计 i 个 extraGap，从 index=1 开始）
      final gapOffset = i > 0 ? extraGap * i : 0.0;
      final top = origin.dy + line.lineStartY + gapOffset;
      rects.add(Rect.fromLTWH(origin.dx + x0, top, x1 - x0, line.height));
    }
    return rects;
  }

  /// 计算某行中第 [charIndex] 个字符的左边 x 坐标（相对于行起点 x=0）。
  static double _resolveCharX({
    required LegacyComposedLine line,
    required int charIndex,
    required TextStyle style,
    required double maxWidth,
  }) {
    if (charIndex <= 0) return 0.0;
    final text = line.plainText;
    if (charIndex >= text.length) {
      // 返回行尾 x
      if (!line.justified || line.segments.length <= 1) {
        final p = TextPainter(
          text: TextSpan(text: text, style: style),
          textDirection: ui.TextDirection.ltr,
          maxLines: 1,
        )..layout(maxWidth: maxWidth);
        return p.width;
      }
      // justify 行：累加所有 segment 宽度（不含最后 extraAfter）
      var x = 0.0;
      for (final segment in line.segments) {
        for (var i = 0; i < segment.text.length; i++) {
          final char = segment.text.substring(i, i + 1);
          final p = TextPainter(
            text: TextSpan(text: char, style: style),
            textDirection: ui.TextDirection.ltr,
            maxLines: 1,
          )..layout(maxWidth: double.infinity);
          x += p.width;
        }
        x += segment.extraAfter;
      }
      return x;
    }
    if (!line.justified || line.segments.length <= 1) {
      final prefix = text.substring(0, charIndex.clamp(0, text.length));
      final p = TextPainter(
        text: TextSpan(text: prefix, style: style),
        textDirection: ui.TextDirection.ltr,
        maxLines: 1,
      )..layout(maxWidth: double.infinity);
      return p.width;
    }
    // justify 行：逐 segment 逐字符累加
    var x = 0.0;
    var cursor = 0;
    for (final segment in line.segments) {
      for (var i = 0; i < segment.text.length; i++) {
        if (cursor >= charIndex) return x;
        final char = segment.text.substring(i, i + 1);
        final p = TextPainter(
          text: TextSpan(text: char, style: style),
          textDirection: ui.TextDirection.ltr,
          maxLines: 1,
        )..layout(maxWidth: double.infinity);
        x += p.width;
        cursor++;
      }
      if (cursor < charIndex) x += segment.extraAfter;
    }
    return x;
  }
}
