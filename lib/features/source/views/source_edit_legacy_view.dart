import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../app/widgets/app_cupertino_page_scaffold.dart';
import '../../../core/database/database_service.dart';
import '../../../core/database/repositories/source_repository.dart';
import '../../../core/services/cookie_store.dart';
import '../../../core/services/qr_scan_service.dart';
import '../../../core/services/source_variable_store.dart';
import '../../../core/utils/legado_json.dart';
import '../../search/views/search_view.dart';
import '../../search/models/search_scope_group_helper.dart';
import '../constants/source_help_texts.dart';
import '../models/book_source.dart';
import '../services/source_cookie_scope_resolver.dart';
import '../services/source_explore_kinds_service.dart';
import '../services/source_import_export_service.dart';
import '../services/source_legacy_save_service.dart';
import '../services/source_login_ui_helper.dart';
import '../services/source_login_url_resolver.dart';
import '../services/source_rule_complete.dart';
import 'source_debug_legacy_view.dart';
import 'source_login_form_view.dart';
import 'source_qr_share_view.dart';
import 'source_web_verify_view.dart';

class SourceEditLegacyView extends StatefulWidget {
  final String? originalUrl;
  final String initialRawJson;
  final int? initialTab;

  const SourceEditLegacyView({
    super.key,
    required this.initialRawJson,
    this.originalUrl,
    this.initialTab,
  });

  static SourceEditLegacyView fromSource(
    BookSource source, {
    String? rawJson,
    int? initialTab,
  }) {
    final normalizedRaw = (rawJson != null && rawJson.trim().isNotEmpty)
        ? rawJson
        : LegadoJson.encode(source.toJson());
    return SourceEditLegacyView(
      originalUrl: source.bookSourceUrl,
      initialRawJson: normalizedRaw,
      initialTab: initialTab,
    );
  }

  @override
  State<SourceEditLegacyView> createState() => _SourceEditLegacyViewState();
}

class _SourceEditLegacyViewState extends State<SourceEditLegacyView> {
  static const String _prefRuleHelpShown = 'source_edit_rule_help_shown_v1';
  static const Map<String, String> _fieldLabels = <String, String>{
    'bookSourceUrl': '书源地址',
    'bookSourceName': '书源名称',
    'bookSourceGroup': '书源分组',
    'bookSourceComment': '备注',
    'loginUrl': '登录地址',
    'loginUi': '登录界面',
    'loginCheckJs': '登录校验JS',
    'coverDecodeJs': '封面解码JS',
    'bookUrlPattern': '书籍地址匹配',
    'header': '请求头',
    'variableComment': '变量说明',
    'concurrentRate': '并发率',
    'jsLib': 'JS库',
    'searchUrl': '搜索地址',
    'checkKeyWord': '关键词',
    'bookList': '书籍列表',
    'name': '书名',
    'author': '作者',
    'kind': '分类',
    'wordCount': '字数',
    'lastChapter': '最新章节',
    'intro': '简介',
    'coverUrl': '封面地址',
    'bookUrl': '书籍地址',
    'exploreUrl': '发现地址',
    'init': '详情初始化',
    'tocUrl': '目录地址',
    'canReName': '书名可改',
    'downloadUrls': '下载地址规则',
    'preUpdateJs': '目录预处理JS',
    'chapterList': '章节列表',
    'chapterName': '章节名',
    'chapterUrl': '章节地址',
    'formatJs': '格式化JS',
    'isVolume': '卷标记',
    'updateTime': '更新时间',
    'isVip': 'VIP标记',
    'isPay': '付费标记',
    'nextTocUrl': '下一页目录',
    'content': '正文内容',
    'title': '正文标题',
    'nextContentUrl': '下一页正文',
    'webJs': 'WebView JS',
    'sourceRegex': '替换源正则',
    'replaceRegex': '替换规则',
    'imageStyle': '图片样式',
    'imageDecode': '图片解码',
    'payAction': '购买动作',
  };

  late final DatabaseService _db;
  late final SourceRepository _repo;
  late final SourceExploreKindsService _exploreKindsService;
  late final SourceImportExportService _importExportService;
  late final SourceLegacySaveService _saveService;

  int _tab = 0;
  bool _autoComplete = false;

  String? _currentOriginalUrl;
  BookSource? _savedSource;
  String _savedSnapshot = '';

  bool _enabled = true;
  bool _enabledExplore = true;
  bool _enabledCookieJar = true;
  int _bookSourceType = 0;
  String? _activeFieldKey;
  TextEditingController? _activeFieldController;

  late final TextEditingController _bookSourceUrlCtrl;
  late final TextEditingController _bookSourceNameCtrl;
  late final TextEditingController _bookSourceGroupCtrl;
  late final TextEditingController _bookSourceCommentCtrl;
  late final TextEditingController _loginUrlCtrl;
  late final TextEditingController _loginUiCtrl;
  late final TextEditingController _loginCheckJsCtrl;
  late final TextEditingController _coverDecodeJsCtrl;
  late final TextEditingController _bookUrlPatternCtrl;
  late final TextEditingController _headerCtrl;
  late final TextEditingController _variableCommentCtrl;
  late final TextEditingController _concurrentRateCtrl;
  late final TextEditingController _jsLibCtrl;

  late final TextEditingController _searchUrlCtrl;
  late final TextEditingController _searchCheckKeyWordCtrl;
  late final TextEditingController _searchBookListCtrl;
  late final TextEditingController _searchNameCtrl;
  late final TextEditingController _searchAuthorCtrl;
  late final TextEditingController _searchKindCtrl;
  late final TextEditingController _searchWordCountCtrl;
  late final TextEditingController _searchLastChapterCtrl;
  late final TextEditingController _searchIntroCtrl;
  late final TextEditingController _searchCoverUrlCtrl;
  late final TextEditingController _searchBookUrlCtrl;

  late final TextEditingController _exploreUrlCtrl;
  late final TextEditingController _exploreBookListCtrl;
  late final TextEditingController _exploreNameCtrl;
  late final TextEditingController _exploreAuthorCtrl;
  late final TextEditingController _exploreKindCtrl;
  late final TextEditingController _exploreWordCountCtrl;
  late final TextEditingController _exploreLastChapterCtrl;
  late final TextEditingController _exploreIntroCtrl;
  late final TextEditingController _exploreCoverUrlCtrl;
  late final TextEditingController _exploreBookUrlCtrl;

  late final TextEditingController _infoInitCtrl;
  late final TextEditingController _infoNameCtrl;
  late final TextEditingController _infoAuthorCtrl;
  late final TextEditingController _infoKindCtrl;
  late final TextEditingController _infoWordCountCtrl;
  late final TextEditingController _infoLastChapterCtrl;
  late final TextEditingController _infoIntroCtrl;
  late final TextEditingController _infoCoverUrlCtrl;
  late final TextEditingController _infoTocUrlCtrl;
  late final TextEditingController _infoCanRenameCtrl;
  late final TextEditingController _infoDownloadUrlsCtrl;

  late final TextEditingController _tocPreUpdateJsCtrl;
  late final TextEditingController _tocChapterListCtrl;
  late final TextEditingController _tocChapterNameCtrl;
  late final TextEditingController _tocChapterUrlCtrl;
  late final TextEditingController _tocFormatJsCtrl;
  late final TextEditingController _tocIsVolumeCtrl;
  late final TextEditingController _tocUpdateTimeCtrl;
  late final TextEditingController _tocIsVipCtrl;
  late final TextEditingController _tocIsPayCtrl;
  late final TextEditingController _tocNextTocUrlCtrl;

