import 'rss_read_record.dart';

/// RSS 文章模型（对齐 legado `RssArticle` 关键字段）
class RssArticle {
  final String origin;
  final String sort;
  final String title;
  final int order;
  final String link;
  final String? pubDate;
  final String? description;
  final String? content;
  final String? image;
  final String group;
  final bool read;
  final String? variable;

  const RssArticle({
    this.origin = '',
    this.sort = '',
    this.title = '',
    this.order = 0,
    this.link = '',
    this.pubDate,
    this.description,
    this.content,
    this.image,
    this.group = '默认分组',
    this.read = false,
    this.variable,
  });

  RssArticle copyWith({
    String? origin,
    String? sort,
    String? title,
    int? order,
    String? link,
    String? pubDate,
    String? description,
    String? content,
    String? image,
    String? group,
    bool? read,
    String? variable,
  }) {
    return RssArticle(
      origin: origin ?? this.origin,
      sort: sort ?? this.sort,
      title: title ?? this.title,
      order: order ?? this.order,
      link: link ?? this.link,
      pubDate: pubDate ?? this.pubDate,
      description: description ?? this.description,
      content: content ?? this.content,
      image: image ?? this.image,
      group: group ?? this.group,
      read: read ?? this.read,
      variable: variable ?? this.variable,
    );
  }

  factory RssArticle.fromJson(Map<String, dynamic> json) {
    int parseInt(dynamic raw, int fallback) {
      if (raw is int) return raw;
      if (raw is num) return raw.toInt();
      if (raw is String) return int.tryParse(raw.trim()) ?? fallback;
      return fallback;
    }

    bool parseBool(dynamic raw, bool fallback) {
      if (raw is bool) return raw;
      if (raw is num) return raw != 0;
      if (raw is String) {
        final text = raw.trim().toLowerCase();
        if (text == 'true' || text == '1') return true;
        if (text == 'false' || text == '0') return false;
      }
      return fallback;
    }

    String? parseString(dynamic raw) {
      if (raw == null) return null;
      final text = raw.toString();
      return text;
    }

    return RssArticle(
      origin: (json['origin'] ?? '').toString(),
      sort: (json['sort'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      order: parseInt(json['order'], 0),
      link: (json['link'] ?? '').toString(),
      pubDate: parseString(json['pubDate']),
      description: parseString(json['description']),
      content: parseString(json['content']),
      image: parseString(json['image']),
      group: (json['group'] ?? '默认分组').toString(),
      read: parseBool(json['read'], false),
      variable: parseString(json['variable']),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'origin': origin,
      'sort': sort,
      'title': title,
      'order': order,
      'link': link,
      'pubDate': pubDate,
      'description': description,
      'content': content,
      'image': image,
      'group': group,
      'read': read,
      'variable': variable,
    };
  }

  RssReadRecord toReadRecord({
    int? readTime,
  }) {
    return RssReadRecord(
      record: link,
      title: title,
      readTime: readTime ?? DateTime.now().millisecondsSinceEpoch,
      read: true,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is RssArticle && other.origin == origin && other.link == link;
  }

  @override
  int get hashCode => Object.hash(origin, link);
}
