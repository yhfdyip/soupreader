import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show ReorderableListView, ReorderableDragStartListener;

import '../../../app/widgets/cupertino_bottom_dialog.dart';
import '../../../core/services/exception_log_service.dart';
import '../models/bookshelf_book_group.dart';
import '../services/bookshelf_book_group_store.dart';

class BookshelfGroupManagePlaceholderDialog extends StatefulWidget {
  const BookshelfGroupManagePlaceholderDialog({super.key});

  @override
  State<BookshelfGroupManagePlaceholderDialog> createState() =>
      _BookshelfGroupManagePlaceholderDialogState();
}

class _BookshelfGroupManagePlaceholderDialogState
    extends State<BookshelfGroupManagePlaceholderDialog> {
  final BookshelfBookGroupStore _groupStore = BookshelfBookGroupStore();

  List<BookshelfBookGroup> _groups = const <BookshelfBookGroup>[];
  bool _loading = true;
  bool _adding = false;

  @override
  void initState() {
    super.initState();
    _loadGroups(showLoading: true);
  }

  Future<void> _loadGroups({required bool showLoading}) async {
    if (showLoading && mounted) {
      setState(() => _loading = true);
    }
    try {
      final groups = await _groupStore.getGroups();
      if (!mounted) return;
      setState(() {
        _groups = groups;
        _loading = false;
      });
    } catch (error, stackTrace) {
      ExceptionLogService().record(
        node: 'bookshelf.group_manage.load.failed',
        message: '分组管理加载分组失败',
        error: error,
        stackTrace: stackTrace,
      );
      if (!mounted) return;
      setState(() => _loading = false);
      await _showHintDialog('加载分组失败：$error');
    }
  }

  Future<void> _handleAddGroup() async {
    if (_adding) return;
    bool canAdd = false;
    try {
      canAdd = await _groupStore.canAddGroup();
    } catch (error, stackTrace) {
      ExceptionLogService().record(
        node: 'bookshelf.group_manage.menu_add.check_limit_failed',
        message: '检查分组数量上限失败',
        error: error,
        stackTrace: stackTrace,
      );
      await _showHintDialog('添加分组失败：$error');
      return;
    }
    if (!canAdd) {
      await _showHintDialog('分组已达上限(64个)');
      return;
    }
    final draft = await _showEditGroupDialog(null);
    if (draft == null) return;
    setState(() => _adding = true);
    try {
      await _groupStore.addGroup(
        draft.groupName,
        cover: draft.coverPath,
        bookSort: draft.bookSort,
        enableRefresh: draft.enableRefresh,
      );
      await _loadGroups(showLoading: false);
    } catch (error, stackTrace) {
      ExceptionLogService().record(
        node: 'bookshelf.group_manage.menu_add.failed',
        message: '添加分组失败',
        error: error,
        stackTrace: stackTrace,
      );
      if (!mounted) return;
      await _showHintDialog('添加分组失败：$error');
    } finally {
      if (mounted) {
        setState(() => _adding = false);
      }
    }
  }

  Future<void> _handleEditGroup(BookshelfBookGroup group) async {
    final draft = await _showEditGroupDialog(group);
    if (draft == null) return;
    try {
      final updated = group.copyWith(
        groupName: draft.groupName,
        cover: draft.coverPath,
        clearCover: draft.coverPath == null && group.cover != null,
        bookSort: draft.bookSort,
        enableRefresh: draft.enableRefresh,
      );
      await _groupStore.updateGroup(updated);
      await _loadGroups(showLoading: false);
    } catch (error, stackTrace) {
      ExceptionLogService().record(
        node: 'bookshelf.group_manage.edit.failed',
        message: '编辑分组失败',
        error: error,
        stackTrace: stackTrace,
      );
      if (!mounted) return;
      await _showHintDialog('编辑分组失败：$error');
    }
  }

  Future<void> _handleToggleShow(BookshelfBookGroup group, bool show) async {
    try {
      await _groupStore.updateGroup(group.copyWith(show: show));
      await _loadGroups(showLoading: false);
    } catch (error, stackTrace) {
      ExceptionLogService().record(
        node: 'bookshelf.group_manage.toggle_show.failed',
        message: '切换分组显示失败',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _handleDeleteGroup(BookshelfBookGroup group) async {
    final confirmed = await showCupertinoBottomSheetDialog<bool>(
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
    if (confirmed != true) return;
    try {
      await _groupStore.deleteGroup(group.groupId);
      await _loadGroups(showLoading: false);
    } catch (error, stackTrace) {
      ExceptionLogService().record(
        node: 'bookshelf.group_manage.delete.failed',
        message: '删除分组失败',
        error: error,
        stackTrace: stackTrace,
      );
      if (!mounted) return;
      await _showHintDialog('删除分组失败：$error');
    }
  }

  Future<void> _handleReorder(int oldIndex, int newIndex) async {
    if (oldIndex == newIndex) return;
    final mutable = List<BookshelfBookGroup>.from(_groups);
    final moved = mutable.removeAt(oldIndex);
    final insertAt = newIndex > oldIndex ? newIndex - 1 : newIndex;
    mutable.insert(insertAt, moved);
    // 重新分配 order：保留内置分组原始顺序，仅对自定义分组重排
    var customOrder = 0;
    final reordered = mutable.map((g) {
      if (g.isCustomGroup) {
        return g.copyWith(order: customOrder++);
      }
      return g;
    }).toList();
    setState(() => _groups = reordered);
    try {
      await _groupStore.saveGroups(reordered);
    } catch (error, stackTrace) {
      ExceptionLogService().record(
        node: 'bookshelf.group_manage.reorder.failed',
        message: '分组排序保存失败',
        error: error,
        stackTrace: stackTrace,
      );
      await _loadGroups(showLoading: false);
    }
  }

  Future<BookshelfGroupEditDraft?> _showEditGroupDialog(
    BookshelfBookGroup? existing,
  ) {
    return showCupertinoBottomSheetDialog<BookshelfGroupEditDraft>(
      context: context,
      builder: (dialogContext) => BookshelfGroupEditDialog(existing: existing),
    );
  }

  Future<void> _showHintDialog(String message) {
    return showCupertinoBottomSheetDialog<void>(
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

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.sizeOf(context);
    final width = math.min(screenSize.width * 0.92, 520.0);
    final height = math.min(screenSize.height * 0.82, 620.0);
    final separatorColor = CupertinoColors.separator.resolveFrom(context);
    final secondaryTextColor =
        CupertinoColors.secondaryLabel.resolveFrom(context);

    return Center(
      child: CupertinoPopupSurface(
        child: SizedBox(
          width: width,
          height: height,
          child: CupertinoPageScaffold(
            backgroundColor:
                CupertinoColors.systemBackground.resolveFrom(context),
            child: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  _GroupManageHeader(
                    adding: _adding,
                    onAdd: _handleAddGroup,
                    onClose: () => Navigator.pop(context),
                  ),
                  Container(height: 0.5, color: separatorColor),
                  Expanded(
                    child: _loading
                        ? const Center(child: CupertinoActivityIndicator())
                        : _groups.isEmpty
                            ? Center(
                                child: Text(
                                  '暂无分组',
                                  style: TextStyle(color: secondaryTextColor),
                                ),
                              )
                            : ReorderableListView.builder(
                                padding:
                                    const EdgeInsets.fromLTRB(0, 4, 0, 8),
                                itemCount: _groups.length,
                                onReorder: _handleReorder,
                                buildDefaultDragHandles: false,
                                itemBuilder: (context, index) {
                                  final group = _groups[index];
                                  return _GroupManageRow(
                                    key: ValueKey(group.groupId),
                                    group: group,
                                    index: index,
                                    separatorColor: separatorColor,
                                    onToggleShow: (show) =>
                                        _handleToggleShow(group, show),
                                    onEdit: () => _handleEditGroup(group),
                                    onDelete: group.isCustomGroup
                                        ? () => _handleDeleteGroup(group)
                                        : null,
                                  );
                                },
                              ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GroupManageHeader extends StatelessWidget {
  const _GroupManageHeader({
    required this.adding,
    required this.onAdd,
    required this.onClose,
  });

  final bool adding;
  final VoidCallback onAdd;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 10, 8, 8),
      child: Row(
        children: [
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            minimumSize: Size(34, 34),
            onPressed: onClose,
            child: const Text('完成'),
          ),
          const Expanded(
            child: Text(
              '分组管理',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            ),
          ),
          CupertinoButton(
            padding: const EdgeInsets.all(4),
            minimumSize: Size(34, 34),
            onPressed: adding ? null : onAdd,
            child: adding
                ? const CupertinoActivityIndicator(radius: 8)
                : const Icon(CupertinoIcons.add),
          ),
        ],
      ),
    );
  }
}

class _GroupManageRow extends StatelessWidget {
  const _GroupManageRow({
    super.key,
    required this.group,
    required this.index,
    required this.separatorColor,
    required this.onToggleShow,
    required this.onEdit,
    this.onDelete,
  });

  final BookshelfBookGroup group;
  final int index;
  final Color separatorColor;
  final ValueChanged<bool> onToggleShow;
  final VoidCallback onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final accentColor = CupertinoTheme.of(context).primaryColor;
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
                if (group.isCustomGroup)
                  ReorderableDragStartListener(
                    index: index,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Icon(
                        CupertinoIcons.bars,
                        size: 18,
                        color: tertiaryLabel,
                      ),
                    ),
                  )
                else
                  const SizedBox(width: 26),
                Expanded(
                  child: Text(
                    group.manageName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 15),
                  ),
                ),
                if (onDelete != null)
                  CupertinoButton(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    minimumSize: Size(36, 36),
                    onPressed: onDelete,
                    child: Text(
                      '删除',
                      style: TextStyle(
                        fontSize: 14,
                        color: CupertinoColors.destructiveRed,
                      ),
                    ),
                  ),
                CupertinoButton(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  minimumSize: Size(36, 36),
                  onPressed: onEdit,
                  child: Text(
                    '编辑',
                    style: TextStyle(fontSize: 14, color: accentColor),
                  ),
                ),
                CupertinoSwitch(
                  value: group.show,
                  onChanged: onToggleShow,
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

class BookshelfGroupEditDialog extends StatefulWidget {
  const BookshelfGroupEditDialog({super.key, this.existing});

  final BookshelfBookGroup? existing;

  @override
  State<BookshelfGroupEditDialog> createState() =>
      _BookshelfGroupEditDialogState();
}

class _BookshelfGroupEditDialogState
    extends State<BookshelfGroupEditDialog> {
  late final TextEditingController _groupNameController;

  String? _coverPath;
  late int _bookSort;
  late bool _enableRefresh;
  bool _pickingCover = false;
  String? _errorText;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _groupNameController =
        TextEditingController(text: existing?.groupName ?? '');
    _coverPath = existing?.cover;
    _bookSort = existing?.bookSort ?? -1;
    _enableRefresh = existing?.enableRefresh ?? true;
  }

  @override
  void dispose() {
    _groupNameController.dispose();
    super.dispose();
  }

  Future<void> _pickCover() async {
    if (_pickingCover) return;
    setState(() => _pickingCover = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        withData: false,
      );
      if (!mounted || result == null || result.files.isEmpty) return;
      final selected =
          (result.files.first.path ?? result.files.first.name).trim();
      if (selected.isEmpty) return;
      setState(() {
        _coverPath = selected;
        _errorText = null;
      });
    } catch (error, stackTrace) {
      ExceptionLogService().record(
        node: 'bookshelf.group_manage.edit.pick_cover_failed',
        message: '选择分组封面失败',
        error: error,
        stackTrace: stackTrace,
      );
      if (!mounted) return;
      setState(() => _errorText = '选择封面失败：$error');
    } finally {
      if (mounted) setState(() => _pickingCover = false);
    }
  }

  Future<void> _pickSort() async {
    final selected = await showCupertinoBottomSheetDialog<int>(
      context: context,
      barrierDismissible: true,
      builder: (popupContext) => CupertinoActionSheet(
        title: const Text('排序'),
        actions: [
          for (final option in bookshelfGroupSortOptions)
            CupertinoActionSheetAction(
              isDefaultAction: option.value == _bookSort,
              onPressed: () => Navigator.pop(popupContext, option.value),
              child: Text(option.label),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(popupContext),
          child: const Text('取消'),
        ),
      ),
    );
    if (selected == null || !mounted) return;
    setState(() => _bookSort = selected);
  }

  void _submit() {
    final groupName = _groupNameController.text.trim();
    if (groupName.isEmpty) {
      setState(() => _errorText = '分组名称不能为空');
      return;
    }
    Navigator.pop(
      context,
      BookshelfGroupEditDraft(
        groupName: groupName,
        coverPath:
            (_coverPath ?? '').trim().isEmpty ? null : _coverPath!.trim(),
        bookSort: _bookSort,
        enableRefresh: _enableRefresh,
      ),
    );
  }

  String _coverDisplayName() {
    final path = (_coverPath ?? '').trim();
    if (path.isEmpty) return '';
    final normalized = path.replaceAll('\\', '/');
    final slashIndex = normalized.lastIndexOf('/');
    if (slashIndex < 0 || slashIndex == normalized.length - 1) {
      return normalized;
    }
    return normalized.substring(slashIndex + 1);
  }

  @override
  Widget build(BuildContext context) {
    final secondaryTextColor =
        CupertinoColors.secondaryLabel.resolveFrom(context);
    final destructiveColor = CupertinoColors.systemRed.resolveFrom(context);
    return CupertinoAlertDialog(
      title: Text(_isEditing ? '编辑分组' : '添加分组'),
      content: Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CupertinoTextField(
              controller: _groupNameController,
              placeholder: '分组名称',
              autofocus: true,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Expanded(child: Text('封面')),
                CupertinoButton(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  minimumSize: Size(26, 26),
                  onPressed: _pickingCover ? null : _pickCover,
                  child: _pickingCover
                      ? const CupertinoActivityIndicator(radius: 7)
                      : const Text('选择封面'),
                ),
                if ((_coverPath ?? '').trim().isNotEmpty)
                  CupertinoButton(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    minimumSize: Size(26, 26),
                    onPressed: () => setState(() {
                      _coverPath = null;
                      _errorText = null;
                    }),
                    child: Text(
                      '清除',
                      style: TextStyle(color: destructiveColor),
                    ),
                  ),
              ],
            ),
            if ((_coverPath ?? '').trim().isNotEmpty)
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    _coverDisplayName(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: secondaryTextColor,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Expanded(child: Text('排序')),
                CupertinoButton(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  minimumSize: Size(26, 26),
                  onPressed: _pickSort,
                  child: Text(bookshelfGroupSortLabel(_bookSort)),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Expanded(child: Text('允许下拉刷新')),
                CupertinoSwitch(
                  value: _enableRefresh,
                  onChanged: (value) =>
                      setState(() => _enableRefresh = value),
                ),
              ],
            ),
            if (_errorText != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _errorText!,
                  style: TextStyle(
                    color: destructiveColor,
                    fontSize: 12,
                  ),
                ),
              ),
          ],
        ),
      ),
      actions: [
        CupertinoDialogAction(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        CupertinoDialogAction(
          onPressed: _submit,
          child: const Text('确定'),
        ),
      ],
    );
  }
}

class BookshelfGroupEditDraft {
  const BookshelfGroupEditDraft({
    required this.groupName,
    required this.bookSort,
    required this.enableRefresh,
    this.coverPath,
  });

  final String groupName;
  final String? coverPath;
  final int bookSort;
  final bool enableRefresh;
}

class BookshelfGroupSortOption {
  const BookshelfGroupSortOption(this.value, this.label);

  final int value;
  final String label;
}

const List<BookshelfGroupSortOption> bookshelfGroupSortOptions =
    <BookshelfGroupSortOption>[
  BookshelfGroupSortOption(-1, '默认'),
  BookshelfGroupSortOption(0, '按阅读时间'),
  BookshelfGroupSortOption(1, '按更新时间'),
  BookshelfGroupSortOption(2, '按书名'),
  BookshelfGroupSortOption(3, '手动排序'),
  BookshelfGroupSortOption(4, '综合排序'),
  BookshelfGroupSortOption(5, '按作者'),
];

String bookshelfGroupSortLabel(int value) {
  for (final option in bookshelfGroupSortOptions) {
    if (option.value == value) return option.label;
  }
  return '默认';
}
