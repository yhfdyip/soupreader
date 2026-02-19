import 'package:flutter_test/flutter_test.dart';
import 'package:soupreader/features/source/views/source_qr_share_view.dart';

void main() {
  test('SourceQrShareView 编译可用', () {
    expect(
      () => const SourceQrShareView(
        text: '{"bookSourceUrl":"https://a","bookSourceName":"A"}',
        subject: 'A',
      ),
      returnsNormally,
    );
  });
}
