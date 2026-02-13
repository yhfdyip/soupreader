import '../models/book_source.dart';
import 'rule_parser_engine.dart';
import 'source_debug_key_parser.dart';

class SourceDebugRunResult {
  final SourceDebugIntent intent;
  final bool success;
  final String? error;
  final List<SourceDebugEvent> events;

  const SourceDebugRunResult({
    required this.intent,
    required this.success,
    required this.error,
    required this.events,
  });
}

/// 调试编排层：
/// - 统一 key 解析（避免 UI 各入口分叉）
/// - 统一调试触发与结果汇总
class SourceDebugOrchestrator {
  final RuleParserEngine _engine;
  final SourceDebugKeyParser _parser;

  SourceDebugOrchestrator({
    RuleParserEngine? engine,
    SourceDebugKeyParser? parser,
  })  : _engine = engine ?? RuleParserEngine(),
        _parser = parser ?? const SourceDebugKeyParser();

  SourceDebugParseResult parseKey(String key) => _parser.parse(key);

  Future<SourceDebugRunResult> run({
    required BookSource source,
    required String key,
    required void Function(SourceDebugEvent event) onEvent,
  }) async {
    final parsed = _parser.parse(key);
    final intent = parsed.intent;
    if (intent == null) {
      final error = parsed.error ?? '调试 key 无效';
      final failEvent = SourceDebugEvent(state: -1, message: error);
      onEvent(failEvent);
      return SourceDebugRunResult(
        intent: SourceDebugIntent(
          type: SourceDebugIntentType.search,
          rawKey: key,
          runKey: key.trim(),
          keyword: key.trim(),
        ),
        success: false,
        error: error,
        events: <SourceDebugEvent>[failEvent],
      );
    }

    final events = <SourceDebugEvent>[];
    String? firstError;
    var hasFinished = false;

    void emit(SourceDebugEvent event) {
      events.add(event);
      if (event.state == -1 && firstError == null) {
        firstError = event.message;
      }
      if (event.state == 1000) {
        hasFinished = true;
      }
      onEvent(event);
    }

    try {
      await _engine.debugRun(
        source,
        intent.runKey,
        onEvent: emit,
      );
    } catch (e) {
      final errorText = '调试失败：$e';
      final failEvent = SourceDebugEvent(state: -1, message: errorText);
      emit(failEvent);
    }

    final success = hasFinished && firstError == null;
    return SourceDebugRunResult(
      intent: intent,
      success: success,
      error: firstError,
      events: events,
    );
  }
}
