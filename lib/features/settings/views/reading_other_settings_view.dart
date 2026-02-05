import 'dart:async';

import 'package:flutter/cupertino.dart';

import '../../../core/services/settings_service.dart';
import '../../reader/models/reading_settings.dart';

class ReadingOtherSettingsView extends StatefulWidget {
  const ReadingOtherSettingsView({super.key});

  @override
  State<ReadingOtherSettingsView> createState() => _ReadingOtherSettingsViewState();
}

class _ReadingOtherSettingsViewState extends State<ReadingOtherSettingsView> {
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
        middle: Text('其他'),
      ),
      child: SafeArea(
        child: ListView(
          children: [
            CupertinoListSection.insetGrouped(
              header: const Text('阅读行为'),
              children: [
                CupertinoListTile.notched(
                  title: const Text('屏幕常亮'),
                  trailing: CupertinoSwitch(
                    value: _settings.keepScreenOn,
                    onChanged: (v) => _update(_settings.copyWith(keepScreenOn: v)),
                  ),
                ),
                CupertinoListTile.notched(
                  title: const Text('自动阅读速度'),
                  additionalInfo: Text(_settings.autoReadSpeed.toString()),
                  trailing: const CupertinoListTileChevron(),
                  onTap: _pickAutoReadSpeed,
                ),
              ],
            ),
            CupertinoListSection.insetGrouped(
              header: const Text('文本处理'),
              children: [
                CupertinoListTile.notched(
                  title: const Text('繁体显示'),
                  trailing: CupertinoSwitch(
                    value: _settings.chineseTraditional,
                    onChanged: (v) =>
                        _update(_settings.copyWith(chineseTraditional: v)),
                  ),
                ),
                CupertinoListTile.notched(
                  title: const Text('净化章节标题'),
                  trailing: CupertinoSwitch(
                    value: _settings.cleanChapterTitle,
                    onChanged: (v) =>
                        _update(_settings.copyWith(cleanChapterTitle: v)),
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

  Future<void> _pickAutoReadSpeed() async {
    final controller =
        TextEditingController(text: _settings.autoReadSpeed.toString());
    final result = await showCupertinoDialog<int>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('自动阅读速度'),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: CupertinoTextField(
            controller: controller,
            keyboardType: TextInputType.number,
            placeholder: '1 - 100',
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
    _update(_settings.copyWith(autoReadSpeed: result.clamp(1, 100)));
  }
}

