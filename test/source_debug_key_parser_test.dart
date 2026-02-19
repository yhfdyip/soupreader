import 'package:flutter_test/flutter_test.dart';
import 'package:soupreader/features/source/services/source_debug_key_parser.dart';

void main() {
  group('SourceDebugKeyParser', () {
    const parser = SourceDebugKeyParser();

    test('空 key 返回失败', () {
      final result = parser.parse('   ');
      expect(result.ok, isFalse);
      expect(result.error, '请输入 key');
    });

    test('绝对 URL 识别为详情调试', () {
      final result = parser.parse('https://example.com/book/1');
      expect(result.ok, isTrue);
      expect(result.intent?.type, SourceDebugIntentType.bookInfo);
      expect(result.intent?.runKey, 'https://example.com/book/1');
    });

    test('包含 :: 识别为发现调试', () {
      final result = parser.parse('系统::https://example.com/explore');
      expect(result.ok, isTrue);
      expect(result.intent?.type, SourceDebugIntentType.explore);
      expect(result.intent?.url, 'https://example.com/explore');
      expect(result.intent?.runKey, '系统::https://example.com/explore');
    });

    test('contains(::) 判定优先于 ++ 前缀（对齐 legado）', () {
      final result = parser.parse('++系统::https://example.com/explore');
      expect(result.ok, isTrue);
      expect(result.intent?.type, SourceDebugIntentType.explore);
      expect(result.intent?.url, 'https://example.com/explore');
    });

    test('contains(::) 判定优先于 -- 前缀（对齐 legado）', () {
      final result = parser.parse('--系统::https://example.com/explore');
      expect(result.ok, isTrue);
      expect(result.intent?.type, SourceDebugIntentType.explore);
      expect(result.intent?.url, 'https://example.com/explore');
    });

    test('++ 前缀识别为目录调试', () {
      final result = parser.parse('++https://example.com/toc');
      expect(result.ok, isTrue);
      expect(result.intent?.type, SourceDebugIntentType.toc);
      expect(result.intent?.runKey, '++https://example.com/toc');
    });

    test('-- 前缀识别为正文调试', () {
      final result = parser.parse('--https://example.com/chapter/1');
      expect(result.ok, isTrue);
      expect(result.intent?.type, SourceDebugIntentType.content);
      expect(result.intent?.runKey, '--https://example.com/chapter/1');
    });

    test('普通关键字识别为搜索调试', () {
      final result = parser.parse('我的');
      expect(result.ok, isTrue);
      expect(result.intent?.type, SourceDebugIntentType.search);
      expect(result.intent?.keyword, '我的');
    });
  });
}
