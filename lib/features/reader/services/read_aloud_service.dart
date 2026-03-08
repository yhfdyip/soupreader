import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

enum ReadAloudState {
  stopped,
  playing,
  paused,
}

enum ReadAloudChapterDirection {
  previous,
  next,
}

class ReadAloudStatusSnapshot {
  final ReadAloudState state;
  final int chapterIndex;
  final String chapterTitle;
  final int paragraphIndex;
  final int paragraphCount;

  const ReadAloudStatusSnapshot({
    required this.state,
    required this.chapterIndex,
    required this.chapterTitle,
    required this.paragraphIndex,
    required this.paragraphCount,
  });

  const ReadAloudStatusSnapshot.stopped()
      : state = ReadAloudState.stopped,
        chapterIndex = -1,
        chapterTitle = '',
        paragraphIndex = -1,
        paragraphCount = 0;

  bool get isRunning => state != ReadAloudState.stopped;
  bool get isPlaying => state == ReadAloudState.playing;
  bool get isPaused => state == ReadAloudState.paused;
}

class ReadAloudActionResult {
  final bool success;
  final String message;

  const ReadAloudActionResult({
    required this.success,
    required this.message,
  });
}

typedef ReadAloudStateChanged = void Function(ReadAloudStatusSnapshot state);
typedef ReadAloudMessageCallback = void Function(String message);
typedef ReadAloudChapterSwitchCallback = Future<bool> Function(
  ReadAloudChapterDirection direction,
);

abstract class ReadAloudEngine {
  Future<void> initialize({
    required VoidCallback onCompleted,
    required ValueChanged<String> onError,
  });

  Future<bool> speak(String text);

  Future<void> stop();

  Future<void> dispose();

  Future<void> updateSpeechRate(int rate) async {}
}

class FlutterReadAloudEngine implements ReadAloudEngine {
  FlutterReadAloudEngine({FlutterTts? tts}) : _tts = tts ?? FlutterTts();

  final FlutterTts _tts;
  bool _initialized = false;

  @override
  Future<void> initialize({
    required VoidCallback onCompleted,
    required ValueChanged<String> onError,
  }) async {
    _tts.setCompletionHandler(onCompleted);
    _tts.setErrorHandler((message) {
      onError((message ?? '').trim().isEmpty ? 'TTS 引擎异常' : message!);
    });

    if (_initialized) return;
    await _tts.awaitSpeakCompletion(true);
    _initialized = true;
  }

  @override
  Future<bool> speak(String text) async {
    final result = await _tts.speak(text);
    return result == 1;
  }

  @override
  Future<void> stop() async {
    await _tts.stop();
  }

  @override
  Future<void> dispose() async {
    await _tts.stop();
    _initialized = false;
  }

  @override
  Future<void> updateSpeechRate(int rate) async {
    await _tts.setSpeechRate(rate.clamp(1, 20) / 10.0);
  }
}

class ReadAloudService {
  ReadAloudService({
    ReadAloudEngine? engine,
    this.onStateChanged,
    this.onMessage,
    this.onRequestChapterSwitch,
  }) : _engine = engine ?? FlutterReadAloudEngine();

  final ReadAloudEngine _engine;
  final ReadAloudStateChanged? onStateChanged;
  final ReadAloudMessageCallback? onMessage;
  final ReadAloudChapterSwitchCallback? onRequestChapterSwitch;

  static final RegExp _speakablePattern = RegExp(r'[\u4E00-\u9FFFA-Za-z0-9]');

  bool _disposed = false;
  bool _engineReady = false;
  bool _awaitingChapterSwitch = false;
  bool _processingCompletion = false;

  ReadAloudState _state = ReadAloudState.stopped;
  int _speechRate = 10;
  int _chapterIndex = -1;
  String _chapterTitle = '';
  List<String> _paragraphs = const <String>[];
  int _paragraphIndex = 0;

  ReadAloudStatusSnapshot get snapshot {
    final paragraphIndex = _paragraphs.isEmpty ? -1 : _paragraphIndex;
    return ReadAloudStatusSnapshot(
      state: _state,
      chapterIndex: _chapterIndex,
      chapterTitle: _chapterTitle,
      paragraphIndex: paragraphIndex,
      paragraphCount: _paragraphs.length,
    );
  }

  bool get isRunning => _state != ReadAloudState.stopped;
  bool get isPlaying => _state == ReadAloudState.playing;
  bool get isPaused => _state == ReadAloudState.paused;
  int get speechRate => _speechRate;

