import 'package:flutter_test/flutter_test.dart';
import 'package:soupreader/features/source/services/source_rule_lint_service.dart';

void main() {
  group('SourceRuleLintService', () {
    const service = SourceRuleLintService();

    test('reports missing core chains and required rules', () {
      final report = service.lintFromJson({
        'bookSourceName': '测试源',
        'bookSourceUrl': 'https://example.com',
      });

      expect(report.errorCount, greaterThan(0));
      expect(
        report.issues.any(
          (e) =>
              e.field.contains('searchUrl/ruleSearch') &&
              e.level == RuleLintLevel.error,
        ),
        isTrue,
      );
    });

    test('reports replaceRegex odd segment warning', () {
      final report = service.lintFromJson({
        'bookSourceName': '测试源',
        'bookSourceUrl': 'https://example.com',
        'searchUrl': '/search?key={{key}}',
        'ruleSearch': {
          'bookList': '.item',
          'name': '.name@text',
          'bookUrl': '.name@href',
        },
        'ruleContent': {
          'content': '#content@text',
          'replaceRegex': 'a##b##c',
        },
      });

      expect(
        report.issues.any(
          (e) =>
              e.field == 'ruleContent.replaceRegex' &&
              e.level == RuleLintLevel.warning,
        ),
        isTrue,
      );
    });

    test('returns no issues for minimal valid chain', () {
      final report = service.lintFromJson({
        'bookSourceName': '测试源',
        'bookSourceUrl': 'https://example.com',
        'searchUrl': '/search?key={{key}}',
        'ruleSearch': {
          'bookList': '.item',
          'name': '.name@text',
          'bookUrl': '.name@href',
        },
        'ruleBookInfo': {
          'name': 'h1@text',
          'author': '.author@text',
          'tocUrl': '.toc@href',
        },
        'ruleToc': {
          'chapterList': '.chapter',
          'chapterName': '.title@text',
          'chapterUrl': 'a@href',
        },
        'ruleContent': {
          'content': '#content@text',
        },
      });

      expect(report.hasIssues, isFalse);
      expect(report.errorCount, 0);
      expect(report.warningCount, 0);
    });
  });
}
