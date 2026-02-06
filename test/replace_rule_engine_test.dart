import 'package:flutter_test/flutter_test.dart';
import 'package:soupreader/features/replace/models/replace_rule.dart';
import 'package:soupreader/features/replace/services/replace_rule_engine.dart';

void main() {
  group('ReplaceRuleEngine', () {
    test('effectiveRules filters disabled and respects scope/excludeScope', () {
      final engine = ReplaceRuleEngine();
      final rules = <ReplaceRule>[
        const ReplaceRule(
          id: 1,
          isEnabled: false,
          pattern: 'a',
          replacement: 'b',
        ),
        const ReplaceRule(
          id: 2,
          isEnabled: true,
          pattern: 'a',
          replacement: 'b',
          scope: 'BookA',
        ),
        const ReplaceRule(
          id: 3,
          isEnabled: true,
          pattern: 'a',
          replacement: 'b',
          scope: 'BookA',
          excludeScope: 'src://blocked',
        ),
      ];

      final effective = engine.effectiveRules(
        rules,
        bookName: 'BookA',
        sourceName: 'S1',
        sourceUrl: 'src://blocked',
      );

      expect(effective.map((e) => e.id), [2]);
    });

    test('applyToContent applies in given order and respects scopeContent', () async {
      final engine = ReplaceRuleEngine();
      final rules = <ReplaceRule>[
        const ReplaceRule(
          id: 1,
          order: 1,
          isRegex: false,
          scopeContent: true,
          pattern: 'a',
          replacement: 'b',
        ),
        const ReplaceRule(
          id: 2,
          order: 2,
          isRegex: false,
          scopeContent: true,
          pattern: 'b',
          replacement: 'c',
        ),
        const ReplaceRule(
          id: 3,
          order: 3,
          isRegex: false,
          scopeContent: false,
          pattern: 'c',
          replacement: 'd',
        ),
      ];

      final out = await engine.applyToContent('a', rules);
      expect(out, 'c');
    });

    test('applyToTitle only applies scopeTitle rules', () async {
      final engine = ReplaceRuleEngine();
      final rules = <ReplaceRule>[
        const ReplaceRule(
          id: 1,
          isRegex: false,
          scopeTitle: false,
          pattern: 'a',
          replacement: 'b',
        ),
        const ReplaceRule(
          id: 2,
          isRegex: false,
          scopeTitle: true,
          pattern: 'a',
          replacement: 'b',
        ),
      ];

      final out = await engine.applyToTitle('a', rules);
      expect(out, 'b');
    });

    test('regex replacement works', () async {
      final engine = ReplaceRuleEngine();
      final rules = <ReplaceRule>[
        const ReplaceRule(
          id: 1,
          isRegex: true,
          scopeContent: true,
          timeoutMillisecond: 1000,
          pattern: r'(\d+)',
          replacement: '#',
        ),
      ];

      final out = await engine.applyToContent('a1b22c', rules);
      expect(out, 'a#b#c');
    });
  });
}
