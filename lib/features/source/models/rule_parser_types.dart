// Data types used by RuleParserEngine.
import 'dart:convert';

import 'book_source.dart';

class LegadoTextRule {
  final List<LegadoSelectorStep> selectors;
  final List<String> extractors;
  final List<LegadoReplacePair> replacements;

  const LegadoTextRule({
    required this.selectors,
    required this.extractors,
    required this.replacements,
  });

  static LegadoTextRule parse(
    String raw, {
    required bool Function(String token) isExtractor,
  }) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return const LegadoTextRule(
        selectors: <LegadoSelectorStep>[],
        extractors: <String>['text'],
        replacements: <LegadoReplacePair>[],
      );
    }

    final parts = trimmed.split('##');
    final pipeline = parts.first.trim();

    final replacements = <LegadoReplacePair>[];
    if (parts.length > 1) {
      final rep = parts.sublist(1).toList(growable: false);
      var start = 0;
      // 对齐 legado：当 replace 段为奇数时，首段按 replaceFirst 处理（如 `##a##b###`）。
      if (rep.length >= 3 && rep.length.isOdd) {
        final firstPattern = rep[0].trim();
        if (firstPattern.isNotEmpty) {
          replacements.add(
            LegadoReplacePair(
              pattern: firstPattern,
              replacement: rep[1],
              firstOnly: true,
            ),
          );
        }
        start = 3;
      }

      for (var i = start; i < rep.length; i += 2) {
        final pattern = rep[i].trim();
        final replacement = (i + 1) < rep.length ? rep[i + 1] : '';
        if (pattern.isEmpty) continue;
        replacements.add(
          LegadoReplacePair(
            pattern: pattern,
            replacement: replacement,
          ),
        );
      }
    }

    final tokens = pipeline
        .split('@')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList(growable: false);

    // 从末尾识别 extractor（对标 legado：h1@title@text 表示 title 为空则取 text）
    final startsWithAt = pipeline.startsWith('@');
    var cut = tokens.length;
    final extractors = <String>[];
    if (startsWithAt) {
      // 兼容 legado 写法：@href / @textNodes 等表示"当前元素取属性/文本"
      for (final t in tokens) {
        if (isExtractor(t)) extractors.add(t);
      }
      cut = 0;
    } else if (tokens.length == 1 && isExtractor(tokens.first)) {
      // 对齐 legado：单 token 规则如 text / href 视为"当前元素 extractor"，
      // 不能当作 selector，否则会出现 chapterName=text / chapterUrl=href 取值为空。
      extractors.add(tokens.first);
      cut = 0;
    } else if (tokens.length >= 2) {
      while (cut > 0) {
        final candidate = tokens[cut - 1];
        if (!isExtractor(candidate)) break;
        extractors.insert(0, candidate);
        cut--;
      }
    }

    final selectors = <LegadoSelectorStep>[];
    for (final t in tokens.take(cut)) {
      final step = LegadoSelectorStep.tryParse(t);
      if (step != null) selectors.add(step);
    }

    return LegadoTextRule(
      selectors: selectors,
      extractors:
          extractors.isEmpty ? const <String>['text'] : extractors,
      replacements: replacements,
    );
  }
}

class LegadoSelectorStep {
  final String cssSelector;
  final LegadoIndexSpec? indexSpec;
  final bool childrenOnly;
  final String? ownTextContains;

  const LegadoSelectorStep({
    required this.cssSelector,
    required this.indexSpec,
    this.childrenOnly = false,
    this.ownTextContains,
  });

