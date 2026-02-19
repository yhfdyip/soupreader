import 'dart:convert';

import '../../../core/services/js_runtime.dart';
import '../models/rss_source.dart';
import 'rss_source_filter_helper.dart';

enum RssSubscriptionOpenAction {
  openArticleList,
  openReadDetail,
  openExternal,
  showError,
}

class RssSingleUrlResolveResult {
  final String url;
  final String? errorMessage;

  const RssSingleUrlResolveResult._({
    required this.url,
    this.errorMessage,
  });

  const RssSingleUrlResolveResult.success(String url)
      : this._(url: url, errorMessage: null);

  const RssSingleUrlResolveResult.error(String message)
      : this._(url: '', errorMessage: message);

  bool get success => errorMessage == null && url.trim().isNotEmpty;
}

class RssSubscriptionOpenDecision {
  final RssSubscriptionOpenAction action;
  final String? url;
  final String? message;

  const RssSubscriptionOpenDecision({
    required this.action,
    this.url,
    this.message,
  });
}

class RssSubscriptionHelper {
  const RssSubscriptionHelper._();

  static const String groupPrefix = 'group:';
  static const String _jsOkPrefix = '__SR_RSS_JS_OK__';
  static const String _jsErrorPrefix = '__SR_RSS_JS_ERR__';

  static List<RssSource> filterEnabledSourcesByQuery(
    Iterable<RssSource> sources,
    String? query,
  ) {
    final key = (query ?? '').trim();
    if (key.isEmpty) {
      return RssSourceFilterHelper.filterEnabled(sources);
    }
    if (key.startsWith(groupPrefix)) {
      final group = key.substring(groupPrefix.length).trim();
      return RssSourceFilterHelper.filterEnabledByGroup(sources, group);
    }
    return RssSourceFilterHelper.filterEnabled(sources, searchKey: key);
  }

  static List<String> enabledGroups(Iterable<RssSource> sources) {
    return RssSourceFilterHelper.allGroupsFromSources(
      sources,
      enabledOnly: true,
    );
  }

  static String buildGroupQuery(String group) {
    return '$groupPrefix${group.trim()}';
  }

  static RssSubscriptionOpenDecision decideOpenAction(
    RssSource source, {
    JsRuntime? runtime,
  }) {
    if (!source.singleUrl) {
      final sourceUrl = source.sourceUrl.trim();
      if (sourceUrl.isEmpty) {
        return const RssSubscriptionOpenDecision(
          action: RssSubscriptionOpenAction.showError,
          message: '源地址为空，无法打开订阅',
        );
      }
      return RssSubscriptionOpenDecision(
        action: RssSubscriptionOpenAction.openArticleList,
        url: sourceUrl,
      );
    }

    final resolved = resolveSingleUrl(source, runtime: runtime);
    if (!resolved.success) {
      return RssSubscriptionOpenDecision(
        action: RssSubscriptionOpenAction.showError,
        message: resolved.errorMessage ?? 'singleUrl 解析失败',
      );
    }

    final targetUrl = resolved.url.trim();
    if (targetUrl.toLowerCase().startsWith('http')) {
      return RssSubscriptionOpenDecision(
        action: RssSubscriptionOpenAction.openReadDetail,
        url: targetUrl,
      );
    }
    return RssSubscriptionOpenDecision(
      action: RssSubscriptionOpenAction.openExternal,
      url: targetUrl,
    );
  }

  static RssSingleUrlResolveResult resolveSingleUrl(
    RssSource source, {
    JsRuntime? runtime,
  }) {
    final fallbackUrl = source.sourceUrl.trim();
    final sortUrl = (source.sortUrl ?? '').trim();
    if (sortUrl.isEmpty) {
      if (fallbackUrl.isEmpty) {
        return const RssSingleUrlResolveResult.error('源地址为空，无法打开');
      }
      return RssSingleUrlResolveResult.success(fallbackUrl);
    }

    var candidate = sortUrl;
    if (_isJsRule(sortUrl)) {
      final jsCode = _extractJsCode(sortUrl);
      if (jsCode.isNotEmpty) {
        final jsResult = _evaluateSortUrlJs(
          source: source,
          jsCode: jsCode,
          runtime: runtime ?? createJsRuntime(),
        );
        if (jsResult.hasError) {
          final error = jsResult.error?.trim();
          return RssSingleUrlResolveResult.error(
            error == null || error.isEmpty ? 'singleUrl 脚本执行失败' : error,
          );
        }
        final evaluated = jsResult.value.trim();
        if (evaluated.isNotEmpty) {
          candidate = evaluated;
        }
      }
    }

    final normalized = _normalizeSortUrlCandidate(candidate);
    if (normalized.isNotEmpty) {
      return RssSingleUrlResolveResult.success(normalized);
    }
    if (fallbackUrl.isNotEmpty) {
      return RssSingleUrlResolveResult.success(fallbackUrl);
    }
    return const RssSingleUrlResolveResult.error('singleUrl 解析后为空');
  }

