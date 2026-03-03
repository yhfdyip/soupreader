import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';

import '../../../app/theme/source_ui_tokens.dart';
import '../../../app/theme/ui_tokens.dart';
import '../../../app/widgets/app_cupertino_page_scaffold.dart';
import '../../../app/widgets/app_empty_state.dart';
import '../../../app/widgets/app_manage_search_field.dart';
import '../../../app/widgets/app_nav_bar_button.dart';
import '../../../app/widgets/cupertino_bottom_dialog.dart';
import '../../../app/widgets/source_consistent_card.dart';
import '../../../app/widgets/source_group_badge.dart';
import '../../../core/database/database_service.dart';
import '../../../core/database/repositories/source_repository.dart';
import '../../../core/models/app_settings.dart';
import '../../../core/services/exception_log_service.dart';
import '../../../core/services/settings_service.dart';
import '../../../core/services/source_variable_store.dart';
import '../../search/models/search_scope.dart';
import '../../search/models/search_scope_group_helper.dart';
import '../../search/views/search_view.dart';
import '../../source/models/book_source.dart';
import '../../source/services/source_explore_kinds_service.dart';
import '../../source/services/source_login_url_resolver.dart';
import '../../source/views/source_edit_legacy_view.dart';
import '../../source/views/source_login_form_view.dart';
import '../../source/views/source_login_webview_view.dart';
import '../services/discovery_filter_helper.dart';
import 'discovery_explore_results_view.dart';

/// 发现页（对标 legado ExploreFragment）：
/// - 展示支持发现的书源列表
/// - 点击书源展开/收起发现入口
/// - 点击入口进入二级发现书单页
class DiscoveryView extends StatefulWidget {
  final ValueListenable<int>? compressSignal;

  const DiscoveryView({
    super.key,
    this.compressSignal,
  });

  @override
  State<DiscoveryView> createState() => _DiscoveryViewState();
}

class _DiscoveryViewState extends State<DiscoveryView> {
  static const int _collapsedKindsLimit = 12;
  static const double _minTapSize = SourceUiTokens.minTapSize;

  late final SourceRepository _sourceRepo;
  late final SourceExploreKindsService _exploreKindsService;
  final SettingsService _settingsService = SettingsService();
  StreamSubscription<List<BookSource>>? _sourceSub;
  String? _initError;

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();

  List<BookSource> _allSources = <BookSource>[];
  int? _lastExternalCompressVersion;

  String? _expandedSourceUrl;
  final Set<String> _loadingKindsSources = <String>{};
  final Set<String> _expandedKindsSources = <String>{};
  final Map<String, List<SourceExploreKind>> _sourceKindsCache =
      <String, List<SourceExploreKind>>{};

