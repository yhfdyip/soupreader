import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';

import '../../../app/widgets/app_cupertino_page_scaffold.dart';
import '../../../core/services/qr_scan_service.dart';
import '../constants/source_help_texts.dart';
import '../models/book_source.dart';
import '../services/rule_parser_engine.dart';
import '../services/source_debug_quick_action_helper.dart';
import '../services/source_explore_kinds_service.dart';
import 'source_debug_text_view.dart';

class SourceDebugLegacyView extends StatefulWidget {
  final BookSource source;
  final String? initialDebugKey;

  const SourceDebugLegacyView({
    super.key,
    required this.source,
    this.initialDebugKey,
  });

  @override
  State<SourceDebugLegacyView> createState() => _SourceDebugLegacyViewState();
}

class _SourceDebugLegacyViewState extends State<SourceDebugLegacyView> {
  static const String _defaultExploreHint = '系统::http://xxx';
  static const String _defaultInfoHint = 'https://m.qidian.com/book/1015609210';
  static const String _defaultTocHint =
      '++https://www.zhaishuyuan.com/read/30394';
  static const String _defaultContentHint =
      '--https://www.zhaishuyuan.com/chapter/30394/20940996';

  final RuleParserEngine _engine = RuleParserEngine();
  final List<SourceDebugEvent> _events = <SourceDebugEvent>[];
  final ScrollController _scrollController = ScrollController();
  late final TextEditingController _debugKeyCtrl;
  late final FocusNode _debugKeyFocusNode;
  late final SourceExploreKindsService _exploreKindsService;

  List<SourceExploreKind> _exploreKinds = const <SourceExploreKind>[];
  int _selectedExploreIndex = 0;

  bool _running = false;
  bool _helpVisible = true;
  bool _loadingExploreKinds = false;
  CancelToken? _debugCancelToken;

  String? _searchSrcRaw;
  String? _bookSrcRaw;
  String? _tocSrcRaw;
  String? _contentSrcRaw;

