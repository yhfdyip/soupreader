import 'package:flutter_test/flutter_test.dart';

import 'package:soupreader/features/bookshelf/views/bookshelf_view.dart';

void main() {
  test('BookshelfView 编译可用', () {
    expect(() => const BookshelfView(), returnsNormally);
  });
}
