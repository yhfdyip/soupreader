import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../../../app/widgets/app_cupertino_page_scaffold.dart';
import '../../../core/database/database_service.dart';
import '../../../core/database/entities/book_entity.dart';
import '../../../core/database/repositories/source_repository.dart';
import '../../../core/services/qr_scan_service.dart';
import '../../../core/utils/legado_json.dart';
import '../../../core/services/source_login_store.dart';
import '../models/book_source.dart';
import '../constants/source_help_texts.dart';
import '../services/rule_parser_engine.dart';
import '../services/source_debug_export_service.dart';
import '../services/source_debug_key_parser.dart';
import '../services/source_debug_orchestrator.dart';
import '../services/source_explore_kinds_service.dart';
import '../services/source_debug_summary_parser.dart';
import '../services/source_debug_summary_store.dart';
import '../services/source_quick_test_helper.dart';
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

  static SourceEditView fromSource(
    BookSource source, {
    String? rawJson,
    int? initialTab,
    String? initialDebugKey,
  }) {
    final normalizedRaw = (rawJson != null && rawJson.trim().isNotEmpty)
        ? rawJson
        : LegadoJson.encode(source.toJson());
    return SourceEditView(
      originalUrl: source.bookSourceUrl,
      initialRawJson: normalizedRaw,
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
  late final SourceDebugOrchestrator _debugOrchestrator;
  final SourceDebugExportService _debugExportService =
      SourceDebugExportService();
  final SourceExploreKindsService _exploreKindsService =
      SourceExploreKindsService();
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
  late final TextEditingController _loginHeaderCacheCtrl;
  late final TextEditingController _loginInfoCtrl;
  bool _loginStateLoading = false;
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
  final FocusNode _debugKeyFocusNode = FocusNode();
  bool _debugLoading = false;
  String? _debugError;
  final List<_DebugLine> _debugLines = <_DebugLine>[];
  final List<_DebugLine> _debugLinesAll = <_DebugLine>[];
  final ScrollController _debugTabScrollController = ScrollController();
  bool _debugAutoFollowLogs = true;
  bool _debugAutoScrollQueued = false;
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
  SourceDebugIntentType? _debugIntentType;
  List<MapEntry<String, String>> _cachedExploreQuickEntries =
      <MapEntry<String, String>>[];
  bool _refreshingExploreQuickActions = false;
  bool _showDebugQuickHelp = true;
  String? _previewChapterName;
  String? _previewChapterUrl;
  bool _awaitingChapterNameValue = false;
  bool _awaitingChapterUrlValue = false;

  @override
  void initState() {
    super.initState();
    _db = DatabaseService();
    _repo = SourceRepository(_db);
    _debugOrchestrator = SourceDebugOrchestrator(engine: _engine);

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
    _loginHeaderCacheCtrl = TextEditingController();
    _loginInfoCtrl = TextEditingController();
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
    _loadLoginStateForSource(source?.bookSourceUrl ?? widget.originalUrl);
    _debugKeyFocusNode.addListener(_onDebugKeyFocusChanged);
    _debugTabScrollController.addListener(_onDebugTabScrolled);
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
    _loginHeaderCacheCtrl.dispose();
    _loginInfoCtrl.dispose();
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
    _debugKeyFocusNode.removeListener(_onDebugKeyFocusChanged);
    _debugKeyFocusNode.dispose();
    _debugTabScrollController.removeListener(_onDebugTabScrolled);
    _debugTabScrollController.dispose();
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

    return AppCupertinoPageScaffold(
      title: '书源编辑',
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
    );
  }

  Widget _buildRulesTab() {
    final hasPreviewChapterUrl =
        _previewChapterUrl != null && _previewChapterUrl!.trim().isNotEmpty;

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
          header: const Text('规则页快速测试'),
          footer: const Text('会自动切到调试页并执行，便于边改规则边验证。'),
          children: [
            CupertinoListTile.notched(
              title: const Text('测试搜索规则'),
              subtitle: const Text('使用 checkKeyWord；为空时回退“我的”'),
              trailing: const CupertinoListTileChevron(),
              onTap: _runQuickSearchRuleTest,
            ),
            CupertinoListTile.notched(
              title: const Text('测试正文规则'),
              subtitle: Text(
                hasPreviewChapterUrl
                    ? '使用最近章节链接（--contentUrl）'
                    : '需先在调试中拿到 chapterUrl 后再测正文',
              ),
              trailing: const CupertinoListTileChevron(),
              onTap: _runQuickContentRuleTest,
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
            _buildTextFieldTile(
              '登录头缓存(JSON)',
              _loginHeaderCacheCtrl,
              placeholder: '{"Cookie":"sid=...","Authorization":"Bearer ..."}',
              maxLines: 4,
            ),
            _buildTextFieldTile(
              '登录信息缓存',
              _loginInfoCtrl,
              placeholder: 'userInfo（JSON 或文本，可空）',
              maxLines: 3,
            ),
            CupertinoListTile.notched(
              title: const Text('加载登录态缓存'),
              additionalInfo: _loginStateLoading ? const Text('加载中…') : null,
              trailing: const CupertinoListTileChevron(),
              onTap: _loginStateLoading
                  ? null
                  : () => _loadLoginStateForSource(_effectiveSourceKey()),
            ),
            CupertinoListTile.notched(
              title: const Text('保存登录态缓存'),
              subtitle: const Text('保存 loginHeader/loginInfo 到本地缓存'),
              trailing: const CupertinoListTileChevron(),
              onTap: _loginStateLoading ? null : () => _saveLoginState(),
            ),
            CupertinoListTile.notched(
              title: const Text('清除登录态缓存'),
              subtitle: const Text('清除当前书源的登录头与登录信息'),
              trailing: const CupertinoListTileChevron(),
              onTap: _loginStateLoading ? null : () => _clearLoginState(),
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
      controller: _debugTabScrollController,
      children: [
        _buildDebugPrimaryInputSection(),
        if (_showDebugQuickHelp) _buildDebugQuickActionsSection(),
        _buildDebugSecondaryToolsSection(),
        _buildDebugConsoleSection(),
      ],
    );
  }

  Widget _buildDebugPrimaryInputSection() {
    return CupertinoListSection.insetGrouped(
      header: const Text('输入'),
      footer: const Text('关键字/URL/前缀调试；完整语法见“更多工具 -> 调试帮助”。'),
      children: [
        CupertinoListTile.notched(
          title: const Text('Key'),
          additionalInfo: Text(_currentDebugIntentHint()),
          subtitle: CupertinoTextField(
            controller: _debugKeyCtrl,
            focusNode: _debugKeyFocusNode,
            placeholder: '输入关键字或调试 key',
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _startDebugFromInputSubmit(),
            onChanged: (_) => setState(() {}),
          ),
        ),
        CupertinoListTile.notched(
          title: const Text('扫码填充 Key'),
          trailing: const CupertinoListTileChevron(),
          onTap: _debugLoading ? null : _scanDebugKeyFromQr,
        ),
        CupertinoListTile.notched(
          title: const Text('开始调试'),
          subtitle: const Text('对标 Legado 主流程：输入后立即执行'),
          additionalInfo: _debugLoading ? const Text('运行中…') : null,
          trailing: const CupertinoListTileChevron(),
          onTap: _debugLoading ? null : _startLegadoStyleDebug,
        ),
      ],
    );
  }

  Widget _buildDebugSecondaryToolsSection() {
    return CupertinoListSection.insetGrouped(
      header: const Text('工具'),
      children: [
        if (!_showDebugQuickHelp)
          CupertinoListTile.notched(
            title: const Text('显示快捷提示'),
            subtitle: const Text('重新展开“我的/系统/发现候选/++/--”快捷区'),
            trailing: const CupertinoListTileChevron(),
            onTap: () {
              setState(() => _showDebugQuickHelp = true);
              _debugKeyFocusNode.requestFocus();
            },
          ),
        CupertinoListTile.notched(
          title: const Text('查看源码'),
          subtitle: const Text('搜索/详情/目录/正文/正文结果'),
          additionalInfo: Text('${_debugSourceReadyCount()}/5'),
          trailing: const CupertinoListTileChevron(),
          onTap: _showDebugSourceEntrySheet,
        ),
        CupertinoListTile.notched(
          title: const Text('刷新发现快捷项'),
          subtitle: const Text('对标 Legado「刷新发现」入口'),
          additionalInfo:
              _refreshingExploreQuickActions ? const Text('刷新中…') : null,
          trailing: const CupertinoListTileChevron(),
          onTap: _refreshingExploreQuickActions
              ? null
              : _refreshExploreQuickActions,
        ),
        CupertinoListTile.notched(
          title: const Text('更多工具'),
          subtitle: const Text('导出/摘要/变量快照/帮助/网页验证'),
          trailing: const CupertinoListTileChevron(),
          onTap: _showDebugMoreToolsSheet,
        ),
        if (!_debugAutoFollowLogs && _debugLinesAll.isNotEmpty)
          CupertinoListTile.notched(
            title: const Text('回到最新日志'),
            subtitle: Text('当前已暂停自动跟随（共 ${_debugLinesAll.length} 行）'),
            trailing: const CupertinoListTileChevron(),
            onTap: () {
              _scrollDebugToBottom(forceFollow: true, animated: true);
            },
          ),
      ],
    );
  }

  void _onDebugTabScrolled() {
    if (!_debugTabScrollController.hasClients) return;
    final position = _debugTabScrollController.position;
    final nearBottom = (position.maxScrollExtent - position.pixels) <= 72;
    if (nearBottom == _debugAutoFollowLogs) return;
    if (!mounted) {
      _debugAutoFollowLogs = nearBottom;
      return;
    }
    setState(() => _debugAutoFollowLogs = nearBottom);
  }

  void _onDebugKeyFocusChanged() {
    if (!_debugKeyFocusNode.hasFocus) return;
    if (!mounted || _showDebugQuickHelp) return;
    setState(() => _showDebugQuickHelp = true);
  }

  void _queueDebugAutoScroll({bool force = false}) {
    if (!force && !_debugAutoFollowLogs) return;
    if (_debugAutoScrollQueued) return;
    _debugAutoScrollQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _debugAutoScrollQueued = false;
      if (!mounted || !_debugTabScrollController.hasClients) return;
      _scrollDebugToBottom(forceFollow: force, animated: false);
    });
  }

  void _scrollDebugToBottom({
    bool forceFollow = false,
    bool animated = false,
  }) {
    if (!_debugTabScrollController.hasClients) return;
    final target = _debugTabScrollController.position.maxScrollExtent;
    if (forceFollow && _debugAutoFollowLogs != true) {
      if (mounted) {
        setState(() => _debugAutoFollowLogs = true);
      } else {
        _debugAutoFollowLogs = true;
      }
    }
    if (animated) {
      _debugTabScrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
      );
      return;
    }
    _debugTabScrollController.jumpTo(target);
  }

  int _debugSourceReadyCount() {
    final candidates = <String?>[
      _debugListSrcHtml,
      _debugBookSrcHtml,
      _debugTocSrcHtml,
      _debugContentSrcHtml,
      _debugContentResult,
    ];
    return candidates.where((e) => e?.trim().isNotEmpty == true).length;
  }

  String? _structuredSummaryText() {
    if (_debugLinesAll.isEmpty) return null;
    return _prettyJson(LegadoJson.encode(_buildStructuredDebugSummary()));
  }

  String? _runtimeSnapshotText() {
    if (_debugRuntimeVarsSnapshot.isEmpty) return null;
    return _prettyJson(LegadoJson.encode(_debugRuntimeVarsSnapshot));
  }

  Future<void> _showDebugSourceEntrySheet() async {
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (sheetContext) => CupertinoActionSheet(
        title: const Text('查看源码 / 结果'),
        message: const Text('源码查看已下沉到二级入口，减少主屏干扰。'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(sheetContext);
              _openDebugSourceFromMenu('列表页源码', _debugListSrcHtml);
            },
            child: const Text('列表页源码'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(sheetContext);
              _openDebugSourceFromMenu('详情页源码', _debugBookSrcHtml);
            },
            child: const Text('详情页源码'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(sheetContext);
              _openDebugSourceFromMenu('目录页源码', _debugTocSrcHtml);
            },
            child: const Text('目录页源码'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(sheetContext);
              _openDebugSourceFromMenu('正文页源码', _debugContentSrcHtml);
            },
            child: const Text('正文页源码'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(sheetContext);
              _openDebugSourceFromMenu('正文结果', _debugContentResult);
            },
            child: const Text('正文结果（清理后）'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(sheetContext),
          child: const Text('取消'),
        ),
      ),
    );
  }

  Future<void> _showDebugMoreToolsSheet() async {
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (sheetContext) {
        void closeThen(VoidCallback action) {
          Navigator.pop(sheetContext);
          Future<void>.delayed(Duration.zero, () {
            if (!mounted) return;
            action();
          });
        }

        return CupertinoActionSheet(
          title: const Text('更多工具'),
          message: const Text('高级能力下沉：主流程保留输入、快捷和日志。'),
          actions: [
            CupertinoActionSheetAction(
              onPressed: () => closeThen(() {
                _showDebugHelp();
              }),
              child: const Text('调试帮助'),
            ),
            CupertinoActionSheetAction(
              onPressed: () => closeThen(_openWebVerify),
              child: const Text('网页验证（Cloudflare）'),
            ),
            CupertinoActionSheetAction(
              onPressed: () => closeThen(() {
                _openDebugAdvancedPanel();
              }),
              child: const Text('高级诊断与源码'),
            ),
            CupertinoActionSheetAction(
              onPressed: () => closeThen(() {
                final text = _structuredSummaryText();
                if (text == null) {
                  _showMessage('暂无调试摘要，请先执行调试');
                  return;
                }
                _openDebugText(title: '结构化调试摘要', text: text);
              }),
              child: const Text('结构化调试摘要（脱敏）'),
            ),
            CupertinoActionSheetAction(
              onPressed: () => closeThen(() {
                final text = _structuredSummaryText();
                if (text == null) {
                  _showMessage('暂无调试摘要，请先执行调试');
                  return;
                }
                Clipboard.setData(ClipboardData(text: text));
                _showMessage('已复制调试摘要（脱敏）');
              }),
              child: const Text('复制调试摘要（脱敏）'),
            ),
            CupertinoActionSheetAction(
              onPressed: () => closeThen(() {
                if (_debugLinesAll.isEmpty) {
                  _showMessage('暂无调试日志，请先执行调试');
                  return;
                }
                _exportDebugBundleToFile(includeRawSources: false);
              }),
              child: const Text('一键导出调试包（推荐）'),
            ),
            CupertinoActionSheetAction(
              onPressed: () => closeThen(() {
                if (_debugLinesAll.isEmpty) {
                  _showMessage('暂无调试日志，请先执行调试');
                  return;
                }
                _showExportDebugBundleSheet();
              }),
              child: const Text('导出调试包（更多选项）'),
            ),
            CupertinoActionSheetAction(
              onPressed: () => closeThen(() {
                final text = _runtimeSnapshotText();
                if (text == null) {
                  _showMessage('暂无变量快照');
                  return;
                }
                _openDebugText(title: '运行时变量快照（脱敏）', text: text);
              }),
              child: const Text('运行时变量快照（脱敏）'),
            ),
            CupertinoActionSheetAction(
              onPressed: () => closeThen(() {
                final text = _runtimeSnapshotText();
                if (text == null) {
                  _showMessage('暂无变量快照');
                  return;
                }
                Clipboard.setData(ClipboardData(text: text));
                _showMessage('已复制变量快照（脱敏）');
              }),
              child: const Text('复制变量快照（脱敏）'),
            ),
            CupertinoActionSheetAction(
              onPressed: () => closeThen(_copyDebugConsole),
              child: const Text('复制控制台（全部）'),
            ),
            CupertinoActionSheetAction(
              onPressed: () => closeThen(_copyMinimalReproInfo),
              child: const Text('复制最小复现信息'),
            ),
            CupertinoActionSheetAction(
              isDestructiveAction: true,
              onPressed: () => closeThen(_clearDebugConsole),
              child: const Text('清空控制台'),
            ),
          ],
          cancelButton: CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(sheetContext),
            child: const Text('取消'),
          ),
        );
      },
    );
  }

  Future<void> _openDebugAdvancedPanel() async {
    await Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (_) => AppCupertinoPageScaffold(
          title: '高级调试',
          child: ListView(
            children: [
              _buildDiagnosisSection(),
              _buildDebugSourcesSection(),
            ],
          ),
        ),
      ),
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
    final defaultSearchKey = _defaultDebugSearchKey();
    final myLabel = defaultSearchKey;
    final exploreEntries = _collectExploreQuickEntries();
    final actions = <Widget>[
      _buildQuickActionButton(
        label: myLabel,
        onTap: () => _setDebugKeyAndMaybeRun(defaultSearchKey, run: true),
      ),
      _buildQuickActionButton(
        label: '系统',
        onTap: () => _setDebugKeyAndMaybeRun('系统', run: true),
      ),
      if (exploreEntries.isNotEmpty)
        _buildQuickActionButton(
          label: exploreEntries.first.value,
          onTap: () =>
              _setDebugKeyAndMaybeRun(exploreEntries.first.key, run: true),
        ),
      if (exploreEntries.length > 1)
        _buildQuickActionButton(
          label: '发现候选',
          onTap: () => _showExploreQuickPicker(exploreEntries),
        ),
      _buildQuickActionButton(
        label: '详情URL',
        onTap: _runCurrentKey,
      ),
      _buildQuickActionButton(
        label: '++目录',
        onTap: () => _prefixKeyAndMaybeRun('++'),
      ),
      _buildQuickActionButton(
        label: '--正文',
        onTap: () => _prefixKeyAndMaybeRun('--'),
      ),
    ];

    return CupertinoListSection.insetGrouped(
      header: const Text('快捷（对标 Legado）'),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '搜索关键字：我的 / 系统；发现：标题::url；目录：++url；正文：--url',
                style: TextStyle(
                  fontSize: 12,
                  color: CupertinoColors.secondaryLabel.resolveFrom(context),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: actions,
              ),
            ],
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

  String _currentDebugIntentHint() {
    final parsed = _debugOrchestrator.parseKey(_debugKeyCtrl.text.trim());
    final intent = parsed.intent;
    if (intent != null) {
      return intent.label;
    }
    final last = _debugIntentType;
    if (last == null) return '无效';
    return '上次:${_intentTypeLabel(last)}';
  }

  String _intentTypeLabel(SourceDebugIntentType type) {
    switch (type) {
      case SourceDebugIntentType.search:
        return '搜索';
      case SourceDebugIntentType.bookInfo:
        return '详情';
      case SourceDebugIntentType.explore:
        return '发现';
      case SourceDebugIntentType.toc:
        return '目录';
      case SourceDebugIntentType.content:
        return '正文';
    }
  }

  String _defaultDebugSearchKey() {
    final searchKey = _searchCheckKeyWordCtrl.text.trim();
    return searchKey.isEmpty ? '我的' : searchKey;
  }

  void _startDebugFromInputSubmit() {
    if (_debugLoading) return;
    _startLegadoStyleDebug();
  }

  void _setDebugKeyAndMaybeRun(String key, {required bool run}) {
    setState(() => _debugKeyCtrl.text = key);
    if (run && !_debugLoading) {
      _startLegadoStyleDebug();
    }
  }

  Future<void> _showExploreQuickPicker(
    List<MapEntry<String, String>> entries,
  ) async {
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: const Text('选择发现入口'),
        actions: entries
            .map(
              (entry) => CupertinoActionSheetAction(
                child: Text(entry.value),
                onPressed: () {
                  Navigator.pop(ctx);
                  _setDebugKeyAndMaybeRun(entry.key, run: true);
                },
              ),
            )
            .toList(growable: false),
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('取消'),
        ),
      ),
    );
  }

  List<MapEntry<String, String>> _collectExploreQuickEntries() {
    final parsed = _parseExploreQuickEntries(
      exploreUrl: _exploreUrlCtrl.text,
      exploreScreen: _exploreScreenCtrl.text,
    );
    if (_cachedExploreQuickEntries.isEmpty) {
      return parsed;
    }
    return _mergeExploreQuickEntries([
      ..._cachedExploreQuickEntries,
      ...parsed,
    ]);
  }

  List<MapEntry<String, String>> _parseExploreQuickEntries({
    required String exploreUrl,
    required String exploreScreen,
  }) {
    final result = <MapEntry<String, String>>[];
    final seen = <String>{};

    void addEntry(String title, String url) {
      final normalizedUrl = url.trim();
      if (normalizedUrl.isEmpty) return;
      final normalizedTitle = title.trim().isEmpty ? '发现' : title.trim();
      final key = '$normalizedTitle::$normalizedUrl';
      if (!seen.add(key)) return;
      final displayUrl = normalizedUrl.length <= 22
          ? normalizedUrl
          : '${normalizedUrl.substring(0, 22)}...';
      result.add(MapEntry(key, '$normalizedTitle::$displayUrl'));
    }

    bool isHttp(String value) {
      return value.startsWith('http://') || value.startsWith('https://');
    }

    void parseDynamic(dynamic node) {
      if (node is List) {
        for (final item in node) {
          parseDynamic(item);
        }
        return;
      }
      if (node is! Map) return;
      final map = node.map((key, value) => MapEntry('$key', value));
      final title = (map['title'] ?? map['name'] ?? '').toString().trim();
      final url =
          (map['url'] ?? map['value'] ?? map['link'] ?? '').toString().trim();
      if (isHttp(url)) {
        addEntry(title, url);
      }
    }

    final trimmedExploreUrl = exploreUrl.trim();
    if (trimmedExploreUrl.isNotEmpty) {
      final parts = trimmedExploreUrl.split(RegExp(r'(?:&&|\r?\n)+'));
      for (final rawPart in parts) {
        final part = rawPart.trim();
        if (part.isEmpty) continue;
        final idx = part.indexOf('::');
        if (idx >= 0) {
          final title = part.substring(0, idx).trim();
          final url = part.substring(idx + 2).trim();
          if (isHttp(url)) {
            addEntry(title, url);
          }
          continue;
        }
        if (isHttp(part)) {
          addEntry('发现', part);
        }
      }
      if (result.isEmpty &&
          (trimmedExploreUrl.startsWith('[') ||
              trimmedExploreUrl.startsWith('{'))) {
        try {
          parseDynamic(json.decode(trimmedExploreUrl));
        } catch (_) {
          // ignore parse failure
        }
      }
    }

    final raw = exploreScreen.trim();
    if (raw.isNotEmpty) {
      try {
        parseDynamic(json.decode(raw));
      } catch (_) {
        final regex = RegExp(r'([^:\n]+)::(https?://\S+)');
        for (final match in regex.allMatches(raw)) {
          final title = (match.group(1) ?? '').trim();
          final url = (match.group(2) ?? '').trim();
          if (url.isEmpty) continue;
          addEntry(title, url);
        }
      }
    }

    return result;
  }

  List<MapEntry<String, String>> _entriesFromExploreKinds(
    List<SourceExploreKind> kinds,
  ) {
    final out = <MapEntry<String, String>>[];
    for (final kind in kinds) {
      final url = (kind.url ?? '').trim();
      if (!(url.startsWith('http://') || url.startsWith('https://'))) {
        continue;
      }
      final title = kind.title.trim().isEmpty ? '发现' : kind.title.trim();
      final key = '$title::$url';
      final displayUrl = url.length <= 22 ? url : '${url.substring(0, 22)}...';
      out.add(MapEntry(key, '$title::$displayUrl'));
    }
    return out;
  }

  List<MapEntry<String, String>> _mergeExploreQuickEntries(
    List<MapEntry<String, String>> entries,
  ) {
    final seen = <String>{};
    final merged = <MapEntry<String, String>>[];
    for (final entry in entries) {
      final key = entry.key.trim();
      if (key.isEmpty || !seen.add(key)) continue;
      merged.add(entry);
    }
    return merged;
  }

  Future<void> _scanDebugKeyFromQr() async {
    final text = await QrScanService.scanText(
      context,
      title: '扫码填充调试 Key',
    );
    final value = text?.trim();
    if (value == null || value.isEmpty || !mounted) return;
    setState(() => _debugKeyCtrl.text = value);
  }

  void _runQuickSearchRuleTest() {
    if (!_ensureQuickTestIdle()) return;
    final key = SourceQuickTestHelper.buildSearchKey(
      checkKeyword: _searchCheckKeyWordCtrl.text,
    );
    _switchToDebugTabAndRun(key);
  }

  void _runQuickContentRuleTest() {
    if (!_ensureQuickTestIdle()) return;
    final key = SourceQuickTestHelper.buildContentKey(
      previewChapterUrl: _previewChapterUrl,
    );
    if (key == null) {
      _showMessage('请先调试搜索/目录拿到 chapterUrl，再测试正文规则');
      return;
    }
    _switchToDebugTabAndRun(key);
  }

  bool _ensureQuickTestIdle() {
    if (!_debugLoading) return true;
    _showMessage('调试运行中，请稍后再试');
    return false;
  }

  void _switchToDebugTabAndRun(String key) {
    setState(() => _tab = 3);
    _setDebugKeyAndMaybeRun(key, run: true);
  }

  void _prefixKeyAndMaybeRun(String prefix) {
    final text = _debugKeyCtrl.text.trim();
    if (text.isEmpty || text.length <= 2) {
      setState(() => _debugKeyCtrl.text = prefix);
      return;
    }
    final next = text.startsWith(prefix) ? text : '$prefix$text';
    setState(() => _debugKeyCtrl.text = next);
    if (!_debugLoading) {
      _startLegadoStyleDebug();
    }
  }

  void _runCurrentKey() {
    final key = _debugKeyCtrl.text.trim();
    if (key.isEmpty) {
      _showMessage('请先输入调试 key');
      return;
    }
    if (!_debugLoading) {
      _startLegadoStyleDebug();
    }
  }

  void _openDebugSourceFromMenu(String title, String? content) {
    final text = content?.trim();
    if (text == null || text.isEmpty) {
      _showMessage('$title 暂无内容，请先执行调试');
      return;
    }
    _openDebugText(title: title, text: text);
  }

  Future<void> _refreshExploreQuickActions() async {
    if (_refreshingExploreQuickActions) return;

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

    setState(() => _refreshingExploreQuickActions = true);
    try {
      await _exploreKindsService.clearExploreKindsCache(source);
      final exploreKinds = await _exploreKindsService.exploreKinds(
        source,
        forceRefresh: true,
      );
      final refreshed = <MapEntry<String, String>>[
        ..._entriesFromExploreKinds(exploreKinds),
        ..._parseExploreQuickEntries(
          exploreUrl: '',
          exploreScreen: source.exploreScreen ?? '',
        ),
      ];
      final debug = await _engine.exploreDebug(source);
      final requestUrl =
          (debug.fetch.finalUrl ?? debug.fetch.requestUrl).trim();
      if (requestUrl.isNotEmpty &&
          (requestUrl.startsWith('http://') ||
              requestUrl.startsWith('https://'))) {
        final key = '发现::$requestUrl';
        final display = requestUrl.length <= 22
            ? requestUrl
            : '${requestUrl.substring(0, 22)}...';
        refreshed.insert(0, MapEntry(key, '发现::$display'));
      }

      final merged = _mergeExploreQuickEntries(refreshed);
      setState(() => _cachedExploreQuickEntries = merged);

      if (merged.isEmpty) {
        _showMessage('当前未解析到发现快捷项，请检查 exploreUrl/exploreScreen');
        return;
      }
      if (debug.fetch.body == null || debug.error != null) {
        final reason = (debug.error ?? debug.fetch.error ?? '请求失败').trim();
        _showMessage('已刷新发现快捷项（${merged.length} 项），请求返回异常：$reason');
        return;
      }
      _showMessage('已刷新发现快捷项（${merged.length} 项）');
    } catch (e) {
      final fallback = _parseExploreQuickEntries(
        exploreUrl: _exploreUrlCtrl.text,
        exploreScreen: _exploreScreenCtrl.text,
      );
      setState(() => _cachedExploreQuickEntries = fallback);
      _showMessage('刷新失败：$e');
    } finally {
      if (mounted) {
        setState(() => _refreshingExploreQuickActions = false);
      }
    }
  }

  Future<void> _showDebugHelp() async {
    await _openDebugText(
      title: '调试帮助（对标 Legado）',
      text: _debugHelpText(),
    );
  }

  String _debugHelpText() {
    return SourceHelpTexts.debug;
  }

  Widget _buildDebugSourcesSection() {
    String? nonEmpty(String? s) =>
        (s != null && s.trim().isNotEmpty) ? s : null;
    final listHtml = nonEmpty(_debugListSrcHtml);
    final bookHtml = nonEmpty(_debugBookSrcHtml);
    final tocHtml = nonEmpty(_debugTocSrcHtml);
    final contentHtml = nonEmpty(_debugContentSrcHtml);
    final contentResult = nonEmpty(_debugContentResult);
    final hasDebugLines = _debugLinesAll.isNotEmpty;
    final structuredSummaryText = hasDebugLines
        ? _prettyJson(LegadoJson.encode(_buildStructuredDebugSummary()))
        : null;

    return CupertinoListSection.insetGrouped(
      header: const Text('源码 & 结果'),
      children: [
        CupertinoListTile.notched(
          title: const Text('结构化调试摘要（脱敏）'),
          subtitle: const Text('请求/解析/错误摘要，便于快速定位失败阶段'),
          additionalInfo: Text(hasDebugLines ? '可查看' : '—'),
          trailing: const CupertinoListTileChevron(),
          onTap: structuredSummaryText == null
              ? null
              : () => _openDebugText(
                    title: '结构化调试摘要',
                    text: structuredSummaryText,
                  ),
        ),
        CupertinoListTile.notched(
          title: const Text('复制调试摘要（脱敏）'),
          subtitle: const Text('用于 issue/群反馈，避免贴整段日志'),
          additionalInfo: Text(hasDebugLines ? '可复制' : '—'),
          trailing: const CupertinoListTileChevron(),
          onTap: structuredSummaryText == null
              ? null
              : () {
                  Clipboard.setData(ClipboardData(text: structuredSummaryText));
                  _showMessage('已复制调试摘要（脱敏）');
                },
        ),
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
    final hasLines = _debugLines.isNotEmpty;
    final totalLines = _debugLinesAll.length;
    final visibleLines = _debugLines;

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

    final children = <Widget>[
      if (_debugError != null && _debugError!.trim().isNotEmpty)
        CupertinoListTile.notched(
          title: Text(
            '最近错误',
            style: TextStyle(
              color: CupertinoColors.systemRed.resolveFrom(context),
            ),
          ),
          subtitle: Text(
            _debugError!,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              color: CupertinoColors.systemRed.resolveFrom(context),
            ),
          ),
        ),
      if (totalLines > visibleLines.length)
        CupertinoListTile.notched(
          title: Text('当前展示最近 ${visibleLines.length} 行'),
          subtitle: Text('完整日志共 $totalLines 行，可用“更多工具 -> 复制控制台（全部）”导出'),
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

    return CupertinoListSection.insetGrouped(
      header: Text('控制台（共 $totalLines 行）'),
      children: children,
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
      _debugAutoFollowLogs = true;
      _debugAutoScrollQueued = false;
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
    _queueDebugAutoScroll(force: true);
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

  Map<String, dynamic> _buildStructuredDebugSummary() {
    final logs = _debugLinesAll.map((e) => e.text).toList(growable: false);
    final stageErrors = _debugLinesAll
        .where((e) => e.state == -1)
        .map((e) => e.text)
        .toList(growable: false);
    return SourceDebugSummaryParser.build(
      logLines: logs,
      debugError: _debugError,
      errorLines: stageErrors,
    );
  }

  List<String> _debugDiagnosisLabels(Map<String, dynamic> summary) {
    final diagnosis = summary['diagnosis'];
    if (diagnosis is! Map) return const <String>[];
    final labelsRaw = diagnosis['labels'];
    if (labelsRaw is! List) return const <String>[];
    return labelsRaw
        .map((e) => e.toString().trim())
        .where((e) => e.isNotEmpty)
        .toList(growable: false);
  }

  List<String> _debugDiagnosisHints(Map<String, dynamic> summary) {
    final diagnosis = summary['diagnosis'];
    if (diagnosis is! Map) return const <String>[];
    final hintsRaw = diagnosis['hints'];
    if (hintsRaw is! List) return const <String>[];
    return hintsRaw
        .map((e) => e.toString().trim())
        .where((e) => e.isNotEmpty)
        .toList(growable: false);
  }

  String _labelText(String code) {
    switch (code) {
      case 'request_failure':
        return '请求失败';
      case 'parse_failure':
        return '解析失败';
      case 'paging_interrupted':
        return '分页中断';
      case 'ok':
        return '基本正常';
      case 'no_data':
        return '无数据';
      default:
        return code;
    }
  }

  Color _labelColor(String code) {
    switch (code) {
      case 'request_failure':
      case 'parse_failure':
      case 'paging_interrupted':
        return CupertinoColors.systemRed.resolveFrom(context);
      case 'ok':
        return CupertinoColors.systemGreen.resolveFrom(context);
      default:
        return CupertinoColors.secondaryLabel.resolveFrom(context);
    }
  }

  Widget _buildDiagnosisSection() {
    final hasLogs = _debugLinesAll.isNotEmpty;
    final summary = _buildStructuredDebugSummary();
    final labels = _debugDiagnosisLabels(summary);
    final hints = _debugDiagnosisHints(summary);

    return CupertinoListSection.insetGrouped(
      header: const Text('诊断标签'),
      children: [
        CupertinoListTile.notched(
          title: const Text('失败分类'),
          subtitle: hasLogs
              ? Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final label in labels)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _labelColor(label).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _labelColor(label).withValues(alpha: 0.35),
                          ),
                        ),
                        child: Text(
                          _labelText(label),
                          style: TextStyle(
                            fontSize: 12,
                            color: _labelColor(label),
                          ),
                        ),
                      ),
                  ],
                )
              : const Text('暂无调试数据，请先执行“开始调试”'),
          trailing: const CupertinoListTileChevron(),
          onTap: hasLogs
              ? () => _openDebugText(
                    title: '诊断标签（结构化）',
                    text: _prettyJson(LegadoJson.encode(summary['diagnosis'])),
                  )
              : null,
        ),
        CupertinoListTile.notched(
          title: const Text('定位建议'),
          subtitle: hasLogs
              ? Text(
                  hints.isEmpty ? '—' : hints.join('\n'),
                  style: TextStyle(
                    fontSize: 13,
                    color: CupertinoColors.secondaryLabel.resolveFrom(context),
                  ),
                )
              : const Text('—'),
          trailing: const CupertinoListTileChevron(),
          onTap: hasLogs
              ? () => _openDebugText(
                    title: '定位建议',
                    text: hints.isEmpty ? '—' : hints.join('\n'),
                  )
              : null,
        ),
      ],
    );
  }

  Map<String, dynamic> _buildDebugBundle({required bool includeRawSources}) {
    final now = DateTime.now().toIso8601String();
    final consoleText = _debugLinesAll.map((e) => e.text).join('\n');
    final lines = _debugLinesAll
        .map((e) => <String, dynamic>{'state': e.state, 'text': e.text})
        .toList(growable: false);
    final structuredSummary = _buildStructuredDebugSummary();

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
      'structuredSummary': structuredSummary,
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
    final summary = _buildStructuredDebugSummary();
    final ts = DateTime.now().millisecondsSinceEpoch;
    final fileName = includeRawSources
        ? 'soupreader_debug_bundle_full_$ts.zip'
        : 'soupreader_debug_bundle_$ts.zip';

    final bundleJson = _prettyJson(LegadoJson.encode(bundle));
    final files = <String, String>{
      'bundle.json': bundleJson,
      'console.txt': _debugLinesAll.map((e) => e.text).join('\n'),
      'summary.json': _prettyJson(LegadoJson.encode(summary)),
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
    _debugKeyFocusNode.unfocus();

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
    var key = _debugKeyCtrl.text.trim();
    if (key.isEmpty) {
      key = _defaultDebugSearchKey();
      _debugKeyCtrl.text = key;
    }
    final parsed = _debugOrchestrator.parseKey(key);
    final intent = parsed.intent;
    if (intent == null) {
      setState(() => _debugError = parsed.error ?? '请输入有效 key');
      return;
    }

    setState(() {
      _showDebugQuickHelp = false;
      _debugLoading = true;
      _debugError = null;
      _debugLines.clear();
      _debugLinesAll.clear();
      _debugAutoFollowLogs = true;
      _debugAutoScrollQueued = false;
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
      _debugIntentType = intent.type;
      _previewChapterName = null;
      _previewChapterUrl = null;
      _awaitingChapterNameValue = false;
      _awaitingChapterUrlValue = false;
    });
    _queueDebugAutoScroll(force: true);

    SourceDebugRunResult? runResult;
    try {
      runResult = await _debugOrchestrator.run(
        source: source,
        key: key,
        onEvent: _onDebugEvent,
      );
      if (!mounted) return;
      setState(() {
        _debugRuntimeVarsSnapshot = _engine.debugRuntimeVariablesSnapshot();
        if (_debugError == null &&
            runResult?.error?.trim().isNotEmpty == true) {
          _debugError = runResult!.error!.trim();
        }
      });
      _publishDebugSummary(
        source: source,
        intent: runResult.intent,
        runResult: runResult,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _debugError = '调试失败：$e');
      _publishDebugSummary(
        source: source,
        intent: intent,
        runResult: runResult,
      );
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
    _queueDebugAutoScroll();
  }

  void _publishDebugSummary({
    required BookSource source,
    required SourceDebugIntent intent,
    required SourceDebugRunResult? runResult,
  }) {
    final logLines = _debugLinesAll.map((line) => line.text).toList();
    final errorLines = _debugLinesAll
        .where((line) => line.state == -1)
        .map((line) => line.text)
        .toList();
    final summary = SourceDebugSummaryParser.build(
      logLines: logLines,
      debugError: _debugError,
      errorLines: errorLines,
    );
    final diagnosisRaw = summary['diagnosis'];
    final diagnosis = diagnosisRaw is Map
        ? diagnosisRaw.map((k, v) => MapEntry('$k', v))
        : const <String, dynamic>{};
    final primary = (diagnosis['primary'] ?? 'no_data').toString();
    final labels = (diagnosis['labels'] is List)
        ? (diagnosis['labels'] as List)
            .map((e) => e.toString())
            .where((e) => e.trim().isNotEmpty)
            .toList(growable: false)
        : const <String>[];
    final hints = (diagnosis['hints'] is List)
        ? (diagnosis['hints'] as List)
            .map((e) => e.toString())
            .where((e) => e.trim().isNotEmpty)
            .toList(growable: false)
        : const <String>[];

    final success = runResult?.success ??
        (_debugError == null &&
            !labels.contains('request_failure') &&
            !labels.contains('parse_failure'));

    SourceDebugSummaryStore.instance.push(
      SourceDebugSummary(
        finishedAt: DateTime.now(),
        sourceUrl: source.bookSourceUrl,
        sourceName: source.bookSourceName,
        key: intent.runKey,
        intentType: intent.type,
        success: success,
        debugError: _debugError,
        primaryDiagnosis: primary,
        diagnosisLabels: labels,
        diagnosisHints: hints,
      ),
    );
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

  String _effectiveSourceKey() {
    final fromUrl = _urlCtrl.text.trim();
    if (fromUrl.isNotEmpty) return fromUrl;
    final fromOriginal = (widget.originalUrl ?? '').trim();
    return fromOriginal;
  }

  Future<void> _loadLoginStateForSource(String? sourceKey) async {
    final key = (sourceKey ?? '').trim();
    if (key.isEmpty) {
      if (!mounted) return;
      setState(() {
        _loginHeaderCacheCtrl.text = '';
        _loginInfoCtrl.text = '';
      });
      return;
    }

    if (mounted) {
      setState(() => _loginStateLoading = true);
    }

    final headerMap = await SourceLoginStore.getLoginHeaderMap(key);
    final loginInfo = await SourceLoginStore.getLoginInfo(key);

    if (!mounted) return;
    setState(() {
      _loginStateLoading = false;
      _loginHeaderCacheCtrl.text = headerMap == null || headerMap.isEmpty
          ? ''
          : _prettyJson(jsonEncode(headerMap));
      _loginInfoCtrl.text = loginInfo ?? '';
    });
  }

  Future<void> _saveLoginState({bool showMessage = true}) async {
    final key = _effectiveSourceKey();
    if (key.isEmpty) {
      if (showMessage) {
        _showMessage('请先填写 bookSourceUrl，再保存登录态');
      }
      return;
    }

    final headerRaw = _loginHeaderCacheCtrl.text.trim();
    final loginInfo = _loginInfoCtrl.text.trim();

    try {
      if (headerRaw.isEmpty) {
        await SourceLoginStore.removeLoginHeader(key);
      } else {
        await SourceLoginStore.putLoginHeaderJson(key, headerRaw);
      }

      if (loginInfo.isEmpty) {
        await SourceLoginStore.removeLoginInfo(key);
      } else {
        await SourceLoginStore.putLoginInfo(key, loginInfo);
      }

      if (showMessage) {
        _showMessage('登录态缓存已保存');
      }
    } catch (e) {
      if (showMessage) {
        _showMessage('登录态保存失败：$e');
      }
    }
  }

  Future<void> _clearLoginState() async {
    final key = _effectiveSourceKey();
    if (key.isNotEmpty) {
      await SourceLoginStore.removeLoginHeader(key);
      await SourceLoginStore.removeLoginInfo(key);
    }

    if (!mounted) return;
    setState(() {
      _loginHeaderCacheCtrl.text = '';
      _loginInfoCtrl.text = '';
    });
    _showMessage('登录态缓存已清除');
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
    _loadLoginStateForSource(source.bookSourceUrl);
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
      await _saveLoginState(showMessage: false);
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
