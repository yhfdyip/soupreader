import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;

import '../../../core/utils/html_text_formatter.dart';
import '../models/rule_parser_types.dart';

/// 文本提取与正则替换辅助工具
///
/// 处理从 HTML 元素中提取文本、应用 legado 风格正则替换、
/// 以及正文内容清理。
class RuleParserTextExtractHelper {
  /// 从 HTML 元素中按提取器列表逐个尝试提取值。
  ///
  /// [absoluteUrl] 用于将 href/src 属性转为绝对链接。
  String extractWithFallbacks(
    Element target,
    List<String> extractors, {
    required String baseUrl,
    required String Function(String baseUrl, String url) absoluteUrl,
  }) {
    for (final ex in extractors) {
      final token = ex.trim();
      if (token.isEmpty) continue;
      final lower = token.toLowerCase();

      String value;
      if (lower == 'text') {
        value = target.text;
      } else if (lower == 'textnodes') {
        value = extractTextNodesLikeLegado(target);
      } else if (lower == 'owntext') {
        value = extractOwnTextLikeLegado(target);
      } else if (lower == 'html' || lower == 'innerhtml') {
        value = extractHtmlLikeLegado(target);
      } else if (lower == 'outerhtml' || lower == 'all') {
        value = target.outerHtml;
      } else {
        value = target.attributes[token] ??
            target.attributes[lower] ??
            target.attributes[token.toLowerCase()] ??
            '';
      }

      value = value.trim();
      if (value.isEmpty) continue;

      if (lower == 'href' || lower == 'src') {
        value = absoluteUrl(baseUrl, value);
      }
      return value;
    }
    return '';
  }

  /// 提取元素直接子文本节点并按换行拼接。
  String extractTextNodesLikeLegado(Element target) {
    final lines = <String>[];
    for (final node in target.nodes.whereType<Text>()) {
      final text = node.text.trim();
      if (text.isEmpty) continue;
      lines.add(text);
    }
    return lines.join('\n');
  }

  /// 提取元素自身文本（不含子元素文本），保留原始空白。
  String extractOwnTextLikeLegado(Element target) {
    final buf = StringBuffer();
    for (final node in target.nodes.whereType<Text>()) {
      buf.write(node.text);
    }
    return buf.toString();
  }

  /// 提取元素内部 HTML（移除 script/style）。
  String extractHtmlLikeLegado(Element target) {
    final fragment =
        html_parser.parseFragment(target.outerHtml);
    for (final node in fragment.querySelectorAll('script')) {
      node.remove();
    }
    for (final node in fragment.querySelectorAll('style')) {
      node.remove();
    }
    return fragment.nodes.map((node) {
      if (node is Element) return node.outerHtml;
      if (node is Text) return node.text;
      return node.toString();
    }).join();
  }

  /// 依次应用内联替换规则列表。
  String applyInlineReplacements(
    String input,
    List<LegadoReplacePair> replacements,
  ) {
    var result = input;
    for (final r in replacements) {
      final pattern = r.pattern;
      final replacement = r.replacement;
      if (pattern.isEmpty) continue;
      result = applyLegacyReplaceRegex(
        content: result,
        pattern: pattern,
        replacement: replacement,
        firstOnly: r.firstOnly,
      );
    }
    return result;
  }

  /// 应用单条正则替换（legado 语义）。
  String applyLegacyReplaceRegex({
    required String content,
    required String pattern,
    required String replacement,
    required bool firstOnly,
  }) {
    if (pattern.isEmpty) return content;

    if (firstOnly) {
      try {
        final regex = RegExp(pattern);
        final matcher = regex.firstMatch(content);
        if (matcher == null) return '';
        final matchedText = matcher.group(0) ?? '';
        return matchedText.replaceFirst(regex, replacement);
      } catch (_) {
        return replacement;
      }
    }

    try {
      return content.replaceAll(RegExp(pattern), replacement);
    } catch (_) {
      return content.replaceAll(pattern, replacement);
    }
  }

  /// 应用 `##` 分隔的替换正则链。
  String applyReplaceRegex(
    String content,
    String replaceRegex,
  ) {
    final parts = replaceRegex.split('##');
    if (parts.isEmpty) return content;

    var start = 0;
    if (parts.length >= 3 && parts.length.isOdd) {
      final pattern = parts[0];
      if (pattern.isNotEmpty) {
        final replacement = parts[1];
        content = applyLegacyReplaceRegex(
          content: content,
          pattern: pattern,
          replacement: replacement,
          firstOnly: true,
        );
      }
      start = 3;
    }

    for (int i = start; i < parts.length - 1; i += 2) {
      final pattern = parts[i];
      if (pattern.isEmpty) continue;
      final replacement =
          parts.length > i + 1 ? parts[i + 1] : '';
      content = applyLegacyReplaceRegex(
        content: content,
        pattern: pattern,
        replacement: replacement,
        firstOnly: false,
      );
    }

    return content;
  }

  /// 清理正文内容（保留并绝对化 img 标签）。
  String cleanContent(
    String content, {
    required String baseUrl,
  }) {
    return HtmlTextFormatter.formatKeepImageTags(
      content,
      baseUrl: baseUrl,
    );
  }
}