  static bool _isJsRule(String text) {
    final raw = text.trim().toLowerCase();
    return raw.startsWith('@js:') || raw.startsWith('<js>');
  }

  static String _extractJsCode(String rawRule) {
    final raw = rawRule.trim();
    final lower = raw.toLowerCase();
    if (lower.startsWith('@js:')) {
      return raw.substring(4).trim();
    }
    if (!lower.startsWith('<js>')) return '';
    final closeIndex = lower.lastIndexOf('</js>');
    if (closeIndex > 4) {
      return raw.substring(4, closeIndex).trim();
    }
    final lastTag = raw.lastIndexOf('<');
    if (lastTag > 4) {
      return raw.substring(4, lastTag).trim();
    }
    return raw.substring(4).trim();
  }

  static String _normalizeSortUrlCandidate(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return '';
    if (text.contains('::')) {
      final parts = text.split('::');
      return parts.length > 1 ? parts[1].trim() : '';
    }
    return text;
  }

  static _SortUrlJsEvalResult _evaluateSortUrlJs({
    required RssSource source,
    required String jsCode,
    required JsRuntime runtime,
  }) {
    final lib = (source.jsLib ?? '').trim();
    final libScript = lib.isEmpty ? '' : '$lib\n';
    final script = '''
      (function() {
        try {
          var source = ${jsonEncode(source.toJson())};
          var java = source;
          var baseUrl = ${jsonEncode(source.sourceUrl)};
          $libScript
          var __res = eval(${jsonEncode(jsCode)});
          if (__res === undefined || __res === null) {
            return "$_jsOkPrefix";
          }
          var __text = "";
          if (typeof __res === "string") {
            __text = __res;
          } else {
            try {
              __text = JSON.stringify(__res);
            } catch (_jsonErr) {
              __text = String(__res);
            }
          }
          return "$_jsOkPrefix" + encodeURIComponent(__text);
        } catch (e) {
          var __err = "";
          try {
            __err = String(e && (e.message || e.stack || e));
          } catch (_err) {}
          return "$_jsErrorPrefix" + encodeURIComponent(__err);
        }
      })()
    ''';

    final rawOutput = runtime.evaluate(script).trim();
    if (rawOutput.isEmpty) {
      return const _SortUrlJsEvalResult(value: '');
    }
    final output = _decodeMaybeJsonString(rawOutput);
    if (output.startsWith(_jsErrorPrefix)) {
      final encoded = output.substring(_jsErrorPrefix.length);
      final message = encoded.isEmpty ? '' : Uri.decodeComponent(encoded);
      return _SortUrlJsEvalResult(value: '', error: message);
    }
    if (output.startsWith(_jsOkPrefix)) {
      final encoded = output.substring(_jsOkPrefix.length);
      final value = encoded.isEmpty ? '' : Uri.decodeComponent(encoded);
      return _SortUrlJsEvalResult(value: value);
    }
    return _SortUrlJsEvalResult(value: output);
  }

  static String _decodeMaybeJsonString(String raw) {
    final text = raw.trim();
    if (text.length >= 2 && text.startsWith('"') && text.endsWith('"')) {
      try {
        final decoded = json.decode(text);
        if (decoded is String) return decoded;
      } catch (_) {
        return text;
      }
    }
    return text;
  }
}

class _SortUrlJsEvalResult {
  final String value;
  final String? error;

  const _SortUrlJsEvalResult({
    required this.value,
    this.error,
  });

  bool get hasError => error != null;
}
