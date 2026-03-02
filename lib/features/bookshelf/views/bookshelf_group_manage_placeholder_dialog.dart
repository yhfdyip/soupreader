import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';

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
    final draft = await _showAddGroupDialog();
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

  Future<_AddGroupDraft?> _showAddGroupDialog() {
    return showCupertinoDialog<_AddGroupDraft>(
      context: context,
      builder: (dialogContext) => const _AddGroupDialog(),
    );
  }

  Future<void> _showHintDialog(String message) {
    return showCupertinoDialog<void>(
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
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 8, 8),
                    child: Row(
                      children: [
                        const SizedBox(width: 34),
                        const Expanded(
                          child: Text(
                            '分组管理',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        CupertinoButton(
                          padding: const EdgeInsets.all(4),
                          onPressed: _adding ? null : _handleAddGroup,
                          child: _adding
                              ? const CupertinoActivityIndicator(radius: 8)
                              : const Icon(CupertinoIcons.add),
                          minimumSize: Size(30, 30),
                        ),
                      ],
                    ),
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
                            : ListView.separated(
                                padding:
                                    const EdgeInsets.fromLTRB(12, 8, 12, 12),
                                itemCount: _groups.length,
                                separatorBuilder: (_, __) => Container(
                                  height: 0.5,
                                  color: separatorColor,
                                ),
                                itemBuilder: (context, index) {
                                  final group = _groups[index];
                                  return SizedBox(
                                    height: 44,
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            group.manageName,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                  ),
                  Container(height: 0.5, color: separatorColor),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: CupertinoButton(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        onPressed: () => Navigator.pop(context),
                        child: const Text('完成'),
                        minimumSize: Size(30, 30),
                      ),
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

class _AddGroupDialog extends StatefulWidget {
  const _AddGroupDialog();

  @override
  State<_AddGroupDialog> createState() => _AddGroupDialogState();
}

class _AddGroupDialogState extends State<_AddGroupDialog> {
  final TextEditingController _groupNameController = TextEditingController();

  String? _coverPath;
  int _bookSort = -1;
  bool _enableRefresh = true;
  bool _pickingCover = false;
  String? _errorText;

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
        node: 'bookshelf.group_manage.menu_add.pick_cover_failed',
        message: '选择分组封面失败',
        error: error,
        stackTrace: stackTrace,
      );
      if (!mounted) return;
      setState(() => _errorText = '选择封面失败：$error');
    } finally {
      if (mounted) {
        setState(() => _pickingCover = false);
      }
    }
  }

  Future<void> _pickSort() async {
    final selected = await showCupertinoBottomDialog<int>(
      context: context,
      barrierDismissible: true,
      builder: (popupContext) => CupertinoActionSheet(
        title: const Text('排序'),
        actions: [
          for (final option in _groupSortOptions)
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
      _AddGroupDraft(
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
      title: const Text('添加分组'),
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  onPressed: _pickingCover ? null : _pickCover,
                  child: _pickingCover
                      ? const CupertinoActivityIndicator(radius: 7)
                      : const Text('选择封面'),
                  minimumSize: Size(26, 26),
                ),
                if ((_coverPath ?? '').trim().isNotEmpty)
                  CupertinoButton(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    onPressed: () {
                      setState(() {
                        _coverPath = null;
                        _errorText = null;
                      });
                    },
                    child: Text(
                      '清除',
                      style: TextStyle(color: destructiveColor),
                    ),
                    minimumSize: Size(26, 26),
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  onPressed: _pickSort,
                  child: Text(_groupSortLabel(_bookSort)),
                  minimumSize: Size(26, 26),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Expanded(child: Text('允许下拉刷新')),
                CupertinoSwitch(
                  value: _enableRefresh,
                  onChanged: (value) {
                    setState(() {
                      _enableRefresh = value;
                    });
                  },
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

class _AddGroupDraft {
  const _AddGroupDraft({
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

class _GroupSortOption {
  const _GroupSortOption(this.value, this.label);

  final int value;
  final String label;
}

const List<_GroupSortOption> _groupSortOptions = <_GroupSortOption>[
  _GroupSortOption(-1, '默认'),
  _GroupSortOption(0, '按阅读时间'),
  _GroupSortOption(1, '按更新时间'),
  _GroupSortOption(2, '按书名'),
  _GroupSortOption(3, '手动排序'),
  _GroupSortOption(4, '综合排序'),
  _GroupSortOption(5, '按作者'),
];

String _groupSortLabel(int value) {
  for (final option in _groupSortOptions) {
    if (option.value == value) {
      return option.label;
    }
  }
  return '默认';
}
