import 'package:flutter/cupertino.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../app/theme/colors.dart';
import '../../../app/widgets/app_cupertino_page_scaffold.dart';
import '../../../core/database/database_service.dart';
import '../../../core/database/repositories/book_repository.dart';
import '../../../core/database/repositories/source_repository.dart';
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
import 'settings_ui_tokens.dart';
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
    final bookRepo = BookRepository(db);
    final chapterRepo = ChapterRepository(db);
    final sourceRepo = SourceRepository(db);

    final books = bookRepo.getAllBooks();
    final sourceCount = sourceRepo.getAllSources().length;
    final readingHistoryCount = books
        .where((b) =>
            b.lastReadTime != null &&
            (b.readProgress > 0 || b.currentChapter > 0))
        .length;
    final localBookIds = books.where((b) => b.isLocal).map((b) => b.id).toSet();
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
    final themeName =
        (themeIndex >= 0 && themeIndex < AppColors.readingThemes.length)
            ? AppColors.readingThemes[themeIndex].name
            : AppColors.readingThemes.first.name;
    return '$_appearanceSummary · $themeName';
  }

  String get _sourceSummary {
    final count = _sourceCount;
    final auto =
        _settingsService.appSettings.autoUpdateSources ? '自动更新开' : '自动更新关';
    if (count == null) return auto;
    return SettingsUiTokens.status('$count 个', auto);
  }

  String get _otherSettingsSummary {
    final wifi =
        _settingsService.appSettings.wifiOnlyDownload ? '仅 Wi‑Fi' : '不限网络';
    final cache = FormatUtils.formatBytes(_cacheInfo.bytes);
    return SettingsUiTokens.status(wifi, '缓存 $cache');
  }

  String get _readingHistorySummary {
    final count = _readingHistoryCount;
    if (count == null) return '—';
    return '$count 本';
  }

  @override
  Widget build(BuildContext context) {
    return AppCupertinoPageScaffold(
      title: '设置',
      child: ListView(
        padding: const EdgeInsets.only(top: 8, bottom: 20),
        children: [
          _buildSection(
            title: '源管理',
            items: [
              _buildSettingsItem(
                icon: _buildIconBox(
                  CupertinoIcons.cloud_fill,
                  CupertinoColors.systemCyan,
                ),
                title: '书源管理',
                info: _sourceSummary,
                onTap: _openSourceList,
              ),
              _buildSettingsItem(
                icon: _buildIconBox(
                  CupertinoIcons.wand_stars_inverse,
                  CupertinoColors.systemCyan,
                ),
                title: '替换净化',
                info: '净化/繁简',
                onTap: _openTextRules,
              ),
              _buildSettingsItem(
                icon: _buildIconBox(
                  CupertinoIcons.list_bullet,
                  CupertinoColors.systemCyan,
                ),
                title: '目录规则',
                info: '书源编辑',
                onTap: _openSourceList,
              ),
              _buildSettingsItem(
                icon: _buildIconBox(
                  CupertinoIcons.collections_solid,
                  CupertinoColors.systemCyan,
                ),
                title: '订阅管理',
                info: SettingsUiTokens.plannedLabel,
                isPlanned: true,
                onTap: () => SettingsPlaceholders.showNotImplemented(
                  context,
                  title: '订阅管理暂未实现',
                ),
              ),
              _buildSettingsItem(
                icon: _buildIconBox(
                  CupertinoIcons.speaker_2_fill,
                  CupertinoColors.systemCyan,
                ),
                title: '语音管理',
                info: SettingsUiTokens.plannedLabel,
                isPlanned: true,
                onTap: () => SettingsPlaceholders.showNotImplemented(
                  context,
                  title: '语音管理（TTS）暂未实现',
                ),
              ),
              _buildSettingsItem(
                icon: _buildIconBox(
                  CupertinoIcons.nosign,
                  CupertinoColors.systemCyan,
                ),
                title: '广告屏蔽',
                info: SettingsUiTokens.plannedLabel,
                isPlanned: true,
                onTap: () => SettingsPlaceholders.showNotImplemented(
                  context,
                  title: '广告屏蔽规则暂未实现',
                ),
              ),
            ],
          ),
          _buildSection(
            title: '主题',
            items: [
              _buildSettingsItem(
                icon: _buildIconBox(
                  CupertinoIcons.paintbrush_fill,
                  CupertinoColors.systemIndigo,
                ),
                title: '颜色主题',
                info: _themeSummary,
                onTap: _openTheme,
              ),
            ],
          ),
          _buildSection(
            title: '功能 & 设置',
            items: [
              _buildSettingsItem(
                icon: _buildIconBox(
                  CupertinoIcons.arrow_up_arrow_down_circle_fill,
                  CupertinoColors.systemGreen,
                ),
                title: '备份/同步',
                info: '导入/导出',
                onTap: _openBackup,
              ),
              _buildSettingsItem(
                icon: _buildIconBox(
                  CupertinoIcons.clock_fill,
                  CupertinoColors.systemBlue,
                ),
                title: '阅读记录',
                info: _readingHistorySummary,
                onTap: _openReadingHistory,
              ),
              _buildSettingsItem(
                icon: _buildIconBox(
                  CupertinoIcons.gear_solid,
                  CupertinoColors.systemOrange,
                ),
                title: '其它设置',
                info: _otherSettingsSummary,
                onTap: _openOtherSettings,
              ),
              _buildSettingsItem(
                icon: _buildIconBox(
                  CupertinoIcons.airplane,
                  CupertinoColors.systemBlue,
                ),
                title: '隔空阅读',
                info: SettingsUiTokens.plannedLabel,
                isPlanned: true,
                onTap: () => SettingsPlaceholders.showNotImplemented(
                  context,
                  title: '隔空阅读（接力/Handoff）暂未实现',
                ),
              ),
            ],
          ),
          _buildSection(
            title: '其它',
            items: [
              _buildSettingsItem(
                icon: _buildIconBox(
                  CupertinoIcons.share,
                  CupertinoColors.systemGrey,
                ),
                title: '关于我们',
                info: _version.isEmpty ? '—' : _version,
                onTap: _openAbout,
              ),
              _buildSettingsItem(
                icon: _buildIconBox(
                  CupertinoIcons.share,
                  CupertinoColors.systemGrey,
                ),
                title: '分享',
                info: SettingsUiTokens.plannedLabel,
                isPlanned: true,
                onTap: () => SettingsPlaceholders.showNotImplemented(
                  context,
                  title: '分享暂未实现（可考虑接入 share_plus）',
                ),
              ),
              _buildSettingsItem(
                icon: _buildIconBox(
                  CupertinoIcons.hand_thumbsup_fill,
                  CupertinoColors.systemGrey,
                ),
                title: '好评支持',
                info: SettingsUiTokens.plannedLabel,
                isPlanned: true,
                onTap: () => SettingsPlaceholders.showNotImplemented(
                  context,
                  title: '好评支持暂未实现',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required List<Widget> items,
  }) {
    final theme = ShadTheme.of(context);
    final scheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 6),
            child: Text(
              title,
              style: theme.textTheme.small.copyWith(
                fontWeight: FontWeight.w600,
                color: scheme.mutedForeground,
              ),
            ),
          ),
          ShadCard(
            padding: EdgeInsets.zero,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: _withSeparators(items),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _withSeparators(List<Widget> items) {
    final result = <Widget>[];
    for (var i = 0; i < items.length; i++) {
      result.add(items[i]);
      if (i == items.length - 1) continue;
      result.add(
        const ShadSeparator.horizontal(
          margin: EdgeInsets.symmetric(horizontal: 12),
        ),
      );
    }
    return result;
  }

  Widget _buildSettingsItem({
    required Widget icon,
    required String title,
    String? info,
    bool isPlanned = false,
    required VoidCallback onTap,
  }) {
    final theme = ShadTheme.of(context);
    final scheme = theme.colorScheme;
    final titleColor = isPlanned ? scheme.mutedForeground : scheme.foreground;
    final infoColor = isPlanned
        ? scheme.mutedForeground.withValues(alpha: 0.75)
        : scheme.mutedForeground;
    final normalizedInfo = info?.trim() ?? '';

    return ShadButton.ghost(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      mainAxisAlignment: MainAxisAlignment.start,
      onPressed: onTap,
      child: Row(
        children: [
          Opacity(
            opacity: isPlanned ? 0.65 : 1.0,
            child: icon,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.p.copyWith(color: titleColor),
                ),
                if (normalizedInfo.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    normalizedInfo,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.small.copyWith(
                      color: infoColor,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            LucideIcons.chevronRight,
            size: 16,
            color: scheme.mutedForeground,
          ),
        ],
      ),
    );
  }

  Widget _buildIconBox(IconData icon, Color color) {
    return Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Icon(icon, color: CupertinoColors.white, size: 15),
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
