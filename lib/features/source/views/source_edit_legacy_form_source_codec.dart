import 'dart:convert';

import '../../../core/utils/legado_json.dart';
import '../models/book_source.dart';

class SourceEditLegacyFormSourceCodec {
  static BookSource parseInitialSource(String rawJson) {
    final map = _tryDecodeJsonMap(rawJson);
    if (map == null) {
      return const BookSource(bookSourceUrl: '', bookSourceName: '');
    }
    return BookSource.fromJson(map);
  }

  static Map<String, dynamic>? _tryDecodeJsonMap(String text) {
    try {
      final decoded = json.decode(text);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) {
        return decoded.map((key, value) => MapEntry('$key', value));
      }
    } catch (_) {}
    return null;
  }

  static String snapshotFor(BookSource source) {
    return LegadoJson.encode(source.toJson());
  }

  static String displayVariableComment(BookSource source) {
    const defaultComment = '源变量可在js中通过source.getVariable()获取';
    final custom = (source.variableComment ?? '').trim();
    if (custom.isEmpty) return defaultComment;
    return '$custom\n$defaultComment';
  }

  static String typeLabel(int type) {
    switch (type) {
      case 1:
        return '音频';
      case 2:
        return '图片';
      case 3:
        return '文件';
      default:
        return '默认';
    }
  }
}
