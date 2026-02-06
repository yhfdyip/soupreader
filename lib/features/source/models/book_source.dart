import 'dart:convert';

/// 书源模型 - 字段结构对齐 Legado（开源阅读）
///
/// 目标：
/// - JSON 字段名与 Legado 完全一致
/// - 默认不序列化 null 字段（Gson 默认行为）由上层统一处理或本类 toJson 负责
///
/// 说明：
/// - Legado 的 BookSource 中，搜索 URL 在顶层字段 `searchUrl`，而不是 ruleSearch.url
/// - 发现 URL 在顶层字段 `exploreUrl`
class BookSource {
  // 基础字段（与 Legado 对齐）
  final String bookSourceUrl;
  final String bookSourceName;
  final String? bookSourceGroup;
  final int bookSourceType;
  final String? bookUrlPattern;
  final int customOrder;
  final bool enabled;
  final bool enabledExplore;

  // BaseSource 字段（与 Legado BaseSource 对齐）
  final String? jsLib;
  final bool? enabledCookieJar;
  final String? concurrentRate;
  final String? header;
  final String? loginUrl;
  final String? loginUi;

  // 额外字段（与 Legado 对齐）
  final String? loginCheckJs;
  final String? coverDecodeJs;
  final String? bookSourceComment;
  final String? variableComment;
  final int lastUpdateTime; // Long 毫秒
  final int respondTime; // Long 毫秒
  final int weight;

  // 发现
  final String? exploreUrl;
  final String? exploreScreen;
  final ExploreRule? ruleExplore;

  // 搜索
  final String? searchUrl;
  final SearchRule? ruleSearch;

  // 详情/目录/正文/段评
  final BookInfoRule? ruleBookInfo;
  final TocRule? ruleToc;
  final ContentRule? ruleContent;
  final ReviewRule? ruleReview;

  const BookSource({
    required this.bookSourceUrl,
    required this.bookSourceName,
    this.bookSourceGroup,
    this.bookSourceType = 0,
    this.bookUrlPattern,
    this.customOrder = 0,
    this.enabled = true,
    this.enabledExplore = true,
    this.jsLib,
    this.enabledCookieJar = true,
    this.concurrentRate,
    this.header,
    this.loginUrl,
    this.loginUi,
    this.loginCheckJs,
    this.coverDecodeJs,
    this.bookSourceComment,
    this.variableComment,
    this.lastUpdateTime = 0,
    this.respondTime = 180000,
    this.weight = 0,
    this.exploreUrl,
    this.exploreScreen,
    this.ruleExplore,
    this.searchUrl,
    this.ruleSearch,
    this.ruleBookInfo,
    this.ruleToc,
    this.ruleContent,
    this.ruleReview,
  });

  String get id => bookSourceUrl;

