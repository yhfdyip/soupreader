import 'dart:async';

import 'package:flutter/cupertino.dart';

import '../../../app/widgets/app_cupertino_page_scaffold.dart';
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

  @override
  void initState() {
    super.initState();
    _settings = _settingsService.readingSettings;
  }

  void _update(ReadingSettings next) {
    setState(() => _settings = next);
    unawaited(_settingsService.saveReadingSettings(next));
  }

  @override
  Widget build(BuildContext context) {
    return AppCupertinoPageScaffold(
      title: '状态栏与操作',
      child: ListView(
        padding: const EdgeInsets.only(top: 8, bottom: 20),
        children: [
          CupertinoListSection.insetGrouped(
            header: const Text('状态栏'),
            children: [
              CupertinoListTile.notched(
                title: const Text('显示状态栏'),
                trailing: CupertinoSwitch(
                  value: _settings.showStatusBar,
                  onChanged: (v) =>
                      _update(_settings.copyWith(showStatusBar: v)),
                ),
              ),
              CupertinoListTile.notched(
                title: const Text('隐藏导航栏'),
                trailing: CupertinoSwitch(
                  value: _settings.hideNavigationBar,
                  onChanged: (v) =>
                      _update(_settings.copyWith(hideNavigationBar: v)),
                ),
              ),
              CupertinoListTile.notched(
                title: const Text('显示章节进度'),
                trailing: CupertinoSwitch(
                  value: _settings.showChapterProgress,
                  onChanged: (v) =>
                      _update(_settings.copyWith(showChapterProgress: v)),
                ),
              ),
              CupertinoListTile.notched(
                title: const Text('显示时间'),
                trailing: CupertinoSwitch(
                  value: _settings.showTime,
                  onChanged: (v) => _update(_settings.copyWith(showTime: v)),
                ),
              ),
              CupertinoListTile.notched(
                title: const Text('显示进度'),
                trailing: CupertinoSwitch(
                  value: _settings.showProgress,
                  onChanged: (v) =>
                      _update(_settings.copyWith(showProgress: v)),
                ),
              ),
              CupertinoListTile.notched(
                title: const Text('显示电量'),
                trailing: CupertinoSwitch(
                  value: _settings.showBattery,
                  onChanged: (v) => _update(_settings.copyWith(showBattery: v)),
                ),
              ),
              CupertinoListTile.notched(
                title: const Text('显示亮度条'),
                trailing: CupertinoSwitch(
                  value: _settings.showBrightnessView,
                  onChanged: (v) =>
                      _update(_settings.copyWith(showBrightnessView: v)),
                ),
              ),
            ],
          ),
          CupertinoListSection.insetGrouped(
            header: const Text('操作'),
            children: [
              CupertinoListTile.notched(
                title: const Text('点击区域（9 宫格）'),
                additionalInfo: const Text('配置'),
                trailing: const CupertinoListTileChevron(),
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