  @override
  void initState() {
    super.initState();
    _debugKeyCtrl = TextEditingController(text: _initialDebugKey());
    _debugKeyFocusNode = FocusNode();
    _debugKeyFocusNode.addListener(_onDebugKeyFocusChanged);
    _exploreKindsService = SourceExploreKindsService();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadExploreKinds();
    });
  }

  @override
  void dispose() {
    _debugCancelToken?.cancel('debug view disposed');
    _debugKeyFocusNode.removeListener(_onDebugKeyFocusChanged);
    _debugKeyFocusNode.dispose();
    _debugKeyCtrl.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onDebugKeyFocusChanged() {
    if (!mounted) return;
    final nextVisible = _debugKeyFocusNode.hasFocus;
    if (_helpVisible == nextVisible) return;
    setState(() => _helpVisible = nextVisible);
  }

  String _initialSearchKeyword() {
    final keyword = (widget.source.ruleSearch?.checkKeyWord ?? '').trim();
    return keyword.isEmpty ? '我的' : keyword;
  }

  String _initialDebugKey() {
    final explicit = (widget.initialDebugKey ?? '').trim();
    return explicit;
  }

  void _setDebugKey(String value) {
    final text = value.trim();
    _debugKeyCtrl.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    });
  }

  void _resetRawSources() {
    _searchSrcRaw = null;
    _bookSrcRaw = null;
    _tocSrcRaw = null;
    _contentSrcRaw = null;
  }

  void _pushLog(SourceDebugEvent event) {
    if (!mounted) return;
    setState(() {
      _events.add(event);
      if (event.state == -1 || event.state == 1000) {
        _running = false;
      }
    });
    _scrollToBottom();
  }

  void _onDebugEvent(SourceDebugEvent event) {
    if (event.isRaw) {
      if (!mounted) return;
      setState(() {
        switch (event.state) {
          case 10:
            _searchSrcRaw = event.message;
            break;
          case 20:
            _bookSrcRaw = event.message;
            break;
          case 30:
            _tocSrcRaw = event.message;
            break;
          case 40:
            _contentSrcRaw = event.message;
            break;
        }
      });
      return;
    }
    _pushLog(event);
  }

  Future<void> _runDebug([String? key]) async {
    if (_running) return;
    _debugCancelToken?.cancel('debug restarted');
    final cancelToken = CancelToken();
    _debugCancelToken = cancelToken;
    final runKey = SourceDebugQuickActionHelper.normalizeStartKey(
      key ?? _debugKeyCtrl.text,
    );
    _setDebugKey(runKey);
    _debugKeyFocusNode.unfocus();
    setState(() {
      _running = true;
      _helpVisible = false;
      _events.clear();
      _resetRawSources();
    });
    try {
      await _engine.debugRun(
        widget.source,
        runKey,
        onEvent: _onDebugEvent,
        cancelToken: cancelToken,
      );
    } on DioException catch (e) {
      if (e.type != DioExceptionType.cancel) {
        _pushLog(SourceDebugEvent(state: -1, message: '调试失败：$e'));
      }
    } catch (e) {
      _pushLog(SourceDebugEvent(state: -1, message: '调试失败：$e'));
    } finally {
      if (identical(_debugCancelToken, cancelToken)) {
        _debugCancelToken = null;
      }
      if (mounted && _running) {
        setState(() => _running = false);
      }
    }
  }

  Future<void> _loadExploreKinds({bool forceRefresh = false}) async {
    if (_loadingExploreKinds) return;
    setState(() => _loadingExploreKinds = true);
    List<SourceExploreKind> kinds;
    try {
      kinds = await _exploreKindsService.exploreKinds(
        widget.source,
        forceRefresh: forceRefresh,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingExploreKinds = false);
      _pushLog(SourceDebugEvent(state: -1, message: '获取发现出错 JSON 数据错误\n$e'));
      _debugKeyFocusNode.unfocus();
      if (!mounted) return;
      setState(() => _helpVisible = false);
      return;
    }
    if (!mounted) return;

    final filtered = kinds
        .where((item) => (item.url ?? '').trim().isNotEmpty)
        .toList(growable: false);
    final nextIndex = filtered.isEmpty
        ? 0
        : _selectedExploreIndex.clamp(0, filtered.length - 1).toInt();

    setState(() {
      _loadingExploreKinds = false;
      _exploreKinds = filtered;
      _selectedExploreIndex = nextIndex;
    });

    if (filtered.isEmpty) return;
    final first = filtered.first;
    if (!first.title.startsWith('ERROR:')) return;
    _pushLog(
      SourceDebugEvent(
        state: -1,
        message: '获取发现出错\n${first.url ?? ''}',
      ),
    );
    _debugKeyFocusNode.unfocus();
    if (!mounted) return;
    setState(() => _helpVisible = false);
  }

  Future<void> _refreshExploreKinds() async {
    await _exploreKindsService.clearExploreKindsCache(widget.source);
    if (!mounted) return;
    setState(() {
      _events.clear();
      _helpVisible = true;
      _selectedExploreIndex = 0;
    });
    await _loadExploreKinds(forceRefresh: true);
  }

  SourceExploreKind? get _selectedExploreKind {
    if (_exploreKinds.isEmpty) return null;
    final index =
        _selectedExploreIndex.clamp(0, _exploreKinds.length - 1).toInt();
    return _exploreKinds[index];
  }

  void _runExploreQuick(SourceExploreKind kind) {
    final url = (kind.url ?? '').trim();
    if (url.isEmpty) return;
    if (kind.title.startsWith('ERROR:')) return;
    final runKey = SourceDebugQuickActionHelper.buildExploreRunKey(
      title: kind.title,
      url: url,
    );
    _setDebugKey(runKey);
    _runDebug(runKey);
  }

  Future<void> _pickExploreQuick() async {
    if (_exploreKinds.isEmpty) return;
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (popupContext) => CupertinoActionSheet(
        title: const Text('选择发现'),
        actions: [
          for (var i = 0; i < _exploreKinds.length; i++)
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(popupContext);
                final kind = _exploreKinds[i];
                setState(() => _selectedExploreIndex = i);
                _runExploreQuick(kind);
              },
              child: Text(_exploreKinds[i].title),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(popupContext),
          child: const Text('取消'),
        ),
      ),
    );
  }

  void _applyPrefix(String prefix) {
    final action = SourceDebugQuickActionHelper.applyPrefix(
      query: _debugKeyCtrl.text,
      prefix: prefix,
    );
    _setDebugKey(action.nextQuery);
    if (!action.shouldRun) return;
    _runDebug(action.nextQuery);
  }

  void _runCurrentKeyIfNotEmpty() {
    final query = _debugKeyCtrl.text.trim();
    if (query.isEmpty) return;
    _runDebug(query);
  }

  Future<void> _scanAndDebug() async {
    final value = await QrScanService.scanText(context, title: '扫码调试');
    final text = value?.trim();
    if (text == null || text.isEmpty) return;
    await _runDebug(text);
  }

  Future<void> _openRawSource({
    required String title,
    required String? raw,
  }) async {
    final text = (raw ?? '').trim();
    if (text.isEmpty) {
      _showMessage('暂无$title');
      return;
    }
    await Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (_) => SourceDebugTextView(
          title: title,
          text: text,
        ),
      ),
    );
  }

  Future<void> _showMoreMenu() async {
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (popupContext) => CupertinoActionSheet(
        title: const Text('更多'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(popupContext);
              _openRawSource(title: '搜索源码', raw: _searchSrcRaw);
            },
            child: const Text('搜索源码'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(popupContext);
              _openRawSource(title: '详情源码', raw: _bookSrcRaw);
            },
            child: const Text('详情源码'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(popupContext);
              _openRawSource(title: '目录源码', raw: _tocSrcRaw);
            },
            child: const Text('目录源码'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(popupContext);
              _openRawSource(title: '正文源码', raw: _contentSrcRaw);
            },
            child: const Text('正文源码'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(popupContext);
              _refreshExploreKinds();
            },
            child: const Text('刷新发现'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(popupContext);
              _showMessage(SourceHelpTexts.debug);
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

  void _showMessage(String message) {
    showCupertinoDialog<void>(
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

  Widget _buildKeyField() {
    return SizedBox(
      height: 34,
      child: CupertinoSearchTextField(
        controller: _debugKeyCtrl,
        focusNode: _debugKeyFocusNode,
        placeholder: '输入关键字',
        onSubmitted: _runDebug,
      ),
    );
  }

  Widget _buildQuickChip({
    required String text,
    VoidCallback? onTap,
    VoidCallback? onLongPress,
    bool isError = false,
  }) {
    final enabled = onTap != null;
    final foreground = isError
        ? CupertinoColors.systemRed.resolveFrom(context)
        : enabled
            ? CupertinoColors.label.resolveFrom(context)
            : CupertinoColors.secondaryLabel.resolveFrom(context);
    final bg = isError
        ? CupertinoColors.systemRed.resolveFrom(context).withValues(alpha: 0.12)
        : CupertinoColors.systemGrey5.resolveFrom(context);

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 13,
            color: foreground,
          ),
        ),
      ),
    );
  }

  Widget _buildHelpPanel() {
    final myKeyword = _initialSearchKeyword();
    final selectedExplore = _selectedExploreKind;
    final exploreLabel = _loadingExploreKinds
        ? '发现加载中...'
        : selectedExplore == null
            ? _defaultExploreHint
            : SourceDebugQuickActionHelper.buildExploreRunKey(
                title: selectedExplore.title,
                url: selectedExplore.url ?? '',
              );
    final exploreError = selectedExplore?.title.startsWith('ERROR:') ?? false;

    final currentKey = _debugKeyCtrl.text.trim();
    final infoLabel = currentKey.isEmpty ? _defaultInfoHint : currentKey;

    return Container(
      width: double.infinity,
      color: CupertinoColors.systemBackground.resolveFrom(context),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '调试搜索 >> 输入关键字，如：',
            style: TextStyle(
              fontSize: 12,
              color: CupertinoColors.secondaryLabel.resolveFrom(context),
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildQuickChip(
                text: myKeyword,
                onTap: () {
                  _setDebugKey(myKeyword);
                  _runDebug(myKeyword);
                },
              ),
              _buildQuickChip(
                text: '系统',
                onTap: () {
                  _setDebugKey('系统');
                  _runDebug('系统');
                },
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '调试发现 >> 输入发现 URL，如：',
            style: TextStyle(
              fontSize: 12,
              color: CupertinoColors.secondaryLabel.resolveFrom(context),
            ),
          ),
          const SizedBox(height: 6),
          _buildQuickChip(
            text: exploreLabel,
            onTap: selectedExplore == null
                ? null
                : () => _runExploreQuick(selectedExplore),
            onLongPress: _exploreKinds.length > 1 ? _pickExploreQuick : null,
            isError: exploreError,
          ),
          const SizedBox(height: 10),
          Text(
            '调试详情页 >> 输入详情页 URL，如：',
            style: TextStyle(
              fontSize: 12,
              color: CupertinoColors.secondaryLabel.resolveFrom(context),
            ),
          ),
          const SizedBox(height: 6),
          _buildQuickChip(
            text: infoLabel,
            onTap: currentKey.isEmpty ? null : _runCurrentKeyIfNotEmpty,
          ),
          const SizedBox(height: 10),
          Text(
            '调试目录页 >> 输入目录页 URL，如：',
            style: TextStyle(
              fontSize: 12,
              color: CupertinoColors.secondaryLabel.resolveFrom(context),
            ),
          ),
          const SizedBox(height: 6),
          _buildQuickChip(
            text: _defaultTocHint,
            onTap: () => _applyPrefix('++'),
          ),
          const SizedBox(height: 10),
          Text(
            '调试正文页 >> 输入正文页 URL，如：',
            style: TextStyle(
              fontSize: 12,
              color: CupertinoColors.secondaryLabel.resolveFrom(context),
            ),
          ),
          const SizedBox(height: 6),
          _buildQuickChip(
            text: _defaultContentHint,
            onTap: () => _applyPrefix('--'),
          ),
        ],
      ),
    );
  }

  Widget _buildLogList() {
    if (_events.isEmpty) {
      return Center(
        child: Text(
          '提交 key 后开始调试',
          style: TextStyle(
            color: CupertinoColors.secondaryLabel.resolveFrom(context),
          ),
        ),
      );
    }
    return ListView.separated(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
      itemBuilder: (_, index) {
        final event = _events[index];
        final color = event.state < 0
            ? CupertinoColors.systemRed.resolveFrom(context)
            : event.state >= 20
                ? CupertinoColors.systemBlue.resolveFrom(context)
                : CupertinoColors.label.resolveFrom(context);
        return Text(
          event.message,
          style: TextStyle(fontSize: 13, color: color),
        );
      },
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemCount: _events.length,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppCupertinoPageScaffold(
      title: '书源调试',
      middle: _buildKeyField(),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CupertinoButton(
            padding: EdgeInsets.zero,
            minimumSize: const Size(30, 30),
            onPressed: _running ? null : _scanAndDebug,
            child: const Icon(CupertinoIcons.qrcode_viewfinder),
          ),
          CupertinoButton(
            padding: EdgeInsets.zero,
            minimumSize: const Size(30, 30),
            onPressed: _showMoreMenu,
            child: const Icon(CupertinoIcons.ellipsis),
          ),
        ],
      ),
      child: Column(
        children: [
          if (_running)
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 6, 0, 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  CupertinoActivityIndicator(),
                  SizedBox(width: 8),
                  Text('调试运行中...'),
                ],
              ),
            ),
          if (_helpVisible) _buildHelpPanel(),
          Expanded(child: _buildLogList()),
        ],
      ),
    );
  }
}
