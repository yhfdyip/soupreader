import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'package:soupreader/app/theme/shadcn_theme.dart';
import 'package:soupreader/core/services/settings_service.dart';
import 'package:soupreader/features/settings/views/global_reading_settings_view.dart';
import 'package:soupreader/features/settings/views/reading_behavior_settings_hub_view.dart';
import 'package:soupreader/features/settings/views/reading_interface_settings_hub_view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await SettingsService().init();
  });

  Future<void> pumpPage(WidgetTester tester, Widget child) async {
    final shadTheme = AppShadcnTheme.light();
    await tester.pumpWidget(
      ShadApp.custom(
        theme: shadTheme,
        darkTheme: shadTheme,
        appBuilder: (context) => CupertinoApp(
          home: child,
          builder: (context, page) => ShadAppBuilder(child: page!),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('GlobalReadingSettingsView 入口跳转层级与返回路径同义', (tester) async {
    await pumpPage(tester, const GlobalReadingSettingsView());

    await tester.tap(find.text('界面（样式）'));
    await tester.pumpAndSettle();
    expect(find.text('阅读视觉与排版'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('入口与阅读页保持一致'), findsOneWidget);

    await tester.tap(find.text('设置（行为）'));
    await tester.pumpAndSettle();
    expect(find.text('阅读行为与操作'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('入口与阅读页保持一致'), findsOneWidget);
  });

  testWidgets('ReadingInterfaceSettingsHubView 二级入口跳转与返回同义', (tester) async {
    await pumpPage(tester, const ReadingInterfaceSettingsHubView());

    await tester.tap(find.text('样式与排版'));
    await tester.pumpAndSettle();
    expect(find.text('主题'), findsOneWidget);
    expect(find.text('翻页模式'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('阅读视觉与排版'), findsOneWidget);

    await tester.tap(find.text('页眉页脚与标题'));
    await tester.pumpAndSettle();
    expect(find.text('章节标题位置'), findsOneWidget);
    expect(find.text('显示模式'), findsWidgets);
  });

  testWidgets('ReadingBehaviorSettingsHubView 二级入口跳转与返回同义', (tester) async {
    await pumpPage(tester, const ReadingBehaviorSettingsHubView());

    await tester.tap(find.text('翻页与按键'));
    await tester.pumpAndSettle();
    expect(find.text('翻页触发阈值'), findsOneWidget);
    expect(find.text('音量键翻页'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('阅读行为与操作'), findsOneWidget);

    await tester.tap(find.text('状态栏与操作'));
    await tester.pumpAndSettle();
    expect(find.text('点击区域（9 宫格）'), findsOneWidget);
    expect(find.text('显示亮度条'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('阅读行为与操作'), findsOneWidget);

    await tester.tap(find.text('其他阅读行为'));
    await tester.pumpAndSettle();
    expect(find.text('屏幕常亮'), findsOneWidget);
    expect(find.text('净化章节标题'), findsOneWidget);
  });
}
