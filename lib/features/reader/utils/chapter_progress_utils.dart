class ChapterProgressUtils {
  const ChapterProgressUtils._();

  static double pageProgressFromIndex({
    required int pageIndex,
    required int totalPages,
  }) {
    if (totalPages <= 0) return 0.0;
    final clampedIndex = pageIndex.clamp(0, totalPages - 1);
    return ((clampedIndex + 1) / totalPages).clamp(0.0, 1.0);
  }

  static int pageIndexFromProgress({
    required double progress,
    required int totalPages,
  }) {
    if (totalPages <= 0) return 0;
    final normalized = progress.clamp(0.0, 1.0).toDouble();
    final page = (normalized * totalPages).ceil().clamp(1, totalPages);
    return page - 1;
  }
}
