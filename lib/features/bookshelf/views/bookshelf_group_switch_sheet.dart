import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart'
    show ReorderableListView, ReorderableDragStartListener;

import '../../../app/widgets/app_sheet_header.dart';
import '../../../app/widgets/cupertino_bottom_dialog.dart';
import '../../../core/services/exception_log_service.dart';
import '../models/bookshelf_book_group.dart';
import '../services/bookshelf_book_group_store.dart';
import 'bookshelf_group_manage_placeholder_dialog.dart';

/// 分组切换底部 sheet（style2 专用）。
///
/// 展示所有分组列表，支持点击切换、编辑模式下删除和拖拽排序、添加新分组。
class BookshelfGroupSwitchSheet extends StatefulWidget {
  const BookshelfGroupSwitchSheet({
    super.key,
    required this.groups,
    required this.selectedGroupId,
    required this.groupStore,
    required this.onGroupSelected,
    required this.onGroupsChanged,
  });

  /// 所有分组（含隐藏分组）。
  final List<BookshelfBookGroup> groups;

  /// 当前选中的分组 ID。
  final int selectedGroupId;

  final BookshelfBookGroupStore groupStore;

  /// 用户点击某个分组时回调，传入选中的 groupId。
  final void Function(int groupId) onGroupSelected;

  /// 分组数据发生变化（增删改排序）后回调，通知外部重新加载。
  final void Function() onGroupsChanged;

  @override
  State<BookshelfGroupSwitchSheet> createState() =>
      _BookshelfGroupSwitchSheetState();
}

