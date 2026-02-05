import 'dart:async';

import 'package:flutter/cupertino.dart';

import '../../../core/services/settings_service.dart';
import '../../reader/models/reading_settings.dart';
import '../../reader/widgets/typography_settings_dialog.dart';
import 'reading_page_settings_view.dart';
import 'reading_status_action_settings_view.dart';
import 'reading_other_settings_view.dart';
import 'reading_preferences_view.dart';

class GlobalReadingSettingsView extends StatefulWidget {
  const GlobalReadingSettingsView({super.key});

  @override
  State<GlobalReadingSettingsView> createState() =>
      _GlobalReadingSettingsViewState();
}

class _GlobalReadingSettingsViewState extends State<GlobalReadingSettingsView> {
  final SettingsService _settingsService = SettingsService();
  late ReadingSettings _settings;

  @override
  void initState() {
    super.initState();
    _settings = _settingsService.readingSettings;
  }

  Future<void> _refresh() async {
    if (!mounted) return;
    setState(() => _settings = _settingsService.readingSettings);
  }

  Future<void> _openCommon() async {
    await Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (context) => const ReadingPreferencesView(),
      ),
    );
    await _refresh();
  }

  void _openTypographyDialog() {
    showTypographySettingsDialog(
      context,
      settings: _settings,
      onSettingsChanged: (newSettings) {
        setState(() => _settings = newSettings);
        unawaited(_settingsService.saveReadingSettings(newSettings));
      },
    );
  }

  Future<void> _openPageSettings() async {
    await Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (context) => const ReadingPageSettingsView(),
      ),
    );
    await _refresh();
  }

  Future<void> _openStatusAndActions() async {
    await Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (context) => const ReadingStatusActionSettingsView(),
      ),
    );
    await _refresh();
  }

  Future<void> _openOther() async {
    await Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (context) => const ReadingOtherSettingsView(),
      ),
    );
    await _refresh();
  }

  Future<void> _resetDefaults() async {
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('恢复默认？'),
        content: const Text('\n将把“全局默认阅读设置”恢复为初始值。'),
        actions: [
          CupertinoDialogAction(
            child: const Text('取消'),
            onPressed: () => Navigator.pop(context, false),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: const Text('恢复'),
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await _settingsService.saveReadingSettings(const ReadingSettings());
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('阅读（全局默认）'),
      ),
      child: SafeArea(
        child: ListView(
          children: [
            CupertinoListSection.insetGrouped(
              header: const Text('常用'),
              children: [
                CupertinoListTile.notched(
                  title: const Text('常用与亮度'),
                  additionalInfo: const Text('主题 / 字号 / 翻页 / 亮度'),
                  trailing: const CupertinoListTileChevron(),
                  onTap: _openCommon,
                ),
              ],
            ),
            CupertinoListSection.insetGrouped(
              header: const Text('细项'),
              children: [
                CupertinoListTile.notched(
                  title: const Text('排版与边距'),
                  additionalInfo: const Text('字距 / 段距 / 边距 / 标题'),
                  trailing: const CupertinoListTileChevron(),
                  onTap: _openTypographyDialog,
                ),
                CupertinoListTile.notched(
                  title: const Text('翻页与按键'),
                  additionalInfo: const Text('动画 / 灵敏度 / 音量键'),
                  trailing: const CupertinoListTileChevron(),
                  onTap: _openPageSettings,
                ),
                CupertinoListTile.notched(
                  title: const Text('状态栏与操作'),
                  additionalInfo: const Text('页眉页脚 / 点击区域'),
                  trailing: const CupertinoListTileChevron(),
                  onTap: _openStatusAndActions,
                ),
                CupertinoListTile.notched(
                  title: const Text('其他'),
                  additionalInfo: const Text('常亮 / 繁简 / 净化'),
                  trailing: const CupertinoListTileChevron(),
                  onTap: _openOther,
                ),
              ],
            ),
            CupertinoListSection.insetGrouped(
              header: const Text('高级'),
              children: [
                CupertinoListTile.notched(
                  title: const Text('恢复默认阅读设置'),
                  trailing: const CupertinoListTileChevron(),
                  onTap: _resetDefaults,
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

