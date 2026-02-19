import 'package:flutter_test/flutter_test.dart';
import 'package:soupreader/features/source/services/source_debug_quick_action_helper.dart';

void main() {
  group('SourceDebugQuickActionHelper', () {
    test('normalizeStartKey 空值默认保持为空，仅在传入 fallback 时回退', () {
      expect(SourceDebugQuickActionHelper.normalizeStartKey(''), '');
      expect(
        SourceDebugQuickActionHelper.normalizeStartKey('   ', fallback: '系统'),
        '系统',
      );
      expect(
        SourceDebugQuickActionHelper.normalizeStartKey('  关键字  '),
        '关键字',
      );
    });

    test('applyPrefix 空或短查询只补前缀且不直接执行', () {
      final empty = SourceDebugQuickActionHelper.applyPrefix(
        query: '',
        prefix: '++',
      );
      expect(empty.nextQuery, '++');
      expect(empty.shouldRun, isFalse);

      final shortValue = SourceDebugQuickActionHelper.applyPrefix(
        query: 'ab',
        prefix: '--',
      );
      expect(shortValue.nextQuery, '--');
      expect(shortValue.shouldRun, isFalse);
    });

    test('applyPrefix 普通查询会补前缀并执行', () {
      final action = SourceDebugQuickActionHelper.applyPrefix(
        query: 'https://example.com/toc',
        prefix: '++',
      );
      expect(action.nextQuery, '++https://example.com/toc');
      expect(action.shouldRun, isTrue);
    });

    test('applyPrefix 已有前缀保持原值并执行', () {
      final action = SourceDebugQuickActionHelper.applyPrefix(
        query: '--https://example.com/chapter/1',
        prefix: '--',
      );
      expect(action.nextQuery, '--https://example.com/chapter/1');
      expect(action.shouldRun, isTrue);
    });

    test('buildExploreRunKey 空标题使用默认值', () {
      expect(
        SourceDebugQuickActionHelper.buildExploreRunKey(
          title: '',
          url: 'https://example.com/explore',
        ),
        '发现::https://example.com/explore',
      );
      expect(
        SourceDebugQuickActionHelper.buildExploreRunKey(
          title: '系统',
          url: 'https://example.com/explore',
        ),
        '系统::https://example.com/explore',
      );
    });
  });
}
