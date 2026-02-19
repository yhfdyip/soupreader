class SourceDebugPrefixAction {
  const SourceDebugPrefixAction({
    required this.nextQuery,
    required this.shouldRun,
  });

  final String nextQuery;
  final bool shouldRun;
}

class SourceDebugQuickActionHelper {
  const SourceDebugQuickActionHelper._();

  static String normalizeStartKey(
    String raw, {
    String fallback = '',
  }) {
    final key = raw.trim();
    if (key.isNotEmpty) return key;
    return fallback.trim();
  }

  static SourceDebugPrefixAction applyPrefix({
    required String query,
    required String prefix,
  }) {
    final normalizedPrefix = prefix.trim();
    if (normalizedPrefix.isEmpty) {
      return SourceDebugPrefixAction(
        nextQuery: query.trim(),
        shouldRun: false,
      );
    }

    final normalizedQuery = query.trim();
    if (normalizedQuery.isEmpty || normalizedQuery.length <= 2) {
      return SourceDebugPrefixAction(
        nextQuery: normalizedPrefix,
        shouldRun: false,
      );
    }

    if (!normalizedQuery.startsWith(normalizedPrefix)) {
      return SourceDebugPrefixAction(
        nextQuery: '$normalizedPrefix$normalizedQuery',
        shouldRun: true,
      );
    }

    return SourceDebugPrefixAction(
      nextQuery: normalizedQuery,
      shouldRun: true,
    );
  }

  static String buildExploreRunKey({
    required String title,
    required String url,
  }) {
    final normalizedUrl = url.trim();
    final normalizedTitle = title.trim().isEmpty ? '发现' : title.trim();
    return '$normalizedTitle::$normalizedUrl';
  }
}