  BookSource copyWith({
    String? bookSourceUrl,
    String? bookSourceName,
    String? bookSourceGroup,
    int? bookSourceType,
    String? bookUrlPattern,
    int? customOrder,
    bool? enabled,
    bool? enabledExplore,
    String? jsLib,
    bool? enabledCookieJar,
    String? concurrentRate,
    String? header,
    String? loginUrl,
    String? loginUi,
    String? loginCheckJs,
    String? coverDecodeJs,
    String? bookSourceComment,
    String? variableComment,
    int? lastUpdateTime,
    int? respondTime,
    int? weight,
    String? exploreUrl,
    String? exploreScreen,
    ExploreRule? ruleExplore,
    String? searchUrl,
    SearchRule? ruleSearch,
    BookInfoRule? ruleBookInfo,
    TocRule? ruleToc,
    ContentRule? ruleContent,
    ReviewRule? ruleReview,
  }) {
    return BookSource(
      bookSourceUrl: bookSourceUrl ?? this.bookSourceUrl,
      bookSourceName: bookSourceName ?? this.bookSourceName,
      bookSourceGroup: bookSourceGroup ?? this.bookSourceGroup,
      bookSourceType: bookSourceType ?? this.bookSourceType,
      bookUrlPattern: bookUrlPattern ?? this.bookUrlPattern,
      customOrder: customOrder ?? this.customOrder,
      enabled: enabled ?? this.enabled,
      enabledExplore: enabledExplore ?? this.enabledExplore,
      jsLib: jsLib ?? this.jsLib,
      enabledCookieJar: enabledCookieJar ?? this.enabledCookieJar,
      concurrentRate: concurrentRate ?? this.concurrentRate,
      header: header ?? this.header,
      loginUrl: loginUrl ?? this.loginUrl,
      loginUi: loginUi ?? this.loginUi,
      loginCheckJs: loginCheckJs ?? this.loginCheckJs,
      coverDecodeJs: coverDecodeJs ?? this.coverDecodeJs,
      bookSourceComment: bookSourceComment ?? this.bookSourceComment,
      variableComment: variableComment ?? this.variableComment,
      lastUpdateTime: lastUpdateTime ?? this.lastUpdateTime,
      respondTime: respondTime ?? this.respondTime,
      weight: weight ?? this.weight,
      exploreUrl: exploreUrl ?? this.exploreUrl,
      exploreScreen: exploreScreen ?? this.exploreScreen,
      ruleExplore: ruleExplore ?? this.ruleExplore,
      searchUrl: searchUrl ?? this.searchUrl,
      ruleSearch: ruleSearch ?? this.ruleSearch,
      ruleBookInfo: ruleBookInfo ?? this.ruleBookInfo,
      ruleToc: ruleToc ?? this.ruleToc,
      ruleContent: ruleContent ?? this.ruleContent,
      ruleReview: ruleReview ?? this.ruleReview,
    );
  }

  factory BookSource.fromJson(Map<String, dynamic> json) {
    T? parseRule<T>(
      dynamic raw,
      T Function(Map<String, dynamic> map) fromMap,
    ) {
      if (raw == null) return null;
      if (raw is Map<String, dynamic>) return fromMap(raw);
      if (raw is Map) {
        return fromMap(raw.map((k, v) => MapEntry(k.toString(), v)));
      }
      if (raw is String && raw.trim().isNotEmpty) {
        try {
          final decoded = jsonDecode(raw);
          if (decoded is Map<String, dynamic>) return fromMap(decoded);
          if (decoded is Map) {
            return fromMap(decoded.map((k, v) => MapEntry(k.toString(), v)));
          }
        } catch (_) {
          return null;
        }
      }
      return null;
    }

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

    return BookSource(
      bookSourceUrl: (json['bookSourceUrl'] ?? '').toString(),
      bookSourceName: (json['bookSourceName'] ?? '').toString(),
      bookSourceGroup: json['bookSourceGroup']?.toString(),
      bookSourceType: parseInt(json['bookSourceType'], 0),
      bookUrlPattern: json['bookUrlPattern']?.toString(),
      customOrder: parseInt(json['customOrder'], 0),
      enabled: parseBool(json['enabled'], true),
      enabledExplore: parseBool(json['enabledExplore'], true),
      jsLib: json['jsLib']?.toString(),
      enabledCookieJar: json.containsKey('enabledCookieJar')
          ? (json['enabledCookieJar'] as dynamic) is bool
              ? json['enabledCookieJar'] as bool?
              : (json['enabledCookieJar'] as dynamic) is num
                  ? ((json['enabledCookieJar'] as num).toInt() != 0)
                  : null
          : true,
      concurrentRate: json['concurrentRate']?.toString(),
      header: json['header']?.toString(),
      loginUrl: json['loginUrl']?.toString(),
      loginUi: json['loginUi']?.toString(),
      loginCheckJs: json['loginCheckJs']?.toString(),
      coverDecodeJs: json['coverDecodeJs']?.toString(),
      bookSourceComment: json['bookSourceComment']?.toString(),
      variableComment: json['variableComment']?.toString(),
      lastUpdateTime: parseInt(json['lastUpdateTime'], 0),
      respondTime: parseInt(json['respondTime'], 180000),
      weight: parseInt(json['weight'], 0),
      exploreUrl: json['exploreUrl']?.toString(),
      exploreScreen: json['exploreScreen']?.toString(),
      ruleExplore: parseRule(json['ruleExplore'], ExploreRule.fromJson),
      searchUrl: json['searchUrl']?.toString(),
      ruleSearch: parseRule(json['ruleSearch'], SearchRule.fromJson),
      ruleBookInfo: parseRule(json['ruleBookInfo'], BookInfoRule.fromJson),
      ruleToc: parseRule(json['ruleToc'], TocRule.fromJson),
      ruleContent: parseRule(json['ruleContent'], ContentRule.fromJson),
      ruleReview: parseRule(json['ruleReview'], ReviewRule.fromJson),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'bookSourceUrl': bookSourceUrl,
      'bookSourceName': bookSourceName,
      'bookSourceGroup': bookSourceGroup,
      'bookSourceType': bookSourceType,
      'bookUrlPattern': bookUrlPattern,
      'customOrder': customOrder,
      'enabled': enabled,
      'enabledExplore': enabledExplore,
      'jsLib': jsLib,
      'enabledCookieJar': enabledCookieJar,
      'concurrentRate': concurrentRate,
      'header': header,
      'loginUrl': loginUrl,
      'loginUi': loginUi,
      'loginCheckJs': loginCheckJs,
      'coverDecodeJs': coverDecodeJs,
      'bookSourceComment': bookSourceComment,
      'variableComment': variableComment,
      'lastUpdateTime': lastUpdateTime,
      'respondTime': respondTime,
      'weight': weight,
      'exploreUrl': exploreUrl,
      'exploreScreen': exploreScreen,
      'ruleExplore': ruleExplore?.toJson(),
      'searchUrl': searchUrl,
      'ruleSearch': ruleSearch?.toJson(),
      'ruleBookInfo': ruleBookInfo?.toJson(),
      'ruleToc': ruleToc?.toJson(),
      'ruleContent': ruleContent?.toJson(),
      'ruleReview': ruleReview?.toJson(),
    };
  }
}

