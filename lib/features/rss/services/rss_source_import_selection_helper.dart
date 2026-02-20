import 'dart:convert';

import '../../../core/utils/legado_json.dart';
import '../models/rss_source.dart';
import 'rss_source_import_export_service.dart';

enum RssSourceImportCandidateState {
  newSource,
  update,
  existing,
}

class RssSourceImportCandidate {
  const RssSourceImportCandidate({
    required this.incoming,
    required this.existing,
    required this.rawJson,
    required this.state,
  });

  final RssSource incoming;
  final RssSource? existing;
  final String rawJson;
  final RssSourceImportCandidateState state;

  String get url => incoming.sourceUrl.trim();
}

class RssSourceImportSelectionPolicy {
  const RssSourceImportSelectionPolicy({
    required this.selectedUrls,
    this.selectedIndexes = const <int>{},
    this.keepName = true,
    this.keepGroup = true,
    this.keepEnabled = true,
    this.customGroup = '',
    this.appendCustomGroup = false,
  });

  final Set<String> selectedUrls;
  final Set<int> selectedIndexes;
  final bool keepName;
  final bool keepGroup;
  final bool keepEnabled;
  final String customGroup;
  final bool appendCustomGroup;
}

class RssSourceImportCommitPlanItem {
  const RssSourceImportCommitPlanItem({
    required this.url,
    required this.source,
    required this.rawJson,
    required this.state,
    this.originalUrl,
  });

  final String url;
  final RssSource source;
  final String rawJson;
  final RssSourceImportCandidateState state;
  final String? originalUrl;
}

class RssSourceImportCommitPlan {
  const RssSourceImportCommitPlan({
    this.items = const <RssSourceImportCommitPlanItem>[],
    this.imported = 0,
    this.newCount = 0,
    this.updateCount = 0,
    this.existingCount = 0,
  });

  final List<RssSourceImportCommitPlanItem> items;
  final int imported;
  final int newCount;
  final int updateCount;
  final int existingCount;
}

class RssSourceImportSelectionHelper {
  const RssSourceImportSelectionHelper._();

  static List<RssSourceImportCandidate> buildCandidates({
    required RssSourceImportResult result,
    required Map<String, RssSource> localMap,
  }) {
    final dedup = <String, RssSourceImportCandidate>{};
    for (final source in result.sources) {
      final url = source.sourceUrl.trim();
      if (url.isEmpty) continue;
      final existing = localMap[url];
      final state = existing == null
          ? RssSourceImportCandidateState.newSource
          : (source.lastUpdateTime > existing.lastUpdateTime
              ? RssSourceImportCandidateState.update
              : RssSourceImportCandidateState.existing);
      if (dedup.containsKey(url)) {
        dedup.remove(url);
      }
      dedup[url] = RssSourceImportCandidate(
        incoming: source,
        existing: existing,
        rawJson: result.rawJsonForSourceUrl(url) ?? LegadoJson.encode(source.toJson()),
        state: state,
      );
    }
    return dedup.values.toList(growable: false);
  }

  static Set<String> defaultSelectedUrls(
    List<RssSourceImportCandidate> candidates,
  ) {
    final selected = <String>{};
    for (final candidate in candidates) {
      if (candidate.state == RssSourceImportCandidateState.existing) {
        continue;
      }
      selected.add(candidate.url);
    }
    return selected;
  }

  static bool areAllSelected({
    required List<RssSourceImportCandidate> candidates,
    required Set<String> selectedUrls,
  }) {
    for (final candidate in candidates) {
      if (!selectedUrls.contains(candidate.url)) {
        return false;
      }
    }
    return true;
  }

  static bool areAllStateSelected({
    required List<RssSourceImportCandidate> candidates,
    required Set<String> selectedUrls,
    required RssSourceImportCandidateState state,
  }) {
    for (final candidate in candidates) {
      if (candidate.state != state) continue;
      if (!selectedUrls.contains(candidate.url)) {
        return false;
      }
    }
    return true;
  }

  static Set<String> toggleAllSelection({
    required List<RssSourceImportCandidate> candidates,
    required Set<String> selectedUrls,
  }) {
    final next = selectedUrls.toSet();
    final allSelected =
        areAllSelected(candidates: candidates, selectedUrls: selectedUrls);
    for (final candidate in candidates) {
      final url = candidate.url;
      if (allSelected) {
        next.remove(url);
      } else {
        next.add(url);
      }
    }
    return next;
  }

  static Set<String> toggleStateSelection({
    required List<RssSourceImportCandidate> candidates,
    required Set<String> selectedUrls,
    required RssSourceImportCandidateState state,
  }) {
    final next = selectedUrls.toSet();
    final allStateSelected = areAllStateSelected(
      candidates: candidates,
      selectedUrls: selectedUrls,
      state: state,
    );
    for (final candidate in candidates) {
      if (candidate.state != state) continue;
      final url = candidate.url;
      if (allStateSelected) {
        next.remove(url);
      } else {
        next.add(url);
      }
    }
    return next;
  }

