import 'package:flutter_test/flutter_test.dart';

import 'package:soupreader/features/source/services/source_quick_test_helper.dart';

void main() {
  test('buildSearchKey prefers non-empty checkKeyword', () {
    final key =
        SourceQuickTestHelper.buildSearchKey(checkKeyword: '  仙逆  ');
    expect(key, '仙逆');
  });

  test('buildSearchKey falls back to default when empty', () {
    final key = SourceQuickTestHelper.buildSearchKey(checkKeyword: '   ');
    expect(key, '我的');
  });

  test('buildContentKey returns null when preview url missing', () {
    final key = SourceQuickTestHelper.buildContentKey(previewChapterUrl: null);
    expect(key, isNull);
  });

  test('buildContentKey prefixes preview url with --', () {
    final key = SourceQuickTestHelper.buildContentKey(
      previewChapterUrl: '  https://example.com/chapter/1  ',
    );
    expect(key, '--https://example.com/chapter/1');
  });

  test('buildContentKey keeps existing -- prefix', () {
    final key = SourceQuickTestHelper.buildContentKey(
      previewChapterUrl: '--https://example.com/chapter/2',
    );
    expect(key, '--https://example.com/chapter/2');
  });
}
