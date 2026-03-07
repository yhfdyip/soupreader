import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';

import '../../../core/services/preferences_store.dart';
import '../models/txt_toc_rule.dart';

enum TxtTocRuleImportCandidateState {
  newRule,
  update,
  existing,
}

class TxtTocRuleImportCandidate {
  const TxtTocRuleImportCandidate({
    required this.rule,
    required this.localRule,
    required this.state,
  });

  final TxtTocRule rule;
  final TxtTocRule? localRule;
  final TxtTocRuleImportCandidateState state;

  bool get selectedByDefault =>
      state != TxtTocRuleImportCandidateState.existing;
}

class TxtTocRuleStore {
  static const String _prefsKey = 'txt_toc_rules';
  static const String _defaultAssetPath = 'assets/source/txtTocRule.json';
  static const String _requestWithoutUaSuffix = '#requestWithoutUA';
  static const int _maxImportDepth = 3;

  final Dio _httpClient;
  final PreferencesStore _preferencesStore;

  TxtTocRuleStore({
    Dio? httpClient,
    PreferencesStore? preferencesStore,
  }) : _httpClient = httpClient ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 15),
                receiveTimeout: const Duration(seconds: 15),
                followRedirects: true,
                maxRedirects: 8,
              ),
            ),
       _preferencesStore = preferencesStore ?? defaultPreferencesStore;

  Future<List<TxtTocRule>> loadRules() async {
    final raw = (await _preferencesStore.getString(_prefsKey))?.trim();
    if (raw != null && raw.isNotEmpty) {
      try {
        return TxtTocRule.listFromJsonText(raw);
      } catch (_) {
        // 配置损坏时回退默认规则，避免阻塞目录规则主链路。
      }
    }
    return _loadDefaultRulesFromAsset();
  }

  Future<void> saveRules(List<TxtTocRule> rules) async {
    await _preferencesStore.setString(
      _prefsKey,
      TxtTocRule.listToJsonText(rules),
    );
  }

  Future<void> upsertRule(TxtTocRule rule) async {
    final mergedById = <int, TxtTocRule>{
      for (final item in await loadRules()) item.id: item,
    };
    mergedById[rule.id] = rule;
    await saveRules(_sortRules(mergedById.values.toList(growable: false)));
  }

  Future<void> deleteRule(int id) async {
    final rules = await loadRules();
    if (rules.isEmpty) return;
    final filtered =
        rules.where((rule) => rule.id != id).toList(growable: false);
    if (filtered.length == rules.length) {
      return;
    }
    await saveRules(_sortRules(filtered));
  }

  Future<void> deleteRulesByIds(Iterable<int> ruleIds) async {
    final targetIds = ruleIds.toSet();
    if (targetIds.isEmpty) {
      return;
    }
    final rules = await loadRules();
    if (rules.isEmpty) {
      return;
    }
    final filtered = rules
        .where((rule) => !targetIds.contains(rule.id))
        .toList(growable: false);
    if (filtered.length == rules.length) {
      return;
    }
    await saveRules(_sortRules(filtered));
  }

  Future<void> moveRuleToTop(TxtTocRule rule) async {
    final rules = await loadRules();
    if (rules.isEmpty) return;
    final mergedById = <int, TxtTocRule>{
      for (final item in rules) item.id: item,
    };
    final currentRule = mergedById[rule.id];
    if (currentRule == null) {
      return;
    }
    var minSerial = rules.first.serialNumber;
    for (final current in rules.skip(1)) {
      if (current.serialNumber < minSerial) {
        minSerial = current.serialNumber;
      }
    }
    mergedById[rule.id] = currentRule.copyWith(serialNumber: minSerial - 1);
    await saveRules(_sortRules(mergedById.values.toList(growable: false)));
  }

  Future<void> moveRuleToBottom(TxtTocRule rule) async {
    final rules = await loadRules();
    if (rules.isEmpty) return;
    final mergedById = <int, TxtTocRule>{
      for (final item in rules) item.id: item,
    };
    final currentRule = mergedById[rule.id];
    if (currentRule == null) {
      return;
    }
    var maxSerial = rules.first.serialNumber;
    for (final current in rules.skip(1)) {
      if (current.serialNumber > maxSerial) {
        maxSerial = current.serialNumber;
      }
    }
    mergedById[rule.id] = currentRule.copyWith(serialNumber: maxSerial + 1);
    await saveRules(_sortRules(mergedById.values.toList(growable: false)));
  }

  Future<void> enableRulesByIds(Iterable<int> ruleIds) async {
    final targetIds = ruleIds.toSet();
    if (targetIds.isEmpty) {
      return;
    }
    final mergedById = <int, TxtTocRule>{
      for (final rule in await loadRules()) rule.id: rule,
    };
    for (final id in targetIds) {
      final localRule = mergedById[id];
      if (localRule == null) {
        continue;
      }
      mergedById[id] = localRule.copyWith(enabled: true);
    }
    await saveRules(_sortRules(mergedById.values.toList(growable: false)));
  }

  Future<void> disableRulesByIds(Iterable<int> ruleIds) async {
    final targetIds = ruleIds.toSet();
    if (targetIds.isEmpty) {
      return;
    }
    final mergedById = <int, TxtTocRule>{
      for (final rule in await loadRules()) rule.id: rule,
    };
    for (final id in targetIds) {
      final localRule = mergedById[id];
      if (localRule == null) {
        continue;
      }
      mergedById[id] = localRule.copyWith(enabled: false);
    }
    await saveRules(_sortRules(mergedById.values.toList(growable: false)));
  }

  Future<TxtTocRule> createDraftRule() async {
    final existingIds = <int>{
      for (final rule in await loadRules()) rule.id,
    };
    var nextId = DateTime.now().millisecondsSinceEpoch;
    while (existingIds.contains(nextId)) {
      nextId++;
    }
    return TxtTocRule(
      id: nextId,
      enabled: true,
      name: '',
      rule: '',
      example: null,
      serialNumber: -1,
    );
  }

  Future<List<TxtTocRule>> loadEnabledRules() async {
    final enabledRules = (await loadRules())
        .where((rule) => rule.enabled)
        .toList(growable: false);
    return _sortRules(enabledRules);
  }

  Future<List<TxtTocRuleImportCandidate>> previewImportCandidates(
    String rawInput,
  ) async {
    final incoming = await _parseImportInput(rawInput, depth: 0);
    if (incoming.isEmpty) {
      throw const FormatException('格式不对');
    }
    final localById = <int, TxtTocRule>{
      for (final rule in await loadRules()) rule.id: rule,
    };
    return incoming.map((rule) {
      final localRule = localById[rule.id];
      return TxtTocRuleImportCandidate(
        rule: rule,
        localRule: localRule,
        state: _compareImportState(
          localRule: localRule,
          incomingRule: rule,
        ),
      );
    }).toList(growable: false);
  }

  Future<int> importCandidates({
    required List<TxtTocRuleImportCandidate> candidates,
    required Set<int> selectedIndexes,
  }) async {
    if (selectedIndexes.isEmpty) {
      return 0;
    }
    final mergedById = <int, TxtTocRule>{
      for (final rule in await loadRules()) rule.id: rule,
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
    await saveRules(_sortRules(mergedById.values.toList(growable: false)));
    return importedCount;
  }

  Future<int> importDefaultRules() async {
    final defaults = await _loadDefaultRulesFromAssetStrict();
    final mergedById = <int, TxtTocRule>{
      for (final rule in await loadRules())
        if (rule.id >= 0) rule.id: rule,
    };
    for (final rule in defaults) {
      mergedById[rule.id] = rule;
    }
    await saveRules(_sortRules(mergedById.values.toList(growable: false)));
    return defaults.length;
  }

  Future<List<TxtTocRule>> _loadDefaultRulesFromAsset() async {
    try {
      final raw = await rootBundle.loadString(_defaultAssetPath);
      return _sortRules(TxtTocRule.listFromJsonText(raw));
    } catch (_) {
      return const <TxtTocRule>[];
    }
  }

  Future<List<TxtTocRule>> _loadDefaultRulesFromAssetStrict() async {
    final raw = await rootBundle.loadString(_defaultAssetPath);
    return _sortRules(TxtTocRule.listFromJsonText(raw));
  }

  Future<List<TxtTocRule>> _parseImportInput(
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
      return _sortRules(TxtTocRule.listFromJsonText(text));
    }
    final parsedUri = Uri.tryParse(text);
    if (parsedUri != null) {
      final scheme = parsedUri.scheme.toLowerCase();
      if (scheme == 'http' || scheme == 'https') {
        final remoteText = await _loadTextFromUrl(text);
        return _parseImportInput(remoteText, depth: depth + 1);
      }
      if (scheme == 'file') {
        final localText = await File.fromUri(parsedUri).readAsString();
        return _parseImportInput(localText, depth: depth + 1);
      }
    }
    final localFile = File(text);
    if (await localFile.exists()) {
      final localText = await localFile.readAsString();
      return _parseImportInput(localText, depth: depth + 1);
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

  static TxtTocRuleImportCandidateState _compareImportState({
    required TxtTocRule? localRule,
    required TxtTocRule incomingRule,
  }) {
    if (localRule == null) {
      return TxtTocRuleImportCandidateState.newRule;
    }
    if (incomingRule.sameContentAs(localRule)) {
      return TxtTocRuleImportCandidateState.existing;
    }
    return TxtTocRuleImportCandidateState.update;
  }

  static List<TxtTocRule> _sortRules(List<TxtTocRule> rules) {
    final sorted = List<TxtTocRule>.from(rules);
    sorted.sort((a, b) {
      final bySerial = a.serialNumber.compareTo(b.serialNumber);
      if (bySerial != 0) return bySerial;
      return a.id.compareTo(b.id);
    });
    return sorted;
  }
}
