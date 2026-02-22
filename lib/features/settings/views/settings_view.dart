import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../app/theme/colors.dart';
import '../../../app/widgets/app_cupertino_page_scaffold.dart';
import '../../../core/database/database_service.dart';
import '../../../core/database/repositories/book_repository.dart';
import '../../../core/database/repositories/source_repository.dart';
import '../../../core/models/app_settings.dart';
import '../../../core/services/settings_service.dart';
import '../../../core/utils/format_utils.dart';
import '../../bookshelf/views/reading_history_view.dart';
import '../../reader/models/reading_settings.dart';
import '../../reader/views/speak_engine_manage_view.dart';
import '../../rss/views/rss_source_manage_view.dart';
import '../../source/views/source_list_view.dart';
import 'about_settings_view.dart';
import 'appearance_settings_view.dart';
import 'backup_settings_view.dart';
import 'developer_tools_view.dart';
import 'other_settings_view.dart';
import 'app_help_dialog.dart';
import 'reading_behavior_settings_hub_view.dart';
import 'reading_interface_settings_hub_view.dart';
import 'reading_theme_settings_view.dart';
import 'settings_placeholders.dart';
import 'settings_ui_tokens.dart';
import 'text_rules_settings_view.dart';

/// 设置首页（扁平化分组）
class SettingsView extends StatefulWidget {
  const SettingsView({super.key});

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  final SettingsService _settingsService = SettingsService();
  late ReadingSettings _readingSettings;
  bool _loadingMyHelp = false;

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
    return themeName;
  }

  String get _sourceSummary {
    final count = _sourceCount;
    final auto =
        _settingsService.appSettings.autoUpdateSources ? '自动更新开' : '自动更新关';
    if (count == null) return auto;
    return '$count 个书源 · $auto';
  }

  String get _functionSummary {
    final history =
        _readingHistoryCount == null ? '—' : '$_readingHistoryCount 本';
    final cache = FormatUtils.formatBytes(_cacheInfo.bytes);
    return '阅读记录 $history · 缓存 $cache';
  }

  Widget _plannedInfo() {
    return const Text(
      SettingsUiTokens.plannedLabel,
      style: TextStyle(color: CupertinoColors.secondaryLabel),
    );
  }

  Future<void> _openMyHelp() async {
    if (_loadingMyHelp) return;
    setState(() => _loadingMyHelp = true);
    try {
      final markdownText =
          await rootBundle.loadString('assets/web/help/md/appHelp.md');
      if (!mounted) return;
      await showAppHelpDialog(
        context,
        markdownText: markdownText,
      );
    } catch (error) {
      if (!mounted) return;
      await showCupertinoDialog<void>(
        context: context,
        builder: (dialogContext) => CupertinoAlertDialog(
          title: const Text('帮助'),
          content: Text('帮助文档加载失败：$error'),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('关闭'),
            ),
          ],
        ),
      );
    } finally {
      if (!mounted) return;
      setState(() => _loadingMyHelp = false);
    }
  }

  Widget _buildHelpAction() {
    if (_loadingMyHelp) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 8),
        child: CupertinoActivityIndicator(radius: 9),
      );
    }
    return CupertinoButton(
      padding: EdgeInsets.zero,
      minSize: 30,
      onPressed: _openMyHelp,
      child: const Icon(CupertinoIcons.question_circle, size: 22),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppCupertinoPageScaffold(
      title: '设置',
      trailing: _buildHelpAction(),
      child: ListView(
        padding: const EdgeInsets.only(top: 8, bottom: 20),
        children: [
          CupertinoListSection.insetGrouped(
            header: const Text('源管理'),
            children: [
              CupertinoListTile.notched(
                title: const Text('书源管理'),
                additionalInfo: Text(_sourceSummary),
                trailing: const CupertinoListTileChevron(),
                onTap: () => _open(
                  context,
                  const SourceListView(),
                ),
              ),
              CupertinoListTile.notched(
                title: const Text('替换净化'),
                additionalInfo: const Text('净化/繁简'),
                trailing: const CupertinoListTileChevron(),
                onTap: () => _open(
                  context,
                  const TextRulesSettingsView(),
                ),
              ),
              CupertinoListTile.notched(
                title: const Text('目录规则'),
                additionalInfo: const Text('书源编辑'),
                trailing: const CupertinoListTileChevron(),
                onTap: () => _open(
                  context,
                  const SourceListView(),
                ),
              ),
              CupertinoListTile.notched(
                title: const Text('订阅管理'),
                additionalInfo: const Text('搜索/分组/启停'),
                trailing: const CupertinoListTileChevron(),
                onTap: () => _open(
                  context,
                  const RssSourceManageView(),
                ),
              ),
              CupertinoListTile.notched(
                title: const Text('语音管理'),
                additionalInfo: const Text('系统/HTTP 引擎'),
                trailing: const CupertinoListTileChevron(),
                onTap: () => _open(
                  context,
                  const SpeakEngineManageView(),
                ),
              ),
              CupertinoListTile.notched(
                title: const Text('广告屏蔽'),
                additionalInfo: _plannedInfo(),
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
                title: const Text('应用外观'),
                additionalInfo: Text(_appearanceSummary),
                trailing: const CupertinoListTileChevron(),
                onTap: () => _open(
                  context,
                  const AppearanceSettingsView(),
                ),
              ),
              CupertinoListTile.notched(
                title: const Text('阅读主题'),
                additionalInfo: Text(_themeSummary),
                trailing: const CupertinoListTileChevron(),
                onTap: () => _open(
                  context,
                  const ReadingThemeSettingsView(),
                ),
              ),
              CupertinoListTile.notched(
                title: const Text('白天/黑夜主题'),
                additionalInfo: _plannedInfo(),
                trailing: const CupertinoListTileChevron(),
                onTap: () => SettingsPlaceholders.showNotImplemented(
                  context,
                  title: '白天/黑夜主题（自动切换两套阅读主题）暂未实现',
                ),
              ),
              CupertinoListTile.notched(
                title: const Text('动态颜色/色差'),
                additionalInfo: _plannedInfo(),
                trailing: const CupertinoListTileChevron(),
                onTap: () => SettingsPlaceholders.showNotImplemented(
                  context,
                  title: '动态颜色/色差暂未实现',
                ),
              ),
            ],
          ),
          CupertinoListSection.insetGrouped(
            header: const Text('功能 & 设置'),
            children: [
              CupertinoListTile.notched(
                title: const Text('备份/同步'),
                additionalInfo: const Text('导入/导出'),
                trailing: const CupertinoListTileChevron(),
                onTap: () => _open(
                  context,
                  const BackupSettingsView(),
                ),
              ),
              CupertinoListTile.notched(
                title: const Text('阅读设置（界面）'),
                additionalInfo: const Text('主题 / 字体 / 排版'),
                trailing: const CupertinoListTileChevron(),
                onTap: () => _open(
                  context,
                  const ReadingInterfaceSettingsHubView(),
                ),
              ),
              CupertinoListTile.notched(
                title: const Text('阅读设置（行为）'),
                additionalInfo: const Text('翻页 / 点击 / 状态栏'),
                trailing: const CupertinoListTileChevron(),
                onTap: () => _open(
                  context,
                  const ReadingBehaviorSettingsHubView(),
                ),
              ),
              CupertinoListTile.notched(
                title: const Text('阅读记录'),
                additionalInfo: Text(_functionSummary),
                trailing: const CupertinoListTileChevron(),
                onTap: () => _open(
                  context,
                  const ReadingHistoryView(),
                ),
              ),
              CupertinoListTile.notched(
                title: const Text('其它设置'),
                additionalInfo: const Text('详细配置'),
                trailing: const CupertinoListTileChevron(),
                onTap: () => _open(
                  context,
                  const OtherSettingsView(),
                ),
              ),
              CupertinoListTile.notched(
                title: const Text('隔空阅读'),
                additionalInfo: _plannedInfo(),
                trailing: const CupertinoListTileChevron(),
                onTap: () => SettingsPlaceholders.showNotImplemented(
                  context,
                  title: '隔空阅读（接力/Handoff）暂未实现',
                ),
              ),
            ],
          ),
          CupertinoListSection.insetGrouped(
            header: const Text('其它'),
            children: [
              CupertinoListTile.notched(
                title: const Text('分享'),
                additionalInfo: _plannedInfo(),
                trailing: const CupertinoListTileChevron(),
                onTap: () => SettingsPlaceholders.showNotImplemented(
                  context,
                  title: '分享暂未实现（可考虑接入 share_plus）',
                ),
              ),
              CupertinoListTile.notched(
                title: const Text('好评支持'),
                additionalInfo: _plannedInfo(),
                trailing: const CupertinoListTileChevron(),
                onTap: () => SettingsPlaceholders.showNotImplemented(
                  context,
                  title: '好评支持暂未实现',
                ),
              ),
              CupertinoListTile.notched(
                title: const Text('关于我们'),
                additionalInfo: Text(_version),
                trailing: const CupertinoListTileChevron(),
                onTap: () => _open(
                  context,
                  const AboutSettingsView(),
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
