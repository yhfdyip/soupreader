import 'package:flutter_test/flutter_test.dart';
import 'package:soupreader/features/source/services/source_cookie_scope_resolver.dart';

void main() {
  group('SourceCookieScopeResolver', () {
    test('空字符串返回空候选列表', () {
      expect(SourceCookieScopeResolver.resolveCandidates('  '), isEmpty);
    });

    test('标准 URL 返回原始 URL 与根域 URL', () {
      final uris = SourceCookieScopeResolver.resolveCandidates(
        'https://example.com/book/1',
      );
      expect(
        uris.map((e) => e.toString()).toList(growable: false),
        <String>[
          'https://example.com/book/1',
          'https://example.com',
        ],
      );
    });

    test('逗号后缀 URL 会补充去后缀候选', () {
      final uris = SourceCookieScopeResolver.resolveCandidates(
        'https://example.com,{{key}}',
      );
      expect(
        uris.map((e) => e.toString()).toList(growable: false),
        <String>[
          'https://example.com',
        ],
      );
    });

    test('非 http/https URL 被忽略', () {
      expect(
        SourceCookieScopeResolver.resolveCandidates('javascript:alert(1)'),
        isEmpty,
      );
      expect(
        SourceCookieScopeResolver.resolveCandidates('file:///tmp/a.txt'),
        isEmpty,
      );
    });

    test('域范围候选包含原 host 根地址与主域根地址', () {
      final uris = SourceCookieScopeResolver.resolveDomainCandidates(
        'https://sub.a.example.co.uk/path?from=1',
      );
      expect(
        uris.map((e) => e.toString()).toList(growable: false),
        <String>[
          'https://sub.a.example.co.uk',
          'https://example.co.uk',
        ],
      );
    });

    test('域范围候选可处理逗号后缀 URL', () {
      final uris = SourceCookieScopeResolver.resolveDomainCandidates(
        'https://example.com,{{key}}',
      );
      expect(
        uris.map((e) => e.toString()).toList(growable: false),
        <String>[
          'https://example.com',
        ],
      );
    });

    test('清 Cookie 候选同时包含 URL 作用域与主域作用域', () {
      final uris = SourceCookieScopeResolver.resolveClearCandidates(
        'https://sub.a.example.co.uk/path?from=1',
      );
      expect(
        uris.map((e) => e.toString()).toList(growable: false),
        <String>[
          'https://sub.a.example.co.uk/path?from=1',
          'https://sub.a.example.co.uk',
          'https://example.co.uk',
        ],
      );
    });

    test('清 Cookie 候选会去重并过滤无效链接', () {
      final uris = SourceCookieScopeResolver.resolveClearCandidates(
        'javascript:alert(1)',
      );
      expect(uris, isEmpty);

      final dedup = SourceCookieScopeResolver.resolveClearCandidates(
        'https://example.com,{{key}}',
      );
      expect(
        dedup.map((e) => e.toString()).toList(growable: false),
        <String>[
          'https://example.com',
        ],
      );
    });
  });
}
