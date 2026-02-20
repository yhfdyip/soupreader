import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:soupreader/core/utils/legado_json.dart';
import 'package:soupreader/features/rss/models/rss_source.dart';
import 'package:soupreader/features/rss/services/rss_source_import_commit_service.dart';
import 'package:soupreader/features/rss/services/rss_source_import_selection_helper.dart';

void main() {
  group('RssSourceImportCommitService', () {
    test('commit 返回导入统计并触发 afterCommit', () async {
      final store = _FakeRssSourceStore();
      var afterCommitCount = 0;
      final service = RssSourceImportCommitService(
        upsertSourceRawJson: store.upsert,
        loadAllSources: store.allSources,
        loadRawJsonByUrl: store.rawJsonByUrl,
        afterCommit: () async {
          afterCommitCount++;
        },
      );

      final first = _planItem(
        source: _source(url: 'https://a.com/source.json', name: 'A', customOrder: 3),
        state: RssSourceImportCandidateState.newSource,
      );
      final second = _planItem(
        source: _source(url: 'https://b.com/source.json', name: 'B', customOrder: 4),
        state: RssSourceImportCandidateState.update,
      );

      final result = await service.commit([first, second]);

      expect(result.imported, 2);
      expect(result.newCount, 1);
      expect(result.updateCount, 1);
      expect(result.existingCount, 0);
      expect(store.allSources().length, 2);
      expect(afterCommitCount, 1);
    });

    test('commit 支持 originalUrl 语义（编辑后 URL 变更）', () async {
      final store = _FakeRssSourceStore();
      await store.upsert(
        rawJson: LegadoJson.encode(
          _source(
            url: 'https://old.example.com/source.json',
            name: '旧地址',
            customOrder: 1,
          ).toJson(),
        ),
      );

      final service = RssSourceImportCommitService(
        upsertSourceRawJson: store.upsert,
        loadAllSources: store.allSources,
        loadRawJsonByUrl: store.rawJsonByUrl,
      );

      final moved = RssSourceImportCommitPlanItem(
        url: 'https://new.example.com/source.json',
        source: _source(
          url: 'https://new.example.com/source.json',
          name: '新地址',
          customOrder: 1,
        ),
        rawJson: LegadoJson.encode(
          _source(
            url: 'https://new.example.com/source.json',
            name: '新地址',
            customOrder: 1,
          ).toJson(),
        ),
        state: RssSourceImportCandidateState.update,
        originalUrl: 'https://old.example.com/source.json',
      );

      final result = await service.commit([moved]);

      expect(result.imported, 1);
      expect(store.rawJsonByUrl('https://old.example.com/source.json'), isNull);
      expect(store.rawJsonByUrl('https://new.example.com/source.json'), isNotNull);
      expect(store.allSources().single.sourceName, '新地址');
    });

    test('排序号超界或重复时自动归一为连续序号', () async {
      final store = _FakeRssSourceStore();
      await store.upsert(
        rawJson: LegadoJson.encode(
          _source(url: 'https://a.example.com/s.json', name: 'A', customOrder: 100100)
              .toJson(),
        ),
      );
      await store.upsert(
        rawJson: LegadoJson.encode(
          _source(url: 'https://b.example.com/s.json', name: 'B', customOrder: 100100)
              .toJson(),
        ),
      );

      final service = RssSourceImportCommitService(
        upsertSourceRawJson: store.upsert,
        loadAllSources: store.allSources,
        loadRawJsonByUrl: store.rawJsonByUrl,
      );
      final incoming = _planItem(
        source: _source(url: 'https://c.example.com/s.json', name: 'C', customOrder: 100200),
        state: RssSourceImportCandidateState.newSource,
      );

      final result = await service.commit([incoming]);

      expect(result.imported, 1);
      final sorted = store.allSources().toList()
        ..sort((a, b) => a.sourceUrl.compareTo(b.sourceUrl));
      expect(
        sorted.map((source) => source.customOrder).toList(),
        [0, 1, 2],
      );
      for (final source in sorted) {
        final raw = store.rawJsonByUrl(source.sourceUrl);
        final decoded = json.decode(raw!) as Map<String, dynamic>;
        expect(decoded['customOrder'], source.customOrder);
      }
    });

    test('空计划不触发 afterCommit', () async {
      final store = _FakeRssSourceStore();
      var afterCommitCount = 0;
      final service = RssSourceImportCommitService(
        upsertSourceRawJson: store.upsert,
        loadAllSources: store.allSources,
        loadRawJsonByUrl: store.rawJsonByUrl,
        afterCommit: () async {
          afterCommitCount++;
        },
      );

      final result = await service.commit(const <RssSourceImportCommitPlanItem>[]);

      expect(result.imported, 0);
      expect(afterCommitCount, 0);
      expect(store.allSources(), isEmpty);
    });
  });
}

RssSource _source({
  required String url,
  required String name,
  required int customOrder,
}) {
  return RssSource(
    sourceUrl: url,
    sourceName: name,
    customOrder: customOrder,
    enabled: true,
  );
}

RssSourceImportCommitPlanItem _planItem({
  required RssSource source,
  required RssSourceImportCandidateState state,
}) {
  return RssSourceImportCommitPlanItem(
    url: source.sourceUrl,
    source: source,
    rawJson: LegadoJson.encode(source.toJson()),
    state: state,
  );
}

class _FakeRssSourceStore {
  final Map<String, String> _rawByUrl = <String, String>{};
  final Map<String, RssSource> _sourceByUrl = <String, RssSource>{};

  Future<void> upsert({
    String? originalUrl,
    required String rawJson,
  }) async {
    final oldUrl = (originalUrl ?? '').trim();
    final decoded = json.decode(rawJson) as Map<String, dynamic>;
    final source = RssSource.fromJson(decoded);
    final url = source.sourceUrl.trim();
    if (oldUrl.isNotEmpty && oldUrl != url) {
      _rawByUrl.remove(oldUrl);
      _sourceByUrl.remove(oldUrl);
    }
    _rawByUrl[url] = rawJson;
    _sourceByUrl[url] = source;
  }

  List<RssSource> allSources() {
    return _sourceByUrl.values.toList(growable: false);
  }

  String? rawJsonByUrl(String url) {
    return _rawByUrl[url];
  }
}
