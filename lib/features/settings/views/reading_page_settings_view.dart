import 'dart:async';

import 'package:flutter/cupertino.dart';

import '../../../app/widgets/app_ui_kit.dart';
import '../../../app/widgets/cupertino_bottom_dialog.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform;

import '../../../app/theme/design_tokens.dart';
import '../../../app/widgets/app_cupertino_page_scaffold.dart';
import '../../../core/services/settings_service.dart';
import '../../reader/models/reading_settings.dart';

class ReadingPageSettingsView extends StatefulWidget {
  const ReadingPageSettingsView({super.key});

  @override
  State<ReadingPageSettingsView> createState() =>
      _ReadingPageSettingsViewState();
}

class _ReadingPageSettingsViewState extends State<ReadingPageSettingsView> {
  final SettingsService _settingsService = SettingsService();
  late ReadingSettings _settings;

  bool get _supportsVolumeKeyPaging =>
      defaultTargetPlatform != TargetPlatform.iOS;

  @override
  void initState() {
    super.initState();
    _settings = _settingsService.readingSettings;
  }

  void _update(ReadingSettings next) {
    setState(() => _settings = next);
    unawaited(_settingsService.saveReadingSettings(next));
  }

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
  Widget build(BuildContext context) {
    return AppCupertinoPageScaffold(
      title: '翻页与按键',
      child: AppListView(
        children: [
          AppListSection(
            header: _sectionHeader('翻页触发'),
            hasLeading: false,
            children: [
              AppListTile(
                title: _tileTitle('翻页触发阈值'),
                additionalInfo: _tileMeta(_touchSlopLabel),
                onTap: _pickTouchSlop,
              ),
              AppListTile(
                title: _tileTitle('滚动翻页无动画'),
                trailing: CupertinoSwitch(
                  value: _settings.noAnimScrollPage,
                  activeTrackColor: _accent,
                  onChanged: (v) =>
                      _update(_settings.copyWith(noAnimScrollPage: v)),
                ),
              ),
            ],
          ),
          AppListSection(
            header: _sectionHeader('按键'),
            hasLeading: false,
            children: [
              if (_supportsVolumeKeyPaging) ...
                [
                  AppListTile(
                    title: _tileTitle('音量键翻页'),
                    trailing: CupertinoSwitch(
                      value: _settings.volumeKeyPage,
                      activeTrackColor: _accent,
                      onChanged: (v) =>
                          _update(_settings.copyWith(volumeKeyPage: v)),
                    ),
                  ),
                  AppListTile(
                    title: _tileTitle('朗读时音量键翻页'),
                    trailing: CupertinoSwitch(
                      value: _settings.volumeKeyPageOnPlay,
                      activeTrackColor: _accent,
                      onChanged: (v) => _update(
                          _settings.copyWith(volumeKeyPageOnPlay: v)),
                    ),
                  ),
                ],
              AppListTile(
                title: _tileTitle('鼠标滚轮翻页'),
                trailing: CupertinoSwitch(
                  value: _settings.mouseWheelPage,
                  activeTrackColor: _accent,
                  onChanged: (v) =>
                      _update(_settings.copyWith(mouseWheelPage: v)),
                ),
              ),
              AppListTile(
                title: _tileTitle('长按按键翻页'),
                trailing: CupertinoSwitch(
                  value: _settings.keyPageOnLongPress,
                  activeTrackColor: _accent,
                  onChanged: (v) =>
                      _update(_settings.copyWith(keyPageOnLongPress: v)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Future<void> _pickTouchSlop() async {
    final controller =
        TextEditingController(text: _settings.pageTouchSlop.toString());
    final result = await showCupertinoBottomDialog<int>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('翻页触发阈值'),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: CupertinoTextField(
            controller: controller,
            keyboardType: TextInputType.number,
            placeholder: '0 - 9999（0=系统默认）',
            clearButtonMode: OverlayVisibilityMode.editing,
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
            onPressed: () {
              final raw = int.tryParse(controller.text.trim());
              Navigator.pop(context, raw);
            },
          ),
        ],
      ),
    );
    if (result == null) return;
    _update(_settings.copyWith(pageTouchSlop: result.clamp(0, 9999)));
  }

  String get _touchSlopLabel {
    final value = _settings.pageTouchSlop;
    return value == 0 ? '系统默认' : value.toString();
  }
}
