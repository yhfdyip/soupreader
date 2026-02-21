import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:soupreader/app/theme/shadcn_theme.dart';
import 'package:soupreader/core/database/database_service.dart';
import 'package:soupreader/core/services/settings_service.dart';
import 'package:soupreader/features/source/views/source_list_view.dart';

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
    SharedPreferences.setMockInitialValues(<String, Object>{
      'source_manage_help_shown_v1': true,
    });

    tempDir = await Directory.systemTemp.createTemp(
      'soupreader_source_sort_menu_',
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
    SharedPreferences.setMockInitialValues(<String, Object>{
      'source_manage_help_shown_v1': true,
    });
    await SettingsService().init();
  });

  testWidgets('书源管理顶栏排序入口会打开排序菜单', (WidgetTester tester) async {
    await tester.pumpWidget(_buildTestApp(const SourceListView()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    final sortAction = find.byIcon(CupertinoIcons.arrow_up_arrow_down);
    expect(sortAction, findsOneWidget);

    await tester.tap(sortAction);
    await tester.pumpAndSettle();

    expect(find.widgetWithText(CupertinoActionSheet, '排序'), findsOneWidget);
  });

  testWidgets('书源管理反序菜单项为勾选态切换语义', (WidgetTester tester) async {
    await tester.pumpWidget(_buildTestApp(const SourceListView()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    final sortAction = find.byIcon(CupertinoIcons.arrow_up_arrow_down);
    expect(sortAction, findsOneWidget);

    await tester.tap(sortAction);
    await tester.pumpAndSettle();

    final reverseUnchecked = find.widgetWithText(
      CupertinoActionSheetAction,
      '反序',
    );
    expect(reverseUnchecked, findsOneWidget);
    expect(
      find.widgetWithText(CupertinoActionSheetAction, '✓ 反序'),
      findsNothing,
    );

    await tester.tap(reverseUnchecked);
    await tester.pumpAndSettle();

    await tester.tap(sortAction);
    await tester.pumpAndSettle();
    expect(
      find.widgetWithText(CupertinoActionSheetAction, '✓ 反序'),
      findsOneWidget,
    );
  });

  testWidgets('书源管理智能排序菜单项保持单选勾选语义', (WidgetTester tester) async {
    await tester.pumpWidget(_buildTestApp(const SourceListView()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    final sortAction = find.byIcon(CupertinoIcons.arrow_up_arrow_down);
    expect(sortAction, findsOneWidget);

    await tester.tap(sortAction);
    await tester.pumpAndSettle();

    final autoSortUnchecked = find.widgetWithText(
      CupertinoActionSheetAction,
      '智能排序',
    );
    expect(autoSortUnchecked, findsOneWidget);
    expect(
      find.widgetWithText(CupertinoActionSheetAction, '✓ 智能排序'),
      findsNothing,
    );

    await tester.tap(autoSortUnchecked);
    await tester.pumpAndSettle();

    await tester.tap(sortAction);
    await tester.pumpAndSettle();
    expect(
      find.widgetWithText(CupertinoActionSheetAction, '✓ 智能排序'),
      findsOneWidget,
    );
    expect(
      find.widgetWithText(CupertinoActionSheetAction, '✓ 手动排序'),
      findsNothing,
    );
  });

  testWidgets('书源管理手动排序菜单项保持单选勾选语义', (WidgetTester tester) async {
    await tester.pumpWidget(_buildTestApp(const SourceListView()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    final sortAction = find.byIcon(CupertinoIcons.arrow_up_arrow_down);
    expect(sortAction, findsOneWidget);

    await tester.tap(sortAction);
    await tester.pumpAndSettle();

    await tester.tap(
      find.widgetWithText(CupertinoActionSheetAction, '智能排序'),
    );
    await tester.pumpAndSettle();

    await tester.tap(sortAction);
    await tester.pumpAndSettle();
    expect(
      find.widgetWithText(CupertinoActionSheetAction, '✓ 智能排序'),
      findsOneWidget,
    );
    expect(
      find.widgetWithText(CupertinoActionSheetAction, '✓ 手动排序'),
      findsNothing,
    );

    await tester.tap(
      find.widgetWithText(CupertinoActionSheetAction, '手动排序'),
    );
    await tester.pumpAndSettle();

    await tester.tap(sortAction);
    await tester.pumpAndSettle();
    expect(
      find.widgetWithText(CupertinoActionSheetAction, '✓ 手动排序'),
      findsOneWidget,
    );
    expect(
      find.widgetWithText(CupertinoActionSheetAction, '✓ 智能排序'),
      findsNothing,
    );
  });
}
