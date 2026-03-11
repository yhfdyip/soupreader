import 'package:flutter/cupertino.dart';

import '../../../app/theme/design_tokens.dart';
import '../../../app/widgets/app_cupertino_page_scaffold.dart';
import '../../../app/widgets/app_empty_state.dart';
import '../../../app/widgets/cupertino_bottom_dialog.dart';
import '../../../core/database/database_service.dart';
import '../../../core/database/repositories/rss_star_repository.dart';
import '../../../core/services/exception_log_service.dart';
import '../models/rss_star.dart';
import 'rss_read_view.dart';

enum _RssFavoritesMenuAction {
  deleteCurrentGroup,
  deleteAll,
}
class RssFavoritesPlaceholderView extends StatefulWidget {
  const RssFavoritesPlaceholderView({super.key});

  @override
  State<RssFavoritesPlaceholderView> createState() =>
      _RssFavoritesPlaceholderViewState();
}

class _RssFavoritesPlaceholderViewState
    extends State<RssFavoritesPlaceholderView> {
  late final RssStarRepository _repo;
  String _selectedGroup = '';

  @override
  void initState() {
    super.initState();
    _repo = RssStarRepository(DatabaseService());
  }

  String _resolveCurrentGroup(List<String> groups) {
    if (groups.isEmpty) return '';
    final selected = _selectedGroup.trim();
    if (selected.isNotEmpty && groups.contains(selected)) {
      return selected;
    }
    return groups.first;
  }

  void _selectGroup(String group) {
    final next = group.trim();
    if (next.isEmpty || next == _selectedGroup) return;
    setState(() {
      _selectedGroup = next;
    });
  }

  Future<void> _openGroupMenu({
    required List<String> groups,
    required String currentGroup,
  }) async {
    if (!mounted || groups.isEmpty) return;
    await showCupertinoBottomDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (sheetContext) {
        return CupertinoActionSheet(
          title: const Text('分组'),
          actions: [
            for (final group in groups)
              CupertinoActionSheetAction(
                isDefaultAction: group == currentGroup,
                onPressed: () {
                  Navigator.of(sheetContext).pop();
                  _selectGroup(group);
                },
                child: Text(group),
              ),
          ],
          cancelButton: CupertinoActionSheetAction(
            onPressed: () => Navigator.of(sheetContext).pop(),
            child: const Text('取消'),
          ),
        );
      },
    );
  }

  Future<void> _openMoreMenu({
    required String currentGroup,
  }) async {
    if (!mounted) return;
    final selected = await showCupertinoBottomDialog<_RssFavoritesMenuAction>(
      context: context,
      barrierDismissible: true,
      builder: (sheetContext) {
        return CupertinoActionSheet(
          actions: [
            CupertinoActionSheetAction(
              isDestructiveAction: true,
              onPressed: () {
                Navigator.of(sheetContext).pop(
                  _RssFavoritesMenuAction.deleteCurrentGroup,
                );
              },
              child: const Text('删除当前分组'),
            ),
            CupertinoActionSheetAction(
              isDestructiveAction: true,
              onPressed: () {
                Navigator.of(sheetContext).pop(
                  _RssFavoritesMenuAction.deleteAll,
                );
              },
              child: const Text('删除所有'),
            ),
          ],
          cancelButton: CupertinoActionSheetAction(
            onPressed: () => Navigator.of(sheetContext).pop(),
            child: const Text('取消'),
          ),
        );
      },
    );
    if (selected == null) return;
    switch (selected) {
      case _RssFavoritesMenuAction.deleteCurrentGroup:
        await _deleteCurrentGroup(currentGroup);
        break;
      case _RssFavoritesMenuAction.deleteAll:
        await _deleteAllFavorites();
        break;
    }
  }

  Future<void> _deleteCurrentGroup(String currentGroup) async {
    final group = currentGroup.trim();
    if (group.isEmpty || !mounted) return;
    final confirmed = await showCupertinoBottomDialog<bool>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: const Text('提示'),
        content: Text('确定删除\n<$group>分组'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('确定'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _repo.deleteByGroup(group);
    } catch (error, stackTrace) {
      ExceptionLogService().record(
        node: 'rss_favorites.menu_del_group',
        message: '删除 RSS 收藏分组失败',
        error: error,
        stackTrace: stackTrace,
        context: <String, dynamic>{
          'group': group,
        },
      );
    }
  }

  Future<void> _deleteAllFavorites() async {
    if (!mounted) return;
    final confirmed = await showCupertinoBottomDialog<bool>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: const Text('提示'),
        content: const Text('确定删除\n<全部>收藏'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('确定'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _repo.deleteAll();
    } catch (error, stackTrace) {
      ExceptionLogService().record(
        node: 'rss_favorites.menu_del_all',
        message: '删除全部 RSS 收藏失败',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Widget _buildTrailingActions({
    required List<String> groups,
    required String currentGroup,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CupertinoButton(
          padding: EdgeInsets.zero,
          minimumSize: const Size(28, 28),
          onPressed: groups.isEmpty
              ? null
              : () => _openGroupMenu(
                    groups: groups,
                    currentGroup: currentGroup,
                  ),
          child: const Icon(CupertinoIcons.square_grid_2x2, size: 20),
        ),
        CupertinoButton(
          padding: EdgeInsets.zero,
          minimumSize: const Size(28, 28),
          onPressed: () => _openMoreMenu(currentGroup: currentGroup),
          child: const Icon(CupertinoIcons.ellipsis_circle, size: 20),
        ),
      ],
    );
  }

  Future<void> _openRead(RssStar star) async {
    if (!mounted) return;
    await Navigator.of(context).push<void>(
      CupertinoPageRoute<void>(
        builder: (_) => RssReadPlaceholderView(
          title: star.title,
          origin: star.origin,
          link: star.link,
        ),
      ),
    );
  }

  Widget _buildGroupSegmentedControl(
    List<String> groups,
    String currentGroup,
  ) {
    if (groups.length <= 1) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      child: CupertinoSlidingSegmentedControl<String>(
        groupValue: currentGroup,
        children: {
          for (final group in groups)
            group: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Text(
                group,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12),
              ),
            ),
        },
        onValueChanged: (value) {
          if (value == null) return;
          _selectGroup(value);
        },
      ),
    );
  }

  Widget _buildGroupList(String group) {
    return StreamBuilder<List<RssStar>>(
      stream: _repo.watchByGroup(group),
      builder: (context, snapshot) {
        final stars = snapshot.data ?? const <RssStar>[];
        if (stars.isEmpty) {
          return const AppEmptyState(
            illustration: AppEmptyPlanetIllustration(size: 82),
            title: '当前分组暂无收藏',
            message: '可切换其它分组查看',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 20),
          itemCount: stars.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final star = stars[index];
            return GestureDetector(
              onTap: () => _openRead(star),
              child: _RssFavoriteItemCard(star: star),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<String>>(
      stream: _repo.watchGroups(),
      builder: (context, snapshot) {
        final groups = snapshot.data ?? const <String>[];
        final currentGroup = _resolveCurrentGroup(groups);
        return AppCupertinoPageScaffold(
          title: '收藏夹',
          trailing: _buildTrailingActions(
            groups: groups,
            currentGroup: currentGroup,
          ),
          child: Column(
            children: [
              _buildGroupSegmentedControl(groups, currentGroup),
              if (currentGroup.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '当前分组：$currentGroup',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: CupertinoColors.secondaryLabel.resolveFrom(context)
                                .resolveFrom(context),
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: currentGroup.isEmpty
                    ? const AppEmptyState(
                        illustration: AppEmptyPlanetIllustration(size: 82),
                        title: '暂无收藏',
                        message: '添加收藏后会显示在这里',
                      )
                    : _buildGroupList(currentGroup),
              ),
            ],
          ),
        );
      },
    );
  }
}


class _RssFavoriteItemCard extends StatelessWidget {
  const _RssFavoriteItemCard({
    required this.star,
  });

  final RssStar star;

  @override
  Widget build(BuildContext context) {
    final imageUrl = (star.image ?? '').trim();
    final pubDate = (star.pubDate ?? '').trim();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: CupertinoColors.secondarySystemGroupedBackground.resolveFrom(
          context,
        ),
        borderRadius: BorderRadius.circular(AppDesignTokens.radiusCard),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (imageUrl.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                imageUrl,
                width: 52,
                height: 52,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _buildFallbackImage(context),
              ),
            )
          else
            _buildFallbackImage(context),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  star.title.trim().isEmpty ? '(无标题)' : star.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  pubDate.isEmpty ? '无发布时间' : pubDate,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: CupertinoColors.secondaryLabel.resolveFrom(context),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFallbackImage(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: CupertinoColors.systemGrey5.resolveFrom(context),
        borderRadius: BorderRadius.circular(8),
      ),
      alignment: Alignment.center,
      child: const Icon(CupertinoIcons.news, size: 18),
    );
  }
}

