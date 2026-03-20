import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../services/http_tts_engine.dart';
import '../services/http_tts_rule_store.dart';
import '../services/read_aloud_service.dart';
import '../models/reader_view_types.dart';

/// Dependencies the read-aloud helper needs from the host reader.
class ReaderReadAloudContext {
  /// Returns the current chapter index.
  final int Function() currentChapterIndex;

  /// Returns the current chapter title (post-processed).
  final String Function() currentTitle;

  /// Returns the current chapter content.
  final String Function() currentContent;

  /// Returns the chapter list length.
  final int Function() chapterCount;

  /// Returns the effective readable chapter count.
  final int Function() readableChapterCount;

  /// Loads a chapter by index, optionally going to the last page.
  final Future<void> Function(int index, {bool goToLastPage}) loadChapter;

  /// Returns the current chapter progress (0.0 - 1.0).
  final double Function() chapterProgress;

  /// Whether the auto pager is running.
  final bool Function() isAutoPagerRunning;

  /// Stops the auto pager and auto read panel.
  final void Function() stopAutoPagerForReadAloud;

  /// Returns the content-select speak mode (0 = speak once,
  /// 1 = speak from selected text).
  final int Function() contentSelectSpeakMode;

  /// Saves the content-select speak mode.
  final Future<void> Function(int mode) saveContentSelectSpeakMode;

  /// Returns the audio play wake lock setting.
  final bool Function() audioPlayUseWakeLock;

  /// Saves the audio play wake lock setting.
  final Future<void> Function(bool enabled) saveAudioPlayUseWakeLock;

  /// Shows a toast message.
  final void Function(String message) showToast;

  /// Shows a copy-style toast.
  final void Function(String message) showCopyToast;

  const ReaderReadAloudContext({
    required this.currentChapterIndex,
    required this.currentTitle,
    required this.currentContent,
    required this.chapterCount,
    required this.readableChapterCount,
    required this.loadChapter,
    required this.chapterProgress,
    required this.isAutoPagerRunning,
    required this.stopAutoPagerForReadAloud,
    required this.contentSelectSpeakMode,
    required this.saveContentSelectSpeakMode,
    required this.audioPlayUseWakeLock,
    required this.saveAudioPlayUseWakeLock,
    required this.showToast,
    required this.showCopyToast,
  });
}

/// Manages all read-aloud (TTS) state and logic for the reader.
///
/// Owns the [ReadAloudService] lifecycle, content-select TTS,
/// speech rate, migration-exclusion gating, and sleep timer.
/// Dialog/sheet display and setState remain in the host widget.
class ReaderReadAloudHelper extends ChangeNotifier {
  ReaderReadAloudHelper(this._context);

  final ReaderReadAloudContext _context;
  final HttpTtsRuleStore _httpTtsRuleStore = HttpTtsRuleStore();

  // ── State ────────────────────────────────────────────────

  ReadAloudService? _readAloudServiceOrNull;
  ReadAloudStatusSnapshot _snapshot =
      const ReadAloudStatusSnapshot.stopped();
  int _speechRate = 10;
  FlutterTts? _contentSelectTts;
  bool _contentSelectTtsReady = false;
  bool _showingExclusionDialog = false;
  bool _audioPlayUseWakeLock = false;
  int _contentSelectSpeakMode = 0;

  static final RegExp _speakablePattern =
      RegExp(r'[\u4E00-\u9FFFA-Za-z0-9]');

  static const String exclusionHint =
      '迁移排除：朗读（TTS）功能暂不开放\n该入口仅保留锚点，不可操作';

  // ── Public getters ──────────────────────────────────────

  ReadAloudStatusSnapshot get snapshot => _snapshot;
  int get speechRate => _speechRate;
  bool get isRunning => _snapshot.isRunning;
  bool get isPlaying => _snapshot.isPlaying;
  bool get isPaused => _snapshot.isPaused;
  bool get audioPlayUseWakeLock => _audioPlayUseWakeLock;
  int get contentSelectSpeakMode => _contentSelectSpeakMode;
  bool get showingExclusionDialog => _showingExclusionDialog;
  HttpTtsRuleStore get httpTtsRuleStore => _httpTtsRuleStore;

