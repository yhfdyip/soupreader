import 'package:flutter_test/flutter_test.dart';
import 'package:soupreader/features/source/models/book_source.dart';
import 'package:soupreader/features/source/services/source_legacy_save_service.dart';

void main() {
  group('SourceLegacySaveService', () {
    test('内容变更时刷新 lastUpdateTime 并按原 URL 保存', () async {
      String? savedOriginalUrl;
      String? savedRawJson;
      BookSource? clearedExploreSource;

      final service = SourceLegacySaveService(
        upsertSourceRawJson: ({String? originalUrl, required String rawJson}) {
          savedOriginalUrl = originalUrl;
          savedRawJson = rawJson;
          return Future.value();
        },
        clearExploreKindsCache: (source) {
          clearedExploreSource = source;
          return Future.value();
        },
        nowMillis: () => 123456,
      );

      const oldSource = BookSource(
        bookSourceUrl: 'https://old.example.com',
        bookSourceName: '源A',
        exploreUrl: 'https://old.example.com/explore',
        lastUpdateTime: 10,
      );

      const edited = BookSource(
        bookSourceUrl: 'https://new.example.com',
        bookSourceName: '源A-新',
        exploreUrl: 'https://new.example.com/explore',
        lastUpdateTime: 10,
      );

      final saved = await service.save(source: edited, originalSource: oldSource);

      expect(saved.lastUpdateTime, 123456);
      expect(savedOriginalUrl, 'https://old.example.com');
      expect(savedRawJson, isNotNull);
      expect(clearedExploreSource?.bookSourceUrl, 'https://old.example.com');
    });

    test('内容不变时保留旧 lastUpdateTime', () async {
      int clearExploreCount = 0;

      final service = SourceLegacySaveService(
        upsertSourceRawJson: ({String? originalUrl, required String rawJson}) {
          return Future.value();
        },
        clearExploreKindsCache: (_) {
          clearExploreCount++;
          return Future.value();
        },
        nowMillis: () => 999999,
      );

      const source = BookSource(
        bookSourceUrl: 'https://same.example.com',
        bookSourceName: '同源',
        lastUpdateTime: 88,
      );

      final saved = await service.save(source: source, originalSource: source);

      expect(saved.lastUpdateTime, 88);
      expect(clearExploreCount, 0);
    });

    test('jsLib 变更时触发 scope 清理回调', () async {
      String? clearedJsLib;

      final service = SourceLegacySaveService(
        upsertSourceRawJson: ({String? originalUrl, required String rawJson}) {
          return Future.value();
        },
        clearExploreKindsCache: (_) => Future.value(),
        clearJsLibScope: (jsLib) => clearedJsLib = jsLib,
      );

      const oldSource = BookSource(
        bookSourceUrl: 'https://example.com',
        bookSourceName: 'A',
        jsLib: 'function a(){}',
      );
      const newSource = BookSource(
        bookSourceUrl: 'https://example.com',
        bookSourceName: 'A',
        jsLib: 'function b(){}',
      );

      await service.save(source: newSource, originalSource: oldSource);

      expect(clearedJsLib, 'function a(){}');
    });

    test('URL 变更时清理旧源变量', () async {
      String? removedVariableUrl;

      final service = SourceLegacySaveService(
        upsertSourceRawJson: ({String? originalUrl, required String rawJson}) {
          return Future.value();
        },
        clearExploreKindsCache: (_) => Future.value(),
        removeSourceVariable: (sourceUrl) {
          removedVariableUrl = sourceUrl;
          return Future.value();
        },
      );

      const oldSource = BookSource(
        bookSourceUrl: 'https://old.example.com',
        bookSourceName: '旧源',
      );
      const newSource = BookSource(
        bookSourceUrl: 'https://new.example.com',
        bookSourceName: '新源',
      );

      await service.save(source: newSource, originalSource: oldSource);
      expect(removedVariableUrl, 'https://old.example.com');
    });

    test('name/url 为空时抛出异常', () async {
      final service = SourceLegacySaveService(
        upsertSourceRawJson: ({String? originalUrl, required String rawJson}) {
          return Future.value();
        },
        clearExploreKindsCache: (_) => Future.value(),
      );

      const invalid = BookSource(bookSourceUrl: '', bookSourceName: '');

      expect(
        () => service.save(source: invalid, originalSource: null),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
