import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'package:soupreader/app/theme/shadcn_theme.dart';
import 'package:soupreader/core/services/settings_service.dart';
import 'package:soupreader/features/settings/views/reading_other_settings_view.dart';
import 'package:soupreader/features/settings/views/reading_page_settings_view.dart';
import 'package:soupreader/features/settings/views/reading_status_action_settings_view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await SettingsService().init();
  });

  Future<void> pumpSettingsPage(WidgetTester tester, Widget child) async {
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

  testWidgets('ReadingPageSettingsView 保持翻页与按键条目归类', (tester) async {
    await pumpSettingsPage(tester, const ReadingPageSettingsView());

    expect(find.text('翻页触发阈值'), findsOneWidget);
    expect(find.text('滚动翻页无动画'), findsOneWidget);
    expect(find.text('音量键翻页'), findsOneWidget);
    expect(find.text('鼠标滚轮翻页'), findsOneWidget);
    expect(find.text('长按按键翻页'), findsOneWidget);
    expect(find.text('净化章节标题'), findsNothing);
  });

  testWidgets('ReadingStatusActionSettingsView 补齐导航栏与亮度条入口', (tester) async {
    await pumpSettingsPage(tester, const ReadingStatusActionSettingsView());

    expect(find.text('隐藏导航栏'), findsOneWidget);
    expect(find.text('显示亮度条'), findsOneWidget);
    expect(find.text('点击区域（9 宫格）'), findsOneWidget);
  });

  testWidgets('ReadingOtherSettingsView 保留方向与文本处理分组', (tester) async {
    await pumpSettingsPage(tester, const ReadingOtherSettingsView());

    expect(find.text('屏幕方向'), findsOneWidget);
    expect(find.text('禁用返回键'), findsOneWidget);
    expect(find.text('简繁转换'), findsOneWidget);
    expect(find.text('净化章节标题'), findsOneWidget);
    expect(find.text('屏幕常亮'), findsOneWidget);
  });
}