  late final TextEditingController _contentContentCtrl;
  late final TextEditingController _contentTitleCtrl;
  late final TextEditingController _contentNextContentUrlCtrl;
  late final TextEditingController _contentWebJsCtrl;
  late final TextEditingController _contentSourceRegexCtrl;
  late final TextEditingController _contentReplaceRegexCtrl;
  late final TextEditingController _contentImageStyleCtrl;
  late final TextEditingController _contentImageDecodeCtrl;
  late final TextEditingController _contentPayActionCtrl;

  @override
  void initState() {
    super.initState();
    _db = DatabaseService();
    _repo = SourceRepository(_db);
    _exploreKindsService = SourceExploreKindsService(databaseService: _db);
    _importExportService = SourceImportExportService();
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

    _tab = (widget.initialTab ?? 0).clamp(0, 5);
    _currentOriginalUrl = (widget.originalUrl ?? '').trim();
    if (_currentOriginalUrl?.isEmpty == true) {
      _currentOriginalUrl = null;
    }

    final source = _parseInitialSource();
    _setupControllers(source);
    _savedSource = source;
    _savedSnapshot = _snapshotFor(source);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybeShowRuleHelp();
    });
  }

  @override
  void dispose() {
    _bookSourceUrlCtrl.dispose();
    _bookSourceNameCtrl.dispose();
    _bookSourceGroupCtrl.dispose();
    _bookSourceCommentCtrl.dispose();
    _loginUrlCtrl.dispose();
    _loginUiCtrl.dispose();
    _loginCheckJsCtrl.dispose();
    _coverDecodeJsCtrl.dispose();
    _bookUrlPatternCtrl.dispose();
    _headerCtrl.dispose();
    _variableCommentCtrl.dispose();
    _concurrentRateCtrl.dispose();
    _jsLibCtrl.dispose();

    _searchUrlCtrl.dispose();
    _searchCheckKeyWordCtrl.dispose();
    _searchBookListCtrl.dispose();
    _searchNameCtrl.dispose();
    _searchAuthorCtrl.dispose();
    _searchKindCtrl.dispose();
    _searchWordCountCtrl.dispose();
    _searchLastChapterCtrl.dispose();
    _searchIntroCtrl.dispose();
    _searchCoverUrlCtrl.dispose();
    _searchBookUrlCtrl.dispose();

    _exploreUrlCtrl.dispose();
    _exploreBookListCtrl.dispose();
    _exploreNameCtrl.dispose();
    _exploreAuthorCtrl.dispose();
    _exploreKindCtrl.dispose();
    _exploreWordCountCtrl.dispose();
    _exploreLastChapterCtrl.dispose();
    _exploreIntroCtrl.dispose();
    _exploreCoverUrlCtrl.dispose();
    _exploreBookUrlCtrl.dispose();

    _infoInitCtrl.dispose();
    _infoNameCtrl.dispose();
    _infoAuthorCtrl.dispose();
    _infoKindCtrl.dispose();
    _infoWordCountCtrl.dispose();
    _infoLastChapterCtrl.dispose();
    _infoIntroCtrl.dispose();
    _infoCoverUrlCtrl.dispose();
    _infoTocUrlCtrl.dispose();
    _infoCanRenameCtrl.dispose();
    _infoDownloadUrlsCtrl.dispose();

    _tocPreUpdateJsCtrl.dispose();
    _tocChapterListCtrl.dispose();
    _tocChapterNameCtrl.dispose();
    _tocChapterUrlCtrl.dispose();
    _tocFormatJsCtrl.dispose();
    _tocIsVolumeCtrl.dispose();
    _tocUpdateTimeCtrl.dispose();
    _tocIsVipCtrl.dispose();
    _tocIsPayCtrl.dispose();
    _tocNextTocUrlCtrl.dispose();

    _contentContentCtrl.dispose();
    _contentTitleCtrl.dispose();
    _contentNextContentUrlCtrl.dispose();
    _contentWebJsCtrl.dispose();
    _contentSourceRegexCtrl.dispose();
    _contentReplaceRegexCtrl.dispose();
    _contentImageStyleCtrl.dispose();
    _contentImageDecodeCtrl.dispose();
    _contentPayActionCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final canExit = await _confirmExitIfDirty();
        if (!canExit || !context.mounted) return;
        Navigator.of(context).pop();
      },
      child: AppCupertinoPageScaffold(
        title: '书源编辑',
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CupertinoButton(
              padding: EdgeInsets.zero,
              minimumSize: const Size(30, 30),
              onPressed: _save,
              child: const Text('保存'),
            ),
            CupertinoButton(
              padding: EdgeInsets.zero,
              minimumSize: const Size(30, 30),
              onPressed: _saveAndOpenDebug,
              child: const Text('调试'),
            ),
            CupertinoButton(
              padding: EdgeInsets.zero,
              minimumSize: const Size(30, 30),
              onPressed: _showMore,
              child: const Icon(CupertinoIcons.ellipsis),
            ),
          ],
        ),
        child: Column(
          children: [
            _buildTopSettings(),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: CupertinoSlidingSegmentedControl<int>(
                  groupValue: _tab,
                  children: const {
                    0: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Text('基础'),
                    ),
                    1: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Text('搜索'),
                    ),
                    2: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Text('发现'),
                    ),
                    3: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Text('详情'),
                    ),
                    4: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Text('目录'),
                    ),
                    5: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Text('正文'),
                    ),
                  },
                  onValueChanged: (value) {
                    if (value == null) return;
                    setState(() {
                      _tab = value;
                      _activeFieldKey = null;
                      _activeFieldController = null;
                    });
                  },
                ),
              ),
            ),
            Expanded(
              child: IndexedStack(
                index: _tab,
                children: [
                  _buildBaseTab(),
                  _buildSearchTab(),
                  _buildExploreTab(),
                  _buildInfoTab(),
                  _buildTocTab(),
                  _buildContentTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopSettings() {
    return Container(
      color: CupertinoColors.systemGroupedBackground.resolveFrom(context),
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            const Text('书源类型'),
            const SizedBox(width: 8),
            CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              color: CupertinoColors.systemGrey5.resolveFrom(context),
              borderRadius: BorderRadius.circular(14),
              onPressed: _pickBookSourceType,
              child: Text(_typeLabel(_bookSourceType)),
            ),
            const SizedBox(width: 8),
            _buildTopSwitchItem(
              text: '启用书源',
              value: _enabled,
              onChanged: (value) => setState(() => _enabled = value),
            ),
            const SizedBox(width: 8),
            _buildTopSwitchItem(
              text: '启用发现',
              value: _enabledExplore,
              onChanged: (value) => setState(() => _enabledExplore = value),
            ),
            const SizedBox(width: 8),
            _buildTopSwitchItem(
              text: '自动保存Cookie',
              value: _enabledCookieJar,
              onChanged: (value) => setState(() => _enabledCookieJar = value),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopSwitchItem({
    required String text,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: CupertinoColors.systemGrey6.resolveFrom(context),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Text(text),
          const SizedBox(width: 6),
          Transform.scale(
            scale: 0.82,
            child: CupertinoSwitch(
              value: value,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBaseTab() {
    return ListView(
      children: [
        CupertinoListSection.insetGrouped(
          header: const Text('基础信息'),
          children: [
            _buildTextFieldTile('bookSourceUrl', _bookSourceUrlCtrl),
            _buildTextFieldTile('bookSourceName', _bookSourceNameCtrl),
            _buildTextFieldTile('bookSourceGroup', _bookSourceGroupCtrl),
            _buildTextFieldTile('bookSourceComment', _bookSourceCommentCtrl,
                maxLines: 3),
            _buildTextFieldTile('loginUrl', _loginUrlCtrl),
            _buildTextFieldTile('loginUi', _loginUiCtrl, maxLines: 3),
            _buildTextFieldTile('loginCheckJs', _loginCheckJsCtrl, maxLines: 3),
            _buildTextFieldTile('coverDecodeJs', _coverDecodeJsCtrl,
                maxLines: 3),
            _buildTextFieldTile('bookUrlPattern', _bookUrlPatternCtrl),
            _buildTextFieldTile('header', _headerCtrl, maxLines: 3),
            _buildTextFieldTile('variableComment', _variableCommentCtrl,
                maxLines: 2),
            _buildTextFieldTile('concurrentRate', _concurrentRateCtrl),
            _buildTextFieldTile('jsLib', _jsLibCtrl, maxLines: 4),
          ],
        ),
      ],
    );
  }

  Widget _buildSearchTab() {
    return ListView(
      children: [
        CupertinoListSection.insetGrouped(
          header: const Text('搜索规则'),
          children: [
            _buildTextFieldTile('searchUrl', _searchUrlCtrl),
            _buildTextFieldTile('checkKeyWord', _searchCheckKeyWordCtrl),
            _buildTextFieldTile('bookList', _searchBookListCtrl),
            _buildTextFieldTile('name', _searchNameCtrl),
            _buildTextFieldTile('author', _searchAuthorCtrl),
            _buildTextFieldTile('kind', _searchKindCtrl),
            _buildTextFieldTile('wordCount', _searchWordCountCtrl),
            _buildTextFieldTile('lastChapter', _searchLastChapterCtrl),
            _buildTextFieldTile('intro', _searchIntroCtrl),
            _buildTextFieldTile('coverUrl', _searchCoverUrlCtrl),
            _buildTextFieldTile('bookUrl', _searchBookUrlCtrl),
          ],
        ),
      ],
    );
  }

  Widget _buildExploreTab() {
    return ListView(
      children: [
        CupertinoListSection.insetGrouped(
          header: const Text('发现规则'),
          children: [
            _buildTextFieldTile('exploreUrl', _exploreUrlCtrl),
            _buildTextFieldTile('bookList', _exploreBookListCtrl),
            _buildTextFieldTile('name', _exploreNameCtrl),
            _buildTextFieldTile('author', _exploreAuthorCtrl),
            _buildTextFieldTile('kind', _exploreKindCtrl),
            _buildTextFieldTile('wordCount', _exploreWordCountCtrl),
            _buildTextFieldTile('lastChapter', _exploreLastChapterCtrl),
            _buildTextFieldTile('intro', _exploreIntroCtrl),
            _buildTextFieldTile('coverUrl', _exploreCoverUrlCtrl),
            _buildTextFieldTile('bookUrl', _exploreBookUrlCtrl),
          ],
        ),
      ],
    );
  }

  Widget _buildInfoTab() {
    return ListView(
      children: [
        CupertinoListSection.insetGrouped(
          header: const Text('详情规则'),
          children: [
            _buildTextFieldTile('init', _infoInitCtrl),
            _buildTextFieldTile('name', _infoNameCtrl),
            _buildTextFieldTile('author', _infoAuthorCtrl),
            _buildTextFieldTile('kind', _infoKindCtrl),
            _buildTextFieldTile('wordCount', _infoWordCountCtrl),
            _buildTextFieldTile('lastChapter', _infoLastChapterCtrl),
            _buildTextFieldTile('intro', _infoIntroCtrl),
            _buildTextFieldTile('coverUrl', _infoCoverUrlCtrl),
            _buildTextFieldTile('tocUrl', _infoTocUrlCtrl),
            _buildTextFieldTile('canReName', _infoCanRenameCtrl),
            _buildTextFieldTile('downloadUrls', _infoDownloadUrlsCtrl),
          ],
        ),
      ],
    );
  }

  Widget _buildTocTab() {
    return ListView(
      children: [
        CupertinoListSection.insetGrouped(
          header: const Text('目录规则'),
          children: [
            _buildTextFieldTile('preUpdateJs', _tocPreUpdateJsCtrl,
                maxLines: 3),
            _buildTextFieldTile('chapterList', _tocChapterListCtrl),
            _buildTextFieldTile('chapterName', _tocChapterNameCtrl),
            _buildTextFieldTile('chapterUrl', _tocChapterUrlCtrl),
            _buildTextFieldTile('formatJs', _tocFormatJsCtrl, maxLines: 3),
            _buildTextFieldTile('isVolume', _tocIsVolumeCtrl),
            _buildTextFieldTile('updateTime', _tocUpdateTimeCtrl),
            _buildTextFieldTile('isVip', _tocIsVipCtrl),
            _buildTextFieldTile('isPay', _tocIsPayCtrl),
            _buildTextFieldTile('nextTocUrl', _tocNextTocUrlCtrl),
          ],
        ),
      ],
    );
  }

  Widget _buildContentTab() {
    return ListView(
      children: [
        CupertinoListSection.insetGrouped(
          header: const Text('正文规则'),
          children: [
            _buildTextFieldTile('content', _contentContentCtrl, maxLines: 4),
            _buildTextFieldTile('title', _contentTitleCtrl),
            _buildTextFieldTile('nextContentUrl', _contentNextContentUrlCtrl),
            _buildTextFieldTile('webJs', _contentWebJsCtrl, maxLines: 3),
            _buildTextFieldTile('sourceRegex', _contentSourceRegexCtrl,
                maxLines: 3),
            _buildTextFieldTile('replaceRegex', _contentReplaceRegexCtrl,
                maxLines: 3),
            _buildTextFieldTile('imageStyle', _contentImageStyleCtrl,
                maxLines: 3),
            _buildTextFieldTile('imageDecode', _contentImageDecodeCtrl,
                maxLines: 3),
            _buildTextFieldTile('payAction', _contentPayActionCtrl,
                maxLines: 3),
          ],
        ),
      ],
    );
  }

  CupertinoListTile _buildTextFieldTile(
    String key,
    TextEditingController controller, {
    int maxLines = 1,
  }) {
    final isActiveField = identical(_activeFieldController, controller);
    return CupertinoListTile.notched(
      title: Text(_labelForField(key)),
      subtitle: CupertinoTextField(
        controller: controller,
        maxLines: maxLines,
        onTap: () => _markActiveField(key, controller),
        onChanged: (_) => _markActiveField(key, controller),
      ),
      trailing: isActiveField
          ? CupertinoButton(
              padding: EdgeInsets.zero,
              minimumSize: const Size(28, 28),
              onPressed: () {
                _markActiveField(key, controller);
                _showInsertActions();
              },
              child: const Icon(CupertinoIcons.wand_stars, size: 18),
            )
          : null,
    );
  }

  String _labelForField(String key) {
    return _fieldLabels[key] ?? key;
  }

  void _markActiveField(String key, TextEditingController controller) {
    if (identical(_activeFieldController, controller) &&
        _activeFieldKey == key) {
      return;
    }
    if (!mounted) {
      _activeFieldKey = key;
      _activeFieldController = controller;
      return;
    }
    setState(() {
      _activeFieldKey = key;
      _activeFieldController = controller;
    });
  }

  Future<void> _pickBookSourceType() async {
    final selected = await showCupertinoModalPopup<int>(
      context: context,
      builder: (popupContext) => CupertinoActionSheet(
        title: const Text('书源类型'),
        actions: [
          for (final entry in const <MapEntry<int, String>>[
            MapEntry(0, '默认'),
            MapEntry(1, '音频'),
            MapEntry(2, '图片'),
            MapEntry(3, '文件'),
          ])
            CupertinoActionSheetAction(
              onPressed: () => Navigator.pop(popupContext, entry.key),
              child: Text(entry.value),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(popupContext),
          child: const Text('取消'),
        ),
      ),
    );

    if (selected == null || !mounted) return;
    setState(() => _bookSourceType = selected);
  }

  Future<void> _showMore() async {
    if (!mounted) return;

    await showCupertinoModalPopup<void>(
      context: context,
      builder: (popupContext) => CupertinoActionSheet(
        title: const Text('更多'),
        actions: [
          if (_loginUrlCtrl.text.trim().isNotEmpty)
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(popupContext);
                _saveAndOpenLogin();
              },
              child: const Text('登录'),
            ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(popupContext);
              _saveAndSearch();
            },
            child: const Text('搜索'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(popupContext);
              _clearCookie();
            },
            child: const Text('清 Cookie'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(popupContext);
              setState(() => _autoComplete = !_autoComplete);
              _showMessage('自动补全已${_autoComplete ? '开启' : '关闭'}');
            },
            child: Text('自动补全 ${_autoComplete ? '✓' : ''}'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(popupContext);
              _copySourceJson();
            },
            child: const Text('复制书源'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(popupContext);
              _pasteSourceJson();
            },
            child: const Text('粘贴书源'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(popupContext);
              _setSourceVariable();
            },
            child: const Text('设置源变量'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(popupContext);
              _importFromQrCode();
            },
            child: const Text('扫码导入'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(popupContext);
              _shareSourceJsonQrFallback();
            },
            child: const Text('分享二维码'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(popupContext);
              _shareSourceJsonText();
            },
            child: const Text('分享文本'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(popupContext);
              _showMessage(SourceHelpTexts.ruleHelp);
            },
            child: const Text('帮助'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(popupContext),
          child: const Text('取消'),
        ),
      ),
    );
  }

  Future<void> _maybeShowRuleHelp() async {
    final prefs = await SharedPreferences.getInstance();
    final shown = prefs.getBool(_prefRuleHelpShown) ?? false;
    if (shown) return;
    await prefs.setBool(_prefRuleHelpShown, true);
    if (!mounted) return;
    _showMessage(SourceHelpTexts.ruleHelp);
  }

  Future<void> _showInsertActions() async {
    final fieldKey = _activeFieldKey;
    final onGroupField = fieldKey == 'bookSourceGroup';
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (popupContext) => CupertinoActionSheet(
        title: const Text('编辑工具'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(popupContext);
              _insertUrlOption();
            },
            child: const Text('插入URL参数'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(popupContext);
              _showMessage(SourceHelpTexts.ruleHelp);
            },
            child: const Text('书源教程'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(popupContext);
              _showMessage(SourceHelpTexts.jsHelp);
            },
            child: const Text('js教程'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(popupContext);
              _showMessage(SourceHelpTexts.regexHelp);
            },
            child: const Text('正则教程'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(popupContext);
              if (onGroupField) {
                _insertGroup();
              } else {
                _insertFilePath();
              }
            },
            child: Text(onGroupField ? '插入分组' : '选择文件'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(popupContext),
          child: const Text('取消'),
        ),
      ),
    );
  }

  Future<void> _insertUrlOption() async {
    if (!_ensureActiveFieldSelected()) return;
    final methodCtrl = TextEditingController();
    final charsetCtrl = TextEditingController();
    final headersCtrl = TextEditingController();
    final bodyCtrl = TextEditingController();
    final typeCtrl = TextEditingController();
    final retryCtrl = TextEditingController();
    final webJsCtrl = TextEditingController();
    final jsCtrl = TextEditingController();
    var useWebView = false;

    final text = await showCupertinoModalPopup<String>(
      context: context,
      builder: (popupContext) {
        return StatefulBuilder(
          builder: (context, setPopupState) {
            return CupertinoPopupSurface(
              child: SafeArea(
                top: false,
                child: SizedBox(
                  height: MediaQuery.of(context).size.height * 0.72,
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                        child: Row(
                          children: [
                            CupertinoButton(
                              padding: EdgeInsets.zero,
                              onPressed: () => Navigator.pop(popupContext),
                              child: const Text('取消'),
                            ),
                            const Expanded(
                              child: Center(
                                child: Text(
                                  'URL参数',
                                  style: TextStyle(fontSize: 16),
                                ),
                              ),
                            ),
                            CupertinoButton(
                              padding: EdgeInsets.zero,
                              onPressed: () {
                                final option = <String, dynamic>{};
                                void setText(String key, String value) {
                                  final v = value.trim();
                                  if (v.isNotEmpty) {
                                    option[key] = v;
                                  }
                                }

                                if (useWebView) {
                                  option['useWebView'] = true;
                                }
                                setText('method', methodCtrl.text);
                                setText('charset', charsetCtrl.text);
                                setText('headers', headersCtrl.text);
                                setText('body', bodyCtrl.text);
                                setText('type', typeCtrl.text);
                                setText('retry', retryCtrl.text);
                                setText('webJs', webJsCtrl.text);
                                setText('js', jsCtrl.text);

                                Navigator.pop(popupContext, jsonEncode(option));
                              },
                              child: const Text('插入'),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        height: 1,
                        color: CupertinoColors.separator.resolveFrom(context),
                      ),
                      Expanded(
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                          children: [
                            Row(
                              children: [
                                const Expanded(child: Text('useWebView')),
                                CupertinoSwitch(
                                  value: useWebView,
                                  onChanged: (value) {
                                    setPopupState(() => useWebView = value);
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            _buildUrlOptionField(
                              controller: methodCtrl,
                              placeholder: 'method',
                            ),
                            _buildUrlOptionField(
                              controller: charsetCtrl,
                              placeholder: 'charset',
                            ),
                            _buildUrlOptionField(
                              controller: headersCtrl,
                              placeholder: 'headers',
                            ),
                            _buildUrlOptionField(
                              controller: bodyCtrl,
                              placeholder: 'body',
                            ),
                            _buildUrlOptionField(
                              controller: typeCtrl,
                              placeholder: 'type',
                            ),
                            _buildUrlOptionField(
                              controller: retryCtrl,
                              placeholder: 'retry',
                              keyboardType: TextInputType.number,
                            ),
                            _buildUrlOptionField(
                              controller: webJsCtrl,
                              placeholder: 'webJs',
                              maxLines: 3,
                            ),
                            _buildUrlOptionField(
                              controller: jsCtrl,
                              placeholder: 'js',
                              maxLines: 3,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    methodCtrl.dispose();
    charsetCtrl.dispose();
    headersCtrl.dispose();
    bodyCtrl.dispose();
    typeCtrl.dispose();
    retryCtrl.dispose();
    webJsCtrl.dispose();
    jsCtrl.dispose();

    if (text == null || text.trim().isEmpty) return;
    _insertTextToActiveField(text.trim());
  }

  Widget _buildUrlOptionField({
    required TextEditingController controller,
    required String placeholder,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: CupertinoTextField(
        controller: controller,
        placeholder: placeholder,
        keyboardType: keyboardType,
        maxLines: maxLines,
      ),
    );
  }

  Future<void> _insertGroup() async {
    if (!_ensureActiveFieldSelected()) return;
    final groups = _collectAllGroups();
    if (groups.isEmpty) {
      _showMessage('暂无可选分组');
      return;
    }

    final selected = await showCupertinoModalPopup<String>(
      context: context,
      builder: (popupContext) => CupertinoActionSheet(
        title: const Text('选择分组'),
        actions: [
          for (final group in groups)
            CupertinoActionSheetAction(
              onPressed: () => Navigator.pop(popupContext, group),
              child: Text(group),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(popupContext),
          child: const Text('取消'),
        ),
      ),
    );
    if (selected == null || selected.trim().isEmpty) return;
    _insertTextToActiveField(selected);
  }

  Future<void> _insertFilePath() async {
    if (!_ensureActiveFieldSelected()) return;
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      withData: false,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    final path = (file.path ?? file.name).trim();
    if (path.isEmpty) {
      _showMessage('未获取到文件路径');
      return;
    }
    _insertTextToActiveField(path);
  }

  List<String> _collectAllGroups() {
    final rawGroups = _repo
        .getAllSources()
        .map((source) => source.bookSourceGroup?.trim() ?? '')
        .where((raw) => raw.isNotEmpty);
    return SearchScopeGroupHelper.dealGroups(rawGroups);
  }

  bool _ensureActiveFieldSelected() {
    if (_activeFieldController != null) return true;
    _showMessage('请先选中输入框');
    return false;
  }

  void _insertTextToActiveField(String text) {
    final controller = _activeFieldController;
    if (controller == null) {
      _showMessage('请先选中输入框');
      return;
    }
    final value = controller.value;
    final start = value.selection.start;
    final end = value.selection.end;
    final hasSelection = start >= 0 && end >= 0;
    final replaceStart =
        hasSelection ? (start < end ? start : end) : value.text.length;
    final replaceEnd =
        hasSelection ? (start < end ? end : start) : value.text.length;
    final nextText = value.text.replaceRange(replaceStart, replaceEnd, text);
    controller.value = TextEditingValue(
      text: nextText,
      selection: TextSelection.collapsed(offset: replaceStart + text.length),
    );
  }

  Future<void> _copySourceJson() async {
    final source = _buildSourceFromFields();
    final text = LegadoJson.encode(source.toJson());
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    _showMessage('已复制书源 JSON');
  }

  Future<void> _shareSourceJsonText() async {
    final source = _buildSourceFromFields();
    final text = LegadoJson.encode(source.toJson());
    await SharePlus.instance.share(
      ShareParams(
        text: text,
        subject: source.bookSourceName.trim().isEmpty
            ? 'SoupReader 书源'
            : source.bookSourceName.trim(),
      ),
    );
    if (!mounted) return;
    _showMessage('已打开系统分享');
  }

  Future<void> _shareSourceJsonQrFallback() async {
    final source = _buildSourceFromFields();
    final text = LegadoJson.encode(source.toJson());
    if (!mounted) return;
    await Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (_) => SourceQrShareView(
          text: text,
          subject: source.bookSourceName.trim().isEmpty
              ? '书源二维码'
              : source.bookSourceName.trim(),
        ),
      ),
    );
  }

  Future<void> _pasteSourceJson() async {
    final data = await Clipboard.getData('text/plain');
    final text = data?.text?.trim();
    if (text == null || text.isEmpty) {
      _showMessage('剪贴板为空');
      return;
    }

    final result = await _importExportService.importFromText(text);
    if (!result.success || result.sources.isEmpty) {
      _showMessage(result.errorMessage ?? '粘贴失败：未识别到有效书源');
      return;
    }

    final source = result.sources.first;
    _loadSourceToFields(source);
    _savedSource = source;
    _currentOriginalUrl = source.bookSourceUrl.trim().isEmpty
        ? null
        : source.bookSourceUrl.trim();
    _savedSnapshot = _snapshotFor(source);
    if (!mounted) return;
    _showMessage('已粘贴并载入书源');
  }

  Future<void> _importFromQrCode() async {
    final text = await QrScanService.scanText(context, title: '扫码导入书源');
    final value = text?.trim();
    if (value == null || value.isEmpty) {
      return;
    }
    final result = await _importExportService.importFromText(value);
    if (!result.success || result.sources.isEmpty) {
      _showMessage(result.errorMessage ?? '扫码内容无法识别');
      return;
    }

    final source = result.sources.first;
    _loadSourceToFields(source);
    _savedSource = source;
    _currentOriginalUrl = source.bookSourceUrl.trim().isEmpty
        ? null
        : source.bookSourceUrl.trim();
    _savedSnapshot = _snapshotFor(source);
    if (!mounted) return;
    _showMessage('已从扫码内容载入书源');
  }

  Future<void> _saveAndOpenDebug() async {
    final saved = await _saveInternal(showSuccessMessage: false);
    if (saved == null || !mounted) return;

    await Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (_) => SourceDebugLegacyView(
          source: saved,
        ),
      ),
    );
  }

  Future<void> _saveAndOpenLogin() async {
    final saved = await _saveInternal(showSuccessMessage: false);
    if (saved == null || !mounted) return;

    if (SourceLoginUiHelper.hasLoginUi(saved.loginUi)) {
      await Navigator.of(context).push(
        CupertinoPageRoute<void>(
          builder: (_) => SourceLoginFormView(source: saved),
        ),
      );
      return;
    }

    final resolvedUrl = SourceLoginUrlResolver.resolve(
      baseUrl: saved.bookSourceUrl,
      loginUrl: saved.loginUrl ?? '',
    );
    if (resolvedUrl.isEmpty) {
      _showMessage('当前书源未配置登录地址');
      return;
    }
    final uri = Uri.tryParse(resolvedUrl);
    final scheme = uri?.scheme.toLowerCase();
    if (scheme != 'http' && scheme != 'https') {
      _showMessage('登录地址不是有效网页地址');
      return;
    }

    await Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (_) => SourceWebVerifyView(initialUrl: resolvedUrl),
      ),
    );
  }

  Future<void> _saveAndSearch() async {
    final saved = await _saveInternal(showSuccessMessage: false);
    if (saved == null || !mounted) return;

    await Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (_) => SearchView.scoped(
          sourceUrls: <String>[saved.bookSourceUrl],
        ),
      ),
    );
  }

  Future<void> _setSourceVariable() async {
    final saved = await _saveInternal(showSuccessMessage: false);
    if (saved == null) return;

    final sourceKey = saved.bookSourceUrl.trim();
    if (sourceKey.isEmpty) {
      _showMessage('请先填写 bookSourceUrl');
      return;
    }

    final note = _displayVariableComment(saved);
    final current = await SourceVariableStore.getVariable(sourceKey) ?? '';
    if (!mounted) return;

    final controller = TextEditingController(text: current);
    final result = await showCupertinoDialog<String>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: const Text('设置源变量'),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Column(
            children: [
              Text(
                note,
                style: TextStyle(
                  fontSize: 12,
                  color: CupertinoColors.secondaryLabel.resolveFrom(context),
                ),
              ),
              const SizedBox(height: 10),
              CupertinoTextField(
                controller: controller,
                maxLines: 8,
                placeholder: '输入变量 JSON 或文本',
              ),
            ],
          ),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result == null) return;

    await SourceVariableStore.putVariable(sourceKey, result);
    if (!mounted) return;
    _showMessage('源变量已保存');
  }

  Future<void> _clearCookie() async {
    final url = _bookSourceUrlCtrl.text.trim();
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
    try {
      for (final uri in allCandidates) {
        try {
          await CookieStore.jar.delete(uri, true);
          cleared += 1;
        } catch (e) {
          lastError = e;
        }
      }
    } catch (e) {
      lastError = e;
    }

    if (cleared > 0) {
      _showMessage('已清理该书源 Cookie');
      return;
    }
    if (lastError != null) {
      _showMessage('清理 Cookie 失败：$lastError');
      return;
    }
    _showMessage('未找到可清理的 Cookie');
  }

  Future<void> _save() async {
    final saved = await _saveInternal(showSuccessMessage: false);
    if (saved == null || !mounted) return;
    Navigator.of(context).pop(saved.bookSourceUrl);
  }

  Future<BookSource?> _saveInternal({bool showSuccessMessage = true}) async {
    final source = _buildSourceFromFields();
    try {
      final saved = await _saveService.save(
        source: source,
        originalSource: _savedSource,
      );
      _savedSource = saved;
      _currentOriginalUrl = saved.bookSourceUrl;
      _savedSnapshot = _snapshotFor(saved);
      if (showSuccessMessage && mounted) {
        _showMessage('保存成功');
      }
      return saved;
    } catch (e) {
      if (mounted) {
        _showMessage('保存失败：$e');
      }
      return null;
    }
  }

  Future<bool> _confirmExitIfDirty() async {
    final dirty = _snapshotFor(_buildSourceFromFields()) != _savedSnapshot;
    if (!dirty) return true;

    final result = await showCupertinoDialog<bool>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: const Text('退出'),
        content: const Text('\n存在未保存修改，确认退出吗？'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('继续编辑'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('放弃修改'),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  BookSource _buildSourceFromFields() {
    final base = _savedSource ??
        const BookSource(
          bookSourceUrl: '',
          bookSourceName: '',
        );

    final searchBookList = _textOrNull(_searchBookListCtrl);
    final exploreBookList = _textOrNull(_exploreBookListCtrl);
    final infoInit = _textOrNull(_infoInitCtrl);
    final tocChapterList = _textOrNull(_tocChapterListCtrl);

    final searchRule = SearchRule(
      checkKeyWord: _textOrNull(_searchCheckKeyWordCtrl),
      bookList: searchBookList,
      name: _ruleComplete(_searchNameCtrl, preRule: searchBookList),
      author: _ruleComplete(_searchAuthorCtrl, preRule: searchBookList),
      kind: _ruleComplete(_searchKindCtrl, preRule: searchBookList),
      wordCount: _ruleComplete(_searchWordCountCtrl, preRule: searchBookList),
      lastChapter:
          _ruleComplete(_searchLastChapterCtrl, preRule: searchBookList),
      intro: _ruleComplete(_searchIntroCtrl, preRule: searchBookList),
      coverUrl:
          _ruleComplete(_searchCoverUrlCtrl, preRule: searchBookList, type: 3),
      bookUrl:
          _ruleComplete(_searchBookUrlCtrl, preRule: searchBookList, type: 2),
    );

    final exploreRule = ExploreRule(
      bookList: exploreBookList,
      name: _ruleComplete(_exploreNameCtrl, preRule: exploreBookList),
      author: _ruleComplete(_exploreAuthorCtrl, preRule: exploreBookList),
      kind: _ruleComplete(_exploreKindCtrl, preRule: exploreBookList),
      wordCount: _ruleComplete(_exploreWordCountCtrl, preRule: exploreBookList),
      lastChapter:
          _ruleComplete(_exploreLastChapterCtrl, preRule: exploreBookList),
      intro: _ruleComplete(_exploreIntroCtrl, preRule: exploreBookList),
      coverUrl: _ruleComplete(
        _exploreCoverUrlCtrl,
        preRule: exploreBookList,
        type: 3,
      ),
      bookUrl: _ruleComplete(
        _exploreBookUrlCtrl,
        preRule: exploreBookList,
        type: 2,
      ),
    );

    final infoRule = BookInfoRule(
      init: infoInit,
      name: _ruleComplete(_infoNameCtrl, preRule: infoInit),
      author: _ruleComplete(_infoAuthorCtrl, preRule: infoInit),
      kind: _ruleComplete(_infoKindCtrl, preRule: infoInit),
      wordCount: _ruleComplete(_infoWordCountCtrl, preRule: infoInit),
      lastChapter: _ruleComplete(_infoLastChapterCtrl, preRule: infoInit),
      intro: _ruleComplete(_infoIntroCtrl, preRule: infoInit),
      coverUrl: _ruleComplete(_infoCoverUrlCtrl, preRule: infoInit, type: 3),
      tocUrl: _ruleComplete(_infoTocUrlCtrl, preRule: infoInit, type: 2),
      canReName: _textOrNull(_infoCanRenameCtrl),
      downloadUrls: _ruleComplete(_infoDownloadUrlsCtrl, preRule: infoInit),
    );

    final tocRule = TocRule(
      preUpdateJs: _textOrNull(_tocPreUpdateJsCtrl),
      chapterList: tocChapterList,
      chapterName: _ruleComplete(_tocChapterNameCtrl, preRule: tocChapterList),
      chapterUrl:
          _ruleComplete(_tocChapterUrlCtrl, preRule: tocChapterList, type: 2),
      formatJs: _textOrNull(_tocFormatJsCtrl),
      isVolume: _textOrNull(_tocIsVolumeCtrl),
      updateTime: _textOrNull(_tocUpdateTimeCtrl),
      isVip: _textOrNull(_tocIsVipCtrl),
      isPay: _textOrNull(_tocIsPayCtrl),
      nextTocUrl: _ruleComplete(
        _tocNextTocUrlCtrl,
        preRule: tocChapterList,
        type: 2,
      ),
    );

    final contentRule = ContentRule(
      content: _ruleComplete(_contentContentCtrl),
      title: _ruleComplete(_contentTitleCtrl),
      nextContentUrl: _ruleComplete(_contentNextContentUrlCtrl, type: 2),
      webJs: _textOrNull(_contentWebJsCtrl),
      sourceRegex: _textOrNull(_contentSourceRegexCtrl),
      replaceRegex: _textOrNull(_contentReplaceRegexCtrl),
      imageStyle: _textOrNull(_contentImageStyleCtrl),
      imageDecode: _textOrNull(_contentImageDecodeCtrl),
      payAction: _textOrNull(_contentPayActionCtrl),
    );

    return base.copyWith(
      bookSourceUrl: _bookSourceUrlCtrl.text.trim(),
      bookSourceName: _bookSourceNameCtrl.text,
      bookSourceGroup: _textOrNull(_bookSourceGroupCtrl),
      bookSourceComment: _textOrNull(_bookSourceCommentCtrl),
      loginUrl: _textOrNull(_loginUrlCtrl),
      loginUi: _textOrNull(_loginUiCtrl),
      loginCheckJs: _textOrNull(_loginCheckJsCtrl),
      coverDecodeJs: _textOrNull(_coverDecodeJsCtrl),
      bookUrlPattern: _textOrNull(_bookUrlPatternCtrl),
      header: _textOrNull(_headerCtrl),
      variableComment: _textOrNull(_variableCommentCtrl),
      concurrentRate: _textOrNull(_concurrentRateCtrl),
      jsLib: _textOrNull(_jsLibCtrl),
      searchUrl: _textOrNull(_searchUrlCtrl),
      exploreUrl: _textOrNull(_exploreUrlCtrl),
      enabled: _enabled,
      enabledExplore: _enabledExplore,
      enabledCookieJar: _enabledCookieJar,
      bookSourceType: _bookSourceType,
      ruleSearch: searchRule,
      ruleExplore: exploreRule,
      ruleBookInfo: infoRule,
      ruleToc: tocRule,
      ruleContent: contentRule,
    );
  }

  String? _textOrNull(TextEditingController controller) {
    final value = controller.text;
    return value.trim().isEmpty ? null : value;
  }

  String? _ruleComplete(
    TextEditingController controller, {
    String? preRule,
    int type = 1,
  }) {
    final value = _textOrNull(controller);
    if (!_autoComplete) return value;
    return SourceRuleComplete.autoComplete(
      value,
      preRule: preRule,
      type: type,
    );
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

  BookSource _parseInitialSource() {
    final map = _tryDecodeJsonMap(widget.initialRawJson);
    if (map == null) {
      return const BookSource(bookSourceUrl: '', bookSourceName: '');
    }
    return BookSource.fromJson(map);
  }

  void _setupControllers(BookSource source) {
    _enabled = source.enabled;
    _enabledExplore = source.enabledExplore;
    _enabledCookieJar = source.enabledCookieJar ?? false;
    _bookSourceType = source.bookSourceType;

    _bookSourceUrlCtrl = TextEditingController(text: source.bookSourceUrl);
    _bookSourceNameCtrl = TextEditingController(text: source.bookSourceName);
    _bookSourceGroupCtrl = TextEditingController(text: source.bookSourceGroup);
    _bookSourceCommentCtrl =
        TextEditingController(text: source.bookSourceComment);
    _loginUrlCtrl = TextEditingController(text: source.loginUrl);
    _loginUiCtrl = TextEditingController(text: source.loginUi);
    _loginCheckJsCtrl = TextEditingController(text: source.loginCheckJs);
    _coverDecodeJsCtrl = TextEditingController(text: source.coverDecodeJs);
    _bookUrlPatternCtrl = TextEditingController(text: source.bookUrlPattern);
    _headerCtrl = TextEditingController(text: source.header);
    _variableCommentCtrl = TextEditingController(text: source.variableComment);
    _concurrentRateCtrl = TextEditingController(text: source.concurrentRate);
    _jsLibCtrl = TextEditingController(text: source.jsLib);

    _searchUrlCtrl = TextEditingController(text: source.searchUrl);
    _searchCheckKeyWordCtrl =
        TextEditingController(text: source.ruleSearch?.checkKeyWord);
    _searchBookListCtrl =
        TextEditingController(text: source.ruleSearch?.bookList);
    _searchNameCtrl = TextEditingController(text: source.ruleSearch?.name);
    _searchAuthorCtrl = TextEditingController(text: source.ruleSearch?.author);
    _searchKindCtrl = TextEditingController(text: source.ruleSearch?.kind);
    _searchWordCountCtrl =
        TextEditingController(text: source.ruleSearch?.wordCount);
    _searchLastChapterCtrl =
        TextEditingController(text: source.ruleSearch?.lastChapter);
    _searchIntroCtrl = TextEditingController(text: source.ruleSearch?.intro);
    _searchCoverUrlCtrl =
        TextEditingController(text: source.ruleSearch?.coverUrl);
    _searchBookUrlCtrl =
        TextEditingController(text: source.ruleSearch?.bookUrl);

    _exploreUrlCtrl = TextEditingController(text: source.exploreUrl);
    _exploreBookListCtrl =
        TextEditingController(text: source.ruleExplore?.bookList);
    _exploreNameCtrl = TextEditingController(text: source.ruleExplore?.name);
    _exploreAuthorCtrl =
        TextEditingController(text: source.ruleExplore?.author);
    _exploreKindCtrl = TextEditingController(text: source.ruleExplore?.kind);
    _exploreWordCountCtrl =
        TextEditingController(text: source.ruleExplore?.wordCount);
    _exploreLastChapterCtrl =
        TextEditingController(text: source.ruleExplore?.lastChapter);
    _exploreIntroCtrl = TextEditingController(text: source.ruleExplore?.intro);
    _exploreCoverUrlCtrl =
        TextEditingController(text: source.ruleExplore?.coverUrl);
    _exploreBookUrlCtrl =
        TextEditingController(text: source.ruleExplore?.bookUrl);

    _infoInitCtrl = TextEditingController(text: source.ruleBookInfo?.init);
    _infoNameCtrl = TextEditingController(text: source.ruleBookInfo?.name);
    _infoAuthorCtrl = TextEditingController(text: source.ruleBookInfo?.author);
    _infoKindCtrl = TextEditingController(text: source.ruleBookInfo?.kind);
    _infoWordCountCtrl =
        TextEditingController(text: source.ruleBookInfo?.wordCount);
    _infoLastChapterCtrl =
        TextEditingController(text: source.ruleBookInfo?.lastChapter);
    _infoIntroCtrl = TextEditingController(text: source.ruleBookInfo?.intro);
    _infoCoverUrlCtrl =
        TextEditingController(text: source.ruleBookInfo?.coverUrl);
    _infoTocUrlCtrl = TextEditingController(text: source.ruleBookInfo?.tocUrl);
    _infoCanRenameCtrl =
        TextEditingController(text: source.ruleBookInfo?.canReName);
    _infoDownloadUrlsCtrl =
        TextEditingController(text: source.ruleBookInfo?.downloadUrls);

    _tocPreUpdateJsCtrl =
        TextEditingController(text: source.ruleToc?.preUpdateJs);
    _tocChapterListCtrl =
        TextEditingController(text: source.ruleToc?.chapterList);
    _tocChapterNameCtrl =
        TextEditingController(text: source.ruleToc?.chapterName);
    _tocChapterUrlCtrl =
        TextEditingController(text: source.ruleToc?.chapterUrl);
    _tocFormatJsCtrl = TextEditingController(text: source.ruleToc?.formatJs);
    _tocIsVolumeCtrl = TextEditingController(text: source.ruleToc?.isVolume);
    _tocUpdateTimeCtrl =
        TextEditingController(text: source.ruleToc?.updateTime);
    _tocIsVipCtrl = TextEditingController(text: source.ruleToc?.isVip);
    _tocIsPayCtrl = TextEditingController(text: source.ruleToc?.isPay);
    _tocNextTocUrlCtrl =
        TextEditingController(text: source.ruleToc?.nextTocUrl);

    _contentContentCtrl =
        TextEditingController(text: source.ruleContent?.content);
    _contentTitleCtrl = TextEditingController(text: source.ruleContent?.title);
    _contentNextContentUrlCtrl =
        TextEditingController(text: source.ruleContent?.nextContentUrl);
    _contentWebJsCtrl = TextEditingController(text: source.ruleContent?.webJs);
    _contentSourceRegexCtrl =
        TextEditingController(text: source.ruleContent?.sourceRegex);
    _contentReplaceRegexCtrl =
        TextEditingController(text: source.ruleContent?.replaceRegex);
    _contentImageStyleCtrl =
        TextEditingController(text: source.ruleContent?.imageStyle);
    _contentImageDecodeCtrl =
        TextEditingController(text: source.ruleContent?.imageDecode);
    _contentPayActionCtrl =
        TextEditingController(text: source.ruleContent?.payAction);
  }

  void _loadSourceToFields(BookSource source) {
    setState(() {
      _enabled = source.enabled;
      _enabledExplore = source.enabledExplore;
      _enabledCookieJar = source.enabledCookieJar ?? false;
      _bookSourceType = source.bookSourceType;

      _bookSourceUrlCtrl.text = source.bookSourceUrl;
      _bookSourceNameCtrl.text = source.bookSourceName;
      _bookSourceGroupCtrl.text = source.bookSourceGroup ?? '';
      _bookSourceCommentCtrl.text = source.bookSourceComment ?? '';
      _loginUrlCtrl.text = source.loginUrl ?? '';
      _loginUiCtrl.text = source.loginUi ?? '';
      _loginCheckJsCtrl.text = source.loginCheckJs ?? '';
      _coverDecodeJsCtrl.text = source.coverDecodeJs ?? '';
      _bookUrlPatternCtrl.text = source.bookUrlPattern ?? '';
      _headerCtrl.text = source.header ?? '';
      _variableCommentCtrl.text = source.variableComment ?? '';
      _concurrentRateCtrl.text = source.concurrentRate ?? '';
      _jsLibCtrl.text = source.jsLib ?? '';

      _searchUrlCtrl.text = source.searchUrl ?? '';
      _searchCheckKeyWordCtrl.text = source.ruleSearch?.checkKeyWord ?? '';
      _searchBookListCtrl.text = source.ruleSearch?.bookList ?? '';
      _searchNameCtrl.text = source.ruleSearch?.name ?? '';
      _searchAuthorCtrl.text = source.ruleSearch?.author ?? '';
      _searchKindCtrl.text = source.ruleSearch?.kind ?? '';
      _searchWordCountCtrl.text = source.ruleSearch?.wordCount ?? '';
      _searchLastChapterCtrl.text = source.ruleSearch?.lastChapter ?? '';
      _searchIntroCtrl.text = source.ruleSearch?.intro ?? '';
      _searchCoverUrlCtrl.text = source.ruleSearch?.coverUrl ?? '';
      _searchBookUrlCtrl.text = source.ruleSearch?.bookUrl ?? '';

      _exploreUrlCtrl.text = source.exploreUrl ?? '';
      _exploreBookListCtrl.text = source.ruleExplore?.bookList ?? '';
      _exploreNameCtrl.text = source.ruleExplore?.name ?? '';
      _exploreAuthorCtrl.text = source.ruleExplore?.author ?? '';
      _exploreKindCtrl.text = source.ruleExplore?.kind ?? '';
      _exploreWordCountCtrl.text = source.ruleExplore?.wordCount ?? '';
      _exploreLastChapterCtrl.text = source.ruleExplore?.lastChapter ?? '';
      _exploreIntroCtrl.text = source.ruleExplore?.intro ?? '';
      _exploreCoverUrlCtrl.text = source.ruleExplore?.coverUrl ?? '';
      _exploreBookUrlCtrl.text = source.ruleExplore?.bookUrl ?? '';

      _infoInitCtrl.text = source.ruleBookInfo?.init ?? '';
      _infoNameCtrl.text = source.ruleBookInfo?.name ?? '';
      _infoAuthorCtrl.text = source.ruleBookInfo?.author ?? '';
      _infoKindCtrl.text = source.ruleBookInfo?.kind ?? '';
      _infoWordCountCtrl.text = source.ruleBookInfo?.wordCount ?? '';
      _infoLastChapterCtrl.text = source.ruleBookInfo?.lastChapter ?? '';
      _infoIntroCtrl.text = source.ruleBookInfo?.intro ?? '';
      _infoCoverUrlCtrl.text = source.ruleBookInfo?.coverUrl ?? '';
      _infoTocUrlCtrl.text = source.ruleBookInfo?.tocUrl ?? '';
      _infoCanRenameCtrl.text = source.ruleBookInfo?.canReName ?? '';
      _infoDownloadUrlsCtrl.text = source.ruleBookInfo?.downloadUrls ?? '';

      _tocPreUpdateJsCtrl.text = source.ruleToc?.preUpdateJs ?? '';
      _tocChapterListCtrl.text = source.ruleToc?.chapterList ?? '';
      _tocChapterNameCtrl.text = source.ruleToc?.chapterName ?? '';
      _tocChapterUrlCtrl.text = source.ruleToc?.chapterUrl ?? '';
      _tocFormatJsCtrl.text = source.ruleToc?.formatJs ?? '';
      _tocIsVolumeCtrl.text = source.ruleToc?.isVolume ?? '';
      _tocUpdateTimeCtrl.text = source.ruleToc?.updateTime ?? '';
      _tocIsVipCtrl.text = source.ruleToc?.isVip ?? '';
      _tocIsPayCtrl.text = source.ruleToc?.isPay ?? '';
      _tocNextTocUrlCtrl.text = source.ruleToc?.nextTocUrl ?? '';

      _contentContentCtrl.text = source.ruleContent?.content ?? '';
      _contentTitleCtrl.text = source.ruleContent?.title ?? '';
      _contentNextContentUrlCtrl.text =
          source.ruleContent?.nextContentUrl ?? '';
      _contentWebJsCtrl.text = source.ruleContent?.webJs ?? '';
      _contentSourceRegexCtrl.text = source.ruleContent?.sourceRegex ?? '';
      _contentReplaceRegexCtrl.text = source.ruleContent?.replaceRegex ?? '';
      _contentImageStyleCtrl.text = source.ruleContent?.imageStyle ?? '';
      _contentImageDecodeCtrl.text = source.ruleContent?.imageDecode ?? '';
      _contentPayActionCtrl.text = source.ruleContent?.payAction ?? '';
    });
  }

  String _snapshotFor(BookSource source) {
    return LegadoJson.encode(source.toJson());
  }

  String _displayVariableComment(BookSource source) {
    const defaultComment = '源变量可在js中通过source.getVariable()获取';
    final custom = (source.variableComment ?? '').trim();
    if (custom.isEmpty) return defaultComment;
    return '$custom\n$defaultComment';
  }

  String _typeLabel(int type) {
    switch (type) {
      case 1:
        return '音频';
      case 2:
        return '图片';
      case 3:
        return '文件';
      default:
        return '默认';
    }
  }

  void _showMessage(String message) {
    showCupertinoDialog(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: const Text('提示'),
        content: Text('\n$message'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('好'),
          ),
        ],
      ),
    );
  }
}
