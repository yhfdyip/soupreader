import 'dart:async';

import 'package:flutter/cupertino.dart';

import '../../../app/theme/colors.dart';
import '../../../app/theme/design_tokens.dart';
import '../../../app/widgets/app_cupertino_page_scaffold.dart';
import '../../../app/widgets/app_ui_kit.dart';
import '../../../core/services/settings_service.dart';
import '../../reader/models/reading_settings.dart';

class ReadingThemeSettingsView extends StatefulWidget {
  const ReadingThemeSettingsView({super.key});

  @override
  State<ReadingThemeSettingsView> createState() =>
      _ReadingThemeSettingsViewState();
}

class _ReadingThemeSettingsViewState extends State<ReadingThemeSettingsView> {
  final SettingsService _settingsService = SettingsService();
  late ReadingSettings _settings;

  bool get _isDark => CupertinoTheme.of(context).brightness == Brightness.dark;

  Color get _accent => ReaderSettingsTokens.accent(isDark: _isDark);

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

  @override
  void initState() {
    super.initState();
    _settings = _settingsService.readingSettings;
  }

  void _updateThemeIndex(int index) {
    final next = _settings.copyWith(themeIndex: index);
    setState(() => _settings = next);
    unawaited(_settingsService.saveReadingSettings(next));
  }

  @override
  Widget build(BuildContext context) {
    return AppCupertinoPageScaffold(
      title: '阅读主题',
      child: AppListView(
        padding: const EdgeInsets.only(top: 8, bottom: 24),
        children: [
          AppListSection(
            header: _sectionHeader('选择主题'),
            children: AppColors.readingThemes.asMap().entries.map((entry) {
              final index = entry.key;
              final theme = entry.value;
              final selected = index == _settings.themeIndex;
              return AppListTile(
                leading: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: theme.background,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: theme.text.withValues(alpha: 0.45),
                      width: 0.5,
                    ),
                  ),
                ),
                title: Text(
                  theme.name,
                  style: TextStyle(
                    color: ReaderSettingsTokens.rowTitleColor(isDark: _isDark),
                    fontSize: ReaderSettingsTokens.rowTitleSize,
                  ),
                ),
                subtitle: Text(
                  '背景 ${theme.background.toARGB32().toRadixString(16).padLeft(8, '0')}',
                  style: TextStyle(
                    color: ReaderSettingsTokens.rowMetaColor(isDark: _isDark),
                    fontSize: ReaderSettingsTokens.rowMetaSize,
                  ),
                ),
                trailing: selected
                    ? Icon(
                        CupertinoIcons.checkmark,
                        color: _accent,
                        size: 18,
                      )
                    : null,
                showChevron: false,
                onTap: () => _updateThemeIndex(index),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
