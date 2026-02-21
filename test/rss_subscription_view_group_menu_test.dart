import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:soupreader/app/theme/shadcn_theme.dart';
import 'package:soupreader/core/database/repositories/rss_source_repository.dart';
import 'package:soupreader/features/rss/models/rss_source.dart';
import 'package:soupreader/features/rss/services/rss_source_filter_helper.dart';
import 'package:soupreader/features/rss/views/rss_subscription_view.dart';

class _FakeRssSourceRepository implements RssSourceRepository {
  _FakeRssSourceRepository(List<RssSource> sources)
      : _sources = List<RssSource>.from(sources);

  final List<RssSource> _sources;
  final StreamController<List<RssSource>> _controller =
      StreamController<List<RssSource>>.broadcast();

  List<RssSource> _sorted() {
    return RssSourceFilterHelper.sortByCustomOrder(_sources);
  }

  void _emit() {
    if (_controller.isClosed) return;
    _controller.add(_sorted());
  }

  @override
  List<RssSource> getAllSources() => _sorted();

  @override
  Stream<List<RssSource>> watchAllSources() async* {
    yield _sorted();
    yield* _controller.stream;
  }

  @override
  int get minOrder {
    if (_sources.isEmpty) return 0;
    return _sources
        .map((source) => source.customOrder)
        .reduce((left, right) => left < right ? left : right);
  }

  @override
  Future<void> updateSource(RssSource source) async {
    final index = _sources.indexWhere((it) => it.sourceUrl == source.sourceUrl);
    if (index >= 0) {
      _sources[index] = source;
    } else {
      _sources.add(source);
    }
    _emit();
  }

  @override
  Future<void> deleteSource(String sourceUrl) async {
    _sources.removeWhere((it) => it.sourceUrl == sourceUrl);
    _emit();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

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
  testWidgets('RSS 分组菜单仅展示启用分组并回填 group: 查询', (WidgetTester tester) async {
    const enabledGroupA = '测试分组A';
    const enabledGroupB = '测试分组B';
    const disabledGroup = '禁用分组';

    final repository = _FakeRssSourceRepository(const [
      RssSource(
        sourceUrl: 'https://rss.example.com/a',
        sourceName: '测试源A',
        sourceGroup: enabledGroupA,
        enabled: true,
        customOrder: 1,
      ),
      RssSource(
        sourceUrl: 'https://rss.example.com/b',
        sourceName: '测试源B',
        sourceGroup: enabledGroupB,
        enabled: true,
        customOrder: 2,
      ),
      RssSource(
        sourceUrl: 'https://rss.example.com/c',
        sourceName: '测试源C',
        sourceGroup: disabledGroup,
        enabled: false,
        customOrder: 3,
      ),
    ]);

    await tester.pumpWidget(
      _buildTestApp(RssSubscriptionView(repository: repository)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    await tester.tap(find.byIcon(CupertinoIcons.folder));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.text('全部'), findsNothing);
    expect(
      find.widgetWithText(CupertinoActionSheetAction, enabledGroupA),
      findsOneWidget,
    );
    expect(
      find.widgetWithText(CupertinoActionSheetAction, enabledGroupB),
      findsOneWidget,
    );
    expect(
      find.widgetWithText(CupertinoActionSheetAction, disabledGroup),
      findsNothing,
    );

    await tester.tap(
      find.widgetWithText(CupertinoActionSheetAction, enabledGroupA),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.text('筛选：group:$enabledGroupA'), findsOneWidget);
  });
}
