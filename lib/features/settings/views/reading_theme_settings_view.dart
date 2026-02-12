import 'dart:async';

import 'package:flutter/cupertino.dart';

import '../../../app/theme/colors.dart';
import '../../../app/theme/design_tokens.dart';
import '../../../app/widgets/app_cupertino_page_scaffold.dart';
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

  Color _accent(BuildContext context) {
    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;
    return isDark
        ? AppDesignTokens.brandSecondary
        : AppDesignTokens.brandPrimary;
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
      child: ListView(
        padding: const EdgeInsets.only(top: 8, bottom: 20),
        children: [
          CupertinoListSection.insetGrouped(
            header: const Text('选择主题'),
            children: AppColors.readingThemes.asMap().entries.map((entry) {
              final index = entry.key;
              final theme = entry.value;
              final selected = index == _settings.themeIndex;
              return CupertinoListTile.notched(
                title: Text(theme.name),
                trailing: selected
                    ? Icon(
                        CupertinoIcons.checkmark,
                        color: _accent(context),
                        size: 18,
                      )
                    : null,
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
