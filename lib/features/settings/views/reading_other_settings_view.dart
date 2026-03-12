import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/cupertino.dart';

import '../../../app/theme/design_tokens.dart';
import '../../../app/widgets/app_cupertino_page_scaffold.dart';
import '../../../app/widgets/app_ui_kit.dart';
import '../../../app/widgets/cupertino_bottom_dialog.dart';
import '../../../app/widgets/option_picker_sheet.dart';
import '../../../core/services/settings_service.dart';
import '../../reader/models/reading_settings.dart';

class ReadingOtherSettingsView extends StatefulWidget {
  const ReadingOtherSettingsView({super.key});

  @override
  State<ReadingOtherSettingsView> createState() =>
      _ReadingOtherSettingsViewState();
}

class _ReadingOtherSettingsViewState extends State<ReadingOtherSettingsView> {
  final SettingsService _settingsService = SettingsService();
  late ReadingSettings _settings;

  bool get _isDark => CupertinoTheme.of(context).brightness == Brightness.dark;

  Color get _accent => ReaderSettingsTokens.accent(isDark: _isDark);

  @override
  void initState() {
    super.initState();
    _settings = _settingsService.readingSettings;
  }

  void _update(ReadingSettings next) {
    setState(() => _settings = next);
    unawaited(_settingsService.saveReadingSettings(next));
  }

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

