import 'dart:io';

import 'package:flutter/cupertino.dart';

import '../../../app/widgets/app_action_list_sheet.dart';
import '../../../app/widgets/app_manage_search_field.dart';
import '../../../app/widgets/app_nav_bar_button.dart';
import '../../../app/widgets/cupertino_bottom_dialog.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/widgets/app_cupertino_page_scaffold.dart';

class FileManageView extends StatefulWidget {
  const FileManageView({super.key});

  @override
  State<FileManageView> createState() => _FileManageViewState();
}

class _FileManageViewState extends State<FileManageView> {
  static const int _osErrorOperationNotPermitted = 1;
  static const int _osErrorNotFound = 2;
  static const int _osErrorPathNotFound = 3;
  static const int _osErrorAccessDenied = 5;
  static const int _osErrorPermissionDenied = 13;
  static const int _osErrorDirectoryNotEmpty = 39;
  static const int _osErrorDirectoryNotEmptyWin = 145;

  Directory? _rootDir;
  List<Directory> _subDirs = <Directory>[];
  List<FileSystemEntity> _entities = <FileSystemEntity>[];
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _loading = true;
  bool _creatingFolder = false;

  Directory? get _currentDir => _subDirs.isNotEmpty ? _subDirs.last : _rootDir;

  @override
  void initState() {
    super.initState();
    _initRootDirectory();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _initRootDirectory() async {
    try {
      final docs = await getApplicationDocumentsDirectory();
      var root = docs.parent;
      if (!await root.exists()) {
        root = docs;
      }
      _rootDir = root;
      await _reloadCurrentDirectory();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
      });
      await _showMessage('初始化文件管理失败：$error');
    }
  }

  Future<void> _reloadCurrentDirectory() async {
    final current = _currentDir;
    if (current == null) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _entities = <FileSystemEntity>[];
      });
      return;
    }
    if (mounted) {
      setState(() => _loading = true);
    }
    try {
      final children = current.listSync(followLinks: false);
      children.sort(_compareEntity);
      if (!mounted) return;
      setState(() {
        _entities = children;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      await _showMessage('读取目录失败：$error');
    }
  }

  int _compareEntity(FileSystemEntity a, FileSystemEntity b) {
    final aIsFile = a is File;
    final bIsFile = b is File;
    if (aIsFile != bIsFile) {
      return aIsFile ? 1 : -1;
    }
    final aName = _entityName(a).toLowerCase();
    final bName = _entityName(b).toLowerCase();
    return aName.compareTo(bName);
  }

  String _entityName(FileSystemEntity entity) {
    final normalized = entity.path.replaceAll('\\', '/');
    final index = normalized.lastIndexOf('/');
    if (index < 0 || index + 1 >= normalized.length) return normalized;
    return normalized.substring(index + 1);
  }

  String _displayName(FileSystemEntity entity) {
    final name = _entityName(entity).trim();
    return name.isEmpty ? entity.path : name;
  }

  bool get _atRoot => _subDirs.isEmpty;

  List<_FileListEntry> _buildVisibleEntries() {
    final query = _searchQuery.trim().toLowerCase();
    final result = <_FileListEntry>[];
    if (!_atRoot && _currentDir != null) {
      result.add(_FileListEntry.parent(_currentDir!));
    }
    for (final entity in _entities) {
      final name = _displayName(entity).toLowerCase();
      if (query.isNotEmpty && !name.contains(query)) {
        continue;
      }
      result.add(_FileListEntry.entity(entity));
    }
    return result;
  }

  Future<void> _openRoot() async {
    if (_rootDir == null) return;
    setState(() => _subDirs = <Directory>[]);
    await _reloadCurrentDirectory();
  }

  Future<void> _openDirectory(Directory dir) async {
    setState(() => _subDirs = <Directory>[..._subDirs, dir]);
    await _reloadCurrentDirectory();
  }

  Future<void> _openPathAt(int index) async {
    if (index < 0 || index >= _subDirs.length) return;
    setState(() => _subDirs = _subDirs.take(index + 1).toList(growable: false));
    await _reloadCurrentDirectory();
  }

  Future<bool> _goParent() async {
    if (_atRoot) return false;
    setState(() {
      _subDirs = _subDirs.take(_subDirs.length - 1).toList(growable: false);
    });
    await _reloadCurrentDirectory();
    return true;
  }

  Future<void> _openFile(File file) async {
    try {
      final launched = await launchUrl(
        Uri.file(file.path),
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        await _showMessage('系统无法打开该文件');
      }
    } catch (error) {
      await _showMessage('打开文件失败：$error');
    }
  }

  Future<void> _showEntityMenu(FileSystemEntity entity) async {
    final selected = await showAppActionListSheet<_FileEntityAction>(
      context: context,
      title: _displayName(entity),
      showCancel: true,
      items: const [
        AppActionListItem<_FileEntityAction>(
          value: _FileEntityAction.delete,
          icon: CupertinoIcons.delete,
          label: '删除',
          isDestructiveAction: true,
        ),
      ],
    );
    if (selected == _FileEntityAction.delete) {
      await _deleteEntity(entity);
    }
  }

  Future<void> _deleteEntity(FileSystemEntity entity) async {
    final entityPath = entity.path;
    final displayName = _displayName(entity);
    try {
      final currentType = await FileSystemEntity.type(
        entityPath,
        followLinks: false,
      );
      if (currentType == FileSystemEntityType.notFound) {
        await _showDeleteFailureMessage(
          type: _DeleteFailureType.targetNotFound,
          displayName: displayName,
        );
        return;
      }
      if (entity is Directory) {
        await entity.delete(recursive: false);
      } else {
        await entity.delete();
      }
      await _reloadCurrentDirectory();
    } on FileSystemException catch (error) {
      await _showDeleteFailureMessage(
        type: _resolveDeleteFailureType(error),
        displayName: displayName,
        detail: _buildDeleteErrorDetail(error),
      );
    } catch (error) {
      await _showDeleteFailureMessage(
        type: _DeleteFailureType.otherIo,
        displayName: displayName,
        detail: error.toString(),
      );
    }
  }

  _DeleteFailureType _resolveDeleteFailureType(FileSystemException error) {
    final osCode = error.osError?.errorCode;
    final mergedMessage =
        '${error.message} ${error.osError?.message ?? ''}'.toLowerCase();

    if (osCode == _osErrorDirectoryNotEmpty ||
        osCode == _osErrorDirectoryNotEmptyWin ||
        mergedMessage.contains('directory not empty') ||
        mergedMessage.contains('not empty') ||
        mergedMessage.contains('目录非空')) {
      return _DeleteFailureType.directoryNotEmpty;
    }
    if (osCode == _osErrorPermissionDenied ||
        osCode == _osErrorOperationNotPermitted ||
        osCode == _osErrorAccessDenied ||
        mergedMessage.contains('permission denied') ||
        mergedMessage.contains('operation not permitted') ||
        mergedMessage.contains('access is denied') ||
        mergedMessage.contains('权限')) {
      return _DeleteFailureType.permissionDenied;
    }
    if (osCode == _osErrorNotFound ||
        osCode == _osErrorPathNotFound ||
        mergedMessage.contains('no such file') ||
        mergedMessage.contains('cannot find the file') ||
        mergedMessage.contains('not found') ||
        mergedMessage.contains('不存在')) {
      return _DeleteFailureType.targetNotFound;
    }
    return _DeleteFailureType.otherIo;
  }

  String _buildDeleteErrorDetail(FileSystemException error) {
    final osError = error.osError;
    final errorCode = osError?.errorCode;
    final osMessage = osError?.message.trim() ?? '';
    final message = error.message.trim();
    final details = <String>[
      if (errorCode != null) '错误码：$errorCode',
      if (osMessage.isNotEmpty) osMessage,
      if (message.isNotEmpty && message != osMessage) message,
    ];
    return details.join(' | ');
  }

  Future<void> _showDeleteFailureMessage({
    required _DeleteFailureType type,
    required String displayName,
    String? detail,
  }) async {
    final baseMessage = switch (type) {
      _DeleteFailureType.directoryNotEmpty => '删除失败（目录非空）：请先清空目录后再删除',
      _DeleteFailureType.permissionDenied => '删除失败（权限不足）：当前没有权限删除该项目',
      _DeleteFailureType.targetNotFound => '删除失败（目标不存在）：文件或目录已不存在',
      _DeleteFailureType.otherIo => '删除失败（IO 异常）：请稍后重试',
    };
    final hasDetail = detail != null && detail.trim().isNotEmpty;
    final fullMessage = hasDetail
        ? '$baseMessage\n目标：$displayName\n错误详情：${detail.trim()}'
        : '$baseMessage\n目标：$displayName';
    await _showMessage(fullMessage);
  }

  String _joinPath(String parent, String child) {
    if (parent.endsWith(Platform.pathSeparator)) {
      return '$parent$child';
    }
    return '$parent${Platform.pathSeparator}$child';
  }

  String _normalizePath(String path) {
    var normalized = path.replaceAll('\\', '/');
    while (normalized.endsWith('/') && normalized.length > 1) {
      normalized = normalized.substring(0, normalized.length - 1);
    }
    return normalized;
  }

  bool _isChildPath({
    required String parentPath,
    required String childPath,
  }) {
    final parent = _normalizePath(parentPath);
    final child = _normalizePath(childPath);
    if (child == parent) return false;
    if (parent == '/') {
      return child.startsWith('/') && child.length > 1;
    }
    return child.startsWith('$parent/');
  }

  String? _validateFolderName(String name) {
    if (name == '.' || name == '..') {
      return '文件夹名非法';
    }
    if (name.contains('/') || name.contains('\\')) {
      return '文件夹名非法';
    }
    if (RegExp(r'[\x00-\x1F]').hasMatch(name)) {
      return '文件夹名非法';
    }
    if (RegExp(r'[:*?"<>|]').hasMatch(name)) {
      return '文件夹名非法';
    }
    return null;
  }

  Future<void> _showCreateFolderDialog() async {
    final current = _currentDir;
    if (current == null || _creatingFolder) return;
    final controller = TextEditingController();
    final folderName = await showCupertinoBottomDialog<String>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: const Text('新建文件夹'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            const Text('默认在当前目录创建子文件夹'),
            const SizedBox(height: 8),
            CupertinoTextField(
              controller: controller,
              placeholder: '文件夹名',
              autofocus: true,
              textInputAction: TextInputAction.done,
            ),
          ],
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text),
            child: const Text('确定'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (folderName == null) return;
    await _createFolder(folderName);
  }

  Future<void> _createFolder(String rawName) async {
    final current = _currentDir;
    if (current == null) {
      await _showMessage('创建文件夹失败：当前目录不可用');
      return;
    }
    final name = rawName.trim();
    if (name.isEmpty) {
      await _showMessage('文件夹名不能为空');
      return;
    }
    final invalidReason = _validateFolderName(name);
    if (invalidReason != null) {
      await _showMessage(invalidReason);
      return;
    }
    if (!mounted) return;
    setState(() => _creatingFolder = true);
    try {
      final currentPath = current.absolute.path;
      final targetPath = _joinPath(currentPath, name);
      if (!_isChildPath(parentPath: currentPath, childPath: targetPath)) {
        await _showMessage('文件夹名非法');
        return;
      }

      final targetType = await FileSystemEntity.type(
        targetPath,
        followLinks: false,
      );
      if (targetType != FileSystemEntityType.notFound) {
        await _showMessage('创建文件夹失败：名称已存在');
        return;
      }

      await Directory(targetPath).create(recursive: false);
      if (!mounted) return;
      setState(() {
        _searchQuery = '';
        _searchController.clear();
      });
      await _reloadCurrentDirectory();
    } catch (error) {
      await _showMessage('创建文件夹失败：$error');
    } finally {
      if (mounted) {
        setState(() => _creatingFolder = false);
      }
    }
  }

  Future<void> _onTapEntry(_FileListEntry entry) async {
    if (entry.isParentEntry) {
      await _goParent();
      return;
    }
    final entity = entry.entity;
    if (entity is Directory) {
      await _openDirectory(entity);
      return;
    }
    if (entity is File) {
      await _openFile(entity);
    }
  }

  Future<void> _showMessage(String message) async {
    if (!mounted) return;
    await showCupertinoBottomDialog<void>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: const Text('提示'),
        content: Text('\n$message'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('好'),
          ),
        ],
      ),
    );
  }

  Widget _buildPathBar() {
    final pathButtons = <Widget>[
      CupertinoButton(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        onPressed: _openRoot,
        child: const Text('root', maxLines: 1, overflow: TextOverflow.ellipsis),
        minimumSize: Size(28, 28),
      ),
    ];
    for (var i = 0; i < _subDirs.length; i++) {
      final dir = _subDirs[i];
      pathButtons.add(
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 2),
          child: Icon(CupertinoIcons.chevron_right, size: 12),
        ),
      );
      pathButtons.add(
        CupertinoButton(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          onPressed: () => _openPathAt(i),
          child: Text(
            _displayName(dir),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          minimumSize: Size(28, 28),
        ),
      );
    }
    return SizedBox(
      height: 42,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        children: pathButtons,
      ),
    );
  }

  Widget _buildList() {
    if (_loading) {
      return const Center(child: CupertinoActivityIndicator());
    }
    final entries = _buildVisibleEntries();
    if (entries.isEmpty) {
      return const SizedBox.shrink();
    }
    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 16),
      itemCount: entries.length,
      separatorBuilder: (_, __) => Container(
        margin: const EdgeInsets.only(left: 52),
        height: 0.5,
        color: CupertinoColors.separator.resolveFrom(context),
      ),
      itemBuilder: (context, index) {
        final entry = entries[index];
        final isParent = entry.isParentEntry;
        final entity = entry.entity;
        final isDir = !isParent && entity is Directory;
        final icon = isParent
            ? CupertinoIcons.arrow_uturn_left
            : (isDir ? CupertinoIcons.folder : CupertinoIcons.doc);
        final name = isParent ? '..' : _displayName(entity);
        final sizeText = (!isParent && entity is File)
            ? _formatBytes(entity.lengthSync())
            : '';

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _onTapEntry(entry),
          onLongPress: isParent ? null : () => _showEntityMenu(entity),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: CupertinoColors.activeBlue.resolveFrom(context),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (sizeText.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Text(
                      sizeText,
                      style: TextStyle(
                        fontSize: 12,
                        color: CupertinoColors.secondaryLabel.resolveFrom(
                          context,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    const units = <String>['KB', 'MB', 'GB', 'TB'];
    var value = bytes.toDouble();
    var unitIndex = -1;
    while (value >= 1024 && unitIndex + 1 < units.length) {
      value /= 1024;
      unitIndex++;
    }
    if (unitIndex < 0) return '${bytes}B';
    final fixed =
        value >= 100 ? value.toStringAsFixed(0) : value.toStringAsFixed(1);
    return '$fixed${units[unitIndex]}';
  }

  @override
  Widget build(BuildContext context) {
    return AppCupertinoPageScaffold(
      title: '文件管理',
      trailing: AppNavBarButton(
        onPressed: (_currentDir != null && !_creatingFolder)
            ? _showCreateFolderDialog
            : null,
        child: _creatingFolder
            ? const CupertinoActivityIndicator()
            : const Text('新建文件夹'),
      ),
      child: PopScope<void>(
        canPop: _atRoot,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;
          _goParent();
        },
        child: Column(
          children: [
            _buildPathBar(),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: AppManageSearchField(
                controller: _searchController,
                placeholder: '筛选 • 文件管理',
                onChanged: (value) => setState(() => _searchQuery = value),
              ),
            ),
            Expanded(child: _buildList()),
          ],
        ),
      ),
    );
  }
}

enum _FileEntityAction {
  delete,
}

enum _DeleteFailureType {
  directoryNotEmpty,
  permissionDenied,
  targetNotFound,
  otherIo,
}

class _FileListEntry {
  final FileSystemEntity entity;
  final bool isParentEntry;

  const _FileListEntry._({
    required this.entity,
    required this.isParentEntry,
  });

  factory _FileListEntry.entity(FileSystemEntity entity) {
    return _FileListEntry._(
      entity: entity,
      isParentEntry: false,
    );
  }

  factory _FileListEntry.parent(Directory current) {
    return _FileListEntry._(
      entity: current,
      isParentEntry: true,
    );
  }
}
