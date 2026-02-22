import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/http_tts_rule.dart';

enum HttpTtsImportCandidateState {
  newRule,
  update,
  existing,
}

class HttpTtsImportCandidate {
  const HttpTtsImportCandidate({
    required this.rule,
    required this.localRule,
    required this.state,
  });

  final HttpTtsRule rule;
  final HttpTtsRule? localRule;
  final HttpTtsImportCandidateState state;

  bool get selectedByDefault => state != HttpTtsImportCandidateState.existing;
}

class HttpTtsRuleStore {
  static const String _prefsKey = 'http_tts_rules';
  static const String _defaultAssetPath = 'assets/source/httpTTS.json';
  static const String _requestWithoutUaSuffix = '#requestWithoutUA';
  static const int _maxImportDepth = 3;

  final Dio _httpClient;

  HttpTtsRuleStore({
    Dio? httpClient,
  }) : _httpClient = httpClient ?? Dio();

  Future<List<HttpTtsRule>> loadRules() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey)?.trim();
    if (raw == null || raw.isEmpty) {
      return const <HttpTtsRule>[];
    }
    try {
      return HttpTtsRule.listFromJsonText(raw);
    } catch (_) {
      return const <HttpTtsRule>[];
    }
  }

  Future<void> saveRules(List<HttpTtsRule> rules) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = HttpTtsRule.listToJsonText(rules);
    await prefs.setString(_prefsKey, raw);
  }

  Future<void> upsertRule(HttpTtsRule rule) async {
    final mergedById = <int, HttpTtsRule>{
      for (final item in await loadRules()) item.id: item,
    };
    mergedById[rule.id] = rule;
    await saveRules(mergedById.values.toList(growable: false));
  }

  Future<int> importDefaultRules() async {
    final defaults = await _loadDefaultRulesFromAssets();
    final current = await loadRules();
    final preserved =
        current.where((rule) => !rule.isDefaultRule).toList(growable: false);
    final merged = <HttpTtsRule>[
      ...preserved,
      ...defaults,
    ];
    await saveRules(merged);
    return defaults.length;
  }

  Future<List<HttpTtsImportCandidate>> previewImportCandidates(
    String rawInput,
  ) async {
    final incoming = await _parseImportInput(rawInput, depth: 0);
    if (incoming.isEmpty) {
      throw const FormatException('格式不对');
    }
    final localRules = await loadRules();
    final localById = <int, HttpTtsRule>{
      for (final rule in localRules) rule.id: rule,
    };
    return incoming.map((rule) {
      final localRule = localById[rule.id];
      final state = _compareImportState(rule: rule, localRule: localRule);
      return HttpTtsImportCandidate(
        rule: rule,
        localRule: localRule,
        state: state,
      );
    }).toList(growable: false);
  }

  Future<int> importCandidates({
    required List<HttpTtsImportCandidate> candidates,
    required Set<int> selectedIndexes,
  }) async {
    if (selectedIndexes.isEmpty) {
      return 0;
    }
    final rules = await loadRules();
    final mergedById = <int, HttpTtsRule>{
      for (final rule in rules) rule.id: rule,
    };
    var importedCount = 0;
    final sortedIndexes = selectedIndexes.toList()..sort();
    for (final index in sortedIndexes) {
      if (index < 0 || index >= candidates.length) {
        continue;
      }
      final candidate = candidates[index];
      mergedById[candidate.rule.id] = candidate.rule;
      importedCount++;
    }
    await saveRules(mergedById.values.toList(growable: false));
    return importedCount;
  }

  Future<List<HttpTtsRule>> _parseImportInput(
    String input, {
    required int depth,
  }) async {
    if (depth > _maxImportDepth) {
      throw const FormatException('导入链接重定向层级过深');
    }
    final text = _sanitizeImportInput(input);
    if (text.isEmpty) {
      throw const FormatException('格式不对');
    }
    if (_looksLikeJson(text)) {
      return HttpTtsRule.listFromJsonText(text);
    }
    final parsedUri = Uri.tryParse(text);
    if (parsedUri != null &&
        (parsedUri.scheme == 'http' || parsedUri.scheme == 'https')) {
      final remoteText = await _loadTextFromUrl(text);
      return _parseImportInput(remoteText, depth: depth + 1);
    }
    throw const FormatException('格式不对');
  }

  Future<String> _loadTextFromUrl(String rawUrl) async {
    var url = rawUrl.trim();
    var requestWithoutUa = false;
    if (url.endsWith(_requestWithoutUaSuffix)) {
      requestWithoutUa = true;
      url = url.substring(0, url.length - _requestWithoutUaSuffix.length);
    }
    final response = await _httpClient.get<String>(
      url,
      options: Options(
        responseType: ResponseType.plain,
        headers: requestWithoutUa
            ? const <String, String>{'User-Agent': 'null'}
            : null,
      ),
    );
    final data = response.data;
    if (data == null || data.trim().isEmpty) {
      throw const FormatException('格式不对');
    }
    return data;
  }

  static String _sanitizeImportInput(String input) {
    var value = input.trim();
    if (value.startsWith('\uFEFF')) {
      value = value.replaceFirst(RegExp(r'^\uFEFF+'), '');
    }
    return value.trim();
  }

  static bool _looksLikeJson(String value) {
    return value.startsWith('{') || value.startsWith('[');
  }

  static HttpTtsImportCandidateState _compareImportState({
    required HttpTtsRule rule,
    required HttpTtsRule? localRule,
  }) {
    if (localRule == null) {
      return HttpTtsImportCandidateState.newRule;
    }
    if (rule.lastUpdateTime > localRule.lastUpdateTime) {
      return HttpTtsImportCandidateState.update;
    }
    return HttpTtsImportCandidateState.existing;
  }

  Future<List<HttpTtsRule>> _loadDefaultRulesFromAssets() async {
    final raw = await rootBundle.loadString(_defaultAssetPath);
    final rules = HttpTtsRule.listFromJsonText(raw);
    return rules.where((rule) => rule.url.trim().isNotEmpty).toList();
  }
}
