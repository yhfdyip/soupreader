import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/services.dart';

import '../../../core/utils/legado_json.dart';
import '../models/book_source.dart';
import 'source_host_group_helper.dart';
import 'source_import_selection_helper.dart';

typedef SourceImportRawUpsert = Future<void> Function({
  String? originalUrl,
  required String rawJson,
});

typedef SourceImportAllSourcesLoader = List<BookSource> Function();

typedef SourceImportRawJsonLoader = String? Function(String bookSourceUrl);

typedef SourceImportBlockedHostLoader = Future<Set<String>> Function();
typedef SourceImportAfterCommit = Future<void> Function();

class SourceImportCommitResult {
  const SourceImportCommitResult({
    this.imported = 0,
    this.newCount = 0,
    this.updateCount = 0,
    this.existingCount = 0,
    this.blockedNames = const <String>[],
  });

  final int imported;
  final int newCount;
  final int updateCount;
  final int existingCount;
  final List<String> blockedNames;

  int get blockedCount => blockedNames.length;
}

class SourceImportCommitService {
  SourceImportCommitService({
    required SourceImportRawUpsert upsertSourceRawJson,
    required SourceImportAllSourcesLoader loadAllSources,
    required SourceImportRawJsonLoader loadRawJsonByUrl,
    SourceImportBlockedHostLoader? loadBlockedHosts,
    SourceImportAfterCommit? afterCommit,
  })  : _upsertSourceRawJson = upsertSourceRawJson,
        _loadAllSources = loadAllSources,
        _loadRawJsonByUrl = loadRawJsonByUrl,
        _loadBlockedHosts = loadBlockedHosts ?? _defaultBlockedHostLoader,
        _afterCommit = afterCommit;

  static const String _asset18PlusList = 'assets/source/18PlusList.txt';
  static Set<String>? _cachedBlockedHosts;

  final SourceImportRawUpsert _upsertSourceRawJson;
  final SourceImportAllSourcesLoader _loadAllSources;
  final SourceImportRawJsonLoader _loadRawJsonByUrl;
  final SourceImportBlockedHostLoader _loadBlockedHosts;
  final SourceImportAfterCommit? _afterCommit;

  Future<SourceImportCommitResult> commit(
    List<SourceImportCommitPlanItem> items,
  ) async {
    if (items.isEmpty) {
      return const SourceImportCommitResult();
    }
    final blockedHosts = await _loadBlockedHosts();
    var imported = 0;
    var newCount = 0;
    var updateCount = 0;
    var existingCount = 0;
    final blockedNames = <String>[];
    for (final item in items) {
      if (_isBlockedByDomain(item.url, blockedHosts)) {
        final name = item.source.bookSourceName.trim();
        blockedNames.add(name.isEmpty ? item.url : name);
        continue;
      }
      await _upsertSourceRawJson(rawJson: item.rawJson);
      imported++;
      switch (item.state) {
        case SourceImportCandidateState.newSource:
          newCount++;
        case SourceImportCandidateState.update:
          updateCount++;
        case SourceImportCandidateState.existing:
          existingCount++;
      }
    }
    await _adjustSortNumberIfNeeded();
    if (imported > 0) {
      try {
        await _afterCommit?.call();
      } catch (_) {
        // 导入主流程优先，后处理异常不阻断导入结果。
      }
    }
    return SourceImportCommitResult(
      imported: imported,
      newCount: newCount,
      updateCount: updateCount,
      existingCount: existingCount,
      blockedNames: blockedNames,
    );
  }

  Future<void> _adjustSortNumberIfNeeded() async {
    final all = _loadAllSources();
    if (all.isEmpty) return;
    final allOrders = all.map((source) => source.customOrder).toList();
    final minOrder = allOrders.reduce(math.min);
    final maxOrder = allOrders.reduce(math.max);
    final hasDuplicateOrder = allOrders.toSet().length != allOrders.length;
    final outOfRange = maxOrder > 99999 || minOrder < -99999;
    if (!hasDuplicateOrder && !outOfRange) {
      return;
    }
    final sorted = all.toList(growable: false)
      ..sort((left, right) {
        final orderCompare = left.customOrder.compareTo(right.customOrder);
        if (orderCompare != 0) return orderCompare;
        return left.bookSourceUrl.compareTo(right.bookSourceUrl);
      });
    for (var index = 0; index < sorted.length; index++) {
      final source = sorted[index];
      if (source.customOrder == index) continue;
      final rawMap = _decodeRawMap(_loadRawJsonByUrl(source.bookSourceUrl));
      final normalized = rawMap ?? source.toJson();
      normalized['customOrder'] = index;
      normalized['bookSourceUrl'] = source.bookSourceUrl;
      await _upsertSourceRawJson(
        originalUrl: source.bookSourceUrl,
        rawJson: LegadoJson.encode(normalized),
      );
    }
  }

  static Future<Set<String>> _defaultBlockedHostLoader() async {
    final cached = _cachedBlockedHosts;
    if (cached != null) return cached;
    try {
      final text = await rootBundle.loadString(_asset18PlusList);
      final hosts = _decodeBlockedHosts(text);
      _cachedBlockedHosts = hosts;
      return hosts;
    } catch (_) {
      _cachedBlockedHosts = const <String>{};
      return _cachedBlockedHosts!;
    }
  }

  static Set<String> _decodeBlockedHosts(String rawText) {
    final hosts = <String>{};
    for (final line in rawText.split(RegExp(r'\r?\n'))) {
      final encoded = line.trim();
      if (encoded.isEmpty) continue;
      try {
        final decoded = utf8.decode(base64.decode(encoded)).trim();
        if (decoded.isNotEmpty) {
          hosts.add(decoded.toLowerCase());
        }
      } catch (_) {
        // ignore broken line
      }
    }
    return hosts;
  }

  bool _isBlockedByDomain(String url, Set<String> blockedHosts) {
    if (blockedHosts.isEmpty) return false;
    final domainKey = _extractSecondLevelDomain(url);
    if (domainKey.isEmpty) return false;
    return blockedHosts.contains(domainKey);
  }

  String _extractSecondLevelDomain(String url) {
    final groupedHost = SourceHostGroupHelper.groupHost(url).trim().toLowerCase();
    if (groupedHost.isEmpty || groupedHost == '#') return '';
    return groupedHost;
  }

  Map<String, dynamic>? _decodeRawMap(String? rawJson) {
    final text = rawJson?.trim();
    if (text == null || text.isEmpty) return null;
    try {
      final decoded = json.decode(text);
      if (decoded is Map<String, dynamic>) {
        return Map<String, dynamic>.from(decoded);
      }
      if (decoded is Map) {
        return decoded.map((key, value) => MapEntry('$key', value));
      }
    } catch (_) {
      return null;
    }
    return null;
  }
}
