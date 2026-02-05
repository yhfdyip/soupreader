import 'package:flutter/cupertino.dart';

import '../../../core/services/backup_service.dart';

class BackupSettingsView extends StatefulWidget {
  const BackupSettingsView({super.key});

  @override
  State<BackupSettingsView> createState() => _BackupSettingsViewState();
}

class _BackupSettingsViewState extends State<BackupSettingsView> {
  final BackupService _backupService = BackupService();

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('备份与恢复'),
      ),
      child: SafeArea(
        child: ListView(
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

