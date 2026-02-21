import 'package:flutter/cupertino.dart';

import '../../../app/widgets/app_cupertino_page_scaffold.dart';
import '../../../core/services/backup_service.dart';
import '../../../core/services/settings_service.dart';
import '../../../core/services/webdav_service.dart';

class BackupSettingsView extends StatefulWidget {
  const BackupSettingsView({super.key});

  @override
  State<BackupSettingsView> createState() => _BackupSettingsViewState();
}

class _BackupSettingsViewState extends State<BackupSettingsView> {
  final BackupService _backupService = BackupService();
  final SettingsService _settingsService = SettingsService();
  final WebDavService _webDavService = WebDavService();

  @override
  void initState() {
    super.initState();
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

  @override
  Widget build(BuildContext context) {
    return AppCupertinoPageScaffold(
      title: '备份与恢复',
      child: ListView(
        padding: const EdgeInsets.only(top: 8, bottom: 20),
        children: [
          CupertinoListSection.insetGrouped(
            header: const Text('导出'),
            children: [
              CupertinoListTile.notched(
                title: const Text('导出备份（推荐）'),
                additionalInfo: const Text('不含在线缓存'),
                trailing: const CupertinoListTileChevron(),
                onTap: () => _export(includeOnlineCache: false),
              ),
              CupertinoListTile.notched(
                title: const Text('导出（含在线缓存）'),
                additionalInfo: const Text('体积大'),
                trailing: const CupertinoListTileChevron(),
                onTap: () => _export(includeOnlineCache: true),
              ),
            ],
          ),
          CupertinoListSection.insetGrouped(
            header: const Text('导入'),
            children: [
              CupertinoListTile.notched(
                title: const Text('从文件导入（合并）'),
                additionalInfo: const Text('不清空当前数据'),
                trailing: const CupertinoListTileChevron(),
                onTap: () => _import(overwrite: false),
              ),
              CupertinoListTile.notched(
                title: const Text('从文件导入（覆盖）'),
                additionalInfo: const Text('会清空当前数据'),
                trailing: const CupertinoListTileChevron(),
                onTap: () => _import(overwrite: true),
              ),
            ],
          ),
          CupertinoListSection.insetGrouped(
            header: const Text('WebDav 同步'),
            children: [
              CupertinoListTile.notched(
                title: const Text('同步阅读进度'),
                additionalInfo: const Text('进入退出阅读界面时同步阅读进度'),
                trailing: CupertinoSwitch(
                  value: _settingsService.appSettings.syncBookProgress,
                  onChanged: (value) async {
                    await _settingsService.saveAppSettings(
                      _settingsService.appSettings
                          .copyWith(syncBookProgress: value),
                    );
                    if (!mounted) return;
                    setState(() {});
                  },
                ),
              ),
              CupertinoListTile.notched(
                title: const Text('服务器地址'),
                additionalInfo: Text(
                  _brief(_settingsService.appSettings.webDavUrl),
                ),
                trailing: const CupertinoListTileChevron(),
                onTap: () => _editWebDavField(
                  title: '服务器地址',
                  placeholder: 'https://dav.example.com/dav/',
                  initialValue: _settingsService.appSettings.webDavUrl,
                  onSave: (value) async {
                    await _settingsService.saveAppSettings(
                      _settingsService.appSettings.copyWith(webDavUrl: value),
                    );
                  },
                ),
              ),
              CupertinoListTile.notched(
                title: const Text('账号'),
                additionalInfo: Text(
                  _brief(_settingsService.appSettings.webDavAccount),
                ),
                trailing: const CupertinoListTileChevron(),
                onTap: () => _editWebDavField(
                  title: 'WebDav 账号',
                  placeholder: '请输入账号',
                  initialValue: _settingsService.appSettings.webDavAccount,
                  onSave: (value) async {
                    await _settingsService.saveAppSettings(
                      _settingsService.appSettings
                          .copyWith(webDavAccount: value),
                    );
                  },
                ),
              ),
              CupertinoListTile.notched(
                title: const Text('密码'),
                additionalInfo: Text(
                  _maskSecret(_settingsService.appSettings.webDavPassword),
                ),
                trailing: const CupertinoListTileChevron(),
                onTap: () => _editWebDavField(
                  title: 'WebDav 密码',
                  placeholder: '请输入密码',
                  initialValue: _settingsService.appSettings.webDavPassword,
                  obscureText: true,
                  onSave: (value) async {
                    await _settingsService.saveAppSettings(
                      _settingsService.appSettings
                          .copyWith(webDavPassword: value),
                    );
                  },
                ),
              ),
              CupertinoListTile.notched(
                title: const Text('同步目录'),
                additionalInfo: Text(
                  _brief(_settingsService.appSettings.webDavDir, fallback: '/'),
                ),
                trailing: const CupertinoListTileChevron(),
                onTap: () => _editWebDavField(
                  title: '同步目录',
                  placeholder: '可留空，例如 booksync',
                  initialValue: _settingsService.appSettings.webDavDir,
                  onSave: (value) async {
                    await _settingsService.saveAppSettings(
                      _settingsService.appSettings.copyWith(webDavDir: value),
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
          CupertinoListSection.insetGrouped(
            header: const Text('说明'),
            children: const [
              CupertinoListTile(
                title: Text('备份包含：设置、书源、书架、本地书籍章节内容，以及“本书独立阅读设置”。'),
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Future<void> _export({required bool includeOnlineCache}) async {
    showCupertinoDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CupertinoActivityIndicator()),
    );
    final result = await _backupService.exportToFile(
      includeOnlineCache: includeOnlineCache,
    );
    if (!mounted) return;
    Navigator.pop(context);
    if (result.cancelled) return;
    _showMessage(result.success ? '导出成功' : (result.errorMessage ?? '导出失败'));
  }

  Future<void> _import({required bool overwrite}) async {
    if (overwrite) {
      final confirmed = await showCupertinoDialog<bool>(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text('确认覆盖导入？'),
          content: const Text('\n将清空当前书架、书源与缓存，再从备份恢复。此操作不可撤销。'),
          actions: [
            CupertinoDialogAction(
              child: const Text('取消'),
              onPressed: () => Navigator.pop(context, false),
            ),
            CupertinoDialogAction(
              isDestructiveAction: true,
              child: const Text('继续'),
              onPressed: () => Navigator.pop(context, true),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    if (!mounted) return;
    showCupertinoDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CupertinoActivityIndicator()),
    );
    final result = await _backupService.importFromFile(overwrite: overwrite);
    if (!mounted) return;
    Navigator.pop(context);
    if (result.cancelled) return;
    if (!result.success) {
      _showMessage(result.errorMessage ?? '导入失败');
      return;
    }
    _showMessage(
      '导入完成：书源 ${result.sourcesImported} 条，书籍 ${result.booksImported} 本，章节 ${result.chaptersImported} 章',
    );
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

  String _brief(String value, {String fallback = '未设置'}) {
    final text = value.trim();
    if (text.isEmpty) return fallback;
    if (text.length <= 22) return text;
    return '${text.substring(0, 22)}…';
  }

  String _maskSecret(String value) {
    final text = value.trim();
    if (text.isEmpty) return '未设置';
    return '已设置（${text.length} 位）';
  }

  void _showMessage(String message) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('提示'),
        content: Text('\n$message'),
        actions: [
          CupertinoDialogAction(
            child: const Text('好'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }
}