class _BookshelfGroupSwitchSheetState
    extends State<BookshelfGroupSwitchSheet> {
  late List<BookshelfBookGroup> _groups;
  bool _isEditing = false;
  bool _adding = false;

  @override
  void initState() {
    super.initState();
    _groups = List<BookshelfBookGroup>.from(widget.groups);
  }

  Future<void> _handleAddGroup() async {
    if (_adding) return;
    bool canAdd = false;
    try {
      canAdd = await widget.groupStore.canAddGroup();
    } catch (error, stackTrace) {
      ExceptionLogService().record(
        node: 'bookshelf.group_switch.add.check_limit_failed',
        message: '检查分组数量上限失败',
        error: error,
        stackTrace: stackTrace,
      );
      if (!mounted) return;
      await _showHint('添加分组失败：$error');
      return;
    }
    if (!canAdd) {
      await _showHint('分组已达上限(64个)');
      return;
    }
    final draft = await _showEditDialog(null);
    if (draft == null || !mounted) return;
    setState(() => _adding = true);
    try {
      await widget.groupStore.addGroup(
        draft.groupName,
        cover: draft.coverPath,
        bookSort: draft.bookSort,
        enableRefresh: draft.enableRefresh,
      );
      await _reloadGroups();
    } catch (error, stackTrace) {
      ExceptionLogService().record(
        node: 'bookshelf.group_switch.add.failed',
        message: '添加分组失败',
        error: error,
        stackTrace: stackTrace,
      );
      if (!mounted) return;
      await _showHint('添加分组失败：$error');
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  Future<void> _handleDeleteGroup(BookshelfBookGroup group) async {
    final confirmed = await showCupertinoBottomDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('删除分组'),
        content: Text('\n确定要删除分组「${group.groupName}」吗？书籍不会被删除。'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await widget.groupStore.deleteGroup(group.groupId);
      await _reloadGroups();
    } catch (error, stackTrace) {
      ExceptionLogService().record(
        node: 'bookshelf.group_switch.delete.failed',
        message: '删除分组失败',
        error: error,
        stackTrace: stackTrace,
      );
      if (!mounted) return;
      await _showHint('删除分组失败：$error');
    }
  }

  Future<void> _handleReorder(int oldIndex, int newIndex) async {
    final mutable = List<BookshelfBookGroup>.from(_groups);
    final moved = mutable.removeAt(oldIndex);
    final insertAt = newIndex > oldIndex ? newIndex - 1 : newIndex;
    mutable.insert(insertAt, moved);
    var customOrder = 0;
    final reordered = mutable.map((g) {
      if (g.isCustomGroup) {
        return g.copyWith(order: customOrder++);
      }
      return g;
    }).toList();
    setState(() => _groups = reordered);
    try {
      await widget.groupStore.saveGroups(reordered);
      widget.onGroupsChanged();
    } catch (error, stackTrace) {
      ExceptionLogService().record(
        node: 'bookshelf.group_switch.reorder.failed',
        message: '分组排序保存失败',
        error: error,
        stackTrace: stackTrace,
      );
      await _reloadGroups();
    }
  }

  Future<void> _reloadGroups() async {
    try {
      final groups = await widget.groupStore.getGroups();
      if (!mounted) return;
      setState(() => _groups = groups);
      widget.onGroupsChanged();
    } catch (error, stackTrace) {
      ExceptionLogService().record(
        node: 'bookshelf.group_switch.reload.failed',
        message: '重新加载分组失败',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<BookshelfGroupEditDraft?> _showEditDialog(
    BookshelfBookGroup? existing,
  ) {
    return showCupertinoBottomDialog<BookshelfGroupEditDraft>(
      context: context,
      builder: (ctx) => BookshelfGroupEditDialog(existing: existing),
    );
  }

  Future<void> _showHint(String message) {
    return showCupertinoBottomDialog<void>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('提示'),
        content: Text('\n$message'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('好'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final separatorColor = CupertinoColors.separator.resolveFrom(context);
    final bg = CupertinoColors.systemGroupedBackground.resolveFrom(context);

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(13)),
      child: Container(
        color: bg,
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppSheetHeader(title: '分组'),
              _GroupSwitchHeader(
                isEditing: _isEditing,
                adding: _adding,
                onToggleEdit: () => setState(() => _isEditing = !_isEditing),
                onAdd: _handleAddGroup,
              ),
              Container(height: 0.5, color: separatorColor),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * 0.55,
                ),
                child: _groups.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.symmetric(vertical: 32),
                        child: Center(
                          child: Text(
                            '暂无分组',
                            style: TextStyle(
                              color: CupertinoColors.secondaryLabel
                                  .resolveFrom(context),
                            ),
                          ),
                        ),
                      )
                    : _isEditing
                        ? ReorderableListView.builder(
                            shrinkWrap: true,
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            itemCount: _groups.length,
                            onReorder: _handleReorder,
                            buildDefaultDragHandles: false,
                            itemBuilder: (context, index) {
                              final group = _groups[index];
                              return _GroupEditRow(
                                key: ValueKey(group.groupId),
                                group: group,
                                index: index,
                                separatorColor: separatorColor,
                                onDelete: group.isCustomGroup
                                    ? () => _handleDeleteGroup(group)
                                    : null,
                              );
                            },
                          )
                        : ListView.builder(
                            shrinkWrap: true,
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            itemCount: _groups.length,
                            itemBuilder: (context, index) {
                              final group = _groups[index];
                              final effectiveSelected =
                                  widget.selectedGroupId ==
                                          BookshelfBookGroup.idRoot
                                      ? BookshelfBookGroup.idAll
                                      : widget.selectedGroupId;
                              return _GroupSelectRow(
                                key: ValueKey(group.groupId),
                                group: group,
                                isSelected:
                                    group.groupId == effectiveSelected,
                                separatorColor: separatorColor,
                                onTap: () {
                                  Navigator.pop(context);
                                  widget.onGroupSelected(group.groupId);
                                },
                              );
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GroupSwitchHeader extends StatelessWidget {
  const _GroupSwitchHeader({
    required this.isEditing,
    required this.adding,
    required this.onToggleEdit,
    required this.onAdd,
  });

  final bool isEditing;
  final bool adding;
  final VoidCallback onToggleEdit;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final primaryColor = CupertinoTheme.of(context).primaryColor;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 2, 4, 6),
      child: Row(
        children: [
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            minimumSize: const Size(44, 44),
            onPressed: onToggleEdit,
            child: Text(
              isEditing ? '完成' : '编辑',
              style: TextStyle(fontSize: 15, color: primaryColor),
            ),
          ),
          const Spacer(),
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            minimumSize: const Size(44, 44),
            onPressed: adding ? null : onAdd,
            child: adding
                ? const CupertinoActivityIndicator(radius: 9)
                : Icon(CupertinoIcons.add, color: primaryColor, size: 22),
          ),
        ],
      ),
    );
  }
}

class _GroupSelectRow extends StatelessWidget {
  const _GroupSelectRow({
    super.key,
    required this.group,
    required this.isSelected,
    required this.separatorColor,
    required this.onTap,
  });

  final BookshelfBookGroup group;
  final bool isSelected;
  final Color separatorColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final primaryColor = CupertinoTheme.of(context).primaryColor;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CupertinoButton(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
          minimumSize: const Size(double.infinity, 50),
          onPressed: onTap,
          child: Row(
            children: [
              Expanded(
                child: Text(
                  group.groupName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16,
                    color: CupertinoColors.label.resolveFrom(context),
                  ),
                ),
              ),
              if (isSelected)
                Icon(CupertinoIcons.checkmark, size: 18, color: primaryColor),
            ],
          ),
        ),
        Container(height: 0.5, color: separatorColor),
      ],
    );
  }
}

class _GroupEditRow extends StatelessWidget {
  const _GroupEditRow({
    super.key,
    required this.group,
    required this.index,
    required this.separatorColor,
    this.onDelete,
  });

  final BookshelfBookGroup group;
  final int index;
  final Color separatorColor;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final tertiaryLabel =
        CupertinoColors.tertiaryLabel.resolveFrom(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 50,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                if (onDelete != null)
                  CupertinoButton(
                    padding: const EdgeInsets.only(right: 8),
                    minimumSize: const Size(36, 44),
                    onPressed: onDelete,
                    child: const Icon(
                      CupertinoIcons.minus_circle_fill,
                      color: CupertinoColors.destructiveRed,
                      size: 22,
                    ),
                  )
                else
                  const SizedBox(width: 44),
                Expanded(
                  child: Text(
                    group.groupName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
                if (group.isCustomGroup)
                  ReorderableDragStartListener(
                    index: index,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Icon(
                        CupertinoIcons.bars,
                        size: 20,
                        color: tertiaryLabel,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        Container(height: 0.5, color: separatorColor),
      ],
    );
  }
}
