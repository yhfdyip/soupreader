import 'dart:async';
import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../../../app/theme/design_tokens.dart';
import '../../../app/widgets/app_toast.dart';
import '../../../app/theme/typography.dart';
import '../../../app/theme/ui_tokens.dart';
import '../../../app/widgets/app_action_list_sheet.dart';
import '../../../app/widgets/app_cupertino_page_scaffold.dart';
import '../../../app/widgets/app_nav_bar_button.dart';
import '../../../app/widgets/app_ui_kit.dart';
import '../../../app/widgets/cupertino_bottom_dialog.dart';
import '../../../core/database/database_service.dart';
import '../../../core/database/repositories/source_repository.dart';
import '../../../core/services/cookie_store.dart';
import '../../../core/services/qr_scan_service.dart';
import '../../../core/utils/legado_json.dart';
import '../../../core/services/source_login_store.dart';
import '../../../core/services/source_variable_store.dart';
import '../models/book_source.dart';
import '../constants/source_help_texts.dart';
import '../services/rule_parser_engine.dart';
import '../services/source_debug_export_service.dart';
import '../services/source_debug_key_parser.dart';
import '../services/source_debug_orchestrator.dart';
import '../services/source_explore_kinds_service.dart';
import '../services/source_cookie_scope_resolver.dart';
import '../services/source_legacy_save_service.dart';
import '../services/source_debug_summary_parser.dart';
import '../services/source_debug_summary_store.dart';
import '../services/source_quick_test_helper.dart';
import '../services/source_rule_lint_service.dart';
import 'source_debug_text_view.dart';
import 'source_web_verify_view.dart';

part 'source_edit_view_debug.dart';

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

enum _SourceEditDebugMenuAction {
  scanDebugKeyFromQr,
  openSearchSource,
  openBookSource,
  openTocSource,
  openContentSource,
  refreshExploreQuickActions,
  openDebugHelp,
}

enum _SourceEditDebugToolsAction {
  openWebVerify,
  openDebugAdvancedPanel,
  openStructuredSummary,
  copyStructuredSummary,
  exportDebugBundleQuick,
  exportDebugBundleMore,
  openRuntimeSnapshot,
  copyRuntimeSnapshot,
  copyDebugConsole,
  copyMinimalReproInfo,
  clearDebugConsole,
}

enum _SourceEditExportBundleAction {
  copyBundleWithoutRawSources,
  saveBundleWithoutRawSources,
  saveBundleWithRawSources,
}

enum _SourceEditMoreAction {
  clearCookie,
  copyJson,
  pasteJsonFromClipboard,
}

class _SourceEditViewState extends State<SourceEditView> {
  late final DatabaseService _db;
  late final SourceRepository _repo;
  late final SourceLegacySaveService _saveService;
  String? _currentOriginalUrl;
  BookSource? _savedSource;
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
    _saveService = SourceLegacySaveService(
      upsertSourceRawJson: ({
        String? originalUrl,
        required String rawJson,
      }) {
        return _repo.upsertSourceRawJson(
          originalUrl: originalUrl,
          rawJson: rawJson,
        );
      },
      clearExploreKindsCache: _exploreKindsService.clearExploreKindsCache,
      clearJsLibScope: (_) {
        // Flutter 侧当前无跨源共享 JS Scope，保留回调位以维持行为完整性。
      },
      removeSourceVariable: (sourceUrl) {
        return SourceVariableStore.removeVariable(sourceUrl);
      },
    );
    _currentOriginalUrl = (widget.originalUrl ?? '').trim();
    if (_currentOriginalUrl?.isEmpty == true) {
      _currentOriginalUrl = null;
    }
    _debugOrchestrator = SourceDebugOrchestrator(engine: _engine);

    _tab = widget.initialTab ?? 0;
    _jsonCtrl = TextEditingController(text: _prettyJson(widget.initialRawJson));
    final initialMap = _tryDecodeJsonMap(_jsonCtrl.text);
    final source = initialMap != null ? BookSource.fromJson(initialMap) : null;
    _savedSource = source;

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
          AppNavBarButton(
            onPressed: _save,
            child: const Text('保存'),
          ),
          AppNavBarButton(
            onPressed: _showMore,
            child: const Icon(CupertinoIcons.ellipsis),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: tabControl,
            ),
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

