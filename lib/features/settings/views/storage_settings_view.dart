import 'dart:async';

import 'package:flutter/cupertino.dart';

import '../../../app/widgets/app_cupertino_page_scaffold.dart';
import '../../../core/database/database_service.dart';
import '../../../core/database/repositories/book_repository.dart';
import '../../../core/services/settings_service.dart';
import '../../../core/utils/format_utils.dart';
import 'settings_ui_tokens.dart';

class StorageSettingsView extends StatefulWidget {
  const StorageSettingsView({super.key});

  @override
  State<StorageSettingsView> createState() => _StorageSettingsViewState();
}

class _StorageSettingsViewState extends State<StorageSettingsView> {
  final SettingsService _settingsService = SettingsService();
  late final BookRepository _bookRepo;
  late final ChapterRepository _chapterRepo;

  ChapterCacheInfo _cacheInfo = const ChapterCacheInfo(bytes: 0, chapters: 0);

  @override
  void initState() {
    super.initState();
    final db = DatabaseService();
    _bookRepo = BookRepository(db);
    _chapterRepo = ChapterRepository(db);
    _refreshCacheInfo();
  }

  void _refreshCacheInfo() {
    final localBookIds =
        _bookRepo.getAllBooks().where((b) => b.isLocal).map((b) => b.id).toSet();
    final info =
        _chapterRepo.getDownloadedCacheInfo(protectBookIds: localBookIds);
    if (!mounted) return;
    setState(() => _cacheInfo = info);
  }

  @override
  Widget build(BuildContext context) {
    final wifiOnly = _settingsService.appSettings.wifiOnlyDownload;
    final cacheText = FormatUtils.formatBytes(_cacheInfo.bytes);
    final chapterText =
        _cacheInfo.chapters == 0 ? '无' : '${_cacheInfo.chapters} 章';

    return AppCupertinoPageScaffold(
      title: '下载与缓存',
      child: ListView(
        padding: const EdgeInsets.only(top: 8, bottom: 20),
        children: [
          CupertinoListSection.insetGrouped(
            header: const Text('下载'),
            children: [
              CupertinoListTile.notched(
                title: const Text('仅 Wi‑Fi 下载'),
                trailing: CupertinoSwitch(
                  value: wifiOnly,
                  onChanged: (v) async {
                    await _settingsService.saveAppSettings(
                      _settingsService.appSettings
                          .copyWith(wifiOnlyDownload: v),
                    );
                    if (mounted) setState(() {});
                  },
                ),
              ),
            ],
          ),
          CupertinoListSection.insetGrouped(
            header: const Text('缓存'),
            children: [
              CupertinoListTile.notched(
                title: const Text('章节缓存占用'),
                additionalInfo:
                    Text(SettingsUiTokens.status(cacheText, chapterText)),
              ),
              CupertinoListTile.notched(
                title: const Text('清理章节缓存（在线书籍）'),
                trailing: const CupertinoListTileChevron(),
                onTap: _confirmClearCache,
              ),
            ],
          ),
          CupertinoListSection.insetGrouped(
            header: const Text('说明'),
            children: const [
              CupertinoListTile(
                title: Text('清理缓存不会影响书架与阅读进度；本地导入书籍的正文不会被清理。'),
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Future<void> _confirmClearCache() async {
    final sizeText = FormatUtils.formatBytes(_cacheInfo.bytes);
    final chapterText =
        _cacheInfo.chapters == 0 ? '无' : '${_cacheInfo.chapters} 章';

    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('清理章节缓存？'),
        content: Text(
            '\n当前缓存 $sizeText（$chapterText）\n\n将删除在线书籍已缓存的章节内容，本地导入书籍不受影响。'),
        actions: [
          CupertinoDialogAction(
            child: const Text('取消'),
            onPressed: () => Navigator.pop(context, false),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: const Text('清理'),
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _clearCache();
  }

  Future<void> _clearCache() async {
    showCupertinoDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CupertinoActivityIndicator()),
    );

    try {
      final localBookIds = _bookRepo
          .getAllBooks()
          .where((b) => b.isLocal)
          .map((b) => b.id)
          .toSet();
      final result =
          await _chapterRepo.clearDownloadedCache(protectBookIds: localBookIds);

      if (!mounted) return;
      Navigator.pop(context);

      _refreshCacheInfo();
      _showMessage(result.chapters == 0
          ? '没有可清理的缓存'
          : '已清理 ${FormatUtils.formatBytes(result.bytes)}（${result.chapters} 章）');
    } catch (_) {
      if (!mounted) return;
      Navigator.pop(context);
      _showMessage('清理失败');
    }
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
