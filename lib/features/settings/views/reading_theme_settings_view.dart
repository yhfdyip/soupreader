import 'dart:async';

import 'package:flutter/cupertino.dart';

import '../../../app/theme/colors.dart';
import '../../../app/theme/design_tokens.dart';
import '../../../app/widgets/app_cupertino_page_scaffold.dart';
import '../../../app/widgets/app_ui_kit.dart';
import '../../../core/services/settings_service.dart';
import '../../reader/models/reading_settings.dart';
import '../../reader/widgets/reader_color_picker_dialog.dart';

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

  ReadStyleConfig get _currentStyleConfig {
    final configs = _settings.readStyleConfigs;
    final index = _settings.themeIndex.clamp(0, 9999);
    if (index < configs.length) return configs[index];
    final theme = AppColors.readingThemes[index.clamp(0, AppColors.readingThemes.length - 1)];
    return ReadStyleConfig(
      name: theme.name,
      bgType: ReadStyleConfig.bgTypeColor,
      bgStr: (theme.background.toARGB32() & 0x00FFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase(),
      bgAlpha: 255,
      textColor: theme.text.toARGB32(),
    );
  }

  Future<void> _pickCustomBgColor() async {
    final current = _currentStyleConfig;
    final currentColor = int.tryParse(current.bgStr, radix: 16) ?? 0xFFFFFF;
    final picked = await showReaderColorPickerDialog(
      context: context,
      title: '自定义背景色',
      initialColor: currentColor,
    );
    if (picked == null || !mounted) return;
    final hex = (picked & 0x00FFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase();
    final configs = List<ReadStyleConfig>.from(_settings.readStyleConfigs);
    final index = _settings.themeIndex.clamp(0, 9999);
    final updated = current.copyWith(bgType: ReadStyleConfig.bgTypeColor, bgStr: hex);
    while (configs.length <= index) configs.add(ReadStyleConfig());
    configs[index] = updated;
    final next = _settings.copyWith(readStyleConfigs: configs);
    setState(() => _settings = next);
    unawaited(_settingsService.saveReadingSettings(next));
  }

  Future<void> _pickCustomTextColor() async {
    final current = _currentStyleConfig;
    final picked = await showReaderColorPickerDialog(
      context: context,
      title: '自定义文字色',
      initialColor: current.textColor,
    );
    if (picked == null || !mounted) return;
    final configs = List<ReadStyleConfig>.from(_settings.readStyleConfigs);
    final index = _settings.themeIndex.clamp(0, 9999);
    final updated = current.copyWith(textColor: picked);
    while (configs.length <= index) configs.add(ReadStyleConfig());
    configs[index] = updated;
    final next = _settings.copyWith(readStyleConfigs: configs);
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
          AppListSection(
            header: _sectionHeader('自定义颜色（当前主题）'),
            children: [
              AppListTile(
                leading: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: Color(
                      0xFF000000 |
                      (int.tryParse(_currentStyleConfig.bgStr, radix: 16) ??
                          0xFFFFFF),
                    ),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: CupertinoColors.separator.resolveFrom(context),
                      width: 0.5,
                    ),
                  ),
                ),
                title: Text(
                  '背景色',
                  style: TextStyle(
                    color: ReaderSettingsTokens.rowTitleColor(isDark: _isDark),
                    fontSize: ReaderSettingsTokens.rowTitleSize,
                  ),
                ),
                additionalInfo: Text(
                  '#${_currentStyleConfig.bgStr.toUpperCase()}',
                  style: TextStyle(
                    color: ReaderSettingsTokens.rowMetaColor(isDark: _isDark),
                    fontSize: ReaderSettingsTokens.rowMetaSize,
                  ),
                ),
                onTap: _pickCustomBgColor,
              ),
              AppListTile(
                leading: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: Color(
                      0xFF000000 | (_currentStyleConfig.textColor & 0x00FFFFFF),
                    ),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: CupertinoColors.separator.resolveFrom(context),
                      width: 0.5,
                    ),
                  ),
                ),
                title: Text(
                  '文字色',
                  style: TextStyle(
                    color: ReaderSettingsTokens.rowTitleColor(isDark: _isDark),
                    fontSize: ReaderSettingsTokens.rowTitleSize,
                  ),
                ),
                additionalInfo: Text(
                  '#${(_currentStyleConfig.textColor & 0x00FFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}',
                  style: TextStyle(
                    color: ReaderSettingsTokens.rowMetaColor(isDark: _isDark),
                    fontSize: ReaderSettingsTokens.rowMetaSize,
                  ),
                ),
                onTap: _pickCustomTextColor,
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
