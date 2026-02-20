import 'dart:async';

import 'package:flutter/cupertino.dart';

import '../../../app/widgets/app_cupertino_page_scaffold.dart';
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
      title: '其他',
      child: ListView(
        padding: const EdgeInsets.only(top: 8, bottom: 20),
        children: [
          CupertinoListSection.insetGrouped(
            header: const Text('阅读行为'),
            children: [
              CupertinoListTile.notched(
                title: const Text('屏幕常亮'),
                trailing: CupertinoSwitch(
                  value: _settings.keepScreenOn,
                  onChanged: (v) =>
                      _update(_settings.copyWith(keepScreenOn: v)),
                ),
              ),
              CupertinoListTile.notched(
                title: const Text('屏幕方向'),
                additionalInfo: Text(
                    ReaderScreenOrientation.label(_settings.screenOrientation)),
                trailing: const CupertinoListTileChevron(),
                onTap: _pickScreenOrientation,
              ),
              CupertinoListTile.notched(
                title: const Text('禁用返回键'),
                trailing: CupertinoSwitch(
                  value: _settings.disableReturnKey,
                  onChanged: (v) =>
                      _update(_settings.copyWith(disableReturnKey: v)),
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
                title: const Text('简繁转换'),
                additionalInfo: Text(
                    ChineseConverterType.label(_settings.chineseConverterType)),
                trailing: const CupertinoListTileChevron(),
                onTap: _pickChineseConverterType,
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

  Future<void> _pickChineseConverterType() async {
    final selected = await showCupertinoModalPopup<int>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('简繁转换'),
        actions: [
          for (final mode in ChineseConverterType.values)
            CupertinoActionSheetAction(
              onPressed: () => Navigator.pop(context, mode),
              child: Text(ChineseConverterType.label(mode)),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
      ),
    );
    if (selected == null) return;
    _update(_settings.copyWith(chineseConverterType: selected));
  }

  Future<void> _pickScreenOrientation() async {
    final selected = await showCupertinoModalPopup<int>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('屏幕方向'),
        actions: [
          for (final mode in ReaderScreenOrientation.values)
            CupertinoActionSheetAction(
              onPressed: () => Navigator.pop(context, mode),
              child: Text(ReaderScreenOrientation.label(mode)),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
      ),
    );
    if (selected == null) return;
    _update(_settings.copyWith(screenOrientation: selected));
  }
}
