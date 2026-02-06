/// 替换净化规则 - 字段对齐 Legado `ReplaceRule`
class ReplaceRule {
  final int id; // Long
  final String name;
  final String? group;
  final String pattern;
  final String replacement;
  final String? scope;
  final bool scopeTitle;
  final bool scopeContent;
  final String? excludeScope;
  final bool isEnabled;
  final bool isRegex;
  final int timeoutMillisecond; // Long
  final int order; // Int

  const ReplaceRule({
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
    this.order = -2147483648, // Int.MIN_VALUE
  });

  factory ReplaceRule.create() {
    return ReplaceRule(id: DateTime.now().millisecondsSinceEpoch);
  }

  ReplaceRule copyWith({
    int? id,
    String? name,
    String? group,
    String? pattern,
    String? replacement,
    String? scope,
    bool? scopeTitle,
    bool? scopeContent,
    String? excludeScope,
    bool? isEnabled,
    bool? isRegex,
    int? timeoutMillisecond,
    int? order,
  }) {
    return ReplaceRule(
      id: id ?? this.id,
      name: name ?? this.name,
      group: group ?? this.group,
      pattern: pattern ?? this.pattern,
      replacement: replacement ?? this.replacement,
      scope: scope ?? this.scope,
      scopeTitle: scopeTitle ?? this.scopeTitle,
      scopeContent: scopeContent ?? this.scopeContent,
      excludeScope: excludeScope ?? this.excludeScope,
      isEnabled: isEnabled ?? this.isEnabled,
      isRegex: isRegex ?? this.isRegex,
      timeoutMillisecond: timeoutMillisecond ?? this.timeoutMillisecond,
      order: order ?? this.order,
    );
  }

  factory ReplaceRule.fromJson(Map<String, dynamic> json) {
    int parseInt(dynamic raw, int fallback) {
      if (raw is int) return raw;
      if (raw is num) return raw.toInt();
      if (raw is String) return int.tryParse(raw) ?? fallback;
      return fallback;
    }

    bool parseBool(dynamic raw, bool fallback) {
      if (raw is bool) return raw;
      if (raw is num) return raw != 0;
      if (raw is String) {
        final t = raw.trim().toLowerCase();
        if (t == 'true' || t == '1') return true;
        if (t == 'false' || t == '0') return false;
      }
      return fallback;
    }

    return ReplaceRule(
      id: parseInt(
        json['id'],
        DateTime.now().millisecondsSinceEpoch,
      ),
      name: (json['name'] ?? '').toString(),
      group: json['group']?.toString(),
      pattern: (json['pattern'] ?? '').toString(),
      replacement: (json['replacement'] ?? '').toString(),
      scope: json['scope']?.toString(),
      scopeTitle: parseBool(json['scopeTitle'], false),
      scopeContent: parseBool(json['scopeContent'], true),
      excludeScope: json['excludeScope']?.toString(),
      isEnabled: parseBool(json['isEnabled'], true),
      isRegex: parseBool(json['isRegex'], true),
      timeoutMillisecond: parseInt(json['timeoutMillisecond'], 3000),
      order: parseInt(json['order'], -2147483648),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'group': group,
      'pattern': pattern,
      'replacement': replacement,
      'scope': scope,
      'scopeTitle': scopeTitle,
      'scopeContent': scopeContent,
      'excludeScope': excludeScope,
      'isEnabled': isEnabled,
      'isRegex': isRegex,
      'timeoutMillisecond': timeoutMillisecond,
      'order': order,
    };
  }
}