  @override
  void initState() {
    super.initState();
    try {
      final db = DatabaseService();
      _sourceRepo = SourceRepository(db);
      _exploreKindsService = SourceExploreKindsService(databaseService: db);

      _allSources = _sourceRepo.getAllSources();
      _searchController.addListener(_onQueryChanged);
      _searchFocusNode.addListener(_onSearchFocusChanged);
      _lastExternalCompressVersion = widget.compressSignal?.value;
      widget.compressSignal?.addListener(_onExternalCompressSignal);
      _sourceSub = _sourceRepo.watchAllSources().listen((sources) {
        if (!mounted) return;
        setState(() {
          _allSources = sources;
          if (_expandedSourceUrl != null &&
              !_allSources.any((s) => s.bookSourceUrl == _expandedSourceUrl)) {
            _expandedSourceUrl = null;
          }
        });
      });
    } catch (error, stackTrace) {
      _initError = '发现页初始化异常: $error';
      debugPrint('[discovery] init failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      ExceptionLogService().record(
        node: 'discovery.init',
        message: '发现页初始化失败',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  void didUpdateWidget(covariant DiscoveryView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.compressSignal == widget.compressSignal) return;
    oldWidget.compressSignal?.removeListener(_onExternalCompressSignal);
    _lastExternalCompressVersion = widget.compressSignal?.value;
    widget.compressSignal?.addListener(_onExternalCompressSignal);
  }

  @override
  void dispose() {
    _sourceSub?.cancel();
    widget.compressSignal?.removeListener(_onExternalCompressSignal);
    _searchController
      ..removeListener(_onQueryChanged)
      ..dispose();
    _searchFocusNode
      ..removeListener(_onSearchFocusChanged)
      ..dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onExternalCompressSignal() {
    final version = widget.compressSignal?.value;
    if (version == null) return;
    if (_lastExternalCompressVersion == version) return;
    _lastExternalCompressVersion = version;
    _compressExplore();
  }

  void _onQueryChanged() {
    if (!mounted) return;
    setState(() {});
  }

  void _onSearchFocusChanged() {
    if (!mounted) return;
    setState(() {});
  }

  List<BookSource> _eligibleSources(List<BookSource> input) {
    // 对齐 legado BookSourceDao.flowExplore：
    // 仅以 enabledExplore + hasExploreUrl 作为发现页可见条件，并按 customOrder 升序。
    final indexed = input.asMap().entries.where((entry) {
      final source = entry.value;
      final hasExploreUrl = (source.exploreUrl ?? '').trim().isNotEmpty;
      return source.enabledExplore && hasExploreUrl;
    }).toList(growable: false);

    indexed.sort((a, b) {
      final byOrder = a.value.customOrder.compareTo(b.value.customOrder);
      if (byOrder != 0) return byOrder;
      // customOrder 相同时保持原输入顺序，避免非 legacy 语义下的额外排序。
      return a.key.compareTo(b.key);
    });
    return indexed.map((entry) => entry.value).toList(growable: false);
  }

  List<String> _buildGroups(List<BookSource> sources) {
    final groups = <String>{};
    for (final source in sources) {
      groups
          .addAll(DiscoveryFilterHelper.extractGroups(source.bookSourceGroup));
    }
    final sorted = groups.toList(growable: false)
      ..sort(SearchScopeGroupHelper.cnCompareLikeLegado);
    return sorted;
  }

  void _setQuery(String query) {
    _searchController.text = query;
    _searchController.selection = TextSelection.fromPosition(
      TextPosition(offset: query.length),
    );
  }

  void _clearQuery() {
    _searchController.clear();
    _searchFocusNode.unfocus();
  }

  Future<void> _showGroupFilterMenu() async {
    final groups = _buildGroups(_eligibleSources(_allSources));
    await showCupertinoBottomDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => CupertinoActionSheet(
        title: const Text('分组'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(ctx);
              _setQuery('');
            },
            child: const Text('全部'),
          ),
          for (final group in groups)
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(ctx);
                _setQuery('group:$group');
              },
              child: Text(group),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('取消'),
        ),
      ),
    );
  }

  void _compressExplore() {
    if (_expandedSourceUrl != null) {
      setState(() => _expandedSourceUrl = null);
      return;
    }
    if (!_scrollController.hasClients) return;
    // 与 legado 保持一致：E-Ink 模式避免平滑动画，直接回到顶部。
    if (_settingsService.appSettings.appearanceMode == AppAppearanceMode.eInk) {
      _scrollController.jumpTo(0);
      return;
    }
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOut,
    );
  }

  Future<void> _toggleSource(BookSource source) async {
    final sourceUrl = source.bookSourceUrl;
    if (_expandedSourceUrl == sourceUrl) {
      setState(() {
        _expandedSourceUrl = null;
        _expandedKindsSources.remove(sourceUrl);
      });
      return;
    }

    setState(() {
      _expandedSourceUrl = sourceUrl;
      _expandedKindsSources.remove(sourceUrl);
    });
    await _loadKinds(source, forceRefresh: false);
  }

  void _toggleKindsExpanded(String sourceUrl) {
    if (_expandedKindsSources.contains(sourceUrl)) {
      setState(() => _expandedKindsSources.remove(sourceUrl));
      return;
    }
    setState(() => _expandedKindsSources.add(sourceUrl));
  }

  Future<void> _loadKinds(
    BookSource source, {
    required bool forceRefresh,
  }) async {
    final sourceUrl = source.bookSourceUrl;

    if (!forceRefresh && _sourceKindsCache.containsKey(sourceUrl)) {
      return;
    }

    setState(() => _loadingKindsSources.add(sourceUrl));
    try {
      final kinds = await _exploreKindsService.exploreKinds(
        source,
        forceRefresh: forceRefresh,
      );
      if (!mounted) return;
      setState(() {
        _sourceKindsCache[sourceUrl] = kinds;
        _loadingKindsSources.remove(sourceUrl);
      });
    } catch (e, st) {
      ExceptionLogService().record(
        node: 'discovery.load_kinds',
        message: '加载发现入口失败',
        error: e,
        stackTrace: st,
        context: <String, dynamic>{
          'sourceUrl': sourceUrl,
          'sourceName': source.bookSourceName,
          'forceRefresh': forceRefresh,
        },
      );
      if (!mounted) return;
      setState(() {
        _loadingKindsSources.remove(sourceUrl);
        _sourceKindsCache[sourceUrl] = <SourceExploreKind>[
          SourceExploreKind(
            title: 'ERROR:发现入口解析失败',
            url: '$e\n$st',
          ),
        ];
      });
    }
  }

  Future<void> _openExploreKind(
    BookSource source,
    SourceExploreKind kind,
  ) async {
    final rawUrl = kind.url?.trim() ?? '';
    if (rawUrl.isEmpty) return;

    final title = kind.title.trim().isEmpty ? '发现' : kind.title.trim();
    if (title.startsWith('ERROR:')) {
      _showMessage(rawUrl, title: 'ERROR');
      return;
    }

    await Navigator.of(context, rootNavigator: true).push(
      CupertinoPageRoute<void>(
        builder: (_) => DiscoveryExploreResultsView(
          source: source,
          exploreName: title,
          exploreUrl: rawUrl,
        ),
      ),
    );
  }

  Future<void> _showSourceActions(BookSource source) async {
    showCupertinoBottomDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => CupertinoActionSheet(
        title: Text(source.bookSourceName),
        message: Text(source.bookSourceUrl),
        actions: [
          CupertinoActionSheetAction(
            child: const Text('编辑'),
            onPressed: () {
              Navigator.pop(ctx);
              _openEditor(source.bookSourceUrl);
            },
          ),
          CupertinoActionSheetAction(
            child: const Text('置顶'),
            onPressed: () {
              Navigator.pop(ctx);
              _toTop(source.bookSourceUrl);
            },
          ),
          if ((source.loginUrl ?? '').trim().isNotEmpty)
            CupertinoActionSheetAction(
              child: const Text('登录'),
              onPressed: () {
                Navigator.pop(ctx);
                _openSourceLogin(source);
              },
            ),
          CupertinoActionSheetAction(
            child: const Text('搜索'),
            onPressed: () {
              Navigator.pop(ctx);
              _searchInSource(source);
            },
          ),
          CupertinoActionSheetAction(
            child: const Text('刷新'),
            onPressed: () {
              Navigator.pop(ctx);
              _refreshSourceKinds(source);
            },
          ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            child: const Text('删除'),
            onPressed: () {
              Navigator.pop(ctx);
              _confirmDeleteSource(source);
            },
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          child: const Text('取消'),
          onPressed: () => Navigator.pop(ctx),
        ),
      ),
    );
  }

  Future<void> _openEditor(String sourceUrl) async {
    final key = sourceUrl.trim();
    if (key.isEmpty || !mounted) return;
    final current = _sourceRepo.getSourceByUrl(key);
    if (current == null) {
      await Navigator.of(context).push(
        CupertinoPageRoute<void>(
          builder: (_) => const SourceEditLegacyView(initialRawJson: '{}'),
        ),
      );
      return;
    }

    await Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (_) => SourceEditLegacyView.fromSource(
          current,
          rawJson: _sourceRepo.getRawJsonByUrl(current.bookSourceUrl),
        ),
      ),
    );
  }

  Future<void> _toTop(String sourceUrl) async {
    final key = sourceUrl.trim();
    if (key.isEmpty) return;

    final currentSource = _sourceRepo.getSourceByUrl(key);
    if (currentSource == null) return;

    final all = _sourceRepo.getAllSources();
    final minOrder = all.isEmpty
        ? currentSource.customOrder
        : all.map((item) => item.customOrder).reduce(math.min);

    await _sourceRepo.updateSource(
      currentSource.copyWith(customOrder: minOrder - 1),
    );
  }

  Future<void> _openSourceLogin(BookSource source) async {
    final currentSource = _sourceRepo.getSourceByUrl(source.bookSourceUrl);
    if (currentSource == null) {
      _showMessage('未找到书源');
      return;
    }

    final hasLoginUi = (currentSource.loginUi ?? '').trim().isNotEmpty;
    if (hasLoginUi) {
      await Navigator.of(context).push(
        CupertinoPageRoute<void>(
          builder: (_) => SourceLoginFormView(source: currentSource),
        ),
      );
      return;
    }

    final resolvedUrl = SourceLoginUrlResolver.resolve(
      baseUrl: currentSource.bookSourceUrl,
      loginUrl: currentSource.loginUrl ?? '',
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
        builder: (_) => SourceLoginWebViewView(
          source: currentSource,
          initialUrl: resolvedUrl,
        ),
      ),
    );
  }

  Future<void> _searchInSource(BookSource source) async {
    final nextScope = SearchScope.fromSource(source);
    final currentSettings = _settingsService.appSettings;
    if (currentSettings.searchScope != nextScope) {
      await _settingsService.saveAppSettings(
        currentSettings.copyWith(searchScope: nextScope),
      );
    }
    if (!mounted) return;

    await Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (_) => const SearchView(),
      ),
    );
  }

  Future<void> _refreshSourceKinds(BookSource source) async {
    try {
      await _exploreKindsService.clearExploreKindsCache(source);
    } catch (e, st) {
      ExceptionLogService().record(
        node: 'discovery.refresh_kinds',
        message: '刷新发现入口缓存失败',
        error: e,
        stackTrace: st,
        context: <String, dynamic>{
          'sourceUrl': source.bookSourceUrl,
          'sourceName': source.bookSourceName,
        },
      );
      if (mounted) {
        _showMessage('刷新发现入口失败，请稍后重试');
      }
      return;
    }
    if (!mounted) return;

    setState(() {
      _sourceKindsCache.remove(source.bookSourceUrl);
    });

    if (_expandedSourceUrl == source.bookSourceUrl) {
      await _loadKinds(source, forceRefresh: true);
    }
  }

  Future<void> _confirmDeleteSource(BookSource source) async {
    final ok = await showCupertinoDialog<bool>(
          context: context,
          builder: (ctx) => CupertinoAlertDialog(
            title: const Text('提醒'),
            content: Text('是否确认删除？\n${source.bookSourceName}'),
            actions: [
              CupertinoDialogAction(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('取消'),
              ),
              CupertinoDialogAction(
                isDestructiveAction: true,
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('确定'),
              ),
            ],
          ),
        ) ??
        false;

    if (!ok) return;
    await _deleteSourceByLegacyRule(source);
  }

  Future<void> _deleteSourceByLegacyRule(BookSource source) async {
    final sourceUrl = source.bookSourceUrl.trim();
    if (sourceUrl.isEmpty) return;

    try {
      await _sourceRepo.deleteSource(sourceUrl);
      await SourceVariableStore.removeVariable(sourceUrl);
    } catch (error, stackTrace) {
      ExceptionLogService().record(
        node: 'explore_item.menu_del',
        message: '删除书源失败',
        error: error,
        stackTrace: stackTrace,
        context: <String, dynamic>{
          'sourceKey': sourceUrl,
          'sourceName': source.bookSourceName,
        },
      );
    }
  }

  void _showMessage(String message, {String title = '提示'}) {
    showCupertinoDialog<void>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('好'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_initError != null) return _buildInitErrorPage();

    final eligible = _eligibleSources(_allSources);
    final visible = DiscoveryFilterHelper.applyQueryFilter(
        eligible, _searchController.text);
    final query = _searchController.text.trim();
    final showEmptyMessage = DiscoveryFilterHelper.shouldShowEmptyMessage(
      visibleCount: visible.length,
      query: query,
    );

    return AppCupertinoPageScaffold(
      title: '发现',
      useSliverNavigationBar: true,
      sliverScrollController: _scrollController,
      trailing: AppNavBarButton(
        onPressed: _showGroupFilterMenu,
        child: const Icon(CupertinoIcons.slider_horizontal_3, size: 22),
      ),
      child: const SizedBox.shrink(),
      sliverBodyBuilder: (_) => _buildBodySliver(
        eligible: eligible,
        visible: visible,
        query: query,
        showEmptyMessage: showEmptyMessage,
      ),
    );
  }

  Widget _buildInitErrorPage() {
    return AppCupertinoPageScaffold(
      title: '发现',
      useSliverNavigationBar: true,
      sliverScrollController: _scrollController,
      child: const SizedBox.shrink(),
      sliverBodyBuilder: (_) => SliverSafeArea(
        top: true,
        bottom: true,
        sliver: SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                _initError ?? '初始化失败',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBodySliver({
    required List<BookSource> eligible,
    required List<BookSource> visible,
    required String query,
    required bool showEmptyMessage,
  }) {
    final theme = CupertinoTheme.of(context);
    final uiTokens = AppUiTokens.resolve(context);

    final header = _buildSearchHeader(
      visibleCount: visible.length,
      query: query,
      theme: theme,
      uiTokens: uiTokens,
    );

    if (visible.isEmpty) {
      return SliverSafeArea(
        top: true,
        bottom: true,
        sliver: SliverFillRemaining(
          hasScrollBody: false,
          child: Column(
            children: [
              header,
              Expanded(
                child: showEmptyMessage
                    ? _buildEmptyState(
                        eligibleCount: eligible.length,
                        query: query,
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      );
    }

    return SliverSafeArea(
      top: true,
      bottom: true,
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            if (index == 0) return header;
            if (index == visible.length + 1) {
              return const SizedBox(height: 12);
            }
            final source = visible[index - 1];
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: _buildSourceItem(source),
            );
          },
          childCount: visible.length + 2,
        ),
      ),
    );
  }

  Widget _buildSearchHeader({
    required int visibleCount,
    required String query,
    required CupertinoThemeData theme,
    required AppUiTokens uiTokens,
  }) {
    final showCancel = _searchFocusNode.hasFocus || query.isNotEmpty;

    return Padding(
      padding: AppManageSearchField.outerPadding,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: AppManageSearchField(
                  controller: _searchController,
                  focusNode: _searchFocusNode,
                  placeholder: '请输入关键字搜索书源...',
                ),
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                child: showCancel
                    ? CupertinoButton(
                        key: const ValueKey<String>('discovery_search_cancel'),
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        minimumSize: const Size(_minTapSize, _minTapSize),
                        onPressed: _clearQuery,
                        child: Text(
                          '取消',
                          style: theme.textTheme.actionTextStyle.copyWith(
                            color: SourceUiTokens.resolvePrimaryActionColor(
                                context),
                          ),
                        ),
                      )
                    : const SizedBox(
                        key: ValueKey<String>(
                          'discovery_search_cancel_placeholder',
                        ),
                        width: 0,
                        height: _minTapSize,
                      ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                '书源（$visibleCount）',
                style: theme.textTheme.textStyle.copyWith(
                  fontSize: SourceUiTokens.itemMetaSize,
                  color: uiTokens.colors.mutedForeground,
                ),
              ),
              if (query.startsWith('group:')) ...[
                const SizedBox(width: 8),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: uiTokens.colors.accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(uiTokens.radii.control),
                  ),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    child: Text(
                      '分组筛选',
                      style: theme.textTheme.textStyle.copyWith(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: uiTokens.colors.accent,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState({
    required int eligibleCount,
    required String query,
  }) {
    String subtitle;
    if (eligibleCount == 0) {
      subtitle = '请在书源管理导入书源';
    } else if (query.isNotEmpty) {
      subtitle = '当前筛选条件下无书源';
    } else {
      subtitle = '请在书源管理导入书源';
    }
    return AppEmptyState(
      illustration: const AppEmptyPlanetIllustration(),
      title: '没有发现任何内容',
      message: subtitle,
    );
  }

  Widget _buildSourceItem(BookSource source) {
    final theme = CupertinoTheme.of(context);
    final uiTokens = AppUiTokens.resolve(context);
    final secondaryLabel = uiTokens.colors.secondaryLabel;

    final sourceUrl = source.bookSourceUrl;
    final expanded = _expandedSourceUrl == sourceUrl;
    final loadingKinds = _loadingKindsSources.contains(sourceUrl);
    final kinds = _sourceKindsCache[sourceUrl] ?? const <SourceExploreKind>[];
    final kindsExpanded = _expandedKindsSources.contains(sourceUrl);
    final visibleKinds = kindsExpanded || kinds.length <= _collapsedKindsLimit
        ? kinds
        : kinds.take(_collapsedKindsLimit).toList(growable: false);
    final hasHiddenKinds = visibleKinds.length < kinds.length;
    final groupText = (source.bookSourceGroup ?? '').trim();

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: SourceConsistentCard(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _toggleSource(source),
              onLongPress: () => _showSourceActions(source),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: _minTapSize),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            source.bookSourceName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.textStyle.copyWith(
                              fontSize: SourceUiTokens.itemTitleSize,
                              fontWeight: FontWeight.w600,
                              color: uiTokens.colors.foreground,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            source.bookSourceUrl,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.textStyle.copyWith(
                              fontSize: SourceUiTokens.itemMetaSize,
                              color: secondaryLabel,
                            ),
                          ),
                          if (groupText.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            SourceGroupBadge(
                              text: groupText,
                              textColor: secondaryLabel.withValues(alpha: 0.9),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      expanded
                          ? CupertinoIcons.chevron_down
                          : CupertinoIcons.chevron_forward,
                      size: 16,
                      color: uiTokens.colors.mutedForeground,
                    ),
                  ],
                ),
              ),
            ),
            if (expanded) ...[
              const SizedBox(height: 8),
              if (loadingKinds)
                Row(
                  children: [
                    const CupertinoActivityIndicator(),
                    const SizedBox(width: 8),
                    Text(
                      '正在加载发现入口…',
                      style: theme.textTheme.textStyle.copyWith(
                        fontSize: SourceUiTokens.itemMetaSize,
                        color: secondaryLabel,
                      ),
                    ),
                  ],
                )
              else if (kinds.isEmpty)
                Text(
                  '暂无发现入口',
                  style: theme.textTheme.textStyle.copyWith(
                    fontSize: SourceUiTokens.itemMetaSize,
                    color: secondaryLabel,
                  ),
                )
              else
                LayoutBuilder(
                  builder: (context, constraints) {
                    final maxWidth = constraints.maxWidth;
                    final chips = <Widget>[];
                    for (final kind in visibleKinds) {
                      if (kind.style?.layoutWrapBefore == true) {
                        chips.add(SizedBox(width: maxWidth, height: 0));
                      }

                      final width = _kindWidth(kind.style, maxWidth);
                      final child = _buildKindChip(
                        source,
                        kind,
                        theme: theme,
                        uiTokens: uiTokens,
                      );
                      if (width == null) {
                        chips.add(child);
                      } else {
                        chips.add(
                          SizedBox(
                            width: width,
                            child: child,
                          ),
                        );
                      }
                    }
                    if (hasHiddenKinds || kindsExpanded) {
                      final hiddenCount = kinds.length - visibleKinds.length;
                      chips.add(
                        _buildKindsToggleChip(
                          expanded: kindsExpanded,
                          hiddenCount: hiddenCount,
                          theme: theme,
                          uiTokens: uiTokens,
                          onTap: () => _toggleKindsExpanded(sourceUrl),
                        ),
                      );
                    }

                    return Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: chips,
                    );
                  },
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildKindsToggleChip({
    required bool expanded,
    required int hiddenCount,
    required CupertinoThemeData theme,
    required AppUiTokens uiTokens,
    required VoidCallback onTap,
  }) {
    final title = expanded ? '收起' : '更多 $hiddenCount';
    final textColor = uiTokens.colors.secondaryLabel;
    final backgroundColor =
        CupertinoColors.tertiarySystemFill.resolveFrom(context);
    final borderColor = uiTokens.colors.separator.withValues(alpha: 0.55);
    return _buildKindPill(
      onTap: onTap,
      uiTokens: uiTokens,
      backgroundColor: backgroundColor,
      borderColor: borderColor,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: theme.textTheme.textStyle.copyWith(
              fontSize: SourceUiTokens.actionTextSize,
              color: textColor,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 4),
          Icon(
            expanded ? CupertinoIcons.chevron_up : CupertinoIcons.chevron_down,
            size: 12,
            color: textColor,
          ),
        ],
      ),
    );
  }

  Widget _buildKindPill({
    required Widget child,
    required Color backgroundColor,
    required Color borderColor,
    required AppUiTokens uiTokens,
    required VoidCallback? onTap,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: _minTapSize),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(uiTokens.radii.control),
            border: Border.all(
              color: borderColor,
              width: SourceUiTokens.borderWidth,
            ),
          ),
          child: child,
        ),
      ),
    );
  }

  double? _kindWidth(SourceExploreKindStyle? style, double maxWidth) {
    if (style == null) return null;
    var basis = style.layoutFlexBasisPercent;
    if (basis > 1 && basis <= 100) {
      basis = basis / 100;
    }
    if (basis > 0 && basis <= 1) {
      return (maxWidth * basis).clamp(64.0, maxWidth).toDouble();
    }
    if (style.layoutFlexGrow > 0) {
      return maxWidth;
    }
    return null;
  }

  Widget _buildKindChip(
    BookSource source,
    SourceExploreKind kind, {
    required CupertinoThemeData theme,
    required AppUiTokens uiTokens,
  }) {
    final title = kind.title.trim().isEmpty ? '发现' : kind.title.trim();
    final url = kind.url?.trim() ?? '';
    final isEnabled = url.isNotEmpty;
    final isError = title.startsWith('ERROR:');
    final normalBackground =
        CupertinoColors.tertiarySystemFill.resolveFrom(context);
    final enabledBackground =
        CupertinoColors.secondarySystemFill.resolveFrom(context);

    final backgroundColor = isError
        ? uiTokens.colors.destructive.withValues(alpha: 0.1)
        : isEnabled
            ? enabledBackground
            : normalBackground;
    final borderColor = isError
        ? uiTokens.colors.destructive.withValues(alpha: 0.4)
        : uiTokens.colors.separator.withValues(alpha: isEnabled ? 0.6 : 0.45);
    final textColor = isError
        ? uiTokens.colors.destructive
        : isEnabled
            ? uiTokens.colors.foreground
            : uiTokens.colors.secondaryLabel;

    return _buildKindPill(
      onTap: isEnabled ? () => _openExploreKind(source, kind) : null,
      uiTokens: uiTokens,
      backgroundColor: backgroundColor,
      borderColor: borderColor,
      child: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.textStyle.copyWith(
          fontSize: SourceUiTokens.actionTextSize,
          color: textColor,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
