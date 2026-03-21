import 'package:flutter/foundation.dart';
import 'package:html/dom.dart';

import '../models/rule_parser_types.dart';

/// CSS 选择器兼容层
///
/// 处理 `:nth-child()` 等伪类的解析与匹配，
/// 提供 `querySelectorAll` 的兼容扩展（支持组合器与 nth 过滤）。
class RuleParserSelectorCompatHelper {
  /// 检查 CSS 选择器中是否包含 `:nth-*` 伪类。
  bool containsNthPseudo(String css) {
    final t = css.toLowerCase();
    return t.contains(':nth-child(') ||
        t.contains(':nth-last-child(') ||
        t.contains(':nth-of-type(') ||
        t.contains(':nth-last-of-type(');
  }

  /// 按顶层逗号拆分选择器组：`a, b > c` => [a, b > c]。
  List<String> splitSelectorGroups(String selector) {
    final out = <String>[];
    final buf = StringBuffer();
    var bracket = 0;
    var paren = 0;
    String? quote;

    void flush() {
      final s = buf.toString().trim();
      buf.clear();
      if (s.isNotEmpty) out.add(s);
    }

    for (var i = 0; i < selector.length; i++) {
      final ch = selector[i];
      if (quote != null) {
        buf.write(ch);
        if (ch == quote) quote = null;
        continue;
      }
      if (ch == '"' || ch == "'") {
        quote = ch;
        buf.write(ch);
        continue;
      }
      if (ch == '[') bracket++;
      if (ch == ']') {
        bracket = bracket > 0 ? (bracket - 1) : 0;
      }
      if (ch == '(') paren++;
      if (ch == ')') paren = paren > 0 ? (paren - 1) : 0;

      if (ch == ',' && bracket == 0 && paren == 0) {
        flush();
        continue;
      }
      buf.write(ch);
    }
    flush();
    return out;
  }

  /// 解析 `nth` 表达式（如 `2n+1`、`odd`、`even`）。
  NthExpr? parseNthExpr(String raw) {
    final t = raw.trim().toLowerCase().replaceAll(' ', '');
    if (t.isEmpty) return null;
    if (t == 'odd') return const NthExpr(a: 2, b: 1);
    if (t == 'even') return const NthExpr(a: 2, b: 0);

    if (!t.contains('n')) {
      final v = int.tryParse(t);
      return v == null ? null : NthExpr(a: 0, b: v);
    }

    final parts = t.split('n');
    final aPart = parts.isNotEmpty ? parts.first : '';
    final bPart = parts.length >= 2 ? parts[1] : '';

    int a;
    if (aPart.isEmpty || aPart == '+') {
      a = 1;
    } else if (aPart == '-') {
      a = -1;
    } else {
      a = int.tryParse(aPart) ?? 0;
    }

    int b = 0;
    if (bPart.isNotEmpty) {
      b = int.tryParse(bPart) ?? 0;
    }

    return NthExpr(a: a, b: b);
  }

  /// 判断 1-based position 是否匹配 nth 表达式 `an+b`。
  bool matchesNth(NthExpr expr, int position1Based) {
    final a = expr.a;
    final b = expr.b;
    final p = position1Based;
    if (p <= 0) return false;

    if (a == 0) return p == b;

    if (a > 0) {
      final diff = p - b;
      if (diff < 0) return false;
      return diff % a == 0;
    } else {
      final diff = b - p;
      if (diff < 0) return false;
      return diff % (-a) == 0;
    }
  }

  /// 将 CSS 选择器拆分为以组合器连接的步骤链。
  List<SelectorStepCompat> tokenizeSelectorChain(
    String selector,
  ) {
    final steps = <SelectorStepCompat>[];
    final buf = StringBuffer();

    var bracket = 0;
    var paren = 0;
    String? quote;

    void pushStep(String combinator) {
      final raw = buf.toString().trim();
      buf.clear();
      if (raw.isEmpty) return;
      final extracted = extractNthFilters(raw);
      steps.add(
        SelectorStepCompat(
          combinator: combinator,
          selector: extracted.baseSelector,
          nthFilters: extracted.filters,
        ),
      );
    }

    String pendingCombinator = '';

    for (var i = 0; i < selector.length; i++) {
      final ch = selector[i];
      if (quote != null) {
        buf.write(ch);
        if (ch == quote) quote = null;
        continue;
      }
      if (ch == '"' || ch == "'") {
        quote = ch;
        buf.write(ch);
        continue;
      }
      if (ch == '[') bracket++;
      if (ch == ']') {
        bracket = bracket > 0 ? (bracket - 1) : 0;
      }
      if (ch == '(') paren++;
      if (ch == ')') paren = paren > 0 ? (paren - 1) : 0;

      final isTopLevel = bracket == 0 && paren == 0;
      if (isTopLevel &&
          (ch == '>' || ch == '+' || ch == '~')) {
        pushStep(pendingCombinator);
        pendingCombinator = ch;
        continue;
      }

      if (isTopLevel && ch.trim().isEmpty) {
        if (buf.isNotEmpty) {
          pushStep(pendingCombinator);
          pendingCombinator = ' ';
        } else {
          pendingCombinator = pendingCombinator.isEmpty
              ? ' '
              : pendingCombinator;
        }
        continue;
      }

      buf.write(ch);
    }
    pushStep(pendingCombinator);

    if (steps.isNotEmpty) {
      final first = steps.first;
      steps[0] = SelectorStepCompat(
        combinator: '',
        selector: first.selector,
        nthFilters: first.nthFilters,
      );
    }
    return steps;
  }

