import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../../../app/widgets/app_cupertino_page_scaffold.dart';
import '../../../core/services/settings_service.dart';
import '../../../core/services/webdav_service.dart';
import '../../settings/views/app_help_dialog.dart';
import '../../settings/views/app_log_dialog.dart';
import '../services/remote_books_service.dart';
import 'remote_books_server_config_view.dart';

enum _RemoteBooksSortKey {
  defaultTime,
  name,
}

/// 远程书籍入口承载页（对应 legado: menu_remote -> RemoteBookActivity）。
///
/// 当前已完成：
/// - seq101 `menu_refresh`：刷新动作重载当前目录、路径与返回上级联动、失败可观测；
/// - seq102 `menu_sort`：补齐顶栏“排序”入口与同层级排序菜单承载。
/// - seq103 `menu_sort_name`：补齐名称排序（首次升序、再次点击切换升降序）。
/// - seq104 `menu_sort_time`：补齐更新时间排序（切换到时间排序并支持重复点击切换升降序）。
/// - seq105 `menu_server_config`：补齐“服务器配置”入口，并在配置页关闭后重载当前目录。
/// - seq106 `menu_help`：补齐“帮助”入口并展示 legado 同源 webDavBookHelp 文档。
/// - seq107 `menu_log`：补齐“日志”入口并展示 legado 同义日志弹层。
class RemoteBooksPlaceholderView extends StatefulWidget {
  const RemoteBooksPlaceholderView({
    super.key,
    this.remoteBooksService,
    this.settingsService,
  });

  final RemoteBooksService? remoteBooksService;
  final SettingsService? settingsService;

  @override
  State<RemoteBooksPlaceholderView> createState() =>
      _RemoteBooksPlaceholderViewState();
}

