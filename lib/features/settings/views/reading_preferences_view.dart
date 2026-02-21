import 'dart:async';

import 'package:flutter/cupertino.dart';

import '../../../app/theme/colors.dart';
import '../../../app/theme/design_tokens.dart';
import '../../../app/theme/typography.dart';
import '../../../app/widgets/app_cupertino_page_scaffold.dart';
import '../../../app/widgets/option_picker_sheet.dart';
import '../../../core/services/settings_service.dart';
import '../../reader/models/reading_settings.dart';
import '../../reader/widgets/typography_settings_dialog.dart';

class ReadingPreferencesView extends StatefulWidget {
  const ReadingPreferencesView({super.key});

  @override
  State<ReadingPreferencesView> createState() => _ReadingPreferencesViewState();
}

class _ReadingPreferencesViewState extends State<ReadingPreferencesView> {
  final SettingsService _settingsService = SettingsService();
  late ReadingSettings _settings;

  @override
  void initState() {
    super.initState();
    _settings = _settingsService.readingSettings.sanitize();
  }

  void _update(ReadingSettings newSettings) {
    final safeSettings = newSettings.sanitize();
    setState(() => _settings = safeSettings);
    unawaited(_settingsService.saveReadingSettings(safeSettings));
  }

  String get _themeLabel {
    final index = _settings.themeIndex;
    if (index >= 0 && index < AppColors.readingThemes.length) {
      return AppColors.readingThemes[index].name;
    }
    return AppColors.readingThemes.first.name;
  }

  String get _fontLabel {
    return ReadingFontFamily.getFontName(_settings.fontFamilyIndex);
  }

  String get _fontWeightLabel {
    switch (_settings.textBold) {
      case 1:
        return '粗体';
      case 2:
        return '细体';
      case 0:
      default:
        return '正常';
    }
  }

  Future<void> _pickTheme() async {
    final selected = await showOptionPickerSheet<int>(
      context: context,
      title: '选择阅读主题',
      currentValue: _settings.themeIndex,
      accentColor: AppDesignTokens.brandPrimary,
      items: AppColors.readingThemes.asMap().entries.map((entry) {
        final index = entry.key;
        final theme = entry.value;
        return OptionPickerItem<int>(
          value: index,
          label: theme.name,
        );
      }).toList(growable: false),
    );
    if (selected == null) return;
    _update(_settings.copyWith(themeIndex: selected));
  }

  Future<void> _pickPageTurnMode() async {
    final selected = await showOptionPickerSheet<PageTurnMode>(
      context: context,
      title: '选择翻页模式',
      currentValue: _settings.pageTurnMode,
      accentColor: AppDesignTokens.brandPrimary,
      items: PageTurnModeUi.values(current: _settings.pageTurnMode).map((mode) {
        return OptionPickerItem<PageTurnMode>(
          value: mode,
          label: PageTurnModeUi.isHidden(mode) ? '${mode.name}（隐藏）' : mode.name,
          subtitle: PageTurnModeUi.isHidden(mode) ? '当前版本隐藏' : null,
        );
      }).toList(growable: false),
    );
    if (selected == null) return;
    if (PageTurnModeUi.isHidden(selected)) {
      _showMessage('仿真2模式已隐藏');
      return;
    }
    _update(_settings.copyWith(pageTurnMode: selected));
  }

  Future<void> _pickFontFamily() async {
    final selected = await showOptionPickerSheet<int>(
      context: context,
      title: '选择字体',
      currentValue: _settings.fontFamilyIndex,
      accentColor: AppDesignTokens.brandPrimary,
      items: ReadingFontFamily.presets.asMap().entries.map((entry) {
        final index = entry.key;
        final preset = entry.value;
        return OptionPickerItem<int>(
          value: index,
          label: preset.name,
        );
      }).toList(growable: false),
    );
    if (selected == null) return;
    _update(_settings.copyWith(fontFamilyIndex: selected));
  }

  Future<void> _pickFontWeight() async {
    const options = <(int, String)>[
      (0, '正常'),
      (1, '粗体'),
      (2, '细体'),
    ];

    final selected = await showOptionPickerSheet<int>(
      context: context,
      title: '选择字重',
      currentValue: _settings.textBold,
      accentColor: AppDesignTokens.brandPrimary,
      items: options
          .map(
            (option) => OptionPickerItem<int>(
              value: option.$1,
              label: option.$2,
            ),
          )
          .toList(growable: false),
    );
    if (selected == null) return;
    _update(_settings.copyWith(textBold: selected));
  }

