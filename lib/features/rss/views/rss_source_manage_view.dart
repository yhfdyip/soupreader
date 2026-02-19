import 'package:flutter/cupertino.dart';

import '../../../app/widgets/app_cupertino_page_scaffold.dart';
import '../../../core/database/database_service.dart';
import '../../../core/database/repositories/rss_source_repository.dart';
import '../models/rss_source.dart';
import '../services/rss_source_manage_helper.dart';
import 'rss_group_manage_view.dart';
import 'rss_subscription_view.dart';
import 'rss_source_edit_view.dart';

class RssSourceManageView extends StatefulWidget {
  const RssSourceManageView({super.key});

  @override
  State<RssSourceManageView> createState() => _RssSourceManageViewState();
}

class _RssSourceManageViewState extends State<RssSourceManageView> {
  late final RssSourceRepository _repo;
  final TextEditingController _queryController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _repo = RssSourceRepository(DatabaseService());
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
      title: '订阅源管理',
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CupertinoButton(
            padding: EdgeInsets.zero,
            minimumSize: const Size(28, 28),
            onPressed: _openSubscriptions,
            child: const Icon(CupertinoIcons.dot_radiowaves_left_right),
          ),
          CupertinoButton(
            padding: EdgeInsets.zero,
            minimumSize: const Size(28, 28),
            onPressed: _openAddSource,
            child: const Icon(CupertinoIcons.add),
          ),
          CupertinoButton(
            padding: EdgeInsets.zero,
            minimumSize: const Size(28, 28),
            onPressed: _openQuickFilterSheet,
            child: const Icon(CupertinoIcons.folder),
          ),
        ],
      ),
      child: StreamBuilder<List<RssSource>>(
        stream: _repo.watchAllSources(),
        builder: (context, snapshot) {
          final allSources = snapshot.data ?? _repo.getAllSources();
          final intent = RssSourceManageHelper.parseQueryIntent(_query);
          final visible = RssSourceManageHelper.applyQueryIntent(
            allSources,
            intent,
          );
          final groups = _repo.allGroups();

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
                        _query.isEmpty ? '全部源' : '筛选：${intent.rawQuery}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: CupertinoColors.secondaryLabel,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    Text(
                      '${visible.length} 条',
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
                    ? _buildEmptyState()
                    : _buildList(visible, groups),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    final noData = _repo.size == 0;
    final title = noData ? '暂无订阅源' : '没有匹配结果';
    final action = noData ? '新增订阅源' : '清除筛选';
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
            onPressed: noData ? _openAddSource : () => _setQuery(''),
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
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: CupertinoColors.secondarySystemGroupedBackground
                .resolveFrom(context),
            borderRadius: BorderRadius.circular(12),
          ),
          child: CupertinoListTile.notched(
            title: Text(source.getDisplayNameGroup()),
            additionalInfo: Text(
              source.sourceUrl,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CupertinoSwitch(
                  value: source.enabled,
                  onChanged: (value) => _updateEnabled(source, value),
                ),
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(28, 28),
                  onPressed: () => _showSourceActions(source, groups),
                  child: const Icon(CupertinoIcons.ellipsis_circle, size: 20),
                ),
              ],
            ),
            onTap: () => _openEditSource(source),
          ),
        );
      },
    );
  }

  void _setQuery(String value) {
    _queryController.text = value;
    _queryController.selection = TextSelection.collapsed(offset: value.length);
    setState(() {});
  }

  Future<void> _openAddSource() async {
    if (!mounted) return;
    await Navigator.of(context).push<bool>(
      CupertinoPageRoute<bool>(
        builder: (_) => const RssSourceEditView(),
      ),
    );
  }

  Future<void> _openSubscriptions() async {
    if (!mounted) return;
    await Navigator.of(context).push<void>(
      CupertinoPageRoute<void>(
        builder: (_) => RssSubscriptionView(repository: _repo),
      ),
    );
  }

  Future<void> _openEditSource(RssSource source) async {
    if (!mounted) return;
    await Navigator.of(context).push<bool>(
      CupertinoPageRoute<bool>(
        builder: (_) => RssSourceEditView(sourceUrl: source.sourceUrl),
      ),
    );
  }

  Future<void> _openQuickFilterSheet() async {
    final groups = _repo.allGroups();
    if (!mounted) return;
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: const Text('筛选与分组'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(ctx).pop();
              _setQuery('');
            },
            child: const Text('全部'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(ctx).pop();
              _setQuery('启用');
            },
            child: const Text('启用'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(ctx).pop();
              _setQuery('禁用');
            },
            child: const Text('禁用'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(ctx).pop();
              _setQuery('需登录');
            },
            child: const Text('需登录'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(ctx).pop();
              _setQuery('未分组');
            },
            child: const Text('未分组'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).push(
                CupertinoPageRoute<void>(
                  builder: (_) => RssGroupManageView(repository: _repo),
                ),
              );
            },
            child: const Text('分组管理'),
          ),
          for (final group in groups)
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.of(ctx).pop();
                _setQuery('${RssSourceManageHelper.groupPrefix}$group');
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
              _openEditSource(source);
            },
            child: const Text('编辑'),
          ),
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
              _moveToBottom(source);
            },
            child: const Text('置底'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(ctx).pop();
              _openQuickFilterSheet();
            },
            child: Text(groups.isEmpty ? '筛选与分组' : '筛选与分组 (${groups.length})'),
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

  Future<void> _updateEnabled(RssSource source, bool value) async {
    final updated = source.copyWith(enabled: value);
    await _repo.updateSource(updated);
  }

  Future<void> _moveToTop(RssSource source) async {
    final updated = RssSourceManageHelper.moveToTop(
      source: source,
      minOrder: _repo.minOrder,
    );
    await _repo.updateSource(updated);
  }

  Future<void> _moveToBottom(RssSource source) async {
    final updated = RssSourceManageHelper.moveToBottom(
      source: source,
      maxOrder: _repo.maxOrder,
    );
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
}
