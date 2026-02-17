import 'dart:collection';

import 'package:flutter/widgets.dart';

import 'legacy_justified_text.dart';

class ScrollTextLayoutKey {
  final String chapterId;
  final int contentHash;
  final int widthPx;
  final int fontSizeX100;
  final int lineHeightX100;
  final int letterSpacingX100;
  final String? fontFamily;
  final FontWeight? fontWeight;
  final FontStyle? fontStyle;
  final bool justify;
  final String paragraphIndent;
  final int paragraphSpacingX100;

  const ScrollTextLayoutKey({
    required this.chapterId,
    required this.contentHash,
    required this.widthPx,
    required this.fontSizeX100,
    required this.lineHeightX100,
    required this.letterSpacingX100,
    required this.fontFamily,
    required this.fontWeight,
    required this.fontStyle,
    required this.justify,
    required this.paragraphIndent,
    required this.paragraphSpacingX100,
  });

  @override
  bool operator ==(Object other) {
    return other is ScrollTextLayoutKey &&
        other.chapterId == chapterId &&
        other.contentHash == contentHash &&
        other.widthPx == widthPx &&
        other.fontSizeX100 == fontSizeX100 &&
        other.lineHeightX100 == lineHeightX100 &&
        other.letterSpacingX100 == letterSpacingX100 &&
        other.fontFamily == fontFamily &&
        other.fontWeight == fontWeight &&
        other.fontStyle == fontStyle &&
        other.justify == justify &&
        other.paragraphIndent == paragraphIndent &&
        other.paragraphSpacingX100 == paragraphSpacingX100;
  }

  @override
  int get hashCode => Object.hash(
        chapterId,
        contentHash,
        widthPx,
        fontSizeX100,
        lineHeightX100,
        letterSpacingX100,
        fontFamily,
        fontWeight,
        fontStyle,
        justify,
        paragraphIndent,
        paragraphSpacingX100,
      );
}

class ScrollTextRun {
  final String text;
  final double width;
  final double extraAfter;

  const ScrollTextRun({
    required this.text,
    required this.width,
    required this.extraAfter,
  });
}

class ScrollTextLine {
  final double y;
  final double height;
  final List<ScrollTextRun> runs;

  const ScrollTextLine({
    required this.y,
    required this.height,
    required this.runs,
  });
}

class ScrollTextLayout {
  final ScrollTextLayoutKey key;
  final double bodyHeight;
  final List<ScrollTextLine> lines;

  const ScrollTextLayout({
    required this.key,
    required this.bodyHeight,
    required this.lines,
  });
}

class ScrollTextLayoutEngine {
  ScrollTextLayoutEngine._();

  static const int _maxCacheEntries = 24;
  static final ScrollTextLayoutEngine instance = ScrollTextLayoutEngine._();

  final LinkedHashMap<ScrollTextLayoutKey, ScrollTextLayout> _cache =
      LinkedHashMap<ScrollTextLayoutKey, ScrollTextLayout>();

  ScrollTextLayout compose({
    required ScrollTextLayoutKey key,
    required String content,
    required TextStyle style,
    required double maxWidth,
    required bool justify,
    required String paragraphIndent,
    required double paragraphSpacing,
  }) {
    final cached = _cache.remove(key);
    if (cached != null) {
      _cache[key] = cached;
      return cached;
    }

    final width = maxWidth.clamp(1.0, double.infinity).toDouble();
    final paragraphs = content.split(RegExp(r'\n\s*\n|\n'));
    final lines = <ScrollTextLine>[];
    final widthCache = <String, double>{};
    var y = 0.0;

    for (final rawParagraph in paragraphs) {
      final paragraph = rawParagraph.trimRight();
      if (paragraph.trim().isEmpty) {
        continue;
      }

      final composed = LegacyJustifyComposer.composeParagraph(
        paragraph: paragraph,
        style: style,
        maxWidth: width,
        justify: justify,
        paragraphIndent: paragraphIndent,
        applyParagraphIndent: true,
      );

      for (final line in composed.lines) {
        final runs = <ScrollTextRun>[];
        for (final segment in line.segments) {
          final text = segment.text;
          final textWidth = text.isEmpty
              ? 0.0
              : _measureTextWidth(
                  text: text,
                  style: style,
                  cache: widthCache,
                );
          runs.add(
            ScrollTextRun(
              text: text,
              width: textWidth,
              extraAfter: segment.extraAfter,
            ),
          );
        }

        lines.add(
          ScrollTextLine(
            y: y,
            height: line.height,
            runs: runs,
          ),
        );
        y += line.height;
      }

      y += paragraphSpacing;
    }

    final layout = ScrollTextLayout(
      key: key,
      bodyHeight: y,
      lines: lines,
    );

    _cache[key] = layout;
    while (_cache.length > _maxCacheEntries) {
      _cache.remove(_cache.keys.first);
    }
    return layout;
  }

  static double _measureTextWidth({
    required String text,
    required TextStyle style,
    required Map<String, double> cache,
  }) {
    final cacheKey =
        '${style.fontFamily}|${style.fontSize}|${style.letterSpacing}|${style.fontWeight?.index}|${style.fontStyle?.index}|$text';
    final hit = cache[cacheKey];
    if (hit != null) {
      return hit;
    }

    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout(minWidth: 0, maxWidth: double.infinity);
    final width = painter.width;
    cache[cacheKey] = width;
    return width;
  }

  void clearForTest() {
    _cache.clear();
  }

  int get cacheSizeForDebug => _cache.length;
}
