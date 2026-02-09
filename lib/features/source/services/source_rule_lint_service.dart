import '../models/book_source.dart';

enum RuleLintLevel {
  error,
  warning,
  info,
}

class RuleLintIssue {
  final RuleLintLevel level;
  final String field;
  final String message;
  final String? suggestion;

  const RuleLintIssue({
    required this.level,
    required this.field,
    required this.message,
    this.suggestion,
  });
}

class SourceRuleLintReport {
  final List<RuleLintIssue> issues;

  const SourceRuleLintReport({required this.issues});

  int get errorCount =>
      issues.where((e) => e.level == RuleLintLevel.error).length;
  int get warningCount =>
      issues.where((e) => e.level == RuleLintLevel.warning).length;
  int get infoCount =>
      issues.where((e) => e.level == RuleLintLevel.info).length;

  bool get hasIssues => issues.isNotEmpty;
}

class SourceRuleLintService {
  const SourceRuleLintService();

  SourceRuleLintReport lintFromJson(Map<String, dynamic> json) {
    final source = BookSource.fromJson(json);
    final issues = <RuleLintIssue>[];

    void add(
      RuleLintLevel level,
      String field,
      String message, {
      String? suggestion,
    }) {
      issues.add(
        RuleLintIssue(
          level: level,
          field: field,
          message: message,
          suggestion: suggestion,
        ),
      );
    }

    bool hasText(String? text) => text != null && text.trim().isNotEmpty;

    void checkTemplateBalance(String field, String? text) {
      final value = text?.trim() ?? '';
      if (value.isEmpty) return;
      final left = RegExp(r'\{\{').allMatches(value).length;
      final right = RegExp(r'\}\}').allMatches(value).length;
      if (left != right) {
        add(
          RuleLintLevel.warning,
          field,
          '模板占位符可能不平衡（{{ 与 }} 数量不一致）',
          suggestion: '检查是否缺失右大括号或多写了模板起始符。',
        );
      }
    }

    if (!hasText(source.bookSourceName)) {
      add(
        RuleLintLevel.error,
        'bookSourceName',
        '书源名称为空',
        suggestion: '建议填写可识别的名称，便于后续排查。',
      );
    }

    if (!hasText(source.bookSourceUrl)) {
      add(
        RuleLintLevel.error,
        'bookSourceUrl',
        '书源地址为空',
        suggestion: '至少填写站点根地址，用于拼接相对链接。',
      );
    } else {
      final uri = Uri.tryParse(source.bookSourceUrl);
      final valid = uri != null && uri.scheme.isNotEmpty && uri.host.isNotEmpty;
      if (!valid) {
        add(
          RuleLintLevel.warning,
          'bookSourceUrl',
          '书源地址格式可能异常（非标准 http/https 绝对地址）',
          suggestion: '建议改为 https://example.com 形式。',
        );
      }
    }

    final hasSearch = hasText(source.searchUrl) && source.ruleSearch != null;
    final hasExplore = hasText(source.exploreUrl) && source.ruleExplore != null;
    if (!hasSearch && !hasExplore) {
      add(
        RuleLintLevel.error,
        'searchUrl/ruleSearch 或 exploreUrl/ruleExplore',
        '搜索与发现链路都未配置完整，书源无法在列表检索中使用',
        suggestion: '至少补齐一条链路：searchUrl+ruleSearch 或 exploreUrl+ruleExplore。',
      );
    }

    if (hasText(source.searchUrl) && source.ruleSearch == null) {
      add(
        RuleLintLevel.warning,
        'searchUrl',
        '已填写 searchUrl，但 ruleSearch 为空',
        suggestion: '补充 ruleSearch.bookList/name/bookUrl。',
      );
    }
    if (!hasText(source.searchUrl) && source.ruleSearch != null) {
      add(
        RuleLintLevel.warning,
        'ruleSearch',
        '已填写 ruleSearch，但 searchUrl 为空',
        suggestion: '补充 searchUrl，或改为使用发现链路。',
      );
    }

    final search = source.ruleSearch;
    if (search != null) {
      if (!hasText(search.bookList)) {
        add(
          RuleLintLevel.error,
          'ruleSearch.bookList',
          '搜索书籍列表规则为空',
          suggestion: '填写用于定位搜索结果列表的规则。',
        );
      }
      if (!hasText(search.name)) {
        add(
          RuleLintLevel.warning,
          'ruleSearch.name',
          '搜索书名规则为空',
          suggestion: '建议补齐，否则列表展示可能为空白。',
        );
      }
      if (!hasText(search.bookUrl)) {
        add(
          RuleLintLevel.error,
          'ruleSearch.bookUrl',
          '搜索详情链接规则为空',
          suggestion: '必须能拿到详情链接才能进入后续链路。',
        );
      }
      checkTemplateBalance('searchUrl', source.searchUrl);
    }

    if (hasText(source.exploreUrl) && source.ruleExplore == null) {
      add(
        RuleLintLevel.warning,
        'exploreUrl',
        '已填写 exploreUrl，但 ruleExplore 为空',
        suggestion: '补充 ruleExplore.bookList/name/bookUrl。',
      );
    }
    if (!hasText(source.exploreUrl) && source.ruleExplore != null) {
      add(
        RuleLintLevel.warning,
        'ruleExplore',
        '已填写 ruleExplore，但 exploreUrl 为空',
        suggestion: '补充 exploreUrl，或移除发现规则。',
      );
    }

    final explore = source.ruleExplore;
    if (explore != null) {
      if (!hasText(explore.bookList)) {
        add(
          RuleLintLevel.warning,
          'ruleExplore.bookList',
          '发现列表规则为空',
          suggestion: '若依赖发现页，请补齐列表规则。',
        );
      }
      if (!hasText(explore.bookUrl)) {
        add(
          RuleLintLevel.warning,
          'ruleExplore.bookUrl',
          '发现详情链接规则为空',
          suggestion: '建议补齐，避免发现结果无法进入详情。',
        );
      }
      checkTemplateBalance('exploreUrl', source.exploreUrl);
    }

    final toc = source.ruleToc;
    if (toc != null) {
      final hasAny = hasText(toc.chapterList) ||
          hasText(toc.chapterName) ||
          hasText(toc.chapterUrl) ||
          hasText(toc.nextTocUrl) ||
          hasText(toc.preUpdateJs) ||
          hasText(toc.formatJs);
      if (hasAny) {
        if (!hasText(toc.chapterList)) {
          add(
            RuleLintLevel.error,
            'ruleToc.chapterList',
            '目录章节列表规则为空',
            suggestion: '补齐 chapterList，否则无法遍历目录。',
          );
        }
        if (!hasText(toc.chapterName)) {
          add(
            RuleLintLevel.error,
            'ruleToc.chapterName',
            '目录章节名规则为空',
            suggestion: '补齐 chapterName，否则章节标题不可读。',
          );
        }
        if (!hasText(toc.chapterUrl)) {
          add(
            RuleLintLevel.error,
            'ruleToc.chapterUrl',
            '目录章节链接规则为空',
            suggestion: '补齐 chapterUrl，否则无法进入正文。',
          );
        }
      }
      checkTemplateBalance('ruleToc.nextTocUrl', toc.nextTocUrl);
      checkTemplateBalance('ruleToc.preUpdateJs', toc.preUpdateJs);
      checkTemplateBalance('ruleToc.formatJs', toc.formatJs);
    }

    final content = source.ruleContent;
    if (content != null) {
      if (!hasText(content.content)) {
        add(
          RuleLintLevel.error,
          'ruleContent.content',
          '正文提取规则为空',
          suggestion: '补齐 content 规则（如 @text/@html）。',
        );
      }
      if (hasText(content.replaceRegex)) {
        final parts = content.replaceRegex!.split('##');
        if (parts.length % 2 != 0) {
          add(
            RuleLintLevel.warning,
            'ruleContent.replaceRegex',
            'replaceRegex 片段数为奇数，可能存在缺失替换值',
            suggestion: '检查格式是否为 pattern##replacement##...。',
          );
        }
      }
      checkTemplateBalance('ruleContent.content', content.content);
      checkTemplateBalance(
        'ruleContent.nextContentUrl',
        content.nextContentUrl,
      );
    }

    final info = source.ruleBookInfo;
    if (info != null && !hasText(info.tocUrl)) {
      add(
        RuleLintLevel.info,
        'ruleBookInfo.tocUrl',
        '目录链接规则为空，将回退使用详情页地址作为目录页',
        suggestion: '若站点详情页不含目录，建议补齐 tocUrl。',
      );
    }

    return SourceRuleLintReport(issues: issues);
  }
}
