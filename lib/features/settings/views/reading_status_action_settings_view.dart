import 'dart:async';

import 'package:flutter/cupertino.dart';

import '../../../app/theme/design_tokens.dart';
import '../../../app/widgets/app_cupertino_page_scaffold.dart';
import '../../../app/widgets/app_ui_kit.dart';
import '../../../app/widgets/option_picker_sheet.dart';
import '../../../core/services/settings_service.dart';
import '../../reader/models/reading_settings.dart';
import '../../reader/widgets/click_action_config_dialog.dart';

class ReadingStatusActionSettingsView extends StatefulWidget {
  const ReadingStatusActionSettingsView({super.key});

  @override
  State<ReadingStatusActionSettingsView> createState() =>
      _ReadingStatusActionSettingsViewState();
}

class _ReadingStatusActionSettingsViewState
    extends State<ReadingStatusActionSettingsView> {
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

  Future<void> _pickProgressBarBehavior() async {
    final selected = await showOptionPickerSheet<ProgressBarBehavior>(
      context: context,
      title: '进度条行为',
      currentValue: _settings.progressBarBehavior,
      accentColor: AppDesignTokens.brandPrimary,
      items: const [
        OptionPickerItem(
          value: ProgressBarBehavior.page,
          label: '页面',
        ),
        OptionPickerItem(
          value: ProgressBarBehavior.chapter,
          label: '章节',
        ),
      ],
    );
    if (selected == null) return;
    _update(_settings.copyWith(progressBarBehavior: selected));
  }

  @override
  Widget build(BuildContext context) {
    return AppCupertinoPageScaffold(
      title: '状态栏与操作',
      child: AppListView(
        children: [
          AppListSection(
            header: _sectionHeader('状态栏'),
            hasLeading: false,
            children: [
              _buildSwitchItem(
                title: '显示状态栏',
                value: _settings.showStatusBar,
                onChanged: (v) => _update(_settings.copyWith(showStatusBar: v)),
              ),
              _buildSwitchItem(
                title: '隐藏导航栏',
                value: _settings.hideNavigationBar,
                onChanged: (v) =>
                    _update(_settings.copyWith(hideNavigationBar: v)),
              ),
              _buildSwitchItem(
                title: '显示章节进度',
                value: _settings.showChapterProgress,
                onChanged: (v) =>
                    _update(_settings.copyWith(showChapterProgress: v)),
              ),
              _buildSwitchItem(
                title: '显示时间',
                value: _settings.showTime,
                onChanged: (v) => _update(_settings.copyWith(showTime: v)),
              ),
              _buildSwitchItem(
                title: '显示进度',
                value: _settings.showProgress,
                onChanged: (v) => _update(_settings.copyWith(showProgress: v)),
              ),
              _buildSwitchItem(
                title: '显示电量',
                value: _settings.showBattery,
                onChanged: (v) => _update(_settings.copyWith(showBattery: v)),
              ),
              _buildSwitchItem(
                title: '显示亮度条',
                value: _settings.showBrightnessView,
                onChanged: (v) =>
                    _update(_settings.copyWith(showBrightnessView: v)),
              ),
            ],
          ),
          AppListSection(
            header: _sectionHeader('菜单栏'),
            hasLeading: false,
            children: [
              _buildSwitchItem(
                title: '显示标题附加信息',
                value: _settings.showReadTitleAddition,
                onChanged: (v) =>
                    _update(_settings.copyWith(showReadTitleAddition: v)),
              ),
              _buildSwitchItem(
                title: '菜单栏样式跟随页面',
                value: _settings.readBarStyleFollowPage,
                onChanged: (v) =>
                    _update(_settings.copyWith(readBarStyleFollowPage: v)),
              ),
            ],
          ),
          AppListSection(
            header: _sectionHeader('进度条'),
            hasLeading: false,
            children: [
              _buildOptionItem(
                title: '进度条行为',
                info: _settings.progressBarBehavior == ProgressBarBehavior.chapter
                    ? '章节'
                    : '页面',
                onTap: _pickProgressBarBehavior,
              ),
            ],
          ),
          AppListSection(
            header: _sectionHeader('操作'),
            hasLeading: false,
            children: [
              _buildOptionItem(
                title: '点击区域（9 宫格）',
                info: '配置',
                onTap: () {
                  showClickActionConfigDialog(
                    context,
                    currentConfig: _settings.clickActions,
                    onSave: (newConfig) =>
                        _update(_settings.copyWith(clickActions: newConfig)),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
