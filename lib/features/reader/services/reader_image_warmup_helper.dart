import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui show instantiateImageCodec;

import 'package:flutter/painting.dart';

import '../../source/models/book_source.dart';
import '../../source/services/source_cover_loader.dart';
import '../../source/services/rule_parser_engine.dart';
import '../models/reader_view_types.dart';
import '../services/reader_image_marker_codec.dart';
import '../services/reader_image_request_parser.dart';
import '../services/reader_image_resolver.dart';

/// Dependencies the warmup helper needs from the host reader.
class ReaderImageWarmupContext {
  /// Book ID for persistence scope.
  final String bookId;

  /// Whether the reader is ephemeral (no persistence).
  final bool Function() isEphemeral;

  /// Returns the current page turn mode. Returns `true` for scroll.
  final bool Function() isScrollMode;

  /// Returns the normalized legacy image style string.
  final String Function() normalizedImageStyle;

  /// Returns the current source (may be null).
  final BookSource? Function() currentSource;

  /// Returns the current source URL.
  final String? Function() currentSourceUrl;

  /// Returns the effective source URL for the session.
  final String? Function() effectiveSourceUrl;

  /// Returns recent chapter fetch duration for budget tuning.
  final Duration Function() recentChapterFetchDuration;

  /// Resolves an [ImageProvider] from a parsed image request.
  final ImageProvider<Object>? Function(ReaderImageRequest request)
      resolveImageProvider;

  /// Ensures cookie headers are cached for the image request.
  final Future<void> Function(
    ReaderImageRequest request, {
    Duration timeout,
  }) ensureCookieHeaderCached;

  /// Normalizes a raw image `src` attribute value.
  final String Function(String raw) normalizeImageSrc;

  /// Whether the given URI is HTTP/HTTPS.
  final bool Function(Uri uri) isHttpLikeUri;

  /// Callback when the size cache was updated and repagination
  /// may be needed.
  final void Function() onImageSizeCacheUpdated;

  /// Fetches image bytes via SourceCoverLoader.
  final Future<Uint8List?> Function({
    required BookSource source,
    required String imageUrl,
  }) loadBytesFromSourceLoader;

  /// Fetches image bytes via RuleParserEngine.
  final Future<Uint8List?> Function({
    required BookSource source,
    required String imageUrl,
  }) loadBytesFromRuleEngine;

  /// Saves the serialized image size snapshot.
  final Future<void> Function(String bookId, String payload)
      saveImageSizeSnapshot;

  /// Loads the serialized image size snapshot.
  final String? Function(String bookId) getImageSizeSnapshot;

  const ReaderImageWarmupContext({
    required this.bookId,
    required this.isEphemeral,
    required this.isScrollMode,
    required this.normalizedImageStyle,
    required this.currentSource,
    required this.currentSourceUrl,
    required this.effectiveSourceUrl,
    required this.recentChapterFetchDuration,
    required this.resolveImageProvider,
    required this.ensureCookieHeaderCached,
    required this.normalizeImageSrc,
    required this.isHttpLikeUri,
    required this.onImageSizeCacheUpdated,
    required this.loadBytesFromSourceLoader,
    required this.loadBytesFromRuleEngine,
    required this.saveImageSizeSnapshot,
    required this.getImageSizeSnapshot,
  });
}

/// Manages image pre-warming, size probing, and persistence
/// for the paged reader.
///
/// Extracted from `_SimpleReaderViewState` to reduce file size
/// while keeping the same logic and data flow.
class ReaderImageWarmupHelper {
  ReaderImageWarmupHelper(this._ctx);

  final ReaderImageWarmupContext _ctx;

  // ── Constants ─────────────────────────────────────────────

  static const int chapterLoadMaxProbeCount = 8;
  static const Duration chapterLoadMaxDuration =
      Duration(milliseconds: 260);
  static const int prefetchMaxProbeCount = 6;
  static const Duration prefetchMaxDuration =
      Duration(milliseconds: 180);
  static const int persistedSnapshotMaxEntries = 180;

  static const String legacyImageStyleText = 'TEXT';
  static const String legacyImageStyleSingle = 'SINGLE';
  static const String legacyImageStyleFull = 'FULL';

  static const double _longImageAspectRatioThreshold = 1.6;
  static const double _longImageErrorBoostThreshold = 0.22;

  static const List<String> _legacyImageWidthQueryKeys = <String>[
    'w', 'width', 'imgw', 'img_width', 'imagewidth',
    'ow', 'origw', 'srcw',
  ];
  static const List<String> _legacyImageHeightQueryKeys = <String>[
    'h', 'height', 'imgh', 'img_height', 'imageheight',
    'oh', 'origh', 'srch',
  ];
  static final List<RegExp> _legacyImageWidthUrlPatterns = <RegExp>[
    RegExp(
      r'[?&](?:w|width|imgw|img_width|imagewidth|ow|origw|srcw)=([0-9]+(?:\.[0-9]+)?)',
      caseSensitive: false,
    ),
    RegExp(
      r'(?:^|[?&,_/\.-])w_([0-9]+(?:\.[0-9]+)?)(?:[?&,_/\.-]|$)',
      caseSensitive: false,
    ),
  ];
  static final List<RegExp> _legacyImageHeightUrlPatterns = <RegExp>[
    RegExp(
      r'[?&](?:h|height|imgh|img_height|imageheight|oh|origh|srch)=([0-9]+(?:\.[0-9]+)?)',
      caseSensitive: false,
    ),
    RegExp(
      r'(?:^|[?&,_/\.-])h_([0-9]+(?:\.[0-9]+)?)(?:[?&,_/\.-]|$)',
      caseSensitive: false,
    ),
  ];

