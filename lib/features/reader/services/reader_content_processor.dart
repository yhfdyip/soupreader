import 'dart:ui' show Size;

import 'package:flutter/foundation.dart';

import '../../import/txt_parser.dart';
import '../../replace/models/replace_rule.dart';
import '../../replace/services/replace_rule_service.dart';
import '../models/reading_settings.dart';
import '../models/reader_view_types.dart';
import '../services/reader_image_marker_codec.dart';

typedef ReaderTitleReplaceResolver = Future<String> Function(
  String title, {
  required String bookName,
  required String? sourceUrl,
});

typedef ReaderContentReplaceResolver = Future<ReplaceContentApplyTrace>
    Function(
  String content, {
  required String bookName,
  required String? sourceUrl,
});

class ReaderContentProcessorContext {
  final String bookName;
  final String? Function() currentSourceUrl;
  final bool Function() useReplaceRule;
  final bool Function(String chapterId) removeSameTitleEnabled;
  final bool Function() isCurrentBookEpub;
  final bool Function() delRubyTag;
  final bool Function() delHTag;
  final bool Function() reSegmentEnabled;
  final int Function() chineseConverterType;
  final String Function(String raw) normalizeImageSrc;
  final void Function(String src) rememberBookImageCacheKey;
  final String Function() normalizedImageStyle;
  final bool Function() isScrollMode;
  final Size? Function(String imgTag) extractImageDimensionHintsFromTag;
  final Size? Function(String rawSrc) extractImageDimensionHintsFromSrcUrl;
  final String Function(String text) traditionalToSimplified;
  final String Function(String text) simplifiedToTraditional;
  final ReaderTitleReplaceResolver applyTitleReplace;
  final ReaderContentReplaceResolver applyContentReplaceWithTrace;

  const ReaderContentProcessorContext({
    required this.bookName,
    required this.currentSourceUrl,
    required this.useReplaceRule,
    required this.removeSameTitleEnabled,
    required this.isCurrentBookEpub,
    required this.delRubyTag,
    required this.delHTag,
    required this.reSegmentEnabled,
    required this.chineseConverterType,
    required this.normalizeImageSrc,
    required this.rememberBookImageCacheKey,
    required this.normalizedImageStyle,
    required this.isScrollMode,
    required this.extractImageDimensionHintsFromTag,
    required this.extractImageDimensionHintsFromSrcUrl,
    required this.traditionalToSimplified,
    required this.simplifiedToTraditional,
    required this.applyTitleReplace,
    required this.applyContentReplaceWithTrace,
  });
}

class ReaderContentProcessor extends ChangeNotifier {
  ReaderContentProcessor(this._context);

  final ReaderContentProcessorContext _context;
  final Map<String, ReplaceStageCache> _replaceStageCache =
      <String, ReplaceStageCache>{};

  Map<String, ReplaceStageCache> get replaceStageCache => _replaceStageCache;

  void clearReplaceStageCache() {
    if (_replaceStageCache.isEmpty) return;
    _replaceStageCache.clear();
    notifyListeners();
  }

  void removeReplaceStage(String chapterId) {
    if (_replaceStageCache.remove(chapterId) == null) return;
    notifyListeners();
  }

  String postProcessContent(
    String content,
    String processedTitle, {
    String? chapterId,
  }) {
    var processed = content;
    final shouldRemoveTitle =
        chapterId != null && _context.removeSameTitleEnabled(chapterId);
    if (shouldRemoveTitle) {
      processed = removeDuplicateTitle(processed, processedTitle).content;
    }
    if (_context.isCurrentBookEpub()) {
      if (_context.delRubyTag()) {
        processed = removeRubyTagsLikeLegado(processed);
      }
      if (_context.delHTag()) {
        processed = removeHTagLikeLegado(processed);
      }
    }
    if (_context.reSegmentEnabled()) {
      processed = TxtParser.reSegmentLikeLegado(
        processed,
        chapterTitle: processedTitle,
      );
    }
    processed = convertByChineseConverterType(processed);
    processed = normalizeContentForLegacyImageStyle(processed);
    return formatContentLikeLegado(processed);
  }

  String postProcessTitle(String title) {
    return convertByChineseConverterType(title);
  }

  Future<ReplaceStageCache> computeReplaceStage({
    required String chapterId,
    required String rawTitle,
    required String rawContent,
  }) async {
    final cached = _replaceStageCache[chapterId];
    if (cached != null &&
        cached.rawTitle == rawTitle &&
        cached.rawContent == rawContent) {
      return cached;
    }

    final title = _context.useReplaceRule()
        ? await _context.applyTitleReplace(
            rawTitle,
            bookName: _context.bookName,
            sourceUrl: _context.currentSourceUrl(),
          )
        : rawTitle;
    final contentTrace = _context.useReplaceRule()
        ? await _context.applyContentReplaceWithTrace(
            rawContent,
            bookName: _context.bookName,
            sourceUrl: _context.currentSourceUrl(),
          )
        : ReplaceContentApplyTrace(
            output: rawContent,
            appliedRules: const <ReplaceRule>[],
          );

    final stage = ReplaceStageCache(
      rawTitle: rawTitle,
      rawContent: rawContent,
      title: title,
      content: contentTrace.output,
      effectiveContentReplaceRules: contentTrace.appliedRules,
    );
    _replaceStageCache[chapterId] = stage;
    notifyListeners();
    return stage;
  }

