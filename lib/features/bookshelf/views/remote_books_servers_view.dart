import 'package:flutter/cupertino.dart';

import '../../../app/widgets/app_cupertino_page_scaffold.dart';
import '../../../app/widgets/app_nav_bar_button.dart';
import '../../../app/widgets/cupertino_bottom_dialog.dart';
import '../models/remote_server.dart';
import '../services/remote_server_store.dart';
import 'remote_books_server_config_view.dart';

/// 远程书籍服务器列表页（对应 legado `ServersDialog`）。
class RemoteBooksServersView extends StatefulWidget {
  const RemoteBooksServersView({
    super.key,
    this.serverStore,
  });

  final RemoteServerStore? serverStore;

  @override
  State<RemoteBooksServersView> createState() => _RemoteBooksServersViewState();
}

class _RemoteBooksServersViewState extends State<RemoteBooksServersView> {
  late final RemoteServerStore _serverStore;

  List<RemoteServer> _servers = const <RemoteServer>[];
  int _selectedServerId = RemoteServer.defaultServerId;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _serverStore = widget.serverStore ?? RemoteServerStore();
    _reloadData();
  }

  String _compactReason(String value, {int maxLength = 180}) {
    final normalized = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.isEmpty) return '未知错误';
    if (normalized.length <= maxLength) return normalized;
    return '${normalized.substring(0, maxLength)}...';
  }

  Future<void> _reloadData() async {
    if (_loading) return;
    setState(() {
      _loading = true;
    });
    try {
      final servers = _serverStore.getServers();
      final selectedServerId = _serverStore.getSelectedServerId();
      if (!mounted) return;
      setState(() {
        _servers = servers;
        _selectedServerId = selectedServerId;
      });
    } catch (error) {
      if (!mounted) return;
      _showMessage('加载服务器配置失败\n${_compactReason(error.toString())}');
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _openServerConfig({
    RemoteServer? initialServer,
  }) async {
    if (_loading) return;
    final changed = await Navigator.of(context).push<bool>(
      CupertinoPageRoute<bool>(
        builder: (_) => RemoteBooksServerConfigView(
          serverStore: _serverStore,
          initialServer: initialServer,
        ),
      ),
    );
    if (!mounted || changed != true) return;
    await _reloadData();
  }

  Future<void> _confirmDeleteServer(RemoteServer server) async {
    if (_loading) return;
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: const Text('提醒'),
        content: Text('\n是否确认删除？\n${server.displayName}'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _serverStore.deleteServer(server.id);
      if (!mounted) return;
      await _reloadData();
    } catch (error) {
      if (!mounted) return;
      _showMessage('删除失败\n${_compactReason(error.toString())}');
    }
  }

  Future<void> _applyDefaultAndClose() async {
    if (_loading) return;
    await _serverStore.saveSelectedServerId(RemoteServer.defaultServerId);
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  Future<void> _confirmSelectionAndClose() async {
    if (_loading) return;
    await _serverStore.saveSelectedServerId(_selectedServerId);
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  void _showMessage(String message) {
    showCupertinoBottomDialog<void>(
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

  Widget _buildSelectionIcon({
    required bool selected,
  }) {
    return Icon(
      selected
          ? CupertinoIcons.check_mark_circled_solid
          : CupertinoIcons.circle,
      size: 22,
      color: selected
          ? CupertinoColors.activeBlue.resolveFrom(context)
          : CupertinoColors.tertiaryLabel.resolveFrom(context),
    );
  }

  Widget _buildServerRow(RemoteServer server) {
    final selected = server.id == _selectedServerId;
    return CupertinoListTile.notched(
      title: Text(server.displayName),
      subtitle: Text(
        server.normalizedUrl.isEmpty ? '未设置地址' : server.normalizedUrl,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      onTap: () {
        if (_loading) return;
        setState(() {
          _selectedServerId = server.id;
        });
      },
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CupertinoButton(
            padding: EdgeInsets.zero,
            minimumSize: const Size(28, 28),
            onPressed: _loading
                ? null
                : () => _openServerConfig(initialServer: server),
            child: const Icon(
              CupertinoIcons.pencil,
              size: 18,
            ),
          ),
          const SizedBox(width: 8),
          CupertinoButton(
            padding: EdgeInsets.zero,
            minimumSize: const Size(28, 28),
            onPressed: _loading ? null : () => _confirmDeleteServer(server),
            child: Icon(
              CupertinoIcons.delete,
              size: 18,
              color: CupertinoColors.destructiveRed.resolveFrom(context),
            ),
          ),
          const SizedBox(width: 8),
          _buildSelectionIcon(selected: selected),
        ],
      ),
    );
  }

  Widget _buildBottomActions(BuildContext context) {
    final separatorColor = CupertinoColors.separator.resolveFrom(context);
    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: separatorColor,
              width: 0.5,
            ),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
        child: Row(
          children: [
            CupertinoButton(
              onPressed: _loading ? null : _applyDefaultAndClose,
              child: const Text('默认'),
            ),
            const Spacer(),
            CupertinoButton(
              onPressed: _loading ? null : () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            const SizedBox(width: 12),
            CupertinoButton.filled(
              onPressed: _loading ? null : _confirmSelectionAndClose,
              padding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 8,
              ),
              child: const Text('确定'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    if (_loading && _servers.isEmpty) {
      return const Center(
        child: CupertinoActivityIndicator(),
      );
    }
    return ListView(
      padding: const EdgeInsets.only(top: 8, bottom: 12),
      children: [
        CupertinoListSection.insetGrouped(
          children: [
            CupertinoListTile.notched(
              title: const Text('默认'),
              subtitle: const Text('使用全局 WebDav 配置'),
              onTap: () {
                if (_loading) return;
                setState(() {
                  _selectedServerId = RemoteServer.defaultServerId;
                });
              },
              trailing: _buildSelectionIcon(
                selected: _selectedServerId == RemoteServer.defaultServerId,
              ),
            ),
            ..._servers.map(_buildServerRow),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppCupertinoPageScaffold(
      title: '服务器配置',
      trailing: AppNavBarButton(
        onPressed: _loading ? null : _openServerConfig,
        child: const Text('新建'),
      ),
      child: Column(
        children: [
          Expanded(child: _buildContent(context)),
          _buildBottomActions(context),
        ],
      ),
    );
  }
}