  static final RegExp _cssStyleAttrRegex = RegExp(
    r'''style\s*=\s*(?:"([^"]*)"|'([^']*)')''',
    caseSensitive: false,
  );

  // ── Mutable state ─────────────────────────────────────────

  bool _pendingImageSizeRepagination = false;
  final Set<String> _imageSizeWarmupInFlight = <String>{};
  Timer? _imageSizeSnapshotPersistTimer;
  final Set<String> _bookImageSizeCacheKeys = <String>{};
  final Map<String, ReaderImageMarkerMeta> _chapterImageMetaByCacheKey =
      <String, ReaderImageMarkerMeta>{};
  double _longImageFirstFrameErrorEma = 0.0;
  int _longImageFirstFrameErrorSamples = 0;
  final Map<String, ReaderImageWarmupSourceTelemetry>
      _imageWarmupTelemetryBySource =
      <String, ReaderImageWarmupSourceTelemetry>{};

  // ── Public getters ────────────────────────────────────────

  bool get pendingImageSizeRepagination => _pendingImageSizeRepagination;
  set pendingImageSizeRepagination(bool v) =>
      _pendingImageSizeRepagination = v;

  Set<String> get bookImageSizeCacheKeys => _bookImageSizeCacheKeys;

  Map<String, ReaderImageMarkerMeta> get chapterImageMetaByCacheKey =>
      _chapterImageMetaByCacheKey;

  // ── Lifecycle ─────────────────────────────────────────────

  /// Cancel any pending persist timer. Should be called in
  /// dispose before [persistSnapshot].
  void cancelPersistTimer() {
    _imageSizeSnapshotPersistTimer?.cancel();
    _imageSizeSnapshotPersistTimer = null;
  }

  // ── Snapshot persistence / restoration ────────────────────

  /// Restores the image size cache from persisted snapshot.
  Future<void> restoreSnapshot() async {
    if (_ctx.isEphemeral()) return;
    final rawSnapshot = _ctx.getImageSizeSnapshot(_ctx.bookId);
    if (rawSnapshot == null || rawSnapshot.trim().isEmpty) {
      return;
    }
    try {
      final decoded =
          const JsonDecoder().convert(rawSnapshot) as Object?;
      if (decoded is! Map) {
        return;
      }
      final dynamic rawEntries = decoded['entries'] ?? decoded;
      if (rawEntries is! Map) {
        return;
      }
      final entries =
          rawEntries.map((key, value) => MapEntry('$key', value));
      ReaderImageMarkerCodec.restoreResolvedSizeCache(
        entries,
        clearBeforeRestore: false,
        maxEntries: persistedSnapshotMaxEntries,
      );
      for (final rawKey in entries.keys) {
        final normalized =
            ReaderImageMarkerCodec.normalizeResolvedSizeKey(rawKey);
        if (normalized.isNotEmpty) {
          _bookImageSizeCacheKeys.add(normalized);
        }
      }
    } catch (_) {
      // 快照解析失败时忽略，不阻断阅读主流程。
    }
  }

  /// Schedules a debounced persist of the image size snapshot.
  void schedulePersistSnapshot() {
    if (_ctx.isEphemeral()) return;
    _imageSizeSnapshotPersistTimer?.cancel();
    _imageSizeSnapshotPersistTimer =
        Timer(const Duration(milliseconds: 680), () {
      _imageSizeSnapshotPersistTimer = null;
      unawaited(persistSnapshot());
    });
  }

  /// Persists the current image size cache to storage.
  Future<void> persistSnapshot({bool force = false}) async {
    if (_ctx.isEphemeral()) return;
    if (!force && _bookImageSizeCacheKeys.isEmpty) return;
    try {
      final snapshot = ReaderImageMarkerCodec.snapshotResolvedSizeCache(
        keys: _bookImageSizeCacheKeys,
        maxEntries: persistedSnapshotMaxEntries,
      );
      final payload = snapshot.isEmpty
          ? ''
          : _jsonEncode(<String, dynamic>{
              'v': 1,
              'entries': snapshot,
            });
      await _ctx.saveImageSizeSnapshot(_ctx.bookId, payload);
    } catch (_) {
      // 持久化失败时忽略，不影响阅读链路。
    }
  }

  // ── Cache key bookkeeping ─────────────────────────────────

  /// Remembers a normalized cache key for a given image src.
  void rememberBookImageCacheKey(String src) {
    final normalized =
        ReaderImageMarkerCodec.normalizeResolvedSizeKey(src);
    if (normalized.isEmpty) return;
    _bookImageSizeCacheKeys.add(normalized);
  }

  /// Looks up a chapter image meta by normalized cache key.
  ReaderImageMarkerMeta? lookupCurrentChapterImageMeta(
    String src,
  ) {
    final key =
        ReaderImageMarkerCodec.normalizeResolvedSizeKey(src);
    if (key.isEmpty) return null;
    return _chapterImageMetaByCacheKey[key];
  }

  // ── Long-image first-frame error tracking ─────────────────