  /// 从原始选择器片段中提取 nth 伪类过滤器。
  NthExtractResult extractNthFilters(String rawSelectorPart) {
    var s = rawSelectorPart;
    final filters = <NthFilter>[];

    final kinds = <String>[
      'nth-child',
      'nth-last-child',
      'nth-of-type',
      'nth-last-of-type',
    ];

    for (final kind in kinds) {
      while (true) {
        final lower = s.toLowerCase();
        final idx = lower.indexOf(':$kind(');
        if (idx < 0) break;

        var start = idx + kind.length + 2;
        var depth = 1;
        var end = -1;
        for (var i = start; i < s.length; i++) {
          final ch = s[i];
          if (ch == '(') depth++;
          if (ch == ')') depth--;
          if (depth == 0) {
            end = i;
            break;
          }
        }
        if (end < 0) break;
        final exprText = s.substring(start, end);
        final expr = parseNthExpr(exprText);
        if (expr != null) {
          filters.add(NthFilter(kind: kind, expr: expr));
        }
        s = (s.substring(0, idx) + s.substring(end + 1)).trim();
      }
    }

    if (s.trim().isEmpty) s = '*';
    return NthExtractResult(
      baseSelector: s.trim(),
      filters: filters,
    );
  }

  /// 兼容版 querySelectorAll，支持逗号分组与 nth 过滤。
  List<Element> querySelectorAllCompat(
    dynamic ctx,
    String selector,
  ) {
    final groups = splitSelectorGroups(selector);
    if (groups.isEmpty) return const <Element>[];

    final out = <Element>[];
    final seen = <Element>{};
    for (final g in groups) {
      final one = querySelectorAllCompatSingle(ctx, g);
      for (final el in one) {
        if (seen.add(el)) out.add(el);
      }
    }
    return out;
  }

  /// 处理单个选择器组的查询。
  List<Element> querySelectorAllCompatSingle(
    dynamic ctx,
    String selector,
  ) {
    final chain = tokenizeSelectorChain(selector);
    if (chain.isEmpty) return const <Element>[];

    List<Element> contexts;
    if (ctx is Document) {
      final root = ctx.documentElement;
      contexts =
          root == null ? const <Element>[] : <Element>[root];
    } else if (ctx is Element) {
      contexts = <Element>[ctx];
    } else {
      return const <Element>[];
    }

    List<Element> queryDescendants(Element root, String css) {
      try {
        return root.querySelectorAll(css);
      } catch (e) {
        debugPrint('选择器解析失败(compat): $css - $e');
        return const <Element>[];
      }
    }

    List<Element> applyNthFilters(
      List<Element> elements,
      List<NthFilter> filters,
    ) {
      if (filters.isEmpty || elements.isEmpty) return elements;
      return elements.where((el) {
        final parent = el.parent;
        if (parent is! Element) return false;
        final siblings = parent.children;
        final idx = siblings.indexOf(el);
        if (idx < 0) return false;

        for (final f in filters) {
          int pos;
          if (f.kind == 'nth-child') {
            pos = idx + 1;
          } else if (f.kind == 'nth-last-child') {
            pos = siblings.length - idx;
          } else if (f.kind == 'nth-of-type' ||
              f.kind == 'nth-last-of-type') {
            final tag = (el.localName ?? '').toLowerCase();
            final sameType = siblings
                .where(
                  (e) =>
                      (e.localName ?? '').toLowerCase() == tag,
                )
                .toList(growable: false);
            final typeIdx = sameType.indexOf(el);
            if (typeIdx < 0) return false;
            pos = f.kind == 'nth-of-type'
                ? (typeIdx + 1)
                : (sameType.length - typeIdx);
          } else {
            continue;
          }

          if (!matchesNth(f.expr, pos)) return false;
        }
        return true;
      }).toList(growable: false);
    }

    for (final step in chain) {
      final combinator =
          step.combinator.isEmpty ? ' ' : step.combinator;
      final css = step.selector.trim();
      if (css.isEmpty) return const <Element>[];

      final matched = <Element>[];
      if (combinator == ' ') {
        for (final c in contexts) {
          matched.addAll(queryDescendants(c, css));
        }
      } else if (combinator == '>') {
        for (final c in contexts) {
          final all = queryDescendants(c, css);
          matched.addAll(all.where((e) => e.parent == c));
        }
      } else if (combinator == '+') {
        for (final c in contexts) {
          final parent = c.parent;
          if (parent is! Element) continue;
          final siblings = parent.children;
          final idx = siblings.indexOf(c);
          if (idx < 0 || idx + 1 >= siblings.length) continue;
          final cand = siblings[idx + 1];
          final allowed =
              queryDescendants(parent, css).toSet();
          if (allowed.contains(cand)) matched.add(cand);
        }
      } else if (combinator == '~') {
        for (final c in contexts) {
          final parent = c.parent;
          if (parent is! Element) continue;
          final siblings = parent.children;
          final idx = siblings.indexOf(c);
          if (idx < 0) continue;
          final allowed =
              queryDescendants(parent, css).toSet();
          for (var i = idx + 1; i < siblings.length; i++) {
            final cand = siblings[i];
            if (allowed.contains(cand)) matched.add(cand);
          }
        }
      } else {
        for (final c in contexts) {
          matched.addAll(queryDescendants(c, css));
        }
      }

      contexts = applyNthFilters(matched, step.nthFilters);
      if (contexts.isEmpty) return const <Element>[];
    }

    return contexts;
  }
}