  Future<ReadAloudActionResult> start({
    required int chapterIndex,
    required String chapterTitle,
    required String content,
    int startParagraphIndex = 0,
  }) async {
    if (_disposed) {
      return const ReadAloudActionResult(
        success: false,
        message: '朗读服务已释放',
      );
    }
    await _ensureEngineReady();

    final paragraphs = _buildParagraphs(content);
    _chapterIndex = chapterIndex;
    _chapterTitle = chapterTitle;
    _paragraphs = paragraphs;
    _awaitingChapterSwitch = false;

    if (paragraphs.isEmpty) {
      _state = ReadAloudState.stopped;
      _paragraphIndex = 0;
      _notifyState();
      return const ReadAloudActionResult(
        success: false,
        message: '当前章节暂无可朗读内容',
      );
    }

    _paragraphIndex = startParagraphIndex.clamp(0, paragraphs.length - 1);
    _state = ReadAloudState.playing;
    _notifyState();

    final started = await _speakCurrentParagraph();
    if (!started) {
      await _stopInternal(notifyUser: false);
      return const ReadAloudActionResult(
        success: false,
        message: '启动朗读失败',
      );
    }
    return const ReadAloudActionResult(success: true, message: '开始朗读');
  }

  Future<ReadAloudActionResult> pause() async {
    if (_state != ReadAloudState.playing) {
      return const ReadAloudActionResult(
        success: false,
        message: '当前未在朗读',
      );
    }
    _state = ReadAloudState.paused;
    _notifyState();
    await _engine.stop();
    return const ReadAloudActionResult(success: true, message: '暂停朗读');
  }

  Future<ReadAloudActionResult> resume() async {
    if (_state != ReadAloudState.paused) {
      return const ReadAloudActionResult(
        success: false,
        message: '当前未处于暂停状态',
      );
    }
    if (_paragraphs.isEmpty) {
      return const ReadAloudActionResult(
        success: false,
        message: '当前章节暂无可朗读内容',
      );
    }
    _state = ReadAloudState.playing;
    _notifyState();
    final resumed = await _speakCurrentParagraph();
    if (!resumed) {
      await _stopInternal(notifyUser: false);
      return const ReadAloudActionResult(
        success: false,
        message: '继续朗读失败',
      );
    }
    return const ReadAloudActionResult(success: true, message: '继续朗读');
  }

  Future<ReadAloudActionResult> togglePauseResume() {
    if (_state == ReadAloudState.playing) {
      return pause();
    }
    if (_state == ReadAloudState.paused) {
      return resume();
    }
    return Future.value(const ReadAloudActionResult(
      success: false,
      message: '请先开始朗读',
    ));
  }

  Future<ReadAloudActionResult> nextParagraph() async {
    if (_state == ReadAloudState.stopped) {
      return const ReadAloudActionResult(
        success: false,
        message: '请先开始朗读',
      );
    }
    if (_paragraphs.isEmpty) {
      return const ReadAloudActionResult(
        success: false,
        message: '当前章节暂无可朗读内容',
      );
    }

    final nextIndex = _paragraphIndex + 1;
    if (nextIndex < _paragraphs.length) {
      _paragraphIndex = nextIndex;
      _state = ReadAloudState.playing;
      _notifyState();
      final moved = await _speakCurrentParagraph();
      if (moved) {
        return const ReadAloudActionResult(
          success: true,
          message: '朗读下一段',
        );
      }
      await _stopInternal(notifyUser: false);
      return const ReadAloudActionResult(
        success: false,
        message: '朗读下一段失败',
      );
    }

    final movedChapter = await _tryMoveChapter(ReadAloudChapterDirection.next);
    if (movedChapter) {
      return const ReadAloudActionResult(
        success: true,
        message: '朗读下一章',
      );
    }
    return const ReadAloudActionResult(success: false, message: '已到最后一章');
  }

  Future<ReadAloudActionResult> previousParagraph() async {
    if (_state == ReadAloudState.stopped) {
      return const ReadAloudActionResult(
        success: false,
        message: '请先开始朗读',
      );
    }
    if (_paragraphs.isEmpty) {
      return const ReadAloudActionResult(
        success: false,
        message: '当前章节暂无可朗读内容',
      );
    }

    final prevIndex = _paragraphIndex - 1;
    if (prevIndex >= 0) {
      _paragraphIndex = prevIndex;
      _state = ReadAloudState.playing;
      _notifyState();
      final moved = await _speakCurrentParagraph();
      if (moved) {
        return const ReadAloudActionResult(
          success: true,
          message: '朗读上一段',
        );
        }
      await _stopInternal(notifyUser: false);
      return const ReadAloudActionResult(
        success: false,
        message: '朗读上一段失败',
      );
    }

    final movedChapter =
        await _tryMoveChapter(ReadAloudChapterDirection.previous);
    if (movedChapter) {
      return const ReadAloudActionResult(
        success: true,
        message: '朗读上一章',
      );
    }
    return const ReadAloudActionResult(success: false, message: '已到第一章');
  }