  /// Records a sample for the long-image first-frame error EMA.
  void recordLongImageFirstFrameErrorSample({
    required String src,
    required Size resolvedSize,
    ReaderImageMarkerMeta? hintMeta,
    required String normalizedImageStyle,
  }) {
    final width = resolvedSize.width;
    final height = resolvedSize.height;
    if (!width.isFinite ||
        !height.isFinite ||
        width <= 0 ||
        height <= 0) {
      return;
    }
    final actualRatio = height / width;
    if (!actualRatio.isFinite ||
        actualRatio <= _longImageAspectRatioThreshold) {
      return;
    }
    final hintedRatio = _hintMetaAspectRatio(hintMeta);
    final fallbackRatio =
        _fallbackFirstFrameAspectRatio(normalizedImageStyle);
    final expectedRatio = hintedRatio ?? fallbackRatio;
    if (!expectedRatio.isFinite || expectedRatio <= 0) {
      return;
    }
    final error =
        ((expectedRatio - actualRatio).abs() / actualRatio)
            .clamp(0.0, 1.0)
            .toDouble();
    if (!error.isFinite) return;
    if (_longImageFirstFrameErrorSamples <= 0) {
      _longImageFirstFrameErrorEma = error;
    } else {
      _longImageFirstFrameErrorEma =
          _longImageFirstFrameErrorEma * 0.78 + error * 0.22;
    }
    _longImageFirstFrameErrorSamples =
        (_longImageFirstFrameErrorSamples + 1).clamp(0, 4096).toInt();
    rememberBookImageCacheKey(src);
  }

  double? _hintMetaAspectRatio(ReaderImageMarkerMeta? meta) {
    if (meta == null || !meta.hasDimensionHints) return null;
    final width = meta.width!;
    final height = meta.height!;
    if (!width.isFinite ||
        !height.isFinite ||
        width <= 0 ||
        height <= 0) {
      return null;
    }
    final ratio = height / width;
    if (!ratio.isFinite || ratio <= 0) return null;
    return ratio;
  }

  double _fallbackFirstFrameAspectRatio(String imageStyle) {
    switch (imageStyle) {
      case legacyImageStyleSingle:
        return 1.0;
      case legacyImageStyleFull:
        return 0.75;
      default:
        return 0.62;
    }
  }

  // ── Paged image size resolution callbacks ─────────────────

  /// Called when PagedReaderWidget resolves a single image's
  /// intrinsic size.
  void handlePagedImageSizeResolved(String src, Size size) {
    recordLongImageFirstFrameErrorSample(
      src: src,
      resolvedSize: size,
      hintMeta: lookupCurrentChapterImageMeta(src),
      normalizedImageStyle: _ctx.normalizedImageStyle(),
    );
    schedulePersistSnapshot();
  }

  /// Called when the paged reader's internal image size cache
  /// changes (e.g. after an image finishes loading).
  void handlePagedImageSizeCacheUpdated(
    void Function() repaginate,
  ) {
    if (_ctx.isScrollMode()) return;
    schedulePersistSnapshot();
    if (_pendingImageSizeRepagination) return;
    _pendingImageSizeRepagination = true;
    _ctx.onImageSizeCacheUpdated();
  }

  // ── Telemetry ─────────────────────────────────────────────

  String _resolveWarmupTelemetrySourceKey(BookSource? source) {
    final sourceUrl = (source?.bookSourceUrl ??
            _ctx.currentSourceUrl() ??
            _ctx.effectiveSourceUrl() ??
            '')
        .trim();
    if (sourceUrl.isNotEmpty) {
      return sourceUrl;
    }
    return '__global__';
  }

  ReaderImageWarmupSourceTelemetry _telemetryForSource(
    BookSource? source,
  ) {
    final key = _resolveWarmupTelemetrySourceKey(source);
    final cached = _imageWarmupTelemetryBySource[key];
    if (cached != null) {
      return cached;
    }
    if (_imageWarmupTelemetryBySource.length >= 48) {
      String? staleKey;
      DateTime? staleAt;
      _imageWarmupTelemetryBySource.forEach((mapKey, telemetry) {
        if (staleAt == null ||
            telemetry.updatedAt.isBefore(staleAt!)) {
          staleKey = mapKey;
          staleAt = telemetry.updatedAt;
        }
      });
      if (staleKey != null) {
        _imageWarmupTelemetryBySource.remove(staleKey);
      }
    }
    final created = ReaderImageWarmupSourceTelemetry();
    _imageWarmupTelemetryBySource[key] = created;
    return created;
  }

  ReaderImageWarmupSourceTelemetry? _telemetrySnapshotForSource(
    BookSource? source,
  ) {
    final key = _resolveWarmupTelemetrySourceKey(source);
    return _imageWarmupTelemetryBySource[key];
  }

  void _recordWarmupProbeSuccessForSource(BookSource? source) {
    _telemetryForSource(source).recordSuccess();
  }

  void _recordWarmupProbeFailureForSource(
    ReaderImageWarmupFailureKind kind,
    BookSource? source,
  ) {
    _telemetryForSource(source).recordFailure(kind);
  }

  // ── Error classification ──────────────────────────────────

