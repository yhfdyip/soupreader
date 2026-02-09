import 'package:flutter_test/flutter_test.dart';

import 'package:soupreader/features/reader/utils/chapter_progress_utils.dart';

void main() {
  test('pageProgressFromIndex maps page index to 0..1 progress', () {
    expect(
      ChapterProgressUtils.pageProgressFromIndex(
        pageIndex: 0,
        totalPages: 10,
      ),
      closeTo(0.1, 1e-9),
    );
    expect(
      ChapterProgressUtils.pageProgressFromIndex(
        pageIndex: 9,
        totalPages: 10,
      ),
      closeTo(1.0, 1e-9),
    );
    expect(
      ChapterProgressUtils.pageProgressFromIndex(
        pageIndex: 100,
        totalPages: 10,
      ),
      closeTo(1.0, 1e-9),
    );
  });

  test('pageIndexFromProgress maps progress to readable page index', () {
    expect(
      ChapterProgressUtils.pageIndexFromProgress(
        progress: 0.0,
        totalPages: 10,
      ),
      0,
    );
    expect(
      ChapterProgressUtils.pageIndexFromProgress(
        progress: 0.1,
        totalPages: 10,
      ),
      0,
    );
    expect(
      ChapterProgressUtils.pageIndexFromProgress(
        progress: 0.55,
        totalPages: 10,
      ),
      5,
    );
    expect(
      ChapterProgressUtils.pageIndexFromProgress(
        progress: 1.0,
        totalPages: 10,
      ),
      9,
    );
  });

  test('progress-index conversion is stable within one page', () {
    const totalPages = 13;
    for (var pageIndex = 0; pageIndex < totalPages; pageIndex++) {
      final progress = ChapterProgressUtils.pageProgressFromIndex(
        pageIndex: pageIndex,
        totalPages: totalPages,
      );
      final restored = ChapterProgressUtils.pageIndexFromProgress(
        progress: progress,
        totalPages: totalPages,
      );
      expect(restored, pageIndex);
    }
  });
}
