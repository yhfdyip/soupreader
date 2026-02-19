import 'package:flutter_test/flutter_test.dart';
import 'package:soupreader/features/source/models/book_source.dart';
import 'package:soupreader/features/source/views/source_debug_legacy_view.dart';

void main() {
  test('SourceDebugLegacyView 编译可用', () {
    expect(
      () => SourceDebugLegacyView(
        source: const BookSource(
          bookSourceUrl: 'https://example.com',
          bookSourceName: '测试书源',
        ),
      ),
      returnsNormally,
    );
  });
}
