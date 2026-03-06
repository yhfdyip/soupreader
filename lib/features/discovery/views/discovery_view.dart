import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../../app/theme/design_tokens.dart';
import '../../../app/theme/source_ui_tokens.dart';
import '../../../app/theme/ui_tokens.dart';
import '../../../app/widgets/app_action_list_sheet.dart';
import '../../../app/widgets/app_cupertino_page_scaffold.dart';
import '../../../app/widgets/app_empty_state.dart';
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
import 'discovery_search_header.dart';
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

enum _DiscoverySourceMenuAction {
  edit,
  moveToTop,
  login,
  search,
  refresh,
  delete,
}

class _DiscoveryViewState extends State<DiscoveryView> {
  static const int _collapsedKindsLimit = 12;
  static const double _minTapSize = SourceUiTokens.minTapSize;
  static const Duration _expandCollapseDuration = AppDesignTokens.motionNormal;

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

  String? _activeGroupFilter(String query) {
    final raw = query.trim();
    if (!raw.startsWith('group:')) return null;
    final group = raw.substring(6).trim();
    if (group.isEmpty) return null;
    return group;
  }

  Future<void> _showGroupFilterMenu() async {
    final groups = _buildGroups(_eligibleSources(_allSources));
    const allToken = '__all__';
    final items = <AppActionListItem<String>>[
      const AppActionListItem<String>(
        value: allToken,
        icon: CupertinoIcons.square_grid_2x2,
        label: '全部',
      ),
      ...groups.map(
        (group) => AppActionListItem<String>(
          value: group,
          icon: CupertinoIcons.folder,
          label: group,
        ),
      ),
    ];
    final selected = await showAppActionListSheet<String>(
      context: context,
      title: '分组',
      showCancel: true,
      items: items,
    );
    if (selected == null || !mounted) return;
    if (selected == allToken) {
      _setQuery('');
      return;
    }
    _setQuery('group:$selected');
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
    HapticFeedback.selectionClick();
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
    HapticFeedback.selectionClick();
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
    final hasLogin = (source.loginUrl ?? '').trim().isNotEmpty;
    final items = <AppActionListItem<_DiscoverySourceMenuAction>>[
      const AppActionListItem<_DiscoverySourceMenuAction>(
        value: _DiscoverySourceMenuAction.edit,
        icon: CupertinoIcons.pencil,
        label: '编辑',
      ),
      const AppActionListItem<_DiscoverySourceMenuAction>(
        value: _DiscoverySourceMenuAction.moveToTop,
        icon: CupertinoIcons.arrow_up_circle,
        label: '置顶',
      ),
      if (hasLogin)
        const AppActionListItem<_DiscoverySourceMenuAction>(
          value: _DiscoverySourceMenuAction.login,
          icon: CupertinoIcons.person_crop_circle,
          label: '登录',
        ),
      const AppActionListItem<_DiscoverySourceMenuAction>(
        value: _DiscoverySourceMenuAction.search,
        icon: CupertinoIcons.search,
        label: '搜索',
      ),
      const AppActionListItem<_DiscoverySourceMenuAction>(
        value: _DiscoverySourceMenuAction.refresh,
        icon: CupertinoIcons.refresh,
        label: '刷新',
      ),
      const AppActionListItem<_DiscoverySourceMenuAction>(
        value: _DiscoverySourceMenuAction.delete,
        icon: CupertinoIcons.delete,
        label: '删除',
        isDestructiveAction: true,
      ),
    ];
    final selected = await showAppActionListSheet<_DiscoverySourceMenuAction>(
      context: context,
      title: source.bookSourceName,
      message: source.bookSourceUrl,
      showCancel: true,
      items: items,
    );
    if (selected == null || !mounted) return;
    switch (selected) {
      case _DiscoverySourceMenuAction.edit:
        await _openEditor(source.bookSourceUrl);
        return;
      case _DiscoverySourceMenuAction.moveToTop:
        await _toTop(source.bookSourceUrl);
        return;
      case _DiscoverySourceMenuAction.login:
        await _openSourceLogin(source);
        return;
      case _DiscoverySourceMenuAction.search:
        await _searchInSource(source);
        return;
      case _DiscoverySourceMenuAction.refresh:
        await _refreshSourceKinds(source);
        return;
      case _DiscoverySourceMenuAction.delete:
        await _confirmDeleteSource(source);
        return;
    }
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
    final ok = await showCupertinoBottomDialog<bool>(
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
    showCupertinoBottomDialog<void>(
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
      trailing: AppNavBarButton(
        onPressed: _showGroupFilterMenu,
        child: const Icon(CupertinoIcons.slider_horizontal_3, size: 22),
      ),
      child: _buildBody(
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
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            _initError ?? '初始化失败',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }

  Widget _buildBody({
    required List<BookSource> eligible,
    required List<BookSource> visible,
    required String query,
    required bool showEmptyMessage,
  }) {
    final uiTokens = AppUiTokens.resolve(context);

    final header = _buildSearchHeader(
      visibleCount: visible.length,
      query: query,
      uiTokens: uiTokens,
    );

    return Column(
      children: [
        header,
        Expanded(
          child: Stack(
            children: [
              ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.only(bottom: 12),
                itemCount: visible.length,
                itemBuilder: (context, index) {
                  final source = visible[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: _buildSourceItem(source),
                  );
                },
              ),
              if (showEmptyMessage)
                Positioned.fill(
                  child: _buildEmptyState(
                    eligibleCount: eligible.length,
                    query: query,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSearchHeader({
    required int visibleCount,
    required String query,
    required AppUiTokens uiTokens,
  }) {
    final activeGroup = _activeGroupFilter(query);

    return DiscoverySearchHeader(
      controller: _searchController,
      searchFocusNode: _searchFocusNode,
      query: query,
      visibleCount: visibleCount,
      onClear: _clearQuery,
      activeFilterChip: activeGroup == null
          ? null
          : _buildGroupFilterChip(
              uiTokens: uiTokens,
              theme: CupertinoTheme.of(context),
              activeGroup: activeGroup,
            ),
    );
  }

  Widget _buildGroupFilterChip({
    required AppUiTokens uiTokens,
    required CupertinoThemeData theme,
    required String activeGroup,
  }) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: uiTokens.colors.accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(uiTokens.radii.control),
        border: Border.all(
          color: uiTokens.colors.accent.withValues(alpha: 0.28),
          width: SourceUiTokens.borderWidth,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
        child: Text(
          '分组：$activeGroup',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.textStyle.copyWith(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.2,
            color: uiTokens.colors.accent,
          ),
        ),
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
    final model = _buildSourceItemModel(source, uiTokens);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: SourceConsistentCard(
        borderColor: model.cardBorderColor,
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSourceItemHeader(
              source: source,
              expanded: model.expanded,
              groupText: model.groupText,
              theme: theme,
              uiTokens: uiTokens,
              secondaryLabel: model.secondaryLabel,
            ),
            AnimatedSize(
              duration: _expandCollapseDuration,
              curve: Curves.easeOutQuart,
              alignment: Alignment.topCenter,
              clipBehavior: Clip.hardEdge,
              child: model.expanded
                  ? _buildExpandedKindsSection(
                      source: source,
                      sourceUrl: model.sourceUrl,
                      loadingKinds: model.loadingKinds,
                      kinds: model.kinds,
                      visibleKinds: model.visibleKinds,
                      hasHiddenKinds: model.hasHiddenKinds,
                      kindsExpanded: model.kindsExpanded,
                      theme: theme,
                      uiTokens: uiTokens,
                      secondaryLabel: model.secondaryLabel,
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  _DiscoverySourceItemModel _buildSourceItemModel(
    BookSource source,
    AppUiTokens uiTokens,
  ) {
    final secondaryLabel = uiTokens.colors.secondaryLabel;
    final sourceUrl = source.bookSourceUrl;
    final kinds = _sourceKindsCache[sourceUrl] ?? const <SourceExploreKind>[];
    final expanded = _expandedSourceUrl == sourceUrl;
    final kindsExpanded = _expandedKindsSources.contains(sourceUrl);
    final visibleKinds = kindsExpanded || kinds.length <= _collapsedKindsLimit
        ? kinds
        : kinds.take(_collapsedKindsLimit).toList(growable: false);
    final hasHiddenKinds = visibleKinds.length < kinds.length;
    final cardBorderColor = expanded
        ? uiTokens.colors.accent
            .withValues(alpha: SourceUiTokens.discoveryExpandedCardBorderAlpha)
        : null;
    return _DiscoverySourceItemModel(
      sourceUrl: sourceUrl,
      expanded: expanded,
      loadingKinds: _loadingKindsSources.contains(sourceUrl),
      kindsExpanded: kindsExpanded,
      kinds: kinds,
      visibleKinds: visibleKinds,
      hasHiddenKinds: hasHiddenKinds,
      groupText: (source.bookSourceGroup ?? '').trim(),
      secondaryLabel: secondaryLabel,
      cardBorderColor: cardBorderColor,
    );
  }

  Widget _buildSourceItemHeader({
    required BookSource source,
    required bool expanded,
    required String groupText,
    required CupertinoThemeData theme,
    required AppUiTokens uiTokens,
    required Color secondaryLabel,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _toggleSource(source),
      onLongPress: () => _showSourceActions(source),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: _minTapSize),
        child: Row(
          children: [
            Expanded(
              child: _buildSourceInfoBlock(
                source: source,
                groupText: groupText,
                theme: theme,
                uiTokens: uiTokens,
                secondaryLabel: secondaryLabel,
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              expanded
                  ? CupertinoIcons.chevron_down
                  : CupertinoIcons.chevron_forward,
              size: 16,
              color: expanded
                  ? uiTokens.colors.accent
                  : uiTokens.colors.mutedForeground,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSourceInfoBlock({
    required BookSource source,
    required String groupText,
    required CupertinoThemeData theme,
    required AppUiTokens uiTokens,
    required Color secondaryLabel,
  }) {
    return Column(
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
    );
  }

  Widget _buildExpandedKindsSection({
    required BookSource source,
    required String sourceUrl,
    required bool loadingKinds,
    required List<SourceExploreKind> kinds,
    required List<SourceExploreKind> visibleKinds,
    required bool hasHiddenKinds,
    required bool kindsExpanded,
    required CupertinoThemeData theme,
    required AppUiTokens uiTokens,
    required Color secondaryLabel,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: SourceUiTokens.discoveryCardInnerGap),
        Container(
          height: SourceUiTokens.borderWidth,
          color: uiTokens.colors.separator.withValues(alpha: 0.55),
        ),
        const SizedBox(height: SourceUiTokens.discoveryCardInnerGap),
        _buildExpandedKindsBody(
          source: source,
          sourceUrl: sourceUrl,
          loadingKinds: loadingKinds,
          kinds: kinds,
          visibleKinds: visibleKinds,
          hasHiddenKinds: hasHiddenKinds,
          kindsExpanded: kindsExpanded,
          theme: theme,
          uiTokens: uiTokens,
          secondaryLabel: secondaryLabel,
        ),
      ],
    );
  }

  Widget _buildExpandedKindsBody({
    required BookSource source,
    required String sourceUrl,
    required bool loadingKinds,
    required List<SourceExploreKind> kinds,
    required List<SourceExploreKind> visibleKinds,
    required bool hasHiddenKinds,
    required bool kindsExpanded,
    required CupertinoThemeData theme,
    required AppUiTokens uiTokens,
    required Color secondaryLabel,
  }) {
    if (loadingKinds) {
      return _buildLoadingKindsRow(
          theme: theme, secondaryLabel: secondaryLabel);
    }
    if (kinds.isEmpty) {
      return Text(
        '暂无发现入口',
        style: theme.textTheme.textStyle.copyWith(
          fontSize: SourceUiTokens.discoveryMetaTextSize,
          color: secondaryLabel,
        ),
      );
    }
    return _buildKindsWrap(
      source: source,
      sourceUrl: sourceUrl,
      kinds: kinds,
      visibleKinds: visibleKinds,
      hasHiddenKinds: hasHiddenKinds,
      kindsExpanded: kindsExpanded,
      theme: theme,
      uiTokens: uiTokens,
    );
  }

  Widget _buildLoadingKindsRow({
    required CupertinoThemeData theme,
    required Color secondaryLabel,
  }) {
    return Row(
      children: [
        const CupertinoActivityIndicator(),
        const SizedBox(width: 8),
        Text(
          '正在加载发现入口…',
          style: theme.textTheme.textStyle.copyWith(
            fontSize: SourceUiTokens.discoveryMetaTextSize,
            color: secondaryLabel,
          ),
        ),
      ],
    );
  }

  Widget _buildKindsWrap({
    required BookSource source,
    required String sourceUrl,
    required List<SourceExploreKind> kinds,
    required List<SourceExploreKind> visibleKinds,
    required bool hasHiddenKinds,
    required bool kindsExpanded,
    required CupertinoThemeData theme,
    required AppUiTokens uiTokens,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        final chips = _buildKindWidgets(
          source: source,
          kinds: kinds,
          visibleKinds: visibleKinds,
          hasHiddenKinds: hasHiddenKinds,
          kindsExpanded: kindsExpanded,
          sourceUrl: sourceUrl,
          maxWidth: maxWidth,
          theme: theme,
          uiTokens: uiTokens,
        );
        return Wrap(
          spacing: SourceUiTokens.discoveryHeaderGap,
          runSpacing: SourceUiTokens.discoveryHeaderGap,
          children: chips,
        );
      },
    );
  }

  List<Widget> _buildKindWidgets({
    required BookSource source,
    required List<SourceExploreKind> kinds,
    required List<SourceExploreKind> visibleKinds,
    required bool hasHiddenKinds,
    required bool kindsExpanded,
    required String sourceUrl,
    required double maxWidth,
    required CupertinoThemeData theme,
    required AppUiTokens uiTokens,
  }) {
    final chips = <Widget>[];
    for (final kind in visibleKinds) {
      if (kind.style?.layoutWrapBefore == true) {
        chips.add(SizedBox(width: maxWidth, height: 0));
      }
      final width = _kindWidth(kind.style, maxWidth);
      final chip = _buildKindChip(
        source,
        kind,
        theme: theme,
        uiTokens: uiTokens,
      );
      chips.add(width == null ? chip : SizedBox(width: width, child: chip));
    }
    if (hasHiddenKinds || kindsExpanded) {
      chips.add(
        _buildKindsToggleChip(
          expanded: kindsExpanded,
          hiddenCount: kinds.length - visibleKinds.length,
          theme: theme,
          uiTokens: uiTokens,
          onTap: () => _toggleKindsExpanded(sourceUrl),
        ),
      );
    }
    return chips;
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
    final borderColor = uiTokens.colors.separator.withValues(alpha: 0.62);
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
    final tapHandler = onTap == null
        ? null
        : () {
            HapticFeedback.lightImpact();
            onTap();
          };
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: tapHandler,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: _minTapSize),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(uiTokens.radii.control),
            border: Border.all(
              color: borderColor,
              width: SourceUiTokens.borderWidth,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: SourceUiTokens.discoveryChipHorizontalPadding,
              vertical: SourceUiTokens.discoveryChipVerticalPadding,
            ),
            child: child,
          ),
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
            : uiTokens.colors.tertiaryLabel;
    final clickableBorderColor =
        uiTokens.colors.accent.withValues(alpha: isEnabled ? 0.34 : 0.0);
    final resolvedBorderColor = isError
        ? borderColor
        : isEnabled
            ? clickableBorderColor
            : borderColor;

    return _buildKindPill(
      onTap: isEnabled ? () => _openExploreKind(source, kind) : null,
      uiTokens: uiTokens,
      backgroundColor: backgroundColor,
      borderColor: resolvedBorderColor,
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

@immutable
class _DiscoverySourceItemModel {
  const _DiscoverySourceItemModel({
    required this.sourceUrl,
    required this.expanded,
    required this.loadingKinds,
    required this.kindsExpanded,
    required this.kinds,
    required this.visibleKinds,
    required this.hasHiddenKinds,
    required this.groupText,
    required this.secondaryLabel,
    required this.cardBorderColor,
  });

  final String sourceUrl;
  final bool expanded;
  final bool loadingKinds;
  final bool kindsExpanded;
  final List<SourceExploreKind> kinds;
  final List<SourceExploreKind> visibleKinds;
  final bool hasHiddenKinds;
  final String groupText;
  final Color secondaryLabel;
  final Color? cardBorderColor;
}
