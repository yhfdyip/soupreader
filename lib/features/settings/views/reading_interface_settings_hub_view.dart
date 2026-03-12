import 'dart:async';

import 'package:flutter/cupertino.dart';

import '../../../app/theme/design_tokens.dart';
import '../../../app/widgets/app_cupertino_page_scaffold.dart';
import '../../../app/widgets/app_ui_kit.dart';
import '../../../core/services/settings_service.dart';
import '../../reader/models/reading_settings.dart';
import '../../reader/widgets/typography_settings_dialog.dart';
import 'reading_preferences_view.dart';
import 'reading_tip_settings_view.dart';

class ReadingInterfaceSettingsHubView extends StatefulWidget {
  const ReadingInterfaceSettingsHubView({super.key});

  @override
  State<ReadingInterfaceSettingsHubView> createState() =>
      _ReadingInterfaceSettingsHubViewState();
}

class _ReadingInterfaceSettingsHubViewState
    extends State<ReadingInterfaceSettingsHubView> {
  final SettingsService _settingsService = SettingsService();

  ReadingSettings get _settings => _settingsService.readingSettings;

  bool get _isDark => CupertinoTheme.of(context).brightness == Brightness.dark;

  Text _sectionHeader(String title) {
    return Text(
      title,
      style: TextStyle(
        color: ReaderSettingsTokens.titleColor(isDark: _isDark),
        fontSize: ReaderSettingsTokens.sectionTitleSize,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  Future<void> _openPreferences() async {
    await Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (context) => const ReadingPreferencesView(),
      ),
    );
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _openTipSettings() async {
    await Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (context) => const ReadingTipSettingsView(),
      ),
    );
    if (!mounted) return;
    setState(() {});
  }

  void _openTypographyDialog() {
    showTypographySettingsDialog(
      context,
      settings: _settings,
      onSettingsChanged: (newSettings) {
        unawaited(_settingsService.saveReadingSettings(newSettings));
        if (!mounted) return;
        setState(() {});
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppCupertinoPageScaffold(
      title: '阅读界面样式',
      child: AppListView(
        children: [
          AppListSection(
            header: _sectionHeader('阅读样式与排版'),
            children: [
              _buildItem(
                leading: CupertinoIcons.textformat,
                title: '样式与排版',
                onTap: _openPreferences,
              ),
              _buildItem(
                leading: CupertinoIcons.doc_text,
                title: '页眉页脚与标题',
                onTap: _openTipSettings,
              ),
            ],
          ),
          AppListSection(
            header: _sectionHeader('排版细项'),
            children: [
              _buildItem(
                leading: CupertinoIcons.slider_horizontal_3,
                title: '排版与边距（高级）',
                onTap: _openTypographyDialog,
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildItem({
    required IconData leading,
    required String title,
    required VoidCallback onTap,
  }) {
    return AppListTile(
      leading: Icon(
        leading,
        size: 20,
        color: ReaderSettingsTokens.rowMetaColor(isDark: _isDark),
      ),
      title: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: ReaderSettingsTokens.rowTitleColor(isDark: _isDark),
          fontSize: ReaderSettingsTokens.rowTitleSize,
        ),
      ),
      onTap: onTap,
    );
  }
}
