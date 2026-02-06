import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soupreader/main.dart';
import 'package:soupreader/core/database/database_service.dart';
import 'package:soupreader/core/services/settings_service.dart';

void main() {
  late Directory tempDir;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();

    SharedPreferences.setMockInitialValues(<String, Object>{});

    tempDir = await Directory.systemTemp.createTemp('soupreader_test_');
    const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, (MethodCall call) async {
      return tempDir.path;
    });

    await DatabaseService().init();
    await SettingsService().init();
  });

  tearDownAll(() async {
    try {
      await DatabaseService().close();
    } catch (_) {}
    try {
      await tempDir.delete(recursive: true);
    } catch (_) {}
  });

  testWidgets('App launches correctly', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const SoupReaderApp());

    // Verify that the app shows the bookshelf tab/content
    expect(find.text('书架'), findsWidgets);
  });
}
