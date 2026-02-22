import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:fast_gbk/fast_gbk.dart';
import 'package:flutter/services.dart';
import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:shared_preferences/shared_preferences.dart';

import '../../source/services/rule_parser_engine.dart';
import '../models/dict_rule.dart';

class DictRuleStore {
  static const String _prefsKey = 'dict_rules';
  static const String _defaultAssetPath = 'assets/source/dictRules.json';

  static const Map<String, String> _defaultHeaders = {
    'User-Agent': 'Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) '
        'AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.0 Mobile/15E148 Safari/604.1',
    'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
    'Accept-Language': 'zh-CN,zh;q=0.9,en-US;q=0.8,en;q=0.7',
    'Upgrade-Insecure-Requests': '1',
  };

  final Dio _httpClient;
  final RuleParserEngine _ruleParserEngine;

  DictRuleStore({
    Dio? httpClient,
    RuleParserEngine? ruleParserEngine,
  })  : _httpClient = httpClient ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 15),
                receiveTimeout: const Duration(seconds: 15),
                followRedirects: true,
                maxRedirects: 8,
                headers: _defaultHeaders,
              ),
            ),
        _ruleParserEngine = ruleParserEngine ?? RuleParserEngine();

  Future<List<DictRule>> loadRules() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey)?.trim();
    if (raw != null && raw.isNotEmpty) {
      try {
        return DictRule.listFromJsonText(raw);
      } catch (_) {
        // 配置损坏时自动回退到默认资产，避免阻塞 menu_dict 主链路。
      }
    }
    return _loadDefaultRulesFromAsset();
  }

  Future<void> saveRules(List<DictRule> rules) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, DictRule.listToJsonText(rules));
  }

  Future<List<DictRule>> loadEnabledRules() async {
    final rules = await loadRules();
    final enabled = rules.where((rule) => rule.enabled).toList(growable: false)
      ..sort((a, b) => a.sortNumber.compareTo(b.sortNumber));
    return enabled;
  }

  Future<String> search({
    required DictRule rule,
    required String word,
  }) async {
    final normalizedWord = word.trim();
    if (normalizedWord.isEmpty) return '';

    final url = _buildSearchUrl(rule.urlRule, normalizedWord);
    if (url.isEmpty) return '';

    final response = await _httpClient.get<List<int>>(
      url,
      options: Options(responseType: ResponseType.bytes),
    );

    final bytes = Uint8List.fromList(response.data ?? const <int>[]);
    final body = _decodeResponseBytes(bytes, response.headers);
    final baseUrl = (response.realUri?.toString() ?? url).trim();
    return _applyShowRule(
      showRule: rule.showRule,
      body: body,
      baseUrl: baseUrl.isEmpty ? url : baseUrl,
    );
  }

  Future<List<DictRule>> _loadDefaultRulesFromAsset() async {
    try {
      final raw = await rootBundle.loadString(_defaultAssetPath);
      return DictRule.listFromJsonText(raw);
    } catch (_) {
      return const <DictRule>[];
    }
  }

  String _buildSearchUrl(String urlRule, String word) {
    final normalizedRule = urlRule.trim();
    if (normalizedRule.isEmpty) return '';
    final encodedWord = Uri.encodeComponent(word);
    return normalizedRule
        .replaceAll('{{key}}', encodedWord)
        .replaceAll('{key}', encodedWord);
  }

  String _applyShowRule({
    required String showRule,
    required String body,
    required String baseUrl,
  }) {
    final ruleText = showRule.trim();
    if (ruleText.isEmpty) return body;

    if (_looksLikeJsoupScript(ruleText)) {
      return _applyJsoupLikeScript(
        sourceHtml: body,
        jsRule: ruleText,
      );
    }

    final document = html_parser.parse(body);
    return _ruleParserEngine.debugParseRule(document, ruleText, baseUrl).trim();
  }

  bool _looksLikeJsoupScript(String rule) {
    final lower = rule.toLowerCase();
    return lower.startsWith('@js:') ||
        lower.contains('org.jsoup.jsoup.parse(result)') ||
        lower.contains('jsoup.select(');
  }

  String _applyJsoupLikeScript({
    required String sourceHtml,
    required String jsRule,
  }) {
    var script = jsRule.trim();
    if (script.toLowerCase().startsWith('@js:')) {
      script = script.substring(4).trim();
    }
    if (script.isEmpty) return sourceHtml;

    final document = html_parser.parse(sourceHtml);

    final removePattern = RegExp(
      r'''jsoup\.select\((['"])(.*?)\1\)\.remove\(\)''',
      caseSensitive: false,
      dotAll: true,
    );
    for (final match in removePattern.allMatches(script)) {
      final rawSelector = match.group(2);
      if (rawSelector == null) continue;
      final selector = _decodeJsString(rawSelector);
      if (selector.isEmpty) continue;
      final targets = _queryElements(document, selector);
      for (final node in targets) {
        node.remove();
      }
    }

    String? extracted;
    final extractPattern = RegExp(
      r'''jsoup\.select\((['"])(.*?)\1\)\.(html|text|outerHtml)\(\)''',
      caseSensitive: false,
      dotAll: true,
    );
    for (final match in extractPattern.allMatches(script)) {
      final rawSelector = match.group(2);
      final operationRaw = match.group(3);
      if (rawSelector == null || operationRaw == null) continue;
      final selector = _decodeJsString(rawSelector);
      if (selector.isEmpty) continue;
      final targets = _queryElements(document, selector);
      if (targets.isEmpty) {
        extracted = '';
        continue;
      }
      final operation = operationRaw.toLowerCase();
      switch (operation) {
        case 'html':
          extracted = targets.map((node) => node.innerHtml).join('\n').trim();
          break;
        case 'text':
          extracted = targets.map((node) => node.text).join('\n').trim();
          break;
        case 'outerhtml':
          extracted = targets.map((node) => node.outerHtml).join('\n').trim();
          break;
      }
    }

    if (extracted != null) {
      return extracted!;
    }
    return sourceHtml;
  }

  List<Element> _queryElements(Document document, String selector) {
    try {
      return document.querySelectorAll(selector);
    } catch (_) {
      return const <Element>[];
    }
  }

  String _decodeJsString(String raw) {
    return raw
        .replaceAll(r'\"', '"')
        .replaceAll(r"\'", "'")
        .replaceAll(r'\\', '\\')
        .trim();
  }

  String _decodeResponseBytes(Uint8List bytes, Headers headers) {
    if (bytes.isEmpty) return '';
    final headerCharset = _tryParseCharsetFromContentType(
      headers.value('content-type') ?? headers.value('Content-Type'),
    );
    final htmlCharset = _tryParseCharsetFromHtmlHead(bytes);
    final effectiveCharset =
        (headerCharset?.isNotEmpty == true ? headerCharset : htmlCharset) ??
            'utf-8';
    final normalized = _normalizeCharset(effectiveCharset);
    try {
      if (normalized == 'gbk') {
        return gbk.decode(bytes, allowMalformed: true);
      }
      return utf8.decode(bytes, allowMalformed: true);
    } catch (_) {
      try {
        return gbk.decode(bytes, allowMalformed: true);
      } catch (_) {
        return latin1.decode(bytes, allowInvalid: true);
      }
    }
  }

  String _normalizeCharset(String raw) {
    final normalized = raw.trim().toLowerCase();
    if (normalized.isEmpty) return 'utf-8';
    if (normalized == 'utf8') return 'utf-8';
    if (normalized == 'gb2312' ||
        normalized == 'gbk' ||
        normalized == 'gb18030') {
      return 'gbk';
    }
    return normalized;
  }

  String? _tryParseCharsetFromContentType(String? contentType) {
    final ct = (contentType ?? '').trim();
    if (ct.isEmpty) return null;
    final match = RegExp(
      r'charset\s*=\s*([^;\s]+)',
      caseSensitive: false,
    ).firstMatch(ct);
    if (match == null) return null;
    final value = match.group(1);
    if (value == null || value.trim().isEmpty) return null;
    return _normalizeCharset(value.replaceAll('"', '').replaceAll("'", ''));
  }

  String? _tryParseCharsetFromHtmlHead(Uint8List bytes) {
    final headLength = bytes.length < 4096 ? bytes.length : 4096;
    final head = latin1.decode(
      bytes.sublist(0, headLength),
      allowInvalid: true,
    );
    final first = RegExp(
      r'''<meta[^>]+charset\s*=\s*['"]?\s*([^'"\s/>]+)''',
      caseSensitive: false,
    ).firstMatch(head);
    if (first != null) {
      final charset = first.group(1);
      if (charset != null && charset.trim().isNotEmpty) {
        return _normalizeCharset(charset);
      }
    }
    final second = RegExp(
      r'''<meta[^>]+http-equiv\s*=\s*['"]content-type['"][^>]+content\s*=\s*['"][^'"]*charset\s*=\s*([^'"\s;]+)''',
      caseSensitive: false,
    ).firstMatch(head);
    if (second != null) {
      final charset = second.group(1);
      if (charset != null && charset.trim().isNotEmpty) {
        return _normalizeCharset(charset);
      }
    }
    return null;
  }
}
