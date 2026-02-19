import 'package:flutter_test/flutter_test.dart';
import 'package:soupreader/features/rss/views/rss_source_manage_view.dart';

void main() {
  test('RssSourceManageView 编译可用', () {
    expect(
      () => const RssSourceManageView(),
      returnsNormally,
    );
  });
}
