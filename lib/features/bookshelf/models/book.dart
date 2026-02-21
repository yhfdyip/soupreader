/// 书籍模型
class Book {
  final String id;
  final String title;
  final String author;
  final String? coverUrl;
  final String? intro;
  final String? sourceId;
  final String? sourceUrl;
  final String? bookUrl;
  final String? latestChapter;
  final int totalChapters;
  final int currentChapter;
  final double readProgress; // 0.0 - 1.0
  final DateTime? lastReadTime;
  final DateTime? addedTime;
  final bool isLocal; // 是否为本地导入的书籍
  final String? localPath; // 本地文件路径

  const Book({
    required this.id,
    required this.title,
    required this.author,
    this.coverUrl,
    this.intro,
    this.sourceId,
    this.sourceUrl,
    this.bookUrl,
    this.latestChapter,
    this.totalChapters = 0,
    this.currentChapter = 0,
    this.readProgress = 0.0,
    this.lastReadTime,
    this.addedTime,
    this.isLocal = false,
    this.localPath,
  });

  /// 从JSON创建
  factory Book.fromJson(Map<String, dynamic> json) {
    return Book(
      id: json['id'] as String,
      title: json['title'] as String,
      author: json['author'] as String? ?? '未知',
      coverUrl: json['coverUrl'] as String?,
      intro: json['intro'] as String?,
      sourceId: json['sourceId'] as String?,
      sourceUrl: json['sourceUrl'] as String?,
      bookUrl: json['bookUrl'] as String?,
      latestChapter: json['latestChapter'] as String?,
      totalChapters: json['totalChapters'] as int? ?? 0,
      currentChapter: json['currentChapter'] as int? ?? 0,
      readProgress: (json['readProgress'] as num?)?.toDouble() ?? 0.0,
      lastReadTime: json['lastReadTime'] != null
          ? DateTime.parse(json['lastReadTime'] as String)
          : null,
      addedTime: json['addedTime'] != null
          ? DateTime.parse(json['addedTime'] as String)
          : null,
      isLocal: json['isLocal'] as bool? ?? false,
      localPath: json['localPath'] as String?,
    );
  }

  /// 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'author': author,
      'coverUrl': coverUrl,
      'intro': intro,
      'sourceId': sourceId,
      'sourceUrl': sourceUrl,
      'bookUrl': bookUrl,
      'latestChapter': latestChapter,
      'totalChapters': totalChapters,
      'currentChapter': currentChapter,
      'readProgress': readProgress,
      'lastReadTime': lastReadTime?.toIso8601String(),
      'addedTime': addedTime?.toIso8601String(),
      'isLocal': isLocal,
      'localPath': localPath,
    };
  }

  /// 复制并修改
  Book copyWith({
    String? id,
    String? title,
    String? author,
    String? coverUrl,
    String? intro,
    String? sourceId,
    String? sourceUrl,
    String? bookUrl,
    String? latestChapter,
    int? totalChapters,
    int? currentChapter,
    double? readProgress,
    DateTime? lastReadTime,
    DateTime? addedTime,
    bool? isLocal,
    String? localPath,
  }) {
    return Book(
      id: id ?? this.id,
      title: title ?? this.title,
      author: author ?? this.author,
      coverUrl: coverUrl ?? this.coverUrl,
      intro: intro ?? this.intro,
      sourceId: sourceId ?? this.sourceId,
      sourceUrl: sourceUrl ?? this.sourceUrl,
      bookUrl: bookUrl ?? this.bookUrl,
      latestChapter: latestChapter ?? this.latestChapter,
      totalChapters: totalChapters ?? this.totalChapters,
      currentChapter: currentChapter ?? this.currentChapter,
      readProgress: readProgress ?? this.readProgress,
      lastReadTime: lastReadTime ?? this.lastReadTime,
      addedTime: addedTime ?? this.addedTime,
      isLocal: isLocal ?? this.isLocal,
      localPath: localPath ?? this.localPath,
    );
  }

  /// 获取阅读进度百分比文本
  String get progressText {
    return '${(readProgress * 100).toStringAsFixed(1)}%';
  }

  /// 检查是否正在阅读
  bool get isReading => currentChapter > 0 || readProgress > 0;
}

const _unsetChapterContent = Object();

/// 章节模型
class Chapter {
  final String id;
  final String bookId;
  final String title;
  final String? url;
  final int index;
  final bool isDownloaded;
  final String? content; // 缓存的内容

  const Chapter({
    required this.id,
    required this.bookId,
    required this.title,
    this.url,
    required this.index,
    this.isDownloaded = false,
    this.content,
  });

  factory Chapter.fromJson(Map<String, dynamic> json) {
    return Chapter(
      id: json['id'] as String,
      bookId: json['bookId'] as String,
      title: json['title'] as String,
      url: json['url'] as String?,
      index: json['index'] as int,
      isDownloaded: json['isDownloaded'] as bool? ?? false,
      content: json['content'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'bookId': bookId,
      'title': title,
      'url': url,
      'index': index,
      'isDownloaded': isDownloaded,
      'content': content,
    };
  }

  Chapter copyWith({
    String? id,
    String? bookId,
    String? title,
    String? url,
    int? index,
    bool? isDownloaded,
    Object? content = _unsetChapterContent,
  }) {
    return Chapter(
      id: id ?? this.id,
      bookId: bookId ?? this.bookId,
      title: title ?? this.title,
      url: url ?? this.url,
      index: index ?? this.index,
      isDownloaded: isDownloaded ?? this.isDownloaded,
      content: identical(content, _unsetChapterContent)
          ? this.content
          : content as String?,
    );
  }
}
