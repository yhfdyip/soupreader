import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform;

import '../../../app/theme/design_tokens.dart';
import '../../../app/widgets/app_sheet_header.dart';
import '../../../app/widgets/app_ui_kit.dart';
import '../../../app/widgets/cupertino_bottom_dialog.dart';
import '../../../app/widgets/option_picker_sheet.dart';
import '../../../core/services/settings_service.dart';
import '../models/reading_settings.dart';
import 'click_action_config_dialog.dart';

void showReaderMoreConfigSheet(BuildContext context) {
  showCupertinoBottomSheetDialog<void>(
    context: context,
    builder: (ctx) => const _ReaderMoreConfigSheet(),
  );
}

class _ReaderMoreConfigSheet extends StatefulWidget {
  const _ReaderMoreConfigSheet();
  @override
  State<_ReaderMoreConfigSheet> createState() => _ReaderMoreConfigSheetState();
}

class _ReaderMoreConfigSheetState extends State<_ReaderMoreConfigSheet> {
  final SettingsService _svc = SettingsService();
  late ReadingSettings _s;

  bool get _isDark => CupertinoTheme.of(context).brightness == Brightness.dark;
  bool get _volumeSupported => defaultTargetPlatform != TargetPlatform.iOS;
  Color get _accent =>
      _isDark ? AppDesignTokens.brandSecondary : AppDesignTokens.brandPrimary;

  @override
  void initState() {
    super.initState();
    _s = _svc.readingSettings;
  }

  void _u(ReadingSettings n) {
    setState(() => _s = n);
    unawaited(_svc.saveReadingSettings(n));
  }

  Widget _sw(String t, bool v, ValueChanged<bool> cb) => AppListTile(
        title: Text(t,
            style: TextStyle(
                color: CupertinoColors.label.resolveFrom(context),
                fontSize: 15)),
        trailing: CupertinoSwitch(
            value: v, activeTrackColor: _accent, onChanged: cb),
      );

  Widget _op(String t, String i, VoidCallback cb) => AppListTile(
        title: Text(t,
            style: TextStyle(
                color: CupertinoColors.label.resolveFrom(context),
                fontSize: 15)),
        additionalInfo: Text(i,
            style: TextStyle(
                color: CupertinoColors.secondaryLabel.resolveFrom(context),
                fontSize: 13)),
        onTap: cb,
      );

  Widget _hdr(String t) => Text(t,
      style: TextStyle(
          color: CupertinoColors.secondaryLabel.resolveFrom(context),
          fontSize: 13,
          fontWeight: FontWeight.w500));

  Future<void> _pickOrientation() async {
    final r = await showOptionPickerSheet<int>(
      context: context,
      title: '屏幕方向',
      currentValue: _s.screenOrientation,
      items: ReaderScreenOrientation.values
          .map((v) => OptionPickerItem<int>(
              value: v, label: ReaderScreenOrientation.label(v)))
          .toList(growable: false),
    );
    if (r == null) return;
    _u(_s.copyWith(screenOrientation: r));
  }

  Future<void> _pickKeepLight() async {
    const opts = [0, 60, 300, 600, -1];
    const lbls = {0: '跟随系统', 60: '1分钟', 300: '5分钟', 600: '10分钟', -1: '常亮'};
    final r = await showOptionPickerSheet<int>(
      context: context,
      title: '屏幕常亮',
      currentValue: _s.keepLightSeconds,
      items: opts
          .map((v) => OptionPickerItem<int>(value: v, label: lbls[v]!))
          .toList(growable: false),
    );
    if (r == null) return;
    _u(_s.copyWith(keepLightSeconds: r));
  }

  Future<void> _pickProgressBarBehavior() async {
    final r = await showOptionPickerSheet<ProgressBarBehavior>(
      context: context,
      title: '进度条行为',
      currentValue: _s.progressBarBehavior,
      items: ProgressBarBehavior.values
          .map((v) => OptionPickerItem<ProgressBarBehavior>(
              value: v, label: v.label))
          .toList(growable: false),
    );
    if (r == null) return;
    _u(_s.copyWith(progressBarBehavior: r));
  }