  static RssSourceImportCommitPlan buildCommitPlan({
    required List<RssSourceImportCandidate> candidates,
    required RssSourceImportSelectionPolicy policy,
  }) {
    var newCount = 0;
    var updateCount = 0;
    var existingCount = 0;
    final items = <RssSourceImportCommitPlanItem>[];
    for (var index = 0; index < candidates.length; index++) {
      final candidate = candidates[index];
      final url = candidate.url;
      if (url.isEmpty) {
        continue;
      }
      final selected = policy.selectedIndexes.isNotEmpty
          ? policy.selectedIndexes.contains(index)
          : policy.selectedUrls.contains(url);
      if (!selected) {
        continue;
      }

      final merged = _applyPolicy(candidate, policy);
      items.add(
        RssSourceImportCommitPlanItem(
          url: merged.sourceUrl.trim(),
          source: merged,
          rawJson: _buildRawJson(candidate.rawJson, merged),
          state: candidate.state,
          originalUrl: candidate.existing?.sourceUrl,
        ),
      );

      switch (candidate.state) {
        case RssSourceImportCandidateState.newSource:
          newCount++;
        case RssSourceImportCandidateState.update:
          updateCount++;
        case RssSourceImportCandidateState.existing:
          existingCount++;
      }
    }

    return RssSourceImportCommitPlan(
      items: items,
      imported: items.length,
      newCount: newCount,
      updateCount: updateCount,
      existingCount: existingCount,
    );
  }

  static RssSourceImportCandidate? tryReplaceCandidateRawJson({
    required RssSourceImportCandidate candidate,
    required String rawJson,
  }) {
    final decoded = _decodeRawJson(rawJson);
    if (decoded == null) return null;

    var source = RssSource.fromJson(decoded);
    final originalUrl = candidate.url;
    if (source.sourceUrl.trim().isEmpty && originalUrl.isNotEmpty) {
      source = source.copyWith(sourceUrl: originalUrl);
    }
    if (source.sourceName.trim().isEmpty) {
      source = source.copyWith(sourceName: candidate.incoming.sourceName);
    }

    final normalizedRaw = _buildRawJson(rawJson, source);
    return RssSourceImportCandidate(
      incoming: source,
      existing: candidate.existing,
      rawJson: normalizedRaw,
      state: candidate.state,
    );
  }

  static RssSource _applyPolicy(
    RssSourceImportCandidate candidate,
    RssSourceImportSelectionPolicy policy,
  ) {
    var source = candidate.incoming;
    final existing = candidate.existing;
    if (existing != null) {
      if (policy.keepName) {
        source = source.copyWith(sourceName: existing.sourceName);
      }
      if (policy.keepGroup) {
        source = source.copyWith(sourceGroup: existing.sourceGroup);
      }
      if (policy.keepEnabled) {
        source = source.copyWith(enabled: existing.enabled);
      }
      source = source.copyWith(customOrder: existing.customOrder);
    }

    final customGroup = policy.customGroup.trim();
    if (customGroup.isEmpty) {
      return source;
    }

    if (policy.appendCustomGroup) {
      final mergedGroups = <String>{};
      mergedGroups.addAll(RssSource.splitGroups(source.sourceGroup));
      mergedGroups.add(customGroup);
      return source.copyWith(sourceGroup: mergedGroups.join(','));
    }

    return source.copyWith(sourceGroup: customGroup);
  }

  static String _buildRawJson(String rawJson, RssSource source) {
    final rawMap = _decodeRawJson(rawJson);
    final map = rawMap ?? source.toJson();
    map['sourceUrl'] = source.sourceUrl;
    map['sourceName'] = source.sourceName;
    _setNullableString(map, 'sourceGroup', source.sourceGroup);
    map['enabled'] = source.enabled;
    map['customOrder'] = source.customOrder;
    return LegadoJson.encode(map);
  }

  static Map<String, dynamic>? _decodeRawJson(String rawJson) {
    final text = rawJson.trim();
    if (text.isEmpty) return null;
    try {
      final decoded = json.decode(text);
      if (decoded is Map<String, dynamic>) {
        return Map<String, dynamic>.from(decoded);
      }
      if (decoded is Map) {
        return decoded.map((k, v) => MapEntry(k.toString(), v));
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  static void _setNullableString(
    Map<String, dynamic> map,
    String key,
    String? value,
  ) {
    final text = value?.trim();
    if (text == null || text.isEmpty) {
      map.remove(key);
      return;
    }
    map[key] = text;
  }
}
