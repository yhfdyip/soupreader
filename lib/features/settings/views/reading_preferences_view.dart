import 'dart:async';

import 'package:flutter/cupertino.dart';

import '../../../app/widgets/app_toast.dart';
import '../../../app/widgets/cupertino_bottom_dialog.dart';

import '../../../app/theme/colors.dart';
import '../../../app/theme/design_tokens.dart';
import '../../../app/theme/typography.dart';
import '../../../app/widgets/app_cupertino_page_scaffold.dart';
import '../../../app/widgets/app_ui_kit.dart';
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

  Text _tileTitle(String text) {
    return Text(
      text,
      style: TextStyle(
        color: ReaderSettingsTokens.rowTitleColor(isDark: _isDark),
        fontSize: ReaderSettingsTokens.rowTitleSize,
      ),
    );
  }

  Text _tileMeta(String text) {
    return Text(
      text,
      style: TextStyle(
        color: ReaderSettingsTokens.rowMetaColor(isDark: _isDark),
        fontSize: ReaderSettingsTokens.rowMetaSize,
      ),
    );
  }

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
      accentColor: _accent,
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
      accentColor: _accent,
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
      unawaited(showAppToast(context, message: '仿真2模式已隐藏'));
      return;
    }
    _update(_settings.copyWith(pageTurnMode: selected));
  }

  Future<void> _pickFontFamily() async {
    final selected = await showOptionPickerSheet<int>(
      context: context,
      title: '选择字体',
      currentValue: _settings.fontFamilyIndex,
      accentColor: _accent,
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
      accentColor: _accent,
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
    showCupertinoBottomSheetDialog<void>(
      context: context,
      builder: (ctx) => TypographySettingsDialog(
        settings: _settings,
        onSettingsChanged: _update,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppCupertinoPageScaffold(
      title: '样式与排版',
      child: AppListView(
        children: [
          AppListSection(
            header: _sectionHeader('样式'),
            hasLeading: false,
            children: [
              AppListTile(
                title: _tileTitle('主题'),
                additionalInfo: _tileMeta(_themeLabel),
                onTap: _pickTheme,
              ),
              AppListTile(
                title: _tileTitle('字体'),
                additionalInfo: _tileMeta(_fontLabel),
                onTap: _pickFontFamily,
              ),
              AppListTile(
                title: _tileTitle('字重'),
                additionalInfo: _tileMeta(_fontWeightLabel),
                onTap: _pickFontWeight,
              ),
              AppListTile(
                title: _tileTitle('翻页模式'),
                additionalInfo: _tileMeta(_settings.pageTurnMode.name),
                onTap: _pickPageTurnMode,
              ),
            ],
          ),
          AppListSection(
            header: _sectionHeader('排版'),
            hasLeading: false,
            children: [
              _SliderTile(
                title: '字号',
                value: _settings.fontSize,
                min: 8,
                max: 50,
                display: _settings.fontSize.toInt().toString(),
                activeColor: _accent,
                onChanged: (v) => _update(_settings.copyWith(fontSize: v)),
              ),
              _SliderTile(
                title: '字距',
                value: _settings.letterSpacing,
                min: -2,
                max: 5,
                display: _settings.letterSpacing.toStringAsFixed(1),
                activeColor: _accent,
                onChanged: (v) => _update(_settings.copyWith(letterSpacing: v)),
              ),
              _SliderTile(
                title: '行距',
                value: _settings.lineHeight,
                min: 1.0,
                max: 3.0,
                display: _settings.lineHeight.toStringAsFixed(1),
                activeColor: _accent,
                onChanged: (v) => _update(_settings.copyWith(lineHeight: v)),
              ),
              _SliderTile(
                title: '段距',
                value: _settings.paragraphSpacing,
                min: 0,
                max: 50,
                display: _settings.paragraphSpacing.toInt().toString(),
                activeColor: _accent,
                onChanged: (v) =>
                    _update(_settings.copyWith(paragraphSpacing: v)),
              ),
              AppListTile(
                title: _tileTitle('共享排版布局'),
                subtitle: _tileMeta('横竖屏共用同一排版参数'),
                trailing: CupertinoSwitch(
                  value: _settings.shareLayout,
                  activeTrackColor: _accent,
                  onChanged: (value) =>
                      _update(_settings.copyWith(shareLayout: value)),
                ),
              ),
              AppListTile(
                title: _tileTitle('两端对齐'),
                trailing: CupertinoSwitch(
                  value: _settings.textFullJustify,
                  activeTrackColor: _accent,
                  onChanged: (value) =>
                      _update(_settings.copyWith(textFullJustify: value)),
                ),
              ),
              AppListTile(
                title: _tileTitle('底部对齐'),
                trailing: CupertinoSwitch(
                  value: _settings.textBottomJustify,
                  activeTrackColor: _accent,
                  onChanged: (value) =>
                      _update(_settings.copyWith(textBottomJustify: value)),
                ),
              ),
              AppListTile(
                title: _tileTitle('段首缩进'),
                trailing: CupertinoSwitch(
                  value: _settings.paragraphIndent.isNotEmpty,
                  activeTrackColor: _accent,
                  onChanged: (value) => _update(
                    _settings.copyWith(paragraphIndent: value ? '　　' : ''),
                  ),
                ),
              ),
            ],
          ),
          AppListSection(
            header: _sectionHeader('高级'),
            hasLeading: false,
            children: [
              AppListTile(
                title: _tileTitle('排版与边距（高级）'),
                additionalInfo: _tileMeta('更多选项'),
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
  final Color activeColor;
  final ValueChanged<double> onChanged;

  const _SliderTile({
    required this.title,
    required this.value,
    required this.min,
    required this.max,
    required this.display,
    required this.activeColor,
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
    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;
    final safeMin = _safeMin();
    final safeMax = _safeMax();
    final safeValue = _safeSliderValue();
    final canSlide = min.isFinite && max.isFinite && max > min;

    return CupertinoListTile(
      title: Text(
        title,
        style: TextStyle(
          color: ReaderSettingsTokens.rowTitleColor(isDark: isDark),
          fontSize: ReaderSettingsTokens.rowTitleSize,
        ),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 10),
        child: CupertinoSlider(
          value: safeValue,
          min: safeMin,
          max: safeMax,
          activeColor: activeColor,
          onChanged: canSlide ? onChanged : null,
        ),
      ),
      additionalInfo: Text(
        display,
        style: TextStyle(
          color: ReaderSettingsTokens.rowMetaColor(isDark: isDark),
          fontSize: ReaderSettingsTokens.rowMetaSize,
        ),
      ),
    );
  }
}