  Future<void> _pickTouchSlop() async {
    final ctrl =
        TextEditingController(text: _s.pageTouchSlop.toString());
    final r = await showCupertinoBottomDialog<int>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('翻页触发阈值'),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: CupertinoTextField(
            controller: ctrl,
            keyboardType: TextInputType.number,
            placeholder: '0 = 系统默认',
          ),
        ),
        actions: [
          CupertinoDialogAction(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消')),
          CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: () =>
                  Navigator.pop(ctx, int.tryParse(ctrl.text.trim())),
              child: const Text('确定')),
        ],
      ),
    );
    ctrl.dispose();
    if (r == null) return;
    _u(_s.copyWith(pageTouchSlop: r.clamp(0, 9999)));
  }

  String get _keepLightLabel {
    const lbls = {0: '跟随系统', 60: '1分钟', 300: '5分钟', 600: '10分钟', -1: '常亮'};
    return lbls[_s.keepLightSeconds] ?? '跟随系统';
  }

  String get _progressBarLabel => _s.progressBarBehavior.label;

  @override
  Widget build(BuildContext context) {
    final bg = _isDark
        ? CupertinoColors.systemGroupedBackground.darkColor
        : CupertinoColors.systemGroupedBackground.color;
    final h = MediaQuery.sizeOf(context).height;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppDesignTokens.radiusSheet)),
      child: Container(
        color: bg,
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const AppSheetHeader(title: '阅读设置'),
              SizedBox(
                height: h * 0.62,
                child: ListView(
                  padding: const EdgeInsets.only(bottom: 12),
                  children: [
                    AppListSection(
                      header: _hdr('显示'),
                      hasLeading: false,
                      children: [
                        _op('屏幕方向',
                            ReaderScreenOrientation.label(_s.screenOrientation),
                            _pickOrientation),
                        _op('屏幕常亮', _keepLightLabel, _pickKeepLight),
                        _sw('隐藏状态栏', !_s.showStatusBar,
                            (v) => _u(_s.copyWith(showStatusBar: !v))),
                        _sw('隐藏导航栏', _s.hideNavigationBar,
                            (v) => _u(_s.copyWith(hideNavigationBar: v))),
                        _sw('刘海屏留边', _s.paddingDisplayCutouts,
                            (v) => _u(
                                _s.copyWith(paddingDisplayCutouts: v))),
                        _sw('双页模式', _s.doublePage,
                            (v) => _u(_s.copyWith(doublePage: v))),
                        _op('进度条行为', _progressBarLabel,
                            _pickProgressBarBehavior),
                        _sw('显示亮度条', _s.showBrightnessView,
                            (v) => _u(
                                _s.copyWith(showBrightnessView: v))),
                        _sw('显示标题附加信息', _s.showReadTitleAddition,
                            (v) => _u(
                                _s.copyWith(showReadTitleAddition: v))),
                        _sw('菜单栏样式跟随页面', _s.readBarStyleFollowPage,
                            (v) => _u(
                                _s.copyWith(readBarStyleFollowPage: v))),
                      ],
                    ),
                    AppListSection(
                      header: _hdr('翻页与按键'),
                      hasLeading: false,
                      children: [
                        _op(
                            '翻页触发阈值',
                            _s.pageTouchSlop == 0
                                ? '系统默认'
                                : '${_s.pageTouchSlop} dp',
                            _pickTouchSlop),
                        _sw('滚动翻页无动画', _s.noAnimScrollPage,
                            (v) => _u(_s.copyWith(noAnimScrollPage: v))),
                        if (_volumeSupported) ...
                          [
                            _sw('音量键翻页', _s.volumeKeyPage,
                                (v) => _u(_s.copyWith(volumeKeyPage: v))),
                            _sw('朗读时音量键翻页', _s.volumeKeyPageOnPlay,
                                (v) => _u(
                                    _s.copyWith(volumeKeyPageOnPlay: v))),
                          ],
                        _sw('鼠标滚轮翻页', _s.mouseWheelPage,
                            (v) => _u(_s.copyWith(mouseWheelPage: v))),
                        _sw('长按按键翻页', _s.keyPageOnLongPress,
                            (v) => _u(_s.copyWith(keyPageOnLongPress: v))),
                      ],
                    ),
                    AppListSection(
                      header: _hdr('操作'),
                      hasLeading: false,
                      children: [
                        _sw('禁用返回键', _s.disableReturnKey,
                            (v) => _u(_s.copyWith(disableReturnKey: v))),
                        _sw('展开文本菜单', _s.expandTextMenu,
                            (v) => _u(_s.copyWith(expandTextMenu: v))),
                        _sw('自动换源', _s.autoChangeSource,
                            (v) => _u(_s.copyWith(autoChangeSource: v))),
                        _sw('允许选择正文', _s.selectText,
                            (v) => _u(_s.copyWith(selectText: v))),
                        AppListTile(
                          title: Text('点击区域（9宫格）',
                              style: TextStyle(
                                  color: CupertinoColors.label
                                      .resolveFrom(context),
                                  fontSize: 15)),
                          additionalInfo: Text('配置',
                              style: TextStyle(
                                  color: CupertinoColors.secondaryLabel
                                      .resolveFrom(context),
                                  fontSize: 13)),
                          onTap: () => showClickActionConfigDialog(
                            context,
                            currentConfig: _s.clickActions,
                            onSave: (c) =>
                                _u(_s.copyWith(clickActions: c)),
                          ),
                        ),
                      ],
                    ),
                    AppListSection(
                      header: _hdr('文本处理'),
                      hasLeading: false,
                      children: [
                        _sw('净化章节标题', _s.cleanChapterTitle,
                            (v) => _u(_s.copyWith(cleanChapterTitle: v))),
                        _sw('两端对齐', _s.textFullJustify,
                            (v) => _u(_s.copyWith(textFullJustify: v))),
                        _sw('底部对齐', _s.textBottomJustify,
                            (v) => _u(_s.copyWith(textBottomJustify: v))),
                      ],
                    ),
                    if (_s.pageTurnMode == PageTurnMode.simulation)
                      AppListSection(
                        header: _hdr('仿真翻页阴影调试'),
                        hasLeading: false,
                        children: [
                          _buildSlider(
                            '底页阴影强度',
                            _s.simNextShadowAlpha,
                            0.0,
                            1.0,
                            (v) => _u(_s.copyWith(
                                simNextShadowAlpha: v)),
                            format: (v) => v.toStringAsFixed(2),
                          ),
                          _buildSlider(
                            '背面折叠阴影',
                            _s.simFolderShadowAlpha,
                            0.0,
                            1.0,
                            (v) => _u(_s.copyWith(
                                simFolderShadowAlpha: v)),
                            format: (v) => v.toStringAsFixed(2),
                          ),
                          _buildSlider(
                            '圆柱半径',
                            _s.simRadiusUv,
                            0.02,
                            0.3,
                            (v) => _u(_s.copyWith(simRadiusUv: v)),
                            format: (v) => v.toStringAsFixed(3),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSlider(
    String label,
    double value,
    double min,
    double max,
    ValueChanged<double> onChanged, {
    required String Function(double) format,
  }) {
    final safeValue = value.clamp(min, max).toDouble();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      child: SizedBox(
        height: 44,
        child: Row(
          children: [
            SizedBox(
              width: 80,
              child: Text(
                label,
                style: TextStyle(
                  color: CupertinoColors.label.resolveFrom(context),
                  fontSize: 14,
                ),
              ),
            ),
            Expanded(
              child: CupertinoSlider(
                value: safeValue,
                min: min,
                max: max,
                activeColor: _accent,
                onChanged: onChanged,
              ),
            ),
            SizedBox(
              width: 44,
              child: Text(
                format(safeValue),
                textAlign: TextAlign.end,
                style: TextStyle(
                  color: CupertinoColors.secondaryLabel
                      .resolveFrom(context),
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
