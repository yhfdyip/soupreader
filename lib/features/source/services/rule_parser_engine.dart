import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart';
import 'dart:convert';
import '../models/book_source.dart';
import 'package:flutter/foundation.dart';
import 'package:fast_gbk/fast_gbk.dart';
import '../../../core/services/js_runtime.dart';
import 'package:json_path/json_path.dart';
import 'package:xpath_selector_html_parser/xpath_selector_html_parser.dart';
import '../../../core/utils/html_text_formatter.dart';
import '../../../core/services/cookie_store.dart';
import '../../../core/services/source_login_store.dart';

/// 书源规则解析引擎
/// 支持 CSS 选择器、XPath（简化版）和正则表达式
class RuleParserEngine {
  static const Map<String, String> _defaultHeaders = {
    'User-Agent': 'Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) '
        'AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.0 Mobile/15E148 Safari/604.1',
    'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
    'Accept-Language': 'zh-CN,zh;q=0.9,en-US;q=0.8,en;q=0.7',
    'Upgrade-Insecure-Requests': '1',
  };

  static final Dio _dioPlain = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      headers: _defaultHeaders,
      // 书源站点很常见 30x 跳转（尤其从 http -> https）
      followRedirects: true,
      maxRedirects: 8,
    ),
  );

  static CookieJar get _cookieJar {
    // 这里依赖 main() 启动阶段的 CookieStore.setup()，对标 dbss 的 PersistCookieJar 逻辑。
    // 若调用方未初始化，将抛出异常，便于早发现配置问题。
    return CookieStore.jar;
  }

  static Dio? _dioCookieInstance;
  static Dio get _dioCookie {
    final existing = _dioCookieInstance;
    if (existing != null) return existing;
    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        headers: _defaultHeaders,
        followRedirects: true,
        maxRedirects: 8,
      ),
    )..interceptors.add(CookieManager(_cookieJar));
    _dioCookieInstance = dio;
    return dio;
  }

  // 对标 legado：并发率限制记录按 sourceKey 维度共享（跨 RuleParserEngine 实例生效）。
  static final Map<String, _ConcurrentRecord> _concurrentRecordMap =
      <String, _ConcurrentRecord>{};

  // URL 选项里的 js（Legado 格式）需要一个 JS 执行环境。
  // iOS 下为 JavaScriptCore；Android/Linux 下为 QuickJS（flutter_js）。
  // 这里只用于“URL 参数处理”，不做复杂脚本引擎承诺。
  static JsRuntime? _jsRuntimeInstance;
  static JsRuntime get _jsRuntime {
    return _jsRuntimeInstance ??= createJsRuntime();
  }

  final Map<String, String> _runtimeVariables = <String, String>{};

  bool _isValidJsIdentifier(String key) {
    return RegExp(r'^[A-Za-z_\$][A-Za-z0-9_\$]*$').hasMatch(key);
  }

  String _buildJsBindingDeclarations(Map<String, Object?> bindings) {
    final out = StringBuffer();
    final seen = <String>{};

    for (final entry in bindings.entries) {
      final key = entry.key.trim();
      if (key.isEmpty || seen.contains(key) || !_isValidJsIdentifier(key)) {
        continue;
      }
      seen.add(key);
      final safeKey = jsonEncode(key);
      out.writeln('var $key = __b[$safeKey];');
    }
    return out.toString();
  }

  String _evalJsMaybeString({
    required String js,
    String? jsLib,
    Map<String, Object?> bindings = const {},
  }) {
    // 统一的 JS 执行入口（轻量版，对标 legado 的“返回值 toString”语义）
    // - 通过 eval(jsText) 获取“脚本最后一个表达式”的值
    // - 支持注入 jsLib（书源字段）
    // - 支持注入 bindings（如 formatJs 的 title/index）
    final lib = (jsLib ?? '').trim();
    final safeLib = lib.isEmpty ? '' : '$lib\n';
    final safeJs = jsonEncode(js);
    final safeBindings = jsonEncode(bindings);
    final bindingDeclarations = _buildJsBindingDeclarations(bindings);
    final wrapped = '''
      (function(){
        try {
          $safeLib
          var __b = $safeBindings || {};
          for (var k in __b) {
            try {
              if (typeof globalThis !== 'undefined' && globalThis) {
                globalThis[String(k)] = __b[k];
              } else {
                this[String(k)] = __b[k];
              }
            } catch(e) {
              try { this[String(k)] = __b[k]; } catch(e2) {}
            }
          }
          $bindingDeclarations
          var __res;
          try {
            __res = eval($safeJs);
          } catch(_e) {
            __res = '';
          }
          if (__res === undefined || __res === null) {
            try {
              if (typeof chapter !== 'undefined' && chapter && typeof chapter.title === 'string' && chapter.title) {
                return chapter.title;
              }
            } catch(e) {}
            return '';
          }
          if (typeof __res === 'string') return __res;
          try { return JSON.stringify(__res); } catch(e) { return String(__res); }
        } catch (e) {
          return '';
        }
      })()
    ''';
    try {
      final out = _jsRuntime.evaluate(wrapped);
      if (out == 'undefined' || out == 'null') return '';
      return out;
    } catch (_) {
      return '';
    }
  }

  String _evalTocFormatJs({
    required String js,
    required String title,
    required int index1Based,
    String? jsLib,
  }) {
    final out = _evalJsMaybeString(
      js: js,
      jsLib: jsLib,
      bindings: <String, Object?>{
        'index': index1Based,
        'title': title,
        // 对标 legado bindings：有些 formatJs 会读/写 chapter.title
        'chapter': <String, Object?>{'title': title},
      },
    ).trim();
    return out.isEmpty ? title : out;
  }

  List<TocItem> _applyTocFormatJs({
    required List<TocItem> toc,
    required String? formatJs,
    String? jsLib,
  }) {
    final js = (formatJs ?? '').trim();
    if (js.isEmpty || toc.isEmpty) return toc;

    final out = <TocItem>[];
    for (var i = 0; i < toc.length; i++) {
      final item = toc[i];
      final newName = _evalTocFormatJs(
        js: js,
        title: item.name,
        index1Based: i + 1,
        jsLib: jsLib,
      );
      out.add(TocItem(index: item.index, name: newName, url: item.url));
    }
    return out;
  }

  String _applyStageResponseJs({
    required String responseText,
    required String? jsRule,
    required String currentUrl,
    String? jsLib,
    String stageLabel = 'webJs',
    void Function(String message)? onLog,
  }) {
    final js = (jsRule ?? '').trim();
    if (js.isEmpty) return responseText;

    var transformed = _evalJsMaybeString(
      js: js,
      jsLib: jsLib,
      bindings: <String, Object?>{
        'result': responseText,
        'content': responseText,
        'baseUrl': currentUrl,
        'url': currentUrl,
        'vars': Map<String, String>.from(_runtimeVariables),
      },
    );

    if (transformed.isEmpty) {
      transformed = _evalStageJsFallback(
        js: js,
        responseText: responseText,
        currentUrl: currentUrl,
      );
      if (transformed.isNotEmpty) {
        onLog?.call('$stageLabel 使用回退解析应用脚本');
      }
    }

    if (transformed.isEmpty) {
      onLog?.call('$stageLabel 执行返回空，保留原始响应');
      return responseText;
    }

    if (transformed != responseText) {
      onLog?.call(
        '$stageLabel 已应用（长度 ${responseText.length} -> ${transformed.length}）',
      );
    }
    return transformed;
  }

  String _evalStageJsFallback({
    required String js,
    required String responseText,
    required String currentUrl,
  }) {
    final split = _splitRuleByTopLevelOperator(js, const [';']);
    final statements = split.parts.isEmpty ? <String>[js] : split.parts;

    final env = <String, String>{
      'result': responseText,
      'content': responseText,
      'baseUrl': currentUrl,
      'url': currentUrl,
    };

    var lastValue = '';
    for (final raw in statements) {
      final statement = raw.trim();
      if (statement.isEmpty) continue;

      final assign = RegExp(r'^([A-Za-z_\$][A-Za-z0-9_\$]*)\s*=\s*([\s\S]+)$')
          .firstMatch(statement);
      if (assign != null) {
        final key = assign.group(1)?.trim() ?? '';
        final rhs = assign.group(2)?.trim() ?? '';
        if (key.isEmpty || rhs.isEmpty) continue;
        final value = _evalStageJsExpressionFallback(rhs, env);
        if (value != null) {
          env[key] = value;
          lastValue = value;
        }
        continue;
      }

      final value = _evalStageJsExpressionFallback(statement, env);
      if (value != null) {
        lastValue = value;
      }
    }

    if (lastValue.trim().isNotEmpty) return lastValue;

    final resultValue = env['result'] ?? '';
    if (resultValue.trim().isNotEmpty && resultValue != responseText) {
      return resultValue;
    }

    final contentValue = env['content'] ?? '';
    if (contentValue.trim().isNotEmpty && contentValue != responseText) {
      return contentValue;
    }

    return '';
  }

  String? _evalStageJsExpressionFallback(
    String expression,
    Map<String, String> env,
  ) {
    final trimmed = expression.trim();
    if (trimmed.isEmpty) return '';

    final stringify = RegExp(
      r'^JSON\.stringify\s*\(([\s\S]*)\)\s*;?$',
      caseSensitive: false,
    ).firstMatch(trimmed);
    if (stringify != null) {
      final inner = stringify.group(1)?.trim() ?? '';
      if (inner.isEmpty) return '';

      final fromEnv = env[inner];
      if (fromEnv != null) {
        final decoded = _tryDecodeJsonValue(fromEnv);
        return jsonEncode(decoded ?? fromEnv);
      }

      final strLiteral = _decodeSimpleJsStringLiteral(inner);
      if (strLiteral != null) {
        return jsonEncode(strLiteral);
      }

      final normalizedJson = _normalizeLooseJsonLiteral(inner);
      if (normalizedJson != null) {
        return normalizedJson;
      }

      return null;
    }

    final concat = _evalSimpleJsConcat(
      trimmed,
      resolveAtom: (atom) => _resolveStageJsAtomFallback(atom, env),
    );
    if (concat != null) return concat;

    return _resolveStageJsAtomFallback(trimmed, env);
  }

  String? _resolveStageJsAtomFallback(String atom, Map<String, String> env) {
    final trimmed = atom.trim();
    if (trimmed.isEmpty) return '';

    final strLiteral = _decodeSimpleJsStringLiteral(trimmed);
    if (strLiteral != null) return strLiteral;

    if (env.containsKey(trimmed)) return env[trimmed];

    if (trimmed.startsWith('vars[') && trimmed.endsWith(']')) {
      final inner = trimmed.substring(5, trimmed.length - 1).trim();
      if (inner.isEmpty) return '';
      final key = _decodeJsIndexKey(inner);
      return _getRuntimeVariable(key);
    }

    final varsDot =
        RegExp(r'^vars\.([A-Za-z_][A-Za-z0-9_]*)$').firstMatch(trimmed);
    if (varsDot != null) {
      final key = varsDot.group(1) ?? '';
      return _getRuntimeVariable(key);
    }

    if (RegExp(r'^-?\d+(?:\.\d+)?$').hasMatch(trimmed)) {
      return trimmed;
    }

    return null;
  }

  String? _normalizeLooseJsonLiteral(String source) {
    var text = source.trim();
    if (text.isEmpty) return null;
    if (!(text.startsWith('{') || text.startsWith('['))) return null;

    text = text.replaceAllMapped(
      RegExp(r"'([^'\\]*(?:\\.[^'\\]*)*)'"),
      (m) {
        final inner = m.group(1) ?? '';
        final decoded = _unescapeSingleQuotedJsString(inner);
        return jsonEncode(decoded);
      },
    );

    text = text.replaceAllMapped(
      RegExp(r'([\{\[, ]\s*)([A-Za-z_\$][A-Za-z0-9_\$]*)\s*:'),
      (m) => '${m.group(1)}"${m.group(2)}":',
    );

    text = text.replaceAll(RegExp(r'\bundefined\b'), 'null');

    final decoded = _tryDecodeJsonValue(text);
    if (decoded == null) return null;
    try {
      return jsonEncode(decoded);
    } catch (_) {
      return null;
    }
  }

  List<String> _splitPossibleListValues(String text) {
    final t = text.trim();
    if (t.isEmpty) return const <String>[];
    // 常见情况：规则返回多行 URL 或用逗号拼接
    final parts = t
        .split(RegExp(r'[\r\n]+|,|，|;|；'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList(growable: false);
    return parts.isEmpty ? <String>[t] : parts;
  }

  String _normalizeUrlVisitKey(String url) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return '';
    final uri = Uri.tryParse(trimmed);
    if (uri == null) return trimmed;
    if (uri.scheme.isEmpty || uri.host.isEmpty) return trimmed;
    // 分页去重时忽略 hash，避免同页锚点导致重复翻页。
    return uri.replace(fragment: '').toString();
  }

  String? _buildNextChapterUrlKey({
    required String chapterEntryUrl,
    String? nextChapterUrl,
  }) {
    final raw = (nextChapterUrl ?? '').trim();
    if (raw.isEmpty) return null;
    final absolute = _absoluteUrl(chapterEntryUrl, raw);
    final key = _normalizeUrlVisitKey(absolute);
    return key.isEmpty ? null : key;
  }

  bool _markVisitedUrl(Set<String> visitedUrlKeys, String url) {
    final key = _normalizeUrlVisitKey(url);
    if (key.isEmpty || visitedUrlKeys.contains(key)) return false;
    visitedUrlKeys.add(key);
    return true;
  }

  List<String> _collectNextUrlCandidates(
    List<String> candidates, {
    required String currentUrl,
    required Set<String> visitedUrlKeys,
    Set<String>? queuedUrlKeys,
    String? blockedUrlKey,
  }) {
    if (candidates.isEmpty) return const <String>[];

    final currentKey = _normalizeUrlVisitKey(currentUrl);
    final seenInBatch = <String>{};
    final out = <String>[];

    for (final candidate in candidates) {
      final raw = candidate.trim();
      if (raw.isEmpty) continue;

      final absolute = _absoluteUrl(currentUrl, raw);
      final key = _normalizeUrlVisitKey(absolute);
      if (key.isEmpty) continue;
      if (!seenInBatch.add(key)) continue;
      if (key == currentKey) continue;
      if (blockedUrlKey != null &&
          blockedUrlKey.isNotEmpty &&
          key == blockedUrlKey) {
        continue;
      }
      if (visitedUrlKeys.contains(key)) continue;
      if (queuedUrlKeys != null && queuedUrlKeys.contains(key)) continue;
      out.add(absolute);
    }

    return out;
  }

  ({List<String> urls, List<String> debugLines, bool hasBlockedCandidate})
      _collectNextUrlCandidatesWithDebug(
    List<String> candidates, {
    required String currentUrl,
    required Set<String> visitedUrlKeys,
    Set<String>? queuedUrlKeys,
    String? blockedUrlKey,
    int maxLogItems = 20,
  }) {
    if (candidates.isEmpty) {
      return (
        urls: const <String>[],
        debugLines: const <String>['候选为空'],
        hasBlockedCandidate: false,
      );
    }

    final currentKey = _normalizeUrlVisitKey(currentUrl);
    final seenInBatch = <String>{};
    final out = <String>[];
    final lines = <String>[];
    var hasBlockedCandidate = false;
    var omitted = 0;

    for (var i = 0; i < candidates.length; i++) {
      final candidate = candidates[i];
      final raw = candidate.trim();
      String reason;
      String? absolute;

      if (raw.isEmpty) {
        reason = '跳过：空值';
      } else {
        absolute = _absoluteUrl(currentUrl, raw);
        final key = _normalizeUrlVisitKey(absolute);
        if (key.isEmpty) {
          reason = '跳过：无效链接';
        } else if (!seenInBatch.add(key)) {
          reason = '跳过：本批重复';
        } else if (key == currentKey) {
          reason = '跳过：当前页';
        } else if (blockedUrlKey != null &&
            blockedUrlKey.isNotEmpty &&
            key == blockedUrlKey) {
          hasBlockedCandidate = true;
          reason = '跳过：命中下一章';
        } else if (visitedUrlKeys.contains(key)) {
          reason = '跳过：已访问';
        } else if (queuedUrlKeys != null && queuedUrlKeys.contains(key)) {
          reason = '跳过：已在队列';
        } else {
          out.add(absolute);
          reason = '入队';
        }
      }

      if (i < maxLogItems) {
        final src = raw.isEmpty ? '(空)' : raw;
        final dst = absolute == null ? '' : ' => $absolute';
        lines.add('[$i] $src$dst | $reason');
      } else {
        omitted++;
      }
    }

    if (omitted > 0) {
      lines.add('…其余 $omitted 条候选省略');
    }
    lines.add(
      '汇总：新增 ${out.length} 条；已访问 ${visitedUrlKeys.length} 条；'
      '待处理队列 ${(queuedUrlKeys ?? const <String>{}).length} 条',
    );

    return (
      urls: out,
      debugLines: lines,
      hasBlockedCandidate: hasBlockedCandidate,
    );
  }

  String? _pickNextUrlCandidate(
    List<String> candidates, {
    required String currentUrl,
    required Set<String> visitedUrlKeys,
    String? blockedUrlKey,
  }) {
    final list = _collectNextUrlCandidates(
      candidates,
      currentUrl: currentUrl,
      visitedUrlKeys: visitedUrlKeys,
      blockedUrlKey: blockedUrlKey,
    );
    return list.isEmpty ? null : list.first;
  }

  String _normalizeVariableKey(String key) {
    return key.trim();
  }

  String _getRuntimeVariable(String key) {
    final normalized = _normalizeVariableKey(key);
    if (normalized.isEmpty) return '';
    return _runtimeVariables[normalized] ?? '';
  }

  bool _isSensitiveVariableKey(String key) {
    final lower = key.trim().toLowerCase();
    if (lower.isEmpty) return false;
    const tags = <String>[
      'token',
      'cookie',
      'auth',
      'password',
      'passwd',
      'pwd',
      'secret',
      'session',
      'sid',
      'apikey',
      'api_key',
      'authorization',
      'refresh',
    ];
    for (final item in tags) {
      if (lower.contains(item)) return true;
    }
    return false;
  }

  String _maskRuntimeVariableValue(String value, {required bool strong}) {
    final text = value.trim();
    if (text.isEmpty) return '';
    if (strong) {
      if (text.length <= 4) return '*' * text.length;
      final tail = text.substring(text.length - 2);
      return '${'*' * (text.length - 2)}$tail';
    }

    if (text.length <= 2) return '*' * text.length;
    if (text.length <= 8) {
      return '${text.substring(0, 1)}${'*' * (text.length - 1)}';
    }
    final head = text.substring(0, 2);
    final tail = text.substring(text.length - 2);
    return '$head${'*' * (text.length - 4)}$tail';
  }

  Map<String, String> _runtimeVariableSnapshot({required bool desensitize}) {
    if (_runtimeVariables.isEmpty) return const <String, String>{};
    final out = <String, String>{};
    final entries = _runtimeVariables.entries.toList(growable: false)
      ..sort((a, b) => a.key.compareTo(b.key));
    for (final entry in entries) {
      final key = entry.key.trim();
      if (key.isEmpty) continue;
      final value = entry.value;
      if (!desensitize) {
        out[key] = value;
        continue;
      }
      out[key] = _maskRuntimeVariableValue(
        value,
        strong: _isSensitiveVariableKey(key),
      );
    }
    return out;
  }

  void _putRuntimeVariable(String key, String value) {
    final normalized = _normalizeVariableKey(key);
    if (normalized.isEmpty) return;
    _runtimeVariables[normalized] = value;
  }

  void _clearRuntimeVariables() {
    _runtimeVariables.clear();
  }

  String _replaceGetTokens(String input) {
    if (input.isEmpty || !input.contains('@get:{')) return input;
    return input.replaceAllMapped(
      RegExp(r'@get:\{([^{}]+)\}'),
      (match) {
        final key = match.group(1)?.trim() ?? '';
        return _getRuntimeVariable(key);
      },
    );
  }

  bool _isPureGetTokenRule(String rawRule) {
    final trimmed = rawRule.trim();
    if (trimmed.isEmpty) return false;
    return RegExp(r'^@get:\{[^{}]+\}$').hasMatch(trimmed);
  }

  bool _isPureTemplateTokenRule(String rawRule) {
    final trimmed = rawRule.trim();
    if (trimmed.length < 4) return false;
    if (!trimmed.startsWith('{{') || !trimmed.endsWith('}}')) return false;
    return trimmed.indexOf('{{') == 0 &&
        trimmed.lastIndexOf('}}') == trimmed.length - 2;
  }

  bool _isLiteralRuleCandidate(String rawRule) {
    if (rawRule.trim().isEmpty) return false;
    return _isPureGetTokenRule(rawRule) || _isPureTemplateTokenRule(rawRule);
  }

  Map<String, Object?> _buildUrlJsBindings({
    required String baseUrl,
    required String result,
    required Map<String, String> params,
  }) {
    final bindings = <String, Object?>{
      'baseUrl': baseUrl,
      'result': result,
      'vars': Map<String, String>.from(_runtimeVariables),
      'params': Map<String, String>.from(params),
    };
    for (final entry in params.entries) {
      final key = entry.key.trim();
      if (key.isEmpty) continue;
      bindings[key] = entry.value;
    }
    return bindings;
  }

  String? _resolveUrlJsAtom(
    String atom, {
    required String baseUrl,
    required String result,
    required Map<String, String> params,
  }) {
    final trimmed = atom.trim();
    if (trimmed.isEmpty) return '';

    final strLiteral = _decodeSimpleJsStringLiteral(trimmed);
    if (strLiteral != null) return strLiteral;

    if (trimmed == '@result' || trimmed == 'result') return result;
    if (trimmed == 'baseUrl') return baseUrl;

    if (trimmed.startsWith('params[') && trimmed.endsWith(']')) {
      final inner = trimmed.substring(7, trimmed.length - 1).trim();
      if (inner.isEmpty) return '';
      final key = _decodeJsIndexKey(inner);
      return params[key] ?? '';
    }

    final paramsDot =
        RegExp(r'^params\.([A-Za-z_][A-Za-z0-9_]*)$').firstMatch(trimmed);
    if (paramsDot != null) {
      final key = paramsDot.group(1) ?? '';
      return params[key] ?? '';
    }

    if (trimmed.startsWith('vars[') && trimmed.endsWith(']')) {
      final inner = trimmed.substring(5, trimmed.length - 1).trim();
      if (inner.isEmpty) return '';
      final key = _decodeJsIndexKey(inner);
      return _getRuntimeVariable(key);
    }

    final varsDot =
        RegExp(r'^vars\.([A-Za-z_][A-Za-z0-9_]*)$').firstMatch(trimmed);
    if (varsDot != null) {
      final key = varsDot.group(1) ?? '';
      return _getRuntimeVariable(key);
    }

    final fromParams = params[trimmed];
    if (fromParams != null) return fromParams;

    final fromRuntime = _runtimeVariables[trimmed];
    if (fromRuntime != null) return fromRuntime;

    if (RegExp(r'^-?\d+(?:\.\d+)?$').hasMatch(trimmed)) {
      return trimmed;
    }

    return null;
  }

  String? _evalUrlJsFallback(
    String jsCode, {
    required String baseUrl,
    required String result,
    required Map<String, String> params,
  }) {
    final split = _splitRuleByTopLevelOperator(jsCode, const ['+']);
    if (split.parts.isEmpty) return null;

    final out = StringBuffer();
    for (final part in split.parts) {
      final value = _resolveUrlJsAtom(
        part,
        baseUrl: baseUrl,
        result: result,
        params: params,
      );
      if (value == null) return null;
      out.write(value);
    }
    return out.toString();
  }

  String _evalUrlJsSegment(
    String jsCode, {
    required String baseUrl,
    required String result,
    required Map<String, String> params,
    String? jsLib,
  }) {
    var output = _evalJsMaybeString(
      js: jsCode,
      jsLib: jsLib,
      bindings: _buildUrlJsBindings(
        baseUrl: baseUrl,
        result: result,
        params: params,
      ),
    ).trim();

    if (output.isEmpty) {
      output = _evalSimpleJsLibFunctionCall(
            jsCode,
            jsLib: jsLib,
            resolveAtom: (atom) => _resolveUrlJsAtom(
              atom,
              baseUrl: baseUrl,
              result: result,
              params: params,
            ),
          )?.trim() ??
          '';
    }

    if (output.isEmpty) {
      output = _evalUrlJsFallback(
            jsCode,
            baseUrl: baseUrl,
            result: result,
            params: params,
          )?.trim() ??
          '';
    }

    if (output.isEmpty) return result;
    return output.replaceAll('@result', result);
  }

  String _applyUrlJsSegments(
    String rawRule, {
    required String baseUrl,
    required Map<String, String> params,
    String? jsLib,
  }) {
    final source = rawRule;
    if (source.isEmpty) return source;
    if (!source.contains('@js:') && !source.toLowerCase().contains('<js>')) {
      return source;
    }

    var index = 0;
    var segmentStart = 0;
    var hasToken = false;

    String? quote;
    var parenDepth = 0;
    var bracketDepth = 0;
    var braceDepth = 0;

    var result = '';
    var initialized = false;

    void applyLiteralSegment(int start, int end) {
      if (end <= start) return;
      final segment = source.substring(start, end).trim();
      if (segment.isEmpty) return;

      if (!initialized) {
        result = segment;
        initialized = true;
        return;
      }

      if (segment.contains('@result')) {
        result = segment.replaceAll('@result', result);
      } else {
        result = '$result$segment';
      }
    }

    while (index < source.length) {
      final ch = source[index];

      if (quote != null) {
        if (ch == '\\' && index + 1 < source.length) {
          index += 2;
          continue;
        }
        if (ch == quote) quote = null;
        index++;
        continue;
      }

      if (ch == '\\' && index + 1 < source.length) {
        index += 2;
        continue;
      }

      if (ch == '"' || ch == "'") {
        quote = ch;
        index++;
        continue;
      }

      if (ch == '(') {
        parenDepth++;
        index++;
        continue;
      }
      if (ch == ')') {
        if (parenDepth > 0) parenDepth--;
        index++;
        continue;
      }
      if (ch == '[') {
        bracketDepth++;
        index++;
        continue;
      }
      if (ch == ']') {
        if (bracketDepth > 0) bracketDepth--;
        index++;
        continue;
      }
      if (ch == '{') {
        braceDepth++;
        index++;
        continue;
      }
      if (ch == '}') {
        if (braceDepth > 0) braceDepth--;
        index++;
        continue;
      }

      final atTopLevel =
          parenDepth == 0 && bracketDepth == 0 && braceDepth == 0;
      if (!atTopLevel) {
        index++;
        continue;
      }

      if (source.substring(index).toLowerCase().startsWith('<js>')) {
        final closeIndex = source.toLowerCase().indexOf('</js>', index + 4);
        if (closeIndex < 0) {
          index++;
          continue;
        }

        hasToken = true;
        applyLiteralSegment(segmentStart, index);

        final jsCode = source.substring(index + 4, closeIndex).trim();
        result = _evalUrlJsSegment(
          jsCode,
          baseUrl: baseUrl,
          result: result,
          params: params,
          jsLib: jsLib,
        );
        initialized = true;

        index = closeIndex + 5;
        segmentStart = index;
        continue;
      }

      if (source.substring(index).toLowerCase().startsWith('@js:')) {
        hasToken = true;
        applyLiteralSegment(segmentStart, index);

        final jsCode = source.substring(index + 4).trim();
        result = _evalUrlJsSegment(
          jsCode,
          baseUrl: baseUrl,
          result: result,
          params: params,
          jsLib: jsLib,
        );
        initialized = true;

        segmentStart = source.length;
        break;
      }

      index++;
    }

    if (!hasToken) return source;

    applyLiteralSegment(segmentStart, source.length);
    return initialized ? result : source;
  }

  String _unescapeSingleQuotedJsString(String text) {
    final out = StringBuffer();
    for (var i = 0; i < text.length; i++) {
      final ch = text[i];
      if (ch == '\\' && i + 1 < text.length) {
        final next = text[++i];
        switch (next) {
          case 'n':
            out.write('\n');
            break;
          case 'r':
            out.write('\r');
            break;
          case 't':
            out.write('\t');
            break;
          case '\\':
            out.write('\\');
            break;
          case "'":
            out.write("'");
            break;
          case '"':
            out.write('"');
            break;
          default:
            out.write(next);
            break;
        }
        continue;
      }
      out.write(ch);
    }
    return out.toString();
  }

  String? _decodeSimpleJsStringLiteral(String token) {
    final trimmed = token.trim();
    if (trimmed.length < 2) return null;

    if (trimmed.startsWith('"') && trimmed.endsWith('"')) {
      try {
        final decoded = jsonDecode(trimmed);
        if (decoded is String) return decoded;
      } catch (_) {
        return trimmed.substring(1, trimmed.length - 1);
      }
    }

    if (trimmed.startsWith("'") && trimmed.endsWith("'")) {
      final inner = trimmed.substring(1, trimmed.length - 1);
      return _unescapeSingleQuotedJsString(inner);
    }

    return null;
  }

  String _decodeJsIndexKey(String raw) {
    final decoded = _decodeSimpleJsStringLiteral(raw);
    return decoded ?? raw.trim();
  }

  String? _evalSimpleTemplateAtom(String atom) {
    final trimmed = atom.trim();
    if (trimmed.isEmpty) return '';

    final strLiteral = _decodeSimpleJsStringLiteral(trimmed);
    if (strLiteral != null) return strLiteral;

    if (trimmed.startsWith('vars[') && trimmed.endsWith(']')) {
      final inner = trimmed.substring(5, trimmed.length - 1).trim();
      if (inner.isEmpty) return '';
      final key = _decodeJsIndexKey(inner);
      return _getRuntimeVariable(key);
    }

    final varsDot =
        RegExp(r'^vars\.([A-Za-z_][A-Za-z0-9_]*)$').firstMatch(trimmed);
    if (varsDot != null) {
      final key = varsDot.group(1) ?? '';
      return _getRuntimeVariable(key);
    }

    final directVar = _runtimeVariables[trimmed];
    if (directVar != null) return directVar;

    if (trimmed == 'baseUrl') return '';
    if (trimmed == 'result') return '';

    return null;
  }

  String? _evalSimpleTemplateExpression(String code) {
    final split = _splitRuleByTopLevelOperator(code, const ['+']);
    if (split.parts.isEmpty) return null;
    if (split.operator == null) {
      return _evalSimpleTemplateAtom(split.parts.first);
    }

    final out = StringBuffer();
    for (final part in split.parts) {
      final value = _evalSimpleTemplateAtom(part);
      if (value == null) return null;
      out.write(value);
    }
    return out.toString();
  }

  String? _evalSimpleJsConcat(
    String code, {
    required String? Function(String atom) resolveAtom,
  }) {
    final split = _splitRuleByTopLevelOperator(code, const ['+']);
    if (split.parts.isEmpty) return null;

    if (split.operator == null) {
      return resolveAtom(split.parts.first);
    }

    final out = StringBuffer();
    for (final part in split.parts) {
      final value = resolveAtom(part);
      if (value == null) return null;
      out.write(value);
    }
    return out.toString();
  }

  Map<String, ({List<String> args, String returnExpr})>
      _parseSimpleJsLibFunctions(String? jsLib) {
    final source = (jsLib ?? '').trim();
    if (source.isEmpty) {
      return const <String, ({List<String> args, String returnExpr})>{};
    }

    final out = <String, ({List<String> args, String returnExpr})>{};
    final matches = RegExp(
      r'function\s+([A-Za-z_\$][A-Za-z0-9_\$]*)\s*\(([^)]*)\)\s*\{([\s\S]*?)\}',
      multiLine: true,
    ).allMatches(source);

    for (final m in matches) {
      final name = m.group(1)?.trim() ?? '';
      if (name.isEmpty) continue;

      final argsRaw = m.group(2)?.trim() ?? '';
      final body = m.group(3)?.trim() ?? '';
      if (body.isEmpty) continue;

      final returnMatch = RegExp(
        r'^return\s+([\s\S]*?);?\s*$',
        dotAll: true,
      ).firstMatch(body);
      if (returnMatch == null) continue;

      final returnExpr = returnMatch.group(1)?.trim() ?? '';
      if (returnExpr.isEmpty) continue;

      final args = argsRaw.isEmpty
          ? const <String>[]
          : argsRaw
              .split(',')
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toList(growable: false);

      out[name] = (args: args, returnExpr: returnExpr);
    }

    return out;
  }

  String? _evalSimpleJsLibFunctionCall(
    String jsCode, {
    String? jsLib,
    required String? Function(String atom) resolveAtom,
  }) {
    final functions = _parseSimpleJsLibFunctions(jsLib);
    if (functions.isEmpty) return null;

    final call = RegExp(
      r'^([A-Za-z_\$][A-Za-z0-9_\$]*)\s*\((.*)\)\s*;?$',
      dotAll: true,
    ).firstMatch(jsCode.trim());
    if (call == null) return null;

    final fnName = call.group(1)?.trim() ?? '';
    if (fnName.isEmpty) return null;

    final fn = functions[fnName];
    if (fn == null) return null;

    final argsRaw = call.group(2)?.trim() ?? '';
    final callArgs =
        argsRaw.isEmpty ? const <String>[] : _splitByTopLevelComma(argsRaw);

    final local = <String, String>{};
    for (var i = 0; i < fn.args.length; i++) {
      final key = fn.args[i].trim();
      if (key.isEmpty) continue;
      final rawArg = i < callArgs.length ? callArgs[i].trim() : '';
      final resolved = _evalSimpleJsConcat(
        rawArg,
        resolveAtom: resolveAtom,
      );
      local[key] = resolved ?? '';
    }

    return _evalSimpleJsConcat(
      fn.returnExpr,
      resolveAtom: (atom) {
        final t = atom.trim();
        if (local.containsKey(t)) {
          return local[t];
        }
        return resolveAtom(atom);
      },
    );
  }

  String _applyTemplateJsTokens(
    String input, {
    required String baseUrl,
    String? jsLib,
  }) {
    if (input.isEmpty || !input.contains('{{')) return input;

    return input.replaceAllMapped(
      RegExp(r'\{\{([\s\S]*?)\}\}'),
      (match) {
        final code = match.group(1)?.trim() ?? '';
        if (code.isEmpty) return '';

        final directVar = _runtimeVariables[code];
        if (directVar != null) {
          return directVar;
        }

        if (_looksLikeJsonPath(code) ||
            _looksLikeXPath(code) ||
            _looksLikeRegexRule(code)) {
          final value = _getRuntimeVariable(code);
          if (value.isNotEmpty) return value;
        }

        final simple = _evalSimpleTemplateExpression(code);
        if (simple != null) {
          return simple;
        }

        final jsOut = _evalJsMaybeString(
          js: code,
          jsLib: jsLib,
          bindings: <String, Object?>{
            'baseUrl': baseUrl,
            'result': input,
            'vars': Map<String, String>.from(_runtimeVariables),
          },
        ).trim();
        if (jsOut.isNotEmpty) return jsOut;

        final fallback = _evalSimpleJsLibFunctionCall(
          code,
          jsLib: jsLib,
          resolveAtom: (atom) {
            final trimmedAtom = atom.trim();
            if (trimmedAtom == 'baseUrl') return baseUrl;
            if (trimmedAtom == 'result') return input;
            return _evalSimpleTemplateAtom(trimmedAtom);
          },
        );
        return fallback ?? '';
      },
    );
  }

  int _findBalancedBraceEnd(String source, int openBraceIndex) {
    if (openBraceIndex < 0 || openBraceIndex >= source.length) return -1;
    if (source[openBraceIndex] != '{') return -1;

    var depth = 0;
    String? quote;

    for (var i = openBraceIndex; i < source.length; i++) {
      final ch = source[i];
      if (quote != null) {
        if (ch == '\\' && i + 1 < source.length) {
          i++;
          continue;
        }
        if (ch == quote) quote = null;
        continue;
      }

      if (ch == '"' || ch == "'") {
        quote = ch;
        continue;
      }

      if (ch == '{') {
        depth++;
        continue;
      }
      if (ch == '}') {
        depth--;
        if (depth == 0) return i;
        if (depth < 0) return -1;
      }
    }
    return -1;
  }

  List<String> _splitByTopLevelComma(String text) {
    final out = <String>[];
    final buffer = StringBuffer();
    String? quote;
    var parenDepth = 0;
    var bracketDepth = 0;
    var braceDepth = 0;

    void push() {
      final one = buffer.toString().trim();
      buffer.clear();
      if (one.isNotEmpty) out.add(one);
    }

    for (var i = 0; i < text.length; i++) {
      final ch = text[i];
      if (quote != null) {
        buffer.write(ch);
        if (ch == '\\' && i + 1 < text.length) {
          i++;
          buffer.write(text[i]);
          continue;
        }
        if (ch == quote) quote = null;
        continue;
      }

      if (ch == '\\' && i + 1 < text.length) {
        buffer.write(ch);
        i++;
        buffer.write(text[i]);
        continue;
      }
      if (ch == '"' || ch == "'") {
        quote = ch;
        buffer.write(ch);
        continue;
      }

      if (ch == '(') parenDepth++;
      if (ch == ')') parenDepth = parenDepth > 0 ? (parenDepth - 1) : 0;
      if (ch == '[') bracketDepth++;
      if (ch == ']') bracketDepth = bracketDepth > 0 ? (bracketDepth - 1) : 0;
      if (ch == '{') braceDepth++;
      if (ch == '}') braceDepth = braceDepth > 0 ? (braceDepth - 1) : 0;

      final atTopLevel =
          parenDepth == 0 && bracketDepth == 0 && braceDepth == 0;
      if (atTopLevel && ch == ',') {
        push();
        continue;
      }
      buffer.write(ch);
    }
    push();
    return out;
  }

  int _indexOfTopLevelColon(String text) {
    String? quote;
    var parenDepth = 0;
    var bracketDepth = 0;
    var braceDepth = 0;

    for (var i = 0; i < text.length; i++) {
      final ch = text[i];
      if (quote != null) {
        if (ch == '\\' && i + 1 < text.length) {
          i++;
          continue;
        }
        if (ch == quote) quote = null;
        continue;
      }

      if (ch == '"' || ch == "'") {
        quote = ch;
        continue;
      }
      if (ch == '(') parenDepth++;
      if (ch == ')') parenDepth = parenDepth > 0 ? (parenDepth - 1) : 0;
      if (ch == '[') bracketDepth++;
      if (ch == ']') bracketDepth = bracketDepth > 0 ? (bracketDepth - 1) : 0;
      if (ch == '{') braceDepth++;
      if (ch == '}') braceDepth = braceDepth > 0 ? (braceDepth - 1) : 0;

      final atTopLevel =
          parenDepth == 0 && bracketDepth == 0 && braceDepth == 0;
      if (atTopLevel && ch == ':') {
        return i;
      }
    }
    return -1;
  }

  String _stripPairedQuotes(String text) {
    if (text.length < 2) return text;
    final first = text[0];
    final last = text[text.length - 1];
    if ((first == '"' && last == '"') || (first == "'" && last == "'")) {
      return text.substring(1, text.length - 1);
    }
    return text;
  }

  void _mergePutMapFromText(String jsonLikeText, Map<String, String> putMap) {
    final text = jsonLikeText.trim();
    if (text.isEmpty) return;

    try {
      final decoded = jsonDecode(text);
      if (decoded is Map) {
        decoded.forEach((k, v) {
          if (k == null || v == null) return;
          final key = k.toString().trim();
          if (key.isEmpty) return;
          putMap[key] = v.toString();
        });
        return;
      }
    } catch (_) {
      // ignore and fallback to宽松解析
    }

    var inner = text;
    if (inner.startsWith('{') && inner.endsWith('}')) {
      inner = inner.substring(1, inner.length - 1).trim();
    }
    if (inner.isEmpty) return;

    final pairs = _splitByTopLevelComma(inner);
    for (final pair in pairs) {
      final one = pair.trim();
      if (one.isEmpty) continue;

      final idx = _indexOfTopLevelColon(one);
      if (idx <= 0) continue;

      final key = _stripPairedQuotes(one.substring(0, idx).trim());
      var value = one.substring(idx + 1).trim();
      value = _stripPairedQuotes(value);

      if (key.isEmpty) continue;
      putMap[key] = value;
    }
  }

  ({String cleanedRule, Map<String, String> putMap}) _extractPutRules(
      String rawRule) {
    if (rawRule.trim().isEmpty) {
      return (cleanedRule: '', putMap: <String, String>{});
    }

    final putMap = <String, String>{};
    final cleaned = StringBuffer();

    String? quote;
    var parenDepth = 0;
    var bracketDepth = 0;
    var braceDepth = 0;

    var index = 0;
    while (index < rawRule.length) {
      final ch = rawRule[index];

      if (quote != null) {
        cleaned.write(ch);
        if (ch == '\\' && index + 1 < rawRule.length) {
          index++;
          cleaned.write(rawRule[index]);
          index++;
          continue;
        }
        if (ch == quote) quote = null;
        index++;
        continue;
      }

      if (ch == '\\' && index + 1 < rawRule.length) {
        cleaned.write(ch);
        index++;
        cleaned.write(rawRule[index]);
        index++;
        continue;
      }

      final atTopLevel =
          parenDepth == 0 && bracketDepth == 0 && braceDepth == 0;
      if (atTopLevel && rawRule.startsWith('@put:{', index)) {
        final openBraceIndex = index + '@put:'.length;
        final closeBraceIndex = _findBalancedBraceEnd(rawRule, openBraceIndex);
        if (closeBraceIndex > openBraceIndex) {
          final jsonText =
              rawRule.substring(openBraceIndex, closeBraceIndex + 1);
          _mergePutMapFromText(jsonText, putMap);
          index = closeBraceIndex + 1;
          continue;
        }
      }

      if (ch == '"' || ch == "'") {
        quote = ch;
        cleaned.write(ch);
        index++;
        continue;
      }
      if (ch == '(') {
        parenDepth++;
        cleaned.write(ch);
        index++;
        continue;
      }
      if (ch == ')') {
        if (parenDepth > 0) parenDepth--;
        cleaned.write(ch);
        index++;
        continue;
      }
      if (ch == '[') {
        bracketDepth++;
        cleaned.write(ch);
        index++;
        continue;
      }
      if (ch == ']') {
        if (bracketDepth > 0) bracketDepth--;
        cleaned.write(ch);
        index++;
        continue;
      }
      if (ch == '{') {
        braceDepth++;
        cleaned.write(ch);
        index++;
        continue;
      }
      if (ch == '}') {
        if (braceDepth > 0) braceDepth--;
        cleaned.write(ch);
        index++;
        continue;
      }

      cleaned.write(ch);
      index++;
    }

    return (cleanedRule: cleaned.toString().trim(), putMap: putMap);
  }

  void _applyPutRules(
    Map<String, String> putMap, {
    required dynamic node,
    required String baseUrl,
    String? jsLib,
  }) {
    if (putMap.isEmpty) return;
    for (final entry in putMap.entries) {
      final rawValueRule = entry.value;
      if (rawValueRule.trim().isEmpty) continue;

      var resolvedValueRule = _replaceGetTokens(rawValueRule);
      resolvedValueRule = _applyTemplateJsTokens(
        resolvedValueRule,
        baseUrl: baseUrl,
        jsLib: jsLib,
      );

      final value = _isLiteralRuleCandidate(rawValueRule)
          ? resolvedValueRule.trim()
          : _parseValueOnNode(node, resolvedValueRule, baseUrl);
      _putRuntimeVariable(entry.key, value);
    }
  }

  _TopLevelRuleSplit _splitRuleByTopLevelOperator(
    String raw,
    List<String> operators,
  ) {
    final source = raw.trim();
    if (source.isEmpty) {
      return const _TopLevelRuleSplit(
        parts: <String>[],
        operator: null,
      );
    }

    final operatorSet = operators
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList(growable: false);
    if (operatorSet.isEmpty) {
      return _TopLevelRuleSplit(parts: <String>[source], operator: null);
    }

    final matchOrder = operatorSet.toList(growable: false)
      ..sort((a, b) => b.length.compareTo(a.length));

    final parts = <String>[];
    final buffer = StringBuffer();
    String? activeOperator;

    String? quote;
    var parenDepth = 0;
    var bracketDepth = 0;
    var braceDepth = 0;

    void flush() {
      final value = buffer.toString().trim();
      buffer.clear();
      if (value.isNotEmpty) {
        parts.add(value);
      }
    }

    var index = 0;
    while (index < source.length) {
      final ch = source[index];

      if (quote != null) {
        buffer.write(ch);
        if (ch == '\\' && index + 1 < source.length) {
          index++;
          buffer.write(source[index]);
          index++;
          continue;
        }
        if (ch == quote) {
          quote = null;
        }
        index++;
        continue;
      }

      if (ch == '\\' && index + 1 < source.length) {
        buffer.write(ch);
        index++;
        buffer.write(source[index]);
        index++;
        continue;
      }

      if (ch == '"' || ch == "'") {
        quote = ch;
        buffer.write(ch);
        index++;
        continue;
      }

      if (ch == '(') {
        parenDepth++;
        buffer.write(ch);
        index++;
        continue;
      }
      if (ch == ')') {
        if (parenDepth > 0) parenDepth--;
        buffer.write(ch);
        index++;
        continue;
      }

      if (ch == '[') {
        bracketDepth++;
        buffer.write(ch);
        index++;
        continue;
      }
      if (ch == ']') {
        if (bracketDepth > 0) bracketDepth--;
        buffer.write(ch);
        index++;
        continue;
      }

      if (ch == '{') {
        braceDepth++;
        buffer.write(ch);
        index++;
        continue;
      }
      if (ch == '}') {
        if (braceDepth > 0) braceDepth--;
        buffer.write(ch);
        index++;
        continue;
      }

      final atTopLevel =
          parenDepth == 0 && bracketDepth == 0 && braceDepth == 0;
      if (atTopLevel) {
        if (activeOperator == null) {
          for (final candidate in matchOrder) {
            if (source.startsWith(candidate, index)) {
              activeOperator = candidate;
              break;
            }
          }
        }

        if (activeOperator != null &&
            source.startsWith(activeOperator, index)) {
          flush();
          index += activeOperator.length;
          continue;
        }
      }

      buffer.write(ch);
      index++;
    }

    flush();
    if (parts.isEmpty) {
      parts.add(source);
    }
    return _TopLevelRuleSplit(parts: parts, operator: activeOperator);
  }

  List<String> _mergeRuleListResults(
    List<List<String>> results,
    String? operator,
  ) {
    if (results.isEmpty) return const <String>[];
    if (operator == '%%') {
      final out = <String>[];
      final first = results.first;
      for (var i = 0; i < first.length; i++) {
        for (final list in results) {
          if (i < list.length) {
            out.add(list[i]);
          }
        }
      }
      return out;
    }

    final out = <String>[];
    for (final list in results) {
      out.addAll(list);
    }
    return out;
  }

  String _mergeRuleTextResults(
    List<String> results,
    String? operator,
  ) {
    if (results.isEmpty) return '';
    if (operator == '||') return results.first;
    return results.join('\n').trim();
  }

  List<String> _parseStringListFromHtmlSingle(
    Element root,
    String rule,
    String baseUrl,
    bool isUrl,
  ) {
    final extracted = _extractPutRules(rule);
    final one = extracted.cleanedRule.trim();
    if (one.isEmpty) return const <String>[];

    _applyPutRules(
      extracted.putMap,
      node: root,
      baseUrl: baseUrl,
    );

    var resolvedRule = _replaceGetTokens(one);
    resolvedRule = _applyTemplateJsTokens(
      resolvedRule,
      baseUrl: baseUrl,
    );

    if (_isLiteralRuleCandidate(one)) {
      final values = _splitPossibleListValues(resolvedRule);
      if (values.isEmpty) return const <String>[];
      return values
          .map((e) => isUrl ? _absoluteUrl(baseUrl, e) : e)
          .toList(growable: false);
    }

    if (_looksLikeXPath(resolvedRule)) {
      final v = _parseXPathRule(root, resolvedRule, baseUrl);
      final values = _splitPossibleListValues(v);
      if (values.isNotEmpty) {
        return values
            .map((e) => isUrl ? _absoluteUrl(baseUrl, e) : e)
            .toList(growable: false);
      }
      return const <String>[];
    }

    if (_looksLikeRegexRule(resolvedRule)) {
      final v = _parseRegexRuleOnText(root.outerHtml, resolvedRule);
      final values = _splitPossibleListValues(v);
      if (values.isNotEmpty) {
        return values
            .map((e) => isUrl ? _absoluteUrl(baseUrl, e) : e)
            .toList(growable: false);
      }
      return const <String>[];
    }

    final parsed = _LegadoTextRule.parse(
      resolvedRule,
      isExtractor: _isExtractorToken,
    );
    final targets = parsed.selectors.isEmpty
        ? <Element>[root]
        : _selectAllBySelectors(root, parsed.selectors);
    if (targets.isEmpty) return const <String>[];

    final out = <String>[];
    for (final el in targets) {
      var v = _extractWithFallbacks(
        el,
        parsed.extractors,
        baseUrl: baseUrl,
      );
      v = _applyInlineReplacements(v, parsed.replacements).trim();
      if (v.isEmpty) continue;
      for (final item in _splitPossibleListValues(v)) {
        final resolved = isUrl ? _absoluteUrl(baseUrl, item) : item;
        if (resolved.trim().isEmpty) continue;
        out.add(resolved);
      }
    }
    if (out.isEmpty) return const <String>[];

    final seen = <String>{};
    final dedup = <String>[];
    for (final value in out) {
      final key = value.trim();
      if (key.isEmpty || seen.contains(key)) continue;
      seen.add(key);
      dedup.add(key);
    }
    return dedup;
  }

  List<String> _parseStringListFromJsonSingle(
    dynamic json,
    String rule,
    String baseUrl,
    bool isUrl,
  ) {
    final extracted = _extractPutRules(rule);
    final one = extracted.cleanedRule.trim();
    if (one.isEmpty) return const <String>[];

    _applyPutRules(
      extracted.putMap,
      node: json,
      baseUrl: baseUrl,
    );

    var resolvedRule = _replaceGetTokens(one);
    resolvedRule = _applyTemplateJsTokens(
      resolvedRule,
      baseUrl: baseUrl,
    );

    if (_isLiteralRuleCandidate(one)) {
      final values = _splitPossibleListValues(resolvedRule);
      if (values.isEmpty) return const <String>[];
      return values
          .map((e) => isUrl ? _absoluteUrl(baseUrl, e) : e)
          .toList(growable: false);
    }

    if (_looksLikeJsonPath(resolvedRule)) {
      final split = _splitExprAndReplacements(
        resolvedRule,
      );
      var expr = split.expr.trim();
      if (expr.startsWith('@Json:')) {
        expr = expr.substring('@Json:'.length).trim();
      }
      if (expr.isEmpty) return const <String>[];
      try {
        final matches = JsonPath(expr).read(json).toList(growable: false);
        if (matches.isEmpty) return const <String>[];
        final out = <String>[];
        for (final m in matches) {
          final v = m.value;
          if (v is List) {
            for (final item in v) {
              if (item == null) continue;
              final s = _applyInlineReplacements(
                item.toString(),
                split.replacements,
              ).trim();
              if (s.isEmpty) continue;
              for (final part in _splitPossibleListValues(s)) {
                out.add(isUrl ? _absoluteUrl(baseUrl, part) : part);
              }
            }
          } else if (v != null) {
            final s = _applyInlineReplacements(
              v.toString(),
              split.replacements,
            ).trim();
            if (s.isEmpty) continue;
            for (final part in _splitPossibleListValues(s)) {
              out.add(isUrl ? _absoluteUrl(baseUrl, part) : part);
            }
          }
        }
        return out;
      } catch (_) {
        return const <String>[];
      }
    }

    final v = _parseValueOnNode(
      json,
      resolvedRule,
      baseUrl,
    );
    final values = _splitPossibleListValues(v);
    if (values.isEmpty) return const <String>[];
    return values
        .map((e) => isUrl ? _absoluteUrl(baseUrl, e) : e)
        .toList(growable: false);
  }

  List<String> _parseStringListFromHtml({
    required Element root,
    required String rule,
    required String baseUrl,
    required bool isUrl,
  }) {
    final raw = rule.trim();
    if (raw.isEmpty) return const <String>[];

    final split = _splitRuleByTopLevelOperator(raw, const ['&&', '||', '%%']);
    if (split.parts.isEmpty) return const <String>[];

    final results = <List<String>>[];
    for (final candidate in split.parts) {
      final out =
          _parseStringListFromHtmlSingle(root, candidate, baseUrl, isUrl);
      if (out.isNotEmpty) {
        results.add(out);
        if (split.operator == '||') break;
      }
    }
    return _mergeRuleListResults(results, split.operator);
  }

  List<String> _parseStringListFromJson({
    required dynamic json,
    required String rule,
    required String baseUrl,
    required bool isUrl,
  }) {
    final raw = rule.trim();
    if (raw.isEmpty) return const <String>[];

    final split = _splitRuleByTopLevelOperator(raw, const ['&&', '||', '%%']);
    if (split.parts.isEmpty) return const <String>[];

    final results = <List<String>>[];
    for (final candidate in split.parts) {
      final out =
          _parseStringListFromJsonSingle(json, candidate, baseUrl, isUrl);
      if (out.isNotEmpty) {
        results.add(out);
        if (split.operator == '||') break;
      }
    }
    return _mergeRuleListResults(results, split.operator);
  }

  Dio _selectDio({bool? enabledCookieJar}) {
    final enabled = enabledCookieJar ?? true;
    return enabled ? _dioCookie : _dioPlain;
  }

  static Future<void> saveCookiesForUrl(
    String url,
    List<Cookie> cookies,
  ) async {
    final uri = Uri.parse(url);
    await CookieStore.saveFromResponse(uri, cookies);
  }

  static Future<List<Cookie>> loadCookiesForUrl(String url) async {
    final uri = Uri.parse(url);
    return CookieStore.loadForRequest(uri);
  }

  @visibleForTesting
  static Dio debugDioForTest({bool enabledCookieJar = false}) {
    return enabledCookieJar ? _dioCookie : _dioPlain;
  }

  @visibleForTesting
  static void debugResetConcurrentRateLimiterForTest() {
    _concurrentRecordMap.clear();
  }

  _ConcurrentRateSpec? _parseConcurrentRateSpec(String? concurrentRateRaw) {
    final raw = (concurrentRateRaw ?? '').trim();
    if (raw.isEmpty || raw == '0') return null;

    final slashIndex = raw.indexOf('/');
    if (slashIndex <= 0) {
      final intervalMs = int.tryParse(raw);
      if (intervalMs == null || intervalMs <= 0) return null;
      return _ConcurrentRateSpec.interval(raw: raw, intervalMs: intervalMs);
    }

    final countText = raw.substring(0, slashIndex).trim();
    final windowText = raw.substring(slashIndex + 1).trim();
    final count = int.tryParse(countText);
    final windowMs = int.tryParse(windowText);
    if (count == null || count <= 0 || windowMs == null || windowMs <= 0) {
      return null;
    }
    return _ConcurrentRateSpec.window(
      raw: raw,
      maxCount: count,
      windowMs: windowMs,
    );
  }

  _ConcurrentAcquireStep _tryAcquireConcurrentRate({
    required String sourceKey,
    required _ConcurrentRateSpec spec,
  }) {
    final key = sourceKey.trim();
    if (key.isEmpty) {
      return _ConcurrentAcquireStep(
        record: null,
        waitMs: 0,
        decision: '${spec.modeLabel}（sourceKey 为空，跳过限制）',
      );
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    var record = _concurrentRecordMap[key];
    if (record == null) {
      record = _ConcurrentRecord(
        isWindowMode: spec.isWindowMode,
        timeMs: now,
        frequency: 1,
      );
      _concurrentRecordMap[key] = record;
      return _ConcurrentAcquireStep(
        record: record,
        waitMs: 0,
        decision: spec.modeLabel,
      );
    }

    if (!record.isWindowMode) {
      final intervalMs = spec.intervalMs;
      if (intervalMs == null || intervalMs <= 0) {
        return const _ConcurrentAcquireStep(
          record: null,
          waitMs: 0,
          decision: '并发率格式非法，跳过限制',
        );
      }
      if (record.frequency > 0) {
        return _ConcurrentAcquireStep(
          record: record,
          waitMs: intervalMs,
          decision: spec.modeLabel,
        );
      }
      final nextTime = record.timeMs + intervalMs;
      if (now >= nextTime) {
        record.timeMs = now;
        record.frequency = 1;
        return _ConcurrentAcquireStep(
          record: record,
          waitMs: 0,
          decision: spec.modeLabel,
        );
      }
      return _ConcurrentAcquireStep(
        record: record,
        waitMs: nextTime - now,
        decision: spec.modeLabel,
      );
    }

    final maxCount = spec.maxCount;
    final windowMs = spec.windowMs;
    if (maxCount == null ||
        maxCount <= 0 ||
        windowMs == null ||
        windowMs <= 0) {
      return const _ConcurrentAcquireStep(
        record: null,
        waitMs: 0,
        decision: '并发率格式非法，跳过限制',
      );
    }

    final nextTime = record.timeMs + windowMs;
    if (now >= nextTime) {
      record.timeMs = now;
      record.frequency = 1;
      return _ConcurrentAcquireStep(
        record: record,
        waitMs: 0,
        decision: spec.modeLabel,
      );
    }

    // 对标 legado：使用 `>`，允许窗口内先通过 maxCount+1 次后再等待。
    if (record.frequency > maxCount) {
      return _ConcurrentAcquireStep(
        record: record,
        waitMs: nextTime - now,
        decision: spec.modeLabel,
      );
    }

    record.frequency += 1;
    return _ConcurrentAcquireStep(
      record: record,
      waitMs: 0,
      decision: spec.modeLabel,
    );
  }

  Future<_ConcurrentAcquireResult> _acquireConcurrentRatePermit({
    required String? sourceKey,
    required String? concurrentRate,
  }) async {
    final spec = _parseConcurrentRateSpec(concurrentRate);
    if (spec == null) {
      return _ConcurrentAcquireResult(
        record: null,
        waitMs: 0,
        decision: '未启用并发率限制',
      );
    }

    var totalWaitMs = 0;
    while (true) {
      final step = _tryAcquireConcurrentRate(
        sourceKey: sourceKey ?? '',
        spec: spec,
      );
      if (step.waitMs <= 0) {
        return _ConcurrentAcquireResult(
          record: step.record,
          waitMs: totalWaitMs,
          decision: step.decision,
        );
      }
      totalWaitMs += step.waitMs;
      await Future<void>.delayed(Duration(milliseconds: step.waitMs));
    }
  }

  void _releaseConcurrentRatePermit(_ConcurrentRecord? record) {
    if (record == null || record.isWindowMode) return;
    if (record.frequency > 0) {
      record.frequency -= 1;
    }
  }

  Map<String, String> _buildEffectiveRequestHeaders(
    String url, {
    required Map<String, String> customHeaders,
  }) {
    final headers = <String, String>{};

    // 先放入通用头，再用书源自定义 header 覆盖同名 key
    headers.addAll(_defaultHeaders);
    // 再保险：无论 header 来自何处，最终写入 Dio 前都做一次 key 过滤，
    // 避免出现 `{"User-Agent"` 这类非法 key 直接触发 dart:io FormatException。
    customHeaders.forEach((k, v) {
      final key = k.trim();
      if (key.isEmpty) return;
      if (!_httpHeaderTokenRegex.hasMatch(key)) return;
      headers[key] = v;
    });

    // 自动补齐 Referer/Origin（对标 legado 常见用法）
    // - 防盗链/反爬站点常见会校验 Referer / Origin
    // - 若书源里显式指定了 Referer/Origin，则不覆盖
    Uri? uri;
    try {
      uri = Uri.parse(url);
    } catch (_) {
      uri = null;
    }
    if (uri != null && uri.scheme.isNotEmpty && uri.host.isNotEmpty) {
      final isDefaultPort = (uri.scheme == 'http' && uri.port == 80) ||
          (uri.scheme == 'https' && uri.port == 443);
      final origin = isDefaultPort || !uri.hasPort
          ? '${uri.scheme}://${uri.host}'
          : '${uri.scheme}://${uri.host}:${uri.port}';

      bool hasKey(String key) {
        final lower = key.toLowerCase();
        return headers.keys.any((k) => k.toLowerCase() == lower);
      }

      if (!hasKey('Origin')) {
        headers['Origin'] = origin;
      }
      if (!hasKey('Referer')) {
        headers['Referer'] = '$origin/';
      }
    }

    return headers;
  }

  void _applyPreferredOriginHeaders(
    Map<String, String> headers,
    String? originText,
  ) {
    final raw = (originText ?? '').trim();
    if (raw.isEmpty) return;
    Uri? uri;
    try {
      uri = Uri.parse(raw);
    } catch (_) {
      uri = null;
    }
    if (uri == null || uri.scheme.isEmpty || uri.host.isEmpty) return;

    final isDefaultPort = (uri.scheme == 'http' && uri.port == 80) ||
        (uri.scheme == 'https' && uri.port == 443);
    final origin = isDefaultPort || !uri.hasPort
        ? '${uri.scheme}://${uri.host}'
        : '${uri.scheme}://${uri.host}:${uri.port}';

    bool hasKey(String key) {
      final lower = key.toLowerCase();
      return headers.keys.any((k) => k.toLowerCase() == lower);
    }

    // 对标 legado：UrlOption.origin 主要用于补齐防盗链站点的 Origin/Referer
    if (!hasKey('Origin')) {
      headers['Origin'] = origin;
    }
    if (!hasKey('Referer')) {
      headers['Referer'] = '$origin/';
    }
  }

  String _formatRequestHeadersForLog(Map<String, String> headers) {
    if (headers.isEmpty) return '—';

    String redactIfSensitive(String key, String value) {
      final k = key.toLowerCase();
      if (k == 'cookie' || k == 'authorization') {
        // 调试需要“看得到差异”，但也避免整段泄露：只展示头尾片段。
        final len = value.length;
        if (len <= 160) return value;
        final head = value.substring(0, 120);
        final tail = value.substring(len - 40);
        return '$head…$tail (len=$len)';
      }
      if (value.length <= 220) return value;
      return '${value.substring(0, 220)}…';
    }

    const preferredOrder = <String>[
      'User-Agent',
      'Accept',
      'Accept-Language',
      'Referer',
      'Origin',
      'Cookie',
    ];

    final entries = headers.entries.toList(growable: false);

    String? getByName(String name) {
      final lower = name.toLowerCase();
      for (final e in entries) {
        if (e.key.toLowerCase() == lower) {
          return '${e.key}: ${redactIfSensitive(e.key, e.value)}';
        }
      }
      return null;
    }

    final lines = <String>[];
    final takenLower = <String>{};

    for (final k in preferredOrder) {
      final line = getByName(k);
      if (line != null) {
        lines.add(line);
        takenLower.add(k.toLowerCase());
      }
    }

    final rest = entries
        .where((e) => !takenLower.contains(e.key.toLowerCase()))
        .toList(growable: false)
      ..sort((a, b) => a.key.toLowerCase().compareTo(b.key.toLowerCase()));

    for (final e in rest) {
      lines.add('${e.key}: ${redactIfSensitive(e.key, e.value)}');
    }

    const maxLines = 18;
    if (lines.length > maxLines) {
      final head = lines.take(maxLines).toList(growable: false);
      head.add('…（${lines.length - maxLines} 行已省略）');
      return head.join('\n');
    }
    return lines.join('\n');
  }

  static final RegExp _httpHeaderTokenRegex =
      RegExp(r"^[!#$%&'*+\-.^_`|~0-9A-Za-z]+$");

  _ParsedHeaders _parseRequestHeaders(
    String? header, {
    String? jsLib,
  }) {
    if (header == null) return _ParsedHeaders.empty;
    final raw = header.trim();
    if (raw.isEmpty) return _ParsedHeaders.empty;

    String? warning;

    String? evalHeaderJs(String js) {
      // 对标 legado：header 支持 @js: / <js>，执行后得到 JSON 文本。
      final out = _evalJsMaybeString(js: js, jsLib: jsLib).trim();
      return out.isEmpty ? null : out;
    }

    Map<String, String> mapToHeaders(Map decoded) {
      final m = <String, String>{};
      decoded.forEach((k, v) {
        final key = k.toString().trim();
        if (key.isEmpty) return;
        if (v == null) return;
        if (_httpHeaderTokenRegex.hasMatch(key)) {
          m[key] = v.toString();
        } else {
          warning ??= '存在非法 header key（已忽略）: $key';
        }
      });
      return m;
    }

    String? normalizeMaybeDoubleEncoded(String text) {
      final t = text.trim();
      if (t.length >= 2 && t.startsWith('"') && t.endsWith('"')) {
        try {
          final decoded = jsonDecode(t);
          if (decoded is String) return decoded;
        } catch (_) {
          // ignore
        }
      }
      return null;
    }

    String? unescapeWeirdJsonObjectText(String text) {
      final t = text.trim();
      // 兼容少见情况：header 被“多转了一次字符串”，变成：
      // {\"User-Agent\":\"xxx\"}
      // 或 {\\\"User-Agent\\\":\\\"xxx\\\"}
      if (!(t.startsWith('{') && t.contains(r'\"'))) return null;
      var fixed = t;
      // 先把 \\ -> \（避免后续 \" 仍然带双斜杠）
      fixed = fixed.replaceAll(r'\\', '\\');
      // 再把 \" -> "
      fixed = fixed.replaceAll(r'\"', '"');
      return fixed == t ? null : fixed;
    }

    // 对标 legado：header 支持 @js: / <js> 语法，执行后得到 JSON
    String normalizedRaw = raw;
    if (raw.length >= 4 && raw.toLowerCase().startsWith('@js:')) {
      final js = raw.substring(4).trim();
      final out = js.isEmpty ? null : evalHeaderJs(js);
      if (out != null) {
        warning ??= 'header 使用 @js: 生成';
        normalizedRaw = out;
      } else {
        warning ??= 'header @js: 执行失败（将按原文本解析）';
      }
    } else if (raw.length >= 4 && raw.toLowerCase().startsWith('<js>')) {
      var js = raw.substring(4);
      final lastTag = js.lastIndexOf('<');
      if (lastTag > 0) js = js.substring(0, lastTag);
      js = js.trim();
      final out = js.isEmpty ? null : evalHeaderJs(js);
      if (out != null) {
        warning ??= 'header 使用 <js> 生成';
        normalizedRaw = out;
      } else {
        warning ??= 'header <js> 执行失败（将按原文本解析）';
      }
    }

    // Legado 的 header 常见格式是 JSON 字符串：
    // {"User-Agent":"xxx","Referer":"xxx"}
    final doubleDecoded = normalizeMaybeDoubleEncoded(normalizedRaw);
    normalizedRaw = doubleDecoded ?? normalizedRaw;
    if (normalizedRaw.startsWith('{') && normalizedRaw.endsWith('}')) {
      try {
        final decoded = jsonDecode(normalizedRaw);
        if (decoded is Map) {
          return _ParsedHeaders(
            headers: mapToHeaders(decoded),
            warning: warning,
          );
        }
      } catch (_) {
        // fallthrough: try other formats below
      }

      // 兼容部分“二次转义”的 JSON 文本（常见于导入/粘贴路径）
      final fixed = unescapeWeirdJsonObjectText(normalizedRaw);
      if (fixed != null) {
        try {
          final decoded = jsonDecode(fixed);
          if (decoded is Map) {
            warning ??= 'header 似乎被二次转义，已自动修复解析';
            return _ParsedHeaders(
              headers: mapToHeaders(decoded),
              warning: warning,
            );
          }
        } catch (_) {
          warning ??= 'header 看起来像 JSON，但解析失败（将尝试其它格式）';
        }
      } else {
        warning ??= 'header 看起来像 JSON，但解析失败（将尝试其它格式）';
      }

      // 一些导入/编辑路径可能把 Map 变成 Dart 的 toString 形式：
      // {User-Agent: xxx, Referer: yyy}
      // 这种不是 JSON，但我们也尽量解析，避免直接崩溃。
      final inner = normalizedRaw.substring(1, normalizedRaw.length - 1).trim();
      if (inner.isNotEmpty && !inner.contains('"')) {
        final m = <String, String>{};
        for (final part in inner.split(',')) {
          final p = part.trim();
          if (p.isEmpty) continue;
          final idx = p.indexOf(':');
          if (idx <= 0) continue;
          final key = p.substring(0, idx).trim();
          final value = p.substring(idx + 1).trim();
          if (key.isEmpty) continue;
          if (!_httpHeaderTokenRegex.hasMatch(key)) continue;
          m[key] = value;
        }
        if (m.isNotEmpty) {
          return _ParsedHeaders(headers: m, warning: warning);
        }
      }
    }

    // 兼容编辑器里的“每行 key:value”格式
    final headers = <String, String>{};
    for (final line in normalizedRaw.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      final idx = trimmed.indexOf(':');
      if (idx <= 0) continue;
      final key = trimmed.substring(0, idx).trim();
      final value = trimmed.substring(idx + 1).trim();
      if (key.isEmpty) continue;
      if (!_httpHeaderTokenRegex.hasMatch(key)) {
        warning ??= '存在非法 header key（已忽略）: $key';
        continue;
      }
      headers[key] = value;
    }
    return _ParsedHeaders(headers: headers, warning: warning);
  }

  int _findLegadoUrlOptionSplitIndex(String source) {
    if (source.trim().isEmpty) return -1;

    String? quote;
    var parenDepth = 0;
    var bracketDepth = 0;
    var braceDepth = 0;

    for (var i = 0; i < source.length; i++) {
      final ch = source[i];

      if (quote != null) {
        if (ch == '\\' && i + 1 < source.length) {
          i++;
          continue;
        }
        if (ch == quote) quote = null;
        continue;
      }

      if (ch == '\\' && i + 1 < source.length) {
        i++;
        continue;
      }

      if (ch == '"' || ch == "'") {
        quote = ch;
        continue;
      }

      if (ch == '(') {
        parenDepth++;
        continue;
      }
      if (ch == ')') {
        if (parenDepth > 0) parenDepth--;
        continue;
      }
      if (ch == '[') {
        bracketDepth++;
        continue;
      }
      if (ch == ']') {
        if (bracketDepth > 0) bracketDepth--;
        continue;
      }
      if (ch == '{') {
        braceDepth++;
        continue;
      }
      if (ch == '}') {
        if (braceDepth > 0) braceDepth--;
        continue;
      }

      final atTopLevel =
          parenDepth == 0 && bracketDepth == 0 && braceDepth == 0;
      if (!atTopLevel || ch != ',') continue;

      var j = i + 1;
      while (j < source.length && source[j].trim().isEmpty) {
        j++;
      }
      if (j >= source.length || source[j] != '{') continue;

      final closeBrace = _findBalancedBraceEnd(source, j);
      if (closeBrace <= j) continue;

      final tail = source.substring(closeBrace + 1).trim();
      if (tail.isEmpty) {
        return i;
      }
    }

    return -1;
  }

  _LegadoUrlParsed _parseLegadoStyleUrl(String rawUrl) {
    final trimmed = rawUrl.trim();
    if (trimmed.isEmpty) return _LegadoUrlParsed(url: '', option: null);

    // Legado 常见：url,{jsonOption} 或 url, {jsonOption}
    // - 与 legado 的“逗号 + 可选空白 + JSON”分割语义保持一致。
    final idx = _findLegadoUrlOptionSplitIndex(trimmed);
    if (idx <= 0) return _LegadoUrlParsed(url: trimmed, option: null);

    final urlPart = trimmed.substring(0, idx).trim();
    final optPart = trimmed.substring(idx + 1).trim(); // starts with '{'
    if (!optPart.startsWith('{') || !optPart.endsWith('}')) {
      return _LegadoUrlParsed(url: trimmed, option: null);
    }

    try {
      final decoded = jsonDecode(optPart);
      if (decoded is! Map) {
        return _LegadoUrlParsed(url: trimmed, option: null);
      }
      final map = decoded.map((k, v) => MapEntry(k.toString(), v));
      return _LegadoUrlParsed(
        url: urlPart.isEmpty ? trimmed : urlPart,
        option: _LegadoUrlOption.fromJson(map),
      );
    } catch (_) {
      return _LegadoUrlParsed(url: trimmed, option: null);
    }
  }

  _UrlJsPatchResult? _applyLegadoUrlOptionJs({
    required String js,
    required String url,
    required Map<String, String> headerMap,
  }) {
    // 对标 legado 的 url 参数 js：
    // - java.url 可读写
    // - java.headerMap.put(k,v) / putAll({}) 等
    // - 只用于“在请求前修改 url/header”
    final safeUrl = jsonEncode(url);
    final safeHeaders = jsonEncode(headerMap);
    final wrapped = '''
      (function(){
        var java = {};
        java.url = $safeUrl;
        java.headerMap = $safeHeaders;
        java.headerMap.put = function(k,v){ this[String(k)] = String(v); };
        java.headerMap.putAll = function(obj){
          if(!obj) return;
          for (var key in obj) { this[String(key)] = String(obj[key]); }
        };
        java.log = function(){ try { console.log.apply(console, arguments); } catch(e) {} };
        try {
          (function(){ $js })();
        } catch (e) {
          return JSON.stringify({ok:false, error: String(e && (e.stack||e.message||e)), url: java.url, headers: java.headerMap});
        }
        return JSON.stringify({ok:true, url: java.url, headers: java.headerMap});
      })()
    ''';

    try {
      final text = _jsRuntime.evaluate(wrapped).trim();
      if (text.isEmpty || text == 'null' || text == 'undefined') {
        return _applyLegadoUrlOptionJsFallback(
          js: js,
          url: url,
          headerMap: headerMap,
        );
      }
      final decoded = jsonDecode(text);
      if (decoded is! Map) {
        return _applyLegadoUrlOptionJsFallback(
          js: js,
          url: url,
          headerMap: headerMap,
        );
      }
      final ok = decoded['ok'] == true;
      final patchedUrl = decoded['url']?.toString() ?? url;
      final headersRaw = decoded['headers'];
      final patchedHeaders = <String, String>{};
      if (headersRaw is Map) {
        headersRaw.forEach((k, v) {
          if (k == null || v == null) return;
          patchedHeaders[k.toString()] = v.toString();
        });
      }
      return _UrlJsPatchResult(
        ok: ok,
        url: patchedUrl,
        headers: patchedHeaders.isEmpty ? headerMap : patchedHeaders,
        error: decoded['error']?.toString(),
      );
    } catch (e) {
      final fallback = _applyLegadoUrlOptionJsFallback(
        js: js,
        url: url,
        headerMap: headerMap,
      );
      if (fallback != null) return fallback;
      return _UrlJsPatchResult(
        ok: false,
        url: url,
        headers: headerMap,
        error: e.toString(),
      );
    }
  }

  _UrlJsPatchResult? _applyLegadoUrlOptionJsFallback({
    required String js,
    required String url,
    required Map<String, String> headerMap,
  }) {
    final statements =
        _splitRuleByTopLevelOperator(js, const [';']).parts.isEmpty
            ? <String>[js]
            : _splitRuleByTopLevelOperator(js, const [';']).parts;

    var patchedUrl = url;
    final patchedHeaders = <String, String>{}..addAll(headerMap);
    var changed = false;

    for (final raw in statements) {
      final statement = raw.trim();
      if (statement.isEmpty) continue;

      final lower = statement.toLowerCase();

      final appendMatch = RegExp(
        r'^java\.url\s*=\s*java\.url\s*\+\s*(.+)$',
        caseSensitive: false,
      ).firstMatch(statement);
      if (appendMatch != null) {
        final rhs = appendMatch.group(1)?.trim() ?? '';
        final suffix = _decodeSimpleJsStringLiteral(rhs) ?? '';
        if (suffix.isNotEmpty) {
          patchedUrl = '$patchedUrl$suffix';
          changed = true;
        }
        continue;
      }

      final setMatch = RegExp(
        r'^java\.url\s*=\s*(.+)$',
        caseSensitive: false,
      ).firstMatch(statement);
      if (setMatch != null) {
        final rhs = setMatch.group(1)?.trim() ?? '';
        if (rhs.toLowerCase() != 'java.url') {
          final absolute = _decodeSimpleJsStringLiteral(rhs);
          if (absolute != null) {
            patchedUrl = absolute;
            changed = true;
          }
        }
        continue;
      }

      if (lower.startsWith('java.headermap.putall')) {
        final m = RegExp(
          r'^java\.headerMap\.putAll\s*\((.*)\)$',
          caseSensitive: false,
          dotAll: true,
        ).firstMatch(statement);
        final args = m?.group(1)?.trim() ?? '';
        if (args.isEmpty) continue;
        final map = <String, String>{};
        _mergePutMapFromText(args, map);
        if (map.isNotEmpty) {
          patchedHeaders.addAll(map);
          changed = true;
        }
        continue;
      }

      if (lower.startsWith('java.headermap.put')) {
        final m = RegExp(
          r'^java\.headerMap\.put\s*\((.*)\)$',
          caseSensitive: false,
          dotAll: true,
        ).firstMatch(statement);
        final args = m?.group(1)?.trim() ?? '';
        if (args.isEmpty) continue;
        final pairs = _splitByTopLevelComma(args);
        if (pairs.length < 2) continue;

        final key = _decodeSimpleJsStringLiteral(pairs[0].trim()) ??
            _stripPairedQuotes(pairs[0].trim());
        final value = _decodeSimpleJsStringLiteral(pairs[1].trim()) ??
            _stripPairedQuotes(pairs[1].trim());
        if (key.isEmpty) continue;
        patchedHeaders[key] = value;
        changed = true;
      }
    }

    if (!changed) return null;
    return _UrlJsPatchResult(
      ok: true,
      url: patchedUrl,
      headers: patchedHeaders,
      error: 'urlOption.js 使用回退解析',
    );
  }

  String _normalizeCharset(String raw) {
    final c = raw.trim().toLowerCase();
    if (c.isEmpty) return '';
    if (c == 'utf8') return 'utf-8';
    if (c == 'utf_8') return 'utf-8';
    if (c == 'gb2312' || c == 'gbk' || c == 'gb18030') return 'gbk';
    return c;
  }

  bool _containsPercentTriplet(String text) {
    if (text.length < 3) return false;
    for (var i = 0; i <= text.length - 3; i++) {
      if (text.codeUnitAt(i) != 0x25) continue; // '%'
      final a = text.codeUnitAt(i + 1);
      final b = text.codeUnitAt(i + 2);
      final aHex =
          (a >= 48 && a <= 57) || (a >= 65 && a <= 70) || (a >= 97 && a <= 102);
      final bHex =
          (b >= 48 && b <= 57) || (b >= 65 && b <= 70) || (b >= 97 && b <= 102);
      if (aHex && bHex) return true;
    }
    return false;
  }

  String _percentEncodeBytes(
    List<int> bytes, {
    required bool spaceAsPlus,
  }) {
    const hex = '0123456789ABCDEF';
    final out = StringBuffer();

    for (final b in bytes) {
      final byte = b & 0xFF;
      final isAlphaNum = (byte >= 0x30 && byte <= 0x39) ||
          (byte >= 0x41 && byte <= 0x5A) ||
          (byte >= 0x61 && byte <= 0x7A);
      final isUnreserved = isAlphaNum ||
          byte == 0x2D || // -
          byte == 0x5F || // _
          byte == 0x2E || // .
          byte == 0x7E; // ~
      if (isUnreserved) {
        out.writeCharCode(byte);
        continue;
      }
      if (spaceAsPlus && byte == 0x20) {
        out.write('+');
        continue;
      }
      out.write('%');
      out.write(hex[(byte >> 4) & 0x0F]);
      out.write(hex[byte & 0x0F]);
    }

    return out.toString();
  }

  String _decodeMaybePercentEncoded(
    String token, {
    required bool formStyle,
  }) {
    if (token.isEmpty) return token;
    final hasEncoded = _containsPercentTriplet(token);
    final hasFormPlus = formStyle && token.contains('+');
    if (!hasEncoded && !hasFormPlus) return token;

    var input = token;
    if (formStyle && input.contains('+')) {
      input = input.replaceAll('+', '%20');
    }
    try {
      return Uri.decodeComponent(input);
    } catch (_) {
      return token;
    }
  }

  String _legacyEscape(String source) {
    if (source.isEmpty) return source;
    final out = StringBuffer();
    for (final code in source.codeUnits) {
      final isDigit = code >= 48 && code <= 57;
      final isUpper = code >= 65 && code <= 90;
      final isLower = code >= 97 && code <= 122;
      if (isDigit || isUpper || isLower) {
        out.writeCharCode(code);
        continue;
      }

      if (code < 16) {
        out.write('%0${code.toRadixString(16)}');
      } else if (code < 256) {
        out.write('%${code.toRadixString(16)}');
      } else {
        out.write('%u${code.toRadixString(16)}');
      }
    }
    return out.toString();
  }

  String _encodeParamToken(
    String token, {
    required String normalizedCharset,
    required bool checkEncoded,
    required bool isQuery,
  }) {
    final text = token;
    if (text.isEmpty) return text;

    if (checkEncoded) {
      final already =
          _containsPercentTriplet(text) || (!isQuery && text.contains('+'));
      if (already) return text;
    }

    var source = text;
    if (!checkEncoded) {
      source = _decodeMaybePercentEncoded(text, formStyle: !isQuery);
    }

    if (normalizedCharset == 'escape') {
      return _legacyEscape(source);
    }

    final bytes =
        normalizedCharset == 'gbk' ? gbk.encode(source) : utf8.encode(source);
    return _percentEncodeBytes(bytes, spaceAsPlus: !isQuery);
  }

  String _encodeParamsText(
    String params,
    String? optionCharset, {
    required bool isQuery,
  }) {
    final text = params.trim();
    if (text.isEmpty) return '';

    final normalizedCharset = _normalizeCharset(optionCharset ?? '');
    final checkEncoded = normalizedCharset.isEmpty;

    final out = <String>[];
    for (final part in text.split('&')) {
      if (part.isEmpty) {
        out.add('');
        continue;
      }
      final idx = part.indexOf('=');
      if (idx < 0) {
        out.add(
          _encodeParamToken(
            part,
            normalizedCharset: normalizedCharset,
            checkEncoded: checkEncoded,
            isQuery: isQuery,
          ),
        );
        continue;
      }

      final key = part.substring(0, idx);
      final value = part.substring(idx + 1);
      final encodedKey = _encodeParamToken(
        key,
        normalizedCharset: normalizedCharset,
        checkEncoded: checkEncoded,
        isQuery: isQuery,
      );
      final encodedValue = _encodeParamToken(
        value,
        normalizedCharset: normalizedCharset,
        checkEncoded: checkEncoded,
        isQuery: isQuery,
      );
      out.add('$encodedKey=$encodedValue');
    }

    return out.join('&');
  }

  String _encodeUrlQueryByCharset(String url, String? optionCharset) {
    if (url.trim().isEmpty) return url;
    final hashIndex = url.indexOf('#');
    final beforeFragment = hashIndex >= 0 ? url.substring(0, hashIndex) : url;
    final fragment = hashIndex >= 0 ? url.substring(hashIndex) : '';

    final queryIndex = beforeFragment.indexOf('?');
    if (queryIndex < 0) return url;
    if (queryIndex >= beforeFragment.length - 1) {
      return '$beforeFragment$fragment';
    }

    final base = beforeFragment.substring(0, queryIndex);
    final query = beforeFragment.substring(queryIndex + 1);
    final encodedQuery = _encodeParamsText(
      query,
      optionCharset,
      isQuery: true,
    );
    return '$base?$encodedQuery$fragment';
  }

  String? _getHeaderIgnoreCase(Map<String, String> headers, String key) {
    final lower = key.toLowerCase();
    for (final entry in headers.entries) {
      if (entry.key.toLowerCase() == lower) {
        return entry.value;
      }
    }
    return null;
  }

  bool _isBodyMethod(String method) {
    return method == 'POST' || method == 'PUT' || method == 'PATCH';
  }

  bool _looksLikeJsonText(String text) {
    final t = text.trimLeft();
    if (!(t.startsWith('{') || t.startsWith('['))) return false;
    return _tryDecodeJsonValue(t) != null;
  }

  bool _looksLikeXmlText(String text) {
    final t = text.trimLeft();
    return t.startsWith('<');
  }

  String _charsetLabelForContentType(String normalizedCharset) {
    if (normalizedCharset.isEmpty || normalizedCharset == 'escape') {
      return 'UTF-8';
    }
    if (normalizedCharset == 'gbk') return 'GBK';
    return normalizedCharset.toUpperCase();
  }

  ({
    String url,
    String method,
    String? body,
    int retry,
    String methodDecision,
    String retryDecision,
    String requestCharsetDecision,
    String bodyEncoding,
    String bodyDecision,
  }) _normalizeRequestPayload(
    String url,
    _LegadoUrlOption? option,
    Map<String, String> requestHeaders,
  ) {
    final methodRaw = (option?.method ?? '').trim();
    var method = methodRaw.toUpperCase();
    if (method.isEmpty) method = 'GET';

    final methodDecision = methodRaw.isEmpty
        ? '未配置 method，使用默认 GET'
        : '使用 urlOption.method=$method';

    final retry = option?.retry ?? 0;
    final normalizedRetry = retry < 0 ? 0 : retry;
    final retryDecision = retry < 0
        ? 'urlOption.retry=$retry（非法负值），已按 0 处理'
        : 'urlOption.retry=$normalizedRetry';

    final optionCharset = option?.charset;
    final normalizedOptionCharset = _normalizeCharset(optionCharset ?? '');

    final requestCharsetDecision = normalizedOptionCharset.isEmpty
        ? '未指定 charset，URL/表单按原值（默认 UTF-8）处理'
        : normalizedOptionCharset == 'escape'
            ? '请求参数按 legacy escape 编码'
            : '请求参数按 $normalizedOptionCharset 编码';

    var finalUrl = _encodeUrlQueryByCharset(url, optionCharset);
    var body = option?.body;
    var bodyEncoding = 'none';
    var bodyDecision =
        _isBodyMethod(method) ? '请求体为空' : '$method 非 body 方法，不发送请求体';

    if (_isBodyMethod(method) && body != null && body.isNotEmpty) {
      final contentType = _getHeaderIgnoreCase(requestHeaders, 'Content-Type');
      final lowerContentType = (contentType ?? '').toLowerCase();
      final hasContentType = (contentType ?? '').trim().isNotEmpty;
      final formContentType = lowerContentType.contains(
        'application/x-www-form-urlencoded',
      );
      final structuredBody =
          _looksLikeJsonText(body) || _looksLikeXmlText(body);

      if (formContentType || (!hasContentType && !structuredBody)) {
        bodyEncoding = 'form';
        bodyDecision = formContentType
            ? 'Content-Type 指定 x-www-form-urlencoded，按表单编码 body'
            : '未指定 Content-Type 且 body 非 JSON/XML，按表单编码 body';
        body = _encodeParamsText(body, optionCharset, isQuery: false);
        if (!hasContentType) {
          final normalizedCharset = _normalizeCharset(optionCharset ?? '');
          requestHeaders['Content-Type'] =
              'application/x-www-form-urlencoded; charset=${_charsetLabelForContentType(normalizedCharset)}';
          bodyDecision = '$bodyDecision，并自动补齐 Content-Type';
        }
      } else if (_looksLikeJsonText(body)) {
        bodyEncoding = 'json';
        bodyDecision = hasContentType
            ? '识别为 JSON，保留原始 body（Content-Type 已给出）'
            : '识别为 JSON，保留原始 body';
      } else {
        bodyEncoding = 'raw';
        bodyDecision =
            hasContentType ? '保留原始 body（由 Content-Type 指示）' : '保留原始 body';
      }
    }

    return (
      url: finalUrl,
      method: method,
      body: body,
      retry: normalizedRetry,
      methodDecision: methodDecision,
      retryDecision: retryDecision,
      requestCharsetDecision: requestCharsetDecision,
      bodyEncoding: bodyEncoding,
      bodyDecision: bodyDecision,
    );
  }

  bool _isRetryableRequestError(Object error) {
    if (error is! DioException) return false;
    return error.type != DioExceptionType.cancel &&
        error.type != DioExceptionType.badResponse;
  }

  Future<({Response<List<int>> response, int retryCount})>
      _requestBytesWithRetry({
    required Dio dio,
    required String url,
    required Options options,
    required String method,
    required String? body,
    required int retry,
  }) async {
    final maxAttempt = retry < 0 ? 0 : retry;
    Object? lastError;

    for (var attempt = 0; attempt <= maxAttempt; attempt++) {
      try {
        final response = await dio.request<List<int>>(
          url,
          data: _isBodyMethod(method) ? (body ?? '') : null,
          options: options,
        );
        return (response: response, retryCount: attempt);
      } catch (e) {
        lastError = e;
        final canRetry = attempt < maxAttempt && _isRetryableRequestError(e);
        if (!canRetry) {
          throw _RequestRetryFailure(error: e, retryCount: attempt);
        }
      }
    }

    throw _RequestRetryFailure(
      error: lastError ?? StateError('request failed without explicit error'),
      retryCount: maxAttempt,
    );
  }

  String? _tryParseCharsetFromContentType(String? contentType) {
    final ct = (contentType ?? '').trim();
    if (ct.isEmpty) return null;
    final m =
        RegExp(r'charset\s*=\s*([^;\s]+)', caseSensitive: false).firstMatch(ct);
    if (m == null) return null;
    final v = m.group(1);
    if (v == null) return null;
    return _normalizeCharset(v.replaceAll('"', '').replaceAll("'", ''));
  }

  String? _tryParseCharsetFromHtmlHead(Uint8List bytes) {
    // 用 latin1 作为“无损映射”，只为查 meta charset（不用于最终文本）
    final headLen = bytes.length < 4096 ? bytes.length : 4096;
    final head = latin1.decode(bytes.sublist(0, headLen), allowInvalid: true);
    final m1 = RegExp(r'''<meta[^>]+charset\s*=\s*['"]?\s*([^'"\s/>]+)''',
            caseSensitive: false)
        .firstMatch(head);
    final c1 = m1?.group(1);
    if (c1 != null && c1.trim().isNotEmpty) return _normalizeCharset(c1);

    final m2 = RegExp(
            r'''<meta[^>]+http-equiv\s*=\s*['"]content-type['"][^>]+content\s*=\s*['"][^'"]*charset\s*=\s*([^'"\s;]+)''',
            caseSensitive: false)
        .firstMatch(head);
    final c2 = m2?.group(1);
    if (c2 != null && c2.trim().isNotEmpty) return _normalizeCharset(c2);
    return null;
  }

  _DecodedText _decodeResponseBytes({
    required Uint8List bytes,
    required Map<String, String> responseHeaders,
    String? optionCharset,
  }) {
    final forced = optionCharset != null && optionCharset.trim().isNotEmpty
        ? _normalizeCharset(optionCharset)
        : '';
    final headerCharset = _tryParseCharsetFromContentType(
      responseHeaders['content-type'] ?? responseHeaders['Content-Type'],
    );
    final htmlCharset = _tryParseCharsetFromHtmlHead(bytes);

    final charsetSource = forced.isNotEmpty
        ? 'urlOption.charset'
        : (headerCharset?.isNotEmpty == true)
            ? '响应头 Content-Type'
            : (htmlCharset?.isNotEmpty == true)
                ? 'HTML meta'
                : '默认回退';

    final charset = (forced.isNotEmpty
            ? forced
            : (headerCharset?.isNotEmpty == true ? headerCharset! : ''))
        .trim();

    final effective = charset.isNotEmpty ? charset : (htmlCharset ?? 'utf-8');
    final normalized = _normalizeCharset(effective);
    final decisionPrefix =
        '来源=$charsetSource，option=${forced.isEmpty ? '-' : forced}，header=${headerCharset ?? '-'}，meta=${htmlCharset ?? '-'}，effective=${normalized.isEmpty ? 'utf-8' : normalized}';

    try {
      if (normalized == 'gbk') {
        return _DecodedText(
          text: gbk.decode(bytes, allowMalformed: true),
          charset: 'gbk',
          charsetSource: charsetSource,
          charsetDecision: '$decisionPrefix，decoder=gbk',
        );
      }
      if (normalized == 'utf-8') {
        return _DecodedText(
          text: utf8.decode(bytes, allowMalformed: true),
          charset: 'utf-8',
          charsetSource: charsetSource,
          charsetDecision: '$decisionPrefix，decoder=utf-8',
        );
      }
      // 其它编码先走 utf-8 容错；失败再回退 latin1
      return _DecodedText(
        text: utf8.decode(bytes, allowMalformed: true),
        charset: normalized,
        charsetSource: charsetSource,
        charsetDecision: '$decisionPrefix，decoder=utf-8(容错)',
      );
    } catch (_) {
      return _DecodedText(
        text: latin1.decode(bytes, allowInvalid: true),
        charset: normalized.isEmpty ? 'latin1' : normalized,
        charsetSource: charsetSource,
        charsetDecision: '$decisionPrefix，decoder=latin1(回退)',
      );
    }
  }

  /// 搜索书籍
  Future<List<SearchResult>> search(BookSource source, String keyword) async {
    _clearRuntimeVariables();
    final searchRule = source.ruleSearch;
    final searchUrlRule = source.searchUrl;
    if (searchRule == null || searchUrlRule == null || searchUrlRule.isEmpty) {
      return [];
    }

    try {
      // 构建搜索URL
      final searchUrl = _buildUrl(
        source.bookSourceUrl,
        searchUrlRule,
        {'key': keyword, 'searchKey': keyword},
        jsLib: source.jsLib,
      );

      // 发送请求
      final response = await _fetch(
        searchUrl,
        header: source.header,
        jsLib: source.jsLib,
        timeoutMs: source.respondTime,
        enabledCookieJar: source.enabledCookieJar,
        sourceKey: source.bookSourceUrl,
        concurrentRate: source.concurrentRate,
      );
      if (response == null) return [];

      final results = <SearchResult>[];

      // 获取书籍列表
      final bookListRule = searchRule.bookList ?? '';
      final trimmed = response.trimLeft();
      final jsonRoot = (trimmed.startsWith('{') || trimmed.startsWith('['))
          ? _tryDecodeJsonValue(response)
          : null;

      // JSONPath 模式（对标 legado：部分源直接返回 JSON）
      if (jsonRoot != null && _looksLikeJsonPath(bookListRule)) {
        final nodes = _selectJsonList(jsonRoot, bookListRule);
        for (final node in nodes) {
          final name = _parseValueOnNode(node, searchRule.name, searchUrl);
          final author = _parseValueOnNode(node, searchRule.author, searchUrl);
          final intro = _parseValueOnNode(node, searchRule.intro, searchUrl);
          final kind = _parseValueOnNode(node, searchRule.kind, searchUrl);
          final lastChapter =
              _parseValueOnNode(node, searchRule.lastChapter, searchUrl);
          final updateTime =
              _parseValueOnNode(node, searchRule.updateTime, searchUrl);
          final wordCount =
              _parseValueOnNode(node, searchRule.wordCount, searchUrl);

          var bookUrl = _parseValueOnNode(node, searchRule.bookUrl, searchUrl);
          if (bookUrl.isNotEmpty && !bookUrl.startsWith('http')) {
            bookUrl = _absoluteUrl(searchUrl, bookUrl);
          }

          var coverUrl =
              _parseValueOnNode(node, searchRule.coverUrl, searchUrl);
          if (coverUrl.isNotEmpty && !coverUrl.startsWith('http')) {
            coverUrl = _absoluteUrl(searchUrl, coverUrl);
          }

          final result = SearchResult(
            name: name,
            author: author,
            coverUrl: coverUrl,
            intro: intro,
            kind: kind,
            lastChapter: lastChapter,
            updateTime: updateTime,
            wordCount: wordCount,
            bookUrl: bookUrl,
            sourceUrl: source.bookSourceUrl,
            sourceName: source.bookSourceName,
          );

          if (result.name.isNotEmpty && result.bookUrl.isNotEmpty) {
            results.add(result);
          }
        }
      } else {
        // HTML 模式
        final document = html_parser.parse(response);
        final bookElements = _selectAllElementsByRule(document, bookListRule);

        for (final element in bookElements) {
          var bookUrl = _parseRule(element, searchRule.bookUrl, searchUrl);
          if (bookUrl.isNotEmpty && !bookUrl.startsWith('http')) {
            bookUrl = _absoluteUrl(searchUrl, bookUrl);
          }

          var coverUrl = _parseRule(element, searchRule.coverUrl, searchUrl);
          if (coverUrl.isNotEmpty && !coverUrl.startsWith('http')) {
            coverUrl = _absoluteUrl(searchUrl, coverUrl);
          }

          final result = SearchResult(
            name: _parseRule(element, searchRule.name, searchUrl),
            author: _parseRule(element, searchRule.author, searchUrl),
            coverUrl: coverUrl,
            intro: _parseRule(element, searchRule.intro, searchUrl),
            kind: _parseRule(element, searchRule.kind, searchUrl),
            lastChapter: _parseRule(element, searchRule.lastChapter, searchUrl),
            updateTime: _parseRule(element, searchRule.updateTime, searchUrl),
            wordCount: _parseRule(element, searchRule.wordCount, searchUrl),
            bookUrl: bookUrl,
            sourceUrl: source.bookSourceUrl,
            sourceName: source.bookSourceName,
          );

          if (result.name.isNotEmpty && result.bookUrl.isNotEmpty) {
            results.add(result);
          }
        }
      }

      return results;
    } catch (e) {
      debugPrint('搜索失败: $e');
      return [];
    }
  }

  /// 对标 Legado 的「书源调试」：按 key 触发不同链路，并以“日志流”方式输出调试信息。
  ///
  /// key 规则（与 legado Debug.startDebug 一致）：
  /// - 绝对 URL（http/https）: 详情页调试（详情→目录→正文）
  /// - 包含 :: : 发现页调试（访问 :: 后面的 url，取第一本书继续）
  /// - ++ 开头: 目录页调试（目录→正文）
  /// - -- 开头: 正文页调试（仅正文）
  /// - 其它: 搜索关键字调试（搜索→详情→目录→正文）
  Future<void> debugRun(
    BookSource source,
    String key, {
    required void Function(SourceDebugEvent event) onEvent,
  }) async {
    final started = DateTime.now();

    String formatTimePrefix() {
      final ms = DateTime.now().difference(started).inMilliseconds;
      final minutes = (ms ~/ 60000) % 60;
      final seconds = (ms ~/ 1000) % 60;
      final millis = ms % 1000;
      final mm = minutes.toString().padLeft(2, '0');
      final ss = seconds.toString().padLeft(2, '0');
      final sss = millis.toString().padLeft(3, '0');
      return '[$mm:$ss.$sss]';
    }

    void log(
      String msg, {
      int state = 1,
      bool showTime = true,
    }) {
      final text = showTime ? '${formatTimePrefix()} $msg' : msg;
      onEvent(SourceDebugEvent(state: state, message: text));
    }

    void rawHtml(int state, String html) {
      onEvent(SourceDebugEvent(state: state, message: html, isRaw: true));
    }

    void rawText(int state, String text) {
      onEvent(SourceDebugEvent(state: state, message: text, isRaw: true));
    }

    bool isAbsUrl(String input) {
      final t = input.trim();
      return t.startsWith('http://') || t.startsWith('https://');
    }

    Future<FetchDebugResult> fetchStage(
      String url, {
      required int rawState,
    }) async {
      final res = await _fetchDebug(
        url,
        header: source.header,
        jsLib: source.jsLib,
        timeoutMs: source.respondTime,
        enabledCookieJar: source.enabledCookieJar,
        sourceKey: source.bookSourceUrl,
        concurrentRate: source.concurrentRate,
      );
      if (res.headersWarning != null && res.headersWarning!.trim().isNotEmpty) {
        log('└请求头解析提示：${res.headersWarning}', state: 1, showTime: false);
      }
      final cookieJarEnabled = source.enabledCookieJar ?? true;
      log(
        '└请求头（CookieJar=${cookieJarEnabled ? '开' : '关'}）\n'
        '${_formatRequestHeadersForLog(res.requestHeaders)}',
        state: 1,
        showTime: false,
      );
      if (res.retryCount > 0) {
        log('└重试次数：${res.retryCount}', state: 1, showTime: false);
      }
      log(
        '└并发率：${res.concurrentDecision}；等待=${res.concurrentWaitMs}ms',
        state: 1,
        showTime: false,
      );
      log('└请求决策：${res.methodDecision}', state: 1, showTime: false);
      log(
        '└重试决策：${res.retryDecision}；实际重试=${res.retryCount}',
        state: 1,
        showTime: false,
      );
      log('└请求编码：${res.requestCharsetDecision}', state: 1, showTime: false);
      final bodyPolicy = res.bodyEncoding == 'none'
          ? res.bodyDecision
          : '${res.bodyDecision}（bodyEncoding=${res.bodyEncoding}）';
      log('└请求体决策：$bodyPolicy', state: 1, showTime: false);
      final requestContentType = _getHeaderIgnoreCase(
        res.requestHeaders,
        'Content-Type',
      );
      if (requestContentType != null && requestContentType.trim().isNotEmpty) {
        log('└Content-Type：$requestContentType', state: 1, showTime: false);
      }
      if (res.requestBodySnippet != null &&
          res.requestBodySnippet!.trim().isNotEmpty) {
        log(
          '└请求体（${res.method}）\n${res.requestBodySnippet}',
          state: 1,
          showTime: false,
        );
      } else {
        log(
          '└请求方法：${res.method}',
          state: 1,
          showTime: false,
        );
      }
      final status = res.statusCode;
      final statusText = status != null ? ' ($status)' : '';
      final isBadStatus = status != null && status >= 400;
      if (res.body != null) {
        log(
          '≡获取${isBadStatus ? '完成' : '成功'}:${res.finalUrl ?? res.requestUrl}'
          '$statusText ${res.elapsedMs}ms',
          state: isBadStatus ? -1 : 1,
        );
        if (res.responseCharset != null &&
            res.responseCharset!.trim().isNotEmpty) {
          log('└响应编码：${res.responseCharset}', state: 1, showTime: false);
        }
        if (res.responseCharsetDecision != null &&
            res.responseCharsetDecision!.trim().isNotEmpty) {
          log(
            '└响应解码决策：${res.responseCharsetDecision}',
            state: 1,
            showTime: false,
          );
        }
        rawHtml(rawState, res.body!);
        if (isBadStatus) {
          log('└HTTP 状态码异常：$status', state: -1, showTime: false);
          final headerHint = _importantResponseHeaders(res.responseHeaders);
          if (headerHint.isNotEmpty) {
            log('└响应头：$headerHint', state: -1, showTime: false);
          }
          if (status == 403) {
            log(
              '└提示：403 多为反爬/需要 Referer/Cookie。可在书源 header 里补 Referer/Origin/Cookie，或开启 enabledCookieJar。',
              state: -1,
              showTime: false,
            );
          }
        }
      } else {
        log(
          '≡请求失败:${res.requestUrl}$statusText ${res.elapsedMs}ms',
          state: -1,
        );
        if (res.error != null && res.error!.trim().isNotEmpty) {
          log('└${res.error}', state: -1, showTime: false);
        }
      }
      return res;
    }

    try {
      log('︾开始解析');

      final trimmed = key.trim();
      if (trimmed.isEmpty) {
        log('key 不能为空', state: -1);
        return;
      }

      if (isAbsUrl(trimmed)) {
        log('⇒开始访问详情页:$trimmed');
        final ok = await _debugInfoTocContent(
          source: source,
          bookUrl: trimmed,
          fetchStage: fetchStage,
          emitRaw: rawText,
          log: log,
        );
        if (!ok) return;
        log('︽解析完成', state: 1000);
        return;
      }

      if (trimmed.contains('::')) {
        final url = trimmed.substring(trimmed.indexOf('::') + 2).trim();
        log('⇒开始访问发现页:$url');
        final firstBookUrl = await _debugBookListThenPickFirst(
          source: source,
          keyOrUrl: url,
          mode: _DebugListMode.explore,
          exploreUrlOverride: url,
          fetchStage: fetchStage,
          log: log,
        );
        if (firstBookUrl == null) {
          log('︽未获取到书籍', state: -1);
          return;
        }
        final ok = await _debugInfoTocContent(
          source: source,
          bookUrl: firstBookUrl,
          fetchStage: fetchStage,
          emitRaw: rawText,
          log: log,
        );
        if (!ok) return;
        log('︽解析完成', state: 1000);
        return;
      }

      if (trimmed.startsWith('++')) {
        final url = trimmed.substring(2).trim();
        log('⇒开始访目录页:$url');
        final ok = await _debugTocThenContent(
          source: source,
          tocUrl: url,
          fetchStage: fetchStage,
          emitRaw: rawText,
          log: log,
        );
        if (!ok) return;
        log('︽解析完成', state: 1000);
        return;
      }

      if (trimmed.startsWith('--')) {
        final url = trimmed.substring(2).trim();
        log('⇒开始访正文页:$url');
        final ok = await _debugContentOnly(
          source: source,
          chapterUrl: url,
          fetchStage: fetchStage,
          emitRaw: rawText,
          log: log,
        );
        if (!ok) return;
        log('︽解析完成', state: 1000);
        return;
      }

      log('⇒开始搜索关键字:$trimmed');
      final firstBookUrl = await _debugBookListThenPickFirst(
        source: source,
        keyOrUrl: trimmed,
        mode: _DebugListMode.search,
        fetchStage: fetchStage,
        log: log,
      );
      if (firstBookUrl == null) {
        log('︽未获取到书籍', state: -1);
        return;
      }
      final ok = await _debugInfoTocContent(
        source: source,
        bookUrl: firstBookUrl,
        fetchStage: fetchStage,
        emitRaw: rawText,
        log: log,
      );
      if (!ok) return;
      log('︽解析完成', state: 1000);
    } catch (e, st) {
      log('调试异常: $e', state: -1);
      log(st.toString(), state: -1, showTime: false);
    }
  }

  Future<String?> _debugBookListThenPickFirst({
    required BookSource source,
    required String keyOrUrl,
    required _DebugListMode mode,
    String? exploreUrlOverride,
    required Future<FetchDebugResult> Function(String url,
            {required int rawState})
        fetchStage,
    required void Function(String msg, {int state, bool showTime}) log,
  }) async {
    final isSearch = mode == _DebugListMode.search;
    final bookListRule = isSearch ? source.ruleSearch : source.ruleExplore;
    final urlRule = isSearch
        ? source.searchUrl
        : ((exploreUrlOverride != null && exploreUrlOverride.trim().isNotEmpty)
            ? exploreUrlOverride.trim()
            : source.exploreUrl);

    log(isSearch ? '︾开始解析搜索页' : '︾开始解析发现页');

    if (bookListRule == null || urlRule == null || urlRule.trim().isEmpty) {
      log(isSearch ? '⇒搜索规则为空' : '⇒发现规则为空', state: -1);
      return null;
    }

    final requestUrl = isSearch
        ? _buildUrl(
            source.bookSourceUrl,
            urlRule,
            {'key': keyOrUrl, 'searchKey': keyOrUrl},
            jsLib: source.jsLib,
          )
        : _buildUrl(
            source.bookSourceUrl,
            urlRule,
            const {},
            jsLib: source.jsLib,
          );

    final fetch = await fetchStage(requestUrl, rawState: 10);
    final body = fetch.body;
    if (body == null) {
      log('︽列表页解析失败', state: -1);
      return null;
    }

    final listSelector = bookListRule.bookList ?? '';

    log('┌获取书籍列表');
    final results = <SearchResult>[];
    var loggedSample = false;

    final trimmed = body.trimLeft();
    final jsonRoot = (trimmed.startsWith('{') || trimmed.startsWith('['))
        ? _tryDecodeJsonValue(body)
        : null;

    if (jsonRoot != null && _looksLikeJsonPath(listSelector)) {
      final nodes = _selectJsonList(jsonRoot, listSelector);
      log('└列表大小:${nodes.length}');
      if (nodes.isEmpty) {
        log('≡列表为空，可能是详情页或规则不匹配');
      }

      for (var i = 0; i < nodes.length; i++) {
        final node = nodes[i];
        final name = _parseValueOnNode(node, bookListRule.name, requestUrl);
        final author = _parseValueOnNode(node, bookListRule.author, requestUrl);
        var coverUrl =
            _parseValueOnNode(node, bookListRule.coverUrl, requestUrl);
        if (coverUrl.isNotEmpty && !coverUrl.startsWith('http')) {
          coverUrl = _absoluteUrl(requestUrl, coverUrl);
        }
        final intro = _parseValueOnNode(node, bookListRule.intro, requestUrl);
        final lastChapter =
            _parseValueOnNode(node, bookListRule.lastChapter, requestUrl);
        var bookUrl = _parseValueOnNode(node, bookListRule.bookUrl, requestUrl);
        if (bookUrl.isNotEmpty && !bookUrl.startsWith('http')) {
          bookUrl = _absoluteUrl(requestUrl, bookUrl);
        }

        if (!loggedSample && name.isNotEmpty && bookUrl.isNotEmpty) {
          loggedSample = true;
          log('┌获取书名');
          log('└$name');
          log('┌获取作者');
          log('└$author');
          log('┌获取封面');
          log('└$coverUrl');
          log('┌获取简介');
          log('└${intro.isEmpty ? '' : intro}');
          log('┌获取最新章节');
          log('└$lastChapter');
          log('┌获取详情链接');
          log('└$bookUrl');
        }

        if (name.isEmpty || bookUrl.isEmpty) continue;
        results.add(
          SearchResult(
            name: name,
            author: author,
            coverUrl: coverUrl,
            intro: intro,
            lastChapter: lastChapter,
            bookUrl: bookUrl,
            sourceUrl: source.bookSourceUrl,
            sourceName: source.bookSourceName,
          ),
        );
      }
    } else {
      final document = html_parser.parse(body);
      final elements = _selectAllElementsByRule(document, listSelector);
      log('└列表大小:${elements.length}');

      if (elements.isEmpty) {
        // 对齐 legado：列表为空时可能是“详情页”，这里仅提示，不强行走详情解析（后续可按 bookUrlPattern 补齐）
        log('≡列表为空，可能是详情页或规则不匹配');
      }

      for (var i = 0; i < elements.length; i++) {
        final el = elements[i];
        final name = _parseRule(el, bookListRule.name, requestUrl);
        final author = _parseRule(el, bookListRule.author, requestUrl);
        var coverUrl = _parseRule(el, bookListRule.coverUrl, requestUrl);
        if (coverUrl.isNotEmpty && !coverUrl.startsWith('http')) {
          coverUrl = _absoluteUrl(requestUrl, coverUrl);
        }
        final intro = _parseRule(el, bookListRule.intro, requestUrl);
        final lastChapter =
            _parseRule(el, bookListRule.lastChapter, requestUrl);
        var bookUrl = _parseRule(el, bookListRule.bookUrl, requestUrl);
        if (bookUrl.isNotEmpty && !bookUrl.startsWith('http')) {
          bookUrl = _absoluteUrl(requestUrl, bookUrl);
        }

        // 对齐 legado：仅输出“一条有效样本”，避免 selector 命中广告/空节点导致样本全空而误导排查。
        if (!loggedSample && name.isNotEmpty && bookUrl.isNotEmpty) {
          loggedSample = true;
          log('┌获取书名');
          log('└$name');
          log('┌获取作者');
          log('└$author');
          log('┌获取封面');
          log('└$coverUrl');
          log('┌获取简介');
          log('└${intro.isEmpty ? '' : intro}');
          log('┌获取最新章节');
          log('└$lastChapter');
          log('┌获取详情链接');
          log('└$bookUrl');
        }

        if (name.isEmpty || bookUrl.isEmpty) continue;
        results.add(
          SearchResult(
            name: name,
            author: author,
            coverUrl: coverUrl,
            intro: intro,
            lastChapter: lastChapter,
            bookUrl: bookUrl,
            sourceUrl: source.bookSourceUrl,
            sourceName: source.bookSourceName,
          ),
        );
      }
    }

    log('◇书籍总数:${results.length}');
    return results.isNotEmpty ? results.first.bookUrl : null;
  }

  Future<bool> _debugInfoTocContent({
    required BookSource source,
    required String bookUrl,
    required Future<FetchDebugResult> Function(String url,
            {required int rawState})
        fetchStage,
    required void Function(int state, String payload) emitRaw,
    required void Function(String msg, {int state, bool showTime}) log,
  }) async {
    final tocUrl = await _debugBookInfo(
      source: source,
      bookUrl: bookUrl,
      fetchStage: fetchStage,
      log: log,
    );
    if (tocUrl == null || tocUrl.trim().isEmpty) {
      log('≡未获取到目录链接', state: -1);
      return false;
    }
    return _debugTocThenContent(
      source: source,
      tocUrl: tocUrl,
      fetchStage: fetchStage,
      emitRaw: emitRaw,
      log: log,
    );
  }

  Future<String?> _debugBookInfo({
    required BookSource source,
    required String bookUrl,
    required Future<FetchDebugResult> Function(String url,
            {required int rawState})
        fetchStage,
    required void Function(String msg, {int state, bool showTime}) log,
  }) async {
    log('︾开始解析详情页');

    final rule = source.ruleBookInfo;
    if (rule == null) {
      log('⇒详情规则为空', state: -1);
      return null;
    }

    final fullUrl = _absoluteUrl(source.bookSourceUrl, bookUrl);
    final fetch = await fetchStage(fullUrl, rawState: 20);
    final body = fetch.body;
    if (body == null) {
      log('︽详情页解析失败', state: -1);
      return null;
    }

    final trimmed = body.trimLeft();
    final jsonRoot = (trimmed.startsWith('{') || trimmed.startsWith('['))
        ? _tryDecodeJsonValue(body)
        : null;

    // JSON 模式：不支持 init
    if (jsonRoot != null) {
      String getField(String label, String? ruleStr) {
        log('┌$label');
        final value = _parseValueOnNode(jsonRoot, ruleStr, fullUrl);
        log('└$value');
        return value;
      }

      final name = getField('获取书名', rule.name);
      final author = getField('获取作者', rule.author);
      getField('获取分类', rule.kind);
      getField('获取字数', rule.wordCount);
      final lastChapter = getField('获取最新章节', rule.lastChapter);
      getField('获取简介', rule.intro);
      getField('获取封面', rule.coverUrl);
      var tocUrl = getField('获取目录链接', rule.tocUrl);
      if (tocUrl.trim().isEmpty) {
        log('≡目录链接为空，将使用详情页作为目录页', showTime: false);
        tocUrl = fullUrl;
      } else if (!tocUrl.startsWith('http')) {
        tocUrl = _absoluteUrl(fullUrl, tocUrl);
      }

      if (name.isEmpty &&
          author.isEmpty &&
          lastChapter.isEmpty &&
          tocUrl.isEmpty) {
        log('≡字段全为空，可能 ruleBookInfo 不匹配', state: -1);
      }

      log('︽详情页解析完成', showTime: false);
      log('', showTime: false);

      return tocUrl;
    }

    final document = html_parser.parse(body);
    Element? root = document.documentElement;
    if (root == null) {
      log('⇒页面无 documentElement', state: -1);
      return null;
    }

    if (rule.init != null && rule.init!.trim().isNotEmpty) {
      log('≡执行详情页初始化规则');
      final initEl = _selectFirstElementByRule(document, rule.init!.trim());
      if (initEl != null) {
        root = initEl;
      } else {
        log('└init 匹配失败（将继续用 documentElement）');
      }
    }

    String getField(String label, String? ruleStr) {
      log('┌$label');
      final value = _parseRule(root!, ruleStr, fullUrl);
      log('└$value');
      return value;
    }

    final name = getField('获取书名', rule.name);
    final author = getField('获取作者', rule.author);
    getField('获取分类', rule.kind);
    getField('获取字数', rule.wordCount);
    final lastChapter = getField('获取最新章节', rule.lastChapter);
    getField('获取简介', rule.intro);
    getField('获取封面', rule.coverUrl);
    var tocUrl = getField('获取目录链接', rule.tocUrl);
    if (tocUrl.trim().isEmpty) {
      // 对齐 legado 的容错：部分站点“详情页就是目录页”，tocUrl 规则为空/不匹配时允许直接用当前详情页继续。
      log('≡目录链接为空，将使用详情页作为目录页', showTime: false);
      tocUrl = fullUrl;
    } else if (!tocUrl.startsWith('http')) {
      tocUrl = _absoluteUrl(fullUrl, tocUrl);
    }

    if (name.isEmpty &&
        author.isEmpty &&
        lastChapter.isEmpty &&
        tocUrl.isEmpty) {
      log('≡字段全为空，可能 ruleBookInfo 不匹配', state: -1);
    }

    log('︽详情页解析完成', showTime: false);
    log('', showTime: false);

    return tocUrl;
  }

  Future<bool> _debugTocThenContent({
    required BookSource source,
    required String tocUrl,
    required Future<FetchDebugResult> Function(String url,
            {required int rawState})
        fetchStage,
    required void Function(int state, String payload) emitRaw,
    required void Function(String msg, {int state, bool showTime}) log,
  }) async {
    log('︾开始解析目录页');

    final tocRule = source.ruleToc;
    if (tocRule == null) {
      log('⇒目录规则为空', state: -1);
      return false;
    }

    final normalized = _normalizeListRule(tocRule.chapterList);
    final toc = <TocItem>[];

    final visitedUrlKeys = <String>{};
    var currentUrl = _absoluteUrl(source.bookSourceUrl, tocUrl);
    var page = 0;
    const maxPages = 12;
    final pendingNextUrls = <String>[];
    final queuedUrlKeys = <String>{};

    while (currentUrl.trim().isNotEmpty && page < maxPages) {
      if (!_markVisitedUrl(visitedUrlKeys, currentUrl)) break;
      queuedUrlKeys.remove(_normalizeUrlVisitKey(currentUrl));

      log('≡目录页请求:${page + 1}');
      final fetch = await fetchStage(currentUrl, rawState: 30);
      final body = fetch.body!;
      final stageBody = _applyStageResponseJs(
        responseText: body,
        jsRule: tocRule.preUpdateJs,
        currentUrl: currentUrl,
        jsLib: source.jsLib,
        stageLabel: 'preUpdateJs',
        onLog: (msg) => log('└$msg', showTime: false),
      );
      emitRaw(30, stageBody);

      final trimmed = stageBody.trimLeft();
      final jsonRoot = (trimmed.startsWith('{') || trimmed.startsWith('['))
          ? _tryDecodeJsonValue(stageBody)
          : null;

      List<String> nextCandidates = const <String>[];

      log('┌获取章节列表');
      if (jsonRoot != null && _looksLikeJsonPath(normalized.selector)) {
        final nodes = _selectJsonList(jsonRoot, normalized.selector);
        log('└列表大小:${nodes.length}');
        for (var i = 0; i < nodes.length; i++) {
          final node = nodes[i];
          final name = _parseValueOnNode(node, tocRule.chapterName, currentUrl);
          var url = _parseValueOnNode(node, tocRule.chapterUrl, currentUrl);
          if (url.isNotEmpty && !url.startsWith('http')) {
            url = _absoluteUrl(currentUrl, url);
          }
          if (toc.isEmpty && i == 0) {
            log('┌获取章节名');
            log('└$name');
            log('┌获取章节链接');
            log('└$url');
          }
          if (name.isEmpty || url.isEmpty) continue;
          toc.add(TocItem(index: toc.length, name: name, url: url));
        }
        if (tocRule.nextTocUrl != null &&
            tocRule.nextTocUrl!.trim().isNotEmpty) {
          nextCandidates = _parseStringListFromJson(
            json: jsonRoot,
            rule: tocRule.nextTocUrl!,
            baseUrl: currentUrl,
            isUrl: true,
          );
          if (nextCandidates.isNotEmpty) {
            log('┌获取目录下一页');
            log('└${nextCandidates.join('\n')}');
          }
        }
      } else {
        final document = html_parser.parse(body);
        final elements =
            _selectAllElementsByRule(document, normalized.selector);
        log('└列表大小:${elements.length}');
        for (var i = 0; i < elements.length; i++) {
          final el = elements[i];
          final name = _parseRule(el, tocRule.chapterName, currentUrl);
          var url = _parseRule(el, tocRule.chapterUrl, currentUrl);
          if (url.isNotEmpty && !url.startsWith('http')) {
            url = _absoluteUrl(currentUrl, url);
          }
          if (toc.isEmpty && i == 0) {
            log('┌获取章节名');
            log('└$name');
            log('┌获取章节链接');
            log('└$url');
          }
          if (name.isEmpty || url.isEmpty) continue;
          toc.add(TocItem(index: toc.length, name: name, url: url));
        }
        if (tocRule.nextTocUrl != null &&
            tocRule.nextTocUrl!.trim().isNotEmpty) {
          final root = document.documentElement;
          if (root != null) {
            nextCandidates = _parseStringListFromHtml(
              root: root,
              rule: tocRule.nextTocUrl!,
              baseUrl: currentUrl,
              isUrl: true,
            );
            if (nextCandidates.isNotEmpty) {
              log('┌获取目录下一页');
              log('└${nextCandidates.join('\n')}');
            }
          }
        }
      }

      if (nextCandidates.isNotEmpty) {
        final collect = _collectNextUrlCandidatesWithDebug(
          nextCandidates,
          currentUrl: currentUrl,
          visitedUrlKeys: visitedUrlKeys,
          queuedUrlKeys: queuedUrlKeys,
        );
        log('┌目录下一页候选决策');
        log('└${collect.debugLines.join('\n')}');

        for (final u in collect.urls) {
          final key = _normalizeUrlVisitKey(u);
          if (key.isEmpty || queuedUrlKeys.contains(key)) continue;
          queuedUrlKeys.add(key);
          pendingNextUrls.add(u);
        }
        if (collect.urls.isNotEmpty) {
          log('┌目录下一页入队结果');
          log('└${pendingNextUrls.join('\n')}');
        }
      }

      if (pendingNextUrls.isEmpty) {
        log('≡目录翻页结束：无可用下一页');
        break;
      }
      currentUrl = pendingNextUrls.removeAt(0);
      page++;
    }

    var out = toc;
    if (normalized.reverse) out = out.reversed.toList(growable: true);
    out = <TocItem>[
      for (var i = 0; i < out.length; i++)
        TocItem(index: i, name: out[i].name, url: out[i].url),
    ];
    out = _applyTocFormatJs(
      toc: out,
      formatJs: tocRule.formatJs,
      jsLib: source.jsLib,
    );
    log('◇章节总数:${out.length}');

    if (out.isEmpty) {
      log('≡没有正文章节', state: -1);
      return false;
    }

    log('︽目录页解析完成', showTime: false);
    log('', showTime: false);

    return _debugContentOnly(
      source: source,
      chapterUrl: out.first.url,
      nextChapterUrl: out.length > 1 ? out[1].url : null,
      fetchStage: fetchStage,
      emitRaw: emitRaw,
      log: log,
    );
  }

  Future<bool> _debugContentOnly({
    required BookSource source,
    required String chapterUrl,
    String? nextChapterUrl,
    required Future<FetchDebugResult> Function(String url,
            {required int rawState})
        fetchStage,
    required void Function(int state, String payload) emitRaw,
    required void Function(String msg, {int state, bool showTime}) log,
  }) async {
    log('︾开始解析正文页');

    final rule = source.ruleContent;
    if (rule == null) {
      log('⇒正文规则为空', state: -1);
      return false;
    }

    final visitedUrlKeys = <String>{};
    var currentUrl = _absoluteUrl(source.bookSourceUrl, chapterUrl);
    final nextChapterUrlKey = _buildNextChapterUrlKey(
      chapterEntryUrl: currentUrl,
      nextChapterUrl: nextChapterUrl,
    );
    var page = 0;
    const maxPages = 8;

    final parts = <String>[];
    var totalExtracted = 0;
    final pendingNextUrls = <String>[];
    final queuedUrlKeys = <String>{};

    while (currentUrl.trim().isNotEmpty && page < maxPages) {
      if (!_markVisitedUrl(visitedUrlKeys, currentUrl)) break;
      queuedUrlKeys.remove(_normalizeUrlVisitKey(currentUrl));

      log('≡正文页请求:${page + 1}');
      final fetch = await fetchStage(currentUrl, rawState: 40);
      final body = fetch.body!;
      final stageBody = _applyStageResponseJs(
        responseText: body,
        jsRule: rule.webJs,
        currentUrl: currentUrl,
        jsLib: source.jsLib,
        stageLabel: 'webJs',
        onLog: (msg) => log('└$msg', showTime: false),
      );
      emitRaw(40, stageBody);

      final trimmed = stageBody.trimLeft();
      final jsonRoot = (trimmed.startsWith('{') || trimmed.startsWith('['))
          ? _tryDecodeJsonValue(stageBody)
          : null;

      String extracted;
      List<String> nextCandidates = const <String>[];

      if (jsonRoot != null &&
          rule.content != null &&
          _looksLikeJsonPath(rule.content!)) {
        extracted = _parseValueOnNode(jsonRoot, rule.content, currentUrl);
        if (rule.nextContentUrl != null &&
            rule.nextContentUrl!.trim().isNotEmpty) {
          nextCandidates = _parseStringListFromJson(
            json: jsonRoot,
            rule: rule.nextContentUrl!,
            baseUrl: currentUrl,
            isUrl: true,
          );
          if (nextCandidates.isNotEmpty) {
            log('┌获取正文下一页');
            log('└${nextCandidates.join('\n')}');
          }
        }
      } else {
        final document = html_parser.parse(stageBody);
        final root = document.documentElement;
        if (root == null) {
          log('⇒页面无 documentElement', state: -1);
          return false;
        }

        if (rule.content == null || rule.content!.trim().isEmpty) {
          if (page == 0) log('⇒内容规则为空，默认获取整个网页');
          extracted = root.text;
        } else {
          extracted = _parseRule(root, rule.content, currentUrl);
        }

        if (rule.nextContentUrl != null &&
            rule.nextContentUrl!.trim().isNotEmpty) {
          nextCandidates = _parseStringListFromHtml(
            root: root,
            rule: rule.nextContentUrl!,
            baseUrl: currentUrl,
            isUrl: true,
          );
          if (nextCandidates.isNotEmpty) {
            log('┌获取正文下一页');
            log('└${nextCandidates.join('\n')}');
          }
        }
      }

      totalExtracted += extracted.length;

      var processed = extracted;
      if (rule.replaceRegex != null && rule.replaceRegex!.trim().isNotEmpty) {
        processed = _applyReplaceRegex(processed, rule.replaceRegex!);
      }
      final cleaned = _cleanContent(processed);
      if (cleaned.trim().isNotEmpty) parts.add(cleaned);

      if (nextCandidates.isNotEmpty) {
        final collect = _collectNextUrlCandidatesWithDebug(
          nextCandidates,
          currentUrl: currentUrl,
          visitedUrlKeys: visitedUrlKeys,
          queuedUrlKeys: queuedUrlKeys,
          blockedUrlKey: nextChapterUrlKey,
        );
        log('┌正文下一页候选决策');
        log('└${collect.debugLines.join('\n')}');

        if (collect.urls.isEmpty) {
          if (collect.hasBlockedCandidate) {
            log('≡命中下一章链接，停止正文翻页');
          }
        } else {
          for (final u in collect.urls) {
            final key = _normalizeUrlVisitKey(u);
            if (key.isEmpty || queuedUrlKeys.contains(key)) continue;
            queuedUrlKeys.add(key);
            pendingNextUrls.add(u);
          }
          log('┌正文下一页入队结果');
          log('└${pendingNextUrls.join('\n')}');
        }
      }

      if (pendingNextUrls.isEmpty) {
        log('≡正文翻页结束：无可用下一页');
        break;
      }
      currentUrl = pendingNextUrls.removeAt(0);
      page++;
    }

    final cleanedAll = parts.join('\n');
    emitRaw(41, cleanedAll);

    log('◇分页:${parts.length} 提取总长:$totalExtracted 清理后总长:${cleanedAll.length}');
    log('┌获取正文内容');
    final maxLog = 2000;
    final preview = cleanedAll.length <= maxLog
        ? cleanedAll
        : '${cleanedAll.substring(0, maxLog)}\n…（已截断，查看“正文结果”可看全文）';
    log('└\n$preview');

    if (cleanedAll.trim().isEmpty) {
      log('≡内容为空', state: -1);
      return false;
    }

    log('︽正文页解析完成');
    return true;
  }

  /// 搜索调试：返回「请求/解析」过程的关键诊断信息
  Future<SearchDebugResult> searchDebug(
      BookSource source, String keyword) async {
    final searchRule = source.ruleSearch;
    final searchUrlRule = source.searchUrl;
    if (searchRule == null || searchUrlRule == null || searchUrlRule.isEmpty) {
      return SearchDebugResult(
        fetch: FetchDebugResult.empty(),
        requestType: DebugRequestType.search,
        requestUrlRule: searchUrlRule,
        listRule: searchRule?.bookList,
        listCount: 0,
        results: const [],
        fieldSample: const {},
        error: 'searchUrl / ruleSearch 为空',
      );
    }

    final requestUrl = _buildUrl(
      source.bookSourceUrl,
      searchUrlRule,
      {'key': keyword, 'searchKey': keyword},
      jsLib: source.jsLib,
    );

    final fetch = await _fetchDebug(
      requestUrl,
      header: source.header,
      jsLib: source.jsLib,
      timeoutMs: source.respondTime,
      enabledCookieJar: source.enabledCookieJar,
      sourceKey: source.bookSourceUrl,
      concurrentRate: source.concurrentRate,
    );
    if (fetch.body == null) {
      return SearchDebugResult(
        fetch: fetch,
        requestType: DebugRequestType.search,
        requestUrlRule: searchUrlRule,
        listRule: searchRule.bookList,
        listCount: 0,
        results: const [],
        fieldSample: const {},
        error: fetch.error ?? '请求失败',
      );
    }

    try {
      final bookListRule = searchRule.bookList ?? '';
      final results = <SearchResult>[];
      Map<String, String> fieldSample = const {};
      var listCount = 0;

      final body = fetch.body!;
      final trimmed = body.trimLeft();
      final jsonRoot = (trimmed.startsWith('{') || trimmed.startsWith('['))
          ? _tryDecodeJsonValue(body)
          : null;

      if (jsonRoot != null && _looksLikeJsonPath(bookListRule)) {
        final nodes = _selectJsonList(jsonRoot, bookListRule);
        listCount = nodes.length;
        for (final node in nodes) {
          final name = _parseValueOnNode(node, searchRule.name, requestUrl);
          final author = _parseValueOnNode(node, searchRule.author, requestUrl);
          final kind = _parseValueOnNode(node, searchRule.kind, requestUrl);
          var coverUrl =
              _parseValueOnNode(node, searchRule.coverUrl, requestUrl);
          if (coverUrl.isNotEmpty && !coverUrl.startsWith('http')) {
            coverUrl = _absoluteUrl(requestUrl, coverUrl);
          }
          final intro = _parseValueOnNode(node, searchRule.intro, requestUrl);
          final lastChapter =
              _parseValueOnNode(node, searchRule.lastChapter, requestUrl);
          final updateTime =
              _parseValueOnNode(node, searchRule.updateTime, requestUrl);
          final wordCount =
              _parseValueOnNode(node, searchRule.wordCount, requestUrl);
          var bookUrl = _parseValueOnNode(node, searchRule.bookUrl, requestUrl);
          if (bookUrl.isNotEmpty && !bookUrl.startsWith('http')) {
            bookUrl = _absoluteUrl(requestUrl, bookUrl);
          }

          final result = SearchResult(
            name: name,
            author: author,
            coverUrl: coverUrl,
            intro: intro,
            kind: kind,
            lastChapter: lastChapter,
            updateTime: updateTime,
            wordCount: wordCount,
            bookUrl: bookUrl,
            sourceUrl: source.bookSourceUrl,
            sourceName: source.bookSourceName,
          );

          if (results.isEmpty) {
            fieldSample = <String, String>{
              'name': name,
              'author': author,
              'coverUrl': coverUrl,
              'intro': intro,
              'kind': kind,
              'lastChapter': lastChapter,
              'updateTime': updateTime,
              'wordCount': wordCount,
              'bookUrl': bookUrl,
            };
          }

          if (result.name.isNotEmpty && result.bookUrl.isNotEmpty) {
            results.add(result);
          }
        }
      } else {
        final document = html_parser.parse(body);
        final bookElements = _selectAllElementsByRule(document, bookListRule);
        listCount = bookElements.length;

        for (final element in bookElements) {
          final name = _parseRule(element, searchRule.name, requestUrl);
          final author = _parseRule(element, searchRule.author, requestUrl);
          final kind = _parseRule(element, searchRule.kind, requestUrl);
          var coverUrl = _parseRule(element, searchRule.coverUrl, requestUrl);
          if (coverUrl.isNotEmpty && !coverUrl.startsWith('http')) {
            coverUrl = _absoluteUrl(requestUrl, coverUrl);
          }
          final intro = _parseRule(element, searchRule.intro, requestUrl);
          final lastChapter =
              _parseRule(element, searchRule.lastChapter, requestUrl);
          final updateTime =
              _parseRule(element, searchRule.updateTime, requestUrl);
          final wordCount =
              _parseRule(element, searchRule.wordCount, requestUrl);
          var bookUrl = _parseRule(element, searchRule.bookUrl, requestUrl);
          if (bookUrl.isNotEmpty && !bookUrl.startsWith('http')) {
            bookUrl = _absoluteUrl(requestUrl, bookUrl);
          }

          final result = SearchResult(
            name: name,
            author: author,
            coverUrl: coverUrl,
            intro: intro,
            kind: kind,
            lastChapter: lastChapter,
            updateTime: updateTime,
            wordCount: wordCount,
            bookUrl: bookUrl,
            sourceUrl: source.bookSourceUrl,
            sourceName: source.bookSourceName,
          );

          if (results.isEmpty) {
            fieldSample = <String, String>{
              'name': name,
              'author': author,
              'coverUrl': coverUrl,
              'intro': intro,
              'kind': kind,
              'lastChapter': lastChapter,
              'updateTime': updateTime,
              'wordCount': wordCount,
              'bookUrl': bookUrl,
            };
          }

          if (result.name.isNotEmpty && result.bookUrl.isNotEmpty) {
            results.add(result);
          }
        }
      }

      return SearchDebugResult(
        fetch: fetch,
        requestType: DebugRequestType.search,
        requestUrlRule: searchUrlRule,
        listRule: bookListRule,
        listCount: listCount,
        results: results,
        fieldSample: fieldSample,
        error: null,
      );
    } catch (e) {
      return SearchDebugResult(
        fetch: fetch,
        requestType: DebugRequestType.search,
        requestUrlRule: searchUrlRule,
        listRule: searchRule.bookList,
        listCount: 0,
        results: const [],
        fieldSample: const {},
        error: '解析失败: $e',
      );
    }
  }

  /// 发现书籍
  ///
  /// 对标 Legado：`exploreUrl` + `ruleExplore`
  Future<List<SearchResult>> explore(
    BookSource source, {
    String? exploreUrlOverride,
  }) async {
    _clearRuntimeVariables();
    final exploreRule = source.ruleExplore;
    final exploreUrlRule = exploreUrlOverride ?? source.exploreUrl;
    if (exploreRule == null ||
        exploreUrlRule == null ||
        exploreUrlRule.trim().isEmpty) {
      return [];
    }

    try {
      final exploreUrl = _buildUrl(
        source.bookSourceUrl,
        exploreUrlRule,
        const {},
        jsLib: source.jsLib,
      );

      final response = await _fetch(
        exploreUrl,
        header: source.header,
        jsLib: source.jsLib,
        timeoutMs: source.respondTime,
        enabledCookieJar: source.enabledCookieJar,
        sourceKey: source.bookSourceUrl,
        concurrentRate: source.concurrentRate,
      );
      if (response == null) return [];

      final results = <SearchResult>[];

      final bookListRule = exploreRule.bookList ?? '';
      final trimmed = response.trimLeft();
      final jsonRoot = (trimmed.startsWith('{') || trimmed.startsWith('['))
          ? _tryDecodeJsonValue(response)
          : null;

      if (jsonRoot != null && _looksLikeJsonPath(bookListRule)) {
        final nodes = _selectJsonList(jsonRoot, bookListRule);
        for (final node in nodes) {
          final name = _parseValueOnNode(node, exploreRule.name, exploreUrl);
          final author =
              _parseValueOnNode(node, exploreRule.author, exploreUrl);
          final intro = _parseValueOnNode(node, exploreRule.intro, exploreUrl);
          final kind = _parseValueOnNode(node, exploreRule.kind, exploreUrl);
          final lastChapter =
              _parseValueOnNode(node, exploreRule.lastChapter, exploreUrl);
          final updateTime =
              _parseValueOnNode(node, exploreRule.updateTime, exploreUrl);
          final wordCount =
              _parseValueOnNode(node, exploreRule.wordCount, exploreUrl);

          var bookUrl =
              _parseValueOnNode(node, exploreRule.bookUrl, exploreUrl);
          if (bookUrl.isNotEmpty && !bookUrl.startsWith('http')) {
            bookUrl = _absoluteUrl(exploreUrl, bookUrl);
          }

          var coverUrl =
              _parseValueOnNode(node, exploreRule.coverUrl, exploreUrl);
          if (coverUrl.isNotEmpty && !coverUrl.startsWith('http')) {
            coverUrl = _absoluteUrl(exploreUrl, coverUrl);
          }

          final result = SearchResult(
            name: name,
            author: author,
            coverUrl: coverUrl,
            intro: intro,
            kind: kind,
            lastChapter: lastChapter,
            updateTime: updateTime,
            wordCount: wordCount,
            bookUrl: bookUrl,
            sourceUrl: source.bookSourceUrl,
            sourceName: source.bookSourceName,
          );

          if (result.name.isNotEmpty && result.bookUrl.isNotEmpty) {
            results.add(result);
          }
        }
      } else {
        final document = html_parser.parse(response);
        final bookElements = _selectAllElementsByRule(document, bookListRule);

        for (final element in bookElements) {
          var bookUrl = _parseRule(element, exploreRule.bookUrl, exploreUrl);
          if (bookUrl.isNotEmpty && !bookUrl.startsWith('http')) {
            bookUrl = _absoluteUrl(exploreUrl, bookUrl);
          }
          var coverUrl = _parseRule(element, exploreRule.coverUrl, exploreUrl);
          if (coverUrl.isNotEmpty && !coverUrl.startsWith('http')) {
            coverUrl = _absoluteUrl(exploreUrl, coverUrl);
          }
          final result = SearchResult(
            name: _parseRule(element, exploreRule.name, exploreUrl),
            author: _parseRule(element, exploreRule.author, exploreUrl),
            coverUrl: coverUrl,
            intro: _parseRule(element, exploreRule.intro, exploreUrl),
            kind: _parseRule(element, exploreRule.kind, exploreUrl),
            lastChapter:
                _parseRule(element, exploreRule.lastChapter, exploreUrl),
            updateTime: _parseRule(element, exploreRule.updateTime, exploreUrl),
            wordCount: _parseRule(element, exploreRule.wordCount, exploreUrl),
            bookUrl: bookUrl,
            sourceUrl: source.bookSourceUrl,
            sourceName: source.bookSourceName,
          );

          if (result.name.isNotEmpty && result.bookUrl.isNotEmpty) {
            results.add(result);
          }
        }
      }

      return results;
    } catch (e) {
      debugPrint('发现失败: $e');
      return [];
    }
  }

  Future<ExploreDebugResult> exploreDebug(
    BookSource source, {
    String? exploreUrlOverride,
  }) async {
    final exploreRule = source.ruleExplore;
    final exploreUrlRule = exploreUrlOverride ?? source.exploreUrl;
    if (exploreRule == null ||
        exploreUrlRule == null ||
        exploreUrlRule.trim().isEmpty) {
      return ExploreDebugResult(
        fetch: FetchDebugResult.empty(),
        requestType: DebugRequestType.explore,
        requestUrlRule: exploreUrlRule,
        listRule: exploreRule?.bookList,
        listCount: 0,
        results: const [],
        fieldSample: const {},
        error: 'exploreUrl / ruleExplore 为空',
      );
    }

    final requestUrl = _buildUrl(
      source.bookSourceUrl,
      exploreUrlRule,
      const {},
      jsLib: source.jsLib,
    );
    final fetch = await _fetchDebug(
      requestUrl,
      header: source.header,
      jsLib: source.jsLib,
      timeoutMs: source.respondTime,
      enabledCookieJar: source.enabledCookieJar,
      sourceKey: source.bookSourceUrl,
      concurrentRate: source.concurrentRate,
    );
    if (fetch.body == null) {
      return ExploreDebugResult(
        fetch: fetch,
        requestType: DebugRequestType.explore,
        requestUrlRule: exploreUrlRule,
        listRule: exploreRule.bookList,
        listCount: 0,
        results: const [],
        fieldSample: const {},
        error: fetch.error ?? '请求失败',
      );
    }

    try {
      final bookListRule = exploreRule.bookList ?? '';
      final results = <SearchResult>[];
      Map<String, String> fieldSample = const {};
      var listCount = 0;

      final body = fetch.body!;
      final trimmed = body.trimLeft();
      final jsonRoot = (trimmed.startsWith('{') || trimmed.startsWith('['))
          ? _tryDecodeJsonValue(body)
          : null;

      if (jsonRoot != null && _looksLikeJsonPath(bookListRule)) {
        final nodes = _selectJsonList(jsonRoot, bookListRule);
        listCount = nodes.length;
        for (final node in nodes) {
          final name = _parseValueOnNode(node, exploreRule.name, requestUrl);
          final author =
              _parseValueOnNode(node, exploreRule.author, requestUrl);
          final kind = _parseValueOnNode(node, exploreRule.kind, requestUrl);
          var coverUrl =
              _parseValueOnNode(node, exploreRule.coverUrl, requestUrl);
          if (coverUrl.isNotEmpty && !coverUrl.startsWith('http')) {
            coverUrl = _absoluteUrl(requestUrl, coverUrl);
          }
          final intro = _parseValueOnNode(node, exploreRule.intro, requestUrl);
          final lastChapter =
              _parseValueOnNode(node, exploreRule.lastChapter, requestUrl);
          final updateTime =
              _parseValueOnNode(node, exploreRule.updateTime, requestUrl);
          final wordCount =
              _parseValueOnNode(node, exploreRule.wordCount, requestUrl);
          var bookUrl =
              _parseValueOnNode(node, exploreRule.bookUrl, requestUrl);
          if (bookUrl.isNotEmpty && !bookUrl.startsWith('http')) {
            bookUrl = _absoluteUrl(requestUrl, bookUrl);
          }

          final result = SearchResult(
            name: name,
            author: author,
            coverUrl: coverUrl,
            intro: intro,
            kind: kind,
            lastChapter: lastChapter,
            updateTime: updateTime,
            wordCount: wordCount,
            bookUrl: bookUrl,
            sourceUrl: source.bookSourceUrl,
            sourceName: source.bookSourceName,
          );

          if (results.isEmpty) {
            fieldSample = <String, String>{
              'name': name,
              'author': author,
              'coverUrl': coverUrl,
              'intro': intro,
              'kind': kind,
              'lastChapter': lastChapter,
              'updateTime': updateTime,
              'wordCount': wordCount,
              'bookUrl': bookUrl,
            };
          }

          if (result.name.isNotEmpty && result.bookUrl.isNotEmpty) {
            results.add(result);
          }
        }
      } else {
        final document = html_parser.parse(body);
        final bookElements = _selectAllElementsByRule(document, bookListRule);
        listCount = bookElements.length;

        for (final element in bookElements) {
          final name = _parseRule(element, exploreRule.name, requestUrl);
          final author = _parseRule(element, exploreRule.author, requestUrl);
          final kind = _parseRule(element, exploreRule.kind, requestUrl);
          var coverUrl = _parseRule(element, exploreRule.coverUrl, requestUrl);
          if (coverUrl.isNotEmpty && !coverUrl.startsWith('http')) {
            coverUrl = _absoluteUrl(requestUrl, coverUrl);
          }
          final intro = _parseRule(element, exploreRule.intro, requestUrl);
          final lastChapter =
              _parseRule(element, exploreRule.lastChapter, requestUrl);
          final updateTime =
              _parseRule(element, exploreRule.updateTime, requestUrl);
          final wordCount =
              _parseRule(element, exploreRule.wordCount, requestUrl);
          var bookUrl = _parseRule(element, exploreRule.bookUrl, requestUrl);
          if (bookUrl.isNotEmpty && !bookUrl.startsWith('http')) {
            bookUrl = _absoluteUrl(requestUrl, bookUrl);
          }

          final result = SearchResult(
            name: name,
            author: author,
            coverUrl: coverUrl,
            intro: intro,
            kind: kind,
            lastChapter: lastChapter,
            updateTime: updateTime,
            wordCount: wordCount,
            bookUrl: bookUrl,
            sourceUrl: source.bookSourceUrl,
            sourceName: source.bookSourceName,
          );

          if (results.isEmpty) {
            fieldSample = <String, String>{
              'name': name,
              'author': author,
              'coverUrl': coverUrl,
              'intro': intro,
              'kind': kind,
              'lastChapter': lastChapter,
              'updateTime': updateTime,
              'wordCount': wordCount,
              'bookUrl': bookUrl,
            };
          }

          if (result.name.isNotEmpty && result.bookUrl.isNotEmpty) {
            results.add(result);
          }
        }
      }

      return ExploreDebugResult(
        fetch: fetch,
        requestType: DebugRequestType.explore,
        requestUrlRule: exploreUrlRule,
        listRule: bookListRule,
        listCount: listCount,
        results: results,
        fieldSample: fieldSample,
        error: null,
      );
    } catch (e) {
      return ExploreDebugResult(
        fetch: fetch,
        requestType: DebugRequestType.explore,
        requestUrlRule: exploreUrlRule,
        listRule: exploreRule.bookList,
        listCount: 0,
        results: const [],
        fieldSample: const {},
        error: '解析失败: $e',
      );
    }
  }

  /// 获取书籍详情
  Future<BookDetail?> getBookInfo(
    BookSource source,
    String bookUrl, {
    bool clearRuntimeVariables = true,
  }) async {
    if (clearRuntimeVariables) {
      _clearRuntimeVariables();
    }
    final bookInfoRule = source.ruleBookInfo;
    if (bookInfoRule == null) return null;

    try {
      final fullUrl = _absoluteUrl(source.bookSourceUrl, bookUrl);
      final response = await _fetch(
        fullUrl,
        header: source.header,
        jsLib: source.jsLib,
        timeoutMs: source.respondTime,
        enabledCookieJar: source.enabledCookieJar,
        sourceKey: source.bookSourceUrl,
        concurrentRate: source.concurrentRate,
      );
      if (response == null) return null;

      final trimmed = response.trimLeft();
      final jsonRoot = (trimmed.startsWith('{') || trimmed.startsWith('['))
          ? _tryDecodeJsonValue(response)
          : null;

      // JSON 模式
      if (jsonRoot != null) {
        var tocUrl = _parseValueOnNode(jsonRoot, bookInfoRule.tocUrl, fullUrl);
        if (tocUrl.trim().isEmpty && source.ruleToc != null) {
          tocUrl = fullUrl;
        } else if (tocUrl.isNotEmpty && !tocUrl.startsWith('http')) {
          tocUrl = _absoluteUrl(fullUrl, tocUrl);
        }

        var coverUrl =
            _parseValueOnNode(jsonRoot, bookInfoRule.coverUrl, fullUrl);
        if (coverUrl.isNotEmpty && !coverUrl.startsWith('http')) {
          coverUrl = _absoluteUrl(fullUrl, coverUrl);
        }

        return BookDetail(
          name: _parseValueOnNode(jsonRoot, bookInfoRule.name, fullUrl),
          author: _parseValueOnNode(jsonRoot, bookInfoRule.author, fullUrl),
          coverUrl: coverUrl,
          intro: _parseValueOnNode(jsonRoot, bookInfoRule.intro, fullUrl),
          kind: _parseValueOnNode(jsonRoot, bookInfoRule.kind, fullUrl),
          lastChapter:
              _parseValueOnNode(jsonRoot, bookInfoRule.lastChapter, fullUrl),
          updateTime:
              _parseValueOnNode(jsonRoot, bookInfoRule.updateTime, fullUrl),
          wordCount:
              _parseValueOnNode(jsonRoot, bookInfoRule.wordCount, fullUrl),
          tocUrl: tocUrl,
          bookUrl: fullUrl,
        );
      }

      // HTML 模式
      final document = html_parser.parse(response);
      Element? root = document.documentElement;

      // 如果有 init 规则，先定位根元素
      if (bookInfoRule.init != null && bookInfoRule.init!.isNotEmpty) {
        root = _selectFirstElementByRule(document, bookInfoRule.init!);
      }

      if (root == null) return null;

      var tocUrl = _parseRule(root, bookInfoRule.tocUrl, fullUrl);
      if (tocUrl.trim().isEmpty && source.ruleToc != null) {
        // 兼容 legado 常见用法：部分站点“详情页即目录页”，未配置 tocUrl 时默认使用当前详情页。
        tocUrl = fullUrl;
      } else if (tocUrl.isNotEmpty && !tocUrl.startsWith('http')) {
        tocUrl = _absoluteUrl(fullUrl, tocUrl);
      }

      var coverUrl = _parseRule(root, bookInfoRule.coverUrl, fullUrl);
      if (coverUrl.isNotEmpty && !coverUrl.startsWith('http')) {
        coverUrl = _absoluteUrl(fullUrl, coverUrl);
      }

      return BookDetail(
        name: _parseRule(root, bookInfoRule.name, fullUrl),
        author: _parseRule(root, bookInfoRule.author, fullUrl),
        coverUrl: coverUrl,
        intro: _parseRule(root, bookInfoRule.intro, fullUrl),
        kind: _parseRule(root, bookInfoRule.kind, fullUrl),
        lastChapter: _parseRule(root, bookInfoRule.lastChapter, fullUrl),
        updateTime: _parseRule(root, bookInfoRule.updateTime, fullUrl),
        wordCount: _parseRule(root, bookInfoRule.wordCount, fullUrl),
        tocUrl: tocUrl,
        bookUrl: fullUrl,
      );
    } catch (e) {
      debugPrint('获取书籍详情失败: $e');
      return null;
    }
  }

  Future<BookInfoDebugResult> getBookInfoDebug(
    BookSource source,
    String bookUrl,
  ) async {
    final bookInfoRule = source.ruleBookInfo;
    if (bookInfoRule == null) {
      return BookInfoDebugResult(
        fetch: FetchDebugResult.empty(),
        requestType: DebugRequestType.bookInfo,
        requestUrlRule: bookUrl,
        initRule: null,
        initMatched: false,
        detail: null,
        fieldSample: const {},
        error: 'ruleBookInfo 为空',
      );
    }

    final fullUrl = _absoluteUrl(source.bookSourceUrl, bookUrl);
    final fetch = await _fetchDebug(
      fullUrl,
      header: source.header,
      jsLib: source.jsLib,
      timeoutMs: source.respondTime,
      enabledCookieJar: source.enabledCookieJar,
      sourceKey: source.bookSourceUrl,
      concurrentRate: source.concurrentRate,
    );
    if (fetch.body == null) {
      return BookInfoDebugResult(
        fetch: fetch,
        requestType: DebugRequestType.bookInfo,
        requestUrlRule: bookUrl,
        initRule: bookInfoRule.init,
        initMatched: false,
        detail: null,
        fieldSample: const {},
        error: fetch.error ?? '请求失败',
      );
    }

    try {
      final body = fetch.body!;
      final trimmed = body.trimLeft();
      final jsonRoot = (trimmed.startsWith('{') || trimmed.startsWith('['))
          ? _tryDecodeJsonValue(body)
          : null;

      // JSON 模式（响应为 JSON 时 init 不适用）
      if (jsonRoot != null) {
        final initRule = bookInfoRule.init;
        final initMatched = initRule == null || initRule.trim().isEmpty;

        final name = _parseValueOnNode(jsonRoot, bookInfoRule.name, fullUrl);
        final author =
            _parseValueOnNode(jsonRoot, bookInfoRule.author, fullUrl);
        var coverUrl =
            _parseValueOnNode(jsonRoot, bookInfoRule.coverUrl, fullUrl);
        if (coverUrl.isNotEmpty && !coverUrl.startsWith('http')) {
          coverUrl = _absoluteUrl(fullUrl, coverUrl);
        }
        final intro = _parseValueOnNode(jsonRoot, bookInfoRule.intro, fullUrl);
        final kind = _parseValueOnNode(jsonRoot, bookInfoRule.kind, fullUrl);
        final lastChapter =
            _parseValueOnNode(jsonRoot, bookInfoRule.lastChapter, fullUrl);
        final updateTime =
            _parseValueOnNode(jsonRoot, bookInfoRule.updateTime, fullUrl);
        final wordCount =
            _parseValueOnNode(jsonRoot, bookInfoRule.wordCount, fullUrl);
        var tocUrl = _parseValueOnNode(jsonRoot, bookInfoRule.tocUrl, fullUrl);
        if (tocUrl.trim().isEmpty && source.ruleToc != null) {
          tocUrl = fullUrl;
        } else if (tocUrl.isNotEmpty && !tocUrl.startsWith('http')) {
          tocUrl = _absoluteUrl(fullUrl, tocUrl);
        }

        final detail = BookDetail(
          name: name,
          author: author,
          coverUrl: coverUrl,
          intro: intro,
          kind: kind,
          lastChapter: lastChapter,
          updateTime: updateTime,
          wordCount: wordCount,
          tocUrl: tocUrl,
          bookUrl: fullUrl,
        );

        return BookInfoDebugResult(
          fetch: fetch,
          requestType: DebugRequestType.bookInfo,
          requestUrlRule: bookUrl,
          initRule: initRule,
          initMatched: initMatched,
          detail: detail,
          fieldSample: <String, String>{
            'name': name,
            'author': author,
            'coverUrl': coverUrl,
            'intro': intro,
            'kind': kind,
            'lastChapter': lastChapter,
            'updateTime': updateTime,
            'wordCount': wordCount,
            'tocUrl': tocUrl,
          },
          error: initMatched ? null : '响应为 JSON：init 规则不适用',
        );
      }

      // HTML 模式
      final document = html_parser.parse(body);
      Element? root = document.documentElement;
      var initMatched = true;

      if (bookInfoRule.init != null && bookInfoRule.init!.isNotEmpty) {
        root = _selectFirstElementByRule(document, bookInfoRule.init!);
        initMatched = root != null;
      }
      if (root == null) {
        return BookInfoDebugResult(
          fetch: fetch,
          requestType: DebugRequestType.bookInfo,
          requestUrlRule: bookUrl,
          initRule: bookInfoRule.init,
          initMatched: initMatched,
          detail: null,
          fieldSample: const {},
          error: 'init 定位失败或页面无 documentElement',
        );
      }

      final name = _parseRule(root, bookInfoRule.name, fullUrl);
      final author = _parseRule(root, bookInfoRule.author, fullUrl);
      var coverUrl = _parseRule(root, bookInfoRule.coverUrl, fullUrl);
      if (coverUrl.isNotEmpty && !coverUrl.startsWith('http')) {
        coverUrl = _absoluteUrl(fullUrl, coverUrl);
      }
      final intro = _parseRule(root, bookInfoRule.intro, fullUrl);
      final kind = _parseRule(root, bookInfoRule.kind, fullUrl);
      final lastChapter = _parseRule(root, bookInfoRule.lastChapter, fullUrl);
      final updateTime = _parseRule(root, bookInfoRule.updateTime, fullUrl);
      final wordCount = _parseRule(root, bookInfoRule.wordCount, fullUrl);
      var tocUrl = _parseRule(root, bookInfoRule.tocUrl, fullUrl);
      if (tocUrl.trim().isEmpty && source.ruleToc != null) {
        tocUrl = fullUrl;
      } else if (tocUrl.isNotEmpty && !tocUrl.startsWith('http')) {
        tocUrl = _absoluteUrl(fullUrl, tocUrl);
      }

      final detail = BookDetail(
        name: name,
        author: author,
        coverUrl: coverUrl,
        intro: intro,
        kind: kind,
        lastChapter: lastChapter,
        updateTime: updateTime,
        wordCount: wordCount,
        tocUrl: tocUrl,
        bookUrl: fullUrl,
      );

      return BookInfoDebugResult(
        fetch: fetch,
        requestType: DebugRequestType.bookInfo,
        requestUrlRule: bookUrl,
        initRule: bookInfoRule.init,
        initMatched: initMatched,
        detail: detail,
        fieldSample: <String, String>{
          'name': name,
          'author': author,
          'coverUrl': coverUrl,
          'intro': intro,
          'kind': kind,
          'lastChapter': lastChapter,
          'updateTime': updateTime,
          'wordCount': wordCount,
          'tocUrl': tocUrl,
        },
        error: null,
      );
    } catch (e) {
      return BookInfoDebugResult(
        fetch: fetch,
        requestType: DebugRequestType.bookInfo,
        requestUrlRule: bookUrl,
        initRule: bookInfoRule.init,
        initMatched: false,
        detail: null,
        fieldSample: const {},
        error: '解析失败: $e',
      );
    }
  }

  /// 获取目录
  Future<List<TocItem>> getToc(
    BookSource source,
    String tocUrl, {
    bool clearRuntimeVariables = true,
  }) async {
    if (clearRuntimeVariables) {
      _clearRuntimeVariables();
    }
    final tocRule = source.ruleToc;
    if (tocRule == null) return [];

    try {
      final normalized = _normalizeListRule(tocRule.chapterList);
      final chapters = <TocItem>[];

      final visitedUrlKeys = <String>{};
      var currentUrl = _absoluteUrl(source.bookSourceUrl, tocUrl);
      var page = 0;
      const maxPages = 12;
      final pendingNextUrls = <String>[];
      final queuedUrlKeys = <String>{};

      while (currentUrl.trim().isNotEmpty && page < maxPages) {
        if (!_markVisitedUrl(visitedUrlKeys, currentUrl)) break;
        queuedUrlKeys.remove(_normalizeUrlVisitKey(currentUrl));

        final response = await _fetch(
          currentUrl,
          header: source.header,
          jsLib: source.jsLib,
          timeoutMs: source.respondTime,
          enabledCookieJar: source.enabledCookieJar,
          sourceKey: source.bookSourceUrl,
          concurrentRate: source.concurrentRate,
        );
        if (response == null) break;

        final stageBody = _applyStageResponseJs(
          responseText: response,
          jsRule: tocRule.preUpdateJs,
          currentUrl: currentUrl,
          jsLib: source.jsLib,
          stageLabel: 'preUpdateJs',
        );

        final trimmed = stageBody.trimLeft();
        final jsonRoot = (trimmed.startsWith('{') || trimmed.startsWith('['))
            ? _tryDecodeJsonValue(stageBody)
            : null;

        List<String> nextCandidates = const <String>[];

        if (jsonRoot != null && _looksLikeJsonPath(normalized.selector)) {
          final nodes = _selectJsonList(jsonRoot, normalized.selector);
          for (final node in nodes) {
            final name =
                _parseValueOnNode(node, tocRule.chapterName, currentUrl);
            var url = _parseValueOnNode(node, tocRule.chapterUrl, currentUrl);
            if (url.isNotEmpty && !url.startsWith('http')) {
              url = _absoluteUrl(currentUrl, url);
            }
            if (name.isEmpty || url.isEmpty) continue;
            chapters.add(TocItem(index: chapters.length, name: name, url: url));
          }

          if (tocRule.nextTocUrl != null &&
              tocRule.nextTocUrl!.trim().isNotEmpty) {
            nextCandidates = _parseStringListFromJson(
              json: jsonRoot,
              rule: tocRule.nextTocUrl!,
              baseUrl: currentUrl,
              isUrl: true,
            );
          }
        } else {
          final document = html_parser.parse(stageBody);
          final root = document.documentElement;
          if (root == null) break;

          final chapterElements =
              _selectAllElementsByRule(document, normalized.selector);

          for (final element in chapterElements) {
            final name = _parseRule(element, tocRule.chapterName, currentUrl);
            var url = _parseRule(element, tocRule.chapterUrl, currentUrl);
            if (url.isNotEmpty && !url.startsWith('http')) {
              url = _absoluteUrl(currentUrl, url);
            }
            if (name.isEmpty || url.isEmpty) continue;
            chapters.add(TocItem(index: chapters.length, name: name, url: url));
          }

          if (tocRule.nextTocUrl != null &&
              tocRule.nextTocUrl!.trim().isNotEmpty) {
            nextCandidates = _parseStringListFromHtml(
              root: root,
              rule: tocRule.nextTocUrl!,
              baseUrl: currentUrl,
              isUrl: true,
            );
          }
        }

        if (nextCandidates.isNotEmpty) {
          final appendUrls = _collectNextUrlCandidates(
            nextCandidates,
            currentUrl: currentUrl,
            visitedUrlKeys: visitedUrlKeys,
            queuedUrlKeys: queuedUrlKeys,
          );
          for (final u in appendUrls) {
            final key = _normalizeUrlVisitKey(u);
            if (key.isEmpty || queuedUrlKeys.contains(key)) continue;
            queuedUrlKeys.add(key);
            pendingNextUrls.add(u);
          }
        }

        if (pendingNextUrls.isEmpty) break;
        currentUrl = pendingNextUrls.removeAt(0);
        page++;
      }

      final ordered = normalized.reverse
          ? chapters.reversed.toList(growable: false)
          : chapters;
      final reIndexed = <TocItem>[
        for (var i = 0; i < ordered.length; i++)
          TocItem(index: i, name: ordered[i].name, url: ordered[i].url),
      ];
      final formatted = _applyTocFormatJs(
        toc: reIndexed,
        formatJs: tocRule.formatJs,
        jsLib: source.jsLib,
      );
      return formatted;
    } catch (e) {
      debugPrint('获取目录失败: $e');
      return [];
    }
  }

  Future<TocDebugResult> getTocDebug(BookSource source, String tocUrl) async {
    final tocRule = source.ruleToc;
    if (tocRule == null) {
      return TocDebugResult(
        fetch: FetchDebugResult.empty(),
        requestType: DebugRequestType.toc,
        requestUrlRule: tocUrl,
        listRule: null,
        listCount: 0,
        toc: const [],
        fieldSample: const {},
        error: 'ruleToc 为空',
      );
    }

    final fullUrl = _absoluteUrl(source.bookSourceUrl, tocUrl);
    final fetch = await _fetchDebug(
      fullUrl,
      header: source.header,
      jsLib: source.jsLib,
      timeoutMs: source.respondTime,
      enabledCookieJar: source.enabledCookieJar,
      sourceKey: source.bookSourceUrl,
      concurrentRate: source.concurrentRate,
    );
    if (fetch.body == null) {
      return TocDebugResult(
        fetch: fetch,
        requestType: DebugRequestType.toc,
        requestUrlRule: tocUrl,
        listRule: tocRule.chapterList,
        listCount: 0,
        toc: const [],
        fieldSample: const {},
        error: fetch.error ?? '请求失败',
      );
    }

    try {
      final normalized = _normalizeListRule(tocRule.chapterList);
      final chapters = <TocItem>[];
      Map<String, String> sample = const {};
      var listCount = 0;

      final body = fetch.body!;
      final stageBody = _applyStageResponseJs(
        responseText: body,
        jsRule: tocRule.preUpdateJs,
        currentUrl: fullUrl,
        jsLib: source.jsLib,
        stageLabel: 'preUpdateJs',
      );
      final trimmed = stageBody.trimLeft();
      final jsonRoot = (trimmed.startsWith('{') || trimmed.startsWith('['))
          ? _tryDecodeJsonValue(stageBody)
          : null;

      if (jsonRoot != null && _looksLikeJsonPath(normalized.selector)) {
        final nodes = _selectJsonList(jsonRoot, normalized.selector);
        listCount = nodes.length;
        for (final node in nodes) {
          final name = _parseValueOnNode(node, tocRule.chapterName, fullUrl);
          var url = _parseValueOnNode(node, tocRule.chapterUrl, fullUrl);
          if (url.isNotEmpty && !url.startsWith('http')) {
            url = _absoluteUrl(fullUrl, url);
          }
          if (chapters.isEmpty) {
            sample = <String, String>{'name': name, 'url': url};
          }
          if (name.isNotEmpty && url.isNotEmpty) {
            chapters.add(TocItem(index: chapters.length, name: name, url: url));
          }
        }
        if (tocRule.nextTocUrl != null &&
            tocRule.nextTocUrl!.trim().isNotEmpty) {
          final nextList = _parseStringListFromJson(
            json: jsonRoot,
            rule: tocRule.nextTocUrl!,
            baseUrl: fullUrl,
            isUrl: true,
          );
          if (nextList.isNotEmpty) {
            sample = <String, String>{
              ...sample,
              'nextTocUrl': nextList.join('\n')
            };
          }
        }
      } else {
        final document = html_parser.parse(stageBody);
        final chapterElements =
            _selectAllElementsByRule(document, normalized.selector);
        listCount = chapterElements.length;

        for (var i = 0; i < chapterElements.length; i++) {
          final element = chapterElements[i];
          final name = _parseRule(element, tocRule.chapterName, fullUrl);
          var url = _parseRule(element, tocRule.chapterUrl, fullUrl);
          if (url.isNotEmpty && !url.startsWith('http')) {
            url = _absoluteUrl(fullUrl, url);
          }
          if (chapters.isEmpty) {
            sample = <String, String>{'name': name, 'url': url};
          }
          if (name.isNotEmpty && url.isNotEmpty) {
            chapters.add(TocItem(index: chapters.length, name: name, url: url));
          }
        }

        if (tocRule.nextTocUrl != null &&
            tocRule.nextTocUrl!.trim().isNotEmpty) {
          final root = document.documentElement;
          if (root != null) {
            final nextList = _parseStringListFromHtml(
              root: root,
              rule: tocRule.nextTocUrl!,
              baseUrl: fullUrl,
              isUrl: true,
            );
            if (nextList.isNotEmpty) {
              sample = <String, String>{
                ...sample,
                'nextTocUrl': nextList.join('\n')
              };
            }
          }
        }
      }

      final ordered = normalized.reverse
          ? chapters.reversed.toList(growable: false)
          : chapters;
      final reIndexed = <TocItem>[
        for (var i = 0; i < ordered.length; i++)
          TocItem(index: i, name: ordered[i].name, url: ordered[i].url),
      ];
      final formatted = _applyTocFormatJs(
        toc: reIndexed,
        formatJs: tocRule.formatJs,
        jsLib: source.jsLib,
      );
      if (formatted.isNotEmpty && sample.isNotEmpty) {
        sample = <String, String>{
          ...sample,
          'nameAfterFormat': formatted.first.name,
        };
      }

      return TocDebugResult(
        fetch: fetch,
        requestType: DebugRequestType.toc,
        requestUrlRule: tocUrl,
        listRule: normalized.selector,
        listCount: listCount,
        toc: formatted,
        fieldSample: sample,
        error: null,
      );
    } catch (e) {
      return TocDebugResult(
        fetch: fetch,
        requestType: DebugRequestType.toc,
        requestUrlRule: tocUrl,
        listRule: tocRule.chapterList,
        listCount: 0,
        toc: const [],
        fieldSample: const {},
        error: '解析失败: $e',
      );
    }
  }

  _NormalizedListRule _normalizeListRule(String? rawRule) {
    var rule = (rawRule ?? '').trim();
    var reverse = false;
    if (rule.startsWith('-')) {
      reverse = true;
      rule = rule.substring(1);
    }
    if (rule.startsWith('+')) {
      rule = rule.substring(1);
    }
    return _NormalizedListRule(selector: rule.trim(), reverse: reverse);
  }

  String _importantResponseHeaders(Map<String, String> headers) {
    if (headers.isEmpty) return '';
    final normalized = <String, String>{};
    headers.forEach((k, v) => normalized[k.toLowerCase()] = v);

    const keys = <String>[
      'content-type',
      'location',
      'set-cookie',
      'server',
      'via',
      'x-powered-by',
      'cf-ray',
      'cf-cache-status',
      'x-cache',
      'x-served-by',
    ];

    final parts = <String>[];
    for (final k in keys) {
      final v = normalized[k];
      if (v == null || v.trim().isEmpty) continue;
      final safe = v.length <= 200 ? v : '${v.substring(0, 200)}…';
      parts.add('$k=$safe');
    }
    return parts.join('; ');
  }

  /// 获取正文
  Future<String> getContent(
    BookSource source,
    String chapterUrl, {
    String? nextChapterUrl,
    bool clearRuntimeVariables = true,
  }) async {
    if (clearRuntimeVariables) {
      _clearRuntimeVariables();
    }
    final contentRule = source.ruleContent;
    if (contentRule == null) return '';

    try {
      final visitedUrlKeys = <String>{};
      var currentUrl = _absoluteUrl(source.bookSourceUrl, chapterUrl);
      final nextChapterUrlKey = _buildNextChapterUrlKey(
        chapterEntryUrl: currentUrl,
        nextChapterUrl: nextChapterUrl,
      );
      var page = 0;
      const maxPages = 8;

      final parts = <String>[];
      final pendingNextUrls = <String>[];
      final queuedUrlKeys = <String>{};

      while (currentUrl.trim().isNotEmpty && page < maxPages) {
        if (!_markVisitedUrl(visitedUrlKeys, currentUrl)) break;
        queuedUrlKeys.remove(_normalizeUrlVisitKey(currentUrl));

        final response = await _fetch(
          currentUrl,
          header: source.header,
          jsLib: source.jsLib,
          timeoutMs: source.respondTime,
          enabledCookieJar: source.enabledCookieJar,
          sourceKey: source.bookSourceUrl,
          concurrentRate: source.concurrentRate,
        );
        if (response == null) break;

        final stageBody = _applyStageResponseJs(
          responseText: response,
          jsRule: contentRule.webJs,
          currentUrl: currentUrl,
          jsLib: source.jsLib,
          stageLabel: 'webJs',
        );

        final trimmed = stageBody.trimLeft();
        final jsonRoot = (trimmed.startsWith('{') || trimmed.startsWith('['))
            ? _tryDecodeJsonValue(stageBody)
            : null;

        String extracted;
        List<String> nextCandidates = const <String>[];

        if (jsonRoot != null &&
            contentRule.content != null &&
            _looksLikeJsonPath(contentRule.content!)) {
          extracted =
              _parseValueOnNode(jsonRoot, contentRule.content, currentUrl);
          if (contentRule.nextContentUrl != null &&
              contentRule.nextContentUrl!.trim().isNotEmpty) {
            nextCandidates = _parseStringListFromJson(
              json: jsonRoot,
              rule: contentRule.nextContentUrl!,
              baseUrl: currentUrl,
              isUrl: true,
            );
          }
        } else {
          final document = html_parser.parse(stageBody);
          final root = document.documentElement;
          if (root == null) break;
          if (contentRule.content == null ||
              contentRule.content!.trim().isEmpty) {
            extracted = root.text;
          } else {
            extracted = _parseRule(root, contentRule.content, currentUrl);
          }
          if (contentRule.nextContentUrl != null &&
              contentRule.nextContentUrl!.trim().isNotEmpty) {
            nextCandidates = _parseStringListFromHtml(
              root: root,
              rule: contentRule.nextContentUrl!,
              baseUrl: currentUrl,
              isUrl: true,
            );
          }
        }

        var processed = extracted;
        if (contentRule.replaceRegex != null &&
            contentRule.replaceRegex!.trim().isNotEmpty) {
          processed = _applyReplaceRegex(processed, contentRule.replaceRegex!);
        }
        final cleaned = _cleanContent(processed);
        if (cleaned.trim().isNotEmpty) parts.add(cleaned);

        if (nextCandidates.isNotEmpty) {
          final appendUrls = _collectNextUrlCandidates(
            nextCandidates,
            currentUrl: currentUrl,
            visitedUrlKeys: visitedUrlKeys,
            queuedUrlKeys: queuedUrlKeys,
            blockedUrlKey: nextChapterUrlKey,
          );
          for (final u in appendUrls) {
            final key = _normalizeUrlVisitKey(u);
            if (key.isEmpty || queuedUrlKeys.contains(key)) continue;
            queuedUrlKeys.add(key);
            pendingNextUrls.add(u);
          }
        }

        if (pendingNextUrls.isEmpty) break;
        currentUrl = pendingNextUrls.removeAt(0);
        page++;
      }

      return parts.join('\n');
    } catch (e) {
      debugPrint('获取正文失败: $e');
      return '';
    }
  }

  Future<ContentDebugResult> getContentDebug(
    BookSource source,
    String chapterUrl, {
    String? nextChapterUrl,
  }) async {
    final contentRule = source.ruleContent;
    if (contentRule == null) {
      return ContentDebugResult(
        fetch: FetchDebugResult.empty(),
        requestType: DebugRequestType.content,
        requestUrlRule: chapterUrl,
        extractedLength: 0,
        cleanedLength: 0,
        content: '',
        error: 'ruleContent 为空',
      );
    }

    final fullUrl = _absoluteUrl(source.bookSourceUrl, chapterUrl);
    final fetch = await _fetchDebug(
      fullUrl,
      header: source.header,
      jsLib: source.jsLib,
      timeoutMs: source.respondTime,
      enabledCookieJar: source.enabledCookieJar,
      sourceKey: source.bookSourceUrl,
      concurrentRate: source.concurrentRate,
    );
    if (fetch.body == null) {
      return ContentDebugResult(
        fetch: fetch,
        requestType: DebugRequestType.content,
        requestUrlRule: chapterUrl,
        extractedLength: 0,
        cleanedLength: 0,
        content: '',
        error: fetch.error ?? '请求失败',
      );
    }

    try {
      final visitedUrlKeys = <String>{};
      var currentUrl = fullUrl;
      final nextChapterUrlKey = _buildNextChapterUrlKey(
        chapterEntryUrl: fullUrl,
        nextChapterUrl: nextChapterUrl,
      );
      var page = 0;
      const maxPages = 8;

      var totalExtracted = 0;
      final parts = <String>[];
      final pendingNextUrls = <String>[];
      final queuedUrlKeys = <String>{};

      while (currentUrl.trim().isNotEmpty && page < maxPages) {
        if (!_markVisitedUrl(visitedUrlKeys, currentUrl)) break;
        queuedUrlKeys.remove(_normalizeUrlVisitKey(currentUrl));

        // 第一页用 fetch（含请求/响应调试信息），后续页用普通请求即可
        final body = (currentUrl == fullUrl)
            ? fetch.body!
            : await _fetch(
                currentUrl,
                header: source.header,
                jsLib: source.jsLib,
                timeoutMs: source.respondTime,
                enabledCookieJar: source.enabledCookieJar,
                sourceKey: source.bookSourceUrl,
                concurrentRate: source.concurrentRate,
              );
        if (body == null) break;

        final stageBody = _applyStageResponseJs(
          responseText: body,
          jsRule: contentRule.webJs,
          currentUrl: currentUrl,
          jsLib: source.jsLib,
          stageLabel: 'webJs',
        );

        final trimmed = stageBody.trimLeft();
        final jsonRoot = (trimmed.startsWith('{') || trimmed.startsWith('['))
            ? _tryDecodeJsonValue(stageBody)
            : null;

        String extracted;
        List<String> nextCandidates = const <String>[];

        if (jsonRoot != null &&
            contentRule.content != null &&
            _looksLikeJsonPath(contentRule.content!)) {
          extracted =
              _parseValueOnNode(jsonRoot, contentRule.content, currentUrl);
          if (contentRule.nextContentUrl != null &&
              contentRule.nextContentUrl!.trim().isNotEmpty) {
            nextCandidates = _parseStringListFromJson(
              json: jsonRoot,
              rule: contentRule.nextContentUrl!,
              baseUrl: currentUrl,
              isUrl: true,
            );
          }
        } else {
          final document = html_parser.parse(stageBody);
          final root = document.documentElement;
          if (root == null) break;
          if (contentRule.content == null ||
              contentRule.content!.trim().isEmpty) {
            extracted = root.text;
          } else {
            extracted = _parseRule(root, contentRule.content, currentUrl);
          }
          if (contentRule.nextContentUrl != null &&
              contentRule.nextContentUrl!.trim().isNotEmpty) {
            nextCandidates = _parseStringListFromHtml(
              root: root,
              rule: contentRule.nextContentUrl!,
              baseUrl: currentUrl,
              isUrl: true,
            );
          }
        }

        totalExtracted += extracted.length;

        var text = extracted;
        if (contentRule.replaceRegex != null &&
            contentRule.replaceRegex!.isNotEmpty) {
          text = _applyReplaceRegex(text, contentRule.replaceRegex!);
        }
        final cleaned = _cleanContent(text);
        if (cleaned.trim().isNotEmpty) parts.add(cleaned);

        if (nextCandidates.isNotEmpty) {
          final appendUrls = _collectNextUrlCandidates(
            nextCandidates,
            currentUrl: currentUrl,
            visitedUrlKeys: visitedUrlKeys,
            queuedUrlKeys: queuedUrlKeys,
            blockedUrlKey: nextChapterUrlKey,
          );
          for (final u in appendUrls) {
            final key = _normalizeUrlVisitKey(u);
            if (key.isEmpty || queuedUrlKeys.contains(key)) continue;
            queuedUrlKeys.add(key);
            pendingNextUrls.add(u);
          }
        }

        if (pendingNextUrls.isEmpty) break;
        currentUrl = pendingNextUrls.removeAt(0);
        page++;
      }

      final cleanedAll = parts.join('\n');

      return ContentDebugResult(
        fetch: fetch,
        requestType: DebugRequestType.content,
        requestUrlRule: chapterUrl,
        extractedLength: totalExtracted,
        cleanedLength: cleanedAll.length,
        content: cleanedAll,
        error: null,
      );
    } catch (e) {
      return ContentDebugResult(
        fetch: fetch,
        requestType: DebugRequestType.content,
        requestUrlRule: chapterUrl,
        extractedLength: 0,
        cleanedLength: 0,
        content: '',
        error: '解析失败: $e',
      );
    }
  }

  Future<void> _mergeSourceLoginHeaders(
    Map<String, String> headers,
    String? sourceKey,
  ) async {
    final key = (sourceKey ?? '').trim();
    if (key.isEmpty) return;

    final loginHeaders = await SourceLoginStore.getLoginHeaderMap(key);
    if (loginHeaders == null || loginHeaders.isEmpty) return;

    headers.addAll(loginHeaders);
  }

  /// 发送HTTP请求
  Future<String?> _fetch(
    String url, {
    String? header,
    String? jsLib,
    int? timeoutMs,
    bool? enabledCookieJar,
    String? sourceKey,
    String? concurrentRate,
  }) async {
    try {
      final parsedHeaders = _parseRequestHeaders(header, jsLib: jsLib);
      final parsedUrl = _parseLegadoStyleUrl(url);

      // Header 合并顺序对齐 legado 语义：
      // 书源 header -> 登录 header -> URL option headers（最高优先级）
      final mergedCustomHeaders = <String, String>{}
        ..addAll(parsedHeaders.headers);
      await _mergeSourceLoginHeaders(mergedCustomHeaders, sourceKey);
      mergedCustomHeaders
          .addAll(parsedUrl.option?.headers ?? const <String, String>{});

      // URL option js 允许二次修改 url/header
      var finalUrl = parsedUrl.url;
      if (parsedUrl.option?.js != null &&
          parsedUrl.option!.js!.trim().isNotEmpty) {
        final patched = _applyLegadoUrlOptionJs(
          js: parsedUrl.option!.js!.trim(),
          url: finalUrl,
          headerMap: mergedCustomHeaders,
        );
        if (patched != null) {
          finalUrl = patched.url;
          mergedCustomHeaders
            ..clear()
            ..addAll(patched.headers);
        }
      }

      // 对标 legado：UrlOption.origin 可补齐/覆盖 Origin/Referer（但若用户已显式写入，则不动）
      _applyPreferredOriginHeaders(
          mergedCustomHeaders, parsedUrl.option?.origin);

      final requestHeaders = _buildEffectiveRequestHeaders(
        finalUrl,
        customHeaders: mergedCustomHeaders,
      );

      final normalized = _normalizeRequestPayload(
        finalUrl,
        parsedUrl.option,
        requestHeaders,
      );
      final method = normalized.method;
      final body = normalized.body;
      final retry = normalized.retry;
      finalUrl = normalized.url;

      final timeout = (timeoutMs != null && timeoutMs > 0)
          ? Duration(milliseconds: timeoutMs)
          : null;

      final opts = Options(
        method: method,
        connectTimeout: timeout,
        sendTimeout: timeout,
        receiveTimeout: timeout,
        responseType: ResponseType.bytes,
        validateStatus: (_) => true,
        headers: requestHeaders,
      );

      final permit = await _acquireConcurrentRatePermit(
        sourceKey: sourceKey,
        concurrentRate: concurrentRate,
      );
      late ({Response<List<int>> response, int retryCount}) requestResult;
      final dio = _selectDio(enabledCookieJar: enabledCookieJar);
      try {
        requestResult = await _requestBytesWithRetry(
          dio: dio,
          url: finalUrl,
          options: opts,
          method: method,
          body: body,
          retry: retry,
        );
      } finally {
        _releaseConcurrentRatePermit(permit.record);
      }
      final resp = requestResult.response;
      final bytes = Uint8List.fromList(resp.data ?? const <int>[]);
      final respHeaders =
          resp.headers.map.map((k, v) => MapEntry(k, v.join(', ')));
      final decoded = _decodeResponseBytes(
        bytes: bytes,
        responseHeaders: respHeaders,
        optionCharset: parsedUrl.option?.charset,
      );
      return decoded.text;
    } catch (e) {
      debugPrint('请求失败: $url - $e');
      return null;
    }
  }

  Future<FetchDebugResult> _fetchDebug(
    String url, {
    String? header,
    String? jsLib,
    int? timeoutMs,
    bool? enabledCookieJar,
    String? sourceKey,
    String? concurrentRate,
  }) async {
    final sw = Stopwatch()..start();
    final parsedHeaders = _parseRequestHeaders(header, jsLib: jsLib);
    final parsedUrl = _parseLegadoStyleUrl(url);

    final mergedCustomHeaders = <String, String>{}
      ..addAll(parsedHeaders.headers);
    await _mergeSourceLoginHeaders(mergedCustomHeaders, sourceKey);
    mergedCustomHeaders
        .addAll(parsedUrl.option?.headers ?? const <String, String>{});

    var finalUrl = parsedUrl.url;
    _UrlJsPatchResult? urlJsPatch;
    if (parsedUrl.option?.js != null &&
        parsedUrl.option!.js!.trim().isNotEmpty) {
      urlJsPatch = _applyLegadoUrlOptionJs(
        js: parsedUrl.option!.js!.trim(),
        url: finalUrl,
        headerMap: mergedCustomHeaders,
      );
      if (urlJsPatch != null) {
        finalUrl = urlJsPatch.url;
        mergedCustomHeaders
          ..clear()
          ..addAll(urlJsPatch.headers);
      }
    }

    _applyPreferredOriginHeaders(mergedCustomHeaders, parsedUrl.option?.origin);

    final requestHeaders = _buildEffectiveRequestHeaders(
      finalUrl,
      customHeaders: mergedCustomHeaders,
    );
    final normalized = _normalizeRequestPayload(
      finalUrl,
      parsedUrl.option,
      requestHeaders,
    );
    final method = normalized.method;
    final body = normalized.body;
    final retry = normalized.retry;
    final methodDecision = normalized.methodDecision;
    final retryDecision = normalized.retryDecision;
    final requestCharsetDecision = normalized.requestCharsetDecision;
    final bodyEncoding = normalized.bodyEncoding;
    final bodyDecision = normalized.bodyDecision;
    finalUrl = normalized.url;
    var concurrentWaitMs = 0;
    var concurrentDecision = '未启用并发率限制';

    final forLog = Map<String, String>.from(requestHeaders);
    final cookieJarOn = enabledCookieJar ?? true;
    if (cookieJarOn) {
      try {
        final cookies = await RuleParserEngine.loadCookiesForUrl(finalUrl);
        if (cookies.isNotEmpty &&
            !forLog.keys.any((k) => k.toLowerCase() == 'cookie')) {
          forLog['Cookie'] =
              cookies.map((c) => '${c.name}=${c.value}').join('; ');
        }
      } catch (_) {
        // ignore cookie load failure
      }
    }
    try {
      final ct = _getHeaderIgnoreCase(requestHeaders, 'Content-Type');
      if (ct != null && ct.trim().isNotEmpty) {
        forLog['Content-Type'] = ct;
      }

      final timeout = (timeoutMs != null && timeoutMs > 0)
          ? Duration(milliseconds: timeoutMs)
          : null;
      final options = Options(
        method: method,
        connectTimeout: timeout,
        sendTimeout: timeout,
        receiveTimeout: timeout,
        validateStatus: (_) => true,
        responseType: ResponseType.bytes,
        headers: requestHeaders,
      );

      final permit = await _acquireConcurrentRatePermit(
        sourceKey: sourceKey,
        concurrentRate: concurrentRate,
      );
      concurrentWaitMs = permit.waitMs;
      concurrentDecision = permit.decision;
      late ({Response<List<int>> response, int retryCount}) requestResult;
      try {
        requestResult = await _requestBytesWithRetry(
          dio: _selectDio(enabledCookieJar: enabledCookieJar),
          url: finalUrl,
          options: options,
          method: method,
          body: body,
          retry: retry,
        );
      } finally {
        _releaseConcurrentRatePermit(permit.record);
      }
      final response = requestResult.response;
      final retryCount = requestResult.retryCount;
      final respHeaders = response.headers.map.map(
        (k, v) => MapEntry(k, v.join(', ')),
      );
      final bytes = Uint8List.fromList(response.data ?? const <int>[]);
      final decoded = _decodeResponseBytes(
        bytes: bytes,
        responseHeaders: respHeaders,
        optionCharset: parsedUrl.option?.charset,
      );
      sw.stop();
      return FetchDebugResult(
        requestUrl: parsedUrl.url,
        finalUrl: response.realUri.toString(),
        statusCode: response.statusCode,
        elapsedMs: sw.elapsedMilliseconds,
        method: method,
        requestBodySnippet: _snippet(body),
        responseCharset: decoded.charset,
        responseLength: decoded.text.length,
        responseSnippet: _snippet(decoded.text),
        requestHeaders: forLog,
        headersWarning: parsedHeaders.warning,
        responseHeaders: respHeaders,
        error: urlJsPatch?.error,
        retryCount: retryCount,
        methodDecision: methodDecision,
        retryDecision: retryDecision,
        requestCharsetDecision: requestCharsetDecision,
        bodyEncoding: bodyEncoding,
        bodyDecision: bodyDecision,
        responseCharsetSource: decoded.charsetSource,
        responseCharsetDecision: decoded.charsetDecision,
        concurrentWaitMs: concurrentWaitMs,
        concurrentDecision: concurrentDecision,
        body: decoded.text,
      );
    } catch (e) {
      sw.stop();
      final actualError = e is _RequestRetryFailure ? e.error : e;
      final actualRetryCount = e is _RequestRetryFailure ? e.retryCount : retry;
      if (actualError is DioException) {
        final response = actualError.response;
        String? bodyText;
        String? responseCharsetDecision;
        String? responseCharsetSource;
        String? responseCharset;
        final statusCode = response?.statusCode;
        final finalUrl = response?.realUri.toString();
        final respHeaders = response?.headers.map.map(
              (k, v) => MapEntry(k, v.join(', ')),
            ) ??
            const <String, String>{};
        if (response?.data is List<int>) {
          final decoded = _decodeResponseBytes(
            bytes: Uint8List.fromList(response?.data ?? const <int>[]),
            responseHeaders: respHeaders,
            optionCharset: parsedUrl.option?.charset,
          );
          bodyText = decoded.text;
          responseCharset = decoded.charset;
          responseCharsetSource = decoded.charsetSource;
          responseCharsetDecision = decoded.charsetDecision;
        } else {
          bodyText = response?.data?.toString();
        }
        final parts = <String>[
          'DioException(${actualError.type})',
          if (parsedHeaders.warning != null)
            'header警告=${parsedHeaders.warning}',
          if (retry > 0) 'retry=$retry',
          if (actualError.message != null &&
              actualError.message!.trim().isNotEmpty)
            actualError.message!.trim(),
          if (actualError.error != null) 'error=${actualError.error}',
        ];
        return FetchDebugResult(
          requestUrl: parsedUrl.url,
          finalUrl: finalUrl,
          statusCode: statusCode,
          elapsedMs: sw.elapsedMilliseconds,
          method: method,
          requestBodySnippet: _snippet(body),
          responseCharset: responseCharset,
          responseLength: bodyText?.length ?? 0,
          responseSnippet: _snippet(bodyText),
          requestHeaders: forLog,
          headersWarning: parsedHeaders.warning,
          responseHeaders: respHeaders,
          error: parts.join('：'),
          retryCount: actualRetryCount,
          methodDecision: methodDecision,
          retryDecision: retryDecision,
          requestCharsetDecision: requestCharsetDecision,
          bodyEncoding: bodyEncoding,
          bodyDecision: bodyDecision,
          responseCharsetSource: responseCharsetSource,
          responseCharsetDecision: responseCharsetDecision,
          concurrentWaitMs: concurrentWaitMs,
          concurrentDecision: concurrentDecision,
          body: bodyText,
        );
      }
      return FetchDebugResult(
        requestUrl: parsedUrl.url,
        finalUrl: null,
        statusCode: null,
        elapsedMs: sw.elapsedMilliseconds,
        method: method,
        requestBodySnippet: _snippet(body),
        responseCharset: null,
        responseLength: 0,
        responseSnippet: null,
        requestHeaders: forLog,
        headersWarning: parsedHeaders.warning,
        responseHeaders: const <String, String>{},
        error: actualError.toString(),
        retryCount: actualRetryCount,
        methodDecision: methodDecision,
        retryDecision: retryDecision,
        requestCharsetDecision: requestCharsetDecision,
        bodyEncoding: bodyEncoding,
        bodyDecision: bodyDecision,
        responseCharsetSource: null,
        responseCharsetDecision: null,
        concurrentWaitMs: concurrentWaitMs,
        concurrentDecision: concurrentDecision,
        body: null,
      );
    }
  }

  String? _snippet(String? text) {
    if (text == null) return null;
    final t = text.replaceAll('\r\n', '\n');
    final max = 1200;
    if (t.length <= max) return t;
    return t.substring(0, max);
  }

  /// 构建URL
  String _buildUrl(
    String baseUrl,
    String rule,
    Map<String, String> params, {
    String? jsLib,
  }) {
    var resolvedRule = _replaceGetTokens(rule);
    resolvedRule = _applyUrlJsSegments(
      resolvedRule,
      baseUrl: baseUrl,
      params: params,
      jsLib: jsLib,
    );

    // 替换参数
    params.forEach((key, value) {
      final encoded = Uri.encodeComponent(value);
      resolvedRule = resolvedRule.replaceAll('{{$key}}', encoded);
      resolvedRule = resolvedRule.replaceAll('{$key}', encoded);
    });

    resolvedRule = _applyTemplateJsTokens(
      resolvedRule,
      baseUrl: baseUrl,
      jsLib: jsLib,
    );

    final optionSplitIndex = _findLegadoUrlOptionSplitIndex(resolvedRule);
    if (optionSplitIndex <= 0) {
      return _absoluteUrl(baseUrl, resolvedRule);
    }

    final urlPart = resolvedRule.substring(0, optionSplitIndex).trim();
    final optionPart = resolvedRule.substring(optionSplitIndex + 1).trim();
    if (optionPart.isEmpty) {
      return _absoluteUrl(baseUrl, urlPart);
    }

    return '${_absoluteUrl(baseUrl, urlPart)},$optionPart';
  }

  @visibleForTesting
  String debugBuildUrlForTest(
    String baseUrl,
    String rule,
    Map<String, String> params, {
    String? jsLib,
  }) {
    return _buildUrl(baseUrl, rule, params, jsLib: jsLib);
  }

  @visibleForTesting
  ({
    String url,
    String? method,
    String? body,
    int retry,
    Map<String, String> headers,
    String methodDecision,
    String retryDecision,
    String requestCharsetDecision,
    String bodyEncoding,
    String bodyDecision,
  }) debugResolveRequestForTest(
    String baseUrl,
    String urlRule,
    Map<String, String> params, {
    String? header,
    String? jsLib,
    Map<String, String>? sourceLoginHeaders,
  }) {
    final builtUrl = _buildUrl(baseUrl, urlRule, params, jsLib: jsLib);
    final parsedHeaders = _parseRequestHeaders(header, jsLib: jsLib);
    final parsedUrl = _parseLegadoStyleUrl(builtUrl);

    final mergedCustomHeaders = <String, String>{}
      ..addAll(parsedHeaders.headers)
      ..addAll(sourceLoginHeaders ?? const <String, String>{})
      ..addAll(parsedUrl.option?.headers ?? const <String, String>{});

    var finalUrl = parsedUrl.url;
    if (parsedUrl.option?.js != null &&
        parsedUrl.option!.js!.trim().isNotEmpty) {
      final patched = _applyLegadoUrlOptionJs(
        js: parsedUrl.option!.js!.trim(),
        url: finalUrl,
        headerMap: mergedCustomHeaders,
      );
      if (patched != null) {
        finalUrl = patched.url;
        mergedCustomHeaders
          ..clear()
          ..addAll(patched.headers);
      }
    }

    _applyPreferredOriginHeaders(mergedCustomHeaders, parsedUrl.option?.origin);

    final requestHeaders = _buildEffectiveRequestHeaders(
      finalUrl,
      customHeaders: mergedCustomHeaders,
    );
    final normalized = _normalizeRequestPayload(
      finalUrl,
      parsedUrl.option,
      requestHeaders,
    );

    return (
      url: normalized.url,
      method: normalized.method,
      body: normalized.body,
      retry: normalized.retry,
      headers: requestHeaders,
      methodDecision: normalized.methodDecision,
      retryDecision: normalized.retryDecision,
      requestCharsetDecision: normalized.requestCharsetDecision,
      bodyEncoding: normalized.bodyEncoding,
      bodyDecision: normalized.bodyDecision,
    );
  }

  /// 转换为绝对URL
  String _absoluteUrl(String baseUrl, String url) {
    if (url.isEmpty) return '';
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return url;
    }
    if (url.startsWith('//')) {
      return 'https:$url';
    }
    try {
      final base = Uri.parse(baseUrl);
      return base.resolve(url).toString();
    } catch (_) {
      if (url.startsWith('/')) {
        final uri = Uri.tryParse(baseUrl);
        if (uri != null && uri.scheme.isNotEmpty && uri.host.isNotEmpty) {
          return '${uri.scheme}://${uri.host}$url';
        }
      }
      final trimmedBase = baseUrl.endsWith('/')
          ? baseUrl.substring(0, baseUrl.length - 1)
          : baseUrl;
      final trimmedUrl = url.startsWith('/') ? url.substring(1) : url;
      return '$trimmedBase/$trimmedUrl';
    }
  }

  bool _looksLikeXPath(String rule) {
    final t = rule.trimLeft();
    return t.startsWith('@XPath:') || t.startsWith('//');
  }

  bool _looksLikeJsonPath(String rule) {
    final t = rule.trimLeft();
    return t.startsWith('@Json:') ||
        t == r'$' ||
        t.startsWith(r'$.') ||
        t.startsWith(r'$[') ||
        t.startsWith(r'$..');
  }

  bool _looksLikeRegexRule(String rule) {
    final t = rule.trimLeft();
    return t.startsWith(':');
  }

  ({String expr, List<_LegadoReplacePair> replacements})
      _splitExprAndReplacements(
    String raw,
  ) {
    final parts = raw.split('##');
    final expr = parts.first.trim();
    final reps = <_LegadoReplacePair>[];
    if (parts.length > 1) {
      final rep = parts.sublist(1);
      for (var i = 0; i < rep.length; i += 2) {
        final pattern = rep[i].trim();
        final replacement = (i + 1) < rep.length ? rep[i + 1] : '';
        if (pattern.isEmpty) continue;
        reps.add(
            _LegadoReplacePair(pattern: pattern, replacement: replacement));
      }
    }
    return (expr: expr, replacements: reps);
  }

  String _parseXPathRule(Element element, String raw, String baseUrl) {
    final split = _splitExprAndReplacements(raw);
    var expr = split.expr;
    if (expr.startsWith('@XPath:')) {
      expr = expr.substring('@XPath:'.length).trim();
    }
    if (expr.isEmpty) return '';

    try {
      final result = HtmlXPath.node(element).query(expr);
      var text =
          result.attr ?? (result.node?.text ?? (result.node?.toString() ?? ''));
      text = _applyInlineReplacements(text, split.replacements);
      return text.trim();
    } catch (e) {
      debugPrint('XPath 解析失败: $expr - $e');
      return '';
    }
  }

  String _parseJsonPathRule(dynamic json, String raw) {
    final split = _splitExprAndReplacements(raw);
    var expr = split.expr;
    if (expr.startsWith('@Json:')) {
      expr = expr.substring('@Json:'.length).trim();
    }
    if (expr.isEmpty) return '';

    dynamic value;
    try {
      final matches = JsonPath(expr).read(json).toList(growable: false);
      if (matches.isEmpty) return '';
      value = matches.first.value;
    } catch (e) {
      // 兼容少量源写法：直接给 key（不带 $.）
      if (json is Map && json.containsKey(expr)) {
        value = json[expr];
      } else {
        debugPrint('JsonPath 解析失败: $expr - $e');
        return '';
      }
    }

    String text;
    if (value == null) {
      text = '';
    } else if (value is String) {
      text = value;
    } else if (value is num || value is bool) {
      text = value.toString();
    } else {
      try {
        text = jsonEncode(value);
      } catch (_) {
        text = value.toString();
      }
    }
    text = _applyInlineReplacements(text, split.replacements);
    return text.trim();
  }

  dynamic _tryDecodeJsonValue(String text) {
    final t = text.trim();
    if (t.isEmpty) return null;
    try {
      return jsonDecode(t);
    } catch (_) {
      return null;
    }
  }

  String _parseValueOnNode(dynamic node, String? rule, String baseUrl) {
    if (rule == null || rule.trim().isEmpty) return '';
    final extracted = _extractPutRules(rule);
    var currentRule = extracted.cleanedRule;
    if (currentRule.isEmpty) return '';

    _applyPutRules(
      extracted.putMap,
      node: node,
      baseUrl: baseUrl,
    );

    if (node is Element) {
      return _parseRule(node, currentRule, baseUrl);
    }

    final split = _splitRuleByTopLevelOperator(currentRule, const ['&&', '||']);
    if (split.parts.isEmpty) return '';

    final values = <String>[];
    for (final r in split.parts) {
      final rawOne = r.trim();
      if (rawOne.isEmpty) continue;

      var one = _replaceGetTokens(rawOne);
      one = _applyTemplateJsTokens(
        one,
        baseUrl: baseUrl,
      ).trim();
      if (one.isEmpty) continue;

      if (_isLiteralRuleCandidate(rawOne)) {
        values.add(one);
        if (split.operator == '||') break;
        continue;
      }

      if (_looksLikeJsonPath(one)) {
        final v = _parseJsonPathRule(node, one);
        if (v.isNotEmpty) {
          values.add(v);
          if (split.operator == '||') break;
        }
      } else if (node is Map && node.containsKey(one)) {
        final v = node[one];
        if (v == null) continue;
        final s = v.toString().trim();
        if (s.isNotEmpty) {
          values.add(s);
          if (split.operator == '||') break;
        }
      }
    }

    return _mergeRuleTextResults(values, split.operator);
  }

  List<dynamic> _selectJsonList(dynamic json, String rawRule) {
    final split = _splitExprAndReplacements(rawRule);
    var expr = split.expr.trim();
    if (expr.startsWith('@Json:')) {
      expr = expr.substring('@Json:'.length).trim();
    }
    if (expr.isEmpty) return const <dynamic>[];

    try {
      final matches = JsonPath(expr).read(json).toList(growable: false);
      if (matches.isEmpty) return const <dynamic>[];
      // 如果命中的是数组节点，优先展开成 item 列表
      final first = matches.first.value;
      if (first is List) return first;
      // 否则返回每个 match 的 value
      return matches.map((m) => m.value).toList(growable: false);
    } catch (e) {
      debugPrint('JsonPath 列表解析失败: $expr - $e');
      return const <dynamic>[];
    }
  }

  String _parseRegexRuleOnText(String text, String raw) {
    final split = _splitExprAndReplacements(raw);
    var expr = split.expr.trimLeft();
    if (!expr.startsWith(':')) return '';
    expr = expr.substring(1).trim();
    if (expr.isEmpty) return '';

    try {
      final re = RegExp(expr, dotAll: true, multiLine: true);
      final m = re.firstMatch(text);
      if (m == null) return '';
      final v = (m.groupCount >= 1 ? m.group(1) : m.group(0)) ?? '';
      final out = _applyInlineReplacements(v, split.replacements);
      return out.trim();
    } catch (e) {
      debugPrint('Regex 解析失败: $expr - $e');
      return '';
    }
  }

  /// 解析规则
  String _parseRule(Element element, String? rule, String baseUrl) {
    if (rule == null || rule.isEmpty) return '';

    final extracted = _extractPutRules(rule);
    var currentRule = extracted.cleanedRule;
    if (currentRule.isEmpty) return '';

    _applyPutRules(
      extracted.putMap,
      node: element,
      baseUrl: baseUrl,
    );
    final split = _splitRuleByTopLevelOperator(currentRule, const ['&&', '||']);
    if (split.parts.isEmpty) return '';

    final results = <String>[];
    for (final r in split.parts) {
      final rawOne = r.trim();
      if (rawOne.isEmpty) continue;

      var trimmed = _replaceGetTokens(rawOne);
      trimmed = _applyTemplateJsTokens(
        trimmed,
        baseUrl: baseUrl,
      ).trim();
      if (trimmed.isEmpty) continue;

      String result = '';
      if (_isLiteralRuleCandidate(rawOne)) {
        result = trimmed;
      } else if (_looksLikeXPath(trimmed)) {
        result = _parseXPathRule(element, trimmed, baseUrl);
      } else if (_looksLikeRegexRule(trimmed)) {
        result = _parseRegexRuleOnText(element.outerHtml, trimmed);
      } else {
        result = _parseSingleRule(element, trimmed, baseUrl);
      }
      if (result.isNotEmpty) {
        results.add(result);
        if (split.operator == '||') break;
      }
    }

    return _mergeRuleTextResults(results, split.operator);
  }

  static const Set<String> _specialExtractors = {
    'text',
    'textnodes',
    'owntext',
    'html',
    'innerhtml',
    'outerhtml',
  };

  static const Set<String> _commonAttrExtractors = {
    'href',
    'src',
    'title',
    'alt',
    'value',
    'content',
    'data-src',
    'data-original',
    'data-url',
  };

  bool _looksLikeCssSelector(String token) {
    // 命中常见 selector 结构（伪类/组合器/属性选择器等）
    return token.contains(RegExp(r'[ #.:\[\]\(\)>+~*,]')) ||
        token.startsWith('.') ||
        token.startsWith('#') ||
        token.startsWith('class.') ||
        token.startsWith('id.') ||
        token.startsWith('tag.') ||
        token.startsWith('css.');
  }

  bool _isExtractorToken(String token) {
    final t = token.trim();
    if (t.isEmpty) return false;
    // 像 selector 的一律不当 extractor（例如 li:not(...)）
    if (_looksLikeCssSelector(t)) return false;
    final lower = t.toLowerCase();
    if (_specialExtractors.contains(lower)) return true;
    if (_commonAttrExtractors.contains(lower)) return true;
    if (lower.startsWith('data-') || lower.startsWith('aria-')) return true;
    // 自定义属性一般会带连接符/下划线/命名空间（尽量别把 img/a/p 这类 tag 误判为属性）
    if (t.contains('-') || t.contains('_') || t.contains(':')) return true;
    return false;
  }

  /// 解析单个规则（对标 Legado 规则链：selector@selector@index@attr@text + ##replace）
  String _parseSingleRule(Element element, String rule, String baseUrl) {
    if (rule.isEmpty) return '';

    final parsed = _LegadoTextRule.parse(
      rule,
      isExtractor: _isExtractorToken,
    );

    final target = parsed.selectors.isEmpty
        ? element
        : _selectFirstBySelectors(element, parsed.selectors);
    if (target == null) return '';

    var result = _extractWithFallbacks(
      target,
      parsed.extractors,
      baseUrl: baseUrl,
    );
    result = _applyInlineReplacements(result, parsed.replacements);
    return result.trim();
  }

  Element? _selectFirstBySelectors(
    dynamic parent,
    List<_LegadoSelectorStep> steps,
  ) {
    final all = _selectAllBySelectors(parent, steps);
    return all.isEmpty ? null : all.first;
  }

  List<Element> _selectAllBySelectors(
    dynamic parent,
    List<_LegadoSelectorStep> steps,
  ) {
    List<dynamic> contexts = <dynamic>[parent];

    for (final step in steps) {
      final css = step.cssSelector.trim();
      if (css.isEmpty) continue;

      final matched = <Element>[];
      for (final ctx in contexts) {
        matched.addAll(_queryAllElements(ctx, css));
      }

      final idx = step.index;
      if (idx != null) {
        if (matched.isEmpty) return const <Element>[];
        var effective = idx >= 0 ? idx : matched.length + idx;
        if (effective < 0 || effective >= matched.length) {
          return const <Element>[];
        }
        contexts = <dynamic>[matched[effective]];
      } else {
        contexts = matched;
      }
    }

    return contexts.whereType<Element>().toList(growable: false);
  }

  List<Element> _queryAllElements(dynamic ctx, String css) {
    if (css.trim().isEmpty) return const <Element>[];
    try {
      // `package:html` 的 querySelector 对 `:nth-child/:nth-of-type` 等伪类支持不完整：
      // - nth-of-type 直接抛 UnimplementedError
      // - nth-child 常见返回空（不报错）
      // 为对标 legado 的书源兼容性，这里对包含 nth 的选择器走兼容实现。
      if (_containsNthPseudo(css)) {
        return _querySelectorAllCompat(ctx, css);
      }
      if (ctx is Document) return ctx.querySelectorAll(css);
      if (ctx is Element) return ctx.querySelectorAll(css);
    } catch (e) {
      debugPrint('选择器解析失败: $css - $e');
    }
    return const <Element>[];
  }

  @visibleForTesting
  List<Element> debugQueryAllElements(dynamic ctx, String css) {
    return _queryAllElements(ctx, css);
  }

  @visibleForTesting
  String debugParseRule(dynamic ctx, String rule, String baseUrl) {
    final root = ctx is Document ? ctx.documentElement : ctx;
    if (root is! Element) return '';
    return _parseRule(root, rule, baseUrl);
  }

  @visibleForTesting
  List<String> debugParseStringListFromHtml(
    dynamic ctx,
    String rule,
    String baseUrl,
    bool isUrl,
  ) {
    final root = ctx is Document ? ctx.documentElement : ctx;
    if (root is! Element) return const <String>[];
    return _parseStringListFromHtml(
      root: root,
      rule: rule,
      baseUrl: baseUrl,
      isUrl: isUrl,
    );
  }

  @visibleForTesting
  List<String> debugParseStringListFromJson(
    dynamic json,
    String rule,
    String baseUrl,
    bool isUrl,
  ) {
    return _parseStringListFromJson(
      json: json,
      rule: rule,
      baseUrl: baseUrl,
      isUrl: isUrl,
    );
  }

  @visibleForTesting
  void debugClearRuntimeVariables() {
    _clearRuntimeVariables();
  }

  @visibleForTesting
  void debugPutRuntimeVariable(String key, String value) {
    _putRuntimeVariable(key, value);
  }

  @visibleForTesting
  String debugGetRuntimeVariable(String key) {
    return _getRuntimeVariable(key);
  }

  Map<String, String> debugRuntimeVariablesSnapshot({
    bool desensitize = true,
  }) {
    return _runtimeVariableSnapshot(desensitize: desensitize);
  }

  @visibleForTesting
  String? debugPickNextUrlCandidateForTest(
    List<String> candidates, {
    required String currentUrl,
    required Set<String> visitedUrls,
    String? blockedUrl,
  }) {
    final visitedKeys = <String>{
      for (final item in visitedUrls) _normalizeUrlVisitKey(item),
    }..removeWhere((e) => e.isEmpty);
    final blockedKey = (blockedUrl == null || blockedUrl.trim().isEmpty)
        ? null
        : _normalizeUrlVisitKey(blockedUrl);
    return _pickNextUrlCandidate(
      candidates,
      currentUrl: currentUrl,
      visitedUrlKeys: visitedKeys,
      blockedUrlKey: blockedKey,
    );
  }

  @visibleForTesting
  ({List<String> urls, List<String> debugLines, bool hasBlockedCandidate})
      debugCollectNextUrlCandidatesWithDebugForTest(
    List<String> candidates, {
    required String currentUrl,
    required Set<String> visitedUrls,
    Set<String>? queuedUrls,
    String? blockedUrl,
  }) {
    final visitedKeys = <String>{
      for (final item in visitedUrls) _normalizeUrlVisitKey(item),
    }..removeWhere((e) => e.isEmpty);
    Set<String>? queuedKeys;
    if (queuedUrls != null) {
      queuedKeys = <String>{
        for (final item in queuedUrls) _normalizeUrlVisitKey(item),
      }..removeWhere((e) => e.isEmpty);
    }
    final blockedKey = (blockedUrl == null || blockedUrl.trim().isEmpty)
        ? null
        : _normalizeUrlVisitKey(blockedUrl);

    return _collectNextUrlCandidatesWithDebug(
      candidates,
      currentUrl: currentUrl,
      visitedUrlKeys: visitedKeys,
      queuedUrlKeys: queuedKeys,
      blockedUrlKey: blockedKey,
    );
  }

  bool _containsNthPseudo(String css) {
    final t = css.toLowerCase();
    return t.contains(':nth-child(') ||
        t.contains(':nth-last-child(') ||
        t.contains(':nth-of-type(') ||
        t.contains(':nth-last-of-type(');
  }

  List<String> _splitSelectorGroups(String selector) {
    // 按顶层逗号拆分：`a, b > c` => [a, b > c]
    final out = <String>[];
    final buf = StringBuffer();
    var bracket = 0;
    var paren = 0;
    String? quote;

    void flush() {
      final s = buf.toString().trim();
      buf.clear();
      if (s.isNotEmpty) out.add(s);
    }

    for (var i = 0; i < selector.length; i++) {
      final ch = selector[i];
      if (quote != null) {
        buf.write(ch);
        if (ch == quote) quote = null;
        continue;
      }
      if (ch == '"' || ch == "'") {
        quote = ch;
        buf.write(ch);
        continue;
      }
      if (ch == '[') bracket++;
      if (ch == ']') bracket = bracket > 0 ? (bracket - 1) : 0;
      if (ch == '(') paren++;
      if (ch == ')') paren = paren > 0 ? (paren - 1) : 0;

      if (ch == ',' && bracket == 0 && paren == 0) {
        flush();
        continue;
      }
      buf.write(ch);
    }
    flush();
    return out;
  }

  _NthExpr? _parseNthExpr(String raw) {
    final t = raw.trim().toLowerCase().replaceAll(' ', '');
    if (t.isEmpty) return null;
    if (t == 'odd') return const _NthExpr(a: 2, b: 1);
    if (t == 'even') return const _NthExpr(a: 2, b: 0);

    if (!t.contains('n')) {
      final v = int.tryParse(t);
      return v == null ? null : _NthExpr(a: 0, b: v);
    }

    final parts = t.split('n');
    final aPart = parts.isNotEmpty ? parts.first : '';
    final bPart = parts.length >= 2 ? parts[1] : '';

    int a;
    if (aPart.isEmpty || aPart == '+') {
      a = 1;
    } else if (aPart == '-') {
      a = -1;
    } else {
      a = int.tryParse(aPart) ?? 0;
    }

    int b = 0;
    if (bPart.isNotEmpty) {
      b = int.tryParse(bPart) ?? 0;
    }

    return _NthExpr(a: a, b: b);
  }

  bool _matchesNth(_NthExpr expr, int position1Based) {
    final a = expr.a;
    final b = expr.b;
    final p = position1Based;
    if (p <= 0) return false;

    if (a == 0) return p == b;

    // 存在 n>=0 使 p = a*n + b
    if (a > 0) {
      final diff = p - b;
      if (diff < 0) return false;
      return diff % a == 0;
    } else {
      final diff = b - p;
      if (diff < 0) return false;
      return diff % (-a) == 0;
    }
  }

  List<_SelectorStepCompat> _tokenizeSelectorChain(String selector) {
    // 仅实现 legado 常见链式：后代（空格）/子代（>）/兄弟（+、~）
    final steps = <_SelectorStepCompat>[];
    final buf = StringBuffer();

    var bracket = 0;
    var paren = 0;
    String? quote;

    void pushStep(String combinator) {
      final raw = buf.toString().trim();
      buf.clear();
      if (raw.isEmpty) return;
      final extracted = _extractNthFilters(raw);
      steps.add(
        _SelectorStepCompat(
          combinator: combinator,
          selector: extracted.baseSelector,
          nthFilters: extracted.filters,
        ),
      );
    }

    String pendingCombinator = '';

    for (var i = 0; i < selector.length; i++) {
      final ch = selector[i];
      if (quote != null) {
        buf.write(ch);
        if (ch == quote) quote = null;
        continue;
      }
      if (ch == '"' || ch == "'") {
        quote = ch;
        buf.write(ch);
        continue;
      }
      if (ch == '[') bracket++;
      if (ch == ']') bracket = bracket > 0 ? (bracket - 1) : 0;
      if (ch == '(') paren++;
      if (ch == ')') paren = paren > 0 ? (paren - 1) : 0;

      final isTopLevel = bracket == 0 && paren == 0;
      if (isTopLevel && (ch == '>' || ch == '+' || ch == '~')) {
        pushStep(pendingCombinator);
        pendingCombinator = ch;
        continue;
      }

      if (isTopLevel && ch.trim().isEmpty) {
        // 多个空白 => 一个后代 combinator
        if (buf.isNotEmpty) {
          pushStep(pendingCombinator);
          pendingCombinator = ' ';
        } else {
          pendingCombinator =
              pendingCombinator.isEmpty ? ' ' : pendingCombinator;
        }
        continue;
      }

      buf.write(ch);
    }
    pushStep(pendingCombinator);

    // 规范：第一个 step combinator 置空（不管前面怎么解析的）
    if (steps.isNotEmpty) {
      final first = steps.first;
      steps[0] = _SelectorStepCompat(
        combinator: '',
        selector: first.selector,
        nthFilters: first.nthFilters,
      );
    }
    return steps;
  }

  _NthExtractResult _extractNthFilters(String rawSelectorPart) {
    var s = rawSelectorPart;
    final filters = <_NthFilter>[];

    // 只处理最常用的四种；避免误伤其它伪类（例如 :not(...)）
    final kinds = <String>[
      'nth-child',
      'nth-last-child',
      'nth-of-type',
      'nth-last-of-type',
    ];

    // 简单扫描：找 `:kind(...)` 并剥离
    // 注意：这里不解析嵌套 :not(:nth-...) 的复杂情况（少见），保持实现可控。
    for (final kind in kinds) {
      while (true) {
        final lower = s.toLowerCase();
        final idx = lower.indexOf(':$kind(');
        if (idx < 0) break;

        // 找到对应的 ')'
        var start = idx + kind.length + 2; // : + kind + (
        var depth = 1;
        var end = -1;
        for (var i = start; i < s.length; i++) {
          final ch = s[i];
          if (ch == '(') depth++;
          if (ch == ')') depth--;
          if (depth == 0) {
            end = i;
            break;
          }
        }
        if (end < 0) break;
        final exprText = s.substring(start, end);
        final expr = _parseNthExpr(exprText);
        if (expr != null) {
          filters.add(_NthFilter(kind: kind, expr: expr));
        }
        s = (s.substring(0, idx) + s.substring(end + 1)).trim();
      }
    }

    if (s.trim().isEmpty) s = '*';
    return _NthExtractResult(baseSelector: s.trim(), filters: filters);
  }

  List<Element> _querySelectorAllCompat(dynamic ctx, String selector) {
    final groups = _splitSelectorGroups(selector);
    if (groups.isEmpty) return const <Element>[];

    final out = <Element>[];
    final seen = <Element>{};
    for (final g in groups) {
      final one = _querySelectorAllCompatSingle(ctx, g);
      for (final el in one) {
        if (seen.add(el)) out.add(el);
      }
    }
    return out;
  }

  List<Element> _querySelectorAllCompatSingle(dynamic ctx, String selector) {
    final chain = _tokenizeSelectorChain(selector);
    if (chain.isEmpty) return const <Element>[];

    List<Element> contexts;
    if (ctx is Document) {
      final root = ctx.documentElement;
      contexts = root == null ? const <Element>[] : <Element>[root];
    } else if (ctx is Element) {
      contexts = <Element>[ctx];
    } else {
      return const <Element>[];
    }

    List<Element> queryDescendants(Element root, String css) {
      try {
        return root.querySelectorAll(css);
      } catch (e) {
        debugPrint('选择器解析失败(compat): $css - $e');
        return const <Element>[];
      }
    }

    List<Element> applyNthFilters(
        List<Element> elements, List<_NthFilter> filters) {
      if (filters.isEmpty || elements.isEmpty) return elements;
      return elements.where((el) {
        final parent = el.parent;
        if (parent is! Element) return false;
        final siblings = parent.children;
        final idx = siblings.indexOf(el);
        if (idx < 0) return false;

        for (final f in filters) {
          int pos;
          if (f.kind == 'nth-child') {
            pos = idx + 1;
          } else if (f.kind == 'nth-last-child') {
            pos = siblings.length - idx;
          } else if (f.kind == 'nth-of-type' || f.kind == 'nth-last-of-type') {
            final tag = (el.localName ?? '').toLowerCase();
            final sameType = siblings
                .where((e) => (e.localName ?? '').toLowerCase() == tag)
                .toList(growable: false);
            final typeIdx = sameType.indexOf(el);
            if (typeIdx < 0) return false;
            pos = f.kind == 'nth-of-type'
                ? (typeIdx + 1)
                : (sameType.length - typeIdx);
          } else {
            continue;
          }

          if (!_matchesNth(f.expr, pos)) return false;
        }
        return true;
      }).toList(growable: false);
    }

    for (final step in chain) {
      final combinator = step.combinator.isEmpty ? ' ' : step.combinator;
      final css = step.selector.trim();
      if (css.isEmpty) return const <Element>[];

      final matched = <Element>[];
      if (combinator == ' ') {
        for (final c in contexts) {
          matched.addAll(queryDescendants(c, css));
        }
      } else if (combinator == '>') {
        for (final c in contexts) {
          final all = queryDescendants(c, css);
          matched.addAll(all.where((e) => e.parent == c));
        }
      } else if (combinator == '+') {
        for (final c in contexts) {
          final parent = c.parent;
          if (parent is! Element) continue;
          final siblings = parent.children;
          final idx = siblings.indexOf(c);
          if (idx < 0 || idx + 1 >= siblings.length) continue;
          final cand = siblings[idx + 1];
          // 通过“父节点内筛选”判断是否命中 selector（避免依赖 Element.matches）
          final allowed = queryDescendants(parent, css).toSet();
          if (allowed.contains(cand)) matched.add(cand);
        }
      } else if (combinator == '~') {
        for (final c in contexts) {
          final parent = c.parent;
          if (parent is! Element) continue;
          final siblings = parent.children;
          final idx = siblings.indexOf(c);
          if (idx < 0) continue;
          final allowed = queryDescendants(parent, css).toSet();
          for (var i = idx + 1; i < siblings.length; i++) {
            final cand = siblings[i];
            if (allowed.contains(cand)) matched.add(cand);
          }
        }
      } else {
        // 未知 combinator：退化为后代选择（尽量不让解析直接挂掉）
        for (final c in contexts) {
          matched.addAll(queryDescendants(c, css));
        }
      }

      contexts = applyNthFilters(matched, step.nthFilters);
      if (contexts.isEmpty) return const <Element>[];
    }

    return contexts;
  }

  List<Element> _selectAllElementsByRule(
    dynamic parent,
    String selectorRule, {
    String? rawHtml,
  }) {
    final raw = selectorRule.trim();
    if (raw.isEmpty) return const <Element>[];

    if (_looksLikeXPath(raw)) {
      final split = _splitExprAndReplacements(raw);
      var expr = split.expr;
      if (expr.startsWith('@XPath:')) {
        expr = expr.substring('@XPath:'.length).trim();
      }
      if (expr.isEmpty) return const <Element>[];
      try {
        final root = parent is Document
            ? parent.documentElement
            : parent is Element
                ? parent
                : null;
        if (root == null) return const <Element>[];
        final result = HtmlXPath.node(root).query(expr);
        return result.nodes
            .where((n) => n.isElement)
            .map((n) => (n as HtmlNodeTree).element)
            .toList(growable: false);
      } catch (e) {
        debugPrint('XPath 列表解析失败: $expr - $e');
        return const <Element>[];
      }
    }

    if (_looksLikeRegexRule(raw)) {
      final split = _splitExprAndReplacements(raw);
      var expr = split.expr.trimLeft();
      expr = expr.startsWith(':') ? expr.substring(1).trim() : expr;
      if (expr.isEmpty) return const <Element>[];

      final htmlText = rawHtml ??
          (parent is Document
              ? parent.documentElement?.outerHtml
              : parent is Element
                  ? parent.outerHtml
                  : null) ??
          '';
      if (htmlText.isEmpty) return const <Element>[];

      try {
        final re = RegExp(expr, dotAll: true, multiLine: true);
        final out = <Element>[];
        for (final m in re.allMatches(htmlText)) {
          final snippet = (m.groupCount >= 1 ? m.group(1) : m.group(0)) ?? '';
          if (snippet.trim().isEmpty) continue;
          final wrapper = html_parser
              .parse('<div>$snippet</div>')
              .documentElement
              ?.querySelector('div');
          if (wrapper != null) out.add(wrapper);
        }
        return out;
      } catch (e) {
        debugPrint('Regex 列表解析失败: $expr - $e');
        return const <Element>[];
      }
    }

    final parsed = _LegadoTextRule.parse(
      raw,
      isExtractor: _isExtractorToken,
    );
    return _selectAllBySelectors(parent, parsed.selectors);
  }

  Element? _selectFirstElementByRule(dynamic parent, String selectorRule) {
    final all = _selectAllElementsByRule(parent, selectorRule);
    return all.isEmpty ? null : all.first;
  }

  String _extractWithFallbacks(
    Element target,
    List<String> extractors, {
    required String baseUrl,
  }) {
    for (final ex in extractors) {
      final token = ex.trim();
      if (token.isEmpty) continue;
      final lower = token.toLowerCase();

      String value;
      if (lower == 'text') {
        value = target.text;
      } else if (lower == 'textnodes' || lower == 'owntext') {
        value = target.nodes.whereType<Text>().map((t) => t.text).join('');
      } else if (lower == 'html' || lower == 'innerhtml') {
        value = target.innerHtml;
      } else if (lower == 'outerhtml') {
        value = target.outerHtml;
      } else {
        value = target.attributes[token] ??
            target.attributes[lower] ??
            target.attributes[token.toLowerCase()] ??
            '';
      }

      value = value.trim();
      if (value.isEmpty) continue;

      // 常见 URL 属性：自动转绝对链接
      if (lower == 'href' || lower == 'src') {
        value = _absoluteUrl(baseUrl, value);
      }
      return value;
    }
    return '';
  }

  String _applyInlineReplacements(
    String input,
    List<_LegadoReplacePair> replacements,
  ) {
    var result = input;
    for (final r in replacements) {
      final pattern = r.pattern;
      final replacement = r.replacement;
      if (pattern.isEmpty) continue;
      try {
        result = result.replaceAll(RegExp(pattern), replacement);
      } catch (_) {
        result = result.replaceAll(pattern, replacement);
      }
    }
    return result;
  }

  /// 应用替换正则
  String _applyReplaceRegex(String content, String replaceRegex) {
    // 源阅格式: regex##replacement##regex2##replacement2...
    final parts = replaceRegex.split('##');
    if (parts.isEmpty) return content;

    for (int i = 0; i < parts.length - 1; i += 2) {
      final pattern = parts[i];
      if (pattern.isEmpty) continue;
      final replacement = parts.length > i + 1 ? parts[i + 1] : '';

      try {
        content = content.replaceAll(RegExp(pattern), replacement);
      } catch (e) {
        // 兼容兜底：单条正则异常时按字面量替换，且不中断后续 replaceRegex 链。
        try {
          content = content.replaceAll(pattern, replacement);
        } catch (_) {
          debugPrint('替换正则失败(第${(i ~/ 2) + 1}条): $e');
        }
      }
    }

    return content;
  }

  /// 清理正文内容
  String _cleanContent(String content) {
    // 对齐 legado 的 HTML -> 文本清理策略（块级标签换行、不可见字符移除）
    return HtmlTextFormatter.formatToPlainText(content);
  }
}

