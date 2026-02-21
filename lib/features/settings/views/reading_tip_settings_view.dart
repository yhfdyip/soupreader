import 'dart:async';

import 'package:flutter/cupertino.dart';

import '../../../app/theme/design_tokens.dart';
import '../../../app/widgets/app_cupertino_page_scaffold.dart';
import '../../../app/widgets/option_picker_sheet.dart';
import '../../../core/services/settings_service.dart';
import '../../reader/models/reading_settings.dart';
import '../../reader/services/reader_tip_selection_helper.dart';
import '../../reader/widgets/reader_color_picker_dialog.dart';

class ReadingTipSettingsView extends StatefulWidget {
  const ReadingTipSettingsView({super.key});

  @override
  State<ReadingTipSettingsView> createState() => _ReadingTipSettingsViewState();
}

class _ReadingTipSettingsViewState extends State<ReadingTipSettingsView> {
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

  void _applyTipSelection(ReaderTipSlot slot, int value) {
    _update(
      ReaderTipSelectionHelper.applySelection(
        settings: _settings,
        slot: slot,
        selectedValue: value,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppCupertinoPageScaffold(
      title: '页眉页脚与标题',
      child: ListView(
        padding: const EdgeInsets.only(top: 8, bottom: 20),
        children: [
          CupertinoListSection.insetGrouped(
            header: const Text('标题'),
            children: [
              _optionTile(
                title: '章节标题位置',
                value: _titleModeLabel(_settings.titleMode),
                onTap: _pickTitleMode,
              ),
              _SliderTile(
                title: '标题字号偏移',
                value: _settings.titleSize.toDouble(),
                min: 0,
                max: 10,
                display: _settings.titleSize.toString(),
                onChanged: (value) => _update(
                  _settings.copyWith(titleSize: value.round()),
                ),
              ),
              _SliderTile(
                title: '标题上边距',
                value: _settings.titleTopSpacing,
                min: 0,
                max: 100,
                display: _settings.titleTopSpacing.toStringAsFixed(0),
                onChanged: (value) =>
                    _update(_settings.copyWith(titleTopSpacing: value)),
              ),
              _SliderTile(
                title: '标题下边距',
                value: _settings.titleBottomSpacing,
                min: 0,
                max: 100,
                display: _settings.titleBottomSpacing.toStringAsFixed(0),
                onChanged: (value) =>
                    _update(_settings.copyWith(titleBottomSpacing: value)),
              ),
            ],
          ),
          CupertinoListSection.insetGrouped(
            header: const Text('页眉'),
            children: [
              _optionTile(
                title: '显示模式',
                value: _headerModeLabel(_settings.headerMode),
                onTap: _pickHeaderMode,
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
                  onSelected: (v) =>
                      _applyTipSelection(ReaderTipSlot.headerLeft, v),
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
                      _applyTipSelection(ReaderTipSlot.headerCenter, v),
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
                      _applyTipSelection(ReaderTipSlot.headerRight, v),
                ),
              ),
            ],
          ),
          CupertinoListSection.insetGrouped(
            header: const Text('页脚'),
            children: [
              _optionTile(
                title: '显示模式',
                value: _footerModeLabel(_settings.footerMode),
                onTap: _pickFooterMode,
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
                  onSelected: (v) =>
                      _applyTipSelection(ReaderTipSlot.footerLeft, v),
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
                      _applyTipSelection(ReaderTipSlot.footerCenter, v),
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
                      _applyTipSelection(ReaderTipSlot.footerRight, v),
                ),
              ),
            ],
          ),
          CupertinoListSection.insetGrouped(
            header: const Text('页眉页脚样式'),
            children: [
              _optionTile(
                title: '文字颜色',
                value: _tipColorLabel(_settings.tipColor),
                onTap: () => _pickTipColor(forDivider: false),
              ),
              _optionTile(
                title: '分割线颜色',
                value: _tipDividerColorLabel(_settings.tipDividerColor),
                onTap: () => _pickTipColor(forDivider: true),
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
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
    final selected = await showOptionPickerSheet<int>(
      context: context,
      title: title,
      currentValue: current,
      accentColor: AppDesignTokens.brandPrimary,
      items: options
          .map(
            (opt) => OptionPickerItem<int>(
              value: opt.value,
              label: opt.label,
            ),
          )
          .toList(growable: false),
    );
    if (selected == null) return;
    onSelected(selected);
  }

  Future<void> _pickTitleMode() async {
    const options = [
      _TipOption(0, '居左'),
      _TipOption(1, '居中'),
      _TipOption(2, '隐藏'),
    ];
    await _pickTip(
      title: '章节标题位置',
      options: options,
      current: _settings.titleMode,
      onSelected: (value) => _update(_settings.copyWith(titleMode: value)),
    );
  }

  Future<void> _pickHeaderMode() async {
    await _pickTip(
      title: '页眉显示模式',
      options: _headerModeOptions,
      current: _settings.headerMode,
      onSelected: (value) => _update(_settings.copyWith(headerMode: value)),
    );
  }

  Future<void> _pickFooterMode() async {
    await _pickTip(
      title: '页脚显示模式',
      options: _footerModeOptions,
      current: _settings.footerMode,
      onSelected: (value) => _update(_settings.copyWith(footerMode: value)),
    );
  }

  Future<void> _pickTipColor({required bool forDivider}) async {
    final options = forDivider ? _tipDividerColorOptions : _tipColorOptions;
    final currentValue = forDivider
        ? (_settings.tipDividerColor ==
                    ReadingSettings.tipDividerColorDefault ||
                _settings.tipDividerColor ==
                    ReadingSettings.tipDividerColorFollowContent
            ? _settings.tipDividerColor
            : _customColorPickerValue)
        : (_settings.tipColor == ReadingSettings.tipColorFollowContent
            ? ReadingSettings.tipColorFollowContent
            : _customColorPickerValue);
    await _pickTip(
      title: forDivider ? '页眉页脚分割线颜色' : '页眉页脚文字颜色',
      options: options,
      current: currentValue,
      onSelected: (value) {
        if (value == _customColorPickerValue) {
          unawaited(_showColorInputDialog(forDivider: forDivider));
          return;
        }
        _update(
          forDivider
              ? _settings.copyWith(tipDividerColor: value)
              : _settings.copyWith(tipColor: value),
        );
      },
    );
  }

  String _titleModeLabel(int value) {
    switch (value) {
      case 1:
        return '居中';
      case 2:
        return '隐藏';
      case 0:
      default:
        return '居左';
    }
  }

  String _headerModeLabel(int value) {
    switch (value) {
      case ReadingSettings.headerModeShow:
        return '显示';
      case ReadingSettings.headerModeHide:
        return '隐藏';
      case ReadingSettings.headerModeHideWhenStatusBarShown:
      default:
        return '显示状态栏时隐藏';
    }
  }

  String _footerModeLabel(int value) {
    switch (value) {
      case ReadingSettings.footerModeHide:
        return '隐藏';
      case ReadingSettings.footerModeShow:
      default:
        return '显示';
    }
  }

  String _tipColorLabel(int value) {
    if (value == ReadingSettings.tipColorFollowContent) {
      return '同正文颜色';
    }
    return '#${_hexRgb(value)}';
  }

  String _tipDividerColorLabel(int value) {
    if (value == ReadingSettings.tipDividerColorDefault) {
      return '默认';
    }
    if (value == ReadingSettings.tipDividerColorFollowContent) {
      return '同正文颜色';
    }
    return '#${_hexRgb(value)}';
  }

  String _hexRgb(int colorValue) {
    final rgb = colorValue & 0x00FFFFFF;
    return rgb.toRadixString(16).padLeft(6, '0').toUpperCase();
  }

  Future<void> _showColorInputDialog({required bool forDivider}) async {
    final currentValue =
        forDivider ? _settings.tipDividerColor : _settings.tipColor;
    final parsed = await showReaderColorPickerDialog(
      context: context,
      title: forDivider ? '分割线颜色' : '文字颜色',
      initialColor: currentValue > 0 ? currentValue : 0xFFADADAD,
      invalidHexMessage: '请输入 6 位十六进制颜色（如 FF6600）',
    );
    if (parsed == null) return;
    _update(
      forDivider
          ? _settings.copyWith(tipDividerColor: parsed)
          : _settings.copyWith(tipColor: parsed),
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

  static const int _customColorPickerValue = -2;
  static const List<_TipOption> _headerModeOptions = [
    _TipOption(ReadingSettings.headerModeHideWhenStatusBarShown, '显示状态栏时隐藏'),
    _TipOption(ReadingSettings.headerModeShow, '显示'),
    _TipOption(ReadingSettings.headerModeHide, '隐藏'),
  ];
  static const List<_TipOption> _footerModeOptions = [
    _TipOption(ReadingSettings.footerModeShow, '显示'),
    _TipOption(ReadingSettings.footerModeHide, '隐藏'),
  ];
  static const List<_TipOption> _tipColorOptions = [
    _TipOption(ReadingSettings.tipColorFollowContent, '同正文颜色'),
    _TipOption(_customColorPickerValue, '自定义'),
  ];
  static const List<_TipOption> _tipDividerColorOptions = [
    _TipOption(ReadingSettings.tipDividerColorDefault, '默认'),
    _TipOption(ReadingSettings.tipDividerColorFollowContent, '同正文颜色'),
    _TipOption(_customColorPickerValue, '自定义'),
  ];
}

class _TipOption {
  final int value;
  final String label;

  const _TipOption(this.value, this.label);
}

class _SliderTile extends StatelessWidget {
  final String title;
  final double value;
  final double min;
  final double max;
  final String display;
  final ValueChanged<double> onChanged;

  const _SliderTile({
    required this.title,
    required this.value,
    required this.min,
    required this.max,
    required this.display,
    required this.onChanged,
  });

  double _safeMin() => min.isFinite ? min : 0.0;

  double _safeMax() {
    final safeMin = _safeMin();
    return max.isFinite && max > safeMin ? max : safeMin + 1.0;
  }

  double _safeSliderValue() {
    final safeMin = _safeMin();
    final safeMax = _safeMax();
    final safeRaw = value.isFinite ? value : safeMin;
    return safeRaw.clamp(safeMin, safeMax).toDouble();
  }

  @override
  Widget build(BuildContext context) {
    final safeMin = _safeMin();
    final safeMax = _safeMax();
    final safeValue = _safeSliderValue();
    final canSlide = min.isFinite && max.isFinite && max > min;

    return CupertinoListTile(
      title: Text(title),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 10),
        child: CupertinoSlider(
          value: safeValue,
          min: safeMin,
          max: safeMax,
          onChanged: canSlide ? onChanged : null,
        ),
      ),
      additionalInfo: Text(display),
    );
  }
}
