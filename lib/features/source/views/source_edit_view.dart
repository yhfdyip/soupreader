import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show SelectableText;
import 'package:flutter/services.dart';

import '../../../core/database/database_service.dart';
import '../../../core/database/entities/book_entity.dart';
import '../../../core/database/repositories/source_repository.dart';
import '../../../core/utils/legado_json.dart';
import '../models/book_source.dart';
import '../services/rule_parser_engine.dart';
import '../services/source_debug_export_service.dart';
import '../services/source_rule_lint_service.dart';
import 'source_debug_text_view.dart';
import 'source_web_verify_view.dart';

class SourceEditView extends StatefulWidget {
  final String? originalUrl;
  final String initialRawJson;
  final int? initialTab;
  final String? initialDebugKey;

  const SourceEditView({
    super.key,
    required this.initialRawJson,
    this.originalUrl,
    this.initialTab,
    this.initialDebugKey,
  });

  static SourceEditView fromEntity(
    BookSourceEntity entity, {
    int? initialTab,
    String? initialDebugKey,
  }) {
    final raw = (entity.rawJson != null && entity.rawJson!.trim().isNotEmpty)
        ? entity.rawJson!
        : LegadoJson.encode({
            'bookSourceUrl': entity.bookSourceUrl,
            'bookSourceName': entity.bookSourceName,
            'bookSourceGroup': entity.bookSourceGroup,
            'bookSourceType': entity.bookSourceType,
            'customOrder': 0,
            'enabled': entity.enabled,
            'enabledExplore': true,
            'enabledCookieJar': true,
            'respondTime': 180000,
            'weight': entity.weight,
            'header': entity.header,
            'loginUrl': entity.loginUrl,
          });
    return SourceEditView(
      originalUrl: entity.bookSourceUrl,
      initialRawJson: raw,
      initialTab: initialTab,
      initialDebugKey: initialDebugKey,
    );
  }

  @override
  State<SourceEditView> createState() => _SourceEditViewState();
}

class _SourceEditViewState extends State<SourceEditView> {
  late final DatabaseService _db;
  late final SourceRepository _repo;
  final RuleParserEngine _engine = RuleParserEngine();
  final SourceDebugExportService _debugExportService =
      SourceDebugExportService();
  final SourceRuleLintService _ruleLintService = const SourceRuleLintService();

  int _tab = 0; // 0 基础 1 规则 2 JSON 3 调试

  late final TextEditingController _nameCtrl;
  late final TextEditingController _urlCtrl;
  late final TextEditingController _groupCtrl;
  late final TextEditingController _typeCtrl;
  late final TextEditingController _customOrderCtrl;
  late final TextEditingController _weightCtrl;
  late final TextEditingController _respondTimeCtrl;
  bool _enabledCookieJar = true;
  late final TextEditingController _concurrentRateCtrl;
  late final TextEditingController _bookUrlPatternCtrl;
  late final TextEditingController _jsLibCtrl;
  late final TextEditingController _headerCtrl;
  late final TextEditingController _loginUrlCtrl;
  late final TextEditingController _loginUiCtrl;
  late final TextEditingController _loginCheckJsCtrl;
  late final TextEditingController _coverDecodeJsCtrl;
  late final TextEditingController _bookSourceCommentCtrl;
  late final TextEditingController _variableCommentCtrl;
  late final TextEditingController _searchUrlCtrl;
  late final TextEditingController _exploreUrlCtrl;
  late final TextEditingController _exploreScreenCtrl;

  // 规则（常用字段）
  late final TextEditingController _searchCheckKeyWordCtrl;
  late final TextEditingController _searchBookListCtrl;
  late final TextEditingController _searchNameCtrl;
  late final TextEditingController _searchAuthorCtrl;
  late final TextEditingController _searchBookUrlCtrl;
  late final TextEditingController _searchCoverUrlCtrl;
  late final TextEditingController _searchIntroCtrl;
  late final TextEditingController _searchKindCtrl;
  late final TextEditingController _searchLastChapterCtrl;
  late final TextEditingController _searchUpdateTimeCtrl;
  late final TextEditingController _searchWordCountCtrl;

  late final TextEditingController _exploreBookListCtrl;
  late final TextEditingController _exploreNameCtrl;
  late final TextEditingController _exploreAuthorCtrl;
  late final TextEditingController _exploreBookUrlCtrl;
  late final TextEditingController _exploreCoverUrlCtrl;
  late final TextEditingController _exploreIntroCtrl;
  late final TextEditingController _exploreKindCtrl;
  late final TextEditingController _exploreLastChapterCtrl;
  late final TextEditingController _exploreUpdateTimeCtrl;
  late final TextEditingController _exploreWordCountCtrl;

  late final TextEditingController _infoInitCtrl;
  late final TextEditingController _infoNameCtrl;
  late final TextEditingController _infoAuthorCtrl;
  late final TextEditingController _infoIntroCtrl;
  late final TextEditingController _infoCoverUrlCtrl;
  late final TextEditingController _infoTocUrlCtrl;
  late final TextEditingController _infoKindCtrl;
  late final TextEditingController _infoLastChapterCtrl;
  late final TextEditingController _infoUpdateTimeCtrl;
  late final TextEditingController _infoWordCountCtrl;

  late final TextEditingController _tocChapterListCtrl;
  late final TextEditingController _tocChapterNameCtrl;
  late final TextEditingController _tocChapterUrlCtrl;
  late final TextEditingController _tocNextTocUrlCtrl;
  late final TextEditingController _tocPreUpdateJsCtrl;
  late final TextEditingController _tocFormatJsCtrl;

  late final TextEditingController _contentContentCtrl;
  late final TextEditingController _contentTitleCtrl;
  late final TextEditingController _contentReplaceRegexCtrl;
  late final TextEditingController _contentNextContentUrlCtrl;

  late final TextEditingController _jsonCtrl;
  String? _jsonError;

  bool _enabled = true;
  bool _enabledExplore = true;

  // 调试
  final TextEditingController _debugKeyCtrl = TextEditingController();
  bool _debugLoading = false;
  String? _debugError;
  final List<_DebugLine> _debugLines = <_DebugLine>[];
  final List<_DebugLine> _debugLinesAll = <_DebugLine>[];
  int _debugConsoleMode = 1; // 0 分段 1 文本 2 逐行
  bool _debugShowAllLines = true; // 全量展示（可能卡顿）
  bool _debugWrapLines = true; // 逐行模式自动换行
  String _debugFilter = ''; // 控制台过滤关键字（大小写不敏感）
  final Set<int> _expandedDebugBlocks = <int>{};
  String? _debugListSrcHtml; // state=10（搜索/发现列表页）
  String? _debugBookSrcHtml; // state=20（详情页）
  String? _debugTocSrcHtml; // state=30（目录页）
  String? _debugContentSrcHtml; // state=40（正文页）
  String? _debugContentResult; // 清理后的正文结果（便于直接看）
  String? _debugMethodDecision;
  String? _debugRetryDecision;
  String? _debugRequestCharsetDecision;
  String? _debugBodyDecision;
  String? _debugResponseCharset;
  String? _debugResponseCharsetDecision;
  Map<String, String> _debugRuntimeVarsSnapshot = <String, String>{};
  String? _previewChapterName;
  String? _previewChapterUrl;
  bool _awaitingChapterNameValue = false;
  bool _awaitingChapterUrlValue = false;