  ReaderImageWarmupFailureKind mergeWarmupFailureKind(
    ReaderImageWarmupFailureKind? current,
    ReaderImageWarmupFailureKind candidate,
  ) {
    if (current == null) {
      return candidate;
    }
    if (current == ReaderImageWarmupFailureKind.timeout ||
        candidate == ReaderImageWarmupFailureKind.timeout) {
      return ReaderImageWarmupFailureKind.timeout;
    }
    if (current == ReaderImageWarmupFailureKind.auth ||
        candidate == ReaderImageWarmupFailureKind.auth) {
      return ReaderImageWarmupFailureKind.auth;
    }
    if (current == ReaderImageWarmupFailureKind.decode ||
        candidate == ReaderImageWarmupFailureKind.decode) {
      return ReaderImageWarmupFailureKind.decode;
    }
    return ReaderImageWarmupFailureKind.other;
  }

  ReaderImageWarmupFailureKind classifyWarmupProbeError(
    Object error,
  ) {
    if (error is TimeoutException) {
      return ReaderImageWarmupFailureKind.timeout;
    }
    final statusCode = _extractStatusCodeFromProbeError(error);
    if (statusCode == 401 || statusCode == 403) {
      return ReaderImageWarmupFailureKind.auth;
    }
    final message = '$error'.toLowerCase();
    if (_looksLikeTimeoutMessage(message)) {
      return ReaderImageWarmupFailureKind.timeout;
    }
    if (_looksLikeAuthFailureMessage(message)) {
      return ReaderImageWarmupFailureKind.auth;
    }
    if (_looksLikeDecodeFailureMessage(message)) {
      return ReaderImageWarmupFailureKind.decode;
    }
    return ReaderImageWarmupFailureKind.other;
  }

  int? _extractStatusCodeFromProbeError(Object error) {
    try {
      final dynamic dynamicError = error;
      final value = dynamicError.statusCode;
      if (value is int) {
        return value;
      }
    } catch (_) {
      // ignore statusCode extract failure
    }
    return null;
  }

  bool _looksLikeTimeoutMessage(String message) {
    return message.contains('timeout') ||
        message.contains('timed out') ||
        message.contains('deadline exceeded');
  }

  bool _looksLikeAuthFailureMessage(String message) {
    return message.contains('unauthorized') ||
        message.contains('forbidden') ||
        message.contains('401') ||
        message.contains('403') ||
        message.contains('cookie') ||
        message.contains('referer') ||
        message.contains('origin') ||
        message.contains('login required');
  }

  bool _looksLikeDecodeFailureMessage(String message) {
    return message.contains('decode') ||
        message.contains('codec') ||
        message.contains('unsupported image') ||
        message.contains('invalid image') ||
        message.contains('format exception');
  }

  // ── Main warmup entry point ───────────────────────────────

  /// Probes image sizes for paged content and caches results.
  /// Returns `true` if the size cache was updated.
  Future<bool> warmupPagedImageSizeCache(
    String content, {
    int maxProbeCount = 8,
    Duration maxDuration = const Duration(milliseconds: 260),
  }) async {
    if (_ctx.isScrollMode()) return false;
    final imageStyle = _ctx.normalizedImageStyle();
    if (imageStyle == legacyImageStyleText) return false;
    final budget = _resolveImageWarmupBudget(
      baseProbeCount: maxProbeCount,
      baseDuration: maxDuration,
    );

    final metas = collectUniqueImageMarkerMetas(
      content,
      maxCount: budget.probeCount,
    );
    if (metas.isEmpty) return false;

    final deadline = DateTime.now().add(budget.maxDuration);
    final source = _ctx.currentSource();
    var changed = false;

    for (final meta in metas) {
      final src = meta.src.trim();
      if (src.isEmpty) continue;
      rememberBookImageCacheKey(src);
      final request = ReaderImageRequestParser.parse(src);

      if (meta.hasDimensionHints) {
        changed = ReaderImageMarkerCodec.rememberResolvedSize(
              src,
              width: meta.width!,
              height: meta.height!,
            ) ||
            changed;
      }

      if (ReaderImageMarkerCodec.lookupResolvedSize(src) != null) {
        continue;
      }

      final remaining = deadline.difference(DateTime.now());
      if (remaining <= Duration.zero) {
        break;
      }
      if (_imageSizeWarmupInFlight.contains(src)) {
        continue;
      }

      await _ctx.ensureCookieHeaderCached(
        request,
        timeout: _clampWarmupDuration(
          remaining,
          max: const Duration(milliseconds: 140),
        ),
      );

      final imageProvider = _ctx.resolveImageProvider(request);

      _imageSizeWarmupInFlight.add(src);
      try {
        final probeTimeout = _clampWarmupDuration(
          remaining,
          max: budget.perProbeTimeout,
        );
        Size? resolved;
        ReaderImageWarmupFailureKind? failureKind;
        var attempted = false;
        if (imageProvider != null) {
          final providerProbe = await resolveImageIntrinsicSize(
            imageProvider,
            timeout: probeTimeout,
          );
          attempted = attempted || providerProbe.attempted;
          resolved = providerProbe.size;
          if (providerProbe.failureKind != null) {
            failureKind = mergeWarmupFailureKind(
              failureKind,
              providerProbe.failureKind!,
            );
          }
        }
        if (resolved == null) {
          final sourceAwareProbe =
              await _resolveImageIntrinsicSizeFromSourceAwareFetch(
            request,
            timeout: probeTimeout,
          );
          attempted = attempted || sourceAwareProbe.attempted;
          resolved = sourceAwareProbe.size;
          if (sourceAwareProbe.failureKind != null) {
            failureKind = mergeWarmupFailureKind(
              failureKind,
              sourceAwareProbe.failureKind!,
            );
          }
        }
        if (resolved == null) {
          if (attempted) {
            _recordWarmupProbeFailureForSource(
              failureKind ?? ReaderImageWarmupFailureKind.other,
              source,
            );
          }
          continue;
        }
        _recordWarmupProbeSuccessForSource(source);
        recordLongImageFirstFrameErrorSample(
          src: src,
          resolvedSize: resolved,
          hintMeta: meta,
          normalizedImageStyle: _ctx.normalizedImageStyle(),
        );
        changed = ReaderImageMarkerCodec.rememberResolvedSize(
              src,
              width: resolved.width,
              height: resolved.height,
            ) ||
            changed;
      } finally {
        _imageSizeWarmupInFlight.remove(src);
      }
    }

    if (changed) {
      schedulePersistSnapshot();
    }
    return changed;
  }

