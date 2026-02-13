import 'package:flutter/foundation.dart';

class SourceAvailabilitySummary {
  final DateTime finishedAt;
  final bool includeDisabled;
  final String? keyword;
  final int total;
  final int available;
  final int failed;
  final int empty;
  final int timeout;
  final int skipped;
  final List<String> failedSourceUrls;

  const SourceAvailabilitySummary({
    required this.finishedAt,
    required this.includeDisabled,
    required this.keyword,
    required this.total,
    required this.available,
    required this.failed,
    required this.empty,
    required this.timeout,
    required this.skipped,
    required this.failedSourceUrls,
  });

  int get failedLikeCount => failed + empty;
}

class SourceAvailabilitySummaryStore {
  SourceAvailabilitySummaryStore._();

  static final SourceAvailabilitySummaryStore instance =
      SourceAvailabilitySummaryStore._();

  final ValueNotifier<SourceAvailabilitySummary?> _notifier =
      ValueNotifier<SourceAvailabilitySummary?>(null);

  ValueListenable<SourceAvailabilitySummary?> get listenable => _notifier;

  SourceAvailabilitySummary? get latest => _notifier.value;

  void update(SourceAvailabilitySummary summary) {
    _notifier.value = summary;
  }

  void clear() {
    _notifier.value = null;
  }
}
