import 'dart:convert';

import '../../../core/utils/legado_json.dart';
import '../models/book_source.dart';
import 'source_import_export_service.dart';

enum SourceImportCandidateState {
  newSource,
  update,
  existing,
}

class SourceImportCandidate {
  const SourceImportCandidate({
    required this.incoming,
    required this.existing,
    required this.rawJson,
    required this.state,
  });

  final BookSource incoming;
  final BookSource? existing;
  final String rawJson;
  final SourceImportCandidateState state;

  String get url => incoming.bookSourceUrl.trim();
}

class SourceImportSelectionPolicy {
  const SourceImportSelectionPolicy({
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

class SourceImportCommitPlanItem {
  const SourceImportCommitPlanItem({
    required this.url,
    required this.source,
    required this.rawJson,
    required this.state,
  });

  final String url;
  final BookSource source;
  final String rawJson;
  final SourceImportCandidateState state;
}

class SourceImportCommitPlan {
  const SourceImportCommitPlan({
    this.items = const <SourceImportCommitPlanItem>[],
    this.imported = 0,
    this.newCount = 0,
    this.updateCount = 0,
    this.existingCount = 0,
  });

  final List<SourceImportCommitPlanItem> items;
  final int imported;
  final int newCount;
  final int updateCount;
  final int existingCount;
}

class SourceImportSelectionHelper {
  static List<SourceImportCandidate> buildCandidates({
    required SourceImportResult result,
    required Map<String, BookSource> localMap,
  }) {
    final dedup = <String, SourceImportCandidate>{};
    for (final source in result.sources) {
      final url = source.bookSourceUrl.trim();
      if (url.isEmpty) continue;
      final existing = localMap[url];
      final state = existing == null
          ? SourceImportCandidateState.newSource
          : (source.lastUpdateTime > existing.lastUpdateTime
              ? SourceImportCandidateState.update
              : SourceImportCandidateState.existing);
      if (dedup.containsKey(url)) {
        dedup.remove(url);
      }
      dedup[url] = SourceImportCandidate(
        incoming: source,
        existing: existing,
        rawJson: result.rawJsonForSourceUrl(url) ??
            LegadoJson.encode(source.toJson()),
        state: state,
      );
    }
    return dedup.values.toList(growable: false);
  }

  static Set<String> defaultSelectedUrls(
      List<SourceImportCandidate> candidates) {
    final selected = <String>{};
    for (final candidate in candidates) {
      if (candidate.state == SourceImportCandidateState.existing) {
        continue;
      }
      selected.add(candidate.url);
    }
    return selected;
  }

  static bool areAllSelected({
    required List<SourceImportCandidate> candidates,
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
    required List<SourceImportCandidate> candidates,
    required Set<String> selectedUrls,
    required SourceImportCandidateState state,
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
    required List<SourceImportCandidate> candidates,
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
    required List<SourceImportCandidate> candidates,
    required Set<String> selectedUrls,
    required SourceImportCandidateState state,
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

  static SourceImportCommitPlan buildCommitPlan({
    required List<SourceImportCandidate> candidates,
    required SourceImportSelectionPolicy policy,
  }) {
    var newCount = 0;
    var updateCount = 0;
    var existingCount = 0;
    final items = <SourceImportCommitPlanItem>[];
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
        SourceImportCommitPlanItem(
          url: url,
          source: merged,
          rawJson: _buildRawJson(candidate.rawJson, merged),
          state: candidate.state,
        ),
      );
      switch (candidate.state) {
        case SourceImportCandidateState.newSource:
          newCount++;
        case SourceImportCandidateState.update:
          updateCount++;
        case SourceImportCandidateState.existing:
          existingCount++;
      }
    }
    return SourceImportCommitPlan(
      items: items,
      imported: items.length,
      newCount: newCount,
      updateCount: updateCount,
      existingCount: existingCount,
    );
  }

  static SourceImportCandidate? tryReplaceCandidateRawJson({
    required SourceImportCandidate candidate,
    required String rawJson,
  }) {
    final decoded = _decodeRawJson(rawJson);
    if (decoded == null) return null;

    final source = BookSource.fromJson(decoded);
    var incoming = source;
    final originalUrl = candidate.url;
    if (incoming.bookSourceUrl.trim().isEmpty && originalUrl.isNotEmpty) {
      incoming = incoming.copyWith(bookSourceUrl: originalUrl);
    }
    if (incoming.bookSourceName.trim().isEmpty) {
      incoming =
          incoming.copyWith(bookSourceName: candidate.incoming.bookSourceName);
    }

    final normalizedRaw = _buildRawJson(rawJson, incoming);
    return SourceImportCandidate(
      incoming: incoming,
      existing: candidate.existing,
      rawJson: normalizedRaw,
      state: candidate.state,
    );
  }

  static BookSource _applyPolicy(
    SourceImportCandidate candidate,
    SourceImportSelectionPolicy policy,
  ) {
    var source = candidate.incoming;
    final existing = candidate.existing;
    if (existing != null) {
      if (policy.keepName) {
        source = source.copyWith(bookSourceName: existing.bookSourceName);
      }
      if (policy.keepGroup) {
        source = source.copyWith(bookSourceGroup: existing.bookSourceGroup);
      }
      if (policy.keepEnabled) {
        source = source.copyWith(
          enabled: existing.enabled,
          enabledExplore: existing.enabledExplore,
        );
      }
      source = source.copyWith(customOrder: existing.customOrder);
    }
    final customGroup = policy.customGroup.trim();
    if (customGroup.isEmpty) {
      return source;
    }
    if (policy.appendCustomGroup) {
      final mergedGroups = <String>{};
      mergedGroups.addAll(_splitGroups(source.bookSourceGroup));
      mergedGroups.add(customGroup);
      return source.copyWith(bookSourceGroup: mergedGroups.join(','));
    }
    return source.copyWith(bookSourceGroup: customGroup);
  }

  static String _buildRawJson(String rawJson, BookSource source) {
    final rawMap = _decodeRawJson(rawJson);
    final map = rawMap ?? source.toJson();
    map['bookSourceUrl'] = source.bookSourceUrl;
    map['bookSourceName'] = source.bookSourceName;
    _setNullableString(map, 'bookSourceGroup', source.bookSourceGroup);
    map['enabled'] = source.enabled;
    map['enabledExplore'] = source.enabledExplore;
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

  static List<String> _splitGroups(String? raw) {
    final value = raw?.trim();
    if (value == null || value.isEmpty) return const <String>[];
    return value
        .split(RegExp(r'[,;，；]'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
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
