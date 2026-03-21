import 'dart:convert';
import 'dart:typed_data';

import 'package:fast_gbk/fast_gbk.dart';

import '../models/rule_parser_types.dart';

/// 编码/解码辅助工具
///
/// 处理 charset 规范化、URL percent-encoding、
/// 响应体解码等与字符编码相关的操作。
class RuleParserEncodingHelper {
  /// 将各种 charset 别名规范化为统一标识。
  String normalizeCharset(String raw) {
    final c = raw.trim().toLowerCase();
    if (c.isEmpty) return '';
    if (c == 'utf8') return 'utf-8';
    if (c == 'utf_8') return 'utf-8';
    if (c == 'gb2312' || c == 'gbk' || c == 'gb18030') return 'gbk';
    return c;
  }

  /// 检查文本中是否包含 percent-encoded 三元组（%XX）。
  bool containsPercentTriplet(String text) {
    if (text.length < 3) return false;
    for (var i = 0; i <= text.length - 3; i++) {
      if (text.codeUnitAt(i) != 0x25) continue; // '%'
      final a = text.codeUnitAt(i + 1);
      final b = text.codeUnitAt(i + 2);
      final aHex = (a >= 48 && a <= 57) ||
          (a >= 65 && a <= 70) ||
          (a >= 97 && a <= 102);
      final bHex = (b >= 48 && b <= 57) ||
          (b >= 65 && b <= 70) ||
          (b >= 97 && b <= 102);
      if (aHex && bHex) return true;
    }
    return false;
  }

  /// 将字节列表按 percent-encoding 规则编码为字符串。
  String percentEncodeBytes(
    List<int> bytes, {
    required bool spaceAsPlus,
  }) {
    const hex = '0123456789ABCDEF';
    final out = StringBuffer();

    for (final b in bytes) {
      final byte = b & 0xFF;
      final isAlphaNum = (byte >= 0x30 && byte <= 0x39) ||
          (byte >= 0x41 && byte <= 0x5A) ||
          (byte >= 0x61 && byte <= 0x7A);
      final isUnreserved = isAlphaNum ||
          byte == 0x2D || // -
          byte == 0x5F || // _
          byte == 0x2E || // .
          byte == 0x7E; // ~
      if (isUnreserved) {
        out.writeCharCode(byte);
        continue;
      }
      if (spaceAsPlus && byte == 0x20) {
        out.write('+');
        continue;
      }
      out.write('%');
      out.write(hex[(byte >> 4) & 0x0F]);
      out.write(hex[byte & 0x0F]);
    }

    return out.toString();
  }

  /// 尝试对 percent-encoded 文本解码；若无编码内容则原样返回。
  String decodeMaybePercentEncoded(
    String token, {
    required bool formStyle,
  }) {
    if (token.isEmpty) return token;
    final hasEncoded = containsPercentTriplet(token);
    final hasFormPlus = formStyle && token.contains('+');
    if (!hasEncoded && !hasFormPlus) return token;

    var input = token;
    if (formStyle && input.contains('+')) {
      input = input.replaceAll('+', '%20');
    }
    try {
      return Uri.decodeComponent(input);
    } catch (_) {
      return token;
    }
  }

  /// JavaScript `escape()` 兼容编码。
  String legacyEscape(String source) {
    if (source.isEmpty) return source;
    final out = StringBuffer();
    for (final code in source.codeUnits) {
      final isDigit = code >= 48 && code <= 57;
      final isUpper = code >= 65 && code <= 90;
      final isLower = code >= 97 && code <= 122;
      if (isDigit || isUpper || isLower) {
        out.writeCharCode(code);
        continue;
      }

      if (code < 16) {
        out.write('%0${code.toRadixString(16)}');
      } else if (code < 256) {
        out.write('%${code.toRadixString(16)}');
      } else {
        out.write('%u${code.toRadixString(16)}');
      }
    }
    return out.toString();
  }

  /// 对单个参数 token 进行编码。
  String encodeParamToken(
    String token, {
    required String normalizedCharset,
    required bool checkEncoded,
    required bool isQuery,
  }) {
    final text = token;
    if (text.isEmpty) return text;

    if (checkEncoded) {
      final already = containsPercentTriplet(text) ||
          (!isQuery && text.contains('+'));
      if (already) return text;
    }

    var source = text;
    if (!checkEncoded) {
      source = decodeMaybePercentEncoded(text, formStyle: !isQuery);
    }

    if (normalizedCharset == 'escape') {
      return legacyEscape(source);
    }

    final bytes = normalizedCharset == 'gbk'
        ? gbk.encode(source)
        : utf8.encode(source);
    return percentEncodeBytes(bytes, spaceAsPlus: !isQuery);
  }

  /// 对 `&` 分隔的参数文本按指定 charset 编码。
  String encodeParamsText(
    String params,
    String? optionCharset, {
    required bool isQuery,
  }) {
    final text = params.trim();
    if (text.isEmpty) return '';

    final nc = normalizeCharset(optionCharset ?? '');
    final checkEncoded = nc.isEmpty;

    final out = <String>[];
    for (final part in text.split('&')) {
      if (part.isEmpty) {
        out.add('');
        continue;
      }
      final idx = part.indexOf('=');
      if (idx < 0) {
        out.add(
          encodeParamToken(
            part,
            normalizedCharset: nc,
            checkEncoded: checkEncoded,
            isQuery: isQuery,
          ),
        );
        continue;
      }

      final key = part.substring(0, idx);
      final value = part.substring(idx + 1);
      final encodedKey = encodeParamToken(
        key,
        normalizedCharset: nc,
        checkEncoded: checkEncoded,
        isQuery: isQuery,
      );
      final encodedValue = encodeParamToken(
        value,
        normalizedCharset: nc,
        checkEncoded: checkEncoded,
        isQuery: isQuery,
      );
      out.add('$encodedKey=$encodedValue');
    }

    return out.join('&');
  }

