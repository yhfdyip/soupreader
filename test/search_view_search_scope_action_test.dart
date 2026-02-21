import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:soupreader/app/theme/shadcn_theme.dart';
import 'package:soupreader/core/database/database_service.dart';
import 'package:soupreader/core/services/settings_service.dart';
import 'package:soupreader/features/search/views/search_scope_picker_view.dart';
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
      'soupreader_search_scope_menu_',
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

  testWidgets('搜索设置里的多分组/书源入口会打开搜索范围页', (WidgetTester tester) async {
    await tester.pumpWidget(_buildTestApp(const SearchView()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    final settingsAction = find.byIcon(CupertinoIcons.slider_horizontal_3);
    expect(settingsAction, findsOneWidget);

    await tester.tap(settingsAction);
    await tester.pumpAndSettle();

    final scopeAction = find.widgetWithText(
      CupertinoActionSheetAction,
      '多分组/书源',
    );
    expect(scopeAction, findsOneWidget);

    await tester.tap(scopeAction);
    await tester.pumpAndSettle();

    expect(find.byType(SearchScopePickerView), findsOneWidget);
    expect(find.text('搜索范围'), findsOneWidget);
  });
}
