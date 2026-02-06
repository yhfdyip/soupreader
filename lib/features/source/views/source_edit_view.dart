import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../../../core/database/database_service.dart';
import '../../../core/database/entities/book_entity.dart';
import '../../../core/database/repositories/source_repository.dart';
import '../../../core/utils/legado_json.dart';
import '../models/book_source.dart';
import '../services/rule_parser_engine.dart';

class SourceEditView extends StatefulWidget {
  final String? originalUrl;
  final String initialRawJson;

  const SourceEditView({
    super.key,
    required this.initialRawJson,
    this.originalUrl,
  });

  static SourceEditView fromEntity(BookSourceEntity entity) {
    final raw = (entity.rawJson != null && entity.rawJson!.trim().isNotEmpty)
        ? entity.rawJson!
        : LegadoJson.encode({
            'bookSourceUrl': entity.bookSourceUrl,
            'bookSourceName': entity.bookSourceName,
            'bookSourceGroup': entity.bookSourceGroup,
            'enabled': entity.enabled,
            'weight': entity.weight,
            'header': entity.header,
            'loginUrl': entity.loginUrl,
          });
    return SourceEditView(originalUrl: entity.bookSourceUrl, initialRawJson: raw);
  }

  @override
  State<SourceEditView> createState() => _SourceEditViewState();
}

class _SourceEditViewState extends State<SourceEditView> {
  late final DatabaseService _db;
  late final SourceRepository _repo;
  final RuleParserEngine _engine = RuleParserEngine();

  int _tab = 0; // 0 基础 1 规则 2 JSON 3 调试

  late final TextEditingController _nameCtrl;
  late final TextEditingController _urlCtrl;
  late final TextEditingController _groupCtrl;
  late final TextEditingController _weightCtrl;
  late final TextEditingController _headerCtrl;
  late final TextEditingController _searchUrlCtrl;
  late final TextEditingController _exploreUrlCtrl;

  // 规则（常用字段）
  late final TextEditingController _searchBookListCtrl;
  late final TextEditingController _searchNameCtrl;
  late final TextEditingController _searchAuthorCtrl;
  late final TextEditingController _searchBookUrlCtrl;
  late final TextEditingController _searchCoverUrlCtrl;
  late final TextEditingController _searchIntroCtrl;
  late final TextEditingController _searchLastChapterCtrl;

  late final TextEditingController _exploreBookListCtrl;
  late final TextEditingController _exploreNameCtrl;
  late final TextEditingController _exploreAuthorCtrl;
  late final TextEditingController _exploreBookUrlCtrl;
  late final TextEditingController _exploreCoverUrlCtrl;
  late final TextEditingController _exploreIntroCtrl;
  late final TextEditingController _exploreLastChapterCtrl;

  late final TextEditingController _infoInitCtrl;
  late final TextEditingController _infoNameCtrl;
  late final TextEditingController _infoAuthorCtrl;
  late final TextEditingController _infoIntroCtrl;
  late final TextEditingController _infoCoverUrlCtrl;
  late final TextEditingController _infoTocUrlCtrl;
  late final TextEditingController _infoLastChapterCtrl;

  late final TextEditingController _tocChapterListCtrl;
  late final TextEditingController _tocChapterNameCtrl;
  late final TextEditingController _tocChapterUrlCtrl;

  late final TextEditingController _contentContentCtrl;
  late final TextEditingController _contentTitleCtrl;
  late final TextEditingController _contentReplaceRegexCtrl;

  late final TextEditingController _jsonCtrl;
  String? _jsonError;

  bool _enabled = true;
  bool _enabledExplore = true;

  // 调试
  final TextEditingController _debugKeyCtrl = TextEditingController();
  final TextEditingController _debugExploreUrlCtrl = TextEditingController();
  bool _debugLoading = false;
  String? _debugError;
  List<SearchResult> _debugResults = const [];
  SearchResult? _selectedResult;
  BookDetail? _selectedDetail;
  List<TocItem> _selectedToc = const [];
  String? _selectedContent;