    return AppListView(
      children: [
        AppListSection(
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
        AppListSection(
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
        AppListSection(
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
        AppListSection(
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
        AppListSection(
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
        AppListSection(
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
        AppListSection(
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
        AppListSection(
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
    return AppListView(
      children: [
        AppListSection(
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
        AppListSection(
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
        AppListSection(
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
        AppListSection(
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
        AppListSection(
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
              style: const TextStyle(
                fontFamily: AppTypography.fontFamilyMonospace,
                fontSize: 13,
              ),
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

  void _showMore() async {
    final selected = await showAppActionListSheet<_SourceEditMoreAction>(
      context: context,
      title: '更多',
      showCancel: true,
      items: const [
        AppActionListItem<_SourceEditMoreAction>(
          value: _SourceEditMoreAction.clearCookie,
          icon: CupertinoIcons.delete_solid,
          label: '清 Cookie',
        ),
        AppActionListItem<_SourceEditMoreAction>(
          value: _SourceEditMoreAction.copyJson,
          icon: CupertinoIcons.doc_on_doc,
          label: '复制 JSON',
        ),
        AppActionListItem<_SourceEditMoreAction>(
          value: _SourceEditMoreAction.pasteJsonFromClipboard,
          icon: CupertinoIcons.doc_on_clipboard,
          label: '从剪贴板粘贴 JSON',
        ),
      ],
    );
    if (selected == null || !mounted) return;
    switch (selected) {
      case _SourceEditMoreAction.clearCookie:
        await _clearCookie();
        return;
      case _SourceEditMoreAction.copyJson:
        Clipboard.setData(ClipboardData(text: _jsonCtrl.text));
        if (mounted) unawaited(showAppToast(context, message: '已复制 JSON'));
        return;
      case _SourceEditMoreAction.pasteJsonFromClipboard:
        await _pasteJsonFromClipboard();
        return;
    }
  }

  Future<void> _clearCookie() async {
    final url = _urlCtrl.text.trim();
    if (url.isEmpty) {
      _showMessage('请先填写 bookSourceUrl');
      return;
    }

    final allCandidates = <Uri>[];
    final seen = <String>{};
    void addAll(Iterable<Uri> uris) {
      for (final uri in uris) {
        final key = uri.toString();
        if (seen.add(key)) {
          allCandidates.add(uri);
        }
      }
    }

    addAll(SourceCookieScopeResolver.resolveClearCandidates(url));
    if (allCandidates.isEmpty) {
      _showMessage('bookSourceUrl 不是有效 URL');
      return;
    }

    var cleared = 0;
    Object? lastError;
    for (final uri in allCandidates) {
      try {
        await CookieStore.jar.delete(uri, true);
        cleared += 1;
      } catch (e) {
        lastError = e;
      }
    }

    if (cleared > 0) {
      unawaited(showAppToast(context, message: '已清理该书源 Cookie'));
      return;
    }
    if (lastError != null) {
      _showMessage('清理 Cookie 失败：$lastError');
      return;
    }
    _showMessage('未找到可清理的 Cookie');
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
        unawaited(showAppToast(context, message: '登录态缓存已保存'));
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
    unawaited(showAppToast(context, message: '登录态缓存已清除'));
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
    unawaited(showAppToast(context, message: '已从 JSON 同步到表单'));
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
      final decoded = _tryDecodeJsonMap(_jsonCtrl.text);
      if (decoded == null) {
        _showMessage('JSON 格式错误');
        return;
      }
      final source = BookSource.fromJson(decoded);
      final saved = await _saveService.save(
        source: source,
        originalSource: _savedSource,
      );
      _savedSource = saved;
      _currentOriginalUrl = saved.bookSourceUrl;
      _urlCtrl.text = saved.bookSourceUrl;
      _jsonCtrl.text = _prettyJson(LegadoJson.encode(saved.toJson()));
      _validateJson(silent: true);
      await _saveLoginState(showMessage: false);
      if (!mounted) return;
      unawaited(showAppToast(context, message: '保存成功'));
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
      '规则体检报告',
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
    showCupertinoBottomDialog(
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
