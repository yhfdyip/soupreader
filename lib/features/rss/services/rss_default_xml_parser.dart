import '../models/rss_article.dart';

/// 默认 RSS XML 解析器（对齐 legado `RssParserDefault`）
class RssDefaultXmlParser {
  const RssDefaultXmlParser._();

  static final RegExp _itemPattern = RegExp(
    r'<item\b[\s\S]*?<\/item>',
    caseSensitive: false,
  );

  static final RegExp _imgTagPattern = RegExp(
    r'(<img [^>]*>)',
    caseSensitive: false,
  );
  static final RegExp _imgSrcPattern = RegExp(
    r'src\s*=\s*"([^"]+)"',
    caseSensitive: false,
  );

  static List<RssArticle> parse({
    required String sortName,
    required String xml,
    required String sourceUrl,
  }) {
    final articleList = <RssArticle>[];
    for (final match in _itemPattern.allMatches(xml)) {
      final rawItem = match.group(0) ?? '';
      if (rawItem.isEmpty) continue;

      final title = _extractTagTextFromRaw(rawItem, const <String>['title']);
      final link = _extractTagTextFromRaw(rawItem, const <String>['link']);
      final description = _extractTagTextFromRaw(
        rawItem,
        const <String>['description'],
      );
      final content = _extractTagTextFromRaw(
        rawItem,
        const <String>['content:encoded'],
      );
      final pubDate = _extractTagTextFromRaw(
        rawItem,
        const <String>['pubDate', 'time'],
      );

      String? image = _extractTagAttrFromRaw(
        rawItem,
        tagNames: const <String>['media:thumbnail'],
        name: 'url',
      );
      image ??= _extractEnclosureImage(rawItem);
      if ((image == null || image.isEmpty) &&
          description != null &&
          description.isNotEmpty) {
        image = _extractImageUrl(description);
      }
      if ((image == null || image.isEmpty) &&
          content != null &&
          content.isNotEmpty) {
        image = _extractImageUrl(content);
      }

      articleList.add(
        RssArticle(
          origin: sourceUrl,
          sort: sortName,
          title: title ?? '',
          link: link ?? '',
          pubDate: _emptyAsNull(pubDate),
          description: _emptyAsNull(description),
          content: _emptyAsNull(content),
          image: _emptyAsNull(image),
        ),
      );
    }
    return articleList;
  }

  static String? _extractTagTextFromRaw(String raw, List<String> tagNames) {
    for (final tag in tagNames) {
      final normalized = tag.trim();
      if (normalized.isEmpty) continue;
      final escaped = RegExp.escape(normalized);
      final pattern = RegExp(
        '<$escaped\\b[^>]*>([\\s\\S]*?)<\\/$escaped>',
        caseSensitive: false,
      );
      final match = pattern.firstMatch(raw);
      if (match == null) continue;
      final cleaned = _cleanupTagBody(match.group(1) ?? '');
      if (cleaned.isNotEmpty) return cleaned;
    }
    return null;
  }

  static String? _extractTagAttrFromRaw(
    String raw, {
    required List<String> tagNames,
    required String name,
  }) {
    final attr = RegExp.escape(name.trim());
    for (final tag in tagNames) {
      final normalized = tag.trim();
      if (normalized.isEmpty) continue;
      final escaped = RegExp.escape(normalized);
      final pattern = RegExp(
        '<$escaped\\b[^>]*\\b$attr\\s*=\\s*["\']([^"\']+)["\'][^>]*>',
        caseSensitive: false,
      );
      final match = pattern.firstMatch(raw);
      if (match == null) continue;
      final value = match.group(1)?.trim();
      if (value != null && value.isNotEmpty) return value;
    }
    return null;
  }

  static String? _extractEnclosureImage(String rawItem) {
    final tagPattern = RegExp(
      r'<enclosure\b[^>]*>',
      caseSensitive: false,
    );
    for (final match in tagPattern.allMatches(rawItem)) {
      final tag = match.group(0) ?? '';
      if (tag.isEmpty) continue;
      final type = _extractAttrValue(tag, 'type')?.toLowerCase() ?? '';
      if (!type.contains('image/')) continue;
      final url = _extractAttrValue(tag, 'url');
      if (url != null && url.trim().isNotEmpty) return url.trim();
    }
    return null;
  }

  static String? _extractAttrValue(String tag, String attrName) {
    final escaped = RegExp.escape(attrName.trim());
    final pattern = RegExp(
      '\\b$escaped\\s*=\\s*["\']([^"\']+)["\']',
      caseSensitive: false,
    );
    final match = pattern.firstMatch(tag);
    if (match == null) return null;
    final value = match.group(1)?.trim();
    if (value == null || value.isEmpty) return null;
    return value;
  }

  static String _cleanupTagBody(String raw) {
    var value = raw.trim();
    final cdata = RegExp(r'^<!\[CDATA\[([\s\S]*)\]\]>$').firstMatch(value);
    if (cdata != null) {
      value = (cdata.group(1) ?? '').trim();
    }
    if (value.isNotEmpty && value.startsWith('<!--[CDATA[')) {
      value = value
          .replaceFirst(RegExp(r'^<!--\[CDATA\['), '')
          .replaceFirst(RegExp(r'\]\]-->$'), '')
          .trim();
    }
    if (value.isNotEmpty && value.startsWith('<![CDATA[')) {
      value = value
          .replaceFirst(RegExp(r'^<!\[CDATA\['), '')
          .replaceFirst(RegExp(r'\]\]>$'), '')
          .trim();
    }
    return value;
  }

  static String? _extractImageUrl(String input) {
    final tagMatch = _imgTagPattern.firstMatch(input);
    if (tagMatch == null) return null;
    final tag = tagMatch.group(1);
    if (tag == null || tag.isEmpty) return null;
    final srcMatch = _imgSrcPattern.firstMatch(tag);
    if (srcMatch == null) return null;
    return _emptyAsNull(srcMatch.group(1)?.trim());
  }

  static String? _emptyAsNull(String? text) {
    final value = text?.trim();
    if (value == null || value.isEmpty) return null;
    return value;
  }
}
