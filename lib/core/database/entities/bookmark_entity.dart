/// 书签实体（纯数据模型）
class BookmarkEntity {
  final String id;

  final String bookId;

  final String bookName;

  final String bookAuthor;

  final int chapterIndex;

  final String chapterTitle;

  final int chapterPos; // 章节内字符位置

  final String content; // 书签处的文本内容（预览用）

  final DateTime createdTime;

  BookmarkEntity({
    required this.id,
    required this.bookId,
    required this.bookName,
    required this.bookAuthor,
    required this.chapterIndex,
    required this.chapterTitle,
    this.chapterPos = 0,
    this.content = '',
    DateTime? createdTime,
  }) : createdTime = createdTime ?? DateTime.now();

  /// 复制并修改
  BookmarkEntity copyWith({
    String? id,
    String? bookId,
    String? bookName,
    String? bookAuthor,
    int? chapterIndex,
    String? chapterTitle,
    int? chapterPos,
    String? content,
    DateTime? createdTime,
  }) {
    return BookmarkEntity(
      id: id ?? this.id,
      bookId: bookId ?? this.bookId,
      bookName: bookName ?? this.bookName,
      bookAuthor: bookAuthor ?? this.bookAuthor,
      chapterIndex: chapterIndex ?? this.chapterIndex,
      chapterTitle: chapterTitle ?? this.chapterTitle,
      chapterPos: chapterPos ?? this.chapterPos,
      content: content ?? this.content,
      createdTime: createdTime ?? this.createdTime,
    );
  }
}