  // ── Budget resolution ─────────────────────────────────────

  ReaderImageWarmupBudget _resolveImageWarmupBudget({
    required int baseProbeCount,
    required Duration baseDuration,
  }) {
    var probeCount = baseProbeCount;
    var durationMs = baseDuration.inMilliseconds;
    final source = _ctx.currentSource();
    final telemetry = _telemetrySnapshotForSource(source);

    final sampledLatencyMs =
        _ctx.recentChapterFetchDuration().inMilliseconds > 0
            ? _ctx.recentChapterFetchDuration().inMilliseconds
            : (source?.respondTime ?? 0);

    if (sampledLatencyMs > 0) {
      final boostedDuration =
          durationMs + (sampledLatencyMs * 0.6).round();
      durationMs = boostedDuration.clamp(durationMs, 980);
      if (sampledLatencyMs >= 900) {
        probeCount += 3;
      } else if (sampledLatencyMs >= 600) {
        probeCount += 2;
      } else if (sampledLatencyMs >= 350) {
        probeCount += 1;
      }
    }

    if ((source?.loginUrl ?? '').trim().isNotEmpty) {
      durationMs = (durationMs + 120)
          .clamp(baseDuration.inMilliseconds, 980);
      probeCount += 1;
    }

    if (_longImageFirstFrameErrorSamples >= 3 &&
        _longImageFirstFrameErrorEma >=
            _longImageErrorBoostThreshold) {
      final errorBoostMs =
          (_longImageFirstFrameErrorEma * 320)
              .round()
              .clamp(90, 260);
      durationMs = (durationMs + errorBoostMs)
          .clamp(baseDuration.inMilliseconds, 1200);
      probeCount +=
          _longImageFirstFrameErrorEma >= 0.45 ? 3 : 2;
    }

    if (telemetry != null && telemetry.sampleCount >= 3) {
      if (telemetry.timeoutRateEma >= 0.16 ||
          telemetry.timeoutStreak >= 2) {
        final timeoutBoostMs =
            (telemetry.timeoutRateEma * 420)
                    .round()
                    .clamp(70, 340) +
                telemetry.timeoutStreak * 45;
        durationMs = (durationMs + timeoutBoostMs)
            .clamp(baseDuration.inMilliseconds, 1450);
        probeCount +=
            telemetry.timeoutRateEma >= 0.34 ? 3 : 2;
      }
      if (telemetry.authRateEma >= 0.10 ||
          telemetry.authStreak >= 1) {
        final authBoostMs =
            (120 + telemetry.authRateEma * 210)
                .round()
                .clamp(110, 280);
        durationMs = (durationMs + authBoostMs)
            .clamp(baseDuration.inMilliseconds, 1450);
        probeCount +=
            telemetry.authRateEma >= 0.26 ? 2 : 1;
      }
      if (telemetry.decodeRateEma >= 0.16 ||
          telemetry.decodeStreak >= 2) {
        durationMs = (durationMs + 70)
            .clamp(baseDuration.inMilliseconds, 1450);
        probeCount += 1;
      }
      if (telemetry.successRateEma >= 0.78 &&
          telemetry.timeoutRateEma <= 0.06 &&
          telemetry.sampleCount >= 8) {
        probeCount -= 1;
      }
    }

    probeCount = probeCount.clamp(baseProbeCount, 18);
    final maxDuration = Duration(milliseconds: durationMs);
    var perProbeTimeoutMs = (durationMs * 0.46).round();
    if (telemetry != null && telemetry.sampleCount >= 3) {
      if (telemetry.timeoutRateEma >= 0.20 ||
          telemetry.timeoutStreak >= 2) {
        perProbeTimeoutMs += 70;
      }
      if (telemetry.authRateEma >= 0.12) {
        perProbeTimeoutMs += 40;
      }
    }
    final perProbeTimeout = Duration(
      milliseconds: perProbeTimeoutMs.clamp(180, 620),
    );
    return ReaderImageWarmupBudget(
      probeCount: probeCount,
      maxDuration: maxDuration,
      perProbeTimeout: perProbeTimeout,
    );
  }

  Duration _clampWarmupDuration(
    Duration remaining, {
    required Duration max,
  }) {
    if (remaining <= Duration.zero) return Duration.zero;
    if (remaining < max) return remaining;
    return max;
  }

  // ── Source-aware fetch probe ───────────────────────────────