  static LegadoSelectorStep? tryParse(String token) {
    final t = token.trim();
    if (t.isEmpty) return null;

    var base = t;
    LegadoIndexSpec? indexSpec;

    final bracketParsed = _tryParseBracketIndex(t);
    if (bracketParsed != null) {
      base = bracketParsed.base;
      indexSpec = bracketParsed.spec;
    } else {
      final dotParsed = _tryParseDotIndex(t);
      if (dotParsed != null) {
        base = dotParsed.base;
        indexSpec = dotParsed.spec;
      }
    }

    final selectorBase = _parseLegacySelectorBase(base);
    if (selectorBase.textSelector &&
        (selectorBase.ownTextContains == null ||
            selectorBase.ownTextContains!.isEmpty)) {
      return null;
    }

    base = selectorBase.cssBase;
    final css = _toCssSelector(base);
    if (css.trim().isEmpty) {
      // 对齐 legado：允许仅写索引（如 [0]），语义等价于当前节点 children。
      if (indexSpec != null && base.trim().isEmpty) {
        return LegadoSelectorStep(
          cssSelector: '*',
          indexSpec: indexSpec,
          childrenOnly: true,
          ownTextContains: null,
        );
      }
      return null;
    }
    return LegadoSelectorStep(
      cssSelector: css,
      indexSpec: indexSpec,
      childrenOnly: selectorBase.childrenOnly,
      ownTextContains: selectorBase.ownTextContains,
    );
  }

  static ({
    String cssBase,
    bool childrenOnly,
    bool textSelector,
    String? ownTextContains,
  }) _parseLegacySelectorBase(String raw) {
    final t = raw.trim();
    if (t == 'children' || t.startsWith('children.')) {
      return (
        cssBase: '*',
        childrenOnly: true,
        textSelector: false,
        ownTextContains: null,
      );
    }

    if (t.startsWith('text.')) {
      var keyword = t.substring('text.'.length);
      final nextDot = keyword.indexOf('.');
      if (nextDot >= 0) {
        keyword = keyword.substring(0, nextDot);
      }
      keyword = keyword.trim();
      return (
        cssBase: '*',
        childrenOnly: false,
        textSelector: true,
        ownTextContains: keyword.isEmpty ? null : keyword,
      );
    }

    return (
      cssBase: t,
      childrenOnly: false,
      textSelector: false,
      ownTextContains: null,
    );
  }

  static ({String base, LegadoIndexSpec spec})? _tryParseDotIndex(
    String token,
  ) {
    ({String base, LegadoIndexSpec spec})? parseBySplit(
      int splitPos, {
      required bool exclude,
    }) {
      if (splitPos < 0 || splitPos >= token.length - 1) return null;
      final body = token.substring(splitPos + 1).trim();
      final values = _parseLegacyColonIndexes(body);
      if (values == null || values.isEmpty) return null;
      final base = token.substring(0, splitPos).trimRight();
      return (
        base: base,
        spec: LegadoIndexSpec(
          exclude: exclude,
          terms: values
              .map((v) => LegadoIndexTerm.value(v))
              .toList(growable: false),
        ),
      );
    }

    // 旧语法：selector!0:3（排除）
    final bangPos = token.lastIndexOf('!');
    if (bangPos >= 0) {
      final parsed = parseBySplit(bangPos, exclude: true);
      if (parsed != null) return parsed;
    }

    // 旧语法：selector.-1:10:2（选择）
    for (var pos = token.length - 1; pos >= 0; pos--) {
      if (token[pos] != '.') continue;
      final parsed = parseBySplit(pos, exclude: false);
      if (parsed != null) return parsed;
    }

    return null;
  }

  static List<int>? _parseLegacyColonIndexes(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return null;
    final out = <int>[];
    for (final part in t.split(':')) {
      final v = int.tryParse(part.trim());
      if (v == null) return null;
      out.add(v);
    }
    return out;
  }

