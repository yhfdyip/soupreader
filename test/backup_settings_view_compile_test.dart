import 'package:flutter_test/flutter_test.dart';

import 'package:soupreader/features/settings/views/backup_settings_view.dart';

void main() {
  test('BackupSettingsView 编译可用', () {
    expect(
      () => const BackupSettingsView(),
      returnsNormally,
    );
  });
}
