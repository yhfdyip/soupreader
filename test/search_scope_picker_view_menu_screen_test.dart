import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:soupreader/app/theme/shadcn_theme.dart';
import 'package:soupreader/features/search/views/search_scope_picker_view.dart';
import 'package:soupreader/features/source/models/book_source.dart';

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

BookSource _source({
  required String name,
  required String url,
  required String group,
  bool enabled = true,
  int order = 0,
}) {
  return BookSource(
    bookSourceName: name,
    bookSourceUrl: url,
    bookSourceGroup: group,
    enabled: enabled,
    customOrder: order,
  );
}

void main() {
  testWidgets('menu_screen 筛选仅在书源模式显示并按输入过滤书源', (tester) async {
    final sources = <BookSource>[
      _source(name: '甲源', url: 'https://a.example.com', group: '甲组', order: 0),
      _source(name: '乙源', url: 'https://b.example.com', group: '乙组', order: 1),
      _source(
        name: '停用乙源',
        url: 'https://c.example.com',
        group: '乙组',
        enabled: false,
        order: 2,
      ),
    ];
    final enabledSources = sources
        .where((source) => source.enabled == true)
        .toList(growable: false);

    await tester.pumpWidget(
      _buildTestApp(
        SearchScopePickerView(
          sources: sources,
          enabledSources: enabledSources,
        ),
      ),
    );
    await tester.pumpAndSettle();

    const fieldKey = Key('search_scope_menu_screen_field');
    expect(find.byKey(fieldKey), findsNothing);

    await tester.tap(find.text('书源'));
    await tester.pumpAndSettle();
    expect(find.byKey(fieldKey), findsOneWidget);

    await tester.enterText(find.byKey(fieldKey), '乙组');
    await tester.pumpAndSettle();

    expect(find.text('甲源'), findsNothing);
    expect(find.text('乙源'), findsOneWidget);
    expect(find.text('停用乙源'), findsOneWidget);
  });
}
