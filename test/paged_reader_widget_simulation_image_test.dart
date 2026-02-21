import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:soupreader/features/reader/models/reading_settings.dart';
import 'package:soupreader/features/reader/services/reader_image_marker_codec.dart';
import 'package:soupreader/features/reader/widgets/page_factory.dart';
import 'package:soupreader/features/reader/widgets/paged_reader_widget.dart';

PageFactory _buildFactoryWithImageMarker() {
  final marker = ReaderImageMarkerCodec.encode(
    'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/w8AAusB9Y8Zs2gAAAAASUVORK5CYII=',
    width: 600,
    height: 400,
  );
  final content = [
    ...List<String>.filled(80, '用于填充章节正文的测试文本。'),
    marker,
    ...List<String>.filled(80, '用于翻页后续页面的测试文本。'),
  ].join('\n');

  final factory = PageFactory();
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
    legacyImageStyle: 'SINGLE',
  );
  factory.paginateAll();
  return factory;
}

Widget _buildReader({
  required PageFactory factory,
  required PageTurnMode mode,
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
          animDuration: 300,
          legacyImageStyle: 'SINGLE',
        ),
      ),
    ),
  );
}

Future<void> _finishSimulationTurn(WidgetTester tester) async {
  // 包含帧准备等待窗口（最多 1800ms）+ 动画时长
  await tester.pump(const Duration(milliseconds: 2100));
  await tester.pump(const Duration(milliseconds: 48));
}

void main() {
  testWidgets('simulation 模式在图片页附近仍可完成翻页', (tester) async {
    final factory = _buildFactoryWithImageMarker();
    expect(factory.totalPages, greaterThan(1));

    await tester.pumpWidget(
      _buildReader(
        factory: factory,
        mode: PageTurnMode.simulation,
      ),
    );
    await tester.pump();
    expect(factory.currentPageIndex, 0);

    await tester.tapAt(const Offset(370, 420));
    await tester.pump();
    await _finishSimulationTurn(tester);

    expect(factory.currentPageIndex, 1);
  });
}
