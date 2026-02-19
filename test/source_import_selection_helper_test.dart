import 'package:flutter_test/flutter_test.dart';
import 'package:soupreader/features/source/models/book_source.dart';
import 'package:soupreader/features/source/services/source_import_export_service.dart';
import 'package:soupreader/features/source/services/source_import_selection_helper.dart';

void main() {
  group('SourceImportSelectionHelper', () {
    test('buildCandidates 标记新增/更新/已有并给出默认勾选', () {
      final incoming = [
        _source(url: 'https://u1', name: '源1', update: 120),
        _source(url: 'https://u2', name: '源2', update: 80),
        _source(url: 'https://u3', name: '源3', update: 10),
      ];
      final result = SourceImportResult(
        success: true,
        sources: incoming,
        sourceRawJsonByUrl: {
          for (final source in incoming) source.bookSourceUrl: '{}',
        },
      );
      final localMap = <String, BookSource>{
        'https://u1': _source(url: 'https://u1', name: '本地1', update: 100),
        'https://u2': _source(url: 'https://u2', name: '本地2', update: 90),
      };

      final candidates = SourceImportSelectionHelper.buildCandidates(
        result: result,
        localMap: localMap,
      );
      final states = {
        for (final item in candidates) item.url: item.state,
      };

      expect(states['https://u1'], SourceImportCandidateState.update);
      expect(states['https://u2'], SourceImportCandidateState.existing);
      expect(states['https://u3'], SourceImportCandidateState.newSource);

      final selected =
          SourceImportSelectionHelper.defaultSelectedUrls(candidates);
      expect(selected, {'https://u1', 'https://u3'});
    });

    test('buildCandidates 重复 URL 采用后出现项', () {
      final first = _source(url: 'https://u1', name: '旧', update: 100);
      final second = _source(url: 'https://u1', name: '新', update: 120);
      final result = SourceImportResult(
        success: true,
        sources: [
          first,
          _source(url: 'https://u2', name: '其他', update: 1),
          second,
        ],
        sourceRawJsonByUrl: const {},
      );

      final candidates = SourceImportSelectionHelper.buildCandidates(
        result: result,
        localMap: const {},
      );
      final u1 = candidates.singleWhere((item) => item.url == 'https://u1');
      expect(u1.incoming.bookSourceName, '新');
      expect(candidates.last.url, 'https://u1');
    });

    test('buildCommitPlan 应用保留字段和自定义分组覆盖', () {
      final existing = _source(
        url: 'https://u1',
        name: '本地名',
        group: '本地组',
        enabled: false,
        enabledExplore: false,
        order: 9,
        update: 100,
      );
      final incoming = _source(
        url: 'https://u1',
        name: '导入名',
        group: '导入组',
        enabled: true,
        enabledExplore: true,
        order: 1,
        update: 120,
      );
      final plan = SourceImportSelectionHelper.buildCommitPlan(
        candidates: [
          SourceImportCandidate(
            incoming: incoming,
            existing: existing,
            rawJson: incoming.toJson().toString(),
            state: SourceImportCandidateState.update,
          ),
        ],
        policy: const SourceImportSelectionPolicy(
          selectedUrls: {'https://u1'},
          keepName: true,
          keepGroup: true,
          keepEnabled: true,
          customGroup: '手动组',
          appendCustomGroup: false,
        ),
      );

      expect(plan.imported, 1);
      expect(plan.newCount, 0);
      expect(plan.updateCount, 1);
      expect(plan.existingCount, 0);
      final source = plan.items.single.source;
      expect(source.bookSourceName, '本地名');
      expect(source.bookSourceGroup, '手动组');
      expect(source.enabled, isFalse);
      expect(source.enabledExplore, isFalse);
      expect(source.customOrder, 9);
    });

    test('buildCommitPlan 追加分组并过滤未勾选条目', () {
      final plan = SourceImportSelectionHelper.buildCommitPlan(
        candidates: [
          SourceImportCandidate(
            incoming: _source(url: 'https://u1', name: 'A', group: '男频'),
            existing: null,
            rawJson: '{}',
            state: SourceImportCandidateState.newSource,
          ),
          SourceImportCandidate(
            incoming: _source(url: 'https://u2', name: 'B', group: '女频'),
            existing: _source(url: 'https://u2', name: 'B本地', group: '完本'),
            rawJson: '{}',
            state: SourceImportCandidateState.existing,
          ),
        ],
        policy: const SourceImportSelectionPolicy(
          selectedUrls: {'https://u1'},
          keepName: true,
          keepGroup: true,
          keepEnabled: true,
          customGroup: '精选',
          appendCustomGroup: true,
        ),
      );

      expect(plan.imported, 1);
      expect(plan.newCount, 1);
      expect(plan.updateCount, 0);
      expect(plan.existingCount, 0);
      final source = plan.items.single.source;
      expect(source.bookSourceGroup, '男频,精选');
    });

    test('buildCommitPlan 在同 URL 候选下按索引勾选生效', () {
      final candidates = [
        SourceImportCandidate(
          incoming: _source(url: 'https://same', name: 'A1', update: 1),
          existing: null,
          rawJson: '{}',
          state: SourceImportCandidateState.newSource,
        ),
        SourceImportCandidate(
          incoming: _source(url: 'https://same', name: 'A2', update: 2),
          existing: null,
          rawJson: '{}',
          state: SourceImportCandidateState.newSource,
        ),
      ];

      final plan = SourceImportSelectionHelper.buildCommitPlan(
        candidates: candidates,
        policy: const SourceImportSelectionPolicy(
          selectedUrls: {'https://same'},
          selectedIndexes: {1},
        ),
      );

      expect(plan.imported, 1);
      expect(plan.items.single.source.bookSourceName, 'A2');
    });

    test('toggleStateSelection 仅切换目标状态条目', () {
      final candidates = [
        SourceImportCandidate(
          incoming: _source(url: 'https://u1', name: 'A'),
          existing: null,
          rawJson: '{}',
          state: SourceImportCandidateState.newSource,
        ),
        SourceImportCandidate(
          incoming: _source(url: 'https://u2', name: 'B'),
          existing: _source(url: 'https://u2', name: 'B本地', update: 1),
          rawJson: '{}',
          state: SourceImportCandidateState.update,
        ),
        SourceImportCandidate(
          incoming: _source(url: 'https://u3', name: 'C'),
          existing: _source(url: 'https://u3', name: 'C本地', update: 9),
          rawJson: '{}',
          state: SourceImportCandidateState.existing,
        ),
      ];
      final selected = <String>{'https://u3'};

      final toggleNew = SourceImportSelectionHelper.toggleStateSelection(
        candidates: candidates,
        selectedUrls: selected,
        state: SourceImportCandidateState.newSource,
      );
      expect(toggleNew, {'https://u1', 'https://u3'});

      final toggleNewAgain = SourceImportSelectionHelper.toggleStateSelection(
        candidates: candidates,
        selectedUrls: toggleNew,
        state: SourceImportCandidateState.newSource,
      );
      expect(toggleNewAgain, {'https://u3'});

      final toggleUpdate = SourceImportSelectionHelper.toggleStateSelection(
        candidates: candidates,
        selectedUrls: toggleNewAgain,
        state: SourceImportCandidateState.update,
      );
      expect(toggleUpdate, {'https://u2', 'https://u3'});
    });

    test('toggleAllSelection 在全选与全不选之间切换', () {
      final candidates = [
        SourceImportCandidate(
          incoming: _source(url: 'https://u1', name: 'A'),
          existing: null,
          rawJson: '{}',
          state: SourceImportCandidateState.newSource,
        ),
        SourceImportCandidate(
          incoming: _source(url: 'https://u2', name: 'B'),
          existing: null,
          rawJson: '{}',
          state: SourceImportCandidateState.newSource,
        ),
      ];
      final first = SourceImportSelectionHelper.toggleAllSelection(
        candidates: candidates,
        selectedUrls: const <String>{},
      );
      expect(first, {'https://u1', 'https://u2'});
      final second = SourceImportSelectionHelper.toggleAllSelection(
        candidates: candidates,
        selectedUrls: first,
      );
      expect(second, isEmpty);
    });

    test('tryReplaceCandidateRawJson 可回写编辑结果并允许更新 URL', () {
      final candidate = SourceImportCandidate(
        incoming: _source(url: 'https://u1', name: '旧名', group: '旧组'),
        existing: null,
        rawJson: '{"bookSourceUrl":"https://u1","bookSourceName":"旧名"}',
        state: SourceImportCandidateState.newSource,
      );

      final updated = SourceImportSelectionHelper.tryReplaceCandidateRawJson(
        candidate: candidate,
        rawJson:
            '{"bookSourceUrl":"https://changed","bookSourceName":"新名","bookSourceGroup":"新组"}',
      );

      expect(updated, isNotNull);
      expect(updated!.url, 'https://changed');
      expect(updated.incoming.bookSourceUrl, 'https://changed');
      expect(updated.incoming.bookSourceName, '新名');
      expect(updated.incoming.bookSourceGroup, '新组');
      expect(updated.rawJson, contains('"bookSourceName":"新名"'));
      expect(updated.rawJson, contains('"bookSourceUrl":"https://changed"'));
    });

    test('tryReplaceCandidateRawJson 空 URL 时回退原候选 URL', () {
      final candidate = SourceImportCandidate(
        incoming: _source(url: 'https://u1', name: '旧名'),
        existing: null,
        rawJson: '{"bookSourceUrl":"https://u1","bookSourceName":"旧名"}',
        state: SourceImportCandidateState.newSource,
      );

      final updated = SourceImportSelectionHelper.tryReplaceCandidateRawJson(
        candidate: candidate,
        rawJson: '{"bookSourceUrl":"","bookSourceName":"新名"}',
      );

      expect(updated, isNotNull);
      expect(updated!.url, 'https://u1');
      expect(updated.incoming.bookSourceUrl, 'https://u1');
      expect(updated.rawJson, contains('"bookSourceUrl":"https://u1"'));
    });

    test('tryReplaceCandidateRawJson 遇到非法 JSON 返回 null', () {
      final candidate = SourceImportCandidate(
        incoming: _source(url: 'https://u1', name: '旧名'),
        existing: null,
        rawJson: '{"bookSourceUrl":"https://u1","bookSourceName":"旧名"}',
        state: SourceImportCandidateState.newSource,
      );

      final updated = SourceImportSelectionHelper.tryReplaceCandidateRawJson(
        candidate: candidate,
        rawJson: '{invalid json',
      );

      expect(updated, isNull);
    });
  });
}

BookSource _source({
  required String url,
  required String name,
  String? group,
  bool enabled = true,
  bool enabledExplore = true,
  int order = 0,
  int update = 0,
}) {
  return BookSource(
    bookSourceUrl: url,
    bookSourceName: name,
    bookSourceGroup: group,
    enabled: enabled,
    enabledExplore: enabledExplore,
    customOrder: order,
    lastUpdateTime: update,
  );
}
