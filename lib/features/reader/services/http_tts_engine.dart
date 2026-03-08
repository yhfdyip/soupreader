import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import '../models/http_tts_rule.dart';
import 'read_aloud_service.dart';

/// HTTP TTS 朗读引擎，通过 HTTP 请求获取音频字节后用 just_audio 播放。
///
/// URL 格式与 legado 书源 URL 格式兼容：
/// - 支持 `url,{method,body,header,...}` JSON option 格式
/// - 支持 `{{speakText}}` / `{{speakSpeed}}` 模板变量注入
class HttpTtsReadAloudEngine implements ReadAloudEngine {
  HttpTtsReadAloudEngine({
    required this.rule,
    this.speechRate = 10,
  });

  final HttpTtsRule rule;
  int speechRate;

  VoidCallback? _onCompleted;
  ValueChanged<String>? _onError;
  bool _initialized = false;
  bool _disposed = false;

  final AudioPlayer _player = AudioPlayer();
  StreamSubscription<PlayerState>? _playerStateSub;

  static final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(minutes: 5),
      headers: const <String, String>{
        'User-Agent':
            'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) '
            'AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 '
            'Mobile/15E148 Safari/604.1',
      },
      followRedirects: true,
      maxRedirects: 5,
    ),
  );

  @override
  Future<void> initialize({
    required VoidCallback onCompleted,
    required ValueChanged<String> onError,
  }) async {
    _onCompleted = onCompleted;
    _onError = onError;
    if (_initialized) return;
    _initialized = true;
    _playerStateSub = _player.playerStateStream.listen(_handlePlayerState);
  }

  @override
  Future<bool> speak(String text) async {
    if (_disposed) return false;
    try {
      await _player.stop();
      final bytes = await _fetchAudioBytes(text);
      if (bytes == null || bytes.isEmpty) {
        _onError?.call('获取音频失败');
        return false;
      }
      await _player.setAudioSource(_BytesAudioSource(bytes));
      await _player.play();
      return true;
    } catch (e) {
      _onError?.call('HTTP TTS 播放失败：$e');
      return false;
    }
  }

  @override
  Future<void> stop() async {
    await _player.stop();
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
    await _playerStateSub?.cancel();
    await _player.stop();
    await _player.dispose();
  }

  @override
  Future<void> updateSpeechRate(int rate) async {
    speechRate = rate.clamp(1, 20);
  }

  void _handlePlayerState(PlayerState state) {
    if (_disposed) return;
    if (state.processingState == ProcessingState.completed) {
      _onCompleted?.call();
    }
  }

  Future<Uint8List?> _fetchAudioBytes(String speakText) async {
    final rawUrl = rule.url.trim();
    if (rawUrl.isEmpty) return null;

    final parsed = _parseLegadoStyleUrl(rawUrl);
    final injectedUrl = _injectVariables(
      parsed.url,
      speakText: speakText,
      speakSpeed: speechRate,
    );

    final customHeaders = _parseHeaders(rule.header);
    final optionHeaders = parsed.option?.headers ?? const <String, String>{};
    customHeaders.addAll(optionHeaders);

    final method = parsed.option?.method?.toUpperCase() ?? 'GET';
    String? body = parsed.option?.body;
    if (body != null) {
      body = _injectVariables(
        body,
        speakText: speakText,
        speakSpeed: speechRate,
      );
    }

    final options = Options(
      method: method,
      responseType: ResponseType.bytes,
      validateStatus: (_) => true,
      headers: customHeaders,
    );

    final Response<List<int>> response;
    if (method == 'POST' && body != null) {
      response = await _dio.post<List<int>>(
        injectedUrl,
        data: body,
        options: options,
      );
    } else {
      response = await _dio.get<List<int>>(
        injectedUrl,
        options: options,
      );
    }

    final statusCode = response.statusCode ?? 0;
    if (statusCode >= 400) {
      throw Exception('HTTP $statusCode');
    }

    final data = response.data;
    if (data == null || data.isEmpty) return null;
    return Uint8List.fromList(data);
  }

  /// 注入 speakText / speakSpeed 变量到 URL 或 body 模板中。
  String _injectVariables(
    String template, {
    required String speakText,
    required int speakSpeed,
  }) {
    final encoded = Uri.encodeComponent(speakText);
    return template
        .replaceAll('{{speakText}}', encoded)
        .replaceAll('{{speakSpeed}}', speakSpeed.toString());
  }

  /// 解析 legado 风格的 URL：`url,{jsonOption}` 格式。
  _LegadoUrlParsed _parseLegadoStyleUrl(String rawUrl) {
    final commaIndex = rawUrl.indexOf(',{');
    if (commaIndex < 0) {
      return _LegadoUrlParsed(url: rawUrl, option: null);
    }
    final url = rawUrl.substring(0, commaIndex).trim();
    final optionText = rawUrl.substring(commaIndex + 1).trim();
    try {
      final json = jsonDecode(optionText) as Map<String, dynamic>;
      return _LegadoUrlParsed(
        url: url,
        option: _LegadoUrlOption.fromJson(json),
      );
    } catch (_) {
      return _LegadoUrlParsed(url: url, option: null);
    }
  }

  /// 解析 header 字符串（JSON 格式或 key: value 每行格式）。
  Map<String, String> _parseHeaders(String? headerText) {
    if (headerText == null || headerText.trim().isEmpty) {
      return <String, String>{};
    }
    final text = headerText.trim();
    try {
      final decoded = jsonDecode(text);
      if (decoded is Map) {
        return Map<String, String>.fromEntries(
          decoded.entries.map((e) => MapEntry('${e.key}', '${e.value}')),
        );
      }
    } catch (_) {}
    // key: value 换行格式
    final result = <String, String>{};
    for (final line in text.split('\n')) {
      final colonIdx = line.indexOf(':');
      if (colonIdx < 0) continue;
      final key = line.substring(0, colonIdx).trim();
      final value = line.substring(colonIdx + 1).trim();
      if (key.isNotEmpty) result[key] = value;
    }
    return result;
  }
}

class _LegadoUrlParsed {
  const _LegadoUrlParsed({required this.url, required this.option});
  final String url;
  final _LegadoUrlOption? option;
}

class _LegadoUrlOption {
  const _LegadoUrlOption({
    this.method,
    this.body,
    this.headers,
  });

  final String? method;
  final String? body;
  final Map<String, String>? headers;

  factory _LegadoUrlOption.fromJson(Map<String, dynamic> json) {
    Map<String, String>? headers;
    final rawHeader = json['header'];
    if (rawHeader is Map) {
      headers = Map<String, String>.fromEntries(
        rawHeader.entries.map((e) => MapEntry('${e.key}', '${e.value}')),
      );
    } else if (rawHeader is String && rawHeader.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(rawHeader.trim());
        if (decoded is Map) {
          headers = Map<String, String>.fromEntries(
            decoded.entries
                .map((e) => MapEntry('${e.key}', '${e.value}')),
          );
        }
      } catch (_) {}
    }
    return _LegadoUrlOption(
      method: json['method'] as String?,
      body: json['body'] as String?,
      headers: headers,
    );
  }
}

/// just_audio 自定义音频源，从 Uint8List 字节播放。
class _BytesAudioSource extends StreamAudioSource {
  _BytesAudioSource(this._bytes);
  final Uint8List _bytes;

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    start ??= 0;
    end ??= _bytes.length;
    return StreamAudioResponse(
      sourceLength: _bytes.length,
      contentLength: end - start,
      offset: start,
      stream: Stream.value(_bytes.sublist(start, end)),
      contentType: 'audio/mpeg',
    );
  }
}