  static ({String base, LegadoIndexSpec spec})?
      _tryParseBracketIndex(
    String token,
  ) {
    if (!token.endsWith(']')) return null;
    final start = _findTrailingBracketStart(token);
    if (start < 0) return null;

    final body =
        token.substring(start + 1, token.length - 1).trim();
    if (body.isEmpty) return null;

    // 只接受 legado 索引语法字符，避免把 CSS 属性选择器误判为索引列表。
    for (final rune in body.runes) {
      final ch = String.fromCharCode(rune);
      final isDigit = rune >= 0x30 && rune <= 0x39;
      final isAllowed = isDigit ||
          ch == '-' ||
          ch == ':' ||
          ch == ',' ||
          ch == '!' ||
          ch == ' ';
      if (!isAllowed) return null;
    }

    var includeBody = body;
    var exclude = false;
    if (includeBody.startsWith('!')) {
      exclude = true;
      includeBody = includeBody.substring(1).trimLeft();
      if (includeBody.isEmpty) return null;
    }

    final terms = <LegadoIndexTerm>[];
    final segments = includeBody.split(',');
    for (final segment in segments) {
      final raw = segment.trim();
      if (raw.isEmpty) return null;

      final colonCount = ':'.allMatches(raw).length;
      if (colonCount == 0) {
        final value = int.tryParse(raw);
        if (value == null) return null;
        terms.add(LegadoIndexTerm.value(value));
        continue;
      }

      if (colonCount > 2) return null;
      final parts = raw.split(':');
      if (parts.length < 2 || parts.length > 3) return null;

      int? parseNullableInt(String s) {
        final t = s.trim();
        if (t.isEmpty) return null;
        return int.tryParse(t);
      }

      final startRaw = parts[0].trim();
      final endRaw = parts[1].trim();
      final stepRaw =
          parts.length == 3 ? parts[2].trim() : '';

      final startVal = parseNullableInt(parts[0]);
      final endVal = parseNullableInt(parts[1]);
      if (startRaw.isNotEmpty && startVal == null) return null;
      if (endRaw.isNotEmpty && endVal == null) return null;

      var stepVal = 1;
      if (parts.length == 3) {
        final parsedStep = parseNullableInt(parts[2]);
        if (stepRaw.isNotEmpty && parsedStep == null) {
          return null;
        }
        stepVal = parsedStep ?? 1;
      }
      if (stepVal == 0) stepVal = 1;

      terms.add(
        LegadoIndexTerm.range(
          start: startVal,
          end: endVal,
          step: stepVal,
        ),
      );
    }

    if (terms.isEmpty) return null;
    final base = token.substring(0, start).trimRight();
    return (
      base: base,
      spec: LegadoIndexSpec(
        exclude: exclude,
        terms: terms,
      ),
    );
  }

  static int _findTrailingBracketStart(String token) {
    var depth = 0;
    for (var i = token.length - 1; i >= 0; i--) {
      final ch = token[i];
      if (ch == ']') {
        depth++;
        continue;
      }
      if (ch != '[') continue;
      depth--;
      if (depth == 0) return i;
      if (depth < 0) return -1;
    }
    return -1;
  }

  static String _toCssSelector(String raw) {
    final t = raw.trim();
    if (t.startsWith('class.')) {
      return '.${t.substring('class.'.length)}';
    }
    if (t.startsWith('id.')) {
      return '#${t.substring('id.'.length)}';
    }
    if (t.startsWith('tag.')) {
      return t.substring('tag.'.length);
    }
    if (t.startsWith('css.')) {
      return t.substring('css.'.length);
    }
    return t;
  }
}

class LegadoIndexSpec {
  final bool exclude;
  final List<LegadoIndexTerm> terms;

  const LegadoIndexSpec({
    this.exclude = false,
    required this.terms,
  });
}

class LegadoIndexTerm {
  final int? value;
  final int? start;
  final int? end;
  final int step;

  const LegadoIndexTerm.value(int value)
      : this._(
          value: value,
          start: null,
          end: null,
          step: 1,
        );

  const LegadoIndexTerm.range({
    required int? start,
    required int? end,
    required int step,
  }) : this._(
          value: null,
          start: start,
          end: end,
          step: step,
        );

  const LegadoIndexTerm._({
    required this.value,
    required this.start,
    required this.end,
    required this.step,
  });

  bool get isRange => value == null;
}

