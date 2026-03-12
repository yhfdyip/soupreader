import 'dart:async';

import 'package:flutter/cupertino.dart';

import '../../../app/widgets/app_ui_kit.dart';
import '../../../app/widgets/cupertino_bottom_dialog.dart';

import '../../../app/widgets/app_cupertino_page_scaffold.dart';
import '../../../core/database/database_service.dart';
import '../../../core/database/repositories/book_repository.dart';
import '../../../core/services/settings_service.dart';
import '../../../core/utils/format_utils.dart';
import '../services/other_maintenance_service.dart';
import 'settings_ui_tokens.dart';

class StorageSettingsView extends StatefulWidget {
  const StorageSettingsView({super.key});

  @override
  State<StorageSettingsView> createState() => _StorageSettingsViewState();
}

class _StorageSettingsViewState extends State<StorageSettingsView> {
  final SettingsService _settingsService = SettingsService();
  final OtherMaintenanceService _maintenanceService = OtherMaintenanceService();
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
    final localBookIds = _bookRepo
        .getAllBooks()
        .where((b) => b.isLocal)
        .map((b) => b.id)
        .toSet();
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
      child: AppListView(
        children: [
          AppListSection(
            header: const Text('下载'),
            hasLeading: false,
            children: [
              AppListTile(
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
          AppListSection(
            header: const Text('缓存'),
            hasLeading: false,
            children: [
              AppListTile(
                title: const Text('章节缓存占用'),
                additionalInfo:
                    Text(SettingsUiTokens.status(cacheText, chapterText)),
              ),
              AppListTile(
                title: const Text('清理缓存'),                onTap: _confirmClearCache,
              ),
            ],
          ),
          AppListSection(
            header: const Text('维护'),
            hasLeading: false,
            children: [
              AppListTile(
                title: const Text('清除 WebView 数据'),                onTap: _confirmClearWebViewData,
              ),
              AppListTile(
                title: const Text('压缩数据库'),                onTap: _confirmShrinkDatabase,
              ),
            ],
          ),
          const AppListSection(
            header: const Text('说明'),
            hasLeading: false,
            children: [
              AppListTile(
                title: Text('清理缓存不会影响书架与阅读进度；本地导入书籍正文不会被清理。'),
                showChevron: false,
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

    final confirmed = await showCupertinoBottomSheetDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('清理缓存'),
        content:
            Text('\n当前章节缓存 $sizeText（$chapterText）\n\n将删除在线书籍缓存与应用缓存目录，是否继续？'),
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
    await _runMaintenanceAction(
      loadingMessage: '正在清理缓存...',
      action: _maintenanceService.cleanCache,
      refreshCacheInfo: true,
    );
  }

  Future<void> _confirmClearWebViewData() async {
    final confirmed = await showCupertinoBottomSheetDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('清除 WebView 数据'),
        content: const Text('\n将清除内置浏览器所有数据，是否继续？'),
        actions: [
          CupertinoDialogAction(
            child: const Text('取消'),
            onPressed: () => Navigator.pop(context, false),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: const Text('清除'),
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _runMaintenanceAction(
      loadingMessage: '正在清除 WebView 数据...',
      action: _maintenanceService.clearWebViewData,
      refreshCacheInfo: false,
    );
  }

  Future<void> _confirmShrinkDatabase() async {
    final confirmed = await showCupertinoBottomSheetDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('压缩数据库'),
        content: const Text('\n将执行数据库压缩，是否继续？'),
        actions: [
          CupertinoDialogAction(
            child: const Text('取消'),
            onPressed: () => Navigator.pop(context, false),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: const Text('确定'),
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _runMaintenanceAction(
      loadingMessage: '正在压缩数据库...',
      action: _maintenanceService.shrinkDatabase,
      refreshCacheInfo: false,
    );
  }

  Future<void> _runMaintenanceAction({
    required String loadingMessage,
    required Future<MaintenanceActionResult> Function() action,
    required bool refreshCacheInfo,
  }) async {
    showCupertinoBottomSheetDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => CupertinoAlertDialog(
        content: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CupertinoActivityIndicator(),
              const SizedBox(height: 12),
              Text(loadingMessage),
            ],
          ),
        ),
      ),
    );

    MaintenanceActionResult result;
    try {
      result = await action();
    } catch (error) {
      result = MaintenanceActionResult(
        success: false,
        message: '执行失败',
        detail: '$error',
      );
    }

    if (!mounted) return;
    Navigator.pop(context);

    if (refreshCacheInfo) {
      _refreshCacheInfo();
    }
    _showMessage(result.message, detail: result.success ? null : result.detail);
  }

  void _showMessage(String message, {String? detail}) {
    final normalizedDetail = (detail ?? '').trim();
    showCupertinoBottomSheetDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('提示'),
        content: Text(
          normalizedDetail.isEmpty
              ? '\n$message'
              : '\n$message\n\n$normalizedDetail',
        ),
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