  ReadAloudService get _readAloudService =>
      _readAloudServiceOrNull ??= ReadAloudService(
        onStateChanged: _handleStateChanged,
        onMessage: _handleMessage,
        onRequestChapterSwitch: _handleChapterSwitchRequest,
      );

  // ── Init / Dispose ──────────────────────────────────────

  /// Initializes the read-aloud engine from persisted settings.
  Future<void> init() async {
    _audioPlayUseWakeLock = _context.audioPlayUseWakeLock();
    _contentSelectSpeakMode = _context.contentSelectSpeakMode();

    final selectedRuleId =
        await _httpTtsRuleStore.loadSelectedRuleId();
    final persistedRate = await _httpTtsRuleStore.loadSpeechRate();

    ReadAloudEngine engine;
    if (selectedRuleId != null) {
      final rules = await _httpTtsRuleStore.loadRules();
      final rule =
          rules.where((r) => r.id == selectedRuleId).firstOrNull;
      engine = rule != null
          ? HttpTtsReadAloudEngine(
              rule: rule, speechRate: persistedRate)
          : FlutterReadAloudEngine();
    } else {
      engine = FlutterReadAloudEngine();
    }

    _readAloudServiceOrNull = ReadAloudService(
      engine: engine,
      onStateChanged: _handleStateChanged,
      onMessage: _handleMessage,
      onRequestChapterSwitch: _handleChapterSwitchRequest,
    );
    _speechRate = persistedRate;
    notifyListeners();
  }

  Future<void> disposeService() async {
    await _readAloudServiceOrNull?.dispose();
    await _disposeContentSelectTts();
  }

  @override
  void dispose() {
    unawaited(disposeService());
    super.dispose();
  }

  // ── Read Aloud Actions ──────────────────────────────────

  /// Detects whether read aloud is available.
  ReadAloudCapability detectCapability() {
    if (kIsWeb) {
      return const ReadAloudCapability(
        available: false,
        reason: '当前平台暂不支持语音朗读',
      );
    }
    if (_context.chapterCount() == 0) {
      return const ReadAloudCapability(
        available: false,
        reason: '当前书籍暂无可朗读章节',
      );
    }
    if (_context.currentContent().trim().isEmpty) {
      return const ReadAloudCapability(
        available: false,
        reason: '当前章节暂无可朗读内容',
      );
    }
    return const ReadAloudCapability(
      available: true,
      reason: '',
    );
  }

  /// Opens (starts/pauses/resumes) read aloud from the menu.
  Future<void> openReadAloudAction() async {
    final capability = detectCapability();
    if (!capability.available) {
      _context.showToast(capability.reason);
      return;
    }

    if (_context.isAutoPagerRunning()) {
      _context.stopAutoPagerForReadAloud();
    }

    ReadAloudActionResult result;
    if (!_snapshot.isRunning) {
      result = await _readAloudService.start(
        chapterIndex: _context.currentChapterIndex(),
        chapterTitle: _context.currentTitle(),
        content: _context.currentContent(),
      );
    } else if (_snapshot.isPaused) {
      result = await _readAloudService.resume();
    } else {
      result = await _readAloudService.pause();
    }
    _context.showToast(result.message);
  }

  /// Triggers previous paragraph navigation.
  Future<void> triggerPreviousParagraph() async {
    final result = await _readAloudService.previousParagraph();
    if (!result.success) {
      _context.showToast(result.message);
    }
  }

  /// Triggers next paragraph navigation.
  Future<void> triggerNextParagraph() async {
    final result = await _readAloudService.nextParagraph();
    if (!result.success) {
      _context.showToast(result.message);
    }
  }

  /// Triggers pause/resume toggle.
  Future<void> triggerPauseResume() async {
    final result = await _readAloudService.togglePauseResume();
    _context.showToast(result.message);
  }

  /// Stops read aloud.
  Future<void> stop() async {
    await _readAloudService.stop();
  }

