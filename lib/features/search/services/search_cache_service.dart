import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/models/app_settings.dart';
import '../../source/services/rule_parser_engine.dart';

/// 搜索页本地状态存储（历史词 + 结果缓存）。
class SearchCacheService {
  static const String _historyKey = 'search_history_keywords_v1';
  static const String _cacheKey = 'search_result_cache_v1';
  static const int _maxHistoryItems = 12;
  static const int _maxCacheEntries = 24;
  static const int _maxCacheResultsPerEntry = 160;

  Future<SharedPreferences> get _prefs async {
    return SharedPreferences.getInstance();
  }

  Future<List<String>> loadHistory() async {
    final prefs = await _prefs;
    final raw = prefs.getStringList(_historyKey) ?? const <String>[];
    return _normalizeHistory(raw);
  }

  Future<List<String>> saveHistoryKeyword(String keyword) async {
    final normalized = keyword.trim();
    if (normalized.isEmpty) {
      return loadHistory();
    }
    final prefs = await _prefs;
    final current = prefs.getStringList(_historyKey) ?? const <String>[];
    final next = <String>[
      normalized,
      ...current.where((item) => item.trim() != normalized),
    ];
    final cleaned = _normalizeHistory(next);
    await prefs.setStringList(_historyKey, cleaned);
    return cleaned;
  }

  Future<List<String>> deleteHistoryKeyword(String keyword) async {
    final target = keyword.trim();
    final prefs = await _prefs;
    final current = prefs.getStringList(_historyKey) ?? const <String>[];
    final next =
        current.where((item) => item.trim() != target).toList(growable: false);
    final cleaned = _normalizeHistory(next);
    await prefs.setStringList(_historyKey, cleaned);
    return cleaned;
  }

  Future<void> clearHistory() async {
    final prefs = await _prefs;
    await prefs.remove(_historyKey);
  }

  String buildCacheKey({
    required String keyword,
    required SearchFilterMode filterMode,
    required Iterable<String> scopeSourceUrls,
  }) {
    final normalizedKeyword =
        keyword.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
    final normalizedScope = scopeSourceUrls
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList(growable: false)
      ..sort();
    final normalizedFilterMode =
        normalizeSearchFilterMode(filterMode) == SearchFilterMode.precise
            ? 'precise'
            : 'normal';
    return '$normalizedFilterMode|$normalizedKeyword|${normalizedScope.join(",")}';
  }

  Future<SearchCacheEntry?> readCache({
    required String key,
    required int retentionDays,
  }) async {
    final entries = await _readCacheEntries();
    final now = DateTime.now().millisecondsSinceEpoch;
    final maxAgeMs = Duration(days: retentionDays.clamp(1, 30)).inMilliseconds;
    for (final entry in entries) {
      if (entry.key != key) continue;
      if (now - entry.savedAtMs > maxAgeMs) return null;
      if (entry.results.isEmpty) return null;
      return entry;
    }
    return null;
  }

  Future<void> writeCache({
    required String key,
    required List<SearchResult> results,
  }) async {
    final normalizedResults = results
        .where((item) => item.sourceUrl.trim().isNotEmpty)
        .where((item) => item.bookUrl.trim().isNotEmpty)
        .take(_maxCacheResultsPerEntry)
        .toList(growable: false);
    if (normalizedResults.isEmpty) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    final current = await _readCacheEntries();
    final next = <SearchCacheEntry>[
      SearchCacheEntry(
        key: key,
        savedAtMs: now,
        results: normalizedResults,
      ),
      ...current.where((item) => item.key != key),
    ].take(_maxCacheEntries).toList(growable: false);
    await _writeCacheEntries(next);
  }

  Future<int> purgeExpiredCache({required int retentionDays}) async {
    final maxAgeMs = Duration(days: retentionDays.clamp(1, 30)).inMilliseconds;
    final now = DateTime.now().millisecondsSinceEpoch;
    final current = await _readCacheEntries();
    final next = current
        .where((item) => now - item.savedAtMs <= maxAgeMs)
        .toList(growable: false);
    await _writeCacheEntries(next);
    return current.length - next.length;
  }

  Future<int> clearCache() async {
    final entries = await _readCacheEntries();
    final prefs = await _prefs;
    await prefs.remove(_cacheKey);
    return entries.length;
  }

