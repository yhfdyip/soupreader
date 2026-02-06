import 'dart:convert';

import '../../../features/source/models/book_source.dart';
import '../../utils/legado_json.dart';
import '../database_service.dart';
import '../entities/book_entity.dart';

/// 书源存储仓库
class SourceRepository {
  final DatabaseService _db;

  SourceRepository(this._db);

  List<BookSource> getAllSources() {
    return _db.sourcesBox.values.map(_entityToSource).toList();
  }

  BookSource? getSourceByUrl(String url) {
    final entity = _db.sourcesBox.get(url);
    return entity != null ? _entityToSource(entity) : null;
  }

  Future<void> addSource(BookSource source) async {
    await _db.sourcesBox.put(source.bookSourceUrl, _sourceToEntity(source));
  }

  Future<void> addSources(List<BookSource> sources) async {
    final entries = <String, BookSourceEntity>{};
    for (final source in sources) {
      entries[source.bookSourceUrl] = _sourceToEntity(source);
    }
    await _db.sourcesBox.putAll(entries);
  }

  Future<void> updateSource(BookSource source) async {
    await addSource(source);
  }

  /// 以「原始 JSON」形式保存书源（编辑器/对标 legado 推荐用法）：
  /// - 按 JSON 中的 `bookSourceUrl` 作为主键
  /// - `rawJson` 会按 LegadoJson 规则剥离 null 字段
  /// - 可选删除旧主键（当用户改了 bookSourceUrl）
  Future<void> upsertSourceRawJson({
    String? originalUrl,
    required String rawJson,
  }) async {
    final decoded = json.decode(rawJson);
    if (decoded is! Map) {
      throw const FormatException('书源 JSON 必须是对象（Map）');
    }
    final map = decoded is Map<String, dynamic>
        ? decoded
        : decoded.map((key, value) => MapEntry('$key', value));

    final source = BookSource.fromJson(map);
    if (source.bookSourceUrl.trim().isEmpty) {
      throw const FormatException('bookSourceUrl 不能为空');
    }

    final normalizedRawJson = LegadoJson.encode(map);
    final entity = _sourceToEntity(source, rawJsonOverride: normalizedRawJson);

    if (originalUrl != null &&
        originalUrl.trim().isNotEmpty &&
        originalUrl != source.bookSourceUrl) {
      await _db.sourcesBox.delete(originalUrl);
    }
    await _db.sourcesBox.put(source.bookSourceUrl, entity);
  }

  Future<void> deleteSource(String url) async {
    await _db.sourcesBox.delete(url);
  }

  Future<void> deleteDisabledSources() async {
    final disabled = _db.sourcesBox.values
        .where((source) => !source.enabled)
        .map((source) => source.bookSourceUrl)
        .toList();
    await _db.sourcesBox.deleteAll(disabled);
  }

  List<BookSource> fromEntities(Iterable<BookSourceEntity> entities) {
    return entities.map(_entityToSource).toList();
  }

  BookSourceEntity _sourceToEntity(
    BookSource source, {
    String? rawJsonOverride,
  }) {
    final rawJson = rawJsonOverride ?? LegadoJson.encode(source.toJson());
    return BookSourceEntity(
      bookSourceUrl: source.bookSourceUrl,
      bookSourceName: source.bookSourceName,
      bookSourceGroup: source.bookSourceGroup,
      bookSourceType: source.bookSourceType,
      enabled: source.enabled,
      bookSourceComment: source.bookSourceComment,
      weight: source.weight,
      header: source.header,
      loginUrl: source.loginUrl,
      lastUpdateTime: source.lastUpdateTime > 0
          ? DateTime.fromMillisecondsSinceEpoch(source.lastUpdateTime)
          : null,
      ruleSearchJson: _encodeRule(source.ruleSearch?.toJson()),
      ruleBookInfoJson: _encodeRule(source.ruleBookInfo?.toJson()),
      ruleTocJson: _encodeRule(source.ruleToc?.toJson()),
      ruleContentJson: _encodeRule(source.ruleContent?.toJson()),
      rawJson: rawJson,
    );
  }

  BookSource _entityToSource(BookSourceEntity entity) {
    final raw = entity.rawJson;
    if (raw != null && raw.trim().isNotEmpty) {
      try {
        final decoded = json.decode(raw);
        if (decoded is Map<String, dynamic>) {
          return BookSource.fromJson(decoded);
        }
        if (decoded is Map) {
          return BookSource.fromJson(
            decoded.map((key, value) => MapEntry('$key', value)),
          );
        }
      } catch (_) {
        // fallthrough
      }
    }

    // 兼容旧存储：从拆分字段拼回一个 Legado 结构
    final lastUpdateTime = entity.lastUpdateTime?.millisecondsSinceEpoch ?? 0;
    return BookSource.fromJson({
      'bookSourceUrl': entity.bookSourceUrl,
      'bookSourceName': entity.bookSourceName,
      'bookSourceGroup': entity.bookSourceGroup,
      'bookSourceType': entity.bookSourceType,
      'customOrder': 0,
      'enabled': entity.enabled,
      'enabledExplore': true,
      'jsLib': null,
      'enabledCookieJar': true,
      'concurrentRate': null,
      'header': entity.header,
      'loginUrl': entity.loginUrl,
      'loginUi': null,
      'loginCheckJs': null,
      'coverDecodeJs': null,
      'bookSourceComment': entity.bookSourceComment,
      'variableComment': null,
      'lastUpdateTime': lastUpdateTime,
      'respondTime': 180000,
      'weight': entity.weight,
      'exploreUrl': null,
      'exploreScreen': null,
      'ruleExplore': null,
      'searchUrl': null,
      'ruleSearch': _decodeRule(entity.ruleSearchJson, SearchRule.fromJson)?.toJson(),
      'ruleBookInfo':
          _decodeRule(entity.ruleBookInfoJson, BookInfoRule.fromJson)?.toJson(),
      'ruleToc': _decodeRule(entity.ruleTocJson, TocRule.fromJson)?.toJson(),
      'ruleContent':
          _decodeRule(entity.ruleContentJson, ContentRule.fromJson)?.toJson(),
      'ruleReview': null,
    });
  }

  String? _encodeRule(Map<String, dynamic>? rule) {
    if (rule == null) return null;
    return LegadoJson.encode(rule);
  }

  T? _decodeRule<T>(
    String? jsonString,
    T Function(Map<String, dynamic>) mapper,
  ) {
    if (jsonString == null || jsonString.trim().isEmpty) return null;
    final raw = json.decode(jsonString);
    if (raw is Map<String, dynamic>) {
      return mapper(raw);
    }
    if (raw is Map) {
      return mapper(raw.map((key, value) => MapEntry('$key', value)));
    }
    return null;
  }
}