  /// Toggles pause/resume from the read-aloud bar.
  Future<void> togglePauseResume() async {
    await _readAloudService.togglePauseResume();
  }

  /// Goes to next paragraph from the read-aloud bar.
  Future<void> nextParagraph() async {
    await _readAloudService.nextParagraph();
  }

  /// Goes to previous paragraph from the read-aloud bar.
  Future<void> previousParagraph() async {
    await _readAloudService.previousParagraph();
  }

  /// Updates speech rate and persists it.
  Future<void> updateSpeechRate(int rate) async {
    _speechRate = rate;
    notifyListeners();
    await _readAloudService.updateSpeechRate(rate);
    await _httpTtsRuleStore.saveSpeechRate(rate);
  }

  /// Sets the sleep timer.
  void setTimer(int minutes) {
    _readAloudService.setTimer(minutes);
    notifyListeners();
  }

  /// Syncs the current chapter context to the read-aloud
  /// service so it can auto-advance chapters.
  void syncChapterContext() {
    unawaited(
      _readAloudService.updateChapter(
        chapterIndex: _context.currentChapterIndex(),
        chapterTitle: _context.currentTitle(),
        content: _context.currentContent(),
      ),
    );
  }

  // ── Selected Text Read Aloud ────────────────────────────

  /// Handles read-aloud for selected text based on the
  /// current speak mode.
  Future<void> handleSelectedTextReadAloud(
    String selectedText,
  ) async {
    if (selectedText.trim().isEmpty) return;
    if (_contentSelectSpeakMode == 1) {
      await startFromSelectedText(selectedText);
      return;
    }
    await speakSelectedTextOnce(selectedText);
  }

  /// Starts continuous read aloud from the selected text
  /// position in the current chapter.
  Future<void> startFromSelectedText(String selectedText) async {
    final capability = detectCapability();
    if (!capability.available) {
      _context.showToast(capability.reason);
      return;
    }

    if (_context.isAutoPagerRunning()) {
      _context.stopAutoPagerForReadAloud();
    }

    final normalizedSelection = selectedText.trim();
    final selectionStartIndex =
        _resolveSelectedTextStartIndex(normalizedSelection);
    ReadAloudActionResult result;
    if (selectionStartIndex >= 0) {
      result = await _readAloudService.start(
        chapterIndex: _context.currentChapterIndex(),
        chapterTitle: _context.currentTitle(),
        content: _context.currentContent().substring(
              selectionStartIndex,
            ),
        startParagraphIndex: 0,
      );
    } else {
      final startParagraphIndex =
          _resolveStartParagraphIndex(normalizedSelection);
      result = await _readAloudService.start(
        chapterIndex: _context.currentChapterIndex(),
        chapterTitle: _context.currentTitle(),
        content: _context.currentContent(),
        startParagraphIndex: startParagraphIndex,
      );
    }
    if (result.success) return;
    _context.showToast(result.message);
  }

  /// Speaks the selected text once using a standalone TTS
  /// instance (not the main read-aloud service).
  Future<void> speakSelectedTextOnce(String selectedText) async {
    if (kIsWeb) {
      _context.showToast('当前平台暂不支持语音朗读');
      return;
    }
    try {
      final tts = await _ensureContentSelectTtsReady();
      await tts.stop();
      final result = await tts.speak(selectedText);
      if (result != 1) {
        _context.showToast('启动朗读失败');
      }
    } catch (error) {
      _context.showToast('启动朗读失败：$error');
    }
  }

  /// Toggles the content-select speak mode (0 = speak once,
  /// 1 = speak from selection).
  void toggleContentSelectSpeakMode() {
    final nextMode = _contentSelectSpeakMode == 1 ? 0 : 1;
    _contentSelectSpeakMode = nextMode;
    notifyListeners();
    unawaited(_context.saveContentSelectSpeakMode(nextMode));
    _context.showToast(
      nextMode == 1
          ? '切换为从选择的地方开始一直朗读'
          : '切换为朗读选择内容',
    );
  }

  // ── Audio Play Menu ─────────────────────────────────────

