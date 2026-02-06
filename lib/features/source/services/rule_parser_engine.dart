import 'package:dio/dio.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart';
import '../models/book_source.dart';
import 'package:flutter/foundation.dart';
import '../../../core/utils/html_text_formatter.dart';

/// 书源规则解析引擎
/// 支持 CSS 选择器、XPath（简化版）和正则表达式
class RuleParserEngine {
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 15),
    headers: {
      'User-Agent': 'Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) '
          'AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.0 Mobile/15E148 Safari/604.1',
    },
  ));

  /// 搜索书籍
  Future<List<SearchResult>> search(BookSource source, String keyword) async {
    final searchRule = source.ruleSearch;
    final searchUrlRule = source.searchUrl;
    if (searchRule == null || searchUrlRule == null || searchUrlRule.isEmpty) {
      return [];
    }

    try {
      // 构建搜索URL
      final searchUrl = _buildUrl(
        source.bookSourceUrl,
        searchUrlRule,
        {'key': keyword, 'searchKey': keyword},
      );

      // 发送请求
      final response = await _fetch(searchUrl, source.header);
      if (response == null) return [];

      // 解析结果
      final document = html_parser.parse(response);
      final results = <SearchResult>[];

      // 获取书籍列表
      final bookListRule = searchRule.bookList ?? '';
      final bookElements = _querySelectorAll(document, bookListRule);

      for (final element in bookElements) {
        final result = SearchResult(
          name: _parseRule(element, searchRule.name, source.bookSourceUrl),
          author: _parseRule(element, searchRule.author, source.bookSourceUrl),
          coverUrl:
              _parseRule(element, searchRule.coverUrl, source.bookSourceUrl),
          intro: _parseRule(element, searchRule.intro, source.bookSourceUrl),
          lastChapter:
              _parseRule(element, searchRule.lastChapter, source.bookSourceUrl),
          bookUrl:
              _parseRule(element, searchRule.bookUrl, source.bookSourceUrl),
          sourceUrl: source.bookSourceUrl,
          sourceName: source.bookSourceName,
        );

        if (result.name.isNotEmpty && result.bookUrl.isNotEmpty) {
          results.add(result);
        }
      }

      return results;
    } catch (e) {
      debugPrint('搜索失败: $e');
      return [];
    }
  }

  /// 发现书籍
  ///
  /// 对标 Legado：`exploreUrl` + `ruleExplore`
  Future<List<SearchResult>> explore(
    BookSource source, {
    String? exploreUrlOverride,
  }) async {
    final exploreRule = source.ruleExplore;
    final exploreUrlRule = exploreUrlOverride ?? source.exploreUrl;
    if (exploreRule == null ||
        exploreUrlRule == null ||
        exploreUrlRule.trim().isEmpty) {
      return [];
    }

    try {
      final exploreUrl = _buildUrl(
        source.bookSourceUrl,
        exploreUrlRule,
        const {},
      );

      final response = await _fetch(exploreUrl, source.header);
      if (response == null) return [];

      final document = html_parser.parse(response);
      final results = <SearchResult>[];

      final bookListRule = exploreRule.bookList ?? '';
      final bookElements = _querySelectorAll(document, bookListRule);

      for (final element in bookElements) {
        final result = SearchResult(
          name: _parseRule(element, exploreRule.name, source.bookSourceUrl),
          author: _parseRule(element, exploreRule.author, source.bookSourceUrl),
          coverUrl:
              _parseRule(element, exploreRule.coverUrl, source.bookSourceUrl),
          intro: _parseRule(element, exploreRule.intro, source.bookSourceUrl),
          lastChapter:
              _parseRule(element, exploreRule.lastChapter, source.bookSourceUrl),
          bookUrl:
              _parseRule(element, exploreRule.bookUrl, source.bookSourceUrl),
          sourceUrl: source.bookSourceUrl,
          sourceName: source.bookSourceName,
        );

        if (result.name.isNotEmpty && result.bookUrl.isNotEmpty) {
          results.add(result);
        }
      }

      return results;
    } catch (e) {
      debugPrint('发现失败: $e');
      return [];
    }
  }

  /// 获取书籍详情
  Future<BookDetail?> getBookInfo(BookSource source, String bookUrl) async {
    final bookInfoRule = source.ruleBookInfo;
    if (bookInfoRule == null) return null;

    try {
      final fullUrl = _absoluteUrl(source.bookSourceUrl, bookUrl);
      final response = await _fetch(fullUrl, source.header);
      if (response == null) return null;

      final document = html_parser.parse(response);
      Element? root = document.documentElement;

      // 如果有 init 规则，先定位根元素
      if (bookInfoRule.init != null && bookInfoRule.init!.isNotEmpty) {
        root = _querySelector(document, bookInfoRule.init!);
      }

      if (root == null) return null;

      return BookDetail(
        name: _parseRule(root, bookInfoRule.name, source.bookSourceUrl),
        author: _parseRule(root, bookInfoRule.author, source.bookSourceUrl),
        coverUrl: _parseRule(root, bookInfoRule.coverUrl, source.bookSourceUrl),
        intro: _parseRule(root, bookInfoRule.intro, source.bookSourceUrl),
        kind: _parseRule(root, bookInfoRule.kind, source.bookSourceUrl),
        lastChapter:
            _parseRule(root, bookInfoRule.lastChapter, source.bookSourceUrl),
        tocUrl: _parseRule(root, bookInfoRule.tocUrl, source.bookSourceUrl),
        bookUrl: fullUrl,
      );
    } catch (e) {
      debugPrint('获取书籍详情失败: $e');
      return null;
    }
  }

  /// 获取目录
  Future<List<TocItem>> getToc(BookSource source, String tocUrl) async {
    final tocRule = source.ruleToc;
    if (tocRule == null) return [];

    try {
      final fullUrl = _absoluteUrl(source.bookSourceUrl, tocUrl);
      final response = await _fetch(fullUrl, source.header);
      if (response == null) return [];

      final document = html_parser.parse(response);
      final chapters = <TocItem>[];

      // 获取章节列表
      final chapterListRule = tocRule.chapterList ?? '';
      final chapterElements = _querySelectorAll(document, chapterListRule);

      for (int i = 0; i < chapterElements.length; i++) {
        final element = chapterElements[i];
        final item = TocItem(
          index: i,
          name: _parseRule(element, tocRule.chapterName, source.bookSourceUrl),
          url: _parseRule(element, tocRule.chapterUrl, source.bookSourceUrl),
        );

        if (item.name.isNotEmpty && item.url.isNotEmpty) {
          chapters.add(item);
        }
      }

      return chapters;
    } catch (e) {
      debugPrint('获取目录失败: $e');
      return [];
    }
  }

  /// 获取正文
  Future<String> getContent(BookSource source, String chapterUrl) async {
    final contentRule = source.ruleContent;
    if (contentRule == null) return '';

    try {
      final fullUrl = _absoluteUrl(source.bookSourceUrl, chapterUrl);
      final response = await _fetch(fullUrl, source.header);
      if (response == null) return '';

      final document = html_parser.parse(response);
      String content = _parseRule(
        document.documentElement!,
        contentRule.content,
        source.bookSourceUrl,
      );

      // 应用替换规则
      if (contentRule.replaceRegex != null &&
          contentRule.replaceRegex!.isNotEmpty) {
        content = _applyReplaceRegex(content, contentRule.replaceRegex!);
      }

      // 清理内容
      content = _cleanContent(content);

      return content;
    } catch (e) {
      debugPrint('获取正文失败: $e');
      return '';
    }
  }

  /// 发送HTTP请求
  Future<String?> _fetch(String url, String? header) async {
    try {
      final options = Options();
      if (header != null && header.isNotEmpty) {
        try {
          // 尝试解析自定义 header
          final headers = <String, String>{};
          for (final line in header.split('\n')) {
            final parts = line.split(':');
            if (parts.length >= 2) {
              headers[parts[0].trim()] = parts.sublist(1).join(':').trim();
            }
          }
          options.headers = headers;
        } catch (_) {}
      }

      final response = await _dio.get(url, options: options);
      return response.data?.toString();
    } catch (e) {
      debugPrint('请求失败: $url - $e');
      return null;
    }
  }

  /// 构建URL
  String _buildUrl(String baseUrl, String rule, Map<String, String> params) {
    String url = rule;

    // 替换参数
    params.forEach((key, value) {
      url = url.replaceAll('{{$key}}', Uri.encodeComponent(value));
      url = url.replaceAll('{$key}', Uri.encodeComponent(value));
    });

    return _absoluteUrl(baseUrl, url);
  }

  /// 转换为绝对URL
  String _absoluteUrl(String baseUrl, String url) {
    if (url.isEmpty) return '';
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return url;
    }
    if (url.startsWith('//')) {
      return 'https:$url';
    }
    if (url.startsWith('/')) {
      final uri = Uri.parse(baseUrl);
      return '${uri.scheme}://${uri.host}$url';
    }
    return '$baseUrl/$url';
  }

  /// 解析规则
  String _parseRule(Element element, String? rule, String baseUrl) {
    if (rule == null || rule.isEmpty) return '';

    String result = '';

    // 处理多个规则（用 || 分隔，表示备选）
    final rules = rule.split('||');
    for (final r in rules) {
      result = _parseSingleRule(element, r.trim(), baseUrl);
      if (result.isNotEmpty) break;
    }

    return result.trim();
  }

  /// 解析单个规则
  String _parseSingleRule(Element element, String rule, String baseUrl) {
    if (rule.isEmpty) return '';

    // 提取属性规则 @attr 或 @text
    String? attrRule;
    String selectorRule = rule;

    if (rule.contains('@')) {
      final atIndex = rule.lastIndexOf('@');
      selectorRule = rule.substring(0, atIndex).trim();
      attrRule = rule.substring(atIndex + 1).trim();
    }

    // 如果选择器为空，使用当前元素
    Element? target = element;
    if (selectorRule.isNotEmpty) {
      target = _querySelector(element, selectorRule);
    }

    if (target == null) return '';

    // 获取内容
    String result;
    if (attrRule == null || attrRule == 'text') {
      result = target.text;
    } else if (attrRule == 'textNodes') {
      result = target.nodes.whereType<Text>().map((t) => t.text).join('');
    } else if (attrRule == 'ownText') {
      result = target.nodes.whereType<Text>().map((t) => t.text).join('');
    } else if (attrRule == 'html' || attrRule == 'innerHTML') {
      result = target.innerHtml;
    } else if (attrRule == 'outerHtml') {
      result = target.outerHtml;
    } else {
      result = target.attributes[attrRule] ?? '';
    }

    // 如果是URL属性，转换为绝对路径
    if (attrRule == 'href' || attrRule == 'src') {
      result = _absoluteUrl(baseUrl, result);
    }

    return result.trim();
  }

  /// CSS选择器查询单个元素
  Element? _querySelector(dynamic parent, String selector) {
    if (selector.isEmpty) return null;

    try {
      if (parent is Document) {
        return parent.querySelector(selector);
      } else if (parent is Element) {
        return parent.querySelector(selector);
      }
    } catch (e) {
      debugPrint('选择器解析失败: $selector - $e');
    }

    return null;
  }

  /// CSS选择器查询多个元素
  List<Element> _querySelectorAll(dynamic parent, String selector) {
    if (selector.isEmpty) return [];

    try {
      if (parent is Document) {
        return parent.querySelectorAll(selector);
      } else if (parent is Element) {
        return parent.querySelectorAll(selector);
      }
    } catch (e) {
      debugPrint('选择器解析失败: $selector - $e');
    }

    return [];
  }

  /// 应用替换正则
  String _applyReplaceRegex(String content, String replaceRegex) {
    try {
      // 源阅格式: regex##replacement##regex2##replacement2...
      final parts = replaceRegex.split('##');
      for (int i = 0; i < parts.length - 1; i += 2) {
        final regex = RegExp(parts[i]);
        final replacement = parts.length > i + 1 ? parts[i + 1] : '';
        content = content.replaceAll(regex, replacement);
      }
    } catch (e) {
      debugPrint('替换正则失败: $e');
    }
    return content;
  }

  /// 清理正文内容
  String _cleanContent(String content) {
    // 对齐 legado 的 HTML -> 文本清理策略（块级标签换行、不可见字符移除）
    return HtmlTextFormatter.formatToPlainText(content);
  }
}

/// 搜索结果
class SearchResult {
  final String name;
  final String author;
  final String coverUrl;
  final String intro;
  final String lastChapter;
  final String bookUrl;
  final String sourceUrl;
  final String sourceName;

  const SearchResult({
    required this.name,
    required this.author,
    required this.coverUrl,
    required this.intro,
    required this.lastChapter,
    required this.bookUrl,
    required this.sourceUrl,
    required this.sourceName,
  });
}

/// 书籍详情
class BookDetail {
  final String name;
  final String author;
  final String coverUrl;
  final String intro;
  final String kind;
  final String lastChapter;
  final String tocUrl;
  final String bookUrl;

  const BookDetail({
    required this.name,
    required this.author,
    required this.coverUrl,
    required this.intro,
    required this.kind,
    required this.lastChapter,
    required this.tocUrl,
    required this.bookUrl,
  });
}

/// 目录项
class TocItem {
  final int index;
  final String name;
  final String url;

  const TocItem({
    required this.index,
    required this.name,
    required this.url,
  });
}
