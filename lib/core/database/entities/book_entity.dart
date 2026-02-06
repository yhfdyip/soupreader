import 'package:hive/hive.dart';

part 'book_entity.g.dart';

/// Hive 存储用的书籍实体
@HiveType(typeId: 0)
class BookEntity extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String title;

  @HiveField(2)
  final String author;

  @HiveField(3)
  final String? coverUrl;

  @HiveField(4)
  final String? intro;

  @HiveField(5)
  final String? sourceId;

  @HiveField(6)
  final String? sourceUrl;

  @HiveField(7)
  final String? latestChapter;

  @HiveField(8)
  final int totalChapters;

  @HiveField(9)
  final int currentChapter;

  @HiveField(10)
  final double readProgress;

  @HiveField(11)
  final DateTime? lastReadTime;

  @HiveField(12)
  final DateTime? addedTime;

  @HiveField(13)
  final bool isLocal;

  @HiveField(14)
  final String? localPath;

  BookEntity({
    required this.id,
    required this.title,
    required this.author,
    this.coverUrl,
    this.intro,
    this.sourceId,
    this.sourceUrl,
    this.latestChapter,
    this.totalChapters = 0,
    this.currentChapter = 0,
    this.readProgress = 0.0,
    this.lastReadTime,
    this.addedTime,
    this.isLocal = false,
    this.localPath,
  });
}

/// Hive 存储用的章节实体
@HiveType(typeId: 1)
class ChapterEntity extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String bookId;

  @HiveField(2)
  final String title;

  @HiveField(3)
  final String? url;

  @HiveField(4)
  final int index;

  @HiveField(5)
  final bool isDownloaded;

  @HiveField(6)
  final String? content;

  ChapterEntity({
    required this.id,
    required this.bookId,
    required this.title,
    this.url,
    required this.index,
    this.isDownloaded = false,
    this.content,
  });
}

/// Hive 存储用的书源实体
@HiveType(typeId: 2)
class BookSourceEntity extends HiveObject {
  @HiveField(0)
  final String bookSourceUrl;

  @HiveField(1)
  final String bookSourceName;

  @HiveField(2)
  final String? bookSourceGroup;

  @HiveField(3)
  final int bookSourceType;

  @HiveField(4)
  final bool enabled;

  @HiveField(5)
  final String? ruleSearchJson;

  @HiveField(6)
  final String? ruleBookInfoJson;

  @HiveField(7)
  final String? ruleTocJson;

  @HiveField(8)
  final String? ruleContentJson;

  @HiveField(9)
  final String? bookSourceComment;

  @HiveField(10)
  final int weight;

  @HiveField(11)
  final String? header;

  @HiveField(12)
  final String? loginUrl;

  @HiveField(13)
  final DateTime? lastUpdateTime;

  /// 保真保存 Legado 书源 JSON（用于严格对齐字段与 null 序列化行为）
  ///
  /// - 导入 Legado 后，将原始对象（去除 null 字段）编码后存入此字段。
  /// - 导出时优先使用此字段，避免丢字段。
  @HiveField(14)
  final String? rawJson;

  BookSourceEntity({
    required this.bookSourceUrl,
    required this.bookSourceName,
    this.bookSourceGroup,
    this.bookSourceType = 0,
    this.enabled = true,
    this.ruleSearchJson,
    this.ruleBookInfoJson,
    this.ruleTocJson,
    this.ruleContentJson,
    this.bookSourceComment,
    this.weight = 0,
    this.header,
    this.loginUrl,
    this.lastUpdateTime,
    this.rawJson,
  });
}

/// Hive 存储用的替换净化规则实体（对齐 Legado ReplaceRule 字段）
@HiveType(typeId: 3)
class ReplaceRuleEntity extends HiveObject {
  @HiveField(0)
  final int id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final String? group;

  @HiveField(3)
  final String pattern;

  @HiveField(4)
  final String replacement;

  @HiveField(5)
  final String? scope;

  @HiveField(6)
  final bool scopeTitle;

  @HiveField(7)
  final bool scopeContent;

  @HiveField(8)
  final String? excludeScope;

  @HiveField(9)
  final bool isEnabled;

  @HiveField(10)
  final bool isRegex;

  @HiveField(11)
  final int timeoutMillisecond;

  @HiveField(12)
  final int order;

  ReplaceRuleEntity({
    required this.id,
    this.name = '',
    this.group,
    this.pattern = '',
    this.replacement = '',
    this.scope,
    this.scopeTitle = false,
    this.scopeContent = true,
    this.excludeScope,
    this.isEnabled = true,
    this.isRegex = true,
    this.timeoutMillisecond = 3000,
    this.order = -2147483648,
  });
}
