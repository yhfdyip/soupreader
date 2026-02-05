import 'package:flutter/cupertino.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../app/theme/colors.dart';
import '../../../core/database/database_service.dart';
import '../../../core/database/repositories/book_repository.dart';
import '../../../core/models/app_settings.dart';
import '../../../core/services/settings_service.dart';
import '../../../core/utils/format_utils.dart';
import '../../reader/models/reading_settings.dart';
import '../../source/views/source_list_view.dart';
import 'about_settings_view.dart';
import 'appearance_settings_view.dart';
import 'backup_settings_view.dart';
import 'global_reading_settings_view.dart';
import 'storage_settings_view.dart';

/// 设置首页 - 以“分类入口 + 摘要”为主（对标 Legado/同级阅读器的 IA）
///
/// 设计目标：
/// - 首页不堆细项，只做导航
/// - 每个入口显示“当前状态摘要”，用户一眼知道设置作用域
class SettingsView extends StatefulWidget {
  const SettingsView({super.key});

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  final SettingsService _settingsService = SettingsService();
  late ReadingSettings _readingSettings;

  String _version = '';
  int? _sourceCount;
  ChapterCacheInfo _cacheInfo = const ChapterCacheInfo(bytes: 0, chapters: 0);

  @override
  void initState() {
    super.initState();
    _readingSettings = _settingsService.readingSettings;
    _loadVersion();
    _refreshStats();
  }

  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (!mounted) return;
      setState(() {
        _version = '${info.version} (${info.buildNumber})';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _version = '—');
    }
  }

  Future<void> _refreshStats() async {
    final db = DatabaseService();
    final chapterRepo = ChapterRepository(db);

    final sourceCount = db.sourcesBox.length;
    final localBookIds = db.booksBox.values
        .where((b) => b.isLocal)
        .map((b) => b.id)
        .toSet();
    final cacheInfo =
        chapterRepo.getDownloadedCacheInfo(protectBookIds: localBookIds);

    if (!mounted) return;
    setState(() {
      _sourceCount = sourceCount;
      _cacheInfo = cacheInfo;
      _readingSettings = _settingsService.readingSettings;
    });
  }

  String get _appearanceSummary {
    final app = _settingsService.appSettings;
    switch (app.appearanceMode) {
      case AppAppearanceMode.followSystem:
        return '跟随系统';
      case AppAppearanceMode.light:
        return '浅色';
      case AppAppearanceMode.dark:
        return '深色';
    }
  }

  String get _readingSummary {
    final fontSize = _readingSettings.fontSize.toInt();
    final lineHeight = _readingSettings.lineHeight.toStringAsFixed(1);
    final themeIndex = _readingSettings.themeIndex;
    final themeName = (themeIndex >= 0 &&
            themeIndex < AppColors.readingThemes.length)
        ? AppColors.readingThemes[themeIndex].name
        : AppColors.readingThemes.first.name;
    return '$fontSize · $themeName · $lineHeight';
  }

  String get _sourceSummary {
    final count = _sourceCount;
    final auto = _settingsService.appSettings.autoUpdateSources ? '自动更新开' : '自动更新关';
    if (count == null) return auto;
    return '$count 个 · $auto';
  }

  String get _storageSummary {
    final wifi = _settingsService.appSettings.wifiOnlyDownload ? '仅 Wi‑Fi' : '不限网络';
    final cache = FormatUtils.formatBytes(_cacheInfo.bytes);
    return '$wifi · 缓存 $cache';
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('设置'),
      ),
      child: SafeArea(
        child: ListView(
          children: [
            CupertinoListSection.insetGrouped(
              header: const Text('分类'),
              children: [
                CupertinoListTile.notched(
                  leading: _buildIconBox(
                    CupertinoIcons.brightness_solid,
                    CupertinoColors.systemIndigo,
                  ),
                  title: const Text('外观与通用'),
                  additionalInfo: Text(_appearanceSummary),
                  trailing: const CupertinoListTileChevron(),
                  onTap: _openAppearance,
                ),
                CupertinoListTile.notched(
                  leading: _buildIconBox(
                    CupertinoIcons.book,
                    CupertinoColors.systemBlue,
                  ),
                  title: const Text('阅读（全局默认）'),
                  additionalInfo: Text(_readingSummary),
                  trailing: const CupertinoListTileChevron(),
                  onTap: _openGlobalReading,
                ),
                CupertinoListTile.notched(
                  leading: _buildIconBox(
                    CupertinoIcons.cloud_fill,
                    CupertinoColors.systemCyan,
                  ),
                  title: const Text('书源'),
                  additionalInfo: Text(_sourceSummary),
                  trailing: const CupertinoListTileChevron(),
                  onTap: _openSource,
                ),
                CupertinoListTile.notched(
                  leading: _buildIconBox(
                    CupertinoIcons.archivebox_fill,
                    CupertinoColors.systemOrange,
                  ),
                  title: const Text('下载与缓存'),
                  additionalInfo: Text(_storageSummary),
                  trailing: const CupertinoListTileChevron(),
                  onTap: _openStorage,
                ),
                CupertinoListTile.notched(
                  leading: _buildIconBox(
                    CupertinoIcons.arrow_up_arrow_down_circle_fill,
                    CupertinoColors.systemGreen,
                  ),
                  title: const Text('备份与恢复'),
                  trailing: const CupertinoListTileChevron(),
                  onTap: _openBackup,
                ),
                CupertinoListTile.notched(
                  leading: _buildIconBox(
                    CupertinoIcons.info_circle_fill,
                    CupertinoColors.systemGrey,
                  ),
                  title: const Text('关于与诊断'),
                  additionalInfo: Text(_version.isEmpty ? '—' : _version),
                  trailing: const CupertinoListTileChevron(),
                  onTap: _openAbout,
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildIconBox(IconData icon, Color color) {
    return Container(
      width: 29,
      height: 29,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Icon(icon, color: CupertinoColors.white, size: 17),
    );
  }

  Future<void> _openAppearance() async {
    await Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (context) => const AppearanceSettingsView(),
      ),
    );
    await _refreshStats();
  }

  Future<void> _openGlobalReading() async {
    await Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (context) => const GlobalReadingSettingsView(),
      ),
    );
    await _refreshStats();
  }

  Future<void> _openSource() async {
    await Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (context) => const SourceListView(),
      ),
    );
    await _refreshStats();
  }

  Future<void> _openStorage() async {
    await Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (context) => const StorageSettingsView(),
      ),
    );
    await _refreshStats();
  }

  Future<void> _openBackup() async {
    await Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (context) => const BackupSettingsView(),
      ),
    );
    await _refreshStats();
  }

  Future<void> _openAbout() async {
    await Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (context) => const AboutSettingsView(),
      ),
    );
    await _refreshStats();
  }
}