class _LegadoTextRule {
  final List<_LegadoSelectorStep> selectors;
  final List<String> extractors;
  final List<_LegadoReplacePair> replacements;

  const _LegadoTextRule({
    required this.selectors,
    required this.extractors,
    required this.replacements,
  });

  static _LegadoTextRule parse(
    String raw, {
    required bool Function(String token) isExtractor,
  }) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return const _LegadoTextRule(
        selectors: <_LegadoSelectorStep>[],
        extractors: <String>['text'],
        replacements: <_LegadoReplacePair>[],
      );
    }

    final parts = trimmed.split('##');
    final pipeline = parts.first.trim();

    final replacements = <_LegadoReplacePair>[];
    if (parts.length > 1) {
      final rep = parts.sublist(1).map((e) => e).toList(growable: false);
      for (var i = 0; i < rep.length; i += 2) {
        final pattern = rep[i].trim();
        final replacement = (i + 1) < rep.length ? rep[i + 1] : '';
        if (pattern.isEmpty) continue;
        replacements.add(
          _LegadoReplacePair(pattern: pattern, replacement: replacement),
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
      // 兼容 legado 写法：@href / @textNodes 等表示“当前元素取属性/文本”
      for (final t in tokens) {
        if (isExtractor(t)) extractors.add(t);
      }
      cut = 0;
    } else if (tokens.length >= 2) {
      while (cut > 0) {
        final candidate = tokens[cut - 1];
        if (!isExtractor(candidate)) break;
        extractors.insert(0, candidate);
        cut--;
      }
    }

    final selectors = <_LegadoSelectorStep>[];
    for (final t in tokens.take(cut)) {
      final step = _LegadoSelectorStep.tryParse(t);
      if (step != null) selectors.add(step);
    }

    return _LegadoTextRule(
      selectors: selectors,
      extractors: extractors.isEmpty ? const <String>['text'] : extractors,
      replacements: replacements,
    );
  }
}