class LegadoReplacePair {
  final String pattern;
  final String replacement;
  final bool firstOnly;

  const LegadoReplacePair({
    required this.pattern,
    required this.replacement,
    this.firstOnly = false,
  });
}

class TopLevelRuleSplit {
  final List<String> parts;
  final String? operator;

  const TopLevelRuleSplit({
    required this.parts,
    required this.operator,
  });
}

class ConcurrentRateSpec {
  final String raw;
  final bool isWindowMode;
  final int? intervalMs;
  final int? maxCount;
  final int? windowMs;

  const ConcurrentRateSpec.interval({
    required this.raw,
    required this.intervalMs,
  })  : isWindowMode = false,
        maxCount = null,
        windowMs = null;

  const ConcurrentRateSpec.window({
    required this.raw,
    required this.maxCount,
    required this.windowMs,
  })  : isWindowMode = true,
        intervalMs = null;

  String get modeLabel {
    if (!isWindowMode) {
      return '间隔模式 ${intervalMs ?? 0}ms';
    }
    return '窗口模式 ${maxCount ?? 0}/${windowMs ?? 0}ms';
  }
}

class ConcurrentRecord {
  final bool isWindowMode;
  int timeMs;
  int frequency;

  ConcurrentRecord({
    required this.isWindowMode,
    required this.timeMs,
    required this.frequency,
  });
}

class ConcurrentAcquireStep {
  final ConcurrentRecord? record;
  final int waitMs;
  final String decision;

  const ConcurrentAcquireStep({
    required this.record,
    required this.waitMs,
    required this.decision,
  });
}

class ConcurrentAcquireResult {
  final ConcurrentRecord? record;
  final int waitMs;
  final String decision;

  const ConcurrentAcquireResult({
    required this.record,
    required this.waitMs,
    required this.decision,
  });
}

enum DebugListMode { search, explore }

class SourceDebugEvent {
  final int state;
  final String message;
  final bool isRaw;

  const SourceDebugEvent({
    required this.state,
    required this.message,
    this.isRaw = false,
  });
}

enum DebugRequestType { search, explore, bookInfo, toc, content }

class ScriptHttpResponse {
  final String requestUrl;
  final String finalUrl;
  final int statusCode;
  final String statusMessage;
  final Map<String, String> headers;
  final String body;

  const ScriptHttpResponse({
    required this.requestUrl,
    required this.finalUrl,
    required this.statusCode,
    required this.statusMessage,
    required this.headers,
    required this.body,
  });
}

class FetchDebugResult {
  final String requestUrl;
  final String? finalUrl;
  final int? statusCode;
  final int elapsedMs;
  final bool isRedirect;
  final String method;
  final String? requestBodySnippet;
  final String? responseCharset;
  final int responseLength;
  final String? responseSnippet;
  final Map<String, String> requestHeaders;
  final String? headersWarning;
  final Map<String, String> responseHeaders;
  final String? error;

  /// 实际重试次数（不含首发请求）。
  final int retryCount;

  /// method 的最终决策说明。
  final String methodDecision;

  /// retry 的配置与归一化决策说明。
  final String retryDecision;

  /// 请求参数编码决策（url query / form body）。
  final String requestCharsetDecision;

  /// 请求体编码类型：none/form/json/raw。
  final String bodyEncoding;

  /// 请求体编码策略说明。
  final String bodyDecision;

  /// 响应编码来源：urlOption.charset / header / meta / default。
  final String? responseCharsetSource;

  /// 响应编码判定与解码器决策说明。
  final String? responseCharsetDecision;

  /// 并发率限流累计等待时长（毫秒）。
  final int concurrentWaitMs;

  /// 并发率决策说明（对标 legado：间隔模式 / 窗口模式）。
  final String concurrentDecision;

  /// 原始响应体（仅用于编辑器调试；不要在普通 UI 中到处传递）
  final String? body;

