import 'dart:async';

import 'package:flutter/cupertino.dart';

import '../../../app/widgets/app_cupertino_page_scaffold.dart';
import '../../../core/services/settings_service.dart';
import '../../reader/models/reading_settings.dart';
import '../../replace/views/replace_rule_list_view.dart';

class TextRulesSettingsView extends StatefulWidget {
  const TextRulesSettingsView({super.key});

  @override
  State<TextRulesSettingsView> createState() => _TextRulesSettingsViewState();
}

class _TextRulesSettingsViewState extends State<TextRulesSettingsView> {
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
      title: '替换净化',
      child: ListView(
        padding: const EdgeInsets.only(top: 8, bottom: 20),
        children: [
          CupertinoListSection.insetGrouped(
            header: const Text('内置开关'),
            children: [
              CupertinoListTile.notched(
                title: const Text('净化章节标题'),
                trailing: CupertinoSwitch(
                  value: _settings.cleanChapterTitle,
                  onChanged: (v) =>
                      _update(_settings.copyWith(cleanChapterTitle: v)),
                ),
              ),
              CupertinoListTile.notched(
                title: const Text('简繁转换'),
                additionalInfo: Text(
                    ChineseConverterType.label(_settings.chineseConverterType)),
                trailing: const CupertinoListTileChevron(),
                onTap: _pickChineseConverterType,
              ),
            ],
          ),
          CupertinoListSection.insetGrouped(
            header: const Text('规则列表'),
            children: [
              CupertinoListTile.notched(
                title: const Text('文本替换规则'),
                trailing: const CupertinoListTileChevron(),
                onTap: _openReplaceRules,
              ),
            ],
          ),
          CupertinoListSection.insetGrouped(
            header: const Text('说明'),
            children: const [
              CupertinoListTile(title: Text('本页用于净化正文内容与标题。')),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Future<void> _openReplaceRules() async {
    await Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (context) => const ReplaceRuleListView(),
      ),
    );
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
}
