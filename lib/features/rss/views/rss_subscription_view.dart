import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/cupertino.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/theme/design_tokens.dart';
import '../../../app/widgets/app_toast.dart';
import '../../../app/widgets/app_action_list_sheet.dart';
import '../../../app/widgets/app_cupertino_page_scaffold.dart';
import '../../../app/widgets/app_empty_state.dart';
import '../../../app/widgets/app_manage_search_field.dart';
import '../../../app/widgets/app_nav_bar_button.dart';
import '../../../app/widgets/cupertino_bottom_dialog.dart';
import '../../../core/database/database_service.dart';
import '../../../core/database/repositories/rss_source_repository.dart';
import '../../../core/services/exception_log_service.dart';
import '../../../core/services/source_variable_store.dart';
import '../models/rss_source.dart';
import '../services/rss_source_manage_helper.dart';
import '../services/rss_subscription_helper.dart';
import 'rss_articles_placeholder_view.dart';
import 'rule_subscription_view.dart';
import 'rss_source_edit_view.dart';
import 'rss_source_manage_view.dart';

class RssSubscriptionView extends StatefulWidget {
  const RssSubscriptionView({
    super.key,
    this.repository,
    this.reselectSignal,
  });

  final RssSourceRepository? repository;
  final ValueListenable<int>? reselectSignal;

  @override
  State<RssSubscriptionView> createState() => _RssSubscriptionViewState();
}

enum _RssSubscriptionSourceAction {
  moveToTop,
  edit,
  disable,
  delete,
}

class _RssSubscriptionViewState extends State<RssSubscriptionView> {
  late final RssSourceRepository _repo;
  final TextEditingController _queryController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  int? _lastReselectVersion;

  @override
  void initState() {
    super.initState();
    _repo = widget.repository ?? RssSourceRepository(DatabaseService());
    _bindReselectSignal(widget.reselectSignal);
  }

