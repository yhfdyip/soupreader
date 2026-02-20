import '../../bookshelf/models/book.dart';

class SearchBookInfoEditDraft {
  final String name;
  final String author;
  final String coverUrl;
  final String intro;

  const SearchBookInfoEditDraft({
    required this.name,
    required this.author,
    required this.coverUrl,
    required this.intro,
  });

  SearchBookInfoEditDraft normalized() {
    return SearchBookInfoEditDraft(
      name: name.trim(),
      author: author.trim(),
      coverUrl: coverUrl.trim(),
      intro: intro.trim(),
    );
  }
}

/// 搜索详情页“编辑书籍信息”字段处理（对齐 legado：保存后落库并回写详情展示）。
class SearchBookInfoEditHelper {
  const SearchBookInfoEditHelper._();

  static SearchBookInfoEditDraft fromBook(Book book) {
    return SearchBookInfoEditDraft(
      name: book.title,
      author: book.author,
      coverUrl: (book.coverUrl ?? '').trim(),
      intro: (book.intro ?? '').trim(),
    );
  }

  static Book applyDraft({
    required Book original,
    required SearchBookInfoEditDraft draft,
  }) {
    final normalized = draft.normalized();
    final nextName = normalized.name.isEmpty ? original.title : normalized.name;
    final nextAuthor =
        normalized.author.isEmpty ? original.author : normalized.author;
    final nextCoverUrl =
        normalized.coverUrl.isEmpty ? null : normalized.coverUrl;
    final nextIntro = normalized.intro.isEmpty ? null : normalized.intro;

    // `Book.copyWith` 无法把 nullable 字段显式清空，因此这里按字段重建对象。
    return Book(
      id: original.id,
      title: nextName,
      author: nextAuthor,
      coverUrl: nextCoverUrl,
      intro: nextIntro,
      sourceId: original.sourceId,
      sourceUrl: original.sourceUrl,
      bookUrl: original.bookUrl,
      latestChapter: original.latestChapter,
      totalChapters: original.totalChapters,
      currentChapter: original.currentChapter,
      readProgress: original.readProgress,
      lastReadTime: original.lastReadTime,
      addedTime: original.addedTime,
      isLocal: original.isLocal,
      localPath: original.localPath,
    );
  }
}
