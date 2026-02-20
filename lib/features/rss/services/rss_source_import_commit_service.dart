import 'dart:convert';
import 'dart:math' as math;

import '../../../core/utils/legado_json.dart';
import '../models/rss_source.dart';
import 'rss_source_import_selection_helper.dart';

typedef RssSourceImportRawUpsert = Future<void> Function({
  String? originalUrl,
  required String rawJson,
});

typedef RssSourceImportAllSourcesLoader = List<RssSource> Function();

typedef RssSourceImportRawJsonLoader = String? Function(String sourceUrl);

typedef RssSourceImportAfterCommit = Future<void> Function();

class RssSourceImportCommitResult {
  const RssSourceImportCommitResult({
    this.imported = 0,
    this.newCount = 0,
    this.updateCount = 0,
    this.existingCount = 0,
  });

  final int imported;
  final int newCount;
  final int updateCount;
  final int existingCount;
}

class RssSourceImportCommitService {
  RssSourceImportCommitService({
    required RssSourceImportRawUpsert upsertSourceRawJson,
    required RssSourceImportAllSourcesLoader loadAllSources,
    required RssSourceImportRawJsonLoader loadRawJsonByUrl,
    RssSourceImportAfterCommit? afterCommit,
  })  : _upsertSourceRawJson = upsertSourceRawJson,
        _loadAllSources = loadAllSources,
        _loadRawJsonByUrl = loadRawJsonByUrl,
        _afterCommit = afterCommit;

  final RssSourceImportRawUpsert _upsertSourceRawJson;
  final RssSourceImportAllSourcesLoader _loadAllSources;
  final RssSourceImportRawJsonLoader _loadRawJsonByUrl;
  final RssSourceImportAfterCommit? _afterCommit;

  Future<RssSourceImportCommitResult> commit(
    List<RssSourceImportCommitPlanItem> items,
  ) async {
    if (items.isEmpty) {
      return const RssSourceImportCommitResult();
    }

    var imported = 0;
    var newCount = 0;
    var updateCount = 0;
    var existingCount = 0;

    for (final item in items) {
      await _upsertSourceRawJson(
        originalUrl: item.originalUrl,
        rawJson: item.rawJson,
      );
      imported++;
      switch (item.state) {
        case RssSourceImportCandidateState.newSource:
          newCount++;
        case RssSourceImportCandidateState.update:
          updateCount++;
        case RssSourceImportCandidateState.existing:
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

    return RssSourceImportCommitResult(
      imported: imported,
      newCount: newCount,
      updateCount: updateCount,
      existingCount: existingCount,
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
        return left.sourceUrl.compareTo(right.sourceUrl);
      });

    for (var index = 0; index < sorted.length; index++) {
      final source = sorted[index];
      if (source.customOrder == index) continue;

      final rawMap = _decodeRawMap(_loadRawJsonByUrl(source.sourceUrl));
      final normalized = rawMap ?? source.toJson();
      normalized['customOrder'] = index;
      normalized['sourceUrl'] = source.sourceUrl;

      await _upsertSourceRawJson(
        originalUrl: source.sourceUrl,
        rawJson: LegadoJson.encode(normalized),
      );
    }
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
