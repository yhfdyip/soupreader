import 'dart:async';

import 'package:flutter/cupertino.dart';

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
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('替换净化'),
      ),
      child: SafeArea(
        child: ListView(
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
                  title: const Text('繁体显示'),
                  trailing: CupertinoSwitch(
                    value: _settings.chineseTraditional,
                    onChanged: (v) =>
                        _update(_settings.copyWith(chineseTraditional: v)),
                  ),
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
}
