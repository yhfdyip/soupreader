import 'package:flutter_test/flutter_test.dart';

import 'package:soupreader/features/reader/widgets/page_factory.dart';

void main() {
  PageFactory buildFactory() {
    final factory = PageFactory();
    factory.setChapters(
      <ChapterData>[
        ChapterData(title: '第一章', content: '第一章正文'),
        ChapterData(title: '第二章', content: '第二章正文'),
      ],
      0,
    );
    factory.setLayoutParams(
      contentHeight: 800,
      contentWidth: 400,
      fontSize: 18,
    );
    factory.paginateAll();
    return factory;
  }

  test('page factory notifies all content changed listeners', () {
    final factory = buildFactory();
    var first = 0;
    var second = 0;
    void firstListener() => first++;
    void secondListener() => second++;

    factory.addContentChangedListener(firstListener);
    factory.addContentChangedListener(secondListener);

    factory.jumpToPage(0);

    expect(first, 1);
    expect(second, 1);
  });

  test('removed listener will not receive notifications', () {
    final factory = buildFactory();
    var first = 0;
    var second = 0;
    void firstListener() => first++;
    void secondListener() => second++;

    factory.addContentChangedListener(firstListener);
    factory.addContentChangedListener(secondListener);
    factory.removeContentChangedListener(firstListener);

    factory.jumpToPage(0);

    expect(first, 0);
    expect(second, 1);
  });

  test('legacy onContentChanged callback still works with listeners', () {
    final factory = buildFactory();
    var legacy = 0;
    var modern = 0;

    factory.onContentChanged = () => legacy++;
    factory.addContentChangedListener(() => modern++);

    factory.jumpToPage(0);

    expect(legacy, 1);
    expect(modern, 1);
  });
}
