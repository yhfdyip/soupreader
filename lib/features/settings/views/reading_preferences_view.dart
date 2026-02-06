import 'dart:async';

import 'package:flutter/cupertino.dart';
import '../../../app/theme/colors.dart';
import '../../../core/services/settings_service.dart';
import '../../reader/models/reading_settings.dart';
import '../../reader/widgets/typography_settings_dialog.dart';

/// 阅读偏好（全局默认）
///
/// 目标：把“高频项”集中到一个页面，避免用户在多个弹窗/多级菜单里来回找。
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
    _settings = _settingsService.readingSettings;
  }

  void _update(ReadingSettings newSettings) {
    setState(() => _settings = newSettings);
    unawaited(_settingsService.saveReadingSettings(newSettings));
  }

  String get _themeLabel {
    final index = _settings.themeIndex;
    if (index >= 0 && index < AppColors.readingThemes.length) {
      return AppColors.readingThemes[index].name;
    }
    return AppColors.readingThemes.first.name;
  }

  Future<void> _pickTheme() async {
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: const Text('选择阅读主题'),
        actions: AppColors.readingThemes.asMap().entries.map((entry) {
          final index = entry.key;
          final theme = entry.value;
          final isSelected = index == _settings.themeIndex;
          return CupertinoActionSheetAction(
            onPressed: () {
              _update(_settings.copyWith(themeIndex: index));
              Navigator.pop(ctx);
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  theme.name,
                  style: TextStyle(
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
                if (isSelected) ...[
                  const SizedBox(width: 8),
                  const Icon(CupertinoIcons.checkmark,
                      size: 18, color: CupertinoColors.activeBlue),
                ],
              ],
            ),
          );
        }).toList(),
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.pop(ctx),
          child: const Text('取消'),
        ),
      ),
    );
  }

  Future<void> _pickPageTurnMode() async {
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: const Text('选择翻页模式'),
        actions: PageTurnModeUi.values(current: _settings.pageTurnMode).map((mode) {
          final isSelected = mode == _settings.pageTurnMode;
          return CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(ctx);
              if (PageTurnModeUi.isHidden(mode)) {
                _showMessage('仿真2模式已隐藏');
                return;
              }
              _update(_settings.copyWith(pageTurnMode: mode));
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  PageTurnModeUi.isHidden(mode) ? '${mode.name}（隐藏）' : mode.name,
                  style: TextStyle(
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: PageTurnModeUi.isHidden(mode)
                        ? CupertinoColors.inactiveGray
                        : null,
                  ),
                ),
                if (isSelected) ...[
                  const SizedBox(width: 8),
                  const Icon(CupertinoIcons.checkmark,
                      size: 18, color: CupertinoColors.activeBlue),
                ],
              ],
            ),
          );
        }).toList(),
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.pop(ctx),
          child: const Text('取消'),
        ),
      ),
    );
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
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('阅读偏好'),
      ),
      child: SafeArea(
        child: ListView(
          children: [
            CupertinoListSection.insetGrouped(
              header: const Text('常用'),
              children: [
                CupertinoListTile.notched(
                  title: const Text('主题'),
                  additionalInfo: Text(_themeLabel),
                  trailing: const CupertinoListTileChevron(),
                  onTap: _pickTheme,
                ),
                CupertinoListTile.notched(
                  title: const Text('翻页模式'),
                  additionalInfo: Text(_settings.pageTurnMode.name),
                  trailing: const CupertinoListTileChevron(),
                  onTap: _pickPageTurnMode,
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
              header: const Text('排版'),
              children: [
                _SliderTile(
                  title: '字体大小',
                  value: _settings.fontSize,
                  min: 10,
                  max: 40,
                  display: _settings.fontSize.toInt().toString(),
                  onChanged: (v) => _update(_settings.copyWith(fontSize: v)),
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
              ],
            ),
            CupertinoListSection.insetGrouped(
              header: const Text('亮度'),
              children: [
                CupertinoListTile.notched(
                  title: const Text('跟随系统亮度'),
                  trailing: CupertinoSwitch(
                    value: _settings.useSystemBrightness,
                    onChanged: (value) => _update(
                      _settings.copyWith(useSystemBrightness: value),
                    ),
                  ),
                ),
                _SliderTile(
                  title: '手动亮度',
                  value: _settings.brightness,
                  min: 0.0,
                  max: 1.0,
                  display: '${(_settings.brightness * 100).toInt()}%',
                  onChanged: (v) => _update(_settings.copyWith(brightness: v)),
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
                CupertinoListTile.notched(
                  title: const Text('恢复默认阅读设置'),
                  trailing: const CupertinoListTileChevron(),
                  onTap: () => _update(const ReadingSettings()),
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

  @override
  Widget build(BuildContext context) {
    return CupertinoListTile(
      title: Text(title),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 10),
        child: CupertinoSlider(
          value: value.clamp(min, max),
          min: min,
          max: max,
          onChanged: onChanged,
        ),
      ),
      additionalInfo: Text(display),
    );
  }
}
