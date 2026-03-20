// Reader internal data types extracted from [SimpleReaderView].

import 'dart:typed_data';
import 'dart:ui' show Size;

import 'package:flutter/painting.dart';

import '../../replace/models/replace_rule.dart';
import '../services/reader_image_marker_codec.dart';

// ─── Image style constants ──────────────────────────────────────────────────

/// Legacy image rendering style: show images at full width.
const String legacyImageStyleFull = 'FULL';

/// Legacy image rendering style: render image tags as plain text.
const String legacyImageStyleText = 'TEXT';

/// Legacy image rendering style: one image per viewport page.
const String legacyImageStyleSingle = 'SINGLE';

/// Regex matching `<img>` tags with a `src` attribute.
final RegExp legacyImageTagRegex = RegExp(
  r"""<img[^>]*src=['"]([^'"]*(?:['"][^>]+\})?)['"][^>]*>""",
  caseSensitive: false,
);

// ─── Data classes & enums ───────────────────────────────────────────────────

class ReadAloudCapability {
  final bool available;
  final String reason;

  const ReadAloudCapability({
    required this.available,
    required this.reason,
  });
}

enum ReaderImageWarmupFailureKind {
  timeout,
  auth,
  decode,
  other,
}

class ReaderImageSizeProbeResult {
  final Size? size;
  final ReaderImageWarmupFailureKind? failureKind;
  final bool attempted;

  const ReaderImageSizeProbeResult._({
    required this.size,
    required this.failureKind,
    required this.attempted,
  });

  const ReaderImageSizeProbeResult.success(Size value)
      : this._(
          size: value,
          failureKind: null,
          attempted: true,
        );

  const ReaderImageSizeProbeResult.failure(
      ReaderImageWarmupFailureKind kind)
      : this._(
          size: null,
          failureKind: kind,
          attempted: true,
        );

  const ReaderImageSizeProbeResult.skipped()
      : this._(
          size: null,
          failureKind: null,
          attempted: false,
        );
}

class ReaderImageBytesProbeResult {
  final Uint8List? bytes;
  final ReaderImageWarmupFailureKind? failureKind;

  const ReaderImageBytesProbeResult._({
    required this.bytes,
    required this.failureKind,
  });

  const ReaderImageBytesProbeResult.success(Uint8List value)
      : this._(
          bytes: value,
          failureKind: null,
        );

  const ReaderImageBytesProbeResult.failure(
      ReaderImageWarmupFailureKind kind)
      : this._(
          bytes: null,
          failureKind: kind,
        );
}

class ReaderImageWarmupSourceTelemetry {
  int sampleCount = 0;
  int timeoutStreak = 0;
  int authStreak = 0;
  int decodeStreak = 0;
  double successRateEma = 0.0;
  double timeoutRateEma = 0.0;
  double authRateEma = 0.0;
  double decodeRateEma = 0.0;
  DateTime updatedAt = DateTime.fromMillisecondsSinceEpoch(0);

  void recordSuccess() {
    _apply(success: true, failureKind: null);
  }

  void recordFailure(ReaderImageWarmupFailureKind kind) {
    _apply(success: false, failureKind: kind);
  }