class _LegadoSelectorStep {
  final String cssSelector;
  final int? index;

  const _LegadoSelectorStep({
    required this.cssSelector,
    required this.index,
  });

  static _LegadoSelectorStep? tryParse(String token) {
    final t = token.trim();
    if (t.isEmpty) return null;

    int? index;
    var base = t;
    final lastDot = t.lastIndexOf('.');
    if (lastDot > 0 && lastDot < t.length - 1) {
      final maybeIndex = t.substring(lastDot + 1);
      final parsed = int.tryParse(maybeIndex);
      if (parsed != null) {
        index = parsed;
        base = t.substring(0, lastDot);
      }
    }

    final css = _toCssSelector(base);
    if (css.trim().isEmpty) return null;
    return _LegadoSelectorStep(cssSelector: css, index: index);
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

class _LegadoReplacePair {
  final String pattern;
  final String replacement;

  const _LegadoReplacePair({
    required this.pattern,
    required this.replacement,
  });
}

class _TopLevelRuleSplit {
  final List<String> parts;
  final String? operator;

  const _TopLevelRuleSplit({
    required this.parts,
    required this.operator,
  });
}

class _ConcurrentRateSpec {
  final String raw;
  final bool isWindowMode;
  final int? intervalMs;
  final int? maxCount;
  final int? windowMs;

  const _ConcurrentRateSpec.interval({
    required this.raw,
    required this.intervalMs,
  })  : isWindowMode = false,
        maxCount = null,
        windowMs = null;

  const _ConcurrentRateSpec.window({
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

class _ConcurrentRecord {
  final bool isWindowMode;
  int timeMs;
  int frequency;

  _ConcurrentRecord({
    required this.isWindowMode,
    required this.timeMs,
    required this.frequency,
  });
}

class _ConcurrentAcquireStep {
  final _ConcurrentRecord? record;
  final int waitMs;
  final String decision;

  const _ConcurrentAcquireStep({
    required this.record,
    required this.waitMs,
    required this.decision,
  });
}

class _ConcurrentAcquireResult {
  final _ConcurrentRecord? record;
  final int waitMs;
  final String decision;

  const _ConcurrentAcquireResult({
    required this.record,
    required this.waitMs,
    required this.decision,
  });
}

enum _DebugListMode { search, explore }

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

class FetchDebugResult {
  final String requestUrl;
  final String? finalUrl;
  final int? statusCode;
  final int elapsedMs;
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

class _LegadoUrlParsed {
  final String url;
  final _LegadoUrlOption? option;

  const _LegadoUrlParsed({
    required this.url,
    required this.option,
  });
}

class _LegadoUrlOption {
  final String? method;
  final String? body;
  final String? charset;
  final int? retry;
  final Map<String, String> headers;
  final String? origin;
  final String? js;

  const _LegadoUrlOption({
    required this.method,
    required this.body,
    required this.charset,
    required this.retry,
    required this.headers,
    required this.origin,
    required this.js,
  });

  factory _LegadoUrlOption.fromJson(Map<String, dynamic> json) {
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
      json.containsKey('headers') ? json['headers'] : json['header'],
    );

    return _LegadoUrlOption(
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

class _UrlJsPatchResult {
  final bool ok;
  final String url;
  final Map<String, String> headers;
  final String? error;

  const _UrlJsPatchResult({
    required this.ok,
    required this.url,
    required this.headers,
    required this.error,
  });
}

class _RequestRetryFailure {
  final Object error;
  final int retryCount;

  const _RequestRetryFailure({
    required this.error,
    required this.retryCount,
  });

  @override
  String toString() =>
      '_RequestRetryFailure(retryCount=$retryCount, error=$error)';
}

class _DecodedText {
  final String text;
  final String charset;
  final String charsetSource;
  final String charsetDecision;

  const _DecodedText({
    required this.text,
    required this.charset,
    required this.charsetSource,
    required this.charsetDecision,
  });
}

class _ParsedHeaders {
  final Map<String, String> headers;
  final String? warning;

  const _ParsedHeaders({
    required this.headers,
    required this.warning,
  });

  static const empty = _ParsedHeaders(headers: {}, warning: null);

  @override
  String toString() => 'headers=$headers warning=$warning';
}

class _SelectorStepCompat {
  // '' for first, ' ' descendant, '>' child, '+' adjacent, '~' sibling
  final String combinator;
  final String selector;
  final List<_NthFilter> nthFilters;

  const _SelectorStepCompat({
    required this.combinator,
    required this.selector,
    required this.nthFilters,
  });
}

class _NthFilter {
  // nth-child / nth-last-child / nth-of-type / nth-last-of-type
  final String kind;
  final _NthExpr expr;

  const _NthFilter({required this.kind, required this.expr});
}

class _NthExpr {
  final int a;
  final int b;

  const _NthExpr({required this.a, required this.b});
}

class _NthExtractResult {
  final String baseSelector;
  final List<_NthFilter> filters;

  const _NthExtractResult({required this.baseSelector, required this.filters});
}

class _NormalizedListRule {
  final String selector;
  final bool reverse;

  const _NormalizedListRule({
    required this.selector,
    required this.reverse,
  });

  @override
  String toString() => 'selector=$selector reverse=$reverse';
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

  const TocItem({
    required this.index,
    required this.name,
    required this.url,
  });
}