  const FetchDebugResult({
    required this.requestUrl,
    required this.finalUrl,
    required this.statusCode,
    required this.elapsedMs,
    this.isRedirect = false,
    this.method = 'GET',
    this.requestBodySnippet,
    this.responseCharset,
    required this.responseLength,
    required this.responseSnippet,
    required this.requestHeaders,
    required this.headersWarning,
    required this.responseHeaders,
    required this.error,
    this.retryCount = 0,
    this.methodDecision = '未解析',
    this.retryDecision = '未解析',
    this.requestCharsetDecision = '未解析',
    this.bodyEncoding = 'none',
    this.bodyDecision = '未解析',
    this.responseCharsetSource,
    this.responseCharsetDecision,
    this.concurrentWaitMs = 0,
    this.concurrentDecision = '未启用并发率限制',
    required this.body,
  });

  factory FetchDebugResult.empty() {
    return const FetchDebugResult(
      requestUrl: '',
      finalUrl: null,
      statusCode: null,
      elapsedMs: 0,
      isRedirect: false,
      method: 'GET',
      requestBodySnippet: null,
      responseCharset: null,
      responseLength: 0,
      responseSnippet: null,
      requestHeaders: {},
      headersWarning: null,
      responseHeaders: {},
      error: null,
      retryCount: 0,
      methodDecision: '未解析',
      retryDecision: '未解析',
      requestCharsetDecision: '未解析',
      bodyEncoding: 'none',
      bodyDecision: '未解析',
      responseCharsetSource: null,
      responseCharsetDecision: null,
      concurrentWaitMs: 0,
      concurrentDecision: '未启用并发率限制',
      body: null,
    );
  }
}

class LegadoUrlParsed {
  final String url;
  final LegadoUrlOption? option;

  const LegadoUrlParsed({
    required this.url,
    required this.option,
  });
}

class LegadoUrlOption {
  final String? method;
  final String? body;
  final String? charset;
  final int? retry;
  final Map<String, String> headers;
  final String? origin;
  final String? js;

  const LegadoUrlOption({
    required this.method,
    required this.body,
    required this.charset,
    required this.retry,
    required this.headers,
    required this.origin,
    required this.js,
  });

  factory LegadoUrlOption.fromJson(Map<String, dynamic> json) {
    String? getString(String key) {
      final v = json[key];
      if (v == null) return null;
      final t = v.toString().trim();
      return t.isEmpty ? null : t;
    }

    Map<String, String> parseHeaders(dynamic raw) {
      final out = <String, String>{};
      if (raw == null) return out;
      if (raw is Map) {
        raw.forEach((k, v) {
          if (k == null || v == null) return;
          final key = k.toString().trim();
          if (key.isEmpty) return;
          out[key] = v.toString();
        });
        return out;
      }
      if (raw is String) {
        final t = raw.trim();
        if (t.isEmpty) return out;
        // 对标 legado：UrlOption.headers 允许为 JSON 字符串
        if (t.startsWith('{') && t.endsWith('}')) {
          try {
            final decoded = jsonDecode(t);
            if (decoded is Map) {
              decoded.forEach((k, v) {
                if (k == null || v == null) return;
                final key = k.toString().trim();
                if (key.isEmpty) return;
                out[key] = v.toString();
              });
              return out;
            }
          } catch (_) {
            // fallthrough
          }
        }
        // 兼容编辑器里每行 key:value 的形式
        for (final line in t.split('\n')) {
          final trimmed = line.trim();
          if (trimmed.isEmpty) continue;
          final idx = trimmed.indexOf(':');
          if (idx <= 0) continue;
          final key = trimmed.substring(0, idx).trim();
          final value = trimmed.substring(idx + 1).trim();
          if (key.isEmpty) continue;
          out[key] = value;
        }
        return out;
      }
      // 兜底：toString 后尝试 JSON
      final t = raw.toString().trim();
      if (t.isEmpty) return out;
      if (t.startsWith('{') && t.endsWith('}')) {
        try {
          final decoded = jsonDecode(t);
          if (decoded is Map) {
            decoded.forEach((k, v) {
              if (k == null || v == null) return;
              final key = k.toString().trim();
              if (key.isEmpty) return;
              out[key] = v.toString();
            });
          }
        } catch (_) {
          // ignore
        }
      }
      return out;
    }

    String? parseBody(dynamic raw) {
      if (raw == null) return null;
      if (raw is String) {
        final t = raw.trimRight();
        return t.isEmpty ? null : raw;
      }
      try {
        return jsonEncode(raw);
      } catch (_) {
        final t = raw.toString();
        return t.trim().isEmpty ? null : t;
      }
    }

    int? parseRetry(dynamic raw) {
      if (raw == null) return null;
      if (raw is int) return raw;
      if (raw is num) return raw.toInt();
      final text = raw.toString().trim();
      if (text.isEmpty) return null;
      return int.tryParse(text);
    }

    final headers = parseHeaders(
      json.containsKey('headers')
          ? json['headers']
          : json['header'],
    );

    return LegadoUrlOption(
      method: getString('method'),
      body: parseBody(json['body']),
      charset: getString('charset'),
      retry: parseRetry(json['retry']),
      headers: headers,
      origin: getString('origin'),
      js: getString('js'),
    );
  }
}