class _RemoteBooksPlaceholderViewState
    extends State<RemoteBooksPlaceholderView> {
  late final RemoteBooksService _remoteBooksService;
  late final SettingsService _settingsService;
  final List<RemoteBookEntry> _dirStack = <RemoteBookEntry>[];
  List<RemoteBookEntry> _entries = const <RemoteBookEntry>[];
  bool _loading = false;
  String? _errorMessage;
  DateTime? _lastRefreshAt;
  _RemoteBooksSortKey _sortKey = _RemoteBooksSortKey.defaultTime;
  bool _sortAscending = false;

  @override
  void initState() {
    super.initState();
    _remoteBooksService = widget.remoteBooksService ?? RemoteBooksService();
    _settingsService = widget.settingsService ?? SettingsService();
    _refreshCurrentDirectory();
  }

  String _currentPathLabel() {
    final buffer = StringBuffer('books/');
    for (final dir in _dirStack) {
      final name = dir.displayName.trim();
      if (name.isEmpty) continue;
      buffer.write(name);
      buffer.write('/');
    }
    return buffer.toString();
  }

  String? _currentDirectoryUrl() {
    if (_dirStack.isEmpty) return null;
    return _dirStack.last.path;
  }

  String _compactReason(String text, {int maxLength = 180}) {
    final normalized = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.length <= maxLength) return normalized;
    return '${normalized.substring(0, maxLength)}…';
  }

  bool _isAsciiDigit(int codeUnit) {
    return codeUnit >= 0x30 && codeUnit <= 0x39;
  }

  String _readAlphaNumChunk(String value, int marker) {
    if (marker >= value.length) return '';
    final buffer = StringBuffer();
    var index = marker;
    final firstCodeUnit = value.codeUnitAt(index);
    final digitChunk = _isAsciiDigit(firstCodeUnit);
    while (index < value.length) {
      final codeUnit = value.codeUnitAt(index);
      if (_isAsciiDigit(codeUnit) != digitChunk) {
        break;
      }
      buffer.writeCharCode(codeUnit);
      index++;
    }
    return buffer.toString();
  }

  int _compareNameLikeLegado(String left, String right) {
    var leftMarker = 0;
    var rightMarker = 0;
    while (leftMarker < left.length && rightMarker < right.length) {
      final leftChunk = _readAlphaNumChunk(left, leftMarker);
      leftMarker += leftChunk.length;
      final rightChunk = _readAlphaNumChunk(right, rightMarker);
      rightMarker += rightChunk.length;

      if (leftChunk.isEmpty || rightChunk.isEmpty) {
        break;
      }

      final leftStartsWithDigit = _isAsciiDigit(leftChunk.codeUnitAt(0));
      final rightStartsWithDigit = _isAsciiDigit(rightChunk.codeUnitAt(0));
      int result = 0;
      if (leftStartsWithDigit && rightStartsWithDigit) {
        result = leftChunk.length - rightChunk.length;
        if (result == 0) {
          for (var i = 0; i < leftChunk.length; i++) {
            result = leftChunk.codeUnitAt(i) - rightChunk.codeUnitAt(i);
            if (result != 0) return result;
          }
        }
      } else {
        result = leftChunk.compareTo(rightChunk);
      }
      if (result != 0) return result;
    }
    return left.length - right.length;
  }

  List<RemoteBookEntry> _sortEntriesLikeLegado(List<RemoteBookEntry> entries) {
    final sorted = List<RemoteBookEntry>.from(entries);
    sorted.sort((a, b) {
      if (a.isDirectory != b.isDirectory) {
        return a.isDirectory ? -1 : 1;
      }
      if (_sortKey == _RemoteBooksSortKey.name) {
        final byName = _compareNameLikeLegado(a.displayName, b.displayName);
        return _sortAscending ? byName : -byName;
      }
      final byTime = a.lastModify.compareTo(b.lastModify);
      return _sortAscending ? byTime : -byTime;
    });
    return sorted;
  }

  Future<void> _applyNameSort() async {
    if (_loading) return;
    setState(() {
      if (_sortKey == _RemoteBooksSortKey.name) {
        _sortAscending = !_sortAscending;
      } else {
        _sortKey = _RemoteBooksSortKey.name;
        _sortAscending = true;
      }
    });
    await _refreshCurrentDirectory();
  }

  Future<void> _applyTimeSort() async {
    if (_loading) return;
    setState(() {
      if (_sortKey == _RemoteBooksSortKey.defaultTime) {
        _sortAscending = !_sortAscending;
      } else {
        _sortKey = _RemoteBooksSortKey.defaultTime;
        _sortAscending = true;
      }
    });
    await _refreshCurrentDirectory();
  }

  Future<void> _refreshCurrentDirectory() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _errorMessage = null;
      _entries = const <RemoteBookEntry>[];
    });
    try {
      final settings = _settingsService.appSettings;
      final entries = await _remoteBooksService.listCurrentDirectory(
        settings: settings,
        currentDirectoryUrl: _currentDirectoryUrl(),
      );
      if (!mounted) return;
      setState(() {
        _entries = _sortEntriesLikeLegado(entries);
        _errorMessage = null;
        _lastRefreshAt = DateTime.now();
      });
    } catch (error) {
      if (!mounted) return;
      final reason = error is WebDavOperationException
          ? error.message
          : _compactReason(error.toString());
      setState(() {
        _errorMessage = '获取webDav书籍出错\n$reason';
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _goBackDir() async {
    if (_dirStack.isEmpty || _loading) return;
    setState(() {
      _dirStack.removeLast();
    });
    await _refreshCurrentDirectory();
  }

  Future<void> _openDir(RemoteBookEntry entry) async {
    if (!entry.isDirectory || _loading) return;
    setState(() {
      _dirStack.add(entry);
    });
    await _refreshCurrentDirectory();
  }

  String _formatLastRefresh() {
    final ts = _lastRefreshAt;
    if (ts == null) return '尚未刷新';
    final hour = ts.hour.toString().padLeft(2, '0');
    final minute = ts.minute.toString().padLeft(2, '0');
    final second = ts.second.toString().padLeft(2, '0');
    return '最近刷新 $hour:$minute:$second';
  }

  Future<void> _showSortSheet() async {
    if (_loading) return;
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (sheetContext) {
        return CupertinoActionSheet(
          title: const Text('排序'),
          actions: [
            CupertinoActionSheetAction(
              onPressed: () async {
                Navigator.of(sheetContext).pop();
                await _applyNameSort();
              },
              child: const Text('名称排序'),
            ),
            CupertinoActionSheetAction(
              onPressed: () async {
                Navigator.of(sheetContext).pop();
                await _applyTimeSort();
              },
              child: const Text('更新时间排序'),
            ),
          ],
          cancelButton: CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(sheetContext).pop();
            },
            child: const Text('取消'),
          ),
        );
      },
    );
  }

  Future<void> _openServerConfig() async {
    await Navigator.of(context).push<void>(
      CupertinoPageRoute<void>(
        builder: (_) => RemoteBooksServerConfigView(
          settingsService: _settingsService,
        ),
      ),
    );
    if (!mounted) return;
    await _refreshCurrentDirectory();
  }

  Future<void> _openHelp() async {
    try {
      final markdownText =
          await rootBundle.loadString('assets/web/help/md/webDavBookHelp.md');
      if (!mounted) return;
      await showAppHelpDialog(context, markdownText: markdownText);
    } catch (error) {
      if (!mounted) return;
      await showCupertinoDialog<void>(
        context: context,
        builder: (dialogContext) => CupertinoAlertDialog(
          title: const Text('帮助'),
          content: Text('帮助文档加载失败：$error'),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('关闭'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _openLog() async {
    await showAppLogDialog(context);
  }

  Future<void> _showMoreSheet() async {
    if (_loading) return;
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (sheetContext) {
        return CupertinoActionSheet(
          actions: [
            CupertinoActionSheetAction(
              onPressed: () async {
                Navigator.of(sheetContext).pop();
                await _openServerConfig();
              },
              child: const Text('服务器配置'),
            ),
            CupertinoActionSheetAction(
              onPressed: () async {
                Navigator.of(sheetContext).pop();
                await _openHelp();
              },
              child: const Text('帮助'),
            ),
            CupertinoActionSheetAction(
              onPressed: () async {
                Navigator.of(sheetContext).pop();
                await _openLog();
              },
              child: const Text('日志'),
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

  Widget _buildTopPanel(BuildContext context) {
    final separator = CupertinoColors.separator.resolveFrom(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: CupertinoColors.systemBackground.resolveFrom(context),
        border: Border(bottom: BorderSide(color: separator, width: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CupertinoButton(
                padding: EdgeInsets.zero,
                minSize: 28,
                onPressed: _dirStack.isEmpty || _loading ? null : _goBackDir,
                child: const Text('返回上级'),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _currentPathLabel(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            _formatLastRefresh(),
            style: const TextStyle(
              fontSize: 12,
              color: CupertinoColors.secondaryLabel,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEntryTile(BuildContext context, RemoteBookEntry entry) {
    final separator = CupertinoColors.separator.resolveFrom(context);
    final subtitle = entry.isDirectory
        ? '目录'
        : entry.size > 0
            ? '文件 · ${entry.size} B'
            : '文件';
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: entry.isDirectory ? () => _openDir(entry) : null,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: separator, width: 0.5)),
        ),
        child: Row(
          children: [
            Icon(
              entry.isDirectory
                  ? CupertinoIcons.folder
                  : CupertinoIcons.doc_text,
              size: 18,
              color: entry.isDirectory
                  ? CupertinoColors.activeBlue
                  : CupertinoColors.secondaryLabel,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: CupertinoColors.secondaryLabel,
                    ),
                  ),
                ],
              ),
            ),
            if (entry.isDirectory)
              const Icon(
                CupertinoIcons.chevron_forward,
                size: 16,
                color: CupertinoColors.tertiaryLabel,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorCard(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: CupertinoColors.secondarySystemGroupedBackground.resolveFrom(
          context,
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        _errorMessage ?? '',
        style: const TextStyle(fontSize: 13),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading && _entries.isEmpty) {
      return const Center(
        child: CupertinoActivityIndicator(),
      );
    }

    if (_entries.isEmpty) {
      return ListView(
        children: [
          if (_errorMessage != null) _buildErrorCard(context),
          if (_errorMessage == null)
            Container(
              margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: CupertinoColors.secondarySystemGroupedBackground
                    .resolveFrom(context),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                '当前目录暂无远程书籍',
                style: TextStyle(fontSize: 13),
              ),
            ),
        ],
      );
    }

    return ListView.builder(
      itemCount: _entries.length,
      itemBuilder: (context, index) {
        final entry = _entries[index];
        return _buildEntryTile(context, entry);
      },
    );
  }

  Widget _buildRefreshAction() {
    if (_loading) {
      return const SizedBox(
        width: 24,
        height: 24,
        child: Center(
          child: CupertinoActivityIndicator(radius: 9),
        ),
      );
    }
    return CupertinoButton(
      padding: EdgeInsets.zero,
      minSize: 30,
      onPressed: _refreshCurrentDirectory,
      child: const Icon(
        CupertinoIcons.refresh,
        size: 20,
      ),
    );
  }

  Widget _buildSortAction() {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      minSize: 30,
      onPressed: _loading ? null : _showSortSheet,
      child: const Icon(
        CupertinoIcons.sort_down,
        size: 20,
      ),
    );
  }

  Widget _buildMenuAction() {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      minSize: 30,
      onPressed: _loading ? null : _showMoreSheet,
      child: const Icon(
        CupertinoIcons.ellipsis,
        size: 20,
      ),
    );
  }

  Widget _buildTrailingActions() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildMenuAction(),
        const SizedBox(width: 12),
        _buildSortAction(),
        const SizedBox(width: 12),
        _buildRefreshAction(),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppCupertinoPageScaffold(
      title: '远程书籍',
      trailing: _buildTrailingActions(),
      child: Column(
        children: [
          _buildTopPanel(context),
          Expanded(child: _buildBody(context)),
        ],
      ),
    );
  }
}