abstract class BookListRule {
  String? get bookList;
  String? get name;
  String? get author;
  String? get intro;
  String? get kind;
  String? get lastChapter;
  String? get updateTime;
  String? get bookUrl;
  String? get coverUrl;
  String? get wordCount;
}

class SearchRule implements BookListRule {
  final String? checkKeyWord;
  @override
  final String? bookList;
  @override
  final String? name;
  @override
  final String? author;
  @override
  final String? intro;
  @override
  final String? kind;
  @override
  final String? lastChapter;
  @override
  final String? updateTime;
  @override
  final String? bookUrl;
  @override
  final String? coverUrl;
  @override
  final String? wordCount;

  const SearchRule({
    this.checkKeyWord,
    this.bookList,
    this.name,
    this.author,
    this.intro,
    this.kind,
    this.lastChapter,
    this.updateTime,
    this.bookUrl,
    this.coverUrl,
    this.wordCount,
  });

  factory SearchRule.fromJson(Map<String, dynamic> json) {
    return SearchRule(
      checkKeyWord: json['checkKeyWord']?.toString(),
      bookList: json['bookList']?.toString(),
      name: json['name']?.toString(),
      author: json['author']?.toString(),
      intro: json['intro']?.toString(),
      kind: json['kind']?.toString(),
      lastChapter: json['lastChapter']?.toString(),
      updateTime: json['updateTime']?.toString(),
      bookUrl: json['bookUrl']?.toString(),
      coverUrl: json['coverUrl']?.toString(),
      wordCount: json['wordCount']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'checkKeyWord': checkKeyWord,
      'bookList': bookList,
      'name': name,
      'author': author,
      'intro': intro,
      'kind': kind,
      'lastChapter': lastChapter,
      'updateTime': updateTime,
      'bookUrl': bookUrl,
      'coverUrl': coverUrl,
      'wordCount': wordCount,
    };
  }
}

