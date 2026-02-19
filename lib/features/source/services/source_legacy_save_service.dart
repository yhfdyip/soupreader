import '../../../core/utils/legado_json.dart';
import '../models/book_source.dart';

typedef SourceRawUpsert = Future<void> Function({
  String? originalUrl,
  required String rawJson,
});

typedef SourceClearExploreKindsCache = Future<void> Function(BookSource source);

typedef SourceClearJsLibScope = void Function(String? jsLib);
typedef SourceRemoveSourceVariable = Future<void> Function(String sourceUrl);

class SourceLegacySaveService {
  SourceLegacySaveService({
    required SourceRawUpsert upsertSourceRawJson,
    required SourceClearExploreKindsCache clearExploreKindsCache,
    SourceClearJsLibScope? clearJsLibScope,
    SourceRemoveSourceVariable? removeSourceVariable,
    int Function()? nowMillis,
  })  : _upsertSourceRawJson = upsertSourceRawJson,
        _clearExploreKindsCache = clearExploreKindsCache,
        _clearJsLibScope = clearJsLibScope,
        _removeSourceVariable = removeSourceVariable,
        _nowMillis = nowMillis ?? (() => DateTime.now().millisecondsSinceEpoch);

  final SourceRawUpsert _upsertSourceRawJson;
  final SourceClearExploreKindsCache _clearExploreKindsCache;
  final SourceClearJsLibScope? _clearJsLibScope;
  final SourceRemoveSourceVariable? _removeSourceVariable;
  final int Function() _nowMillis;

  Future<BookSource> save({
    required BookSource source,
    BookSource? originalSource,
  }) async {
    final name = source.bookSourceName.trim();
    final url = source.bookSourceUrl.trim();
    if (name.isEmpty || url.isEmpty) {
      throw const FormatException('书源名称和书源地址不能为空');
    }

    final normalizedSource = source.copyWith(
      bookSourceName: source.bookSourceName,
      bookSourceUrl: url,
    );

    final oldSource = originalSource;
    var saving = normalizedSource;
    if (_hasChanged(oldSource, normalizedSource)) {
      saving = normalizedSource.copyWith(lastUpdateTime: _nowMillis());
    }

    if (oldSource != null) {
      if ((oldSource.exploreUrl ?? '') != (saving.exploreUrl ?? '')) {
        await _clearExploreKindsCache(oldSource);
      }
      if ((oldSource.jsLib ?? '') != (saving.jsLib ?? '')) {
        _clearJsLibScope?.call(oldSource.jsLib);
      }
    }

    await _upsertSourceRawJson(
      originalUrl: oldSource?.bookSourceUrl,
      rawJson: LegadoJson.encode(saving.toJson()),
    );
    if (oldSource != null) {
      final oldUrl = oldSource.bookSourceUrl.trim();
      final nextUrl = saving.bookSourceUrl.trim();
      if (oldUrl.isNotEmpty && oldUrl != nextUrl) {
        await _removeSourceVariable?.call(oldUrl);
      }
    }

    return saving;
  }

  bool _hasChanged(BookSource? oldSource, BookSource current) {
    if (oldSource == null) return true;
    return LegadoJson.encode(oldSource.toJson()) !=
        LegadoJson.encode(current.toJson());
  }
}
