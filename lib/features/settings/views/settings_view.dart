import 'package:flutter/cupertino.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../app/theme/colors.dart';
import '../../../app/widgets/app_cupertino_page_scaffold.dart';
import '../../../core/database/database_service.dart';
import '../../../core/database/repositories/book_repository.dart';
import '../../../core/database/repositories/source_repository.dart';
import '../../../core/models/app_settings.dart';
import '../../../core/services/settings_service.dart';
import '../../../core/utils/format_utils.dart';
import '../../reader/models/reading_settings.dart';
import 'developer_tools_view.dart';
import 'function_settings_view.dart';
import 'other_hub_view.dart';
import 'source_management_view.dart';
import 'theme_settings_view.dart';

/// 设置首页（一级入口页）
///
/// 目标：减少首屏拥挤，将具体配置下沉到二级页面。
class SettingsView extends StatefulWidget {
  const SettingsView({super.key});

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  final SettingsService _settingsService = SettingsService();
  late ReadingSettings _readingSettings;

  String _version = '—';
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
    return '$count 个书源 · $auto';
  }

  String get _functionSummary {
    final history = _readingHistoryCount == null ? '—' : '$_readingHistoryCount 本';
    final cache = FormatUtils.formatBytes(_cacheInfo.bytes);
    return '阅读记录 $history · 缓存 $cache';
  }

  @override
  Widget build(BuildContext context) {
    return AppCupertinoPageScaffold(
      title: '设置',
      child: ListView(
        padding: const EdgeInsets.only(top: 8, bottom: 20),
        children: [
          CupertinoListSection.insetGrouped(
            header: const Text('设置分组'),
            children: [
              CupertinoListTile.notched(
                title: const Text('源管理'),
                additionalInfo: Text(_sourceSummary),
                trailing: const CupertinoListTileChevron(),
                onTap: () => _open(
                  context,
                  const SourceManagementView(),
                ),
              ),
              CupertinoListTile.notched(
                title: const Text('主题'),
                additionalInfo: Text(_themeSummary),
                trailing: const CupertinoListTileChevron(),
                onTap: () => _open(
                  context,
                  const ThemeSettingsView(),
                ),
              ),
              CupertinoListTile.notched(
                title: const Text('功能 & 设置'),
                additionalInfo: Text(_functionSummary),
                trailing: const CupertinoListTileChevron(),
                onTap: () => _open(
                  context,
                  const FunctionSettingsView(),
                ),
              ),
              CupertinoListTile.notched(
                title: const Text('其它'),
                additionalInfo: Text(_version),
                trailing: const CupertinoListTileChevron(),
                onTap: () => _open(
                  context,
                  const OtherHubView(),
                ),
              ),
            ],
          ),
          CupertinoListSection.insetGrouped(
            header: const Text('诊断'),
            children: [
              CupertinoListTile.notched(
                title: const Text('开发工具'),
                additionalInfo: const Text('异常日志 · 关键节点'),
                trailing: const CupertinoListTileChevron(),
                onTap: () => _open(
                  context,
                  const DeveloperToolsView(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Future<void> _open(BuildContext context, Widget page) async {
    await Navigator.of(context).push(
      CupertinoPageRoute<void>(builder: (_) => page),
    );
    await _refreshStats();
  }
}
