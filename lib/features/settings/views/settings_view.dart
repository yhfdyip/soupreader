import 'package:flutter/cupertino.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../app/theme/colors.dart';
import '../../../core/database/database_service.dart';
import '../../../core/database/repositories/book_repository.dart';
import '../../../core/models/app_settings.dart';
import '../../../core/services/settings_service.dart';
import '../../../core/utils/format_utils.dart';
import '../../reader/models/reading_settings.dart';
import '../../bookshelf/views/reading_history_view.dart';
import '../../source/views/source_list_view.dart';
import 'about_settings_view.dart';
import 'backup_settings_view.dart';
import 'theme_settings_view.dart';
import 'other_settings_view.dart';
import 'settings_placeholders.dart';
import 'text_rules_settings_view.dart';

/// 设置首页
///
/// 信息架构对标你的示例（进入设置直接展开二级菜单）：
/// 1) 源管理 2) 主题 3) 功能&设置 4) 其它
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
  int? _readingHistoryCount;
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
    final readingHistoryCount = db.booksBox.values
        .where((b) =>
            b.lastReadTime != null && (b.readProgress > 0 || b.currentChapter > 0))
        .length;
    final localBookIds = db.booksBox.values
        .where((b) => b.isLocal)
        .map((b) => b.id)
        .toSet();
    final cacheInfo =
        chapterRepo.getDownloadedCacheInfo(protectBookIds: localBookIds);

    if (!mounted) return;
    setState(() {
      _sourceCount = sourceCount;
      _readingHistoryCount = readingHistoryCount;
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

  String get _themeSummary {
    final themeIndex = _readingSettings.themeIndex;
    final themeName = (themeIndex >= 0 &&
            themeIndex < AppColors.readingThemes.length)
        ? AppColors.readingThemes[themeIndex].name
        : AppColors.readingThemes.first.name;
    return '$_appearanceSummary · $themeName';
  }

  String get _sourceSummary {
    final count = _sourceCount;
    final auto = _settingsService.appSettings.autoUpdateSources ? '自动更新开' : '自动更新关';
    if (count == null) return auto;
    return '$count 个 · $auto';
  }

  String get _otherSettingsSummary {
    final wifi = _settingsService.appSettings.wifiOnlyDownload ? '仅 Wi‑Fi' : '不限网络';
    final cache = FormatUtils.formatBytes(_cacheInfo.bytes);
    return '$wifi · 缓存 $cache';
  }

  String get _readingHistorySummary {
    final count = _readingHistoryCount;
    if (count == null) return '—';
    return '$count 本';
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
              header: const Text('源管理'),
              children: [
                CupertinoListTile.notched(
                  leading: _buildIconBox(
                    CupertinoIcons.cloud_fill,
                    CupertinoColors.systemCyan,
                  ),
                  title: const Text('书源管理'),
                  additionalInfo: Text(_sourceSummary),
                  trailing: const CupertinoListTileChevron(),
                  onTap: _openSourceList,
                ),
                CupertinoListTile.notched(
                  leading: _buildIconBox(
                    CupertinoIcons.collections_solid,
                    CupertinoColors.systemCyan,
                  ),
                  title: const Text('订阅管理'),
                  additionalInfo: const Text('暂未实现'),
                  trailing: const CupertinoListTileChevron(),
                  onTap: () => SettingsPlaceholders.showNotImplemented(
                    context,
                    title: '订阅管理暂未实现',
                  ),
                ),
                CupertinoListTile.notched(
                  leading: _buildIconBox(
                    CupertinoIcons.speaker_2_fill,
                    CupertinoColors.systemCyan,
                  ),
                  title: const Text('语音管理'),
                  additionalInfo: const Text('暂未实现'),
                  trailing: const CupertinoListTileChevron(),
                  onTap: () => SettingsPlaceholders.showNotImplemented(
                    context,
                    title: '语音管理（TTS）暂未实现',
                  ),
                ),
                CupertinoListTile.notched(
                  leading: _buildIconBox(
                    CupertinoIcons.wand_stars_inverse,
                    CupertinoColors.systemCyan,
                  ),
                  title: const Text('替换净化'),
                  additionalInfo: const Text('净化/繁简'),
                  trailing: const CupertinoListTileChevron(),
                  onTap: _openTextRules,
                ),
                CupertinoListTile.notched(
                  leading: _buildIconBox(
                    CupertinoIcons.list_bullet,
                    CupertinoColors.systemCyan,
                  ),
                  title: const Text('目录规则'),
                  additionalInfo: const Text('暂未实现'),
                  trailing: const CupertinoListTileChevron(),
                  onTap: () => SettingsPlaceholders.showNotImplemented(
                    context,
                    title: '目录规则管理暂未实现（后续会合并到书源编辑器/规则调试）',
                  ),
                ),
                CupertinoListTile.notched(
                  leading: _buildIconBox(
                    CupertinoIcons.nosign,
                    CupertinoColors.systemCyan,
                  ),
                  title: const Text('广告屏蔽'),
                  additionalInfo: const Text('暂未实现'),
                  trailing: const CupertinoListTileChevron(),
                  onTap: () => SettingsPlaceholders.showNotImplemented(
                    context,
                    title: '广告屏蔽规则暂未实现',
                  ),
                ),
              ],
            ),
            CupertinoListSection.insetGrouped(
              header: const Text('主题'),
              children: [
                CupertinoListTile.notched(
                  leading: _buildIconBox(
                    CupertinoIcons.paintbrush_fill,
                    CupertinoColors.systemIndigo,
                  ),
                  title: const Text('颜色主题'),
                  additionalInfo: Text(_themeSummary),
                  trailing: const CupertinoListTileChevron(),
                  onTap: _openTheme,
                ),
              ],
            ),
            CupertinoListSection.insetGrouped(
              header: const Text('功能 & 设置'),
              children: [
                CupertinoListTile.notched(
                  leading: _buildIconBox(
                    CupertinoIcons.arrow_up_arrow_down_circle_fill,
                    CupertinoColors.systemGreen,
                  ),
                  title: const Text('备份/同步'),
                  trailing: const CupertinoListTileChevron(),
                  onTap: _openBackup,
                ),
                CupertinoListTile.notched(
                  leading: _buildIconBox(
                    CupertinoIcons.clock_fill,
                    CupertinoColors.systemBlue,
                  ),
                  title: const Text('阅读记录'),
                  additionalInfo: Text(_readingHistorySummary),
                  trailing: const CupertinoListTileChevron(),
                  onTap: _openReadingHistory,
                ),
                CupertinoListTile.notched(
                  leading: _buildIconBox(
                    CupertinoIcons.airplane,
                    CupertinoColors.systemBlue,
                  ),
                  title: const Text('隔空阅读'),
                  additionalInfo: const Text('暂未实现'),
                  trailing: const CupertinoListTileChevron(),
                  onTap: () => SettingsPlaceholders.showNotImplemented(
                    context,
                    title: '隔空阅读（接力/Handoff）暂未实现',
                  ),
                ),
                CupertinoListTile.notched(
                  leading: _buildIconBox(
                    CupertinoIcons.gear_solid,
                    CupertinoColors.systemOrange,
                  ),
                  title: const Text('其它设置'),
                  additionalInfo: Text(_otherSettingsSummary),
                  trailing: const CupertinoListTileChevron(),
                  onTap: _openOtherSettings,
                ),
              ],
            ),
            CupertinoListSection.insetGrouped(
              header: const Text('其它'),
              children: [
                CupertinoListTile.notched(
                  leading: _buildIconBox(
                    CupertinoIcons.share,
                    CupertinoColors.systemGrey,
                  ),
                  title: const Text('分享'),
                  additionalInfo: const Text('暂未实现'),
                  trailing: const CupertinoListTileChevron(),
                  onTap: () => SettingsPlaceholders.showNotImplemented(
                    context,
                    title: '分享暂未实现（可考虑接入 share_plus）',
                  ),
                ),
                CupertinoListTile.notched(
                  leading: _buildIconBox(
                    CupertinoIcons.hand_thumbsup_fill,
                    CupertinoColors.systemGrey,
                  ),
                  title: const Text('好评支持'),
                  additionalInfo: const Text('暂未实现'),
                  trailing: const CupertinoListTileChevron(),
                  onTap: () => SettingsPlaceholders.showNotImplemented(
                    context,
                    title: '好评支持暂未实现',
                  ),
                ),
                CupertinoListTile.notched(
                  leading: _buildIconBox(
                    CupertinoIcons.info_circle_fill,
                    CupertinoColors.systemGrey,
                  ),
                  title: const Text('关于我们'),
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

  Future<void> _openTheme() async {
    await Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (context) => const ThemeSettingsView(),
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

  Future<void> _openOtherSettings() async {
    await Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (context) => const OtherSettingsView(),
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

  Future<void> _openSourceList() async {
    await Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (context) => const SourceListView(),
      ),
    );
    await _refreshStats();
  }

  Future<void> _openTextRules() async {
    await Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (context) => const TextRulesSettingsView(),
      ),
    );
    await _refreshStats();
  }

  Future<void> _openReadingHistory() async {
    await Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (context) => const ReadingHistoryView(),
      ),
    );
    await _refreshStats();
  }
}