  List<String> _normalizeHistory(List<String> values) {
    final seen = <String>{};
    final out = <String>[];
    for (final item in values) {
      final text = item.trim();
      if (text.isEmpty) continue;
      if (!seen.add(text)) continue;
      out.add(text);
      if (out.length >= _maxHistoryItems) break;
    }
    return out;
  }

  Future<List<SearchCacheEntry>> _readCacheEntries() async {
    final prefs = await _prefs;
    final raw = prefs.getString(_cacheKey);
    if (raw == null || raw.trim().isEmpty) {
      return const <SearchCacheEntry>[];
    }
    try {
      final decoded = json.decode(raw);
      if (decoded is! Map) return const <SearchCacheEntry>[];
      final entriesRaw = decoded['entries'];
      if (entriesRaw is! List) return const <SearchCacheEntry>[];
      final entries = <SearchCacheEntry>[];
      for (final item in entriesRaw) {
        if (item is! Map) continue;
        final map = item.map((key, value) => MapEntry('$key', value));
        final parsed = SearchCacheEntry.fromJson(map);
        if (parsed == null) continue;
        entries.add(parsed);
      }
      return entries;
    } catch (_) {
      return const <SearchCacheEntry>[];
    }
  }

  Future<void> _writeCacheEntries(List<SearchCacheEntry> entries) async {
    final prefs = await _prefs;
    if (entries.isEmpty) {
      await prefs.remove(_cacheKey);
      return;
    }
    final payload = <String, Object?>{
      'entries': entries.map((entry) => entry.toJson()).toList(growable: false),
    };
    await prefs.setString(_cacheKey, json.encode(payload));
  }
}

class SearchCacheEntry {
  final String key;
  final int savedAtMs;
  final List<SearchResult> results;

  const SearchCacheEntry({
    required this.key,
    required this.savedAtMs,
    required this.results,
  });

  static SearchCacheEntry? fromJson(Map<String, dynamic> json) {
    final key = (json['key'] ?? '').toString().trim();
    if (key.isEmpty) return null;

    final savedAt = json['savedAtMs'];
    final savedAtMs = savedAt is int
        ? savedAt
        : savedAt is num
            ? savedAt.toInt()
            : 0;
    if (savedAtMs <= 0) return null;

    final resultsRaw = json['results'];
    if (resultsRaw is! List) return null;
    final results = <SearchResult>[];
    for (final item in resultsRaw) {
      if (item is! Map) continue;
      final map = item.map((k, v) => MapEntry('$k', v));
      final result = _searchResultFromJson(map);
      if (result == null) continue;
      results.add(result);
    }
    if (results.isEmpty) return null;
    return SearchCacheEntry(
      key: key,
      savedAtMs: savedAtMs,
      results: results,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'key': key,
      'savedAtMs': savedAtMs,
      'results': results.map(_searchResultToJson).toList(growable: false),
    };
  }

  static SearchResult? _searchResultFromJson(Map<String, dynamic> json) {
    final name = (json['name'] ?? '').toString().trim();
    final author = (json['author'] ?? '').toString().trim();
    final bookUrl = (json['bookUrl'] ?? '').toString().trim();
    final sourceUrl = (json['sourceUrl'] ?? '').toString().trim();
    final sourceName = (json['sourceName'] ?? '').toString().trim();
    if (name.isEmpty || bookUrl.isEmpty || sourceUrl.isEmpty) {
      return null;
    }
    return SearchResult(
      name: name,
      author: author,
      coverUrl: (json['coverUrl'] ?? '').toString(),
      intro: (json['intro'] ?? '').toString(),
      kind: (json['kind'] ?? '').toString(),
      lastChapter: (json['lastChapter'] ?? '').toString(),
      updateTime: (json['updateTime'] ?? '').toString(),
      wordCount: (json['wordCount'] ?? '').toString(),
      bookUrl: bookUrl,
      sourceUrl: sourceUrl,
      sourceName: sourceName.isEmpty ? sourceUrl : sourceName,
    );
  }

  static Map<String, String> _searchResultToJson(SearchResult result) {
    return <String, String>{
      'name': result.name,
      'author': result.author,
      'coverUrl': result.coverUrl,
      'intro': result.intro,
      'kind': result.kind,
      'lastChapter': result.lastChapter,
      'updateTime': result.updateTime,
      'wordCount': result.wordCount,
      'bookUrl': result.bookUrl,
      'sourceUrl': result.sourceUrl,
      'sourceName': result.sourceName,
    };
  }
}