  void _openAdvancedTypography() {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => TypographySettingsDialog(
        settings: _settings,
        onSettingsChanged: _update,
      ),
    );
  }

  void _showMessage(String message) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('提示'),
        content: Text('\n$message'),
        actions: [
          CupertinoDialogAction(
            child: const Text('好'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppCupertinoPageScaffold(
      title: '样式与排版',
      child: ListView(
        padding: const EdgeInsets.only(top: 8, bottom: 20),
        children: [
          CupertinoListSection.insetGrouped(
            header: const Text('样式'),
            children: [
              CupertinoListTile.notched(
                title: const Text('主题'),
                additionalInfo: Text(_themeLabel),
                trailing: const CupertinoListTileChevron(),
                onTap: _pickTheme,
              ),
              CupertinoListTile.notched(
                title: const Text('字体'),
                additionalInfo: Text(_fontLabel),
                trailing: const CupertinoListTileChevron(),
                onTap: _pickFontFamily,
              ),
              CupertinoListTile.notched(
                title: const Text('字重'),
                additionalInfo: Text(_fontWeightLabel),
                trailing: const CupertinoListTileChevron(),
                onTap: _pickFontWeight,
              ),
              CupertinoListTile.notched(
                title: const Text('翻页模式'),
                additionalInfo: Text(_settings.pageTurnMode.name),
                trailing: const CupertinoListTileChevron(),
                onTap: _pickPageTurnMode,
              ),
            ],
          ),
          CupertinoListSection.insetGrouped(
            header: const Text('排版'),
            children: [
              _SliderTile(
                title: '字号',
                value: _settings.fontSize,
                min: 10,
                max: 40,
                display: _settings.fontSize.toInt().toString(),
                onChanged: (v) => _update(_settings.copyWith(fontSize: v)),
              ),
              _SliderTile(
                title: '字距',
                value: _settings.letterSpacing,
                min: -2,
                max: 5,
                display: _settings.letterSpacing.toStringAsFixed(1),
                onChanged: (v) => _update(_settings.copyWith(letterSpacing: v)),
              ),
              _SliderTile(
                title: '行距',
                value: _settings.lineHeight,
                min: 1.0,
                max: 3.0,
                display: _settings.lineHeight.toStringAsFixed(1),
                onChanged: (v) => _update(_settings.copyWith(lineHeight: v)),
              ),
              _SliderTile(
                title: '段距',
                value: _settings.paragraphSpacing,
                min: 0,
                max: 50,
                display: _settings.paragraphSpacing.toInt().toString(),
                onChanged: (v) =>
                    _update(_settings.copyWith(paragraphSpacing: v)),
              ),
              CupertinoListTile.notched(
                title: const Text('两端对齐'),
                trailing: CupertinoSwitch(
                  value: _settings.textFullJustify,
                  onChanged: (value) =>
                      _update(_settings.copyWith(textFullJustify: value)),
                ),
              ),
              CupertinoListTile.notched(
                title: const Text('段首缩进'),
                trailing: CupertinoSwitch(
                  value: _settings.paragraphIndent.isNotEmpty,
                  onChanged: (value) => _update(
                    _settings.copyWith(paragraphIndent: value ? '　　' : ''),
                  ),
                ),
              ),
            ],
          ),
          CupertinoListSection.insetGrouped(
            header: const Text('高级'),
            children: [
              CupertinoListTile.notched(
                title: const Text('排版与边距（高级）'),
                additionalInfo: const Text('更多选项'),
                trailing: const CupertinoListTileChevron(),
                onTap: _openAdvancedTypography,
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _SliderTile extends StatelessWidget {
  final String title;
  final double value;
  final double min;
  final double max;
  final String display;
  final ValueChanged<double> onChanged;

  const _SliderTile({
    required this.title,
    required this.value,
    required this.min,
    required this.max,
    required this.display,
    required this.onChanged,
  });

  double _safeSliderValue() {
    final safeMin = min.isFinite ? min : 0.0;
    final safeMax = max.isFinite && max > safeMin ? max : safeMin + 1.0;
    final safeRaw = value.isFinite ? value : safeMin;
    return safeRaw.clamp(safeMin, safeMax).toDouble();
  }

  double _safeMin() => min.isFinite ? min : 0.0;

  double _safeMax() {
    final safeMin = _safeMin();
    return max.isFinite && max > safeMin ? max : safeMin + 1.0;
  }

  @override
  Widget build(BuildContext context) {
    final safeMin = _safeMin();
    final safeMax = _safeMax();
    final safeValue = _safeSliderValue();
    final canSlide = min.isFinite && max.isFinite && max > min;

    return CupertinoListTile(
      title: Text(title),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 10),
        child: CupertinoSlider(
          value: safeValue,
          min: safeMin,
          max: safeMax,
          onChanged: canSlide ? onChanged : null,
        ),
      ),
      additionalInfo: Text(display),
    );
  }
}