  @override
  void initState() {
    super.initState();
    _db = DatabaseService();
    _repo = SourceRepository(_db);

    _tab = widget.initialTab ?? 0;
    _jsonCtrl = TextEditingController(text: _prettyJson(widget.initialRawJson));
    final initialMap = _tryDecodeJsonMap(_jsonCtrl.text);
    final source = initialMap != null ? BookSource.fromJson(initialMap) : null;

    _nameCtrl = TextEditingController(text: source?.bookSourceName ?? '');
    _urlCtrl = TextEditingController(text: source?.bookSourceUrl ?? '');
    _groupCtrl = TextEditingController(text: source?.bookSourceGroup ?? '');
    _typeCtrl = TextEditingController(
      text: (source?.bookSourceType ?? 0).toString(),
    );
    _customOrderCtrl = TextEditingController(
      text: (source?.customOrder ?? 0).toString(),
    );
    _weightCtrl = TextEditingController(text: (source?.weight ?? 0).toString());
    _respondTimeCtrl = TextEditingController(
      text: (source?.respondTime ?? 180000).toString(),
    );
    _enabledCookieJar = source?.enabledCookieJar ?? true;
    _concurrentRateCtrl =
        TextEditingController(text: source?.concurrentRate ?? '');
    _bookUrlPatternCtrl =
        TextEditingController(text: source?.bookUrlPattern ?? '');
    _jsLibCtrl = TextEditingController(text: source?.jsLib ?? '');
    _headerCtrl = TextEditingController(text: source?.header ?? '');
    _loginUrlCtrl = TextEditingController(text: source?.loginUrl ?? '');
    _loginUiCtrl = TextEditingController(text: source?.loginUi ?? '');
    _loginCheckJsCtrl = TextEditingController(text: source?.loginCheckJs ?? '');
    _coverDecodeJsCtrl =
        TextEditingController(text: source?.coverDecodeJs ?? '');
    _bookSourceCommentCtrl =
        TextEditingController(text: source?.bookSourceComment ?? '');
    _variableCommentCtrl =
        TextEditingController(text: source?.variableComment ?? '');
    _searchUrlCtrl = TextEditingController(text: source?.searchUrl ?? '');
    _exploreUrlCtrl = TextEditingController(text: source?.exploreUrl ?? '');
    _exploreScreenCtrl =
        TextEditingController(text: source?.exploreScreen ?? '');
    _enabled = source?.enabled ?? true;
    _enabledExplore = source?.enabledExplore ?? true;

    _debugKeyCtrl.text = widget.initialDebugKey ?? '';

    _searchCheckKeyWordCtrl =
        TextEditingController(text: source?.ruleSearch?.checkKeyWord ?? '');
    _searchBookListCtrl =
        TextEditingController(text: source?.ruleSearch?.bookList ?? '');
    _searchNameCtrl =
        TextEditingController(text: source?.ruleSearch?.name ?? '');
    _searchAuthorCtrl =
        TextEditingController(text: source?.ruleSearch?.author ?? '');
    _searchBookUrlCtrl =
        TextEditingController(text: source?.ruleSearch?.bookUrl ?? '');
    _searchCoverUrlCtrl =
        TextEditingController(text: source?.ruleSearch?.coverUrl ?? '');
    _searchIntroCtrl =
        TextEditingController(text: source?.ruleSearch?.intro ?? '');
    _searchKindCtrl =
        TextEditingController(text: source?.ruleSearch?.kind ?? '');
    _searchLastChapterCtrl =
        TextEditingController(text: source?.ruleSearch?.lastChapter ?? '');
    _searchUpdateTimeCtrl =
        TextEditingController(text: source?.ruleSearch?.updateTime ?? '');
    _searchWordCountCtrl =
        TextEditingController(text: source?.ruleSearch?.wordCount ?? '');

    _exploreBookListCtrl =
        TextEditingController(text: source?.ruleExplore?.bookList ?? '');
    _exploreNameCtrl =
        TextEditingController(text: source?.ruleExplore?.name ?? '');
    _exploreAuthorCtrl =
        TextEditingController(text: source?.ruleExplore?.author ?? '');
    _exploreBookUrlCtrl =
        TextEditingController(text: source?.ruleExplore?.bookUrl ?? '');
    _exploreCoverUrlCtrl =
        TextEditingController(text: source?.ruleExplore?.coverUrl ?? '');
    _exploreIntroCtrl =
        TextEditingController(text: source?.ruleExplore?.intro ?? '');
    _exploreKindCtrl =
        TextEditingController(text: source?.ruleExplore?.kind ?? '');
    _exploreLastChapterCtrl =
        TextEditingController(text: source?.ruleExplore?.lastChapter ?? '');
    _exploreUpdateTimeCtrl =
        TextEditingController(text: source?.ruleExplore?.updateTime ?? '');
    _exploreWordCountCtrl =
        TextEditingController(text: source?.ruleExplore?.wordCount ?? '');

    _infoInitCtrl =
        TextEditingController(text: source?.ruleBookInfo?.init ?? '');
    _infoNameCtrl =
        TextEditingController(text: source?.ruleBookInfo?.name ?? '');
    _infoAuthorCtrl =
        TextEditingController(text: source?.ruleBookInfo?.author ?? '');
    _infoIntroCtrl =
        TextEditingController(text: source?.ruleBookInfo?.intro ?? '');
    _infoCoverUrlCtrl =
        TextEditingController(text: source?.ruleBookInfo?.coverUrl ?? '');
    _infoTocUrlCtrl =
        TextEditingController(text: source?.ruleBookInfo?.tocUrl ?? '');
    _infoKindCtrl =
        TextEditingController(text: source?.ruleBookInfo?.kind ?? '');
    _infoLastChapterCtrl =
        TextEditingController(text: source?.ruleBookInfo?.lastChapter ?? '');
    _infoUpdateTimeCtrl =
        TextEditingController(text: source?.ruleBookInfo?.updateTime ?? '');
    _infoWordCountCtrl =
        TextEditingController(text: source?.ruleBookInfo?.wordCount ?? '');

    _tocChapterListCtrl =
        TextEditingController(text: source?.ruleToc?.chapterList ?? '');
    _tocChapterNameCtrl =
        TextEditingController(text: source?.ruleToc?.chapterName ?? '');
    _tocChapterUrlCtrl =
        TextEditingController(text: source?.ruleToc?.chapterUrl ?? '');
    _tocNextTocUrlCtrl =
        TextEditingController(text: source?.ruleToc?.nextTocUrl ?? '');
    _tocPreUpdateJsCtrl =
        TextEditingController(text: source?.ruleToc?.preUpdateJs ?? '');
    _tocFormatJsCtrl =
        TextEditingController(text: source?.ruleToc?.formatJs ?? '');

    _contentContentCtrl =
        TextEditingController(text: source?.ruleContent?.content ?? '');
    _contentTitleCtrl =
        TextEditingController(text: source?.ruleContent?.title ?? '');
    _contentReplaceRegexCtrl =
        TextEditingController(text: source?.ruleContent?.replaceRegex ?? '');
    _contentNextContentUrlCtrl =
        TextEditingController(text: source?.ruleContent?.nextContentUrl ?? '');

    _validateJson(silent: true);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _urlCtrl.dispose();
    _groupCtrl.dispose();
    _typeCtrl.dispose();
    _customOrderCtrl.dispose();
    _weightCtrl.dispose();
    _respondTimeCtrl.dispose();
    _concurrentRateCtrl.dispose();
    _bookUrlPatternCtrl.dispose();
    _jsLibCtrl.dispose();
    _headerCtrl.dispose();
    _loginUrlCtrl.dispose();
    _loginUiCtrl.dispose();
    _loginCheckJsCtrl.dispose();
    _coverDecodeJsCtrl.dispose();
    _bookSourceCommentCtrl.dispose();
    _variableCommentCtrl.dispose();
    _searchUrlCtrl.dispose();
    _exploreUrlCtrl.dispose();
    _exploreScreenCtrl.dispose();
    _searchCheckKeyWordCtrl.dispose();
    _searchBookListCtrl.dispose();
    _searchNameCtrl.dispose();
    _searchAuthorCtrl.dispose();
    _searchBookUrlCtrl.dispose();
    _searchCoverUrlCtrl.dispose();
    _searchIntroCtrl.dispose();
    _searchKindCtrl.dispose();
    _searchLastChapterCtrl.dispose();
    _searchUpdateTimeCtrl.dispose();
    _searchWordCountCtrl.dispose();
    _exploreBookListCtrl.dispose();
    _exploreNameCtrl.dispose();
    _exploreAuthorCtrl.dispose();
    _exploreBookUrlCtrl.dispose();
    _exploreCoverUrlCtrl.dispose();
    _exploreIntroCtrl.dispose();
    _exploreKindCtrl.dispose();
    _exploreLastChapterCtrl.dispose();
    _exploreUpdateTimeCtrl.dispose();
    _exploreWordCountCtrl.dispose();
    _infoInitCtrl.dispose();
    _infoNameCtrl.dispose();
    _infoAuthorCtrl.dispose();
    _infoIntroCtrl.dispose();
    _infoCoverUrlCtrl.dispose();
    _infoTocUrlCtrl.dispose();
    _infoKindCtrl.dispose();
    _infoLastChapterCtrl.dispose();
    _infoUpdateTimeCtrl.dispose();
    _infoWordCountCtrl.dispose();
    _tocChapterListCtrl.dispose();
    _tocChapterNameCtrl.dispose();
    _tocChapterUrlCtrl.dispose();
    _tocNextTocUrlCtrl.dispose();
    _tocPreUpdateJsCtrl.dispose();
    _tocFormatJsCtrl.dispose();
    _contentContentCtrl.dispose();
    _contentTitleCtrl.dispose();
    _contentReplaceRegexCtrl.dispose();
    _contentNextContentUrlCtrl.dispose();
    _jsonCtrl.dispose();
    _debugKeyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tabControl = CupertinoSlidingSegmentedControl<int>(
      groupValue: _tab,
      children: const {
        0: Padding(
            padding: EdgeInsets.symmetric(horizontal: 8), child: Text('基础')),
        1: Padding(
            padding: EdgeInsets.symmetric(horizontal: 8), child: Text('规则')),
        2: Padding(
            padding: EdgeInsets.symmetric(horizontal: 8), child: Text('JSON')),
        3: Padding(
            padding: EdgeInsets.symmetric(horizontal: 8), child: Text('调试')),
      },
      onValueChanged: (v) {
        if (v == null) return;
        setState(() => _tab = v);
      },
    );

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('书源编辑'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: _save,
              child: const Text('保存'),
            ),
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: _showMore,
              child: const Icon(CupertinoIcons.ellipsis),
            ),
          ],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: tabControl,
            ),
            Expanded(
              child: IndexedStack(
                index: _tab,
                children: [
                  _buildBasicTab(),
                  _buildRulesTab(),
                  _buildJsonTab(),
                  _buildDebugTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRulesTab() {
    return ListView(
      children: [
        CupertinoListSection.insetGrouped(
          header: const Text('搜索规则（ruleSearch）'),
          footer: const Text(
            '常用规则为 CSS 选择器，可用 “selector@href/@src/@text/@html” 等形式取值。',
          ),
          children: [
            _buildTextFieldTile('校验关键词', _searchCheckKeyWordCtrl,
                placeholder: 'ruleSearch.checkKeyWord（用于可用性检测）'),
            _buildTextFieldTile('书籍列表', _searchBookListCtrl,
                placeholder: 'ruleSearch.bookList（CSS 选择器）'),
            _buildTextFieldTile('书名', _searchNameCtrl,
                placeholder: 'ruleSearch.name'),
            _buildTextFieldTile('作者', _searchAuthorCtrl,
                placeholder: 'ruleSearch.author'),
            _buildTextFieldTile('分类/类型', _searchKindCtrl,
                placeholder: 'ruleSearch.kind（可选）'),
            _buildTextFieldTile('封面', _searchCoverUrlCtrl,
                placeholder: 'ruleSearch.coverUrl（@src）'),
            _buildTextFieldTile('简介', _searchIntroCtrl,
                placeholder: 'ruleSearch.intro'),
            _buildTextFieldTile('最新章节', _searchLastChapterCtrl,
                placeholder: 'ruleSearch.lastChapter'),
            _buildTextFieldTile('更新时间', _searchUpdateTimeCtrl,
                placeholder: 'ruleSearch.updateTime（可选）'),
            _buildTextFieldTile('字数', _searchWordCountCtrl,
                placeholder: 'ruleSearch.wordCount（可选）'),
            _buildTextFieldTile('详情链接', _searchBookUrlCtrl,
                placeholder: 'ruleSearch.bookUrl（@href）'),
          ],
        ),
        CupertinoListSection.insetGrouped(
          header: const Text('发现规则（ruleExplore）'),
          children: [
            _buildTextFieldTile('书籍列表', _exploreBookListCtrl,
                placeholder: 'ruleExplore.bookList'),
            _buildTextFieldTile('书名', _exploreNameCtrl,
                placeholder: 'ruleExplore.name'),
            _buildTextFieldTile('作者', _exploreAuthorCtrl,
                placeholder: 'ruleExplore.author'),
            _buildTextFieldTile('分类/类型', _exploreKindCtrl,
                placeholder: 'ruleExplore.kind（可选）'),
            _buildTextFieldTile('封面', _exploreCoverUrlCtrl,
                placeholder: 'ruleExplore.coverUrl'),
            _buildTextFieldTile('简介', _exploreIntroCtrl,
                placeholder: 'ruleExplore.intro'),
            _buildTextFieldTile('最新章节', _exploreLastChapterCtrl,
                placeholder: 'ruleExplore.lastChapter'),
            _buildTextFieldTile('更新时间', _exploreUpdateTimeCtrl,
                placeholder: 'ruleExplore.updateTime（可选）'),
            _buildTextFieldTile('字数', _exploreWordCountCtrl,
                placeholder: 'ruleExplore.wordCount（可选）'),
            _buildTextFieldTile('详情链接', _exploreBookUrlCtrl,
                placeholder: 'ruleExplore.bookUrl'),
          ],
        ),
        CupertinoListSection.insetGrouped(
          header: const Text('详情规则（ruleBookInfo）'),
          children: [
            _buildTextFieldTile('根节点', _infoInitCtrl,
                placeholder: 'ruleBookInfo.init（可选）'),
            _buildTextFieldTile('书名', _infoNameCtrl,
                placeholder: 'ruleBookInfo.name'),
            _buildTextFieldTile('作者', _infoAuthorCtrl,
                placeholder: 'ruleBookInfo.author'),
            _buildTextFieldTile('封面', _infoCoverUrlCtrl,
                placeholder: 'ruleBookInfo.coverUrl'),
            _buildTextFieldTile('简介', _infoIntroCtrl,
                placeholder: 'ruleBookInfo.intro', maxLines: 3),
            _buildTextFieldTile('分类/类型', _infoKindCtrl,
                placeholder: 'ruleBookInfo.kind（可选）'),
            _buildTextFieldTile('最新章节', _infoLastChapterCtrl,
                placeholder: 'ruleBookInfo.lastChapter'),
            _buildTextFieldTile('更新时间', _infoUpdateTimeCtrl,
                placeholder: 'ruleBookInfo.updateTime（可选）'),
            _buildTextFieldTile('字数', _infoWordCountCtrl,
                placeholder: 'ruleBookInfo.wordCount（可选）'),
            _buildTextFieldTile('目录链接', _infoTocUrlCtrl,
                placeholder: 'ruleBookInfo.tocUrl（@href）'),
          ],
        ),
        CupertinoListSection.insetGrouped(
          header: const Text('目录规则（ruleToc）'),
          children: [
            _buildTextFieldTile('章节列表', _tocChapterListCtrl,
                placeholder: 'ruleToc.chapterList'),
            _buildTextFieldTile('章节名', _tocChapterNameCtrl,
                placeholder: 'ruleToc.chapterName'),
            _buildTextFieldTile('章节链接', _tocChapterUrlCtrl,
                placeholder: 'ruleToc.chapterUrl（@href）'),
            _buildTextFieldTile('目录下一页', _tocNextTocUrlCtrl,
                placeholder: 'ruleToc.nextTocUrl（可选，支持多候选）'),
            _buildTextFieldTile('目录预处理JS', _tocPreUpdateJsCtrl,
                placeholder: 'ruleToc.preUpdateJs（可选，JS）', maxLines: 4),
            _buildTextFieldTile('标题格式化JS', _tocFormatJsCtrl,
                placeholder: 'ruleToc.formatJs（可选，JS）', maxLines: 4),
          ],
        ),
        CupertinoListSection.insetGrouped(
          header: const Text('正文规则（ruleContent）'),
          children: [
            _buildTextFieldTile('标题（可选）', _contentTitleCtrl,
                placeholder: 'ruleContent.title'),
            _buildTextFieldTile('正文', _contentContentCtrl,
                placeholder: 'ruleContent.content（@text/@html）', maxLines: 4),
            _buildTextFieldTile('正文下一页', _contentNextContentUrlCtrl,
                placeholder: 'ruleContent.nextContentUrl（可选，支持多候选）'),
            _buildTextFieldTile('替换正则', _contentReplaceRegexCtrl,
                placeholder: 'ruleContent.replaceRegex（regex##rep##...）',
                maxLines: 4),
          ],
        ),
        CupertinoListSection.insetGrouped(
          header: const Text('字段即时预览（基于最近一次调试）'),
          children: [
            CupertinoListTile.notched(
              title: const Text('chapterName 预览'),
              additionalInfo: Text(
                (_previewChapterName == null || _previewChapterName!.isEmpty)
                    ? '—'
                    : '已提取',
              ),
              trailing: const CupertinoListTileChevron(),
              onTap: _previewChapterName == null || _previewChapterName!.isEmpty
                  ? null
                  : () => _openDebugText(
                        title: 'chapterName 预览',
                        text: [
                          'ruleToc.chapterName: ${_tocChapterNameCtrl.text.trim()}',
                          '',
                          _previewChapterName!,
                        ].join('\n'),
                      ),
            ),
            CupertinoListTile.notched(
              title: const Text('chapterUrl 预览'),
              additionalInfo: Text(
                (_previewChapterUrl == null || _previewChapterUrl!.isEmpty)
                    ? '—'
                    : '已提取',
              ),
              trailing: const CupertinoListTileChevron(),
              onTap: _previewChapterUrl == null || _previewChapterUrl!.isEmpty
                  ? null
                  : () => _openDebugText(
                        title: 'chapterUrl 预览',
                        text: [
                          'ruleToc.chapterUrl: ${_tocChapterUrlCtrl.text.trim()}',
                          '',
                          _previewChapterUrl!,
                        ].join('\n'),
                      ),
            ),
            CupertinoListTile.notched(
              title: const Text('content 预览'),
              additionalInfo: Text(
                (_debugContentResult == null ||
                        _debugContentResult!.trim().isEmpty)
                    ? '—'
                    : '${_debugContentResult!.length} 字符',
              ),
              trailing: const CupertinoListTileChevron(),
              onTap: _debugContentResult == null ||
                      _debugContentResult!.trim().isEmpty
                  ? null
                  : () => _openDebugText(
                        title: 'content 预览',
                        text: [
                          'ruleContent.content: ${_contentContentCtrl.text.trim()}',
                          '',
                          _debugContentResult!,
                        ].join('\n'),
                      ),
            ),
          ],
        ),
        CupertinoListSection.insetGrouped(
          children: [
            CupertinoListTile.notched(
              title: const Text('规则体检（Lint）'),
              subtitle: const Text('检查关键字段缺失、规则格式风险与链路可用性风险'),
              trailing: const CupertinoListTileChevron(),
              onTap: _runRuleLint,
            ),
            CupertinoListTile.notched(
              title: const Text('同步到 JSON'),
              subtitle: const Text('把基础与规则字段写入 JSON（保留未知字段）'),
              trailing: const CupertinoListTileChevron(),
              onTap: () => _syncFieldsToJson(switchToJsonTab: true),
            ),
            CupertinoListTile.notched(
              title: const Text('从 JSON 解析'),
              subtitle: const Text('用当前 JSON 刷新规则表单字段'),
              trailing: const CupertinoListTileChevron(),
              onTap: _syncJsonToFields,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBasicTab() {
    return ListView(
      children: [
        CupertinoListSection.insetGrouped(
          header: const Text('基础信息'),
          children: [
            _buildTextFieldTile('名称', _nameCtrl, placeholder: 'bookSourceName'),
            _buildTextFieldTile('地址', _urlCtrl, placeholder: 'bookSourceUrl'),
            _buildTextFieldTile('分组', _groupCtrl,
                placeholder: 'bookSourceGroup'),
            _buildTextFieldTile('类型', _typeCtrl,
                placeholder: 'bookSourceType（数字）'),
            _buildTextFieldTile(
              '自定义排序',
              _customOrderCtrl,
              placeholder: 'customOrder（数字）',
            ),
            _buildTextFieldTile('权重', _weightCtrl, placeholder: 'weight（数字）'),
            CupertinoListTile.notched(
              title: const Text('启用'),
              trailing: CupertinoSwitch(
                value: _enabled,
                onChanged: (v) => setState(() => _enabled = v),
              ),
            ),
            CupertinoListTile.notched(
              title: const Text('启用发现'),
              trailing: CupertinoSwitch(
                value: _enabledExplore,
                onChanged: (v) => setState(() => _enabledExplore = v),
              ),
            ),
          ],
        ),
        CupertinoListSection.insetGrouped(
          header: const Text('网络/登录'),
          children: [
            _buildTextFieldTile(
              '请求超时',
              _respondTimeCtrl,
              placeholder: 'respondTime（毫秒）',
            ),
            CupertinoListTile.notched(
              title: const Text('CookieJar'),
              subtitle: const Text('enabledCookieJar'),
              trailing: CupertinoSwitch(
                value: _enabledCookieJar,
                onChanged: (v) => setState(() => _enabledCookieJar = v),
              ),
            ),
            _buildTextFieldTile(
              '并发速率',
              _concurrentRateCtrl,
              placeholder: 'concurrentRate（可空）',
            ),
            _buildTextFieldTile(
              'Header',
              _headerCtrl,
              placeholder: 'header（支持 JSON 或每行 key:value）',
              maxLines: 6,
            ),
            _buildTextFieldTile('登录地址', _loginUrlCtrl, placeholder: 'loginUrl'),
            _buildTextFieldTile(
              '登录 UI',
              _loginUiCtrl,
              placeholder: 'loginUi（可空）',
              maxLines: 3,
            ),
            _buildTextFieldTile(
              '登录检查 JS',
              _loginCheckJsCtrl,
              placeholder: 'loginCheckJs（可空）',
              maxLines: 3,
            ),
            _buildTextFieldTile(
              'JS 库',
              _jsLibCtrl,
              placeholder: 'jsLib（可空）',
              maxLines: 2,
            ),
            _buildTextFieldTile(
              '封面解码 JS',
              _coverDecodeJsCtrl,
              placeholder: 'coverDecodeJs（可空）',
              maxLines: 3,
            ),
          ],
        ),
        CupertinoListSection.insetGrouped(
          header: const Text('URL'),
          children: [
            _buildTextFieldTile(
              '书籍 URL 正则',
              _bookUrlPatternCtrl,
              placeholder: 'bookUrlPattern（可空）',
            ),
            _buildTextFieldTile(
              '搜索 URL',
              _searchUrlCtrl,
              placeholder: 'searchUrl（含 {key} 或 {{key}}）',
            ),
            _buildTextFieldTile('发现 URL', _exploreUrlCtrl,
                placeholder: 'exploreUrl'),
            _buildTextFieldTile(
              '发现屏蔽',
              _exploreScreenCtrl,
              placeholder: 'exploreScreen（可空）',
            ),
          ],
        ),
        CupertinoListSection.insetGrouped(
          header: const Text('备注'),
          children: [
            _buildTextFieldTile(
              '书源备注',
              _bookSourceCommentCtrl,
              placeholder: 'bookSourceComment（可空）',
              maxLines: 4,
            ),
            _buildTextFieldTile(
              '变量备注',
              _variableCommentCtrl,
              placeholder: 'variableComment（可空）',
              maxLines: 4,
            ),
          ],
        ),
        CupertinoListSection.insetGrouped(
          children: [
            CupertinoListTile.notched(
              title: const Text('同步到 JSON'),
              subtitle: const Text('把上面常用字段写入 JSON（剥离 null）'),
              trailing: const CupertinoListTileChevron(),
              onTap: () => _syncFieldsToJson(switchToJsonTab: true),
            ),
            CupertinoListTile.notched(
              title: const Text('从 JSON 解析'),
              subtitle: const Text('用当前 JSON 刷新表单字段'),
              trailing: const CupertinoListTileChevron(),
              onTap: _syncJsonToFields,
            ),
          ],
        ),
        if (_jsonError != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Text(
              _jsonError!,
              style: TextStyle(
                color: CupertinoColors.systemRed.resolveFrom(context),
                fontSize: 13,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildJsonTab() {
    return Column(
      children: [
        if (_jsonError != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: Row(
              children: [
                Icon(
                  CupertinoIcons.exclamationmark_triangle_fill,
                  size: 16,
                  color: CupertinoColors.systemRed.resolveFrom(context),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _jsonError!,
                    style: TextStyle(
                      color: CupertinoColors.systemRed.resolveFrom(context),
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: CupertinoTextField(
              controller: _jsonCtrl,
              maxLines: null,
              minLines: 20,
              keyboardType: TextInputType.multiline,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
              onChanged: (_) => _validateJson(silent: true),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: Row(
            children: [
              Expanded(
                child: CupertinoButton.filled(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  onPressed: _formatJson,
                  child: const Text('格式化'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: CupertinoButton(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  onPressed: _validateJson,
                  child: const Text('校验'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDebugTab() {
    return ListView(
      children: [
        CupertinoListSection.insetGrouped(
          header: const Text('输入'),
          footer: const Text(
            '对标 Legado：\n'
            '- 关键字：搜索→详情→目录→正文\n'
            '- 绝对 URL：http/https 详情调试\n'
            '- 发现：标题::url\n'
            '- 目录：++tocUrl\n'
            '- 正文：--contentUrl',
          ),
          children: [
            CupertinoListTile.notched(
              title: const Text('Key'),
              subtitle: CupertinoTextField(
                controller: _debugKeyCtrl,
                placeholder: '输入关键字或调试 key',
              ),
            ),
            CupertinoListTile.notched(
              title: const Text('开始调试'),
              additionalInfo: _debugLoading ? const Text('运行中…') : null,
              trailing: const CupertinoListTileChevron(),
              onTap: _debugLoading ? null : _startLegadoStyleDebug,
            ),
            CupertinoListTile.notched(
              title: const Text('网页验证（Cloudflare）'),
              subtitle: const Text('打开 WebView 完成人机验证，然后导入 Cookie'),
              trailing: const CupertinoListTileChevron(),
              onTap: _openWebVerify,
            ),
            CupertinoListTile.notched(
              title: const Text('一键导出调试包（推荐）'),
              subtitle: const Text('保存为 zip：控制台 + 书源 JSON（不含网页源码）'),
              trailing: const CupertinoListTileChevron(),
              onTap: _debugLinesAll.isEmpty
                  ? null
                  : () => _exportDebugBundleToFile(includeRawSources: false),
            ),
            CupertinoListTile.notched(
              title: const Text('导出调试包（更多选项）'),
              subtitle: const Text('可选择：复制 / 保存（含源码）'),
              trailing: const CupertinoListTileChevron(),
              onTap:
                  _debugLinesAll.isEmpty ? null : _showExportDebugBundleSheet,
            ),
            CupertinoListTile.notched(
              title: const Text('清空控制台'),
              trailing: const CupertinoListTileChevron(),
              onTap: _clearDebugConsole,
            ),
            CupertinoListTile.notched(
              title: const Text('复制控制台（全部）'),
              additionalInfo: Text('${_debugLinesAll.length} 行'),
              trailing: const CupertinoListTileChevron(),
              onTap: _copyDebugConsole,
            ),
            CupertinoListTile.notched(
              title: const Text('复制最小复现信息'),
              subtitle: const Text('包含书源关键字段、请求决策摘要、最近日志'),
              trailing: const CupertinoListTileChevron(),
              onTap: _copyMinimalReproInfo,
            ),
          ],
        ),
        _buildDebugQuickActionsSection(),
        if (_debugError != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Text(
              _debugError!,
              style: TextStyle(
                color: CupertinoColors.systemRed.resolveFrom(context),
                fontSize: 13,
              ),
            ),
          ),
        _buildDebugSourcesSection(),
        _buildDebugConsoleSection(),
      ],
    );
  }

  void _openWebVerify() {
    final map = _buildPatchedJsonForDebug();
    if (map == null) {
      _showMessage('JSON 格式错误');
      return;
    }
    final source = BookSource.fromJson(map);
    if (source.bookSourceUrl.trim().isEmpty) {
      _showMessage('bookSourceUrl 不能为空');
      return;
    }

    final key = _debugKeyCtrl.text.trim();
    final url = _resolveWebVerifyUrl(source: source, key: key);
    Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (_) => SourceWebVerifyView(initialUrl: url),
      ),
    );
  }

  String _resolveWebVerifyUrl({
    required BookSource source,
    required String key,
  }) {
    String abs(String url) {
      final t = url.trim();
      if (t.startsWith('http://') || t.startsWith('https://')) return t;
      if (t.startsWith('//')) return 'https:$t';
      if (t.startsWith('/')) {
        final uri = Uri.parse(source.bookSourceUrl);
        return '${uri.scheme}://${uri.host}$t';
      }
      return '${source.bookSourceUrl}$t';
    }

    String buildSearchUrl(String template, String keyword) {
      var url = template;
      final enc = Uri.encodeComponent(keyword);
      url = url.replaceAll('{{key}}', enc);
      url = url.replaceAll('{key}', enc);
      url = url.replaceAll('{{searchKey}}', enc);
      url = url.replaceAll('{searchKey}', enc);
      return url;
    }

    if (key.isEmpty) return source.bookSourceUrl;
    if (key.startsWith('http://') || key.startsWith('https://')) return key;
    if (key.contains('::')) {
      final idx = key.indexOf('::');
      final url = key.substring(idx + 2).trim();
      return abs(url);
    }
    if (key.startsWith('++') || key.startsWith('--')) {
      final url = key.substring(2).trim();
      return abs(url);
    }
    if (source.searchUrl != null && source.searchUrl!.trim().isNotEmpty) {
      return abs(buildSearchUrl(source.searchUrl!.trim(), key));
    }
    return source.bookSourceUrl;
  }

  Widget _buildDebugQuickActionsSection() {
    final exploreUrl = _exploreUrlCtrl.text.trim();

    List<Widget> actions = [
      _buildQuickActionButton(
        label: '我的',
        onTap: () => _setDebugKeyAndMaybeRun('我的', run: false),
      ),
      _buildQuickActionButton(
        label: '++目录',
        onTap: () => _prefixKey('++'),
      ),
      _buildQuickActionButton(
        label: '--正文',
        onTap: () => _prefixKey('--'),
      ),
    ];

    if (exploreUrl.isNotEmpty) {
      actions.add(
        _buildQuickActionButton(
          label: '发现::exploreUrl',
          onTap: () => _setDebugKeyAndMaybeRun('发现::$exploreUrl', run: false),
        ),
      );
    }

    return CupertinoListSection.insetGrouped(
      header: const Text('快捷'),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: actions,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActionButton({
    required String label,
    required VoidCallback onTap,
  }) {
    return CupertinoButton(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      color: CupertinoColors.systemGrey5.resolveFrom(context),
      onPressed: onTap,
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          color: CupertinoColors.label.resolveFrom(context),
        ),
      ),
    );
  }

  void _setDebugKeyAndMaybeRun(String key, {required bool run}) {
    setState(() => _debugKeyCtrl.text = key);
    if (run && !_debugLoading) {
      _startLegadoStyleDebug();
    }
  }

  void _prefixKey(String prefix) {
    final text = _debugKeyCtrl.text.trim();
    if (text.isEmpty || text.length <= 2) {
      setState(() => _debugKeyCtrl.text = prefix);
      return;
    }
    if (!text.startsWith(prefix)) {
      setState(() => _debugKeyCtrl.text = '$prefix$text');
    }
  }

  Widget _buildDebugSourcesSection() {
    String? nonEmpty(String? s) =>
        (s != null && s.trim().isNotEmpty) ? s : null;
    final listHtml = nonEmpty(_debugListSrcHtml);
    final bookHtml = nonEmpty(_debugBookSrcHtml);
    final tocHtml = nonEmpty(_debugTocSrcHtml);
    final contentHtml = nonEmpty(_debugContentSrcHtml);
    final contentResult = nonEmpty(_debugContentResult);

    return CupertinoListSection.insetGrouped(
      header: const Text('源码 & 结果'),
      children: [
        CupertinoListTile.notched(
          title: const Text('列表页源码'),
          additionalInfo:
              Text(listHtml == null ? '—' : '${listHtml.length} 字符'),
          trailing: const CupertinoListTileChevron(),
          onTap: listHtml == null
              ? null
              : () => _openDebugText(title: '列表页源码', text: listHtml),
        ),
        CupertinoListTile.notched(
          title: const Text('详情页源码'),
          additionalInfo:
              Text(bookHtml == null ? '—' : '${bookHtml.length} 字符'),
          trailing: const CupertinoListTileChevron(),
          onTap: bookHtml == null
              ? null
              : () => _openDebugText(title: '详情页源码', text: bookHtml),
        ),
        CupertinoListTile.notched(
          title: const Text('目录页源码'),
          additionalInfo: Text(tocHtml == null ? '—' : '${tocHtml.length} 字符'),
          trailing: const CupertinoListTileChevron(),
          onTap: tocHtml == null
              ? null
              : () => _openDebugText(title: '目录页源码', text: tocHtml),
        ),
        CupertinoListTile.notched(
          title: const Text('正文页源码'),
          additionalInfo:
              Text(contentHtml == null ? '—' : '${contentHtml.length} 字符'),
          trailing: const CupertinoListTileChevron(),
          onTap: contentHtml == null
              ? null
              : () => _openDebugText(title: '正文页源码', text: contentHtml),
        ),
        CupertinoListTile.notched(
          title: const Text('正文结果（清理后）'),
          additionalInfo: Text(
            contentResult == null ? '—' : '${contentResult.length} 字符',
          ),
          trailing: const CupertinoListTileChevron(),
          onTap: contentResult == null
              ? null
              : () => _openDebugText(title: '正文结果', text: contentResult),
        ),
        CupertinoListTile.notched(
          title: const Text('运行时变量快照（脱敏）'),
          subtitle: const Text('含 @put/@get 运行期变量，用于调试链路排查'),
          additionalInfo: Text('${_debugRuntimeVarsSnapshot.length} 项'),
          trailing: const CupertinoListTileChevron(),
          onTap: _debugRuntimeVarsSnapshot.isEmpty
              ? null
              : () => _openDebugText(
                    title: '运行时变量快照（脱敏）',
                    text: _prettyJson(
                      LegadoJson.encode(_debugRuntimeVarsSnapshot),
                    ),
                  ),
        ),
        CupertinoListTile.notched(
          title: const Text('复制变量快照（脱敏）'),
          additionalInfo: Text('${_debugRuntimeVarsSnapshot.length} 项'),
          trailing: const CupertinoListTileChevron(),
          onTap: _debugRuntimeVarsSnapshot.isEmpty
              ? null
              : () {
                  Clipboard.setData(
                    ClipboardData(
                      text: _prettyJson(
                        LegadoJson.encode(_debugRuntimeVarsSnapshot),
                      ),
                    ),
                  );
                  _showMessage('已复制变量快照（脱敏）');
                },
        ),
      ],
    );
  }

  Widget _buildDebugConsoleSection() {
    final hasLines = _debugLinesAll.isNotEmpty;
    final mode = _debugConsoleMode;
    final modeLabel = mode == 0
        ? '分段'
        : mode == 1
            ? '文本'
            : '逐行';
    final allText =
        hasLines ? _debugLinesAll.map((e) => e.text).join('\n') : '';
    final totalLines = _debugLinesAll.length;
    final baseLines = _debugShowAllLines ? _debugLinesAll : _debugLines;
    final filterActive = _debugFilter.trim().isNotEmpty;
    final visibleLines = filterActive
        ? baseLines
            .where(
              (e) => e.text.toLowerCase().contains(_debugFilter.toLowerCase()),
            )
            .toList(growable: false)
        : baseLines;
    final uiLines = visibleLines.length;
    final effectiveMode = filterActive ? 2 : mode;

    final decisionSummary = _buildDebugDecisionSummaryLines();

    final children = <Widget>[
      if (decisionSummary.isNotEmpty)
        CupertinoListTile.notched(
          title: const Text('请求决策摘要（最近一次）'),
          subtitle: _buildDecisionSummaryPanel(decisionSummary.join('\n')),
          trailing: CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: () {
              Clipboard.setData(
                ClipboardData(text: decisionSummary.join('\n')),
              );
              _showMessage('已复制请求决策摘要');
            },
            child: const Icon(
              CupertinoIcons.doc_on_doc,
              size: 18,
            ),
          ),
        ),
      CupertinoListTile.notched(
        title: const Text('显示模式'),
        subtitle: CupertinoSlidingSegmentedControl<int>(
          groupValue: _debugConsoleMode,
          children: const {
            0: Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Text('分段')),
            1: Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Text('文本')),
            2: Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Text('逐行')),
          },
          onValueChanged: (v) {
            if (v == null) return;
            setState(() => _debugConsoleMode = v);
          },
        ),
      ),
      CupertinoListTile.notched(
        title: const Text('显示全部日志（全局放开）'),
        subtitle: const Text('开启后可能卡顿；建议排查时临时开启'),
        trailing: CupertinoSwitch(
          value: _debugShowAllLines,
          onChanged: (v) => setState(() => _debugShowAllLines = v),
        ),
      ),
      CupertinoListTile.notched(
        title: const Text('过滤关键字'),
        subtitle: CupertinoSearchTextField(
          placeholder: '输入后仅展示命中行（不区分大小写）',
          onChanged: (v) => setState(() => _debugFilter = v),
          onSuffixTap: () => setState(() => _debugFilter = ''),
        ),
      ),
      CupertinoListTile.notched(
        title: const Text('逐行自动换行'),
        subtitle: const Text('仅影响“逐行”模式；关闭时更清爽'),
        trailing: CupertinoSwitch(
          value: _debugWrapLines,
          onChanged: (v) => setState(() => _debugWrapLines = v),
        ),
      ),
      CupertinoListTile.notched(
        title: const Text('打开全文控制台'),
        additionalInfo: Text('$totalLines 行'),
        trailing: const CupertinoListTileChevron(),
        onTap:
            hasLines ? () => _openDebugText(title: '控制台', text: allText) : null,
      ),
    ];

    if (!hasLines) {
      children.add(
        const CupertinoListTile.notched(
          title: Text('暂无日志'),
        ),
      );
      return CupertinoListSection.insetGrouped(
        header: const Text('控制台'),
        children: children,
      );
    }

    if (effectiveMode == 1) {
      final visibleText = visibleLines.map((e) => e.text).join('\n');
      children.add(
        CupertinoListTile.notched(
          title: const Text('文本控制台'),
          subtitle: _buildConsoleTextPanel(visibleText),
          trailing: const CupertinoListTileChevron(),
          onTap: () => _openDebugText(title: '控制台', text: allText),
        ),
      );
    } else if (effectiveMode == 2) {
      String buildContextText(_DebugLine picked, {int radius = 28}) {
        final idx = _debugLinesAll.indexOf(picked);
        if (idx < 0) return picked.text;
        final start = (idx - radius) < 0 ? 0 : (idx - radius);
        final end = (idx + radius + 1) > _debugLinesAll.length
            ? _debugLinesAll.length
            : (idx + radius + 1);
        final slice = _debugLinesAll.sublist(start, end);
        final buf = StringBuffer();
        for (var i = 0; i < slice.length; i++) {
          final lineNo = start + i + 1;
          buf.writeln('${lineNo.toString().padLeft(4)}│ ${slice[i].text}');
        }
        return buf.toString().trimRight();
      }

      if (filterActive && mode == 0) {
        children.add(
          const CupertinoListTile.notched(
            title: Text('提示'),
            subtitle: Text('过滤开启时，分段模式会自动按逐行展示'),
          ),
        );
      }

      for (final line in visibleLines) {
        if (line.text.trim().isEmpty) continue;
        final color = line.state == -1
            ? CupertinoColors.systemRed.resolveFrom(context)
            : line.state == 1000
                ? CupertinoColors.systemGreen.resolveFrom(context)
                : CupertinoColors.label.resolveFrom(context);
        children.add(
          CupertinoListTile.notched(
            title: Text(
              line.text,
              maxLines: _debugWrapLines ? null : 3,
              overflow: _debugWrapLines
                  ? TextOverflow.visible
                  : TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 12.5,
                color: color,
              ),
            ),
            trailing: CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () {
                Clipboard.setData(ClipboardData(text: line.text));
                _showMessage('已复制该行日志');
              },
              child: const Icon(
                CupertinoIcons.doc_on_doc,
                size: 18,
              ),
            ),
            onTap: () => _openDebugText(
              title: '日志上下文',
              text: buildContextText(line),
            ),
          ),
        );
      }
    } else {
      final blocks = _buildDebugBlocks(lines: visibleLines);
      for (var i = 0; i < blocks.length; i++) {
        final block = blocks[i];
        final expanded = _expandedDebugBlocks.contains(i);

        final statusColor = block.hasError
            ? CupertinoColors.systemRed.resolveFrom(context)
            : CupertinoColors.secondaryLabel.resolveFrom(context);

        children.add(
          CupertinoListTile.notched(
            title: Text(block.titlePlain),
            subtitle: Text(
              block.summary ?? '—',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 12.0,
                color: statusColor,
              ),
            ),
            trailing: Icon(
              expanded
                  ? CupertinoIcons.chevron_down
                  : CupertinoIcons.chevron_right,
              size: 16,
              color: CupertinoColors.tertiaryLabel.resolveFrom(context),
            ),
            onTap: () {
              setState(() {
                if (expanded) {
                  _expandedDebugBlocks.remove(i);
                } else {
                  _expandedDebugBlocks.add(i);
                }
              });
            },
          ),
        );

        if (expanded) {
          final preview = block.previewText(maxLines: 18);
          children.add(
            CupertinoListTile.notched(
              title: const Text('内容预览'),
              subtitle: Text(
                preview,
                maxLines: 18,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12.5,
                  color: CupertinoColors.secondaryLabel.resolveFrom(context),
                ),
              ),
              trailing: const CupertinoListTileChevron(),
              onTap: () => _openDebugText(title: '日志分段', text: block.fullText),
            ),
          );
        }
      }
    }

    return CupertinoListSection.insetGrouped(
      header: Text(
        () {
          if (effectiveMode == 1) {
            return '控制台（$modeLabel，总 $totalLines 行）';
          }
          final baseCount = baseLines.length;
          final scopeLabel = _debugShowAllLines ? '全量' : '最近';
          final filterLabel = filterActive ? '过滤+逐行' : modeLabel;
          final shown = uiLines;
          return '控制台（$filterLabel，$scopeLabel $shown/$baseCount，总 $totalLines 行）';
        }(),
      ),
      children: children,
    );
  }

  Widget _buildConsoleTextPanel(String text) {
    final t = text.trimRight();
    final show = t.isEmpty ? '—' : t;
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: CupertinoColors.systemGrey6.resolveFrom(context),
        borderRadius: BorderRadius.circular(10),
      ),
      constraints: const BoxConstraints(minHeight: 120, maxHeight: 340),
      child: CupertinoScrollbar(
        child: SingleChildScrollView(
          child: SelectableText(
            show,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 12.5,
              color: CupertinoColors.label.resolveFrom(context),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDecisionSummaryPanel(String text) {
    final show = text.trim().isEmpty ? '—' : text.trimRight();
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: CupertinoColors.systemGrey6.resolveFrom(context),
        borderRadius: BorderRadius.circular(10),
      ),
      constraints: const BoxConstraints(minHeight: 88, maxHeight: 220),
      child: CupertinoScrollbar(
        child: SingleChildScrollView(
          child: SelectableText(
            show,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 12.5,
              color: CupertinoColors.label.resolveFrom(context),
            ),
          ),
        ),
      ),
    );
  }

  String _stripDebugTimePrefix(String text) {
    final t = text.trimLeft();
    if (!t.startsWith('[')) return t;
    final idx = t.indexOf('] ');
    if (idx < 0) return t;
    return t.substring(idx + 2);
  }

  void _updateRequestDecisionSummary(String message) {
    final plain = _stripDebugTimePrefix(message).trimLeft();
    String valueOf(String prefix) {
      return plain.substring(prefix.length).trim();
    }

    if (plain.startsWith('└请求决策：')) {
      _debugMethodDecision = valueOf('└请求决策：');
      return;
    }
    if (plain.startsWith('└重试决策：')) {
      _debugRetryDecision = valueOf('└重试决策：');
      return;
    }
    if (plain.startsWith('└请求编码：')) {
      _debugRequestCharsetDecision = valueOf('└请求编码：');
      return;
    }
    if (plain.startsWith('└请求体决策：')) {
      _debugBodyDecision = valueOf('└请求体决策：');
      return;
    }
    if (plain.startsWith('└响应编码：')) {
      _debugResponseCharset = valueOf('└响应编码：');
      return;
    }
    if (plain.startsWith('└响应解码决策：')) {
      _debugResponseCharsetDecision = valueOf('└响应解码决策：');
    }
  }

  void _updateRuleFieldPreviewFromLine(String message) {
    final plain = _stripDebugTimePrefix(message).trimLeft();
    if (plain.startsWith('┌获取章节名')) {
      _awaitingChapterNameValue = true;
      return;
    }
    if (plain.startsWith('┌获取章节链接')) {
      _awaitingChapterUrlValue = true;
      return;
    }
    if (plain.startsWith('┌')) {
      _awaitingChapterNameValue = false;
      _awaitingChapterUrlValue = false;
      return;
    }
    if (!plain.startsWith('└')) return;

    final value = plain.substring(1).trim();
    if (_awaitingChapterNameValue) {
      if (value.isNotEmpty) {
        _previewChapterName = value;
      }
      _awaitingChapterNameValue = false;
    }
    if (_awaitingChapterUrlValue) {
      if (value.isNotEmpty) {
        _previewChapterUrl = value;
      }
      _awaitingChapterUrlValue = false;
    }
  }

  List<String> _buildDebugDecisionSummaryLines() {
    final lines = <String>[];
    if (_debugMethodDecision != null && _debugMethodDecision!.isNotEmpty) {
      lines.add('method: $_debugMethodDecision');
    }
    if (_debugRetryDecision != null && _debugRetryDecision!.isNotEmpty) {
      lines.add('retry: $_debugRetryDecision');
    }
    if (_debugRequestCharsetDecision != null &&
        _debugRequestCharsetDecision!.isNotEmpty) {
      lines.add('requestCharset: $_debugRequestCharsetDecision');
    }
    if (_debugBodyDecision != null && _debugBodyDecision!.isNotEmpty) {
      lines.add('body: $_debugBodyDecision');
    }
    if (_debugResponseCharset != null && _debugResponseCharset!.isNotEmpty) {
      lines.add('responseCharset: $_debugResponseCharset');
    }
    if (_debugResponseCharsetDecision != null &&
        _debugResponseCharsetDecision!.isNotEmpty) {
      lines.add('responseDecode: $_debugResponseCharsetDecision');
    }
    return lines;
  }

  void _clearDebugConsole() {
    setState(() {
      _debugLines.clear();
      _debugLinesAll.clear();
      _expandedDebugBlocks.clear();
      _debugError = null;
      _debugListSrcHtml = null;
      _debugBookSrcHtml = null;
      _debugTocSrcHtml = null;
      _debugContentSrcHtml = null;
      _debugContentResult = null;
      _debugMethodDecision = null;
      _debugRetryDecision = null;
      _debugRequestCharsetDecision = null;
      _debugBodyDecision = null;
      _debugResponseCharset = null;
      _debugResponseCharsetDecision = null;
      _debugRuntimeVarsSnapshot = <String, String>{};
      _previewChapterName = null;
      _previewChapterUrl = null;
      _awaitingChapterNameValue = false;
      _awaitingChapterUrlValue = false;
    });
  }

  void _copyDebugConsole() {
    if (_debugLinesAll.isEmpty) {
      _showMessage('暂无日志可复制');
      return;
    }
    final text = _debugLinesAll.map((e) => e.text).join('\n');
    Clipboard.setData(ClipboardData(text: text));
    _showMessage('已复制全部日志');
  }

  void _copyMinimalReproInfo() {
    final text = _buildMinimalReproText();
    Clipboard.setData(ClipboardData(text: text));
    _showMessage('已复制最小复现信息');
  }

  String _buildMinimalReproText() {
    final now = DateTime.now().toIso8601String();
    final patched = _buildPatchedJsonForDebug();
    final source = patched == null ? null : BookSource.fromJson(patched);
    final debugKey = _debugKeyCtrl.text.trim();

    final lines = <String>[
      'SoupReader 最小复现信息',
      '生成时间：$now',
      'Debug Key：${debugKey.isEmpty ? '-' : debugKey}',
      if (source != null) '书源名称：${source.bookSourceName}',
      if (source != null) '书源地址：${source.bookSourceUrl}',
      if (source != null)
        '搜索地址：${(source.searchUrl ?? '').trim().isEmpty ? '-' : source.searchUrl}',
      if (source != null)
        '发现地址：${(source.exploreUrl ?? '').trim().isEmpty ? '-' : source.exploreUrl}',
      if (_debugError != null && _debugError!.trim().isNotEmpty)
        '最近错误：${_debugError!.trim()}',
    ];

    final decisions = _buildDebugDecisionSummaryLines();
    if (decisions.isNotEmpty) {
      lines
        ..add('')
        ..add('请求决策摘要：')
        ..addAll(decisions.map((e) => '- $e'));
    }

    final tailLogs = _debugLinesAll
        .map((e) => e.text)
        .where((e) => e.trim().isNotEmpty)
        .toList(growable: false);
    final start = tailLogs.length > 80 ? tailLogs.length - 80 : 0;
    final slice = tailLogs.sublist(start);
    if (slice.isNotEmpty) {
      lines
        ..add('')
        ..add('关键日志（最近 ${slice.length} 行）：')
        ..addAll(slice);
    }

    return lines.join('\n');
  }

  Map<String, dynamic> _buildDebugBundle({required bool includeRawSources}) {
    final now = DateTime.now().toIso8601String();
    final consoleText = _debugLinesAll.map((e) => e.text).join('\n');
    final lines = _debugLinesAll
        .map((e) => <String, dynamic>{'state': e.state, 'text': e.text})
        .toList(growable: false);

    final bundle = <String, dynamic>{
      'type': 'soupreader_debug_bundle',
      'version': 1,
      'createdAt': now,
      'debugKey': _debugKeyCtrl.text.trim(),
      'error': _debugError,
      'sourceJson': _jsonCtrl.text,
      'consoleText': consoleText,
      'consoleLines': lines,
      'requestDecisionSummary': <String, dynamic>{
        'method': _debugMethodDecision,
        'retry': _debugRetryDecision,
        'requestCharset': _debugRequestCharsetDecision,
        'body': _debugBodyDecision,
        'responseCharset': _debugResponseCharset,
        'responseDecode': _debugResponseCharsetDecision,
      },
      'runtimeVariables': _debugRuntimeVarsSnapshot,
    };

    if (includeRawSources) {
      bundle['rawSources'] = <String, dynamic>{
        'listHtml': _debugListSrcHtml,
        'bookHtml': _debugBookSrcHtml,
        'tocHtml': _debugTocSrcHtml,
        'contentHtml': _debugContentSrcHtml,
        'contentResult': _debugContentResult,
      };
    }

    return bundle;
  }

  Future<void> _showExportDebugBundleSheet() async {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('导出调试包'),
        message: const Text('调试包可能很大，建议优先保存到文件。'),
        actions: [
          CupertinoActionSheetAction(
            child: const Text('复制调试包（不含源码，推荐）'),
            onPressed: () {
              Navigator.pop(context);
              final bundle = _buildDebugBundle(includeRawSources: false);
              final json = _prettyJson(LegadoJson.encode(bundle));
              Clipboard.setData(ClipboardData(text: json));
              _showMessage('已复制调试包（不含源码）');
            },
          ),
          CupertinoActionSheetAction(
            child: const Text('保存调试包到文件（不含源码，推荐）'),
            onPressed: () async {
              Navigator.pop(context);
              await _exportDebugBundleToFile(includeRawSources: false);
            },
          ),
          CupertinoActionSheetAction(
            child: const Text('保存调试包到文件（含源码）'),
            onPressed: () async {
              Navigator.pop(context);
              await _exportDebugBundleToFile(includeRawSources: true);
            },
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          child: const Text('取消'),
          onPressed: () => Navigator.pop(context),
        ),
      ),
    );
  }

  Future<void> _exportDebugBundleToFile({
    required bool includeRawSources,
  }) async {
    final bundle = _buildDebugBundle(includeRawSources: includeRawSources);
    final ts = DateTime.now().millisecondsSinceEpoch;
    final fileName = includeRawSources
        ? 'soupreader_debug_bundle_full_$ts.zip'
        : 'soupreader_debug_bundle_$ts.zip';

    final bundleJson = _prettyJson(LegadoJson.encode(bundle));
    final files = <String, String>{
      'bundle.json': bundleJson,
      'console.txt': _debugLinesAll.map((e) => e.text).join('\n'),
      // 兼容排查：单独导出书源 JSON（原样）
      'source.json': _prettyJson(_jsonCtrl.text),
    };

    if (includeRawSources) {
      void putIfNonEmpty(String path, String? content) {
        final t = content?.trim();
        if (t == null || t.isEmpty) return;
        files[path] = content!;
      }

      putIfNonEmpty('raw/list.html', _debugListSrcHtml);
      putIfNonEmpty('raw/book.html', _debugBookSrcHtml);
      putIfNonEmpty('raw/toc.html', _debugTocSrcHtml);
      putIfNonEmpty('raw/content.html', _debugContentSrcHtml);
      putIfNonEmpty('raw/content_result.txt', _debugContentResult);
    }

    final ok = await _debugExportService.exportZipToFile(
      files: files,
      fileName: fileName,
    );
    if (!mounted) return;
    _showMessage(ok ? '已导出：$fileName' : '导出取消或失败');
  }

  List<_DebugBlock> _buildDebugBlocks({required List<_DebugLine> lines}) {
    final blocks = <_DebugBlock>[];
    _DebugBlock? current;

    String stripTimePrefix(String text) {
      final t = text.trimLeft();
      if (!t.startsWith('[')) return text;
      final idx = t.indexOf('] ');
      if (idx < 0) return text;
      return t.substring(idx + 2);
    }

    for (final line in lines) {
      final plain = stripTimePrefix(line.text).trimLeft();
      if (plain.startsWith('︾')) {
        current = _DebugBlock(title: line.text);
        blocks.add(current);
      }
      (current ??= _DebugBlock(title: '日志')).lines.add(line);
    }

    for (final b in blocks) {
      b.updateComputed();
    }
    return blocks;
  }

  Map<String, dynamic>? _buildPatchedJsonForDebug() {
    final base = _tryDecodeJsonMap(_jsonCtrl.text);
    if (base == null) return null;

    Map<String, dynamic> ensureMap(dynamic raw) {
      if (raw is Map<String, dynamic>) return Map<String, dynamic>.from(raw);
      if (raw is Map) {
        return raw.map((key, value) => MapEntry('$key', value));
      }
      return <String, dynamic>{};
    }

    final map = ensureMap(base);

    String? nonEmpty(TextEditingController ctrl, {bool trimValue = true}) {
      final raw = ctrl.text;
      if (raw.trim().isEmpty) return null;
      return trimValue ? raw.trim() : raw;
    }

    void setIfNonEmpty(
      String key,
      TextEditingController ctrl, {
      bool trimValue = true,
    }) {
      final v = nonEmpty(ctrl, trimValue: trimValue);
      if (v != null) map[key] = v;
    }

    void setIntIfParsable(String key, TextEditingController ctrl) {
      final t = ctrl.text.trim();
      if (t.isEmpty) return;
      final v = int.tryParse(t);
      if (v != null) map[key] = v;
    }

    // 基础字段：仅在表单非空时覆盖，避免“调试前同步”把 JSON 里的字段删空。
    setIfNonEmpty('bookSourceName', _nameCtrl);
    setIfNonEmpty('bookSourceUrl', _urlCtrl);
    setIfNonEmpty('bookSourceGroup', _groupCtrl);
    setIntIfParsable('bookSourceType', _typeCtrl);
    setIntIfParsable('customOrder', _customOrderCtrl);
    setIntIfParsable('weight', _weightCtrl);
    setIntIfParsable('respondTime', _respondTimeCtrl);
    map['enabled'] = _enabled;
    map['enabledExplore'] = _enabledExplore;
    map['enabledCookieJar'] = _enabledCookieJar;
    setIfNonEmpty('concurrentRate', _concurrentRateCtrl);
    setIfNonEmpty('bookUrlPattern', _bookUrlPatternCtrl);
    setIfNonEmpty('jsLib', _jsLibCtrl, trimValue: false);
    setIfNonEmpty('header', _headerCtrl, trimValue: false);
    setIfNonEmpty('loginUrl', _loginUrlCtrl);
    setIfNonEmpty('loginUi', _loginUiCtrl, trimValue: false);
    setIfNonEmpty('loginCheckJs', _loginCheckJsCtrl, trimValue: false);
    setIfNonEmpty('coverDecodeJs', _coverDecodeJsCtrl, trimValue: false);
    setIfNonEmpty('bookSourceComment', _bookSourceCommentCtrl,
        trimValue: false);
    setIfNonEmpty('variableComment', _variableCommentCtrl, trimValue: false);
    setIfNonEmpty('searchUrl', _searchUrlCtrl);
    setIfNonEmpty('exploreUrl', _exploreUrlCtrl);
    setIfNonEmpty('exploreScreen', _exploreScreenCtrl);

    Map<String, dynamic> patchRule(
      String key,
      Map<String, TextEditingController> updates, {
      Set<String> noTrimKeys = const {},
    }) {
      final rule = ensureMap(map[key]);
      for (final entry in updates.entries) {
        final fieldKey = entry.key;
        final ctrl = entry.value;
        final v = nonEmpty(ctrl, trimValue: !noTrimKeys.contains(fieldKey));
        if (v != null) rule[fieldKey] = v;
      }
      return rule;
    }

    map['ruleSearch'] = patchRule('ruleSearch', {
      'checkKeyWord': _searchCheckKeyWordCtrl,
      'bookList': _searchBookListCtrl,
      'name': _searchNameCtrl,
      'author': _searchAuthorCtrl,
      'bookUrl': _searchBookUrlCtrl,
      'coverUrl': _searchCoverUrlCtrl,
      'intro': _searchIntroCtrl,
      'kind': _searchKindCtrl,
      'lastChapter': _searchLastChapterCtrl,
      'updateTime': _searchUpdateTimeCtrl,
      'wordCount': _searchWordCountCtrl,
    });

    map['ruleExplore'] = patchRule('ruleExplore', {
      'bookList': _exploreBookListCtrl,
      'name': _exploreNameCtrl,
      'author': _exploreAuthorCtrl,
      'bookUrl': _exploreBookUrlCtrl,
      'coverUrl': _exploreCoverUrlCtrl,
      'intro': _exploreIntroCtrl,
      'kind': _exploreKindCtrl,
      'lastChapter': _exploreLastChapterCtrl,
      'updateTime': _exploreUpdateTimeCtrl,
      'wordCount': _exploreWordCountCtrl,
    });

    map['ruleBookInfo'] = patchRule(
      'ruleBookInfo',
      {
        'init': _infoInitCtrl,
        'name': _infoNameCtrl,
        'author': _infoAuthorCtrl,
        'coverUrl': _infoCoverUrlCtrl,
        'tocUrl': _infoTocUrlCtrl,
        'kind': _infoKindCtrl,
        'lastChapter': _infoLastChapterCtrl,
        'updateTime': _infoUpdateTimeCtrl,
        'wordCount': _infoWordCountCtrl,
        'intro': _infoIntroCtrl,
      },
      noTrimKeys: {'intro'},
    );

    map['ruleToc'] = patchRule(
      'ruleToc',
      {
        'chapterList': _tocChapterListCtrl,
        'chapterName': _tocChapterNameCtrl,
        'chapterUrl': _tocChapterUrlCtrl,
        'nextTocUrl': _tocNextTocUrlCtrl,
        'preUpdateJs': _tocPreUpdateJsCtrl,
        'formatJs': _tocFormatJsCtrl,
      },
      noTrimKeys: {'preUpdateJs', 'formatJs'},
    );

    map['ruleContent'] = patchRule(
      'ruleContent',
      {
        'title': _contentTitleCtrl,
        'content': _contentContentCtrl,
        'nextContentUrl': _contentNextContentUrlCtrl,
        'replaceRegex': _contentReplaceRegexCtrl,
      },
      noTrimKeys: {'content', 'replaceRegex', 'nextContentUrl'},
    );

    return map;
  }

  Future<void> _startLegadoStyleDebug() async {
    final map = _buildPatchedJsonForDebug();
    if (map == null) {
      setState(() => _debugError = 'JSON 格式错误');
      return;
    }
    final source = BookSource.fromJson(map);
    if (source.bookSourceUrl.trim().isEmpty) {
      setState(() => _debugError = 'bookSourceUrl 不能为空（否则无法构建请求地址）');
      return;
    }
    final key = _debugKeyCtrl.text.trim();
    if (key.isEmpty) {
      setState(() => _debugError = '请输入 key');
      return;
    }

    setState(() {
      _debugLoading = true;
      _debugError = null;
      _debugLines.clear();
      _debugLinesAll.clear();
      _debugListSrcHtml = null;
      _debugBookSrcHtml = null;
      _debugTocSrcHtml = null;
      _debugContentSrcHtml = null;
      _debugContentResult = null;
      _debugMethodDecision = null;
      _debugRetryDecision = null;
      _debugRequestCharsetDecision = null;
      _debugBodyDecision = null;
      _debugResponseCharset = null;
      _debugResponseCharsetDecision = null;
      _debugRuntimeVarsSnapshot = <String, String>{};
      _previewChapterName = null;
      _previewChapterUrl = null;
      _awaitingChapterNameValue = false;
      _awaitingChapterUrlValue = false;
    });

    try {
      await _engine.debugRun(
        source,
        key,
        onEvent: _onDebugEvent,
      );
      if (!mounted) return;
      setState(() {
        _debugRuntimeVarsSnapshot = _engine.debugRuntimeVariablesSnapshot();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _debugError = '调试失败：$e');
    } finally {
      if (mounted) {
        setState(() => _debugLoading = false);
      }
    }
  }

  void _onDebugEvent(SourceDebugEvent event) {
    if (!mounted) return;
    if (event.isRaw) {
      setState(() {
        switch (event.state) {
          case 10:
            _debugListSrcHtml = event.message;
            break;
          case 20:
            _debugBookSrcHtml = event.message;
            break;
          case 30:
            _debugTocSrcHtml = event.message;
            break;
          case 40:
            _debugContentSrcHtml = event.message;
            break;
          case 41:
            _debugContentResult = event.message;
            break;
        }
      });
      return;
    }

    setState(() {
      final line = _DebugLine(state: event.state, text: event.message);
      _updateRequestDecisionSummary(event.message);
      _updateRuleFieldPreviewFromLine(event.message);
      _debugLinesAll.add(line);
      _debugLines.add(line);
      // UI 列表模式保持轻量：仅保留最近一部分；“全文控制台/导出调试包”使用全量日志。
      const maxUiLines = 600;
      if (_debugLines.length > maxUiLines) {
        _debugLines.removeRange(0, _debugLines.length - maxUiLines);
      }

      if (event.state == -1) {
        _debugError = event.message;
      }
    });
  }

  Future<void> _openDebugText({
    required String title,
    required String text,
  }) async {
    await Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (_) => SourceDebugTextView(title: title, text: text),
      ),
    );
  }

  CupertinoListTile _buildTextFieldTile(
    String title,
    TextEditingController controller, {
    String? placeholder,
    int maxLines = 1,
  }) {
    return CupertinoListTile.notched(
      title: Text(title),
      subtitle: CupertinoTextField(
        controller: controller,
        placeholder: placeholder,
        maxLines: maxLines,
      ),
    );
  }

  void _showMore() {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('更多'),
        actions: [
          CupertinoActionSheetAction(
            child: const Text('复制 JSON'),
            onPressed: () {
              Navigator.pop(context);
              Clipboard.setData(ClipboardData(text: _jsonCtrl.text));
              _showMessage('已复制 JSON');
            },
          ),
          CupertinoActionSheetAction(
            child: const Text('从剪贴板粘贴 JSON'),
            onPressed: () {
              Navigator.pop(context);
              _pasteJsonFromClipboard();
            },
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          child: const Text('取消'),
          onPressed: () => Navigator.pop(context),
        ),
      ),
    );
  }

  Future<void> _pasteJsonFromClipboard() async {
    final data = await Clipboard.getData('text/plain');
    final text = data?.text?.trim();
    if (text == null || text.isEmpty) {
      _showMessage('剪贴板为空');
      return;
    }
    setState(() => _jsonCtrl.text = _prettyJson(text));
    _validateJson();
  }

  void _formatJson() {
    final map = _tryDecodeJsonMap(_jsonCtrl.text);
    if (map == null) {
      _validateJson();
      return;
    }
    final normalized = LegadoJson.encode(map);
    setState(() => _jsonCtrl.text = _prettyJson(normalized));
    _validateJson(silent: true);
  }

  Map<String, dynamic>? _tryDecodeJsonMap(String text) {
    try {
      final decoded = json.decode(text);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) {
        return decoded.map((key, value) => MapEntry('$key', value));
      }
    } catch (_) {}
    return null;
  }

  void _validateJson({bool silent = false}) {
    final map = _tryDecodeJsonMap(_jsonCtrl.text);
    String? error;
    if (map == null) {
      error = 'JSON 格式错误';
    } else {
      final source = BookSource.fromJson(map);
      if (source.bookSourceUrl.trim().isEmpty) {
        error = 'bookSourceUrl 不能为空';
      } else if (source.bookSourceName.trim().isEmpty) {
        error = 'bookSourceName 不能为空';
      }
    }
    if (!silent) {
      setState(() => _jsonError = error);
    } else {
      _jsonError = error;
    }
  }

  void _syncFieldsToJson({required bool switchToJsonTab}) {
    final map = _tryDecodeJsonMap(_jsonCtrl.text) ?? <String, dynamic>{};

    void setOrRemove(String key, String? value) {
      if (value == null) {
        map.remove(key);
      } else {
        map[key] = value;
      }
    }

    String? textOrNull(
      TextEditingController ctrl, {
      bool trimValue = true,
    }) {
      final raw = ctrl.text;
      if (raw.trim().isEmpty) return null;
      return trimValue ? raw.trim() : raw;
    }

    int parseInt(String text, int fallback) =>
        int.tryParse(text.trim()) ?? fallback;

    // 基础字段
    setOrRemove('bookSourceName', textOrNull(_nameCtrl));
    setOrRemove('bookSourceUrl', textOrNull(_urlCtrl));
    setOrRemove('bookSourceGroup', textOrNull(_groupCtrl));
    map['bookSourceType'] = parseInt(_typeCtrl.text, 0);
    map['customOrder'] = parseInt(_customOrderCtrl.text, 0);
    map['enabled'] = _enabled;
    map['enabledExplore'] = _enabledExplore;
    map['enabledCookieJar'] = _enabledCookieJar;
    map['respondTime'] = parseInt(_respondTimeCtrl.text, 180000);
    map['weight'] = parseInt(_weightCtrl.text, 0);
    setOrRemove('concurrentRate', textOrNull(_concurrentRateCtrl));
    setOrRemove('bookUrlPattern', textOrNull(_bookUrlPatternCtrl));
    setOrRemove('jsLib', textOrNull(_jsLibCtrl, trimValue: false));
    setOrRemove('header', textOrNull(_headerCtrl, trimValue: false));
    setOrRemove('loginUrl', textOrNull(_loginUrlCtrl));
    setOrRemove('loginUi', textOrNull(_loginUiCtrl, trimValue: false));
    setOrRemove(
        'loginCheckJs', textOrNull(_loginCheckJsCtrl, trimValue: false));
    setOrRemove(
        'coverDecodeJs', textOrNull(_coverDecodeJsCtrl, trimValue: false));
    setOrRemove('bookSourceComment',
        textOrNull(_bookSourceCommentCtrl, trimValue: false));
    setOrRemove(
        'variableComment', textOrNull(_variableCommentCtrl, trimValue: false));
    setOrRemove('searchUrl', textOrNull(_searchUrlCtrl));
    setOrRemove('exploreUrl', textOrNull(_exploreUrlCtrl));
    setOrRemove('exploreScreen', textOrNull(_exploreScreenCtrl));

    Map<String, dynamic> ensureMap(dynamic raw) {
      if (raw is Map<String, dynamic>) return Map<String, dynamic>.from(raw);
      if (raw is Map) {
        return raw.map((key, value) => MapEntry('$key', value));
      }
      return <String, dynamic>{};
    }

    Map<String, dynamic>? mergeRule(
        dynamic rawRule, Map<String, String?> updates) {
      final m = ensureMap(rawRule);
      updates.forEach((k, v) {
        if (v == null) {
          m.remove(k);
        } else {
          m[k] = v;
        }
      });
      return m.isEmpty ? null : m;
    }

    // 规则字段：在“保留未知字段”的前提下只覆盖常用键
    final ruleSearch = mergeRule(map['ruleSearch'], {
      'checkKeyWord': textOrNull(_searchCheckKeyWordCtrl),
      'bookList': textOrNull(_searchBookListCtrl),
      'name': textOrNull(_searchNameCtrl),
      'author': textOrNull(_searchAuthorCtrl),
      'bookUrl': textOrNull(_searchBookUrlCtrl),
      'coverUrl': textOrNull(_searchCoverUrlCtrl),
      'intro': textOrNull(_searchIntroCtrl),
      'kind': textOrNull(_searchKindCtrl),
      'lastChapter': textOrNull(_searchLastChapterCtrl),
      'updateTime': textOrNull(_searchUpdateTimeCtrl),
      'wordCount': textOrNull(_searchWordCountCtrl),
    });
    if (ruleSearch == null) {
      map.remove('ruleSearch');
    } else {
      map['ruleSearch'] = ruleSearch;
    }

    final ruleExplore = mergeRule(map['ruleExplore'], {
      'bookList': textOrNull(_exploreBookListCtrl),
      'name': textOrNull(_exploreNameCtrl),
      'author': textOrNull(_exploreAuthorCtrl),
      'bookUrl': textOrNull(_exploreBookUrlCtrl),
      'coverUrl': textOrNull(_exploreCoverUrlCtrl),
      'intro': textOrNull(_exploreIntroCtrl),
      'kind': textOrNull(_exploreKindCtrl),
      'lastChapter': textOrNull(_exploreLastChapterCtrl),
      'updateTime': textOrNull(_exploreUpdateTimeCtrl),
      'wordCount': textOrNull(_exploreWordCountCtrl),
    });
    if (ruleExplore == null) {
      map.remove('ruleExplore');
    } else {
      map['ruleExplore'] = ruleExplore;
    }

    final ruleBookInfo = mergeRule(map['ruleBookInfo'], {
      'init': textOrNull(_infoInitCtrl),
      'name': textOrNull(_infoNameCtrl),
      'author': textOrNull(_infoAuthorCtrl),
      'intro': textOrNull(_infoIntroCtrl, trimValue: false),
      'kind': textOrNull(_infoKindCtrl),
      'coverUrl': textOrNull(_infoCoverUrlCtrl),
      'tocUrl': textOrNull(_infoTocUrlCtrl),
      'lastChapter': textOrNull(_infoLastChapterCtrl),
      'updateTime': textOrNull(_infoUpdateTimeCtrl),
      'wordCount': textOrNull(_infoWordCountCtrl),
    });
    if (ruleBookInfo == null) {
      map.remove('ruleBookInfo');
    } else {
      map['ruleBookInfo'] = ruleBookInfo;
    }

    final ruleToc = mergeRule(map['ruleToc'], {
      'chapterList': textOrNull(_tocChapterListCtrl),
      'chapterName': textOrNull(_tocChapterNameCtrl),
      'chapterUrl': textOrNull(_tocChapterUrlCtrl),
      'nextTocUrl': textOrNull(_tocNextTocUrlCtrl),
      'preUpdateJs': textOrNull(_tocPreUpdateJsCtrl, trimValue: false),
      'formatJs': textOrNull(_tocFormatJsCtrl, trimValue: false),
    });
    if (ruleToc == null) {
      map.remove('ruleToc');
    } else {
      map['ruleToc'] = ruleToc;
    }

    final ruleContent = mergeRule(map['ruleContent'], {
      'title': textOrNull(_contentTitleCtrl),
      'content': textOrNull(_contentContentCtrl, trimValue: false),
      'nextContentUrl': textOrNull(_contentNextContentUrlCtrl),
      'replaceRegex': textOrNull(_contentReplaceRegexCtrl, trimValue: false),
    });
    if (ruleContent == null) {
      map.remove('ruleContent');
    } else {
      map['ruleContent'] = ruleContent;
    }

    final normalized = LegadoJson.encode(map);
    setState(() {
      _jsonCtrl.text = _prettyJson(normalized);
      if (switchToJsonTab) _tab = 2;
    });
    _validateJson();
  }

  void _syncJsonToFields() {
    final map = _tryDecodeJsonMap(_jsonCtrl.text);
    if (map == null) {
      _validateJson();
      return;
    }
    final source = BookSource.fromJson(map);
    setState(() {
      _nameCtrl.text = source.bookSourceName;
      _urlCtrl.text = source.bookSourceUrl;
      _groupCtrl.text = source.bookSourceGroup ?? '';
      _typeCtrl.text = source.bookSourceType.toString();
      _customOrderCtrl.text = source.customOrder.toString();
      _weightCtrl.text = source.weight.toString();
      _respondTimeCtrl.text = source.respondTime.toString();
      _enabledCookieJar = source.enabledCookieJar ?? true;
      _concurrentRateCtrl.text = source.concurrentRate ?? '';
      _bookUrlPatternCtrl.text = source.bookUrlPattern ?? '';
      _jsLibCtrl.text = source.jsLib ?? '';
      _headerCtrl.text = source.header ?? '';
      _loginUrlCtrl.text = source.loginUrl ?? '';
      _loginUiCtrl.text = source.loginUi ?? '';
      _loginCheckJsCtrl.text = source.loginCheckJs ?? '';
      _coverDecodeJsCtrl.text = source.coverDecodeJs ?? '';
      _bookSourceCommentCtrl.text = source.bookSourceComment ?? '';
      _variableCommentCtrl.text = source.variableComment ?? '';
      _searchUrlCtrl.text = source.searchUrl ?? '';
      _exploreUrlCtrl.text = source.exploreUrl ?? '';
      _exploreScreenCtrl.text = source.exploreScreen ?? '';
      _enabled = source.enabled;
      _enabledExplore = source.enabledExplore;

      _searchCheckKeyWordCtrl.text = source.ruleSearch?.checkKeyWord ?? '';
      _searchBookListCtrl.text = source.ruleSearch?.bookList ?? '';
      _searchNameCtrl.text = source.ruleSearch?.name ?? '';
      _searchAuthorCtrl.text = source.ruleSearch?.author ?? '';
      _searchBookUrlCtrl.text = source.ruleSearch?.bookUrl ?? '';
      _searchCoverUrlCtrl.text = source.ruleSearch?.coverUrl ?? '';
      _searchIntroCtrl.text = source.ruleSearch?.intro ?? '';
      _searchKindCtrl.text = source.ruleSearch?.kind ?? '';
      _searchLastChapterCtrl.text = source.ruleSearch?.lastChapter ?? '';
      _searchUpdateTimeCtrl.text = source.ruleSearch?.updateTime ?? '';
      _searchWordCountCtrl.text = source.ruleSearch?.wordCount ?? '';

      _exploreBookListCtrl.text = source.ruleExplore?.bookList ?? '';
      _exploreNameCtrl.text = source.ruleExplore?.name ?? '';
      _exploreAuthorCtrl.text = source.ruleExplore?.author ?? '';
      _exploreBookUrlCtrl.text = source.ruleExplore?.bookUrl ?? '';
      _exploreCoverUrlCtrl.text = source.ruleExplore?.coverUrl ?? '';
      _exploreIntroCtrl.text = source.ruleExplore?.intro ?? '';
      _exploreKindCtrl.text = source.ruleExplore?.kind ?? '';
      _exploreLastChapterCtrl.text = source.ruleExplore?.lastChapter ?? '';
      _exploreUpdateTimeCtrl.text = source.ruleExplore?.updateTime ?? '';
      _exploreWordCountCtrl.text = source.ruleExplore?.wordCount ?? '';

      _infoInitCtrl.text = source.ruleBookInfo?.init ?? '';
      _infoNameCtrl.text = source.ruleBookInfo?.name ?? '';
      _infoAuthorCtrl.text = source.ruleBookInfo?.author ?? '';
      _infoIntroCtrl.text = source.ruleBookInfo?.intro ?? '';
      _infoKindCtrl.text = source.ruleBookInfo?.kind ?? '';
      _infoCoverUrlCtrl.text = source.ruleBookInfo?.coverUrl ?? '';
      _infoTocUrlCtrl.text = source.ruleBookInfo?.tocUrl ?? '';
      _infoLastChapterCtrl.text = source.ruleBookInfo?.lastChapter ?? '';
      _infoUpdateTimeCtrl.text = source.ruleBookInfo?.updateTime ?? '';
      _infoWordCountCtrl.text = source.ruleBookInfo?.wordCount ?? '';

      _tocChapterListCtrl.text = source.ruleToc?.chapterList ?? '';
      _tocChapterNameCtrl.text = source.ruleToc?.chapterName ?? '';
      _tocChapterUrlCtrl.text = source.ruleToc?.chapterUrl ?? '';
      _tocNextTocUrlCtrl.text = source.ruleToc?.nextTocUrl ?? '';
      _tocPreUpdateJsCtrl.text = source.ruleToc?.preUpdateJs ?? '';
      _tocFormatJsCtrl.text = source.ruleToc?.formatJs ?? '';

      _contentTitleCtrl.text = source.ruleContent?.title ?? '';
      _contentContentCtrl.text = source.ruleContent?.content ?? '';
      _contentNextContentUrlCtrl.text =
          source.ruleContent?.nextContentUrl ?? '';
      _contentReplaceRegexCtrl.text = source.ruleContent?.replaceRegex ?? '';
    });
    _validateJson();
    _showMessage('已从 JSON 同步到表单');
  }

  Future<void> _save() async {
    // 优先用表单内容生成 JSON，避免用户忘记点“同步到 JSON”导致保存旧数据。
    // 若用户只编辑 JSON，可直接切换到 JSON 页保存（此处仍会做一次规范化）。
    _syncFieldsToJson(switchToJsonTab: false);
    _validateJson();
    if (_jsonError != null) {
      _showMessage(_jsonError!);
      return;
    }

    try {
      await _repo.upsertSourceRawJson(
        originalUrl: widget.originalUrl,
        rawJson: _jsonCtrl.text,
      );
      if (!mounted) return;
      _showMessage('保存成功');
    } catch (e) {
      if (!mounted) return;
      _showMessage('保存失败：$e');
    }
  }

  Future<void> _runRuleLint() async {
    final map = _buildPatchedJsonForDebug();
    if (map == null) {
      _showMessage('JSON 格式错误，无法执行规则体检');
      return;
    }

    final report = _ruleLintService.lintFromJson(map);
    final lines = <String>[
      'SoupReader 规则体检报告',
      '错误：${report.errorCount}',
      '警告：${report.warningCount}',
      '建议：${report.infoCount}',
      '',
    ];

    if (!report.hasIssues) {
      lines.add('✅ 未发现明显规则风险。');
    } else {
      for (var i = 0; i < report.issues.length; i++) {
        final item = report.issues[i];
        final level = item.level == RuleLintLevel.error
            ? '错误'
            : item.level == RuleLintLevel.warning
                ? '警告'
                : '建议';
        lines.add('${i + 1}. [$level] ${item.field}');
        lines.add('   ${item.message}');
        if (item.suggestion != null && item.suggestion!.trim().isNotEmpty) {
          lines.add('   建议：${item.suggestion!.trim()}');
        }
      }
    }

    final reportText = lines.join('\n');
    await _openDebugText(title: '规则体检报告', text: reportText);
  }

  String _prettyJson(String raw) {
    try {
      final decoded = json.decode(raw);
      const encoder = JsonEncoder.withIndent('  ');
      return encoder.convert(decoded);
    } catch (_) {
      return raw.trim();
    }
  }

  void _showMessage(String message) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('提示'),
        content: Text('\n$message'),
        actions: [
          CupertinoDialogAction(
            child: const Text('好'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }
}

class _DebugLine {
  final int state;
  final String text;

  const _DebugLine({
    required this.state,
    required this.text,
  });
}

class _DebugBlock {
  final String title;
  final List<_DebugLine> lines = <_DebugLine>[];

  bool hasError = false;
  String? summary;

  _DebugBlock({required this.title});

  String _stripTimePrefix(String text) {
    final t = text.trimLeft();
    if (!t.startsWith('[')) return text;
    final idx = t.indexOf('] ');
    if (idx < 0) return text;
    return t.substring(idx + 2);
  }

  String get titlePlain {
    final plain = _stripTimePrefix(title).trim();
    return plain.isEmpty ? '日志' : plain;
  }

  String get fullText => lines.map((e) => e.text).join('\n');

  String previewText({required int maxLines}) {
    if (maxLines <= 0) return '';
    final nonEmpty = lines
        .map((e) => e.text)
        .where((e) => e.trim().isNotEmpty)
        .toList(growable: false);
    if (nonEmpty.isEmpty) return '';
    final start = nonEmpty.length > maxLines ? nonEmpty.length - maxLines : 0;
    return nonEmpty.sublist(start).join('\n');
  }

  void updateComputed() {
    hasError = lines.any((e) => e.state == -1);
    summary = _buildSummary();
  }

  String? _buildSummary() {
    final plain = lines
        .map((e) => _stripTimePrefix(e.text).trimRight())
        .where((e) => e.trim().isNotEmpty)
        .toList(growable: false);
    if (plain.isEmpty) return null;

    String? firstWhere(bool Function(String s) test) {
      for (final s in plain) {
        if (test(s)) return s;
      }
      return null;
    }

    String? lastWhere(bool Function(String s) test) {
      for (var i = plain.length - 1; i >= 0; i--) {
        final s = plain[i];
        if (test(s)) return s;
      }
      return null;
    }

    final errorDetail = firstWhere(
      (s) => s.contains('DioException') || s.contains('HTTP 状态码异常'),
    );
    if (hasError && errorDetail != null) return errorDetail;

    final requestLine = lastWhere((s) => s.startsWith('≡'));
    if (requestLine != null) return requestLine;

    final anyLine = lastWhere((s) => s.startsWith('└') || s.startsWith('◇'));
    return anyLine ?? plain.first;
  }
}