  String formatContentLikeLegado(String content) {
    var text = content;
    text = text
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&ensp;', ' ')
        .replaceAll('&emsp;', ' ')
        .replaceAll('&thinsp;', '')
        .replaceAll('&zwnj;', '')
        .replaceAll('&zwj;', '')
        .replaceAll('\u2009', '')
        .replaceAll('\u200C', '')
        .replaceAll('\u200D', '')
        .replaceAll('\r\n', '\n');

    final paragraphs = text
        .split(RegExp(r'\s*\n+\s*'))
        .map(trimParagraphLikeLegado)
        .where((paragraph) => paragraph.isNotEmpty)
        .toList(growable: false);
    if (paragraphs.isEmpty) return '';
    return paragraphs.join('\n');
  }

  String normalizeContentForLegacyImageStyle(String content) {
    if (content.isEmpty || !legacyImageTagRegex.hasMatch(content)) {
      return content;
    }
    final imageStyle = _context.normalizedImageStyle();
    if (imageStyle == legacyImageStyleText) {
      return content.replaceAllMapped(
        legacyImageTagRegex,
        (_) => ReaderImageMarkerCodec.textFallbackPlaceholder,
      );
    }
    if (!_context.isScrollMode()) {
      return content.replaceAllMapped(
        legacyImageTagRegex,
        (match) {
          final rawSrc = (match.group(1) ?? '').trim();
          final src = _context.normalizeImageSrc(rawSrc);
          if (src.isEmpty) {
            return ReaderImageMarkerCodec.textFallbackPlaceholder;
          }
          _context.rememberBookImageCacheKey(src);
          final rawTag = match.group(0) ?? '';
          final hintedSize =
              _context.extractImageDimensionHintsFromTag(rawTag) ??
                  _context.extractImageDimensionHintsFromSrcUrl(rawSrc);
          final resolvedSize = ReaderImageMarkerCodec.lookupResolvedSize(src);
          final width = resolvedSize?.width ?? hintedSize?.width;
          final height = resolvedSize?.height ?? hintedSize?.height;
          return '\n${ReaderImageMarkerCodec.encode(
            src,
            width: width,
            height: height,
          )}\n';
        },
      );
    }
    return content.replaceAllMapped(
      legacyImageTagRegex,
      (match) => '\n${match.group(0)}\n',
    );
  }

  String convertByChineseConverterType(String text) {
    switch (_context.chineseConverterType()) {
      case ChineseConverterType.traditionalToSimplified:
        return _context.traditionalToSimplified(text);
      case ChineseConverterType.simplifiedToTraditional:
        return _context.simplifiedToTraditional(text);
      default:
        return text;
    }
  }

  DuplicateTitleRemovalResult removeDuplicateTitle(
    String content,
    String title,
  ) {
    if (content.isEmpty) {
      return DuplicateTitleRemovalResult(
        content: content,
        removed: false,
      );
    }
    final lines = content.replaceAll('\r\n', '\n').split('\n');
    final trimmedTitle = title.trim();
    final index = lines.indexWhere((line) => line.trim().isNotEmpty);
    if (index == -1) {
      return DuplicateTitleRemovalResult(
        content: lines.join('\n'),
        removed: false,
      );
    }
    final firstLine = lines[index].trim();
    if (firstLine == trimmedTitle || firstLine.contains(trimmedTitle)) {
      lines.removeAt(index);
      return DuplicateTitleRemovalResult(
        content: lines.join('\n'),
        removed: true,
      );
    }
    return DuplicateTitleRemovalResult(
      content: lines.join('\n'),
      removed: false,
    );
  }

  String removeRubyTagsLikeLegado(String content) {
    return content
        .replaceAll(
          RegExp(r'<rt\b[^>]*>.*?</rt>', caseSensitive: false, dotAll: true),
          '',
        )
        .replaceAll(
          RegExp(r'<rp\b[^>]*>.*?</rp>', caseSensitive: false, dotAll: true),
          '',
        );
  }

  String removeHTagLikeLegado(String content) {
    final withoutHeaderBlocks = content.replaceAll(
      RegExp(
        r'<h[1-6]\b[^>]*>.*?</h[1-6]\s*>',
        caseSensitive: false,
        dotAll: true,
      ),
      '',
    );
    return withoutHeaderBlocks.replaceAll(
      RegExp(r'<h[1-6]\b[^>]*/>', caseSensitive: false),
      '',
    );
  }

  String trimParagraphLikeLegado(String input) {
    if (input.isEmpty) return '';
    var start = 0;
    var end = input.length;
    while (start < end) {
      final ch = input[start];
      final code = input.codeUnitAt(start);
      if (code <= 0x20 || ch == '　') {
        start++;
        continue;
      }
      break;
    }
    while (end > start) {
      final ch = input[end - 1];
      final code = input.codeUnitAt(end - 1);
      if (code <= 0x20 || ch == '　') {
        end--;
        continue;
      }
      break;
    }
    return input.substring(start, end);
  }
}
