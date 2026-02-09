class SourceQuickTestHelper {
  const SourceQuickTestHelper._();

  static String buildSearchKey({
    required String? checkKeyword,
    String fallback = '我的',
  }) {
    final key = checkKeyword?.trim() ?? '';
    if (key.isNotEmpty) return key;
    final fallbackKey = fallback.trim();
    return fallbackKey.isEmpty ? '我的' : fallbackKey;
  }

  static String? buildContentKey({required String? previewChapterUrl}) {
    final url = previewChapterUrl?.trim() ?? '';
    if (url.isEmpty) return null;
    if (url.startsWith('--')) return url;
    return '--$url';
  }
}
