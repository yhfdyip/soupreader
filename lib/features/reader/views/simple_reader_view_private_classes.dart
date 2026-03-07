part of 'simple_reader_view.dart';

class _ReaderContentEditPayload {
  final String title;
  final String content;

  const _ReaderContentEditPayload({
    required this.title,
    required this.content,
  });
}

class _ReaderContentEditorPage extends StatefulWidget {
  final String initialTitle;
  final String initialContent;
  final Future<String> Function()? onResetContent;

  const _ReaderContentEditorPage({
    required this.initialTitle,
    required this.initialContent,
    this.onResetContent,
  });

  @override
  State<_ReaderContentEditorPage> createState() =>
      _ReaderContentEditorPageState();
}

class _ReaderContentEditorPageState extends State<_ReaderContentEditorPage> {
  late final TextEditingController _titleController;
  late final TextEditingController _contentController;
  bool _returned = false;
  bool _resetting = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.initialTitle);
    _contentController = TextEditingController(text: widget.initialContent);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  void _popWithPayload() {
    if (_returned || _resetting) return;
    _returned = true;
    Navigator.of(context).pop(
      _ReaderContentEditPayload(
        title: _titleController.text,
        content: _contentController.text,
      ),
    );
  }

  Future<void> _copyAll() async {
    final payload = '${_titleController.text}\n${_contentController.text}';
    try {
      await Clipboard.setData(ClipboardData(text: payload));
    } catch (error, stackTrace) {
      ExceptionLogService().record(
        node: 'reader.menu.content_edit.copy_all.failed',
        message: '拷贝所有失败',
        error: error,
        stackTrace: stackTrace,
        context: <String, dynamic>{
          'payloadLength': payload.length,
        },
      );
      return;
    }
    if (!mounted) return;
    _showCopyToast('已拷贝');
  }

  void _showCopyToast(String message) {
    if (!mounted) return;
    showCupertinoBottomSheetDialog<void>(
      context: context,
      barrierColor: CupertinoColors.black.withValues(alpha: 0.08),
      builder: (toastContext) {
        final navigator = Navigator.of(toastContext);
        unawaited(Future<void>.delayed(const Duration(milliseconds: 1100), () {
          if (navigator.mounted && navigator.canPop()) {
            navigator.pop();
          }
        }));
        return SafeArea(
          top: false,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 28),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                  decoration: BoxDecoration(
                    color: CupertinoColors.systemBackground
                        .resolveFrom(context)
                        .withValues(alpha: 0.82),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    message,
                    style: TextStyle(
                      color: CupertinoColors.label.resolveFrom(context),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _moveContentCursorToEnd() {
    _contentController.selection = TextSelection.fromPosition(
      TextPosition(offset: _contentController.text.length),
    );
  }

  Future<void> _resetContent() async {
    if (_resetting) return;
    final handler = widget.onResetContent;
    if (handler == null) {
      _contentController.text = widget.initialContent;
      _moveContentCursorToEnd();
      return;
    }
    setState(() {
      _resetting = true;
    });
    try {
      final content = await handler();
      if (!mounted) return;
      _contentController.text = content;
      _moveContentCursorToEnd();
    } catch (_) {
      // 对齐 legado：重置失败时保持当前编辑内容并静默返回。
    } finally {
      if (!mounted) return;
      setState(() {
        _resetting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop || _resetting) return;
        _popWithPayload();
      },
      child: CupertinoPageScaffold(
        navigationBar: CupertinoNavigationBar(
          middle: const Text('编辑正文'),
          automaticallyImplyLeading: false,
          leading: AppNavBarButton(
            onPressed: _resetting ? null : _popWithPayload,
            child: const Text('关闭'),
          ),
          trailing: AppNavBarButton(
            onPressed: _resetting ? null : _popWithPayload,
            child: const Text('保存'),
          ),
        ),
        child: SafeArea(
          top: false,
          child: Stack(
            fit: StackFit.expand,
            children: [
              IgnorePointer(
                ignoring: _resetting,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
                  child: Column(
                    children: [
                      CupertinoTextField(
                        controller: _titleController,
                        placeholder: '章节标题',
                        enabled: !_resetting,
                        clearButtonMode: OverlayVisibilityMode.editing,
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          CupertinoButton(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            onPressed: _resetting ? null : _resetContent,
                            child: const Text('重置'),
                          ),
                          const SizedBox(width: 8),
                          CupertinoButton(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            onPressed: _resetting ? null : _copyAll,
                            child: const Text('复制全文'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: CupertinoColors.systemBackground.resolveFrom(
                              context,
                            ),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: CupertinoColors.systemGrey4
                                  .resolveFrom(context),
                              width: 0.8,
                            ),
                          ),
                          child: CupertinoTextField(
                            controller: _contentController,
                            enabled: !_resetting,
                            maxLines: null,
                            expands: true,
                            keyboardType: TextInputType.multiline,
                            textAlignVertical: TextAlignVertical.top,
                            clearButtonMode: OverlayVisibilityMode.never,
                            padding: const EdgeInsets.all(12),
                            decoration: null,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (_resetting)
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: CupertinoColors.systemBackground
                          .resolveFrom(context)
                          .withValues(alpha: 0.78),
                    ),
                    child: const Center(
                      child: CupertinoActivityIndicator(radius: 14),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _ReadStyleBgAction {
  asset,
  file,
  clear,
}

class _ReadAloudCapability {
  final bool available;
  final String reason;

  const _ReadAloudCapability({
    required this.available,
    required this.reason,
  });
}

enum _ReaderImageWarmupFailureKind {
  timeout,
  auth,
  decode,
  other,
}

class _ReaderImageSizeProbeResult {
  final Size? size;
  final _ReaderImageWarmupFailureKind? failureKind;
  final bool attempted;

  const _ReaderImageSizeProbeResult._({
    required this.size,
    required this.failureKind,
    required this.attempted,
  });

  const _ReaderImageSizeProbeResult.success(Size value)
      : this._(
          size: value,
          failureKind: null,
          attempted: true,
        );

  const _ReaderImageSizeProbeResult.failure(_ReaderImageWarmupFailureKind kind)
      : this._(
          size: null,
          failureKind: kind,
          attempted: true,
        );

  const _ReaderImageSizeProbeResult.skipped()
      : this._(
          size: null,
          failureKind: null,
          attempted: false,
        );
}

class _ReaderImageBytesProbeResult {
  final Uint8List? bytes;
  final _ReaderImageWarmupFailureKind? failureKind;

  const _ReaderImageBytesProbeResult._({
    required this.bytes,
    required this.failureKind,
  });

  const _ReaderImageBytesProbeResult.success(Uint8List value)
      : this._(
          bytes: value,
          failureKind: null,
        );

  const _ReaderImageBytesProbeResult.failure(_ReaderImageWarmupFailureKind kind)
      : this._(
          bytes: null,
          failureKind: kind,
        );
}

class _ReaderImageWarmupSourceTelemetry {
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

  void recordFailure(_ReaderImageWarmupFailureKind kind) {
    _apply(success: false, failureKind: kind);
  }

  void _apply({
    required bool success,
    required _ReaderImageWarmupFailureKind? failureKind,
  }) {
    final alpha = sampleCount < 8 ? 0.34 : 0.18;
    successRateEma = _ema(successRateEma, success ? 1.0 : 0.0, alpha);
    timeoutRateEma = _ema(
      timeoutRateEma,
      failureKind == _ReaderImageWarmupFailureKind.timeout ? 1.0 : 0.0,
      alpha,
    );
    authRateEma = _ema(
      authRateEma,
      failureKind == _ReaderImageWarmupFailureKind.auth ? 1.0 : 0.0,
      alpha,
    );
    decodeRateEma = _ema(
      decodeRateEma,
      failureKind == _ReaderImageWarmupFailureKind.decode ? 1.0 : 0.0,
      alpha,
    );

    if (success) {
      timeoutStreak = 0;
      authStreak = 0;
      decodeStreak = 0;
    } else {
      switch (failureKind) {
        case _ReaderImageWarmupFailureKind.timeout:
          timeoutStreak = (timeoutStreak + 1).clamp(0, 24).toInt();
          authStreak = 0;
          decodeStreak = 0;
          break;
        case _ReaderImageWarmupFailureKind.auth:
          authStreak = (authStreak + 1).clamp(0, 24).toInt();
          timeoutStreak = 0;
          decodeStreak = 0;
          break;
        case _ReaderImageWarmupFailureKind.decode:
          decodeStreak = (decodeStreak + 1).clamp(0, 24).toInt();
          timeoutStreak = 0;
          authStreak = 0;
          break;
        case _ReaderImageWarmupFailureKind.other:
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

    sampleCount = (sampleCount + 1).clamp(0, 4096).toInt();
    updatedAt = DateTime.now();
  }

  double _ema(double current, double value, double alpha) {
    if (sampleCount <= 0) {
      return value;
    }
    return current * (1 - alpha) + value * alpha;
  }
}

class _ReaderImageWarmupBudget {
  final int probeCount;
  final Duration maxDuration;
  final Duration perProbeTimeout;

  const _ReaderImageWarmupBudget({
    required this.probeCount,
    required this.maxDuration,
    required this.perProbeTimeout,
  });
}

class _ReaderOfflineCacheInput {
  final String startChapter;
  final String endChapter;

  const _ReaderOfflineCacheInput({
    required this.startChapter,
    required this.endChapter,
  });
}

class _ReaderOfflineCacheRange {
  final int startIndex;
  final int endIndex;

  const _ReaderOfflineCacheRange({
    required this.startIndex,
    required this.endIndex,
  });
}

enum _ReaderTextActionMenuAction {
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

enum _ReaderAudioPlayMenuAction {
  login,
  changeSource,
  copyAudioUrl,
  editSource,
  wakeLock,
  log,
}

class _DuplicateTitleRemovalResult {
  final String content;
  final bool removed;

  const _DuplicateTitleRemovalResult({
    required this.content,
    required this.removed,
  });
}

class _ReaderSimulatedReadingInput {
  final bool enabled;
  final String startChapter;
  final String dailyChapters;
  final DateTime startDate;

  const _ReaderSimulatedReadingInput({
    required this.enabled,
    required this.startChapter,
    required this.dailyChapters,
    required this.startDate,
  });
}

class _ReaderBookmarkDraft {
  final String chapterTitle;
  final int chapterPos;
  final String pageText;

  const _ReaderBookmarkDraft({
    required this.chapterTitle,
    required this.chapterPos,
    required this.pageText,
  });
}

class _ReaderBookmarkEditResult {
  final String bookText;
  final String note;

  const _ReaderBookmarkEditResult({
    required this.bookText,
    required this.note,
  });
}

class _ReaderFontOption {
  final String label;
  final int? presetIndex;
  final String? filePath;

  const _ReaderFontOption.preset({
    required this.label,
    required this.presetIndex,
  }) : filePath = null;

  const _ReaderFontOption.custom({
    required this.label,
    required this.filePath,
  }) : presetIndex = null;
}

class _ReaderSystemTypefaceOption {
  final String label;
  final int presetIndex;

  const _ReaderSystemTypefaceOption({
    required this.label,
    required this.presetIndex,
  });
}

class _TipOption {
  final int value;
  final String label;

  const _TipOption(this.value, this.label);
}

class _EffectiveReplaceMenuEntry {
  final String label;
  final ReplaceRule? rule;
  final bool isChineseConverter;

  const _EffectiveReplaceMenuEntry._({
    required this.label,
    required this.rule,
    required this.isChineseConverter,
  });

  const _EffectiveReplaceMenuEntry.rule({
    required String label,
    required ReplaceRule rule,
  }) : this._(
          label: label,
          rule: rule,
          isChineseConverter: false,
        );

  const _EffectiveReplaceMenuEntry.chineseConverter({
    required String label,
  }) : this._(
          label: label,
          rule: null,
          isChineseConverter: true,
        );
}

class _ReplaceStageCache {
  final String rawTitle;
  final String rawContent;
  final String title;
  final String content;
  final List<ReplaceRule> effectiveContentReplaceRules;

  const _ReplaceStageCache({
    required this.rawTitle,
    required this.rawContent,
    required this.title,
    required this.content,
    required this.effectiveContentReplaceRules,
  });
}

class _ResolvedChapterSnapshot {
  final String chapterId;
  final int postProcessSignature;
  final int baseTitleHash;
  final int baseContentHash;
  final String title;
  final String content;
  final bool isDeferredPlaceholder;

  const _ResolvedChapterSnapshot({
    required this.chapterId,
    required this.postProcessSignature,
    required this.baseTitleHash,
    required this.baseContentHash,
    required this.title,
    required this.content,
    this.isDeferredPlaceholder = false,
  });
}

class _ChapterImageMetaSnapshot {
  final String chapterId;
  final int postProcessSignature;
  final int contentHash;
  final List<ReaderImageMarkerMeta> metas;

  const _ChapterImageMetaSnapshot({
    required this.chapterId,
    required this.postProcessSignature,
    required this.contentHash,
    required this.metas,
  });
}

class _ReaderSearchHit {
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

  const _ReaderSearchHit({
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

class _ReaderSearchProgressSnapshot {
  final int chapterIndex;
  final double chapterProgress;

  const _ReaderSearchProgressSnapshot({
    required this.chapterIndex,
    required this.chapterProgress,
  });
}

class _ScrollSegmentSeed {
  final String chapterId;
  final String title;
  final String content;

  const _ScrollSegmentSeed({
    required this.chapterId,
    required this.title,
    required this.content,
  });
}

class _ReaderRenderBlock {
  final String? text;
  final String? imageSrc;

  const _ReaderRenderBlock._({
    this.text,
    this.imageSrc,
  });

  const _ReaderRenderBlock.text(String value)
      : this._(
          text: value,
        );

  const _ReaderRenderBlock.image(String value)
      : this._(
          imageSrc: value,
        );

  bool get isImage => imageSrc != null;
}

class _ScrollSegment {
  final int chapterIndex;
  final String chapterId;
  final String title;
  final String content;
  final double estimatedHeight;

  const _ScrollSegment({
    required this.chapterIndex,
    required this.chapterId,
    required this.title,
    required this.content,
    required this.estimatedHeight,
  });
}

class _ScrollSegmentOffsetRange {
  final _ScrollSegment segment;
  final double start;
  final double end;
  final double height;

  const _ScrollSegmentOffsetRange({
    required this.segment,
    required this.start,
    required this.end,
    required this.height,
  });
}
