import 'dart:async';

import 'package:flutter/cupertino.dart';

import '../../../core/services/settings_service.dart';
import '../../reader/models/reading_settings.dart';

class ReadingPageSettingsView extends StatefulWidget {
  const ReadingPageSettingsView({super.key});

  @override
  State<ReadingPageSettingsView> createState() => _ReadingPageSettingsViewState();
}

class _ReadingPageSettingsViewState extends State<ReadingPageSettingsView> {
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
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('翻页与按键'),
      ),
      child: SafeArea(
        child: ListView(
          children: [
            CupertinoListSection.insetGrouped(
              header: const Text('翻页动画'),
              children: [
                CupertinoListTile.notched(
                  title: const Text('动画时长'),
                  additionalInfo: Text('${_settings.pageAnimDuration} ms'),
                  trailing: const CupertinoListTileChevron(),
                  onTap: () => _pickAnimDuration(),
                ),
                CupertinoListTile.notched(
                  title: const Text('翻页方向'),
                  additionalInfo: Text(_settings.pageDirection.name),
                  trailing: const CupertinoListTileChevron(),
                  onTap: _pickDirection,
                ),
                CupertinoListTile.notched(
                  title: const Text('滚动模式无动画翻页'),
                  trailing: CupertinoSwitch(
                    value: _settings.noAnimScrollPage,
                    onChanged: (v) => _update(_settings.copyWith(noAnimScrollPage: v)),
                  ),
                ),
              ],
            ),
            CupertinoListSection.insetGrouped(
              header: const Text('触发与按键'),
              children: [
                CupertinoListTile.notched(
                  title: const Text('翻页触发灵敏度'),
                  additionalInfo: Text('${_settings.pageTouchSlop}%'),
                  trailing: const CupertinoListTileChevron(),
                  onTap: _pickTouchSlop,
                ),
                CupertinoListTile.notched(
                  title: const Text('音量键翻页'),
                  trailing: CupertinoSwitch(
                    value: _settings.volumeKeyPage,
                    onChanged: (v) => _update(_settings.copyWith(volumeKeyPage: v)),
                  ),
                ),
                CupertinoListTile.notched(
                  title: const Text('鼠标滚轮翻页'),
                  trailing: CupertinoSwitch(
                    value: _settings.mouseWheelPage,
                    onChanged: (v) => _update(_settings.copyWith(mouseWheelPage: v)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAnimDuration() async {
    final controller =
        TextEditingController(text: _settings.pageAnimDuration.toString());
    final result = await showCupertinoDialog<int>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('动画时长 (ms)'),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: CupertinoTextField(
            controller: controller,
            keyboardType: TextInputType.number,
            placeholder: '100 - 600',
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
    final duration = result.clamp(100, 600);
    _update(_settings.copyWith(pageAnimDuration: duration));
  }

  Future<void> _pickDirection() async {
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: const Text('翻页方向'),
        actions: PageDirection.values.map((dir) {
          final selected = dir == _settings.pageDirection;
          return CupertinoActionSheetAction(
            onPressed: () {
              _update(_settings.copyWith(pageDirection: dir));
              Navigator.pop(ctx);
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(dir.name),
                if (selected) ...[
                  const SizedBox(width: 8),
                  const Icon(CupertinoIcons.check_mark,
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

  Future<void> _pickTouchSlop() async {
    final controller =
        TextEditingController(text: _settings.pageTouchSlop.toString());
    final result = await showCupertinoDialog<int>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('翻页灵敏度 (%)'),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: CupertinoTextField(
            controller: controller,
            keyboardType: TextInputType.number,
            placeholder: '0 - 100',
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
    _update(_settings.copyWith(pageTouchSlop: result.clamp(0, 100)));
  }
}