  @override
  void didUpdateWidget(covariant RssSubscriptionView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reselectSignal == widget.reselectSignal) return;
    _unbindReselectSignal(oldWidget.reselectSignal);
    _bindReselectSignal(widget.reselectSignal);
  }

  @override
  void dispose() {
    _unbindReselectSignal(widget.reselectSignal);
    _queryController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _bindReselectSignal(ValueListenable<int>? signal) {
    _lastReselectVersion = signal?.value;
    signal?.addListener(_onReselectSignalChanged);
  }

  void _unbindReselectSignal(ValueListenable<int>? signal) {
    signal?.removeListener(_onReselectSignalChanged);
  }

  void _onReselectSignalChanged() {
    final signal = widget.reselectSignal;
    if (signal == null) return;
    final version = signal.value;
    if (_lastReselectVersion == version) return;
    _lastReselectVersion = version;
    _scrollToTop();
  }

  void _scrollToTop() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  String get _query => _queryController.text.trim();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<RssSource>>(
      stream: _repo.watchAllSources(),
      builder: (context, snapshot) {
        final allSources = snapshot.data ?? _repo.getAllSources();
        final enabledCount = allSources.where((e) => e.enabled).length;
        final visible = RssSubscriptionHelper.filterEnabledSourcesByQuery(
          allSources,
          _query,
        );

        return AppCupertinoPageScaffold(
          title: '订阅',
          useSliverNavigationBar: true,
          sliverScrollController: _scrollController,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppNavBarButton(
                onPressed: _openFavorites,
                child: const Icon(CupertinoIcons.star),
              ),
              AppNavBarButton(
                onPressed: _openGroupMenu,
                child: const Icon(CupertinoIcons.folder),
              ),
              AppNavBarButton(
                onPressed: _openSourceSettings,
                child: const Icon(CupertinoIcons.settings),
              ),
            ],
          ),
          child: const SizedBox.shrink(),
          sliverBodyBuilder: (_) => _buildBodySliver(
            enabledCount: enabledCount,
            visible: visible,
          ),
        );
      },
    );
  }

  Widget _buildBodySliver({
    required int enabledCount,
    required List<RssSource> visible,
  }) {
    final searchField = Padding(
      padding: AppManageSearchField.outerPadding,
      child: AppManageSearchField(
        controller: _queryController,
        placeholder: '搜索订阅源',
        onChanged: (_) => setState(() {}),
      ),
    );

    final summaryRow = Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              _query.isEmpty ? '启用订阅源' : '筛选：$_query',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: CupertinoColors.secondaryLabel.resolveFrom(context),
                fontSize: 12,
              ),
            ),
          ),
          Text(
            '${visible.length} / $enabledCount',
            style: TextStyle(
              color: CupertinoColors.secondaryLabel.resolveFrom(context),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );

    final ruleEntry = _buildRuleSubscriptionEntry();

    if (visible.isEmpty) {
      return SliverSafeArea(
        top: true,
        bottom: true,
        sliver: SliverFillRemaining(
          hasScrollBody: false,
          child: Column(
            children: [
              searchField,
              summaryRow,
              ruleEntry,
              Expanded(child: _buildEmptyState(enabledCount)),
            ],
          ),
        ),
      );
    }

    final listPartCount = visible.length * 2 - 1;
    final listStartIndex = 4;
    final bottomSpacerIndex = listStartIndex + listPartCount;

    return SliverSafeArea(
      top: true,
      bottom: true,
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            if (index == 0) return searchField;
            if (index == 1) return summaryRow;
            if (index == 2) return ruleEntry;
            if (index == 3) return const SizedBox(height: 4);
            if (index == bottomSpacerIndex) {
              return const SizedBox(height: 20);
            }

            final local = index - listStartIndex;
            if (local.isOdd) {
              return const SizedBox(height: 8);
            }
            final sourceIndex = local ~/ 2;
            final source = visible[sourceIndex];
            return _buildSourceItem(source);
          },
          childCount: bottomSpacerIndex + 1,
        ),
      ),
    );
  }

  Widget _buildEmptyState(int enabledCount) {
    final noEnabled = enabledCount == 0;
    final title = noEnabled ? '暂无启用订阅源' : '没有匹配结果';
    final action = noEnabled ? '返回订阅源管理' : '清除筛选';
    final message = noEnabled ? '请先在订阅源管理中启用订阅源' : '当前筛选条件下暂无结果';
    return AppEmptyState(
      illustration: const AppEmptyPlanetIllustration(size: 84),
      title: title,
      message: message,
      action: CupertinoButton(
        onPressed: noEnabled ? _openSourceSettings : () => _setQuery(''),
        child: Text(action),
      ),
    );
  }

  Widget _buildRuleSubscriptionEntry() {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      decoration: BoxDecoration(
        color: CupertinoColors.secondarySystemGroupedBackground.resolveFrom(context)
            .resolveFrom(context),
        borderRadius: BorderRadius.circular(AppDesignTokens.radiusCard),
      ),
      child: CupertinoListTile.notched(
        leading: const Icon(CupertinoIcons.square_list),
        title: const Text('规则订阅'),
        additionalInfo: Text(
          '导入地址',
          style: TextStyle(
            fontSize: 12,
            color: CupertinoColors.secondaryLabel.resolveFrom(context),
          ),
        ),
        trailing: const CupertinoListTileChevron(),
        onTap: _openRuleSubscription,
      ),
    );
  }

  Widget _buildSourceItem(RssSource source) {
    return GestureDetector(
      onLongPress: () => _showSourceActions(source),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: CupertinoColors.secondarySystemGroupedBackground.resolveFrom(context)
              .resolveFrom(context),
          borderRadius: BorderRadius.circular(AppDesignTokens.radiusCard),
        ),
        child: CupertinoListTile.notched(
          leading: _buildSourceIcon(source),
          title: Text(source.sourceName),
          subtitle: source.sourceGroup?.trim().isNotEmpty == true
              ? Text(
                  source.sourceGroup!.trim(),
                  style: TextStyle(
                    fontSize: 12,
                    color: CupertinoColors.secondaryLabel.resolveFrom(context),
                  ),
                )
              : null,
          trailing: CupertinoSwitch(
            value: source.enabled,
            onChanged: (v) => _toggleSourceEnabled(source, v),
          ),
          onTap: () => _openSource(source),
        ),
      ),
    );
  }

  Widget _buildSourceIcon(RssSource source) {
    final iconUrl = source.sourceIcon.trim();
    if (iconUrl.isEmpty) {
      return _defaultIcon();
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: Image.network(
        iconUrl,
        width: 34,
        height: 34,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _defaultIcon(),
      ),
    );
  }

  Widget _defaultIcon() {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: CupertinoColors.systemGrey5.resolveFrom(context),
        borderRadius: BorderRadius.circular(6),
      ),
      alignment: Alignment.center,
      child: const Icon(CupertinoIcons.dot_radiowaves_left_right, size: 18),
    );
  }

  void _setQuery(String value) {
    _queryController.text = value;
    _queryController.selection = TextSelection.collapsed(offset: value.length);
    setState(() {});
  }

  Future<void> _openGroupMenu() async {
    final groups = RssSubscriptionHelper.enabledGroups(_repo.getAllSources());
    if (!mounted || groups.isEmpty) return;
    final query = _query;
    final currentGroup = query.startsWith(RssSubscriptionHelper.groupPrefix)
        ? query.substring(RssSubscriptionHelper.groupPrefix.length).trim()
        : '';
    final items = groups.map((group) {
      final isCurrent = currentGroup == group;
      return AppActionListItem<String>(
        value: group,
        icon: isCurrent
            ? CupertinoIcons.check_mark_circled_solid
            : CupertinoIcons.folder,
        label: isCurrent ? '✓ $group' : group,
      );
    }).toList(growable: false);
    final selectedGroup = await showAppActionListSheet<String>(
      context: context,
      title: '分组',
      showCancel: true,
      items: items,
    );
    if (selectedGroup == null || !mounted) return;
    _setQuery(RssSubscriptionHelper.buildGroupQuery(selectedGroup));
  }

  Future<void> _openFavorites() async {
    if (!mounted) return;
    await Navigator.of(context).push<void>(
      CupertinoPageRoute<void>(
        builder: (_) => const RssFavoritesPlaceholderView(),
      ),
    );
  }

  Future<void> _openRuleSubscription() async {
    if (!mounted) return;
    await Navigator.of(context).push<void>(
      CupertinoPageRoute<void>(
        builder: (_) => const RuleSubscriptionView(),
      ),
    );
  }

  Future<void> _openSourceSettings() async {
    if (!mounted) return;
    await Navigator.of(context).push<void>(
      CupertinoPageRoute<void>(
        builder: (_) => RssSourceManageView(repository: _repo),
      ),
    );
  }

  Future<void> _toggleSourceEnabled(RssSource source, bool enabled) async {
    final current = _repo.getByKey(source.sourceUrl) ?? source;
    try {
      await _repo.updateSource(current.copyWith(enabled: enabled));
    } catch (_) {}
  }

  Future<void> _openSource(RssSource source) async {
    final decision = RssSubscriptionHelper.decideOpenAction(source);
    switch (decision.action) {
      case RssSubscriptionOpenAction.openArticleList:
        await Navigator.of(context).push<void>(
          CupertinoPageRoute<void>(
            builder: (_) => RssArticlesPlaceholderView(
              sourceName: source.sourceName,
              sourceUrl: decision.url ?? source.sourceUrl,
            ),
          ),
        );
        return;
      case RssSubscriptionOpenAction.openReadDetail:
        await Navigator.of(context).push<void>(
          CupertinoPageRoute<void>(
            builder: (_) => RssReadPlaceholderView(
              title: source.sourceName,
              origin: decision.url ?? '',
            ),
          ),
        );
        return;
      case RssSubscriptionOpenAction.openExternal:
        await _openExternal(decision.url ?? '');
        return;
      case RssSubscriptionOpenAction.showError:
        _showToast(decision.message ?? '打开失败');
        return;
    }
  }

  Future<void> _openExternal(String target) async {
    final url = target.trim();
    if (url.isEmpty) {
      _showToast('目标链接为空');
      return;
    }
    final uri = Uri.tryParse(url);
    if (uri == null || uri.scheme.isEmpty) {
      _showToast('目标链接无效：$url');
      return;
    }
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok) {
      _showToast('无法打开外部链接');
    }
  }

  Future<void> _showSourceActions(RssSource source) async {
    if (!mounted) return;
    final selected = await showAppActionListSheet<_RssSubscriptionSourceAction>(
      context: context,
      title: source.sourceName,
      showCancel: true,
      items: const [
        AppActionListItem<_RssSubscriptionSourceAction>(
          value: _RssSubscriptionSourceAction.moveToTop,
          icon: CupertinoIcons.arrow_up_circle,
          label: '置顶',
        ),
        AppActionListItem<_RssSubscriptionSourceAction>(
          value: _RssSubscriptionSourceAction.edit,
          icon: CupertinoIcons.pencil,
          label: '编辑',
        ),
        AppActionListItem<_RssSubscriptionSourceAction>(
          value: _RssSubscriptionSourceAction.disable,
          icon: CupertinoIcons.pause_circle,
          label: '禁用',
        ),
        AppActionListItem<_RssSubscriptionSourceAction>(
          value: _RssSubscriptionSourceAction.delete,
          icon: CupertinoIcons.delete,
          label: '删除',
          isDestructiveAction: true,
        ),
      ],
    );
    if (selected == null || !mounted) return;
    switch (selected) {
      case _RssSubscriptionSourceAction.moveToTop:
        await _moveToTop(source);
        return;
      case _RssSubscriptionSourceAction.edit:
        await _openEditSource(source);
        return;
      case _RssSubscriptionSourceAction.disable:
        await _disableSource(source);
        return;
      case _RssSubscriptionSourceAction.delete:
        await _deleteSource(source);
        return;
    }
  }

  Future<void> _moveToTop(RssSource source) async {
    final sourceUrl = source.sourceUrl.trim();
    if (sourceUrl.isEmpty) return;
    final current = _repo.getByKey(sourceUrl);
    if (current == null) return;
    final updated = RssSourceManageHelper.moveToTop(
      source: current,
      minOrder: _repo.minOrder,
    );
    try {
      await _repo.updateSource(updated);
    } catch (error, stackTrace) {
      ExceptionLogService().record(
        node: 'rss_main_item.menu_top',
        message: 'RSS 主列表置顶失败',
        error: error,
        stackTrace: stackTrace,
        context: <String, dynamic>{
          'sourceUrl': sourceUrl,
          'sourceName': current.sourceName,
          'fromOrder': current.customOrder,
          'toOrder': updated.customOrder,
        },
      );
    }
  }

  Future<void> _openEditSource(RssSource source) async {
    if (!mounted) return;
    await Navigator.of(context).push<void>(
      CupertinoPageRoute<void>(
        builder: (_) => RssSourceEditView(sourceUrl: source.sourceUrl),
      ),
    );
  }

  Future<void> _disableSource(RssSource source) async {
    final sourceUrl = source.sourceUrl.trim();
    if (sourceUrl.isEmpty) return;
    try {
      final current = _repo.getByKey(sourceUrl);
      if (current == null) return;
      await _repo.updateSource(current.copyWith(enabled: false));
    } catch (error, stackTrace) {
      ExceptionLogService().record(
        node: 'rss_main_item.menu_disable',
        message: 'RSS 主列表禁用源失败',
        error: error,
        stackTrace: stackTrace,
        context: <String, dynamic>{
          'sourceUrl': sourceUrl,
          'sourceName': source.sourceName,
        },
      );
    }
  }

  Future<void> _deleteSource(RssSource source) async {
    if (!mounted) return;
    final confirmed = await showCupertinoBottomDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('提醒'),
        content: Text('确定删除\n${source.sourceName}'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final sourceUrl = source.sourceUrl.trim();
    if (sourceUrl.isEmpty) return;

    final current = _repo.getByKey(sourceUrl);
    if (current == null) return;
    try {
      await _repo.deleteSourceWithArticles(sourceUrl);
      await SourceVariableStore.removeVariable(sourceUrl);
    } catch (error, stackTrace) {
      ExceptionLogService().record(
        node: 'rss_main_item.menu_del',
        message: 'RSS 主列表删除订阅源失败',
        error: error,
        stackTrace: stackTrace,
        context: <String, dynamic>{
          'sourceUrl': sourceUrl,
          'sourceName': current.sourceName,
        },
      );
    }
  }

  void _showToast(String message) {
    if (!mounted) return;
    unawaited(showAppToast(context, message: message));
  }
}