  Future<ReadAloudActionResult> stop() async {
    await _stopInternal(notifyUser: true);
    return const ReadAloudActionResult(success: true, message: '朗读已停止');
  }

  Future<void> updateSpeechRate(int rate) async {
    _speechRate = rate.clamp(1, 20);
    await _engine.updateSpeechRate(_speechRate);
  }

  Future<void> updateChapter({
    required int chapterIndex,
    required String chapterTitle,
    required String content,
  }) async {
    if (_disposed) return;

    final chapterChanged = chapterIndex != _chapterIndex;
    _chapterIndex = chapterIndex;
    _chapterTitle = chapterTitle;
    _paragraphs = _buildParagraphs(content);
    _paragraphIndex = 0;

    final shouldAutoSpeak = _state == ReadAloudState.playing &&
        (chapterChanged || _awaitingChapterSwitch);
    _awaitingChapterSwitch = false;
    _notifyState();

    if (!shouldAutoSpeak) return;
    if (_paragraphs.isEmpty) {
      await _tryMoveChapter(ReadAloudChapterDirection.next);
      return;
    }
    final resumed = await _speakCurrentParagraph();
    if (!resumed) {
      await _stopInternal(notifyUser: false);
    }
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _stopInternal(notifyUser: false);
    await _engine.dispose();
  }

  Future<void> _ensureEngineReady() async {
    if (_engineReady) return;
    await _engine.initialize(
      onCompleted: _handleSpeakCompleted,
      onError: _handleSpeakError,
    );
    _engineReady = true;
  }

  Future<bool> _speakCurrentParagraph() async {
    if (_disposed || _state != ReadAloudState.playing || _paragraphs.isEmpty) {
      return false;
    }
    _paragraphIndex = _paragraphIndex.clamp(0, _paragraphs.length - 1);
    final text = _paragraphs[_paragraphIndex];
    return _engine.speak(text);
  }

  void _handleSpeakCompleted() {
    if (_disposed ||
        _state != ReadAloudState.playing ||
        _processingCompletion) {
      return;
    }
    _processingCompletion = true;
    unawaited(() async {
      try {
        if (_paragraphs.isEmpty) {
          await _stopInternal(notifyUser: true);
          return;
        }

        if (_paragraphIndex < _paragraphs.length - 1) {
          _paragraphIndex += 1;
          _notifyState();
          final moved = await _speakCurrentParagraph();
          if (!moved) {
            await _stopInternal(notifyUser: false);
          }
          return;
        }

        await _tryMoveChapter(ReadAloudChapterDirection.next);
      } finally {
        _processingCompletion = false;
      }
    }());
  }

  void _handleSpeakError(String message) {
    if (_disposed) return;
    onMessage?.call('朗读出错：$message');
    unawaited(_stopInternal(notifyUser: false));
  }

  Future<bool> _tryMoveChapter(ReadAloudChapterDirection direction) async {
    final callback = onRequestChapterSwitch;
    if (callback == null) {
      await _stopInternal(notifyUser: true);
      return false;
    }
    _awaitingChapterSwitch = true;

    bool moved = false;
    try {
      moved = await callback(direction);
    } catch (error) {
      _awaitingChapterSwitch = false;
      onMessage?.call('切换章节失败：$error');
      await _stopInternal(notifyUser: true);
      return false;
    }

    if (!moved) {
      _awaitingChapterSwitch = false;
      await _stopInternal(notifyUser: true);
      return false;
    }
    return true;
  }

  Future<void> _stopInternal({required bool notifyUser}) async {
    await _engine.stop();
    _state = ReadAloudState.stopped;
    _awaitingChapterSwitch = false;
    _paragraphIndex = 0;
    _notifyState();
    if (notifyUser) {
      onMessage?.call('朗读已停止');
    }
  }

  List<String> _buildParagraphs(String content) {
    final normalized = content.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    return normalized
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty && _speakablePattern.hasMatch(line))
        .toList(growable: false);
  }

  void _notifyState() {
    onStateChanged?.call(snapshot);
  }
}
