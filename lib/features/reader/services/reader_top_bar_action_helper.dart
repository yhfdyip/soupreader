class ReaderTopBarActionHelper {
  const ReaderTopBarActionHelper._();

  static final RegExp _absUrlRegex = RegExp(
    r'^[a-z][a-z0-9+\-.]*://',
    caseSensitive: false,
  );

  static String normalizeChapterUrl(String? raw) {
    final text = (raw ?? '').trim();
    if (text.isEmpty) return '';
    // Legacy trims chapter url suffix after `,{` before opening in browser.
    return text.split(',{').first.trim();
  }

  static String resolveChapterUrl({
    required String? chapterUrl,
    String? bookUrl,
    String? sourceUrl,
  }) {
    final normalized = normalizeChapterUrl(chapterUrl);
    if (normalized.isEmpty) return '';

    final lower = normalized.toLowerCase();
    if (_absUrlRegex.hasMatch(normalized) || lower.startsWith('data:')) {
      return normalized;
    }
    if (lower.startsWith('javascript:')) {
      return '';
    }

    for (final candidate in <String?>[bookUrl, sourceUrl]) {
      final base = normalizeChapterUrl(candidate);
      if (base.isEmpty) continue;
      final baseUri = Uri.tryParse(base);
      if (baseUri == null || !baseUri.hasScheme) continue;
      try {
        return baseUri.resolve(normalized).toString();
      } catch (_) {
        // ignore and fallback to next candidate
      }
    }
    return normalized;
  }

  static bool isHttpUrl(String? raw) {
    final text = normalizeChapterUrl(raw);
    if (text.isEmpty) return false;
    final uri = Uri.tryParse(text);
    final scheme = uri?.scheme.toLowerCase();
    return scheme == 'http' || scheme == 'https';
  }
}