  Future<ReaderImageSizeProbeResult>
      _resolveImageIntrinsicSizeFromSourceAwareFetch(
    ReaderImageRequest request, {
    Duration timeout = const Duration(milliseconds: 220),
  }) async {
    if (timeout <= Duration.zero) {
      return const ReaderImageSizeProbeResult.skipped();
    }
    final source = _ctx.currentSource();
    if (source == null) {
      return const ReaderImageSizeProbeResult.skipped();
    }
    final normalizedUrl = request.url.trim();
    if (normalizedUrl.isEmpty) {
      return const ReaderImageSizeProbeResult.skipped();
    }
    if (normalizedUrl.toLowerCase().startsWith('data:image')) {
      return const ReaderImageSizeProbeResult.skipped();
    }
    final uri = Uri.tryParse(normalizedUrl);
    if (uri != null && uri.hasScheme && !_ctx.isHttpLikeUri(uri)) {
      return const ReaderImageSizeProbeResult.skipped();
    }

    final rawImageUrl =
        request.raw.isEmpty ? request.url : request.raw;
    final attemptTimeouts =
        _buildSourceAwareProbeTimeouts(timeout);
    var attempted = false;
    ReaderImageWarmupFailureKind? failureKind;
    for (var i = 0; i < attemptTimeouts.length; i++) {
      final probeTimeout = attemptTimeouts[i];
      if (probeTimeout <= Duration.zero) {
        continue;
      }
      attempted = true;

      final bytesProbe = i == 0
          ? await _loadImageBytesFromSourceAwareLoader(
              source: source,
              imageUrl: rawImageUrl,
              timeout: probeTimeout,
            )
          : await _loadImageBytesFromRuleEngine(
              source: source,
              imageUrl: rawImageUrl,
              timeout: probeTimeout,
            );
      if (bytesProbe.failureKind != null) {
        failureKind = mergeWarmupFailureKind(
          failureKind,
          bytesProbe.failureKind!,
        );
      }
      final bytes = bytesProbe.bytes;
      if (bytes == null || bytes.isEmpty) {
        continue;
      }
      final size = await decodeImageSizeFromBytes(bytes);
      if (size != null) {
        return ReaderImageSizeProbeResult.success(size);
      }
      failureKind = mergeWarmupFailureKind(
        failureKind,
        ReaderImageWarmupFailureKind.decode,
      );
    }
    if (!attempted) {
      return const ReaderImageSizeProbeResult.skipped();
    }
    return ReaderImageSizeProbeResult.failure(
      failureKind ?? ReaderImageWarmupFailureKind.other,
    );
  }

  List<Duration> _buildSourceAwareProbeTimeouts(
    Duration totalTimeout,
  ) {
    final totalMs = totalTimeout.inMilliseconds;
    if (totalMs <= 0) return const <Duration>[];
    if (totalMs <= 240) {
      return <Duration>[Duration(milliseconds: totalMs)];
    }

    int clampInt(int value, int min, int max) {
      if (value < min) return min;
      if (value > max) return max;
      return value;
    }

    final attempts = <Duration>[];
    var remainingMs = totalMs;

    void take(int candidateMs) {
      if (remainingMs <= 0) return;
      final bounded = clampInt(candidateMs, 1, remainingMs);
      attempts.add(Duration(milliseconds: bounded));
      remainingMs -= bounded;
    }

    final firstTarget =
        clampInt((totalMs * 0.44).round(), 140, 260);
    take(firstTarget);
    if (remainingMs <= 0) return attempts;

    final secondTarget =
        clampInt((totalMs * 0.36).round(), 120, 360);
    if (remainingMs >= 120) {
      take(secondTarget);
    }
    if (remainingMs > 0) {
      take(remainingMs);
    }
    return attempts;
  }

  Future<ReaderImageBytesProbeResult>
      _loadImageBytesFromSourceAwareLoader({
    required BookSource source,
    required String imageUrl,
    required Duration timeout,
  }) async {
    try {
      final bytes = await _ctx
          .loadBytesFromSourceLoader(
            source: source,
            imageUrl: imageUrl,
          )
          .timeout(timeout);
      if (bytes == null || bytes.isEmpty) {
        return const ReaderImageBytesProbeResult.failure(
          ReaderImageWarmupFailureKind.other,
        );
      }
      return ReaderImageBytesProbeResult.success(bytes);
    } on TimeoutException {
      return const ReaderImageBytesProbeResult.failure(
        ReaderImageWarmupFailureKind.timeout,
      );
    } catch (error) {
      return ReaderImageBytesProbeResult.failure(
        classifyWarmupProbeError(error),
      );
    }
  }

  Future<ReaderImageBytesProbeResult>
      _loadImageBytesFromRuleEngine({
    required BookSource source,
    required String imageUrl,
    required Duration timeout,
  }) async {
    try {
      final bytes = await _ctx
          .loadBytesFromRuleEngine(
            source: source,
            imageUrl: imageUrl,
          )
          .timeout(timeout);
      if (bytes == null || bytes.isEmpty) {
        return const ReaderImageBytesProbeResult.failure(
          ReaderImageWarmupFailureKind.other,
        );
      }
      return ReaderImageBytesProbeResult.success(bytes);
    } on TimeoutException {
      return const ReaderImageBytesProbeResult.failure(
        ReaderImageWarmupFailureKind.timeout,
      );
    } catch (error) {
      return ReaderImageBytesProbeResult.failure(
        classifyWarmupProbeError(error),
      );
    }
  }

