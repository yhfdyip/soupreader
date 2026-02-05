import 'dart:async';

import 'package:flutter/cupertino.dart';

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
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('状态栏与操作'),
      ),
      child: SafeArea(
        child: ListView(
          children: [
            CupertinoListSection.insetGrouped(
              header: const Text('状态栏'),
              children: [
                CupertinoListTile.notched(
                  title: const Text('显示状态栏'),
                  trailing: CupertinoSwitch(
                    value: _settings.showStatusBar,
                    onChanged: (v) => _update(_settings.copyWith(showStatusBar: v)),
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
                    onChanged: (v) => _update(_settings.copyWith(showProgress: v)),
                  ),
                ),
                CupertinoListTile.notched(
                  title: const Text('显示电量'),
                  trailing: CupertinoSwitch(
                    value: _settings.showBattery,
                    onChanged: (v) => _update(_settings.copyWith(showBattery: v)),
                  ),
                ),
              ],
            ),
            CupertinoListSection.insetGrouped(
              header: const Text('页眉'),
              children: [
                CupertinoListTile.notched(
                  title: const Text('显示页眉'),
                  trailing: CupertinoSwitch(
                    value: !_settings.hideHeader,
                    onChanged: (v) => _update(_settings.copyWith(hideHeader: !v)),
                  ),
                ),
                CupertinoListTile.notched(
                  title: const Text('页眉分割线'),
                  trailing: CupertinoSwitch(
                    value: _settings.showHeaderLine,
                    onChanged: (v) =>
                        _update(_settings.copyWith(showHeaderLine: v)),
                  ),
                ),
                _optionTile(
                  title: '左侧',
                  value: _tipLabel(_headerOptions, _settings.headerLeftContent),
                  onTap: () => _pickTip(
                    title: '页眉左侧',
                    options: _headerOptions,
                    current: _settings.headerLeftContent,
                    onSelected: (v) => _update(_settings.copyWith(headerLeftContent: v)),
                  ),
                ),
                _optionTile(
                  title: '中间',
                  value: _tipLabel(_headerOptions, _settings.headerCenterContent),
                  onTap: () => _pickTip(
                    title: '页眉中间',
                    options: _headerOptions,
                    current: _settings.headerCenterContent,
                    onSelected: (v) =>
                        _update(_settings.copyWith(headerCenterContent: v)),
                  ),
                ),
                _optionTile(
                  title: '右侧',
                  value: _tipLabel(_headerOptions, _settings.headerRightContent),
                  onTap: () => _pickTip(
                    title: '页眉右侧',
                    options: _headerOptions,
                    current: _settings.headerRightContent,
                    onSelected: (v) =>
                        _update(_settings.copyWith(headerRightContent: v)),
                  ),
                ),
              ],
            ),
            CupertinoListSection.insetGrouped(
              header: const Text('页脚'),
              children: [
                CupertinoListTile.notched(
                  title: const Text('显示页脚'),
                  trailing: CupertinoSwitch(
                    value: !_settings.hideFooter,
                    onChanged: (v) => _update(_settings.copyWith(hideFooter: !v)),
                  ),
                ),
                CupertinoListTile.notched(
                  title: const Text('页脚分割线'),
                  trailing: CupertinoSwitch(
                    value: _settings.showFooterLine,
                    onChanged: (v) =>
                        _update(_settings.copyWith(showFooterLine: v)),
                  ),
                ),
                _optionTile(
                  title: '左侧',
                  value: _tipLabel(_footerOptions, _settings.footerLeftContent),
                  onTap: () => _pickTip(
                    title: '页脚左侧',
                    options: _footerOptions,
                    current: _settings.footerLeftContent,
                    onSelected: (v) => _update(_settings.copyWith(footerLeftContent: v)),
                  ),
                ),
                _optionTile(
                  title: '中间',
                  value: _tipLabel(_footerOptions, _settings.footerCenterContent),
                  onTap: () => _pickTip(
                    title: '页脚中间',
                    options: _footerOptions,
                    current: _settings.footerCenterContent,
                    onSelected: (v) =>
                        _update(_settings.copyWith(footerCenterContent: v)),
                  ),
                ),
                _optionTile(
                  title: '右侧',
                  value: _tipLabel(_footerOptions, _settings.footerRightContent),
                  onTap: () => _pickTip(
                    title: '页脚右侧',
                    options: _footerOptions,
                    current: _settings.footerRightContent,
                    onSelected: (v) =>
                        _update(_settings.copyWith(footerRightContent: v)),
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
      ),
    );
  }

  Widget _optionTile({
    required String title,
    required String value,
    required VoidCallback onTap,
  }) {
    return CupertinoListTile.notched(
      title: Text(title),
      additionalInfo: Text(value),
      trailing: const CupertinoListTileChevron(),
      onTap: onTap,
    );
  }

  Future<void> _pickTip({
    required String title,
    required List<_TipOption> options,
    required int current,
    required ValueChanged<int> onSelected,
  }) async {
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: Text(title),
        actions: options.map((opt) {
          final selected = opt.value == current;
          return CupertinoActionSheetAction(
            onPressed: () {
              onSelected(opt.value);
              Navigator.pop(ctx);
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(opt.label),
                if (selected) ...[
                  const SizedBox(width: 8),
                  const Icon(CupertinoIcons.checkmark,
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

  String _tipLabel(List<_TipOption> options, int value) {
    for (final opt in options) {
      if (opt.value == value) return opt.label;
    }
    return '无';
  }

  static const List<_TipOption> _headerOptions = [
    _TipOption(0, '书名'),
    _TipOption(1, '章节名'),
    _TipOption(2, '无'),
    _TipOption(3, '时间'),
    _TipOption(4, '电量'),
    _TipOption(5, '进度'),
    _TipOption(6, '页码'),
    _TipOption(7, '章节进度'),
    _TipOption(8, '页码/总页'),
    _TipOption(9, '时间+电量'),
  ];

  static const List<_TipOption> _footerOptions = [
    _TipOption(0, '进度'),
    _TipOption(1, '页码'),
    _TipOption(2, '时间'),
    _TipOption(3, '电量'),
    _TipOption(4, '无'),
    _TipOption(5, '章节名'),
    _TipOption(6, '书名'),
    _TipOption(7, '章节进度'),
    _TipOption(8, '页码/总页'),
    _TipOption(9, '时间+电量'),
  ];
}

class _TipOption {
  final int value;
  final String label;

  const _TipOption(this.value, this.label);
}

