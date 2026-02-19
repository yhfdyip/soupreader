import 'package:flutter_test/flutter_test.dart';
import 'package:soupreader/features/source/views/source_edit_legacy_view.dart';

void main() {
  test('SourceEditLegacyView 编译可用', () {
    expect(
      () => const SourceEditLegacyView(
        initialRawJson: '{"bookSourceUrl":"","bookSourceName":""}',
      ),
      returnsNormally,
    );
  });
}