  // ── Image decoding ────────────────────────────────────────

  /// Decodes image dimensions from raw bytes.
  Future<Size?> decodeImageSizeFromBytes(Uint8List bytes) async {
    if (bytes.isEmpty) return null;
    try {
      final codec = await ui.instantiateImageCodec(bytes);
      try {
        final frame = await codec.getNextFrame();
        final image = frame.image;
        final width = image.width.toDouble();
        final height = image.height.toDouble();
        image.dispose();
        if (!width.isFinite ||
            !height.isFinite ||
            width <= 0 ||
            height <= 0) {
          return null;
        }
        return Size(width, height);
      } finally {
        codec.dispose();
      }
    } catch (_) {
      return null;
    }
  }

  /// Resolves the intrinsic size of an image via its
  /// [ImageProvider].
  Future<ReaderImageSizeProbeResult> resolveImageIntrinsicSize(
    ImageProvider<Object> imageProvider, {
    Duration timeout = const Duration(milliseconds: 220),
  }) async {
    if (timeout <= Duration.zero) {
      return const ReaderImageSizeProbeResult.skipped();
    }
    final completer = Completer<ReaderImageSizeProbeResult>();
    final stream =
        imageProvider.resolve(const ImageConfiguration());
    ImageStreamListener? listener;
    Timer? timer;

    void finish(ReaderImageSizeProbeResult value) {
      if (completer.isCompleted) return;
      if (listener != null) {
        stream.removeListener(listener);
      }
      timer?.cancel();
      completer.complete(value);
    }

    listener = ImageStreamListener(
      (ImageInfo info, bool synchronousCall) {
        final width = info.image.width.toDouble();
        final height = info.image.height.toDouble();
        if (!width.isFinite ||
            !height.isFinite ||
            width <= 0 ||
            height <= 0) {
          finish(
            const ReaderImageSizeProbeResult.failure(
              ReaderImageWarmupFailureKind.decode,
            ),
          );
          return;
        }
        finish(
          ReaderImageSizeProbeResult.success(Size(width, height)),
        );
      },
      onError: (Object error, StackTrace? stackTrace) {
        finish(
          ReaderImageSizeProbeResult.failure(
            classifyWarmupProbeError(error),
          ),
        );
      },
    );

    stream.addListener(listener);
    timer = Timer(
      timeout,
      () => finish(
        const ReaderImageSizeProbeResult.failure(
          ReaderImageWarmupFailureKind.timeout,
        ),
      ),
    );
    return completer.future;
  }

  // ── Image dimension hint extraction ───────────────────────

  /// Extracts width/height hints from an `<img>` tag's
  /// attributes and inline style.
  Size? extractImageDimensionHintsFromTag(String imgTag) {
    if (imgTag.isEmpty) return null;
    var width = _extractImageDimensionFromAttribute(
          imgTag,
          attribute: 'width',
        ) ??
        _extractImageDimensionFromInlineStyle(
          imgTag,
          property: 'width',
        );
    var height = _extractImageDimensionFromAttribute(
          imgTag,
          attribute: 'height',
        ) ??
        _extractImageDimensionFromInlineStyle(
          imgTag,
          property: 'height',
        );
    final aspectRatio =
        _extractImageAspectRatioFromInlineStyle(imgTag);
    if (aspectRatio != null) {
      if (width != null && height == null) {
        height = width / aspectRatio;
      } else if (height != null && width == null) {
        width = height * aspectRatio;
      }
    }
    if (width == null || height == null) {
      return null;
    }
    return Size(width, height);
  }

  double? _extractImageDimensionFromAttribute(
    String imgTag, {
    required String attribute,
  }) {
    final attrRegex = RegExp(
      '''$attribute\\s*=\\s*("([^"]*)"|'([^']*)'|([^\\s>]+))''',
      caseSensitive: false,
    );
    final match = attrRegex.firstMatch(imgTag);
    if (match == null) return null;
    final raw =
        match.group(2) ?? match.group(3) ?? match.group(4) ?? '';
    return _parseLegacyCssPixelValue(raw);
  }

  double? _extractImageDimensionFromInlineStyle(
    String imgTag, {
    required String property,
  }) {
    final rawValue =
        _extractInlineStyleProperty(imgTag, property: property);
    if (rawValue == null) return null;
    return _parseLegacyCssPixelValue(rawValue);
  }

  double? _extractImageAspectRatioFromInlineStyle(
    String imgTag,
  ) {
    final rawValue = _extractInlineStyleProperty(
      imgTag,
      property: 'aspect-ratio',
    );
    if (rawValue == null) return null;
    final value = rawValue.trim().toLowerCase();
    if (value.isEmpty || value == 'auto') return null;
    final ratioMatch = RegExp(
      r'^([0-9]+(?:\.[0-9]+)?)\s*/\s*([0-9]+(?:\.[0-9]+)?)$',
    ).firstMatch(value);
    if (ratioMatch != null) {
      final numerator =
          double.tryParse(ratioMatch.group(1) ?? '');
      final denominator =
          double.tryParse(ratioMatch.group(2) ?? '');
      if (numerator == null ||
          denominator == null ||
          !numerator.isFinite ||
          !denominator.isFinite ||
          numerator <= 0 ||
          denominator <= 0) {
        return null;
      }
      return numerator / denominator;
    }
    final parsed = double.tryParse(value);
    if (parsed == null || !parsed.isFinite || parsed <= 0) {
      return null;
    }
    return parsed;
  }