class ExploreRule implements BookListRule {
  @override
  final String? bookList;
  @override
  final String? name;
  @override
  final String? author;
  @override
  final String? intro;
  @override
  final String? kind;
  @override
  final String? lastChapter;
  @override
  final String? updateTime;
  @override
  final String? bookUrl;
  @override
  final String? coverUrl;
  @override
  final String? wordCount;

  const ExploreRule({
    this.bookList,
    this.name,
    this.author,
    this.intro,
    this.kind,
    this.lastChapter,
    this.updateTime,
    this.bookUrl,
    this.coverUrl,
    this.wordCount,
  });

  factory ExploreRule.fromJson(Map<String, dynamic> json) {
    return ExploreRule(
      bookList: json['bookList']?.toString(),
      name: json['name']?.toString(),
      author: json['author']?.toString(),
      intro: json['intro']?.toString(),
      kind: json['kind']?.toString(),
      lastChapter: json['lastChapter']?.toString(),
      updateTime: json['updateTime']?.toString(),
      bookUrl: json['bookUrl']?.toString(),
      coverUrl: json['coverUrl']?.toString(),
      wordCount: json['wordCount']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'bookList': bookList,
      'name': name,
      'author': author,
      'intro': intro,
      'kind': kind,
      'lastChapter': lastChapter,
      'updateTime': updateTime,
      'bookUrl': bookUrl,
      'coverUrl': coverUrl,
      'wordCount': wordCount,
    };
  }
}

class BookInfoRule {
  final String? init;
  final String? name;
  final String? author;
  final String? intro;
  final String? kind;
  final String? lastChapter;
  final String? updateTime;
  final String? coverUrl;
  final String? tocUrl;
  final String? wordCount;
  final String? canReName;
  final String? downloadUrls;

  const BookInfoRule({
    this.init,
    this.name,
    this.author,
    this.intro,
    this.kind,
    this.lastChapter,
    this.updateTime,
    this.coverUrl,
    this.tocUrl,
    this.wordCount,
    this.canReName,
    this.downloadUrls,
  });

  factory BookInfoRule.fromJson(Map<String, dynamic> json) {
    return BookInfoRule(
      init: json['init']?.toString(),
      name: json['name']?.toString(),
      author: json['author']?.toString(),
      intro: json['intro']?.toString(),
      kind: json['kind']?.toString(),
      lastChapter: json['lastChapter']?.toString(),
      updateTime: json['updateTime']?.toString(),
      coverUrl: json['coverUrl']?.toString(),
      tocUrl: json['tocUrl']?.toString(),
      wordCount: json['wordCount']?.toString(),
      canReName: json['canReName']?.toString(),
      downloadUrls: json['downloadUrls']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'init': init,
      'name': name,
      'author': author,
      'intro': intro,
      'kind': kind,
      'lastChapter': lastChapter,
      'updateTime': updateTime,
      'coverUrl': coverUrl,
      'tocUrl': tocUrl,
      'wordCount': wordCount,
      'canReName': canReName,
      'downloadUrls': downloadUrls,
    };
  }
}

class TocRule {
  final String? preUpdateJs;
  final String? chapterList;
  final String? chapterName;
  final String? chapterUrl;
  final String? formatJs;
  final String? isVolume;
  final String? isVip;
  final String? isPay;
  final String? updateTime;
  final String? nextTocUrl;

  const TocRule({
    this.preUpdateJs,
    this.chapterList,
    this.chapterName,
    this.chapterUrl,
    this.formatJs,
    this.isVolume,
    this.isVip,
    this.isPay,
    this.updateTime,
    this.nextTocUrl,
  });

