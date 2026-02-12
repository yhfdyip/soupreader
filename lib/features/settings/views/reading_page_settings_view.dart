import 'dart:async';

import 'package:flutter/cupertino.dart';

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
      title: '翻页与按键',
      child: ListView(
        children: [
          CupertinoListSection.insetGrouped(
            header: const Text('翻页触发'),
            children: [
              CupertinoListTile.notched(
                title: const Text('翻页触发灵敏度'),
                additionalInfo: Text('${_settings.pageTouchSlop}%'),
                trailing: const CupertinoListTileChevron(),
                onTap: _pickTouchSlop,
              ),
            ],
          ),
          CupertinoListSection.insetGrouped(
            header: const Text('按键与文本'),
            children: [
              CupertinoListTile.notched(
                title: const Text('音量键翻页'),
                trailing: CupertinoSwitch(
                  value: _settings.volumeKeyPage,
                  onChanged: (v) =>
                      _update(_settings.copyWith(volumeKeyPage: v)),
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