  Widget _buildSwitchItem({
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return AppListTile(
      title: _tileTitle(title),
      trailing: CupertinoSwitch(
        value: value,
        activeTrackColor: _accent,
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildOptionItem({
    required String title,
    required String info,
    required VoidCallback onTap,
  }) {
    return AppListTile(
      title: _tileTitle(title),
      additionalInfo: _tileMeta(info),
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppCupertinoPageScaffold(
      title: '其他',
      child: AppListView(
        children: [
          AppListSection(
            header: _sectionHeader('阅读行为'),
            hasLeading: false,
            children: [
              _buildOptionItem(
                title: '屏幕常亮',
                info: _keepLightLabel(_settings.keepLightSeconds),
                onTap: _pickKeepLight,
              ),
              _buildOptionItem(
                title: '屏幕方向',
                info:
                    ReaderScreenOrientation.label(_settings.screenOrientation),
                onTap: _pickScreenOrientation,
              ),
              _buildSwitchItem(
                title: '禁用返回键',
                value: _settings.disableReturnKey,
                onChanged: (v) =>
                    _update(_settings.copyWith(disableReturnKey: v)),
              ),
              _buildSwitchItem(
                title: '展开文本菜单',
                value: _settings.expandTextMenu,
                onChanged: (v) =>
                    _update(_settings.copyWith(expandTextMenu: v)),
              ),
              _buildOptionItem(
                title: '自动阅读速度',
                info: '${_settings.autoReadSpeed}s',
                onTap: _pickAutoReadSpeed,
              ),
              _buildSwitchItem(
                title: '自动换源',
                value: _settings.autoChangeSource,
                onChanged: (v) =>
                    _update(_settings.copyWith(autoChangeSource: v)),
              ),
              _buildSwitchItem(
                title: '允许选择正文',
                value: _settings.selectText,
                onChanged: (v) =>
                    _update(_settings.copyWith(selectText: v)),
              ),
            ],
          ),
          AppListSection(
            header: _sectionHeader('显示适配'),
            hasLeading: false,
            children: [
              _buildSwitchItem(
                title: '正文适应左手',
                value: _settings.readBodyToLh,
                onChanged: (v) =>
                    _update(_settings.copyWith(readBodyToLh: v)),
              ),
              _buildSwitchItem(
                title: '刘海屏留边',
                value: _settings.paddingDisplayCutouts,
                onChanged: (v) =>
                    _update(_settings.copyWith(paddingDisplayCutouts: v)),
              ),
            ],
          ),
          AppListSection(
            header: _sectionHeader('文本处理'),
            hasLeading: false,
            children: [
              _buildOptionItem(
                title: '简繁转换',
                info:
                    ChineseConverterType.label(_settings.chineseConverterType),
                onTap: _pickChineseConverterType,
              ),
              _buildSwitchItem(
                title: '净化章节标题',
                value: _settings.cleanChapterTitle,
                onChanged: (v) =>
                    _update(_settings.copyWith(cleanChapterTitle: v)),
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Future<void> _pickAutoReadSpeed() async {
    final result = await showCupertinoBottomSheetDialog<int>(
      context: context,
      builder: (context) => _AutoReadSpeedPicker(
        initialSpeed: _settings.autoReadSpeed,
        accent: _accent,
      ),
    );
    if (result == null) return;
    _update(_settings.copyWith(autoReadSpeed: result.clamp(1, 120)));
  }

  Future<void> _pickChineseConverterType() async {
    final selected = await showOptionPickerSheet<int>(
      context: context,
      title: '简繁转换',
      currentValue: _settings.chineseConverterType,
      items: [
        for (final mode in ChineseConverterType.values)
          OptionPickerItem<int>(
            value: mode,
            label: ChineseConverterType.label(mode),
          ),
      ],
    );
    if (selected == null) return;
    _update(_settings.copyWith(chineseConverterType: selected));
  }

  Future<void> _pickScreenOrientation() async {
    final selected = await showOptionPickerSheet<int>(
      context: context,
      title: '屏幕方向',
      currentValue: _settings.screenOrientation,
      items: [
        for (final mode in ReaderScreenOrientation.values)
          OptionPickerItem<int>(
            value: mode,
            label: ReaderScreenOrientation.label(mode),
          ),
      ],
    );
    if (selected == null) return;
    _update(_settings.copyWith(screenOrientation: selected));
  }

  String _keepLightLabel(int seconds) {
    switch (seconds) {
      case ReadingSettings.keepLightFollowSystem:
        return '跟随系统';
      case ReadingSettings.keepLightOneMinute:
        return '1分钟';
      case ReadingSettings.keepLightFiveMinutes:
        return '5分钟';
      case ReadingSettings.keepLightTenMinutes:
        return '10分钟';
      case ReadingSettings.keepLightAlways:
        return '常亮';
      default:
        return '跟随系统';
    }
  }

  Future<void> _pickKeepLight() async {
    final options = [
      ReadingSettings.keepLightFollowSystem,
      ReadingSettings.keepLightOneMinute,
      ReadingSettings.keepLightFiveMinutes,
      ReadingSettings.keepLightTenMinutes,
      ReadingSettings.keepLightAlways,
    ];
    final selected = await showOptionPickerSheet<int>(
      context: context,
      title: '屏幕常亮',
      currentValue: _settings.keepLightSeconds,
      items: options
          .map((v) => OptionPickerItem<int>(
                value: v,
                label: _keepLightLabel(v),
              ))
          .toList(growable: false),
    );
    if (selected == null) return;
    _update(_settings.copyWith(keepLightSeconds: selected));
  }
}

/// 自动阅读速度选择器，对标 legado dialog_auto_read 的 SeekBar。
class _AutoReadSpeedPicker extends StatefulWidget {
  final int initialSpeed;
  final Color accent;

  const _AutoReadSpeedPicker({
    required this.initialSpeed,
    required this.accent,
  });

  @override
  State<_AutoReadSpeedPicker> createState() => _AutoReadSpeedPickerState();
}

class _AutoReadSpeedPickerState extends State<_AutoReadSpeedPicker> {
  late int _speed;

  static const int _min = 1;
  static const int _max = 120;

  // 对数映射：slider=0 最慢（120s），slider=1 最快（1s）
  double _speedToSlider(int speed) {
    final normalized =
        math.log(speed.toDouble()) / math.log(_max.toDouble());
    return (1.0 - normalized).clamp(0.0, 1.0);
  }

  int _sliderToSpeed(double slider) {
    final s = math.pow(_max.toDouble(), 1.0 - slider).round();
    return s.clamp(_min, _max);
  }

  @override
  void initState() {
    super.initState();
    _speed = widget.initialSpeed.clamp(_min, _max);
  }

  @override
  Widget build(BuildContext context) {
    final isDark =
        CupertinoTheme.of(context).brightness == Brightness.dark;
    final textStrong = CupertinoColors.label.resolveFrom(context);
    final textNormal =
        CupertinoColors.secondaryLabel.resolveFrom(context);
    return CupertinoAlertDialog(
      title: const Text('自动阅读速度'),
      content: Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '每页（屏）${_speed}s',
              style: TextStyle(
                fontSize: 13,
                color: textStrong,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text('慢',
                    style:
                        TextStyle(fontSize: 11, color: textNormal)),
                const SizedBox(width: 4),
                Expanded(
                  child: CupertinoSlider(
                    value: _speedToSlider(_speed),
                    min: 0.0,
                    max: 1.0,
                    activeColor: widget.accent,
                    thumbColor: isDark
                        ? CupertinoColors.white
                        : widget.accent,
                    onChanged: (v) {
                      setState(() => _speed = _sliderToSpeed(v));
                    },
                  ),
                ),
                const SizedBox(width: 4),
                Text('快',
                    style:
                        TextStyle(fontSize: 11, color: textNormal)),
              ],
            ),
          ],
        ),
      ),
      actions: [
        CupertinoDialogAction(
          child: const Text('取消'),
          onPressed: () => Navigator.pop(context),
        ),
        CupertinoDialogAction(
          isDefaultAction: true,
          child: const Text('确定'),
          onPressed: () => Navigator.pop(context, _speed),
        ),
      ],
    );
  }
}