  factory TocRule.fromJson(Map<String, dynamic> json) {
    return TocRule(
      preUpdateJs: json['preUpdateJs']?.toString(),
      chapterList: json['chapterList']?.toString(),
      chapterName: json['chapterName']?.toString(),
      chapterUrl: json['chapterUrl']?.toString(),
      formatJs: json['formatJs']?.toString(),
      isVolume: json['isVolume']?.toString(),
      isVip: json['isVip']?.toString(),
      isPay: json['isPay']?.toString(),
      updateTime: json['updateTime']?.toString(),
      nextTocUrl: json['nextTocUrl']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'preUpdateJs': preUpdateJs,
      'chapterList': chapterList,
      'chapterName': chapterName,
      'chapterUrl': chapterUrl,
      'formatJs': formatJs,
      'isVolume': isVolume,
      'isVip': isVip,
      'isPay': isPay,
      'updateTime': updateTime,
      'nextTocUrl': nextTocUrl,
    };
  }
}

class ContentRule {
  final String? content;
  final String? title;
  final String? nextContentUrl;
  final String? webJs;
  final String? sourceRegex;
  final String? replaceRegex;
  final String? imageStyle;
  final String? imageDecode;
  final String? payAction;

  const ContentRule({
    this.content,
    this.title,
    this.nextContentUrl,
    this.webJs,
    this.sourceRegex,
    this.replaceRegex,
    this.imageStyle,
    this.imageDecode,
    this.payAction,
  });

  factory ContentRule.fromJson(Map<String, dynamic> json) {
    return ContentRule(
      content: json['content']?.toString(),
      title: json['title']?.toString(),
      nextContentUrl: json['nextContentUrl']?.toString(),
      webJs: json['webJs']?.toString(),
      sourceRegex: json['sourceRegex']?.toString(),
      replaceRegex: json['replaceRegex']?.toString(),
      imageStyle: json['imageStyle']?.toString(),
      imageDecode: json['imageDecode']?.toString(),
      payAction: json['payAction']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'content': content,
      'title': title,
      'nextContentUrl': nextContentUrl,
      'webJs': webJs,
      'sourceRegex': sourceRegex,
      'replaceRegex': replaceRegex,
      'imageStyle': imageStyle,
      'imageDecode': imageDecode,
      'payAction': payAction,
    };
  }
}

class ReviewRule {
  final String? reviewUrl;
  final String? avatarRule;
  final String? contentRule;
  final String? postTimeRule;
  final String? reviewQuoteUrl;
  final String? voteUpUrl;
  final String? voteDownUrl;
  final String? postReviewUrl;
  final String? postQuoteUrl;
  final String? deleteUrl;

  const ReviewRule({
    this.reviewUrl,
    this.avatarRule,
    this.contentRule,
    this.postTimeRule,
    this.reviewQuoteUrl,
    this.voteUpUrl,
    this.voteDownUrl,
    this.postReviewUrl,
    this.postQuoteUrl,
    this.deleteUrl,
  });

  factory ReviewRule.fromJson(Map<String, dynamic> json) {
    return ReviewRule(
      reviewUrl: json['reviewUrl']?.toString(),
      avatarRule: json['avatarRule']?.toString(),
      contentRule: json['contentRule']?.toString(),
      postTimeRule: json['postTimeRule']?.toString(),
      reviewQuoteUrl: json['reviewQuoteUrl']?.toString(),
      voteUpUrl: json['voteUpUrl']?.toString(),
      voteDownUrl: json['voteDownUrl']?.toString(),
      postReviewUrl: json['postReviewUrl']?.toString(),
      postQuoteUrl: json['postQuoteUrl']?.toString(),
      deleteUrl: json['deleteUrl']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'reviewUrl': reviewUrl,
      'avatarRule': avatarRule,
      'contentRule': contentRule,
      'postTimeRule': postTimeRule,
      'reviewQuoteUrl': reviewQuoteUrl,
      'voteUpUrl': voteUpUrl,
      'voteDownUrl': voteDownUrl,
      'postReviewUrl': postReviewUrl,
      'postQuoteUrl': postQuoteUrl,
      'deleteUrl': deleteUrl,
    };
  }
}

