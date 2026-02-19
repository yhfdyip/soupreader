import 'package:flutter_test/flutter_test.dart';
import 'package:soupreader/features/source/views/source_edit_view.dart';

void main() {
  test('SourceEditView 编译可用', () {
    expect(
      () => const SourceEditView(
        initialRawJson: '{"bookSourceUrl":"","bookSourceName":""}',
      ),
      returnsNormally,
    );
  });
}
