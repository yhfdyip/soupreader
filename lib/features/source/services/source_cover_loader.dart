import 'dart:collection';
import 'dart:typed_data';

import '../models/book_source.dart';
import 'rule_parser_engine.dart';

/// 搜索/发现封面的书源感知加载器。
class SourceCoverLoader {
  SourceCoverLoader._();
  static final SourceCoverLoader instance = SourceCoverLoader._();

  static const int _maxMemoryEntries = 240;
  static const Duration _negativeTtl = Duration(minutes: 6);

  final RuleParserEngine _engine = RuleParserEngine();
  final LinkedHashMap<String, Uint8List> _memoryCache =
      LinkedHashMap<String, Uint8List>();
  final Map<String, Future<Uint8List?>> _inflight =
      <String, Future<Uint8List?>>{};
  final Map<String, DateTime> _negativeCacheUntil = <String, DateTime>{};

  String _cacheKey({
    required String sourceUrl,
    required String imageUrl,
  }) {
    return '${sourceUrl.trim()}|${imageUrl.trim()}';
  }

  Uint8List? _getMemory(String key) {
    final data = _memoryCache.remove(key);
    if (data == null) return null;
    // LRU：命中后回插到末尾
    _memoryCache[key] = data;
    return data;
  }

  void _putMemory(String key, Uint8List bytes) {
    _memoryCache.remove(key);
    _memoryCache[key] = bytes;
    if (_memoryCache.length <= _maxMemoryEntries) return;
    _memoryCache.remove(_memoryCache.keys.first);
  }

  Future<Uint8List?> load({
    required String imageUrl,
    required BookSource source,
  }) async {
    final trimmedUrl = imageUrl.trim();
    if (trimmedUrl.isEmpty) return null;
    final key =
        _cacheKey(sourceUrl: source.bookSourceUrl, imageUrl: trimmedUrl);

    final memory = _getMemory(key);
    if (memory != null && memory.isNotEmpty) {
      return memory;
    }

    final negativeUntil = _negativeCacheUntil[key];
    if (negativeUntil != null && DateTime.now().isBefore(negativeUntil)) {
      return null;
    }

    final pending = _inflight[key];
    if (pending != null) return pending;

    final future = _engine
        .fetchCoverBytes(source: source, imageUrl: trimmedUrl)
        .then((bytes) {
      if (bytes != null && bytes.isNotEmpty) {
        _negativeCacheUntil.remove(key);
        _putMemory(key, bytes);
        return bytes;
      }
      _negativeCacheUntil[key] = DateTime.now().add(_negativeTtl);
      return null;
    }).catchError((_) {
      _negativeCacheUntil[key] = DateTime.now().add(_negativeTtl);
      return null;
    }).whenComplete(() {
      _inflight.remove(key);
    });

    _inflight[key] = future;
    return future;
  }

  void clearMemoryCache() {
    _memoryCache.clear();
    _negativeCacheUntil.clear();
    _inflight.clear();
  }
}
