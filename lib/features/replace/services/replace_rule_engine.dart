import 'dart:async';
import 'dart:isolate';

import '../models/replace_rule.dart';

class ReplaceRuleEngine {
  List<ReplaceRule> effectiveRules(
    List<ReplaceRule> allRules, {
    required String bookName,
    required String? sourceName,
    required String? sourceUrl,
  }) {
    final sorted = allRules
      .where((r) => r.isEnabled)
      .toList(growable: false)
      ..sort((a, b) => a.order.compareTo(b.order));
    return sorted.where((r) {
      if (!_isScopeMatched(
        r.scope,
        bookName,
        sourceName,
        sourceUrl,
        emptyMatchesAll: true,
      )) {
        return false;
      }
      if (_isScopeMatched(
        r.excludeScope,
        bookName,
        sourceName,
        sourceUrl,
        emptyMatchesAll: false,
      )) {
        return false;
      }
      return true;
    }).toList(growable: false);
  }

  Future<String> applyToTitle(String title, List<ReplaceRule> rules) async {
    var out = title;
    for (final rule in rules) {
      if (!rule.scopeTitle) continue;
      out = await _applyOne(out, rule);
    }
    return out;
  }

  Future<String> applyToContent(String content, List<ReplaceRule> rules) async {
    var out = content;
    for (final rule in rules) {
      if (!rule.scopeContent) continue;
      out = await _applyOne(out, rule);
    }
    return out;
  }

  bool isValid(ReplaceRule rule) {
    if (rule.pattern.trim().isEmpty) return false;
    if (!rule.isRegex) return true;
    try {
      // 对齐 legado：Pattern.compile 通过但以 '|' 结尾容易导致灾难性回溯/超时
      if (rule.pattern.endsWith('|') && !rule.pattern.endsWith(r'\|')) {
        return false;
      }
      RegExp(rule.pattern);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<String> _applyOne(String input, ReplaceRule rule) async {
    if (!isValid(rule)) return input;
    try {
      if (rule.isRegex) {
        final timeoutMs =
            rule.timeoutMillisecond <= 0 ? 3000 : rule.timeoutMillisecond;
        return _regexReplaceWithTimeout(
          input: input,
          pattern: rule.pattern,
          replacement: rule.replacement,
          timeout: Duration(milliseconds: timeoutMs),
        );
      }
      return input.replaceAll(rule.pattern, rule.replacement);
    } catch (_) {
      return input;
    }
  }

  bool _isScopeMatched(
    String? scope,
    String bookName,
    String? sourceName,
    String? sourceUrl,
    {required bool emptyMatchesAll}
  ) {
    final text = scope?.trim();
    if (text == null || text.isEmpty) return emptyMatchesAll;

    final tokens = text
        .split(RegExp(r'[,\n;，；]'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList(growable: false);

    if (tokens.isEmpty) return emptyMatchesAll;

    bool matchToken(String token, String target) {
      if (target.isEmpty) return false;
      return target == token || target.contains(token) || token.contains(target);
    }

    for (final token in tokens) {
      if (matchToken(token, bookName)) return true;
      if (sourceName != null && matchToken(token, sourceName)) return true;
      if (sourceUrl != null && matchToken(token, sourceUrl)) return true;
    }
    return false;
  }
}

class _RegexReplaceRequest {
  final SendPort sendPort;
  final String input;
  final String pattern;
  final String replacement;

  const _RegexReplaceRequest({
    required this.sendPort,
    required this.input,
    required this.pattern,
    required this.replacement,
  });
}

@pragma('vm:entry-point')
void _regexReplaceIsolateEntry(_RegexReplaceRequest req) {
  try {
    final out = req.input.replaceAll(RegExp(req.pattern), req.replacement);
    Isolate.exit(req.sendPort, out);
  } catch (_) {
    Isolate.exit(req.sendPort, req.input);
  }
}

Future<String> _regexReplaceWithTimeout({
  required String input,
  required String pattern,
  required String replacement,
  required Duration timeout,
}) async {
  final receivePort = ReceivePort();
  final errorPort = ReceivePort();

  Isolate? isolate;
  Timer? timer;

  void cleanup() {
    timer?.cancel();
    timer = null;
    receivePort.close();
    errorPort.close();
    if (isolate != null) {
      isolate!.kill(priority: Isolate.immediate);
      isolate = null;
    }
  }

  final completer = Completer<String>();

  void completeOnce(String value) {
    if (completer.isCompleted) return;
    completer.complete(value);
  }

  receivePort.listen((message) {
    if (message is String) {
      completeOnce(message);
    } else {
      completeOnce(input);
    }
  });

  errorPort.listen((_) {
    completeOnce(input);
  });

  isolate = await Isolate.spawn<_RegexReplaceRequest>(
    _regexReplaceIsolateEntry,
    _RegexReplaceRequest(
      sendPort: receivePort.sendPort,
      input: input,
      pattern: pattern,
      replacement: replacement,
    ),
    onError: errorPort.sendPort,
  );

  timer = Timer(timeout, () {
    isolate?.kill(priority: Isolate.immediate);
    completeOnce(input);
  });

  try {
    return await completer.future;
  } finally {
    cleanup();
  }
}
