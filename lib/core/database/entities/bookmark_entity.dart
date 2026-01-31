import 'package:hive/hive.dart';

part 'bookmark_entity.g.dart';

/// Hive 存储用的书签实体
@HiveType(typeId: 3)
class BookmarkEntity extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String bookId;

  @HiveField(2)
  final String bookName;

  @HiveField(3)
  final String bookAuthor;

  @HiveField(4)
  final int chapterIndex;

  @HiveField(5)
  final String chapterTitle;

  @HiveField(6)
  final int chapterPos; // 章节内字符位置

  @HiveField(7)
  final String content; // 书签处的文本内容（预览用）

  @HiveField(8)
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
