class SourceRuleComplete {
  SourceRuleComplete._();

  static final RegExp _needComplete = RegExp(
    r'(?<!(@|/|^|[|%&]{2})(attr|text|ownText|textNodes|href|content|html|alt|all|value|src)(\(\))?)(\&{2}|%%|\|{2}|$)',
  );

  static final RegExp _notComplete = RegExp(
    r'^:|^##|\{\{|@js:|<js>|@Json:|\$\.',
  );

  static final RegExp _fixImgInfo = RegExp(
    r'(?<=(^|tag\.|[\+/@>~| &]))img((\[@?.+\]|\.[-\w]+)?)[@/]+text(\(\))?(\&{2}|%%|\|{2}|$)',
  );

  static final RegExp _isXpath = RegExp(r'^//|^@Xpath:');

  static String? autoComplete(
    String? rules, {
    String? preRule,
    int type = 1,
  }) {
    if (rules == null || rules.isEmpty) return rules;
    if (_notComplete.hasMatch(rules)) return rules;
    if ((preRule ?? '').isNotEmpty && _notComplete.hasMatch(preRule!)) {
      return rules;
    }

    final splitMatch = RegExp(r'##|,\{').firstMatch(rules);
    final splitIndex = splitMatch?.start ?? -1;
    final splitToken = splitMatch?.group(0) ?? '';
    final cleanedRule = splitIndex < 0 ? rules : rules.substring(0, splitIndex);
    final tail = splitIndex < 0
        ? ''
        : splitToken + rules.substring(splitIndex + splitToken.length);

    final isXpath = _isXpath.hasMatch(cleanedRule);
    final textRule = isXpath ? r'//text()${seq}' : r'@text${seq}';
    final linkRule = isXpath ? r'//@href${seq}' : r'@href${seq}';
    final imgRule = isXpath ? r'//@src${seq}' : r'@src${seq}';
    final imgText = isXpath ? r'img${at}/@alt${seq}' : r'img${at}@alt${seq}';

    String applyRule(String input, String replacement) {
      return input.replaceAllMapped(_needComplete, (match) {
        final seq = match.group(0) ?? '';
        return replacement.replaceAll(r'${seq}', seq);
      });
    }

    String applyImgFix(String input) {
      return input.replaceAllMapped(_fixImgInfo, (match) {
        final full = match.group(0) ?? '';
        final at = RegExp(r'^img((?:\[@?.+\]|\.[-\w]+)?)')
                .firstMatch(full)
                ?.group(1) ??
            '';
        final seq =
            RegExp(r'(\&{2}|%%|\|{2}|$)$').firstMatch(full)?.group(1) ?? '';
        return imgText.replaceAll(r'${seq}', seq).replaceAll(r'${at}', at);
      });
    }

    switch (type) {
      case 1:
        return applyImgFix(applyRule(cleanedRule, textRule)) + tail;
      case 2:
        return applyRule(cleanedRule, linkRule) + tail;
      case 3:
        return applyRule(cleanedRule, imgRule) + tail;
      default:
        return rules;
    }
  }
}
