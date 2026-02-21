import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:soupreader/app/theme/shadcn_theme.dart';
import 'package:soupreader/core/database/database_service.dart';
import 'package:soupreader/core/models/app_settings.dart';
import 'package:soupreader/core/services/settings_service.dart';
import 'package:soupreader/features/search/views/search_view.dart';

Widget _buildTestApp(Widget home) {
  final shadTheme = AppShadcnTheme.light();
  return ShadApp.custom(
    theme: shadTheme,
    darkTheme: shadTheme,
    appBuilder: (context) {
      final shad = ShadTheme.of(context);
      final cupertinoTheme = CupertinoTheme.of(context).copyWith(
        barBackgroundColor: shad.colorScheme.background.withValues(alpha: 0.92),
      );
      return CupertinoApp(
        theme: cupertinoTheme,
        home: home,
        builder: (context, child) => ShadAppBuilder(child: child!),
      );
    },
  );
}

void main() {
  late Directory tempDir;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues(<String, Object>{});

    tempDir = await Directory.systemTemp.createTemp(
      'soupreader_search_precision_menu_',
    );
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
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

  setUp(() async {
    await DatabaseService().clearAll();
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await SettingsService().init();
  });

  testWidgets('搜索设置里的精准搜索采用勾选态并可持久化',
      (WidgetTester tester) async {
    final settings = SettingsService();
    await settings.saveAppSettings(
      settings.appSettings.copyWith(searchFilterMode: SearchFilterMode.normal),
    );

    await tester.pumpWidget(_buildTestApp(const SearchView()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    final settingsAction = find.byIcon(CupertinoIcons.slider_horizontal_3);
    expect(settingsAction, findsOneWidget);

    await tester.tap(settingsAction);
    await tester.pumpAndSettle();

    final precisionAction =
        find.widgetWithText(CupertinoActionSheetAction, '精准搜索');
    expect(precisionAction, findsOneWidget);
    expect(
      find.descendant(
        of: precisionAction,
        matching: find.byIcon(CupertinoIcons.check_mark),
      ),
      findsNothing,
    );

    await tester.tap(precisionAction);
    await tester.pumpAndSettle();

    expect(
      settings.appSettings.searchFilterMode,
      SearchFilterMode.precise,
    );

    await tester.tap(settingsAction);
    await tester.pumpAndSettle();

    final checkedPrecisionAction =
        find.widgetWithText(CupertinoActionSheetAction, '精准搜索');
    expect(checkedPrecisionAction, findsOneWidget);
    expect(
      find.descendant(
        of: checkedPrecisionAction,
        matching: find.byIcon(CupertinoIcons.check_mark),
      ),
      findsOneWidget,
    );
  });
}
