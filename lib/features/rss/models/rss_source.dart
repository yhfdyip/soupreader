import 'dart:collection';
import 'dart:convert';

/// RSS 订阅源模型（对齐 legado `RssSource` 关键字段）
class RssSource {
  final String sourceUrl;
  final String sourceName;
  final String sourceIcon;
  final String? sourceGroup;
  final String? sourceComment;
  final bool enabled;
  final String? variableComment;
  final String? jsLib;
  final bool? enabledCookieJar;
  final String? concurrentRate;
  final String? header;
  final String? loginUrl;
  final String? loginUi;
  final String? loginCheckJs;
  final String? coverDecodeJs;
  final String? sortUrl;
  final bool singleUrl;
  final int articleStyle;
  final String? ruleArticles;
  final String? ruleNextPage;
  final String? ruleTitle;
  final String? rulePubDate;
  final String? ruleDescription;
  final String? ruleImage;
  final String? ruleLink;
  final String? ruleContent;
  final String? contentWhitelist;
  final String? contentBlacklist;
  final String? shouldOverrideUrlLoading;
  final String? style;
  final bool enableJs;
  final bool loadWithBaseUrl;
  final String? injectJs;
  final int lastUpdateTime;
  final int customOrder;

  const RssSource({
    required this.sourceUrl,
    this.sourceName = '',
    this.sourceIcon = '',
    this.sourceGroup,
    this.sourceComment,
    this.enabled = true,
    this.variableComment,
    this.jsLib,
    this.enabledCookieJar = true,
    this.concurrentRate,
    this.header,
    this.loginUrl,
    this.loginUi,
    this.loginCheckJs,
    this.coverDecodeJs,
    this.sortUrl,
    this.singleUrl = false,
    this.articleStyle = 0,
    this.ruleArticles,
    this.ruleNextPage,
    this.ruleTitle,
    this.rulePubDate,
    this.ruleDescription,
    this.ruleImage,
    this.ruleLink,
    this.ruleContent,
    this.contentWhitelist,
    this.contentBlacklist,
    this.shouldOverrideUrlLoading,
    this.style,
    this.enableJs = true,
    this.loadWithBaseUrl = true,
    this.injectJs,
    this.lastUpdateTime = 0,
    this.customOrder = 0,
  });

  RssSource copyWith({
    String? sourceUrl,
    String? sourceName,
    String? sourceIcon,
    String? sourceGroup,
    String? sourceComment,
    bool? enabled,
    String? variableComment,
    String? jsLib,
    bool? enabledCookieJar,
    String? concurrentRate,
    String? header,
    String? loginUrl,
    String? loginUi,
    String? loginCheckJs,
    String? coverDecodeJs,
    String? sortUrl,
    bool? singleUrl,
    int? articleStyle,
    String? ruleArticles,
    String? ruleNextPage,
    String? ruleTitle,
    String? rulePubDate,
    String? ruleDescription,
    String? ruleImage,
    String? ruleLink,
    String? ruleContent,
    String? contentWhitelist,
    String? contentBlacklist,
    String? shouldOverrideUrlLoading,
    String? style,
    bool? enableJs,
    bool? loadWithBaseUrl,
    String? injectJs,
    int? lastUpdateTime,
    int? customOrder,
  }) {
    return RssSource(
      sourceUrl: sourceUrl ?? this.sourceUrl,
      sourceName: sourceName ?? this.sourceName,
      sourceIcon: sourceIcon ?? this.sourceIcon,
      sourceGroup: sourceGroup ?? this.sourceGroup,
      sourceComment: sourceComment ?? this.sourceComment,
      enabled: enabled ?? this.enabled,
      variableComment: variableComment ?? this.variableComment,
      jsLib: jsLib ?? this.jsLib,
      enabledCookieJar: enabledCookieJar ?? this.enabledCookieJar,
      concurrentRate: concurrentRate ?? this.concurrentRate,
      header: header ?? this.header,
      loginUrl: loginUrl ?? this.loginUrl,
      loginUi: loginUi ?? this.loginUi,
      loginCheckJs: loginCheckJs ?? this.loginCheckJs,
      coverDecodeJs: coverDecodeJs ?? this.coverDecodeJs,
      sortUrl: sortUrl ?? this.sortUrl,
      singleUrl: singleUrl ?? this.singleUrl,
      articleStyle: articleStyle ?? this.articleStyle,
      ruleArticles: ruleArticles ?? this.ruleArticles,
      ruleNextPage: ruleNextPage ?? this.ruleNextPage,
      ruleTitle: ruleTitle ?? this.ruleTitle,
      rulePubDate: rulePubDate ?? this.rulePubDate,
      ruleDescription: ruleDescription ?? this.ruleDescription,
      ruleImage: ruleImage ?? this.ruleImage,
      ruleLink: ruleLink ?? this.ruleLink,
      ruleContent: ruleContent ?? this.ruleContent,
      contentWhitelist: contentWhitelist ?? this.contentWhitelist,
      contentBlacklist: contentBlacklist ?? this.contentBlacklist,
      shouldOverrideUrlLoading:
          shouldOverrideUrlLoading ?? this.shouldOverrideUrlLoading,
      style: style ?? this.style,
      enableJs: enableJs ?? this.enableJs,
      loadWithBaseUrl: loadWithBaseUrl ?? this.loadWithBaseUrl,
      injectJs: injectJs ?? this.injectJs,
      lastUpdateTime: lastUpdateTime ?? this.lastUpdateTime,
      customOrder: customOrder ?? this.customOrder,
    );
  }

