import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:soupreader/features/reader/models/reading_settings.dart';
import 'package:soupreader/features/reader/widgets/page_factory.dart';
import 'package:soupreader/features/reader/widgets/paged_reader_widget.dart';

PageFactory _buildFactory() {
  final factory = PageFactory();
  final content = List<String>.filled(240, '这是一段用于翻页视觉回归的测试文本。').join('\n');
  factory.setChapters(
    <ChapterData>[
      ChapterData(title: '第一章', content: content),
    ],
    0,
  );
  factory.setLayoutParams(
    contentHeight: 120,
    contentWidth: 220,
    fontSize: 20,
    lineHeight: 1.4,
  );
  factory.paginateAll();
  return factory;
}

Widget _buildReader({
  required PageFactory factory,
  required PageTurnMode mode,
  int animDuration = 300,
}) {
  return Directionality(
    textDirection: TextDirection.ltr,
    child: MediaQuery(
      data: const MediaQueryData(size: Size(390, 844)),
      child: SizedBox(
        width: 390,
        height: 844,
        child: PagedReaderWidget(
          pageFactory: factory,
          pageTurnMode: mode,
          textStyle: const TextStyle(
            fontSize: 20,
            color: Color(0xFF222222),
          ),
          backgroundColor: const Color(0xFFFAF7F0),
          settings: ReadingSettings(pageTurnMode: mode, showStatusBar: false),
          bookTitle: '测试书',
          showStatusBar: false,
          animDuration: animDuration,
        ),
      ),
    ),
  );
}

Future<void> _dragAndRelease(
  WidgetTester tester, {
  required Offset start,
  required List<Offset> deltas,
}) async {
  final gesture = await tester.startGesture(start);
  for (final delta in deltas) {
    await gesture.moveBy(delta);
    await tester.pump();
  }
  await gesture.up();
  await tester.pump();
}

Future<void> _finishTurnAnimation(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 360));
  await tester.pump(const Duration(milliseconds: 32));
}

void main() {
  testWidgets('none 模式点击翻页应立即生效（无过渡动画）', (tester) async {
    final factory = _buildFactory();
    expect(factory.totalPages, greaterThan(1));

    await tester.pumpWidget(
      _buildReader(
        factory: factory,
        mode: PageTurnMode.none,
        animDuration: 600,
      ),
    );
    await tester.pump();

    expect(factory.currentPageIndex, 0);

    await tester.tapAt(const Offset(370, 420));
    await tester.pump();
    expect(factory.currentPageIndex, 1);

    // 无动画模式不应依赖 600ms 动画时长，下一帧仍保持已翻页状态。
    await tester.pump(const Duration(milliseconds: 16));
    expect(factory.currentPageIndex, 1);
  });

  testWidgets('slide 模式拖拽取消应保持当前页', (tester) async {
    final factory = _buildFactory();
    await tester.pumpWidget(
      _buildReader(
        factory: factory,
        mode: PageTurnMode.slide,
      ),
    );
    await tester.pump();

    expect(factory.currentPageIndex, 0);
    await _dragAndRelease(
      tester,
      start: const Offset(340, 420),
      deltas: const [Offset(-220, 0), Offset(120, 0)],
    );
    await _finishTurnAnimation(tester);
    expect(factory.currentPageIndex, 0);
  });

  testWidgets('slide 模式点击翻页应支持前进和后退', (tester) async {
    final factory = _buildFactory();
    await tester.pumpWidget(
      _buildReader(
        factory: factory,
        mode: PageTurnMode.slide,
      ),
    );
    await tester.pump();

    expect(factory.currentPageIndex, 0);
    await tester.tapAt(const Offset(370, 420));
    await tester.pump();
    await _finishTurnAnimation(tester);
    expect(factory.currentPageIndex, 1);

    await tester.tapAt(const Offset(20, 420));
    await tester.pump();
    await _finishTurnAnimation(tester);
    expect(factory.currentPageIndex, 0);
  });

  testWidgets('cover 模式拖拽取消应保持当前页', (tester) async {
    final factory = _buildFactory();
    await tester.pumpWidget(
      _buildReader(
        factory: factory,
        mode: PageTurnMode.cover,
      ),
    );
    await tester.pump();

    expect(factory.currentPageIndex, 0);
    await _dragAndRelease(
      tester,
      start: const Offset(340, 420),
      deltas: const [Offset(-220, 0), Offset(120, 0)],
    );
    await _finishTurnAnimation(tester);
    expect(factory.currentPageIndex, 0);
  });

  testWidgets('cover 模式点击翻页应支持前进和后退', (tester) async {
    final factory = _buildFactory();
    await tester.pumpWidget(
      _buildReader(
        factory: factory,
        mode: PageTurnMode.cover,
      ),
    );
    await tester.pump();

    expect(factory.currentPageIndex, 0);
    await tester.tapAt(const Offset(370, 420));
    await tester.pump();
    await _finishTurnAnimation(tester);
    expect(factory.currentPageIndex, 1);

    await tester.tapAt(const Offset(20, 420));
    await tester.pump();
    await _finishTurnAnimation(tester);
    expect(factory.currentPageIndex, 0);
  });
}