  String? _extractInlineStyleProperty(
    String imgTag, {
    required String property,
  }) {
    final styleMatch = _cssStyleAttrRegex.firstMatch(imgTag);
    if (styleMatch == null) return null;
    final styleText =
        (styleMatch.group(1) ?? styleMatch.group(2) ?? '').trim();
    if (styleText.isEmpty) return null;
    final propertyRegex = RegExp(
      '''$property\\s*:\\s*([^;]+)''',
      caseSensitive: false,
    );
    final match = propertyRegex.firstMatch(styleText);
    if (match == null) return null;
    return match.group(1)?.trim();
  }

  /// Extracts width/height hints from URL query parameters
  /// and path patterns.
  Size? extractImageDimensionHintsFromSrcUrl(String rawSrc) {
    final request = ReaderImageRequestParser.parse(rawSrc);
    final normalizedUrl = request.url.trim();
    if (normalizedUrl.isEmpty) return null;
    final uri = Uri.tryParse(normalizedUrl);
    final width = _extractImageDimensionFromUrl(
      uri: uri,
      url: normalizedUrl,
      queryKeys: _legacyImageWidthQueryKeys,
      urlPatterns: _legacyImageWidthUrlPatterns,
    );
    final height = _extractImageDimensionFromUrl(
      uri: uri,
      url: normalizedUrl,
      queryKeys: _legacyImageHeightQueryKeys,
      urlPatterns: _legacyImageHeightUrlPatterns,
    );
    if (width == null || height == null) {
      return null;
    }
    return Size(width, height);
  }

  double? _extractImageDimensionFromUrl({
    required Uri? uri,
    required String url,
    required List<String> queryKeys,
    required List<RegExp> urlPatterns,
  }) {
    if (uri != null && uri.queryParameters.isNotEmpty) {
      final normalizedQuery = <String, String>{};
      uri.queryParameters.forEach((key, value) {
        final normalizedKey = key.trim().toLowerCase();
        final normalizedValue = value.trim();
        if (normalizedKey.isEmpty || normalizedValue.isEmpty) {
          return;
        }
        normalizedQuery[normalizedKey] = normalizedValue;
      });
      for (final key in queryKeys) {
        final value = normalizedQuery[key.toLowerCase()];
        final parsed = _parsePositiveDimensionFromText(value);
        if (parsed != null) {
          return parsed;
        }
      }
    }

    for (final pattern in urlPatterns) {
      final match = pattern.firstMatch(url);
      if (match == null) continue;
      final parsed =
          _parsePositiveDimensionFromText(match.group(1));
      if (parsed != null) {
        return parsed;
      }
    }
    return null;
  }

  double? _parsePositiveDimensionFromText(String? raw) {
    if (raw == null) return null;
    final match =
        RegExp(r'([0-9]+(?:\.[0-9]+)?)').firstMatch(raw.trim());
    if (match == null) return null;
    final parsed = double.tryParse(match.group(1) ?? '');
    if (parsed == null || !parsed.isFinite || parsed <= 0) {
      return null;
    }
    return parsed;
  }

  double? _parseLegacyCssPixelValue(String raw) {
    final value = raw.trim().toLowerCase();
    if (value.isEmpty || value.contains('%')) return null;
    final match =
        RegExp(r'^([0-9]+(?:\.[0-9]+)?)(px)?$').firstMatch(value);
    if (match == null) return null;
    final parsed = double.tryParse(match.group(1) ?? '');
    if (parsed == null || !parsed.isFinite || parsed <= 0) {
      return null;
    }
    return parsed;
  }

  // ── Image marker collection ───────────────────────────────

  /// Collects unique image marker metas from content text.
  List<ReaderImageMarkerMeta> collectUniqueImageMarkerMetas(
    String content, {
    int maxCount = 24,
  }) {
    if (content.isEmpty ||
        !ReaderImageMarkerCodec.containsMarker(content)) {
      return const <ReaderImageMarkerMeta>[];
    }
    final lines = content.replaceAll('\r\n', '\n').split('\n');
    final seen = <String>{};
    final metas = <ReaderImageMarkerMeta>[];
    for (final line in lines) {
      if (metas.length >= maxCount) {
        break;
      }
      final meta = ReaderImageMarkerCodec.decodeMetaLine(line);
      if (meta == null) {
        continue;
      }
      final normalizedSrc = _ctx.normalizeImageSrc(meta.src);
      final normalizedKey =
          ReaderImageMarkerCodec.normalizeResolvedSizeKey(
        normalizedSrc,
      );
      if (normalizedSrc.isEmpty ||
          normalizedKey.isEmpty ||
          !seen.add(normalizedKey)) {
        continue;
      }
      _bookImageSizeCacheKeys.add(normalizedKey);
      metas.add(
        ReaderImageMarkerMeta(
          src: normalizedSrc,
          width: meta.width,
          height: meta.height,
        ),
      );
    }
    return metas;
  }

  // ── Helpers ───────────────────────────────────────────────

  static String _jsonEncode(Object? value) {
    return const JsonEncoder().convert(value);
  }
}
