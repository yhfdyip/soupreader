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

  int _tab = 0; // 0 基础 1 JSON 2 调试

  late final TextEditingController _nameCtrl;
  late final TextEditingController _urlCtrl;
  late final TextEditingController _groupCtrl;
  late final TextEditingController _weightCtrl;
  late final TextEditingController _headerCtrl;
  late final TextEditingController _searchUrlCtrl;
  late final TextEditingController _exploreUrlCtrl;

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
        1: Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('JSON')),
        2: Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('调试')),
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
              onPressed: _jsonError == null ? _save : null,
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
              onTap: _syncFieldsToJson,
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

  void _syncFieldsToJson() {
    final map = _tryDecodeJsonMap(_jsonCtrl.text) ?? <String, dynamic>{};
    int parseInt(String text, int fallback) =>
        int.tryParse(text.trim()) ?? fallback;

    map['bookSourceName'] = _nameCtrl.text.trim();
    map['bookSourceUrl'] = _urlCtrl.text.trim();
    map['bookSourceGroup'] =
        _groupCtrl.text.trim().isEmpty ? null : _groupCtrl.text.trim();
    map['enabled'] = _enabled;
    map['enabledExplore'] = _enabledExplore;
    map['weight'] = parseInt(_weightCtrl.text, 0);
    map['header'] = _headerCtrl.text.trim().isEmpty ? null : _headerCtrl.text;
    map['searchUrl'] =
        _searchUrlCtrl.text.trim().isEmpty ? null : _searchUrlCtrl.text.trim();
    map['exploreUrl'] =
        _exploreUrlCtrl.text.trim().isEmpty ? null : _exploreUrlCtrl.text.trim();

    final normalized = LegadoJson.encode(map);
    setState(() {
      _jsonCtrl.text = _prettyJson(normalized);
      _tab = 1;
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
    });
    _validateJson();
    _showMessage('已从 JSON 同步到表单');
  }

  Future<void> _save() async {
    _validateJson();
    if (_jsonError != null) return;

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
