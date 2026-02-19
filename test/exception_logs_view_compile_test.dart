import 'package:flutter_test/flutter_test.dart';

import 'package:soupreader/features/settings/views/exception_logs_view.dart';

void main() {
  test('ExceptionLogsView 编译可用', () {
    expect(
      () => const ExceptionLogsView(),
      returnsNormally,
    );
  });
}