  /// Toggles the audio play wake lock setting.
  Future<void> toggleAudioPlayWakeLock() async {
    final next = !_audioPlayUseWakeLock;
    _audioPlayUseWakeLock = next;
    notifyListeners();
    await _context.saveAudioPlayUseWakeLock(next);
  }

  // ── Exclusion Dialog State ──────────────────────────────

  /// Sets the exclusion dialog showing state.
  void setShowingExclusionDialog(bool showing) {
    _showingExclusionDialog = showing;
  }

  // ── Private ─────────────────────────────────────────────

  void _handleStateChanged(ReadAloudStatusSnapshot snap) {
    _snapshot = snap;
    notifyListeners();
  }

  void _handleMessage(String message) {
    _context.showToast(message);
  }

  Future<bool> _handleChapterSwitchRequest(
    ReadAloudChapterDirection direction,
  ) async {
    final readableChapterCount = _context.readableChapterCount();
    if (readableChapterCount <= 0) return false;
    final step =
        direction == ReadAloudChapterDirection.next ? 1 : -1;
    final targetIndex = _context.currentChapterIndex() + step;
    if (targetIndex < 0 || targetIndex >= readableChapterCount) {
      return false;
    }
    await _context.loadChapter(
      targetIndex,
      goToLastPage:
          direction == ReadAloudChapterDirection.previous,
    );
    return true;
  }

  int _resolveSelectedTextStartIndex(String selectedText) {
    if (selectedText.isEmpty) return -1;
    final content = _context.currentContent();
    if (content.isEmpty) return -1;

    final matches = <int>[];
    var cursor = 0;
    while (cursor < content.length) {
      final matchIndex = content.indexOf(selectedText, cursor);
      if (matchIndex < 0) break;
      matches.add(matchIndex);
      cursor = matchIndex + 1;
    }
    if (matches.isEmpty) return -1;

    final estimatedOffset =
        (content.length * _context.chapterProgress().clamp(0.0, 1.0))
            .round()
            .clamp(0, content.length)
            .toInt();
    matches.sort(
      (a, b) => (a - estimatedOffset)
          .abs()
          .compareTo((b - estimatedOffset).abs()),
    );
    return matches.first;
  }

  int _resolveStartParagraphIndex(String selectedText) {
    final paragraphs =
        _buildParagraphs(_context.currentContent());
    if (paragraphs.isEmpty) return 0;
    final normalizedText = selectedText.trim();
    if (normalizedText.isEmpty) return 0;
    final exactIndex = paragraphs.indexWhere(
      (paragraph) => paragraph.contains(normalizedText),
    );
    if (exactIndex >= 0) return exactIndex;
    final compactSelected =
        normalizedText.replaceAll(RegExp(r'\s+'), '');
    if (compactSelected.isEmpty) return 0;
    final compactIndex = paragraphs.indexWhere(
      (paragraph) => paragraph
          .replaceAll(RegExp(r'\s+'), '')
          .contains(compactSelected),
    );
    return compactIndex >= 0 ? compactIndex : 0;
  }

  List<String> _buildParagraphs(String content) {
    final normalized =
        content.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    return normalized
        .split('\n')
        .map((line) => line.trim())
        .where(
          (line) =>
              line.isNotEmpty && _speakablePattern.hasMatch(line),
        )
        .toList(growable: false);
  }

  Future<FlutterTts> _ensureContentSelectTtsReady() async {
    final existing = _contentSelectTts;
    if (existing != null && _contentSelectTtsReady) {
      return existing;
    }
    final tts = existing ?? FlutterTts();
    _contentSelectTts ??= tts;
    if (!_contentSelectTtsReady) {
      await tts.awaitSpeakCompletion(true);
      _contentSelectTtsReady = true;
    }
    return tts;
  }

  Future<void> _disposeContentSelectTts() async {
    final tts = _contentSelectTts;
    _contentSelectTts = null;
    _contentSelectTtsReady = false;
    if (tts == null) return;
    try {
      await tts.stop();
    } catch (_) {
      // ignore dispose errors
    }
  }
}
