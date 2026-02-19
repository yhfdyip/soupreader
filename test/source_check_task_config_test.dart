import 'package:flutter_test/flutter_test.dart';
import 'package:soupreader/features/source/services/source_availability_check_task_service.dart';

void main() {
  group('SourceCheckTaskConfig', () {
    test('语义比较包含超时与校验开关', () {
      const base = SourceCheckTaskConfig(
        includeDisabled: true,
        sourceUrls: ['a', 'b'],
        keywordOverride: '我的',
        timeoutMs: 180000,
        checkSearch: true,
        checkDiscovery: false,
        checkInfo: true,
        checkCategory: true,
        checkContent: false,
      );
      const same = SourceCheckTaskConfig(
        includeDisabled: true,
        sourceUrls: ['b', 'a'],
        keywordOverride: '我的',
        timeoutMs: 180000,
        checkSearch: true,
        checkDiscovery: false,
        checkInfo: true,
        checkCategory: true,
        checkContent: false,
      );
      const differentTimeout = SourceCheckTaskConfig(
        includeDisabled: true,
        sourceUrls: ['a', 'b'],
        keywordOverride: '我的',
        timeoutMs: 200000,
        checkSearch: true,
        checkDiscovery: false,
        checkInfo: true,
        checkCategory: true,
        checkContent: false,
      );
      const differentSwitch = SourceCheckTaskConfig(
        includeDisabled: true,
        sourceUrls: ['a', 'b'],
        keywordOverride: '我的',
        timeoutMs: 180000,
        checkSearch: false,
        checkDiscovery: false,
        checkInfo: true,
        checkCategory: true,
        checkContent: false,
      );
      const differentInfoSwitch = SourceCheckTaskConfig(
        includeDisabled: true,
        sourceUrls: ['a', 'b'],
        keywordOverride: '我的',
        timeoutMs: 180000,
        checkSearch: true,
        checkDiscovery: false,
        checkInfo: false,
        checkCategory: false,
        checkContent: false,
      );

      expect(base.semanticallyEquals(same), isTrue);
      expect(base.semanticallyEquals(differentTimeout), isFalse);
      expect(base.semanticallyEquals(differentSwitch), isFalse);
      expect(base.semanticallyEquals(differentInfoSwitch), isFalse);
    });

    test('超时归一在无效值时回退默认', () {
      const config = SourceCheckTaskConfig(
        includeDisabled: false,
        timeoutMs: 0,
      );
      expect(config.normalizedTimeoutMs(), 180000);
    });
  });
}
