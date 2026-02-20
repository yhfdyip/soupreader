import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../app/widgets/app_cupertino_page_scaffold.dart';
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
    final theme = ShadTheme.of(context);
    final scheme = theme.colorScheme;

    return AppCupertinoPageScaffold(
      title: '界面（样式）',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        children: [
          Text(
            '阅读视觉与排版',
            style: theme.textTheme.small.copyWith(
              color: scheme.mutedForeground,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          ShadCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _buildItem(
                  title: '样式与排版',
                  info: '主题 / 字体 / 排版',
                  onTap: _openPreferences,
                ),
                const ShadSeparator.horizontal(
                  margin: EdgeInsets.symmetric(horizontal: 12),
                ),
                _buildItem(
                  title: '页眉页脚与标题',
                  info: '标题间距 / 内容位 / 分割线',
                  onTap: _openTipSettings,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(
            '高级',
            style: theme.textTheme.small.copyWith(
              color: scheme.mutedForeground,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          ShadCard(
            padding: EdgeInsets.zero,
            child: _buildItem(
              title: '排版与边距（高级）',
              info: '标题/正文/边距滑杆',
              onTap: _openTypographyDialog,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItem({
    required String title,
    required String info,
    required VoidCallback onTap,
  }) {
    final theme = ShadTheme.of(context);
    final scheme = theme.colorScheme;
    final infoText = info.trim();

    return SizedBox(
      width: double.infinity,
      child: CupertinoButton(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        alignment: Alignment.centerLeft,
        onPressed: onTap,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.p.copyWith(
                      color: scheme.foreground,
                    ),
                  ),
                  if (infoText.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      infoText,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.small.copyWith(
                        color: scheme.mutedForeground,
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
      ),
    );
  }
}