  factory RssSource.fromJson(Map<String, dynamic> json) {
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

    bool? parseNullableBool(dynamic raw) {
      if (raw == null) return null;
      if (raw is bool) return raw;
      if (raw is num) return raw != 0;
      if (raw is String) {
        final text = raw.trim().toLowerCase();
        if (text == 'true' || text == '1') return true;
        if (text == 'false' || text == '0') return false;
      }
      return null;
    }

    String? parseString(dynamic raw) {
      if (raw == null) return null;
      final value = raw.toString();
      return value;
    }

    String? parseHeader(dynamic raw) {
      if (raw == null) return null;
      if (raw is String) return raw;
      if (raw is Map) {
        final map = <String, String>{};
        raw.forEach((key, value) {
          if (key == null || value == null) return;
          final normalizedKey = key.toString().trim();
          if (normalizedKey.isEmpty) return;
          map[normalizedKey] = value.toString();
        });
        if (map.isEmpty) return null;
        return jsonEncode(map);
      }
      return raw.toString();
    }

    return RssSource(
      sourceUrl: (json['sourceUrl'] ?? '').toString().trim(),
      sourceName: (json['sourceName'] ?? '').toString(),
      sourceIcon: (json['sourceIcon'] ?? '').toString(),
      sourceGroup: parseString(json['sourceGroup']),
      sourceComment: parseString(json['sourceComment']),
      enabled: parseBool(json['enabled'], true),
      variableComment: parseString(json['variableComment']),
      jsLib: parseString(json['jsLib']),
      enabledCookieJar: json.containsKey('enabledCookieJar')
          ? parseNullableBool(json['enabledCookieJar'])
          : true,
      concurrentRate: parseString(json['concurrentRate']),
      header: parseHeader(json['header']),
      loginUrl: parseString(json['loginUrl']),
      loginUi: parseString(json['loginUi']),
      loginCheckJs: parseString(json['loginCheckJs']),
      coverDecodeJs: parseString(json['coverDecodeJs']),
      sortUrl: parseString(json['sortUrl']),
      singleUrl: parseBool(json['singleUrl'], false),
      articleStyle: parseInt(json['articleStyle'], 0),
      ruleArticles: parseString(json['ruleArticles']),
      ruleNextPage: parseString(json['ruleNextPage']),
      ruleTitle: parseString(json['ruleTitle']),
      rulePubDate: parseString(json['rulePubDate']),
      ruleDescription: parseString(json['ruleDescription']),
      ruleImage: parseString(json['ruleImage']),
      ruleLink: parseString(json['ruleLink']),
      ruleContent: parseString(json['ruleContent']),
      contentWhitelist: parseString(json['contentWhitelist']),
      contentBlacklist: parseString(json['contentBlacklist']),
      shouldOverrideUrlLoading: parseString(json['shouldOverrideUrlLoading']),
      style: parseString(json['style']),
      enableJs: parseBool(json['enableJs'], true),
      loadWithBaseUrl: parseBool(json['loadWithBaseUrl'], true),
      injectJs: parseString(json['injectJs']),
      lastUpdateTime: parseInt(json['lastUpdateTime'], 0),
      customOrder: parseInt(json['customOrder'], 0),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'sourceUrl': sourceUrl,
      'sourceName': sourceName,
      'sourceIcon': sourceIcon,
      'sourceGroup': sourceGroup,
      'sourceComment': sourceComment,
      'enabled': enabled,
      'variableComment': variableComment,
      'jsLib': jsLib,
      'enabledCookieJar': enabledCookieJar,
      'concurrentRate': concurrentRate,
      'header': header,
      'loginUrl': loginUrl,
      'loginUi': loginUi,
      'loginCheckJs': loginCheckJs,
      'coverDecodeJs': coverDecodeJs,
      'sortUrl': sortUrl,
      'singleUrl': singleUrl,
      'articleStyle': articleStyle,
      'ruleArticles': ruleArticles,
      'ruleNextPage': ruleNextPage,
      'ruleTitle': ruleTitle,
      'rulePubDate': rulePubDate,
      'ruleDescription': ruleDescription,
      'ruleImage': ruleImage,
      'ruleLink': ruleLink,
      'ruleContent': ruleContent,
      'contentWhitelist': contentWhitelist,
      'contentBlacklist': contentBlacklist,
      'shouldOverrideUrlLoading': shouldOverrideUrlLoading,
      'style': style,
      'enableJs': enableJs,
      'loadWithBaseUrl': loadWithBaseUrl,
      'injectJs': injectJs,
      'lastUpdateTime': lastUpdateTime,
      'customOrder': customOrder,
    };
  }

  String getDisplayNameGroup() {
    final group = sourceGroup?.trim();
    if (group == null || group.isEmpty) return sourceName;
    return '$sourceName ($group)';
  }

  RssSource addGroup(String groups) {
    final current = LinkedHashSet<String>.from(splitGroups(sourceGroup));
    final incoming = splitGroups(groups);
    if (incoming.isEmpty) return this;
    current.addAll(incoming);
    return copyWith(sourceGroup: current.join(','));
  }

  RssSource removeGroup(String groups) {
    final current = LinkedHashSet<String>.from(splitGroups(sourceGroup));
    final removed = splitGroups(groups).toSet();
    if (removed.isEmpty) return this;
    current.removeAll(removed);
    return copyWith(sourceGroup: current.join(','));
  }

  String getDisplayVariableComment(String otherComment) {
    final comment = variableComment?.trim();
    if (comment == null || comment.isEmpty) return otherComment;
    return '$comment\n$otherComment';
  }

  static final RegExp _splitGroupRegex = RegExp(r'[,;，；]');

  static List<String> splitGroups(String? raw) {
    final text = raw?.trim();
    if (text == null || text.isEmpty) return const <String>[];
    return text
        .split(_splitGroupRegex)
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList(growable: false);
  }
}
