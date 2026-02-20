import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/widgets/app_cupertino_page_scaffold.dart';
import '../../../core/database/database_service.dart';
import '../../../core/database/repositories/rss_source_repository.dart';
import '../models/rss_source.dart';
import '../services/rss_source_manage_helper.dart';
import '../services/rss_subscription_helper.dart';
import 'rss_articles_placeholder_view.dart';
import 'rss_source_edit_view.dart';
import 'rss_source_manage_view.dart';

class RssSubscriptionView extends StatefulWidget {
  const RssSubscriptionView({
    super.key,
    this.repository,
  });

  final RssSourceRepository? repository;

  @override
  State<RssSubscriptionView> createState() => _RssSubscriptionViewState();
}

class _RssSubscriptionViewState extends State<RssSubscriptionView> {
  late final RssSourceRepository _repo;
  final TextEditingController _queryController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _repo = widget.repository ?? RssSourceRepository(DatabaseService());
  }

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  String get _query => _queryController.text.trim();

  @override
  Widget build(BuildContext context) {
    return AppCupertinoPageScaffold(
      title: '订阅',
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CupertinoButton(
            padding: EdgeInsets.zero,
            minimumSize: const Size(28, 28),
            onPressed: _openFavorites,
            child: const Icon(CupertinoIcons.star),
          ),
          CupertinoButton(
            padding: EdgeInsets.zero,
            minimumSize: const Size(28, 28),
            onPressed: _openGroupFilterSheet,
            child: const Icon(CupertinoIcons.folder),
          ),
          CupertinoButton(
            padding: EdgeInsets.zero,
            minimumSize: const Size(28, 28),
            onPressed: _openSourceSettings,
            child: const Icon(CupertinoIcons.settings),
          ),
        ],
      ),
      child: StreamBuilder<List<RssSource>>(
        stream: _repo.watchAllSources(),
        builder: (context, snapshot) {
          final allSources = snapshot.data ?? _repo.getAllSources();
          final enabledCount = allSources.where((e) => e.enabled).length;
          final visible = RssSubscriptionHelper.filterEnabledSourcesByQuery(
            allSources,
            _query,
          );
          final groups = RssSubscriptionHelper.enabledGroups(allSources);

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                child: CupertinoSearchTextField(
                  controller: _queryController,
                  placeholder: '搜索订阅源',
                  onChanged: (_) => setState(() {}),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _query.isEmpty ? '启用订阅源' : '筛选：$_query',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: CupertinoColors.secondaryLabel,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    Text(
                      '${visible.length} / $enabledCount',
                      style: const TextStyle(
                        color: CupertinoColors.secondaryLabel,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: visible.isEmpty
                    ? _buildEmptyState(enabledCount)
                    : _buildList(visible, groups),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(int enabledCount) {
    final noEnabled = enabledCount == 0;
    final title = noEnabled ? '暂无启用订阅源' : '没有匹配结果';
    final action = noEnabled ? '返回订阅源管理' : '清除筛选';
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: const TextStyle(color: CupertinoColors.secondaryLabel),
          ),
          const SizedBox(height: 10),
          CupertinoButton(
            onPressed: noEnabled
                ? () => Navigator.of(context).maybePop()
                : () => _setQuery(''),
            child: Text(action),
          ),
        ],
      ),
    );
  }

  Widget _buildList(List<RssSource> sources, List<String> groups) {
    return ListView.separated(
      padding: const EdgeInsets.only(top: 4, bottom: 20),
      itemCount: sources.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final source = sources[index];
        return GestureDetector(
          onLongPress: () => _showSourceActions(source, groups),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: CupertinoColors.secondarySystemGroupedBackground
                  .resolveFrom(context),
              borderRadius: BorderRadius.circular(12),
            ),
            child: CupertinoListTile.notched(
              leading: _buildSourceIcon(source),
              title: Text(source.sourceName),
              subtitle: source.sourceGroup?.trim().isNotEmpty == true
                  ? Text(
                      source.sourceGroup!.trim(),
                      style: const TextStyle(
                        fontSize: 12,
                        color: CupertinoColors.secondaryLabel,
                      ),
                    )
                  : null,
              additionalInfo: Text(
                source.sourceUrl,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12),
              ),
              onTap: () => _openSource(source),
            ),
          ),
        );
      },
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

  Future<void> _openGroupFilterSheet() async {
    final groups = RssSubscriptionHelper.enabledGroups(_repo.getAllSources());
    if (!mounted) return;
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: const Text('分组筛选'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(ctx).pop();
              _setQuery('');
            },
            child: const Text('全部'),
          ),
          for (final group in groups)
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.of(ctx).pop();
                _setQuery(RssSubscriptionHelper.buildGroupQuery(group));
              },
              child: Text(group),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('取消'),
        ),
      ),
    );
  }

  Future<void> _openFavorites() async {
    if (!mounted) return;
    await Navigator.of(context).push<void>(
      CupertinoPageRoute<void>(
        builder: (_) => const RssFavoritesPlaceholderView(),
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

  Future<void> _showSourceActions(
    RssSource source,
    List<String> groups,
  ) async {
    if (!mounted) return;
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: Text(source.sourceName),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(ctx).pop();
              _moveToTop(source);
            },
            child: const Text('置顶'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(ctx).pop();
              _openEditSource(source);
            },
            child: const Text('编辑'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(ctx).pop();
              _disableSource(source);
            },
            child: const Text('禁用'),
          ),
          if (groups.isNotEmpty)
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.of(ctx).pop();
                _openGroupFilterSheet();
              },
              child: Text('分组筛选 (${groups.length})'),
            ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.of(ctx).pop();
              _deleteSource(source);
            },
            child: const Text('删除'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('取消'),
        ),
      ),
    );
  }

  Future<void> _moveToTop(RssSource source) async {
    final updated = RssSourceManageHelper.moveToTop(
      source: source,
      minOrder: _repo.minOrder,
    );
    await _repo.updateSource(updated);
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
    final updated = source.copyWith(enabled: false);
    await _repo.updateSource(updated);
  }

  Future<void> _deleteSource(RssSource source) async {
    if (!mounted) return;
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('删除订阅源'),
        content: Text('\n确定删除：${source.sourceName}'),
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
    if (confirmed == true) {
      await _repo.deleteSource(source.sourceUrl);
    }
  }

  void _showToast(String message) {
    if (!mounted) return;
    showCupertinoModalPopup<void>(
      context: context,
      barrierColor: CupertinoColors.black.withValues(alpha: 0.08),
      builder: (toastContext) {
        final navigator = Navigator.of(toastContext);
        unawaited(Future<void>.delayed(const Duration(milliseconds: 1100), () {
          if (navigator.mounted && navigator.canPop()) {
            navigator.pop();
          }
        }));
        return SafeArea(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              margin: const EdgeInsets.only(bottom: 28),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: CupertinoColors.systemBackground
                    .resolveFrom(context)
                    .withValues(alpha: 0.96),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: CupertinoColors.separator.resolveFrom(context),
                ),
              ),
              child: Text(
                message,
                style: TextStyle(
                  color: CupertinoColors.label.resolveFrom(context),
                  fontSize: 13,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