  void _apply({
    required bool success,
    required ReaderImageWarmupFailureKind? failureKind,
  }) {
    final alpha = sampleCount < 8 ? 0.34 : 0.18;
    successRateEma =
        _ema(successRateEma, success ? 1.0 : 0.0, alpha);
    timeoutRateEma = _ema(
      timeoutRateEma,
      failureKind == ReaderImageWarmupFailureKind.timeout
          ? 1.0
          : 0.0,
      alpha,
    );
    authRateEma = _ema(
      authRateEma,
      failureKind == ReaderImageWarmupFailureKind.auth
          ? 1.0
          : 0.0,
      alpha,
    );
    decodeRateEma = _ema(
      decodeRateEma,
      failureKind == ReaderImageWarmupFailureKind.decode
          ? 1.0
          : 0.0,
      alpha,
    );

    if (success) {
      timeoutStreak = 0;
      authStreak = 0;
      decodeStreak = 0;
    } else {
      switch (failureKind) {
        case ReaderImageWarmupFailureKind.timeout:
          timeoutStreak =
              (timeoutStreak + 1).clamp(0, 24).toInt();
          authStreak = 0;
          decodeStreak = 0;
          break;
        case ReaderImageWarmupFailureKind.auth:
          authStreak =
              (authStreak + 1).clamp(0, 24).toInt();
          timeoutStreak = 0;
          decodeStreak = 0;
          break;
        case ReaderImageWarmupFailureKind.decode:
          decodeStreak =
              (decodeStreak + 1).clamp(0, 24).toInt();
          timeoutStreak = 0;
          authStreak = 0;
          break;
        case ReaderImageWarmupFailureKind.other:
          timeoutStreak = 0;
          authStreak = 0;
          decodeStreak = 0;
          break;
        case null:
          timeoutStreak = 0;
          authStreak = 0;
          decodeStreak = 0;
          break;
      }
    }

    sampleCount =
        (sampleCount + 1).clamp(0, 4096).toInt();
    updatedAt = DateTime.now();
  }

  double _ema(
      double current, double value, double alpha) {
    if (sampleCount <= 0) {
      return value;
    }
    return current * (1 - alpha) + value * alpha;
  }
}

class ReaderImageWarmupBudget {
  final int probeCount;
  final Duration maxDuration;
  final Duration perProbeTimeout;

  const ReaderImageWarmupBudget({
    required this.probeCount,
    required this.maxDuration,
    required this.perProbeTimeout,
  });
}

class ReaderOfflineCacheInput {
  final String startChapter;
  final String endChapter;

  const ReaderOfflineCacheInput({
    required this.startChapter,
    required this.endChapter,
  });
}

class ReaderOfflineCacheRange {
  final int startIndex;
  final int endIndex;

  const ReaderOfflineCacheRange({
    required this.startIndex,
    required this.endIndex,
  });
}

enum ReaderTextActionMenuAction {
  replace,
  copy,
  bookmark,
  readAloud,
  dict,
  searchContent,
  browser,
  share,
  processText,
  more,
  collapse,
}

enum ReaderAudioPlayMenuAction {
  login,
  changeSource,
  copyAudioUrl,
  editSource,
  wakeLock,
  log,
}

class DuplicateTitleRemovalResult {
  final String content;
  final bool removed;

  const DuplicateTitleRemovalResult({
    required this.content,
    required this.removed,
  });
}

class ReaderSimulatedReadingInput {
  final bool enabled;
  final String startChapter;
  final String dailyChapters;
  final DateTime startDate;

  const ReaderSimulatedReadingInput({
    required this.enabled,
    required this.startChapter,
    required this.dailyChapters,
    required this.startDate,
  });
}

class ReaderBookmarkDraft {
  final String chapterTitle;
  final int chapterPos;
  final String pageText;

  const ReaderBookmarkDraft({
    required this.chapterTitle,
    required this.chapterPos,
    required this.pageText,
  });
}

class ReaderBookmarkEditResult {
  final String bookText;
  final String note;

  const ReaderBookmarkEditResult({
    required this.bookText,
    required this.note,
  });
}

class TipOption {
  final int value;
  final String label;

  const TipOption(this.value, this.label);
}

class EffectiveReplaceMenuEntry {
  final String label;
  final ReplaceRule? rule;
  final bool isChineseConverter;

  const EffectiveReplaceMenuEntry._({
    required this.label,
    required this.rule,
    required this.isChineseConverter,
  });

  const EffectiveReplaceMenuEntry.rule({
    required String label,
    required ReplaceRule rule,
  }) : this._(
          label: label,
          rule: rule,
          isChineseConverter: false,
        );

  const EffectiveReplaceMenuEntry.chineseConverter({
    required String label,
  }) : this._(
          label: label,
          rule: null,
          isChineseConverter: true,
        );
}

class ReplaceStageCache {
  final String rawTitle;
  final String rawContent;
  final String title;
  final String content;
  final List<ReplaceRule> effectiveContentReplaceRules;

