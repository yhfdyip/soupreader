import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:soupreader/core/utils/legado_json.dart';
import 'package:soupreader/features/source/models/book_source.dart';
import 'package:soupreader/features/source/services/source_import_commit_service.dart';
import 'package:soupreader/features/source/services/source_import_selection_helper.dart';

void main() {
  group('SourceImportCommitService', () {
    test('拦截18+域名并返回导入统计', () async {
      final store = _FakeSourceStore();
      var afterCommitCount = 0;
      final service = SourceImportCommitService(
        upsertSourceRawJson: store.upsert,
        loadAllSources: store.allSources,
        loadRawJsonByUrl: store.rawJsonByUrl,
        loadBlockedHosts: () async => <String>{'blocked.com'},
        afterCommit: () async {
          afterCommitCount++;
        },
      );

      final blocked = _planItem(
        source: _source(
          url: 'https://a.blocked.com/source.json',
          name: '被拦截',
          customOrder: 3,
        ),
        state: SourceImportCandidateState.newSource,
      );
      final allowed = _planItem(
        source: _source(
          url: 'https://safe.example.com/source.json',
          name: '可导入',
          customOrder: 4,
        ),
        state: SourceImportCandidateState.update,
      );

      final result = await service.commit([blocked, allowed]);

      expect(result.imported, 1);
      expect(result.newCount, 0);
      expect(result.updateCount, 1);
      expect(result.existingCount, 0);
      expect(result.blockedCount, 1);
      expect(result.blockedNames, contains('被拦截'));
      expect(store.allSources().length, 1);
      expect(store.allSources().first.bookSourceName, '可导入');
      expect(afterCommitCount, 1);
    });

    test('多段公共后缀域名按主域语义拦截', () async {
      final store = _FakeSourceStore();
      final service = SourceImportCommitService(
        upsertSourceRawJson: store.upsert,
        loadAllSources: store.allSources,
        loadRawJsonByUrl: store.rawJsonByUrl,
        loadBlockedHosts: () async => <String>{'news.co.uk'},
      );

      final blocked = _planItem(
        source: _source(
          url: 'https://reader.news.co.uk/source.json',
          name: '英国源',
          customOrder: 2,
        ),
        state: SourceImportCandidateState.newSource,
      );

      final result = await service.commit([blocked]);
      expect(result.imported, 0);
      expect(result.blockedCount, 1);
      expect(result.blockedNames, contains('英国源'));
      expect(store.allSources(), isEmpty);
    });

    test('排序号超界或重复时自动归一为连续序号', () async {
      final store = _FakeSourceStore();
      var afterCommitCount = 0;
      await store.upsert(
        rawJson: LegadoJson.encode(
          _source(
            url: 'https://a.example.com/s.json',
            name: 'A',
            customOrder: 100100,
          ).toJson(),
        ),
      );
      await store.upsert(
        rawJson: LegadoJson.encode(
          _source(
            url: 'https://b.example.com/s.json',
            name: 'B',
            customOrder: 100100,
          ).toJson(),
        ),
      );

      final service = SourceImportCommitService(
        upsertSourceRawJson: store.upsert,
        loadAllSources: store.allSources,
        loadRawJsonByUrl: store.rawJsonByUrl,
        loadBlockedHosts: () async => const <String>{},
        afterCommit: () async {
          afterCommitCount++;
        },
      );
      final incoming = _planItem(
        source: _source(
          url: 'https://c.example.com/s.json',
          name: 'C',
          customOrder: 100200,
        ),
        state: SourceImportCandidateState.newSource,
      );

      final result = await service.commit([incoming]);

      expect(result.imported, 1);
      final sorted = store.allSources().toList()
        ..sort((a, b) => a.bookSourceUrl.compareTo(b.bookSourceUrl));
      expect(
        sorted.map((source) => source.customOrder).toList(),
        [0, 1, 2],
      );
      for (final source in sorted) {
        final raw = store.rawJsonByUrl(source.bookSourceUrl);
        final decoded = json.decode(raw!) as Map<String, dynamic>;
        expect(decoded['customOrder'], source.customOrder);
      }
      expect(afterCommitCount, 1);
    });

    test('全部被拦截时不触发后处理回调', () async {
      final store = _FakeSourceStore();
      var afterCommitCount = 0;
      final service = SourceImportCommitService(
        upsertSourceRawJson: store.upsert,
        loadAllSources: store.allSources,
        loadRawJsonByUrl: store.rawJsonByUrl,
        loadBlockedHosts: () async => <String>{'blocked.com'},
        afterCommit: () async {
          afterCommitCount++;
        },
      );

      final blockedOnly = _planItem(
        source: _source(
          url: 'https://m.blocked.com/source.json',
          name: '只拦截',
          customOrder: 1,
        ),
        state: SourceImportCandidateState.newSource,
      );

      final result = await service.commit([blockedOnly]);
      expect(result.imported, 0);
      expect(result.blockedCount, 1);
      expect(afterCommitCount, 0);
    });
  });
}

BookSource _source({
  required String url,
  required String name,
  required int customOrder,
}) {
  return BookSource(
    bookSourceUrl: url,
    bookSourceName: name,
    customOrder: customOrder,
    enabled: true,
    enabledExplore: true,
  );
}

SourceImportCommitPlanItem _planItem({
  required BookSource source,
  required SourceImportCandidateState state,
}) {
  return SourceImportCommitPlanItem(
    url: source.bookSourceUrl,
    source: source,
    rawJson: LegadoJson.encode(source.toJson()),
    state: state,
  );
}

class _FakeSourceStore {
  final Map<String, String> _rawByUrl = <String, String>{};
  final Map<String, BookSource> _sourceByUrl = <String, BookSource>{};

  Future<void> upsert({
    String? originalUrl,
    required String rawJson,
  }) async {
    final oldUrl = (originalUrl ?? '').trim();
    final decoded = json.decode(rawJson) as Map<String, dynamic>;
    final source = BookSource.fromJson(decoded);
    final url = source.bookSourceUrl.trim();
    if (oldUrl.isNotEmpty && oldUrl != url) {
      _rawByUrl.remove(oldUrl);
      _sourceByUrl.remove(oldUrl);
    }
    _rawByUrl[url] = rawJson;
    _sourceByUrl[url] = source;
  }

  List<BookSource> allSources() {
    return _sourceByUrl.values.toList(growable: false);
  }

  String? rawJsonByUrl(String url) {
    return _rawByUrl[url];
  }
}
