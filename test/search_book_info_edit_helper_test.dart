import 'package:flutter_test/flutter_test.dart';
import 'package:soupreader/features/bookshelf/models/book.dart';
import 'package:soupreader/features/search/services/search_book_info_edit_helper.dart';

void main() {
  test('SearchBookInfoEditHelper.fromBook 生成编辑草稿', () {
    const book = Book(
      id: 'book-1',
      title: '原书名',
      author: '原作者',
      coverUrl: 'https://example.com/cover.jpg',
      intro: '原简介',
    );

    final draft = SearchBookInfoEditHelper.fromBook(book);
    expect(draft.name, '原书名');
    expect(draft.author, '原作者');
    expect(draft.coverUrl, 'https://example.com/cover.jpg');
    expect(draft.intro, '原简介');
  });

  test('SearchBookInfoEditHelper.applyDraft 按规则覆盖字段', () {
    const original = Book(
      id: 'book-2',
      title: '旧书名',
      author: '旧作者',
      coverUrl: 'https://example.com/old.jpg',
      intro: '旧简介',
      latestChapter: '第10章',
    );
    const draft = SearchBookInfoEditDraft(
      name: '  新书名  ',
      author: '   ',
      coverUrl: '  ',
      intro: '  新简介  ',
    );

    final updated = SearchBookInfoEditHelper.applyDraft(
      original: original,
      draft: draft,
    );

    expect(updated.title, '新书名');
    // 对齐 legado：作者输入为空白时保存为空字符串，不回退旧值。
    expect(updated.author, '');
    // 封面空白时清空（对齐编辑页“删除覆盖值”语义）
    expect(updated.coverUrl, isNull);
    expect(updated.intro, '新简介');
    // 未编辑字段保持不变
    expect(updated.latestChapter, '第10章');
  });
}