  const ReplaceStageCache({
    required this.rawTitle,
    required this.rawContent,
    required this.title,
    required this.content,
    required this.effectiveContentReplaceRules,
  });
}

class ResolvedChapterSnapshot {
  final String chapterId;
  final int postProcessSignature;
  final int baseTitleHash;
  final int baseContentHash;
  final String title;
  final String content;
  final bool isDeferredPlaceholder;

  const ResolvedChapterSnapshot({
    required this.chapterId,
    required this.postProcessSignature,
    required this.baseTitleHash,
    required this.baseContentHash,
    required this.title,
    required this.content,
    this.isDeferredPlaceholder = false,
  });
}

class ChapterImageMetaSnapshot {
  final String chapterId;
  final int postProcessSignature;
  final int contentHash;
  final List<ReaderImageMarkerMeta> metas;

  const ChapterImageMetaSnapshot({
    required this.chapterId,
    required this.postProcessSignature,
    required this.contentHash,
    required this.metas,
  });
}

class ReaderSearchHit {
  final int chapterIndex;
  final String chapterTitle;
  final int chapterContentLength;
  final int start;
  final int end;
  final String query;
  final int occurrenceIndex;
  final String previewBefore;
  final String previewMatch;
  final String previewAfter;
  final int? pageIndex;

  const ReaderSearchHit({
    required this.chapterIndex,
    required this.chapterTitle,
    required this.chapterContentLength,
    required this.start,
    required this.end,
    required this.query,
    required this.occurrenceIndex,
    required this.previewBefore,
    required this.previewMatch,
    required this.previewAfter,
    required this.pageIndex,
  });
}

class ReaderSearchProgressSnapshot {
  final int chapterIndex;
  final double chapterProgress;

  const ReaderSearchProgressSnapshot({
    required this.chapterIndex,
    required this.chapterProgress,
  });
}

class ScrollSegmentSeed {
  final String chapterId;
  final String title;
  final String content;

  const ScrollSegmentSeed({
    required this.chapterId,
    required this.title,
    required this.content,
  });
}

class ReaderRenderBlock {
  final String? text;
  final String? imageSrc;

  const ReaderRenderBlock._({
    this.text,
    this.imageSrc,
  });

  const ReaderRenderBlock.text(String value)
      : this._(
          text: value,
        );

  const ReaderRenderBlock.image(String value)
      : this._(
          imageSrc: value,
        );

  bool get isImage => imageSrc != null;
}

class ScrollSegment {
  final int chapterIndex;
  final String chapterId;
  final String title;
  final String content;
  final double estimatedHeight;

  const ScrollSegment({
    required this.chapterIndex,
    required this.chapterId,
    required this.title,
    required this.content,
    required this.estimatedHeight,
  });
}

class ScrollSegmentOffsetRange {
  final ScrollSegment segment;
  final double start;
  final double end;
  final double height;

  const ScrollSegmentOffsetRange({
    required this.segment,
    required this.start,
    required this.end,
    required this.height,
  });
}

class ScrollTipData {
  final String title;
  final String bookTitle;
  final double bookProgress;
  final double chapterProgress;
  final int currentPage;
  final int totalPages;
  final String currentTime;

  const ScrollTipData({
    required this.title,
    required this.bookTitle,
    required this.bookProgress,
    required this.chapterProgress,
    required this.currentPage,
    required this.totalPages,
    required this.currentTime,
  });

  const ScrollTipData.empty()
      : title = '',
        bookTitle = '',
        bookProgress = 0.0,
        chapterProgress = 0.0,
        currentPage = 1,
        totalPages = 1,
        currentTime = '';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ScrollTipData &&
        other.title == title &&
        other.bookTitle == bookTitle &&
        other.bookProgress == bookProgress &&
        other.chapterProgress == chapterProgress &&
        other.currentPage == currentPage &&
        other.totalPages == totalPages &&
        other.currentTime == currentTime;
  }

  @override
  int get hashCode => Object.hash(
        title,
        bookTitle,
        bookProgress,
        chapterProgress,
        currentPage,
        totalPages,
        currentTime,
      );
}