class UrlJsPatchResult {
  final bool ok;
  final String url;
  final Map<String, String> headers;
  final String? error;

  const UrlJsPatchResult({
    required this.ok,
    required this.url,
    required this.headers,
    required this.error,
  });
}

class RequestRetryFailure {
  final Object error;
  final int retryCount;

  const RequestRetryFailure({
    required this.error,
    required this.retryCount,
  });

  @override
  String toString() =>
      'RequestRetryFailure(retryCount=$retryCount, error=$error)';
}

class DecodedText {
  final String text;
  final String charset;
  final String charsetSource;
  final String charsetDecision;

  const DecodedText({
    required this.text,
    required this.charset,
    required this.charsetSource,
    required this.charsetDecision,
  });
}

class ParsedHeaders {
  final Map<String, String> headers;
  final String? warning;

  const ParsedHeaders({
    required this.headers,
    required this.warning,
  });

  static const empty =
      ParsedHeaders(headers: {}, warning: null);

  @override
  String toString() => 'headers=$headers warning=$warning';
}

class SelectorStepCompat {
  // '' for first, ' ' descendant, '>' child, '+' adjacent, '~' sibling
  final String combinator;
  final String selector;
  final List<NthFilter> nthFilters;

  const SelectorStepCompat({
    required this.combinator,
    required this.selector,
    required this.nthFilters,
  });
}

class NthFilter {
  // nth-child / nth-last-child / nth-of-type / nth-last-of-type
  final String kind;
  final NthExpr expr;

  const NthFilter({required this.kind, required this.expr});
}

class NthExpr {
  final int a;
  final int b;

  const NthExpr({required this.a, required this.b});
}

class NthExtractResult {
  final String baseSelector;
  final List<NthFilter> filters;

  const NthExtractResult(
      {required this.baseSelector, required this.filters});
}

class NormalizedListRule {
  final String selector;
  final bool reverse;

  const NormalizedListRule({
    required this.selector,
    required this.reverse,
  });

  @override
  String toString() => 'selector=$selector reverse=$reverse';
}

class ResolvedBookListRule {
  final BookListRule rule;
  final bool usedSearchRuleAsExploreFallback;

  const ResolvedBookListRule({
    required this.rule,
    required this.usedSearchRuleAsExploreFallback,
  });
}

class BookListAnalyzeOutcome {
  final List<SearchResult> results;
  final int listCount;
  final Map<String, String> fieldSample;
  final String? listRuleRaw;
  final bool usedInfoFallback;

  const BookListAnalyzeOutcome({
    required this.results,
    required this.listCount,
    required this.fieldSample,
    required this.listRuleRaw,
    required this.usedInfoFallback,
  });
}

