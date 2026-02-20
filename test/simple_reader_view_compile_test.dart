import 'package:flutter_test/flutter_test.dart';
import 'package:soupreader/features/reader/views/simple_reader_view.dart';

void main() {
  test('SimpleReaderView 构造器可编译', () {
    const view = SimpleReaderView(
      bookId: 'book-1',
      bookTitle: '测试书籍',
    );
    expect(view.bookId, 'book-1');
    expect(view.bookTitle, '测试书籍');
  });
}
