import 'dart:convert';

/// Legado / Gson 风格的 JSON 编码辅助：
/// - 默认不序列化 null 字段（Gson 默认行为）
/// - Map 中值为 null 的 key 会被移除（递归）
///
/// 注意：List 中的 null 元素不会被移除（Gson 会保留数组里的 null）。
class LegadoJson {
  static dynamic _stripNulls(dynamic value) {
    if (value is Map) {
      final out = <String, dynamic>{};
      for (final entry in value.entries) {
        final key = entry.key.toString();
        final v = entry.value;
        if (v == null) continue;
        out[key] = _stripNulls(v);
      }
      return out;
    }
    if (value is List) {
      return value.map(_stripNulls).toList(growable: false);
    }
    return value;
  }

  static String encode(dynamic value) {
    return json.encode(_stripNulls(value));
  }

  static dynamic decode(String text) {
    return json.decode(text);
  }
}

