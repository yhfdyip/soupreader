/// RSS 阅读记录（对齐 legado `RssReadRecord`）
class RssReadRecord {
  final String record;
  final String? title;
  final int? readTime;
  final bool read;

  const RssReadRecord({
    required this.record,
    this.title,
    this.readTime,
    this.read = true,
  });

  RssReadRecord copyWith({
    String? record,
    String? title,
    int? readTime,
    bool? read,
  }) {
    return RssReadRecord(
      record: record ?? this.record,
      title: title ?? this.title,
      readTime: readTime ?? this.readTime,
      read: read ?? this.read,
    );
  }

  factory RssReadRecord.fromJson(Map<String, dynamic> json) {
    int? parseNullableInt(dynamic raw) {
      if (raw == null) return null;
      if (raw is int) return raw;
      if (raw is num) return raw.toInt();
      if (raw is String) return int.tryParse(raw.trim());
      return null;
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

    return RssReadRecord(
      record: (json['record'] ?? '').toString(),
      title: json['title']?.toString(),
      readTime: parseNullableInt(json['readTime']),
      read: parseBool(json['read'], true),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'record': record,
      'title': title,
      'readTime': readTime,
      'read': read,
    };
  }
}
