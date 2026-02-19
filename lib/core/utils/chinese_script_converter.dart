import 'dart:collection';

import 'chinese_s2t_map.g.dart';
import 'chinese_s2t_phrase_overrides.g.dart';

/// 中文字形转换工具（简繁双向）。
///
/// 语义定位：
/// - 用于阅读正文“简繁转换”设置；
/// - 在保持同步调用链的前提下提供可用转换能力；
/// - 字符映射来源于 OpenCC `STCharacters.txt`（Apache-2.0）。
class ChineseScriptConverter {
  ChineseScriptConverter._();

  static final ChineseScriptConverter instance = ChineseScriptConverter._();

  static const int _cacheLimit = 160;

  final LinkedHashMap<String, String> _s2tCache =
      LinkedHashMap<String, String>();
  final LinkedHashMap<String, String> _t2sCache =
      LinkedHashMap<String, String>();

  static final Map<int, String> _t2sCharMap = _buildReverseCharMap();
  static final Map<String, String> _t2sPhraseOverrides =
      _buildReversePhraseMap();
  static final Set<String> _legacyT2sExcludePhrases =
      _buildLegacyT2sExcludePhrases();
  static final int _t2sPhraseMaxLen =
      _resolveMaxPhraseLen(_t2sPhraseOverrides.keys);
  static final int _t2sExcludeMaxLen =
      _resolveMaxPhraseLen(_legacyT2sExcludePhrases);

  String simplifiedToTraditional(String text) {
    if (text.isEmpty) return text;

    final cached = _s2tCache.remove(text);
    if (cached != null) {
      // LRU：命中后移动到末尾。
      _s2tCache[text] = cached;
      return cached;
    }

    final converted = _convertByPhraseAndCharMap(text);
    _s2tCache[text] = converted;
    if (_s2tCache.length > _cacheLimit) {
      _s2tCache.remove(_s2tCache.keys.first);
    }
    return converted;
  }

  String traditionalToSimplified(String text) {
    if (text.isEmpty) return text;

    final cached = _t2sCache.remove(text);
    if (cached != null) {
      // LRU：命中后移动到末尾。
      _t2sCache[text] = cached;
      return cached;
    }

    final converted = _convertTraditionalToSimplified(text);
    _t2sCache[text] = converted;
    if (_t2sCache.length > _cacheLimit) {
      _t2sCache.remove(_t2sCache.keys.first);
    }
    return converted;
  }

  String _convertByPhraseAndCharMap(String text) {
    final buffer = StringBuffer();
    var index = 0;
    while (index < text.length) {
      var matched = false;
      final remain = text.length - index;
      final maxTry =
          remain < kOpenccS2tPhraseMaxLen ? remain : kOpenccS2tPhraseMaxLen;

      // 对标 OpenCC 短语优先策略：当前位置按最长短语优先匹配。
      for (var len = maxTry; len >= 2; len--) {
        final segment = text.substring(index, index + len);
        final phraseMapped = kOpenccS2tPhraseOverrides[segment];
        if (phraseMapped == null) continue;
        buffer.write(phraseMapped);
        index += len;
        matched = true;
        break;
      }

      if (matched) continue;

      final rune = _runeAt(text, index);
      final mapped = kOpenccS2tCharMap[rune];
      buffer.write(mapped ?? String.fromCharCode(rune));
      index += _runeCodeUnitLength(text, index);
    }
    return buffer.toString();
  }

  String _convertTraditionalToSimplified(String text) {
    final buffer = StringBuffer();
    var index = 0;
    while (index < text.length) {
      var matched = false;
      final remain = text.length - index;
      final maxDictLen = _t2sPhraseMaxLen > _t2sExcludeMaxLen
          ? _t2sPhraseMaxLen
          : _t2sExcludeMaxLen;
      final maxTry = remain < maxDictLen ? remain : maxDictLen;

      // 与简转繁保持一致：当前位置按最长短语优先匹配。
      for (var len = maxTry; len >= 2; len--) {
        final segment = text.substring(index, index + len);
        if (_legacyT2sExcludePhrases.contains(segment)) {
          buffer.write(segment);
          index += len;
          matched = true;
          break;
        }
        final phraseMapped = _t2sPhraseOverrides[segment];
        if (phraseMapped == null) continue;
        buffer.write(phraseMapped);
        index += len;
        matched = true;
        break;
      }

      if (matched) continue;

      final rune = _runeAt(text, index);
      final mapped = _t2sCharMap[rune];
      buffer.write(mapped ?? String.fromCharCode(rune));
      index += _runeCodeUnitLength(text, index);
    }
    return buffer.toString();
  }