  @override
  void initState() {
    super.initState();
    _db = DatabaseService();
    _repo = SourceRepository(_db);

    _jsonCtrl = TextEditingController(text: _prettyJson(widget.initialRawJson));
    final initialMap = _tryDecodeJsonMap(_jsonCtrl.text);
    final source = initialMap != null ? BookSource.fromJson(initialMap) : null;

    _nameCtrl = TextEditingController(text: source?.bookSourceName ?? '');
    _urlCtrl = TextEditingController(text: source?.bookSourceUrl ?? '');
    _groupCtrl = TextEditingController(text: source?.bookSourceGroup ?? '');
    _weightCtrl = TextEditingController(text: (source?.weight ?? 0).toString());
    _headerCtrl = TextEditingController(text: source?.header ?? '');
    _searchUrlCtrl = TextEditingController(text: source?.searchUrl ?? '');
    _exploreUrlCtrl = TextEditingController(text: source?.exploreUrl ?? '');
    _enabled = source?.enabled ?? true;
    _enabledExplore = source?.enabledExplore ?? true;

    _searchBookListCtrl =
        TextEditingController(text: source?.ruleSearch?.bookList ?? '');
    _searchNameCtrl = TextEditingController(text: source?.ruleSearch?.name ?? '');
    _searchAuthorCtrl =
        TextEditingController(text: source?.ruleSearch?.author ?? '');
    _searchBookUrlCtrl =
        TextEditingController(text: source?.ruleSearch?.bookUrl ?? '');
    _searchCoverUrlCtrl =
        TextEditingController(text: source?.ruleSearch?.coverUrl ?? '');
    _searchIntroCtrl =
        TextEditingController(text: source?.ruleSearch?.intro ?? '');
    _searchLastChapterCtrl =
        TextEditingController(text: source?.ruleSearch?.lastChapter ?? '');

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
    _exploreLastChapterCtrl =
        TextEditingController(text: source?.ruleExplore?.lastChapter ?? '');

    _infoInitCtrl =
        TextEditingController(text: source?.ruleBookInfo?.init ?? '');
    _infoNameCtrl = TextEditingController(text: source?.ruleBookInfo?.name ?? '');
    _infoAuthorCtrl =
        TextEditingController(text: source?.ruleBookInfo?.author ?? '');
    _infoIntroCtrl =
        TextEditingController(text: source?.ruleBookInfo?.intro ?? '');
    _infoCoverUrlCtrl =
        TextEditingController(text: source?.ruleBookInfo?.coverUrl ?? '');
    _infoTocUrlCtrl =
        TextEditingController(text: source?.ruleBookInfo?.tocUrl ?? '');
    _infoLastChapterCtrl =
        TextEditingController(text: source?.ruleBookInfo?.lastChapter ?? '');

    _tocChapterListCtrl =
        TextEditingController(text: source?.ruleToc?.chapterList ?? '');
    _tocChapterNameCtrl =
        TextEditingController(text: source?.ruleToc?.chapterName ?? '');
    _tocChapterUrlCtrl =
        TextEditingController(text: source?.ruleToc?.chapterUrl ?? '');

    _contentContentCtrl =
        TextEditingController(text: source?.ruleContent?.content ?? '');
    _contentTitleCtrl =
        TextEditingController(text: source?.ruleContent?.title ?? '');
    _contentReplaceRegexCtrl =
        TextEditingController(text: source?.ruleContent?.replaceRegex ?? '');

    _validateJson(silent: true);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _urlCtrl.dispose();
    _groupCtrl.dispose();
    _weightCtrl.dispose();
    _headerCtrl.dispose();
    _searchUrlCtrl.dispose();
    _exploreUrlCtrl.dispose();
    _searchBookListCtrl.dispose();
    _searchNameCtrl.dispose();
    _searchAuthorCtrl.dispose();
    _searchBookUrlCtrl.dispose();
    _searchCoverUrlCtrl.dispose();
    _searchIntroCtrl.dispose();
    _searchLastChapterCtrl.dispose();
    _exploreBookListCtrl.dispose();
    _exploreNameCtrl.dispose();
    _exploreAuthorCtrl.dispose();
    _exploreBookUrlCtrl.dispose();
    _exploreCoverUrlCtrl.dispose();
    _exploreIntroCtrl.dispose();
    _exploreLastChapterCtrl.dispose();
    _infoInitCtrl.dispose();
    _infoNameCtrl.dispose();
    _infoAuthorCtrl.dispose();
    _infoIntroCtrl.dispose();
    _infoCoverUrlCtrl.dispose();
    _infoTocUrlCtrl.dispose();
    _infoLastChapterCtrl.dispose();
    _tocChapterListCtrl.dispose();
    _tocChapterNameCtrl.dispose();
    _tocChapterUrlCtrl.dispose();
    _contentContentCtrl.dispose();
    _contentTitleCtrl.dispose();
    _contentReplaceRegexCtrl.dispose();
    _jsonCtrl.dispose();
    _debugKeyCtrl.dispose();
    _debugExploreUrlCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tabControl = CupertinoSlidingSegmentedControl<int>(
      groupValue: _tab,
      children: const {
        0: Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('基础')),
        1: Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('规则')),
        2: Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('JSON')),
        3: Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('调试')),
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
            _buildTextFieldTile('书籍列表', _searchBookListCtrl,
                placeholder: 'ruleSearch.bookList（CSS 选择器）'),
            _buildTextFieldTile('书名', _searchNameCtrl,
                placeholder: 'ruleSearch.name'),
            _buildTextFieldTile('作者', _searchAuthorCtrl,
                placeholder: 'ruleSearch.author'),
            _buildTextFieldTile('封面', _searchCoverUrlCtrl,
                placeholder: 'ruleSearch.coverUrl（@src）'),
            _buildTextFieldTile('简介', _searchIntroCtrl,
                placeholder: 'ruleSearch.intro'),
            _buildTextFieldTile('最新章节', _searchLastChapterCtrl,
                placeholder: 'ruleSearch.lastChapter'),
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
            _buildTextFieldTile('封面', _exploreCoverUrlCtrl,
                placeholder: 'ruleExplore.coverUrl'),
            _buildTextFieldTile('简介', _exploreIntroCtrl,
                placeholder: 'ruleExplore.intro'),
            _buildTextFieldTile('最新章节', _exploreLastChapterCtrl,
                placeholder: 'ruleExplore.lastChapter'),
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
            _buildTextFieldTile('最新章节', _infoLastChapterCtrl,
                placeholder: 'ruleBookInfo.lastChapter'),
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
          ],
        ),
        CupertinoListSection.insetGrouped(
          header: const Text('正文规则（ruleContent）'),
          children: [
            _buildTextFieldTile('标题（可选）', _contentTitleCtrl,
                placeholder: 'ruleContent.title'),
            _buildTextFieldTile('正文', _contentContentCtrl,
                placeholder: 'ruleContent.content（@text/@html）', maxLines: 4),
            _buildTextFieldTile('替换正则', _contentReplaceRegexCtrl,
                placeholder: 'ruleContent.replaceRegex（regex##rep##...）',
                maxLines: 4),
          ],
        ),
        CupertinoListSection.insetGrouped(
          children: [
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
            _buildTextFieldTile('分组', _groupCtrl, placeholder: 'bookSourceGroup'),
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
          header: const Text('常用字段'),
          children: [
            _buildTextFieldTile('Header', _headerCtrl, placeholder: 'header（每行 key:value）', maxLines: 6),
            _buildTextFieldTile('搜索 URL', _searchUrlCtrl, placeholder: 'searchUrl（含 {key} 或 {{key}}）'),
            _buildTextFieldTile('发现 URL', _exploreUrlCtrl, placeholder: 'exploreUrl'),
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
          header: const Text('搜索调试'),
          children: [
            CupertinoListTile.notched(
              title: const Text('关键词'),
              subtitle: CupertinoTextField(
                controller: _debugKeyCtrl,
                placeholder: '输入关键字',
              ),
            ),
            CupertinoListTile.notched(
              title: const Text('测试搜索'),
              additionalInfo: _debugLoading ? const Text('请求中…') : null,
              trailing: const CupertinoListTileChevron(),
              onTap: _debugLoading ? null : _debugSearch,
            ),
          ],
        ),
        CupertinoListSection.insetGrouped(
          header: const Text('发现调试'),
          children: [
            CupertinoListTile.notched(
              title: const Text('发现 URL（可选覆盖）'),
              subtitle: CupertinoTextField(
                controller: _debugExploreUrlCtrl,
                placeholder: '为空则使用 exploreUrl',
              ),
            ),
            CupertinoListTile.notched(
              title: const Text('测试发现'),
              additionalInfo: _debugLoading ? const Text('请求中…') : null,
              trailing: const CupertinoListTileChevron(),
              onTap: _debugLoading ? null : _debugExplore,
            ),
          ],
        ),
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
        CupertinoListSection.insetGrouped(
          header: Text('结果（${_debugResults.length}）'),
          children: _debugResults.isEmpty
              ? [
                  const CupertinoListTile.notched(
                    title: Text('暂无结果'),
                  ),
                ]
              : _debugResults
                  .map(
                    (r) => CupertinoListTile.notched(
                      title: Text(r.name.isEmpty ? '（无书名）' : r.name),
                      subtitle: Text(
                        r.author.isEmpty ? r.bookUrl : '${r.author} · ${r.bookUrl}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: const CupertinoListTileChevron(),
                      onTap: () => _selectResult(r),
                    ),
                  )
                  .toList(),
        ),
        if (_selectedResult != null) _buildSelectedDebugCard(),
      ],
    );
  }

  Widget _buildSelectedDebugCard() {
    final r = _selectedResult!;
    return CupertinoListSection.insetGrouped(
      header: const Text('选中项'),
      children: [
        CupertinoListTile.notched(
          title: const Text('书名'),
          additionalInfo: Text(r.name),
        ),
        CupertinoListTile.notched(
          title: const Text('作者'),
          additionalInfo: Text(r.author),
        ),
        CupertinoListTile.notched(
          title: const Text('详情 URL'),
          subtitle: Text(r.bookUrl, maxLines: 2, overflow: TextOverflow.ellipsis),
        ),
        CupertinoListTile.notched(
          title: const Text('测试详情'),
          trailing: const CupertinoListTileChevron(),
          onTap: _debugGetBookInfo,
        ),
        if (_selectedDetail != null) ...[
          CupertinoListTile.notched(
            title: const Text('目录 URL'),
            subtitle: Text(
              _selectedDetail!.tocUrl,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          CupertinoListTile.notched(
            title: const Text('测试目录'),
            trailing: const CupertinoListTileChevron(),
            onTap: _debugGetToc,
          ),
        ],
        if (_selectedToc.isNotEmpty)
          CupertinoListTile.notched(
            title: Text('目录章节（${_selectedToc.length}）'),
            subtitle: Text(
              _selectedToc.take(3).map((e) => e.name).join(' / '),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        if (_selectedToc.isNotEmpty)
          CupertinoListTile.notched(
            title: const Text('测试正文（第 1 章）'),
            trailing: const CupertinoListTileChevron(),
            onTap: _debugGetFirstContent,
          ),
        if (_selectedContent != null)
          CupertinoListTile.notched(
            title: const Text('正文预览'),
            subtitle: Text(
              _selectedContent!,
              maxLines: 6,
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
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
    map['enabled'] = _enabled;
    map['enabledExplore'] = _enabledExplore;
    map['weight'] = parseInt(_weightCtrl.text, 0);
    setOrRemove('header', textOrNull(_headerCtrl, trimValue: false));
    setOrRemove('searchUrl', textOrNull(_searchUrlCtrl));
    setOrRemove('exploreUrl', textOrNull(_exploreUrlCtrl));

    Map<String, dynamic> ensureMap(dynamic raw) {
      if (raw is Map<String, dynamic>) return Map<String, dynamic>.from(raw);
      if (raw is Map) {
        return raw.map((key, value) => MapEntry('$key', value));
      }
      return <String, dynamic>{};
    }

    Map<String, dynamic>? mergeRule(dynamic rawRule, Map<String, String?> updates) {
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
      'bookList': textOrNull(_searchBookListCtrl),
      'name': textOrNull(_searchNameCtrl),
      'author': textOrNull(_searchAuthorCtrl),
      'bookUrl': textOrNull(_searchBookUrlCtrl),
      'coverUrl': textOrNull(_searchCoverUrlCtrl),
      'intro': textOrNull(_searchIntroCtrl),
      'lastChapter': textOrNull(_searchLastChapterCtrl),
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
      'lastChapter': textOrNull(_exploreLastChapterCtrl),
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
      'coverUrl': textOrNull(_infoCoverUrlCtrl),
      'tocUrl': textOrNull(_infoTocUrlCtrl),
      'lastChapter': textOrNull(_infoLastChapterCtrl),
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
    });
    if (ruleToc == null) {
      map.remove('ruleToc');
    } else {
      map['ruleToc'] = ruleToc;
    }

    final ruleContent = mergeRule(map['ruleContent'], {
      'title': textOrNull(_contentTitleCtrl),
      'content': textOrNull(_contentContentCtrl, trimValue: false),
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
      _weightCtrl.text = source.weight.toString();
      _headerCtrl.text = source.header ?? '';
      _searchUrlCtrl.text = source.searchUrl ?? '';
      _exploreUrlCtrl.text = source.exploreUrl ?? '';
      _enabled = source.enabled;
      _enabledExplore = source.enabledExplore;

      _searchBookListCtrl.text = source.ruleSearch?.bookList ?? '';
      _searchNameCtrl.text = source.ruleSearch?.name ?? '';
      _searchAuthorCtrl.text = source.ruleSearch?.author ?? '';
      _searchBookUrlCtrl.text = source.ruleSearch?.bookUrl ?? '';
      _searchCoverUrlCtrl.text = source.ruleSearch?.coverUrl ?? '';
      _searchIntroCtrl.text = source.ruleSearch?.intro ?? '';
      _searchLastChapterCtrl.text = source.ruleSearch?.lastChapter ?? '';

      _exploreBookListCtrl.text = source.ruleExplore?.bookList ?? '';
      _exploreNameCtrl.text = source.ruleExplore?.name ?? '';
      _exploreAuthorCtrl.text = source.ruleExplore?.author ?? '';
      _exploreBookUrlCtrl.text = source.ruleExplore?.bookUrl ?? '';
      _exploreCoverUrlCtrl.text = source.ruleExplore?.coverUrl ?? '';
      _exploreIntroCtrl.text = source.ruleExplore?.intro ?? '';
      _exploreLastChapterCtrl.text = source.ruleExplore?.lastChapter ?? '';

      _infoInitCtrl.text = source.ruleBookInfo?.init ?? '';
      _infoNameCtrl.text = source.ruleBookInfo?.name ?? '';
      _infoAuthorCtrl.text = source.ruleBookInfo?.author ?? '';
      _infoIntroCtrl.text = source.ruleBookInfo?.intro ?? '';
      _infoCoverUrlCtrl.text = source.ruleBookInfo?.coverUrl ?? '';
      _infoTocUrlCtrl.text = source.ruleBookInfo?.tocUrl ?? '';
      _infoLastChapterCtrl.text = source.ruleBookInfo?.lastChapter ?? '';

      _tocChapterListCtrl.text = source.ruleToc?.chapterList ?? '';
      _tocChapterNameCtrl.text = source.ruleToc?.chapterName ?? '';
      _tocChapterUrlCtrl.text = source.ruleToc?.chapterUrl ?? '';

      _contentTitleCtrl.text = source.ruleContent?.title ?? '';
      _contentContentCtrl.text = source.ruleContent?.content ?? '';
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

  Future<void> _debugSearch() async {
    final map = _tryDecodeJsonMap(_jsonCtrl.text);
    if (map == null) {
      setState(() => _debugError = '请先修正 JSON');
      return;
    }
    final source = BookSource.fromJson(map);
    final key = _debugKeyCtrl.text.trim();
    if (key.isEmpty) {
      setState(() => _debugError = '请输入关键词');
      return;
    }

    setState(() {
      _debugLoading = true;
      _debugError = null;
      _debugResults = const [];
      _selectedResult = null;
      _selectedDetail = null;
      _selectedToc = const [];
      _selectedContent = null;
    });

    try {
      final results = await _engine.search(source, key);
      if (!mounted) return;
      setState(() {
        _debugResults = results;
      });
      if (results.isEmpty) {
        setState(() => _debugError = '没有结果（可能规则为空或解析失败）');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _debugError = '搜索失败：$e');
    } finally {
      if (mounted) {
        setState(() => _debugLoading = false);
      }
    }
  }

  Future<void> _debugExplore() async {
    final map = _tryDecodeJsonMap(_jsonCtrl.text);
    if (map == null) {
      setState(() => _debugError = '请先修正 JSON');
      return;
    }
    final source = BookSource.fromJson(map);
    final overrideUrl = _debugExploreUrlCtrl.text.trim();

    setState(() {
      _debugLoading = true;
      _debugError = null;
      _debugResults = const [];
      _selectedResult = null;
      _selectedDetail = null;
      _selectedToc = const [];
      _selectedContent = null;
    });

    try {
      final results = await _engine.explore(
        source,
        exploreUrlOverride: overrideUrl.isEmpty ? null : overrideUrl,
      );
      if (!mounted) return;
      setState(() {
        _debugResults = results;
      });
      if (results.isEmpty) {
        setState(() => _debugError = '没有结果（可能 exploreUrl/ruleExplore 为空或解析失败）');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _debugError = '发现失败：$e');
    } finally {
      if (mounted) {
        setState(() => _debugLoading = false);
      }
    }
  }

  void _selectResult(SearchResult r) {
    setState(() {
      _selectedResult = r;
      _selectedDetail = null;
      _selectedToc = const [];
      _selectedContent = null;
    });
  }

  Future<void> _debugGetBookInfo() async {
    final map = _tryDecodeJsonMap(_jsonCtrl.text);
    final selected = _selectedResult;
    if (map == null || selected == null) return;
    final source = BookSource.fromJson(map);

    setState(() {
      _debugLoading = true;
      _debugError = null;
      _selectedDetail = null;
      _selectedToc = const [];
      _selectedContent = null;
    });

    try {
      final detail = await _engine.getBookInfo(source, selected.bookUrl);
      if (!mounted) return;
      if (detail == null) {
        setState(() => _debugError = '获取详情失败（ruleBookInfo 为空或解析失败）');
        return;
      }
      setState(() => _selectedDetail = detail);
    } catch (e) {
      if (!mounted) return;
      setState(() => _debugError = '获取详情失败：$e');
    } finally {
      if (mounted) {
        setState(() => _debugLoading = false);
      }
    }
  }

  Future<void> _debugGetToc() async {
    final map = _tryDecodeJsonMap(_jsonCtrl.text);
    final detail = _selectedDetail;
    if (map == null || detail == null) return;
    final source = BookSource.fromJson(map);
    if (detail.tocUrl.trim().isEmpty) {
      setState(() => _debugError = 'tocUrl 为空（ruleBookInfo.tocUrl 没解析到）');
      return;
    }

    setState(() {
      _debugLoading = true;
      _debugError = null;
      _selectedToc = const [];
      _selectedContent = null;
    });

    try {
      final toc = await _engine.getToc(source, detail.tocUrl);
      if (!mounted) return;
      setState(() => _selectedToc = toc);
      if (toc.isEmpty) {
        setState(() => _debugError = '目录为空（ruleToc 为空或解析失败）');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _debugError = '获取目录失败：$e');
    } finally {
      if (mounted) {
        setState(() => _debugLoading = false);
      }
    }
  }

  Future<void> _debugGetFirstContent() async {
    final map = _tryDecodeJsonMap(_jsonCtrl.text);
    if (map == null) return;
    final source = BookSource.fromJson(map);
    if (_selectedToc.isEmpty) return;

    final chapterUrl = _selectedToc.first.url;
    if (chapterUrl.trim().isEmpty) return;

    setState(() {
      _debugLoading = true;
      _debugError = null;
      _selectedContent = null;
    });

    try {
      final content = await _engine.getContent(source, chapterUrl);
      if (!mounted) return;
      setState(() => _selectedContent = content);
      if (content.trim().isEmpty) {
        setState(() => _debugError = '正文为空（ruleContent 为空或解析失败）');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _debugError = '获取正文失败：$e');
    } finally {
      if (mounted) {
        setState(() => _debugLoading = false);
      }
    }
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