class SearchDebugResult {
  final FetchDebugResult fetch;
  final DebugRequestType requestType;
  final String? requestUrlRule;
  final String? listRule;
  final int listCount;
  final List<SearchResult> results;
  final Map<String, String> fieldSample;
  final String? error;

  const SearchDebugResult({
    required this.fetch,
    required this.requestType,
    required this.requestUrlRule,
    required this.listRule,
    required this.listCount,
    required this.results,
    required this.fieldSample,
    required this.error,
  });
}

class ExploreDebugResult {
  final FetchDebugResult fetch;
  final DebugRequestType requestType;
  final String? requestUrlRule;
  final String? listRule;
  final int listCount;
  final List<SearchResult> results;
  final Map<String, String> fieldSample;
  final String? error;

  const ExploreDebugResult({
    required this.fetch,
    required this.requestType,
    required this.requestUrlRule,
    required this.listRule,
    required this.listCount,
    required this.results,
    required this.fieldSample,
    required this.error,
  });
}

class BookInfoDebugResult {
  final FetchDebugResult fetch;
  final DebugRequestType requestType;
  final String? requestUrlRule;
  final String? initRule;
  final bool initMatched;
  final BookDetail? detail;
  final Map<String, String> fieldSample;
  final String? error;

  const BookInfoDebugResult({
    required this.fetch,
    required this.requestType,
    required this.requestUrlRule,
    required this.initRule,
    required this.initMatched,
    required this.detail,
    required this.fieldSample,
    required this.error,
  });
}

class TocDebugResult {
  final FetchDebugResult fetch;
  final DebugRequestType requestType;
  final String? requestUrlRule;
  final String? listRule;
  final int listCount;
  final List<TocItem> toc;
  final Map<String, String> fieldSample;
  final String? error;

  const TocDebugResult({
    required this.fetch,
    required this.requestType,
    required this.requestUrlRule,
    required this.listRule,
    required this.listCount,
    required this.toc,
    required this.fieldSample,
    required this.error,
  });
}

class ContentDebugResult {
  final FetchDebugResult fetch;
  final DebugRequestType requestType;
  final String? requestUrlRule;
  final int extractedLength;
  final int cleanedLength;
  final String content;
  final String? error;

  const ContentDebugResult({
    required this.fetch,
    required this.requestType,
    required this.requestUrlRule,
    required this.extractedLength,
    required this.cleanedLength,
    required this.content,
    required this.error,
  });
}

/// 搜索结果
class SearchResult {
  final String name;
  final String author;
  final String coverUrl;
  final String intro;
  final String kind;
  final String lastChapter;
  final String updateTime;
  final String wordCount;
  final String bookUrl;
  final String sourceUrl;
  final String sourceName;

  const SearchResult({
    required this.name,
    required this.author,
    required this.coverUrl,
    required this.intro,
    this.kind = '',
    required this.lastChapter,
    this.updateTime = '',
    this.wordCount = '',
    required this.bookUrl,
    required this.sourceUrl,
    required this.sourceName,
  });
}

/// 书籍详情
class BookDetail {
  final String name;
  final String author;
  final String coverUrl;
  final String intro;
  final String kind;
  final String lastChapter;
  final String updateTime;
  final String wordCount;
  final String tocUrl;
  final String bookUrl;

  const BookDetail({
    required this.name,
    required this.author,
    required this.coverUrl,
    required this.intro,
    required this.kind,
    required this.lastChapter,
    this.updateTime = '',
    this.wordCount = '',
    required this.tocUrl,
    required this.bookUrl,
  });
}

/// 目录项
class TocItem {
  final int index;
  final String name;
  final String url;
  final bool isVolume;
  final bool isVip;
  final bool isPay;
  final String? tag;
  final String? wordCount;

  const TocItem({
    required this.index,
    required this.name,
    required this.url,
    this.isVolume = false,
    this.isVip = false,
    this.isPay = false,
    this.tag,
    this.wordCount,
  });
}
