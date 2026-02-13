import 'package:flutter/foundation.dart';

import 'source_debug_key_parser.dart';

class SourceDebugSummary {
  final DateTime finishedAt;
  final String sourceUrl;
  final String sourceName;
  final String key;
  final SourceDebugIntentType intentType;
  final bool success;
  final String? debugError;
  final String primaryDiagnosis;
  final List<String> diagnosisLabels;
  final List<String> diagnosisHints;

  const SourceDebugSummary({
    required this.finishedAt,
    required this.sourceUrl,
    required this.sourceName,
    required this.key,
    required this.intentType,
    required this.success,
    required this.debugError,
    required this.primaryDiagnosis,
    required this.diagnosisLabels,
    required this.diagnosisHints,
  });
}

class SourceDebugSummaryStore {
  SourceDebugSummaryStore._();

  static final SourceDebugSummaryStore instance = SourceDebugSummaryStore._();

  static const int _maxHistory = 100;

  final ValueNotifier<List<SourceDebugSummary>> _notifier =
      ValueNotifier<List<SourceDebugSummary>>(<SourceDebugSummary>[]);

  ValueListenable<List<SourceDebugSummary>> get listenable => _notifier;

  List<SourceDebugSummary> get history => _notifier.value;

  SourceDebugSummary? get latest =>
      _notifier.value.isEmpty ? null : _notifier.value.first;

  void push(SourceDebugSummary summary) {
    final next = <SourceDebugSummary>[summary, ..._notifier.value];
    if (next.length > _maxHistory) {
      next.removeRange(_maxHistory, next.length);
    }
    _notifier.value = next;
  }

  Set<String> failedSourceUrls() {
    final latestBySource = <String, SourceDebugSummary>{};
    for (final item in _notifier.value) {
      latestBySource.putIfAbsent(item.sourceUrl, () => item);
    }
    return latestBySource.values
        .where((item) => !item.success)
        .map((item) => item.sourceUrl)
        .toSet();
  }

  void clear() {
    _notifier.value = <SourceDebugSummary>[];
  }
}