  static Map<int, String> _buildReverseCharMap() {
    final reversed = <int, String>{};
    for (final entry in kOpenccS2tCharMap.entries) {
      final simplified = String.fromCharCode(entry.key);
      final traditional = entry.value;
      if (traditional.runes.length != 1) continue;
      final traditionalRune = traditional.runes.first;
      reversed.putIfAbsent(traditionalRune, () => simplified);
    }
    return Map<int, String>.unmodifiable(reversed);
  }

  static Map<String, String> _buildReversePhraseMap() {
    final reversed = <String, String>{};
    for (final entry in kOpenccS2tPhraseOverrides.entries) {
      reversed.putIfAbsent(entry.value, () => entry.key);
    }
    return Map<String, String>.unmodifiable(reversed);
  }

  static int _resolveMaxPhraseLen(Iterable<String> keys) {
    var maxLen = 2;
    for (final key in keys) {
      if (key.length > maxLen) {
        maxLen = key.length;
      }
    }
    return maxLen;
  }

  static Set<String> _buildLegacyT2sExcludePhrases() {
    // 对齐 legado 的 T2S 例外词典（ChineseUtils.fixT2sDict）。
    const phrases = <String>[
      '槃',
      '划槳',
      '列根',
      '雪梨',
      '雪糕',
      '多士',
      '起司',
      '芝士',
      '沙芬',
      '母音',
      '华乐',
      '民乐',
      '晶元',
      '晶片',
      '映像',
      '明覆',
      '明瞭',
      '新力',
      '新喻',
      '零錢',
      '零钱',
      '離線',
      '碟片',
      '模組',
      '桌球',
      '案頭',
      '機車',
      '電漿',
      '鳳梨',
      '魔戒',
      '載入',
      '菲林',
      '整合',
      '變數',
      '解碼',
      '散钱',
      '插水',
      '房屋',
      '房价',
      '快取',
      '德士',
      '建立',
      '常式',
      '席丹',
      '布殊',
      '布希',
      '巴哈',
      '巨集',
      '夜学',
      '向量',
      '半形',
      '加彭',
      '列印',
      '函式',
      '全形',
      '光碟',
      '介面',
      '乳酪',
      '沈船',
      '永珍',
      '演化',
      '牛油',
      '相容',
      '磁碟',
      '菲林',
      '規則',
      '酵素',
      '雷根',
      '饭盒',
      '路易斯',
      '非同步',
      '出租车',
      '周杰倫',
      '马铃薯',
      '馬鈴薯',
      '機械人',
      '電單車',
      '電扶梯',
      '音效卡',
      '飆車族',
      '點陣圖',
      '個入球',
      '顆進球',
      '沃尓沃',
      '晶片集',
      '斯瓦巴',
      '斜角巷',
      '战列舰',
      '快速面',
      '希特拉',
      '太空梭',
      '吐瓦魯',
      '吉布堤',
      '吉布地',
      '史太林',
      '南冰洋',
      '区域网',
      '波札那',
      '解析度',
      '酷洛米',
      '金夏沙',
      '魔獸紀元',
      '高空彈跳',
      '铁达尼号',
      '太空战士',
      '埃及妖后',
      '吉里巴斯',
      '附加元件',
      '魔鬼終結者',
      '純文字檔案',
      '奇幻魔法Melody',
      '列支敦斯登',
    ];
    return Set<String>.unmodifiable(phrases);
  }

  int _runeAt(String text, int index) {
    final first = text.codeUnitAt(index);
    if (first < 0xD800 || first > 0xDBFF || index + 1 >= text.length) {
      return first;
    }
    final second = text.codeUnitAt(index + 1);
    if (second < 0xDC00 || second > 0xDFFF) {
      return first;
    }
    return 0x10000 + ((first - 0xD800) << 10) + (second - 0xDC00);
  }

  int _runeCodeUnitLength(String text, int index) {
    final first = text.codeUnitAt(index);
    if (first < 0xD800 || first > 0xDBFF || index + 1 >= text.length) {
      return 1;
    }
    final second = text.codeUnitAt(index + 1);
    if (second < 0xDC00 || second > 0xDFFF) {
      return 1;
    }
    return 2;
  }
}
