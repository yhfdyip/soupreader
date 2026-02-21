import 'package:flutter/cupertino.dart';

import '../../../app/widgets/app_cupertino_page_scaffold.dart';
import '../../../core/models/app_settings.dart';
import '../../../core/services/settings_service.dart';
import '../../../core/services/webdav_service.dart';

/// 远程书籍服务器配置页（对应 legado `menu_server_config` 入口）。
class RemoteBooksServerConfigView extends StatefulWidget {
  const RemoteBooksServerConfigView({
    super.key,
    this.settingsService,
    this.webDavService,
  });

  final SettingsService? settingsService;
  final WebDavService? webDavService;

  @override
  State<RemoteBooksServerConfigView> createState() =>
      _RemoteBooksServerConfigViewState();
}

class _RemoteBooksServerConfigViewState
    extends State<RemoteBooksServerConfigView> {
  late final SettingsService _settingsService;
  late final WebDavService _webDavService;

  @override
  void initState() {
    super.initState();
    _settingsService = widget.settingsService ?? SettingsService();
    _webDavService = widget.webDavService ?? WebDavService();
    _settingsService.appSettingsListenable.addListener(_onSettingsChanged);
  }

  @override
  void dispose() {
    _settingsService.appSettingsListenable.removeListener(_onSettingsChanged);
    super.dispose();
  }

  void _onSettingsChanged() {
    if (!mounted) return;
    setState(() {});
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

  Future<void> _editWebDavField({
    required String title,
    required String placeholder,
    required String initialValue,
    required Future<void> Function(String value) onSave,
    bool obscureText = false,
  }) async {
    final controller = TextEditingController(text: initialValue);
    final result = await showCupertinoDialog<String>(
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
    await onSave(result.trim());
    if (!mounted) return;
    _showMessage('已保存');
  }

  Future<void> _testWebDavConnection() async {
    showCupertinoDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CupertinoActivityIndicator()),
    );

    var message = '连接成功，已准备 WebDav books 目录';
    try {
      await _webDavService
          .ensureUploadDirectories(_settingsService.appSettings);
    } catch (error) {
      message = error.toString();
    } finally {
      if (mounted) {
        Navigator.pop(context);
      }
    }

    if (!mounted) return;
    _showMessage(message);
  }

  void _showMessage(String message) {
    showCupertinoDialog(
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
    final settings = _settingsService.appSettings;
    return AppCupertinoPageScaffold(
      title: '服务器配置',
      child: ListView(
        padding: const EdgeInsets.only(top: 8, bottom: 20),
        children: [
          CupertinoListSection.insetGrouped(
            header: const Text('WebDav'),
            children: [
              CupertinoListTile.notched(
                title: const Text('服务器地址'),
                additionalInfo: Text(
                  _brief(
                    settings.webDavUrl,
                    fallback: AppSettings.defaultWebDavUrl,
                  ),
                ),
                trailing: const CupertinoListTileChevron(),
                onTap: () => _editWebDavField(
                  title: '服务器地址',
                  placeholder: 'https://dav.example.com/dav/',
                  initialValue: settings.webDavUrl,
                  onSave: (value) async {
                    await _settingsService.saveAppSettings(
                      settings.copyWith(webDavUrl: value),
                    );
                  },
                ),
              ),
              CupertinoListTile.notched(
                title: const Text('账号'),
                additionalInfo: Text(_brief(settings.webDavAccount)),
                trailing: const CupertinoListTileChevron(),
                onTap: () => _editWebDavField(
                  title: 'WebDav 账号',
                  placeholder: '请输入账号',
                  initialValue: settings.webDavAccount,
                  onSave: (value) async {
                    await _settingsService.saveAppSettings(
                      settings.copyWith(webDavAccount: value),
                    );
                  },
                ),
              ),
              CupertinoListTile.notched(
                title: const Text('密码'),
                additionalInfo: Text(_maskSecret(settings.webDavPassword)),
                trailing: const CupertinoListTileChevron(),
                onTap: () => _editWebDavField(
                  title: 'WebDav 密码',
                  placeholder: '请输入密码',
                  initialValue: settings.webDavPassword,
                  obscureText: true,
                  onSave: (value) async {
                    await _settingsService.saveAppSettings(
                      settings.copyWith(webDavPassword: value),
                    );
                  },
                ),
              ),
              CupertinoListTile.notched(
                title: const Text('同步目录'),
                additionalInfo: Text(_brief(settings.webDavDir, fallback: '/')),
                trailing: const CupertinoListTileChevron(),
                onTap: () => _editWebDavField(
                  title: '同步目录',
                  placeholder: '可留空，例如 booksync',
                  initialValue: settings.webDavDir,
                  onSave: (value) async {
                    await _settingsService.saveAppSettings(
                      settings.copyWith(webDavDir: value),
                    );
                  },
                ),
              ),
              CupertinoListTile.notched(
                title: const Text('测试连接'),
                additionalInfo: const Text('检查授权并准备 books 目录'),
                trailing: const CupertinoListTileChevron(),
                onTap: _testWebDavConnection,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