  /// 对 URL 中 query string 部分按指定 charset 重新编码。
  String encodeUrlQueryByCharset(
    String url,
    String? optionCharset,
  ) {
    if (url.trim().isEmpty) return url;
    final hashIndex = url.indexOf('#');
    final beforeFragment =
        hashIndex >= 0 ? url.substring(0, hashIndex) : url;
    final fragment = hashIndex >= 0 ? url.substring(hashIndex) : '';

    final queryIndex = beforeFragment.indexOf('?');
    if (queryIndex < 0) return url;
    if (queryIndex >= beforeFragment.length - 1) {
      return '$beforeFragment$fragment';
    }

    final base = beforeFragment.substring(0, queryIndex);
    final query = beforeFragment.substring(queryIndex + 1);
    final encodedQuery = encodeParamsText(
      query,
      optionCharset,
      isQuery: true,
    );
    return '$base?$encodedQuery$fragment';
  }

  /// 生成 Content-Type 中 charset 标签值。
  String charsetLabelForContentType(String normalizedCharset) {
    if (normalizedCharset.isEmpty ||
        normalizedCharset == 'escape') {
      return 'UTF-8';
    }
    if (normalizedCharset == 'gbk') return 'GBK';
    return normalizedCharset.toUpperCase();
  }

  /// 从 Content-Type 响应头中提取 charset。
  String? tryParseCharsetFromContentType(String? contentType) {
    final ct = (contentType ?? '').trim();
    if (ct.isEmpty) return null;
    final m = RegExp(r'charset\s*=\s*([^;\s]+)', caseSensitive: false)
        .firstMatch(ct);
    if (m == null) return null;
    final v = m.group(1);
    if (v == null) return null;
    return normalizeCharset(
      v.replaceAll('"', '').replaceAll("'", ''),
    );
  }

  /// 从 HTML head 中 meta 标签提取 charset。
  String? tryParseCharsetFromHtmlHead(Uint8List bytes) {
    final headLen = bytes.length < 4096 ? bytes.length : 4096;
    final head = latin1.decode(
      bytes.sublist(0, headLen),
      allowInvalid: true,
    );
    final m1 = RegExp(
      r'''<meta[^>]+charset\s*=\s*['"]?\s*([^'"\s/>]+)''',
      caseSensitive: false,
    ).firstMatch(head);
    final c1 = m1?.group(1);
    if (c1 != null && c1.trim().isNotEmpty) {
      return normalizeCharset(c1);
    }

    final m2 = RegExp(
      r'''<meta[^>]+http-equiv\s*=\s*['"]content-type['"][^>]+content\s*=\s*['"][^'"]*charset\s*=\s*([^'"\s;]+)''',
      caseSensitive: false,
    ).firstMatch(head);
    final c2 = m2?.group(1);
    if (c2 != null && c2.trim().isNotEmpty) {
      return normalizeCharset(c2);
    }
    return null;
  }

  /// 将响应字节按最佳 charset 解码为文本。
  DecodedText decodeResponseBytes({
    required Uint8List bytes,
    required Map<String, String> responseHeaders,
    String? optionCharset,
  }) {
    final forced =
        optionCharset != null && optionCharset.trim().isNotEmpty
            ? normalizeCharset(optionCharset)
            : '';
    final headerCharset = tryParseCharsetFromContentType(
      responseHeaders['content-type'] ??
          responseHeaders['Content-Type'],
    );
    final htmlCharset = tryParseCharsetFromHtmlHead(bytes);

    final charsetSource = forced.isNotEmpty
        ? 'urlOption.charset'
        : (headerCharset?.isNotEmpty == true)
            ? '响应头 Content-Type'
            : (htmlCharset?.isNotEmpty == true)
                ? 'HTML meta'
                : '默认回退';

    final charset = (forced.isNotEmpty
            ? forced
            : (headerCharset?.isNotEmpty == true
                ? headerCharset!
                : ''))
        .trim();

    final effective =
        charset.isNotEmpty ? charset : (htmlCharset ?? 'utf-8');
    final normalized = normalizeCharset(effective);
    final decisionPrefix =
        '来源=$charsetSource，option=${forced.isEmpty ? '-' : forced}，header=${headerCharset ?? '-'}，meta=${htmlCharset ?? '-'}，effective=${normalized.isEmpty ? 'utf-8' : normalized}';

    try {
      if (normalized == 'gbk') {
        return DecodedText(
          text: gbk.decode(bytes, allowMalformed: true),
          charset: 'gbk',
          charsetSource: charsetSource,
          charsetDecision: '$decisionPrefix，decoder=gbk',
        );
      }
      if (normalized == 'utf-8') {
        return DecodedText(
          text: utf8.decode(bytes, allowMalformed: true),
          charset: 'utf-8',
          charsetSource: charsetSource,
          charsetDecision: '$decisionPrefix，decoder=utf-8',
        );
      }
      return DecodedText(
        text: utf8.decode(bytes, allowMalformed: true),
        charset: normalized,
        charsetSource: charsetSource,
        charsetDecision: '$decisionPrefix，decoder=utf-8(容错)',
      );
    } catch (_) {
      return DecodedText(
        text: latin1.decode(bytes, allowInvalid: true),
        charset: normalized.isEmpty ? 'latin1' : normalized,
        charsetSource: charsetSource,
        charsetDecision: '$decisionPrefix，decoder=latin1(回退)',
      );
    }
  }
}
