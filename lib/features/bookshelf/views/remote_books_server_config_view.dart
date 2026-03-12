import 'package:flutter/cupertino.dart';

import '../../../app/widgets/app_cupertino_page_scaffold.dart';
import '../../../app/widgets/app_nav_bar_button.dart';
import '../../../app/widgets/app_ui_kit.dart';
import '../../../app/widgets/cupertino_bottom_dialog.dart';
import '../models/remote_server.dart';
import '../services/remote_server_store.dart';

/// 远程书籍服务器配置编辑页（对应 legado `ServerConfigDialog`）。
class RemoteBooksServerConfigView extends StatefulWidget {
  const RemoteBooksServerConfigView({
    super.key,
    this.serverStore,
    this.initialServer,
  });

  final RemoteServerStore? serverStore;
  final RemoteServer? initialServer;

  @override
  State<RemoteBooksServerConfigView> createState() =>
      _RemoteBooksServerConfigViewState();
}

class _RemoteBooksServerConfigViewState
    extends State<RemoteBooksServerConfigView> {
  late final RemoteServerStore _serverStore;
  late final int _serverId;

  late String _nameDraft;
  late String _urlDraft;
  late String _usernameDraft;
  late String _passwordDraft;

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _serverStore = widget.serverStore ?? RemoteServerStore();
    final initial = widget.initialServer;
    _serverId = initial?.id ?? DateTime.now().microsecondsSinceEpoch;
    _nameDraft = initial?.name ?? '';
    _urlDraft = initial?.url ?? '';
    _usernameDraft = initial?.username ?? '';
    _passwordDraft = initial?.password ?? '';
  }

  String _brief(String value, {String fallback = '未设置'}) {
    final text = value.trim();
    if (text.isEmpty) return fallback;
    if (text.length <= 22) return text;
    return '${text.substring(0, 22)}...';
  }

  String _maskSecret(String value) {
    final text = value.trim();
    if (text.isEmpty) return '未设置';
    return '已设置（${text.length} 位）';
  }

  String _compactReason(String value, {int maxLength = 180}) {
    final normalized = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.isEmpty) return '未知错误';
    if (normalized.length <= maxLength) return normalized;
    return '${normalized.substring(0, maxLength)}...';
  }

  Future<void> _editField({
    required String title,
    required String placeholder,
    required String initialValue,
    required void Function(String value) onChanged,
    bool obscureText = false,
  }) async {
    final controller = TextEditingController(text: initialValue);
    final result = await showCupertinoBottomSheetDialog<String>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: Text(title),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: CupertinoTextField(
            controller: controller,
            placeholder: placeholder,
            obscureText: obscureText,
            maxLines: 1,
          ),
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('取消'),
            onPressed: () => Navigator.pop(dialogContext),
          ),
          CupertinoDialogAction(
            child: const Text('保存'),
            onPressed: () => Navigator.pop(dialogContext, controller.text),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result == null) return;
    setState(() {
      onChanged(result.trim());
    });
  }

  Future<void> _saveServerConfig() async {
    if (_saving) return;
    setState(() {
      _saving = true;
    });
    try {
      await _serverStore.upsertServer(
        RemoteServer(
          id: _serverId,
          name: _nameDraft.trim(),
          url: _urlDraft.trim(),
          username: _usernameDraft.trim(),
          password: _passwordDraft.trim(),
        ),
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      _showMessage('保存出错\n${_compactReason(error.toString())}');
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  void _showMessage(String message) {
    showCupertinoBottomSheetDialog<void>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: const Text('提示'),
        content: Text('\n$message'),
        actions: [
          CupertinoDialogAction(
            child: const Text('好'),
            onPressed: () => Navigator.pop(dialogContext),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppCupertinoPageScaffold(
      title: '服务器配置',
      trailing: AppNavBarButton(
        onPressed: _saving ? null : _saveServerConfig,
        child: _saving ? const CupertinoActivityIndicator() : const Text('保存'),
      ),
      child: AppListView(
        children: [
          AppListSection(
            header: const Text('WebDav'),
            hasLeading: false,
            children: [
              AppListTile(
                title: const Text('名称'),
                additionalInfo: Text(_brief(_nameDraft)),
                onTap: () => _editField(
                  title: '名称',
                  placeholder: '请输入名称',
                  initialValue: _nameDraft,
                  onChanged: (value) {
                    _nameDraft = value;
                  },
                ),
              ),
              AppListTile(
                title: const Text('地址'),
                additionalInfo: Text(_brief(_urlDraft)),
                onTap: () => _editField(
                  title: '地址',
                  placeholder: 'https://dav.example.com/books/',
                  initialValue: _urlDraft,
                  onChanged: (value) {
                    _urlDraft = value;
                  },
                ),
              ),
              AppListTile(
                title: const Text('账号'),
                additionalInfo: Text(_brief(_usernameDraft)),
                onTap: () => _editField(
                  title: '账号',
                  placeholder: '请输入账号',
                  initialValue: _usernameDraft,
                  onChanged: (value) {
                    _usernameDraft = value;
                  },
                ),
              ),
              AppListTile(
                title: const Text('密码'),
                additionalInfo: Text(_maskSecret(_passwordDraft)),
                onTap: () => _editField(
                  title: '密码',
                  placeholder: '请输入密码',
                  initialValue: _passwordDraft,
                  obscureText: true,
                  onChanged: (value) {
                    _passwordDraft = value;
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
