import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform;

import '../../../app/theme/colors.dart';
import '../../../app/theme/design_tokens.dart';
import '../../../app/widgets/cupertino_bottom_dialog.dart';
import '../models/reading_settings.dart';

enum ReaderQuickSettingsTab {
  typography,
  interface,
  page,
  more,
}

bool get _supportsVolumeKeyPaging =>
    defaultTargetPlatform != TargetPlatform.iOS;

class ReaderQuickSettingsSheet extends StatefulWidget {
  final ReadingSettings settings;
  final List<ReadingThemeColors> themes;
  final ValueChanged<ReadingSettings> onSettingsChanged;
  final ReaderQuickSettingsTab initialTab;
  final VoidCallback onOpenFullSettings;

  const ReaderQuickSettingsSheet({
    super.key,
    required this.settings,
    required this.themes,
    required this.onSettingsChanged,
    required this.initialTab,
    required this.onOpenFullSettings,
  });

  @override
  State<ReaderQuickSettingsSheet> createState() =>
      _ReaderQuickSettingsSheetState();
}

class _ReaderQuickSettingsSheetState extends State<ReaderQuickSettingsSheet> {
  late ReaderQuickSettingsTab _tab;
  late ReadingSettings _draft;

  @override
  void initState() {
    super.initState();
    _tab = widget.initialTab;
    _draft = widget.settings;
  }

  @override
  void didUpdateWidget(covariant ReaderQuickSettingsSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 该 sheet 是一个独立 route，通常不会随外层 setState 重建；
    // 这里主要用于极少数场景（例如外部强制刷新）保持一致。
    _draft = widget.settings;
  }

  void _apply(ReadingSettings next) {
    setState(() => _draft = next);
    widget.onSettingsChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;
    final sheetBg = ReaderSettingsTokens.sheetBackground(isDark: isDark);
    final height = MediaQuery.of(context).size.height * 0.65;
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: Container(
        height: height,
        color: sheetBg,
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              _buildGrabber(),
              _buildHeader(),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: _buildTabs(),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  child: _buildBody(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGrabber() {
    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;
    final grabberColor = isDark
        ? CupertinoColors.white.withValues(alpha: 0.24)
        : CupertinoColors.separator.resolveFrom(context);
    return Center(
      child: Container(
        margin: const EdgeInsets.only(top: 10, bottom: 8),
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: grabberColor,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;
    final textColor =
        isDark ? CupertinoColors.white : CupertinoColors.label.resolveFrom(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: () => Navigator.pop(context),
            child: Icon(
              CupertinoIcons.xmark,
              color: textColor,
              size: 20,
            ),
          ),
          Expanded(
            child: Text(
              '阅读设置',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: textColor,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: _showMoreActions,
            child: Icon(
              CupertinoIcons.ellipsis,
              color: textColor,
              size: 22,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabs() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: CupertinoSlidingSegmentedControl<ReaderQuickSettingsTab>(
        groupValue: _tab,
        onValueChanged: (v) {
          if (v == null) return;
          setState(() => _tab = v);
        },
        children: const <ReaderQuickSettingsTab, Widget>{
          ReaderQuickSettingsTab.typography: Padding(
            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Text('字体'),
          ),
          ReaderQuickSettingsTab.interface: Padding(
            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Text('界面'),
          ),
          ReaderQuickSettingsTab.page: Padding(
            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Text('翻页'),
          ),
          ReaderQuickSettingsTab.more: Padding(
            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Text('其他'),
          ),
        },
      ),
    );
  }

  Widget _buildBody() {
    switch (_tab) {
      case ReaderQuickSettingsTab.typography:
        return _TypographyTab(
          key: const ValueKey('typography'),
          settings: _draft,
          onSettingsChanged: _apply,
        );
      case ReaderQuickSettingsTab.interface:
        return _InterfaceTab(
          key: const ValueKey('interface'),
          settings: _draft,
          themes: widget.themes,
          onSettingsChanged: _apply,
        );
      case ReaderQuickSettingsTab.page:
        return _PageTab(
          key: const ValueKey('page'),
          settings: _draft,
          onSettingsChanged: _apply,
        );
      case ReaderQuickSettingsTab.more:
        return _MoreTab(
          key: const ValueKey('more'),
          settings: _draft,
          onSettingsChanged: _apply,
          onOpenFullSettings: widget.onOpenFullSettings,
        );
    }
  }

  void _showMoreActions() {
    showCupertinoBottomDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (context) => CupertinoActionSheet(
        title: const Text('更多'),
        actions: [
          CupertinoActionSheetAction(
            child: const Text('打开完整阅读设置'),
            onPressed: () {
              Navigator.pop(context);
              widget.onOpenFullSettings();
            },
          ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            child: const Text('恢复默认设置'),
            onPressed: () {
              Navigator.pop(context);
              _confirmResetDefaults();
            },
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
      ),
    );
  }

  void _confirmResetDefaults() {
    showCupertinoBottomDialog<void>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('恢复默认设置'),
        content: const Text('\n将阅读设置恢复为默认值（立即生效）。'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(context);
              _apply(const ReadingSettings());
            },
            child: const Text('恢复'),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final Widget child;

  const _Section({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;
    final cardColor = ReaderSettingsTokens.sectionBackground(isDark: isDark);
    final titleColor = ReaderSettingsTokens.titleColor(isDark: isDark);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 6),
          child: Text(
            title.toUpperCase(),
            style: TextStyle(
              color: titleColor,
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.5,
            ),
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 14),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(ReaderSettingsTokens.sectionRadius),
          ),
          child: child,
        ),
      ],
    );
  }
}

class _SliderRow extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final String Function(double) format;
  final ValueChanged<double> onChanged;

  const _SliderRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.format,
    required this.onChanged,
  });

  double _safeMin() => min.isFinite ? min : 0.0;

  double _safeMax() {
    final safeMin = _safeMin();
    return max.isFinite && max > safeMin ? max : safeMin + 1.0;
  }

  double _safeValue() {
    final safeMin = _safeMin();
    final safeMax = _safeMax();
    final safeRaw = value.isFinite ? value : safeMin;
    return safeRaw.clamp(safeMin, safeMax).toDouble();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;
    final labelColor = ReaderSettingsTokens.rowTitleColor(isDark: isDark);
    final valueColor = ReaderSettingsTokens.rowMetaColor(isDark: isDark);
    final activeColor = ReaderSettingsTokens.accent(isDark: isDark);
    final safeMin = _safeMin();
    final safeMax = _safeMax();
    final safeValue = _safeValue();
    final canSlide = min.isFinite && max.isFinite && max > min;
    return SizedBox(
      height: 44,
      child: Row(
        children: [
          SizedBox(
            width: 44,
            child: Text(
              label,
              style: TextStyle(
                color: labelColor,
                fontSize: ReaderSettingsTokens.rowMetaSize,
              ),
            ),
          ),
          Expanded(
            child: CupertinoSlider(
              value: safeValue,
              min: safeMin,
              max: safeMax,
              activeColor: activeColor,
              onChanged: canSlide ? onChanged : null,
            ),
          ),
          SizedBox(
            width: 46,
            child: Text(
              format(safeValue),
              textAlign: TextAlign.end,
              style: TextStyle(color: valueColor, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _TypographyTab extends StatelessWidget {
  final ReadingSettings settings;
  final ValueChanged<ReadingSettings> onSettingsChanged;

  const _TypographyTab({
    super.key,
    required this.settings,
    required this.onSettingsChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const BouncingScrollPhysics(),
      children: [
        _Section(
          title: '字号与间距',
          child: _SliderGroup(
            rows: [
              _SliderRowData(
                label: '字号',
                value: settings.fontSize,
                min: 12,
                max: 30,
                format: (v) => v.toStringAsFixed(0),
                onChanged: (v) => onSettingsChanged(
                  settings.copyWith(fontSize: v),
                ),
              ),
              _SliderRowData(
                label: '行距',
                value: settings.lineHeight,
                min: 1.0,
                max: 2.2,
                format: (v) => v.toStringAsFixed(1),
                onChanged: (v) => onSettingsChanged(
                  settings.copyWith(lineHeight: v),
                ),
              ),
              _SliderRowData(
                label: '字距',
                value: settings.letterSpacing,
                min: -2.0,
                max: 5.0,
                format: (v) => v.toStringAsFixed(1),
                onChanged: (v) => onSettingsChanged(
                  settings.copyWith(letterSpacing: v),
                ),
              ),
              _SliderRowData(
                label: '段距',
                value: settings.paragraphSpacing,
                min: 0,
                max: 18,
                format: (v) => v.toStringAsFixed(0),
                onChanged: (v) => onSettingsChanged(
                  settings.copyWith(paragraphSpacing: v),
                ),
              ),
            ],
          ),
        ),
        _Section(
          title: '文字排版',
          child: Column(
            children: [
              _SwitchGroup(
                rows: [
                  _SwitchRowData(
                    label: '两端对齐',
                    value: settings.textFullJustify,
                    onChanged: (v) => onSettingsChanged(
                      settings.copyWith(textFullJustify: v),
                    ),
                  ),
                  _SwitchRowData(
                    label: '段首缩进',
                    value: settings.paragraphIndent.isNotEmpty,
                    onChanged: (v) => onSettingsChanged(
                      settings.copyWith(
                        paragraphIndent: v ? '　　' : '',
                      ),
                    ),
                  ),
                  _SwitchRowData(
                    label: '底部对齐',
                    value: settings.textBottomJustify,
                    onChanged: (v) => onSettingsChanged(
                      settings.copyWith(textBottomJustify: v),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _TextBoldRow(
                value: settings.textBold,
                onChanged: (v) =>
                    onSettingsChanged(settings.copyWith(textBold: v)),
              ),
            ],
          ),
        ),
        _Section(
          title: '边距',
          child: _MarginPresetRow(
            settings: settings,
            onSettingsChanged: onSettingsChanged,
          ),
        ),
        const SizedBox(height: 14),
      ],
    );
  }
}

enum _MarginPreset {
  narrow,
  normal,
  wide,
}

class _MarginPresetRow extends StatelessWidget {
  final ReadingSettings settings;
  final ValueChanged<ReadingSettings> onSettingsChanged;

  const _MarginPresetRow({
    required this.settings,
    required this.onSettingsChanged,
  });

  _MarginPreset? _inferPreset() {
    final lr = ((settings.paddingLeft + settings.paddingRight) / 2).round();
    if (lr <= 14) return _MarginPreset.narrow;
    if (lr >= 26) return _MarginPreset.wide;
    return _MarginPreset.normal;
  }

  ReadingSettings _apply(_MarginPreset preset) {
    switch (preset) {
      case _MarginPreset.narrow:
        return settings.copyWith(
          paddingLeft: 12,
          paddingRight: 12,
          paddingTop: 12,
          paddingBottom: 12,
        );
      case _MarginPreset.normal:
        return settings.copyWith(
          paddingLeft: 20,
          paddingRight: 20,
          paddingTop: 16,
          paddingBottom: 16,
        );
      case _MarginPreset.wide:
        return settings.copyWith(
          paddingLeft: 28,
          paddingRight: 28,
          paddingTop: 20,
          paddingBottom: 20,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final preset = _inferPreset() ?? _MarginPreset.normal;
    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;
    final accent =
        isDark ? AppDesignTokens.brandSecondary : AppDesignTokens.brandPrimary;
    final chipBg = isDark
        ? CupertinoColors.white.withValues(alpha: 0.1)
        : CupertinoColors.tertiarySystemFill.resolveFrom(context);
    final textNormal = isDark
        ? CupertinoColors.white.withValues(alpha: 0.7)
        : CupertinoColors.secondaryLabel.resolveFrom(context);
    Widget chip(String label, _MarginPreset v) {
      final selected = preset == v;
      return CupertinoButton(
        padding: EdgeInsets.zero,
        minimumSize: Size.zero,
        onPressed: () => onSettingsChanged(_apply(v)),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? accent.withValues(alpha: isDark ? 0.18 : 0.12)
                : chipBg,
            borderRadius: BorderRadius.circular(10),
            border: selected
                ? Border.all(color: accent.withValues(alpha: 0.5), width: 1.5)
                : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? accent : textNormal,
              fontSize: 13,
              fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        chip('窄', _MarginPreset.narrow),
        chip('标准', _MarginPreset.normal),
        chip('宽', _MarginPreset.wide),
      ],
    );
  }
}

class _InterfaceTab extends StatelessWidget {
  final ReadingSettings settings;
  final List<ReadingThemeColors> themes;
  final ValueChanged<ReadingSettings> onSettingsChanged;

  const _InterfaceTab({
    super.key,
    required this.settings,
    required this.themes,
    required this.onSettingsChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const BouncingScrollPhysics(),
      children: [
        _Section(
          title: '亮度',
          child: Column(
            children: [
              _SwitchGroup(
                rows: [
                  _SwitchRowData(
                    label: '跟随系统',
                    value: settings.useSystemBrightness,
                    onChanged: (v) => onSettingsChanged(
                        settings.copyWith(useSystemBrightness: v)),
                  ),
                ],
              ),
              Builder(builder: (context) {
                final isDark =
                    CupertinoTheme.of(context).brightness == Brightness.dark;
                return Container(
                  height: 0.5,
                  color: isDark
                      ? CupertinoColors.separator.darkColor
                      : CupertinoColors.separator.color,
                );
              }),
              const SizedBox(height: 4),
              IgnorePointer(
                ignoring: settings.useSystemBrightness,
                child: Opacity(
                  opacity: settings.useSystemBrightness ? 0.4 : 1.0,
                  child: _SliderRow(
                    label: '亮度',
                    value: settings.brightness,
                    min: 0.05,
                    max: 1.0,
                    format: (v) => '${(v * 100).round()}%',
                    onChanged: (v) =>
                        onSettingsChanged(settings.copyWith(brightness: v)),
                  ),
                ),
              ),
            ],
          ),
        ),
        _Section(
          title: '主题',
          child: _ThemeGrid(
            themes: themes,
            selectedIndex: settings.themeIndex,
            onSelected: (index) =>
                onSettingsChanged(settings.copyWith(themeIndex: index)),
          ),
        ),
        _Section(
          title: '内容边距',
          child: _SliderGroup(
            rows: [
              _SliderRowData(
                label: '上边',
                value: settings.paddingTop,
                min: 0,
                max: 80,
                format: (v) => v.round().toString(),
                onChanged: (v) => onSettingsChanged(
                  settings.copyWith(
                    paddingTop: v,
                    marginVertical: v,
                  ),
                ),
              ),
              _SliderRowData(
                label: '下边',
                value: settings.paddingBottom,
                min: 0,
                max: 80,
                format: (v) => v.round().toString(),
                onChanged: (v) => onSettingsChanged(
                  settings.copyWith(
                    paddingBottom: v,
                    marginVertical: v,
                  ),
                ),
              ),
              _SliderRowData(
                label: '左边',
                value: settings.paddingLeft,
                min: 0,
                max: 80,
                format: (v) => v.round().toString(),
                onChanged: (v) => onSettingsChanged(
                  settings.copyWith(
                    paddingLeft: v,
                    marginHorizontal: v,
                  ),
                ),
              ),
              _SliderRowData(
                label: '右边',
                value: settings.paddingRight,
                min: 0,
                max: 80,
                format: (v) => v.round().toString(),
                onChanged: (v) => onSettingsChanged(
                  settings.copyWith(
                    paddingRight: v,
                    marginHorizontal: v,
                  ),
                ),
              ),
            ],
          ),
        ),
        _Section(
          title: '页眉页脚',
          child: _SwitchGroup(
            rows: [
              _SwitchRowData(
                label: '隐藏页眉',
                value: settings.hideHeader,
                onChanged: (v) =>
                    onSettingsChanged(settings.copyWith(hideHeader: v)),
              ),
              _SwitchRowData(
                label: '隐藏页脚',
                value: settings.hideFooter,
                onChanged: (v) =>
                    onSettingsChanged(settings.copyWith(hideFooter: v)),
              ),
              _SwitchRowData(
                label: '页眉分割线',
                value: settings.showHeaderLine,
                onChanged: (v) =>
                    onSettingsChanged(settings.copyWith(showHeaderLine: v)),
              ),
              _SwitchRowData(
                label: '页脚分割线',
                value: settings.showFooterLine,
                onChanged: (v) =>
                    onSettingsChanged(settings.copyWith(showFooterLine: v)),
              ),
            ],
          ),
        ),
        _Section(
          title: '状态栏',
          child: _SwitchGroup(
            rows: [
              _SwitchRowData(
                label: '显示状态栏',
                value: settings.showStatusBar,
                onChanged: (v) =>
                    onSettingsChanged(settings.copyWith(showStatusBar: v)),
              ),
              _SwitchRowData(
                label: '显示时间',
                value: settings.showTime,
                onChanged: (v) =>
                    onSettingsChanged(settings.copyWith(showTime: v)),
              ),
              _SwitchRowData(
                label: '显示进度',
                value: settings.showProgress,
                onChanged: (v) =>
                    onSettingsChanged(settings.copyWith(showProgress: v)),
              ),
              _SwitchRowData(
                label: '显示电量',
                value: settings.showBattery,
                onChanged: (v) =>
                    onSettingsChanged(settings.copyWith(showBattery: v)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
      ],
    );
  }
}

class _ChineseConverterTypeRow extends StatelessWidget {
  final int currentType;
  final ValueChanged<int> onChanged;

  const _ChineseConverterTypeRow({
    required this.currentType,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;
    final safeType = ChineseConverterType.values.contains(currentType)
        ? currentType
        : ChineseConverterType.off;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '简繁转换',
          style: TextStyle(
            color: ReaderSettingsTokens.rowTitleColor(isDark: isDark),
            fontSize: ReaderSettingsTokens.rowTitleSize,
          ),
        ),
        const SizedBox(height: 6),
        CupertinoSlidingSegmentedControl<int>(
          groupValue: safeType,
          backgroundColor: isDark
              ? CupertinoColors.white.withValues(alpha: 0.08)
              : CupertinoColors.systemGroupedBackground.resolveFrom(context),
          thumbColor: ReaderSettingsTokens.accent(isDark: isDark),
          children: {
            for (final mode in ChineseConverterType.values)
              mode: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                child: Text(
                  ChineseConverterType.label(mode),
                  style: TextStyle(
                    color: isDark
                        ? CupertinoColors.white.withValues(alpha: 0.84)
                        : ReaderSettingsTokens.rowTitleColor(isDark: isDark),
                    fontSize: 12,
                  ),
                ),
              ),
          },
          onValueChanged: (value) {
            if (value == null) return;
            onChanged(value);
          },
        ),
      ],
    );
  }
}

class _MoreTab extends StatelessWidget {
  final ReadingSettings settings;
  final ValueChanged<ReadingSettings> onSettingsChanged;
  final VoidCallback onOpenFullSettings;

  const _MoreTab({
    super.key,
    required this.settings,
    required this.onSettingsChanged,
    required this.onOpenFullSettings,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const BouncingScrollPhysics(),
      children: [
        _Section(
          title: '其他',
          child: Column(
            children: [
              _SwitchGroup(
                rows: [
                  _SwitchRowData(
                    label: '屏幕常亮',
                    value: settings.keepLightSeconds ==
                        ReadingSettings.keepLightAlways,
                    onChanged: (v) => onSettingsChanged(
                      settings.copyWith(
                        keepLightSeconds: v
                            ? ReadingSettings.keepLightAlways
                            : ReadingSettings.keepLightFollowSystem,
                      ),
                    ),
                  ),
                  _SwitchRowData(
                    label: '净化章节标题',
                    value: settings.cleanChapterTitle,
                    onChanged: (v) => onSettingsChanged(
                      settings.copyWith(cleanChapterTitle: v),
                    ),
                  ),
                  _SwitchRowData(
                    label: '章节跳转确认',
                    value: settings.confirmSkipChapter,
                    onChanged: (v) => onSettingsChanged(
                      settings.copyWith(confirmSkipChapter: v),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _ChineseConverterTypeRow(
                currentType: settings.chineseConverterType,
                onChanged: (value) => onSettingsChanged(
                  settings.copyWith(chineseConverterType: value),
                ),
              ),
            ],
          ),
        ),
        _Section(
          title: '屏幕方向',
          child: _ScreenOrientationRow(
            value: settings.screenOrientation,
            onChanged: (v) =>
                onSettingsChanged(settings.copyWith(screenOrientation: v)),
          ),
        ),
        _Section(
          title: '高级',
          child: CupertinoButton(
            padding: const EdgeInsets.symmetric(vertical: 8),
            onPressed: onOpenFullSettings,
            child: const Text('打开完整阅读设置'),
          ),
        ),
        const SizedBox(height: 14),
      ],
    );
  }
}

class _ScreenOrientationRow extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;

  const _ScreenOrientationRow({
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final options = [
      (ReadingSettings.screenOrientationUnspecified, '跟随'),
      (ReadingSettings.screenOrientationPortrait, '竖屏'),
      (ReadingSettings.screenOrientationLandscape, '横屏'),
      (ReadingSettings.screenOrientationSensor, '传感器'),
    ];
    final safeValue = options.any((o) => o.$1 == value)
        ? value
        : ReadingSettings.screenOrientationUnspecified;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final option in options)
          _ModeChip(
            label: option.$2,
            selected: safeValue == option.$1,
            disabled: false,
            onTap: () => onChanged(option.$1),
          ),
      ],
    );
  }
}

class _ThemeGrid extends StatelessWidget {
  final List<ReadingThemeColors> themes;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  const _ThemeGrid({
    required this.themes,
    required this.selectedIndex,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final safeSelected = (selectedIndex >= 0 && selectedIndex < themes.length)
        ? selectedIndex
        : 0;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final crossAxisCount = width >= 360 ? 4 : 3;
        final itemWidth = (width - (crossAxisCount - 1) * 10) / crossAxisCount;
        final itemHeight = 54.0;

        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (var i = 0; i < themes.length; i++)
              SizedBox(
                width: itemWidth,
                height: itemHeight,
                child: _ThemeCell(
                  theme: themes[i],
                  label: themes[i].name,
                  selected: i == safeSelected,
                  onTap: () => onSelected(i),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _ThemeCell extends StatelessWidget {
  final ReadingThemeColors theme;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ThemeCell({
    required this.theme,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;
    final accent = ReaderSettingsTokens.accent(isDark: isDark);
    final borderColor =
        selected ? accent : ReaderSettingsTokens.sectionBorder(isDark: isDark);
    return CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: Size.zero,
      onPressed: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: theme.background,
          borderRadius: BorderRadius.circular(AppDesignTokens.radiusCard),
          border: Border.all(color: borderColor, width: selected ? 2.0 : 0.5),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.25),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        padding: const EdgeInsets.all(8),
        child: Stack(
          children: [
            Align(
              alignment: Alignment.bottomLeft,
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: theme.text.withValues(alpha: 0.9),
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
            if (selected)
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: accent,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    CupertinoIcons.checkmark,
                    color: CupertinoColors.white,
                    size: 10,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PageTab extends StatelessWidget {
  final ReadingSettings settings;
  final ValueChanged<ReadingSettings> onSettingsChanged;

  const _PageTab({
    super.key,
    required this.settings,
    required this.onSettingsChanged,
  });

  @override
  Widget build(BuildContext context) {
    final modes = PageTurnModeUi.values(current: settings.pageTurnMode);
    return ListView(
      physics: const BouncingScrollPhysics(),
      children: [
        _Section(
          title: '翻页模式',
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final mode in modes)
                _ModeChip(
                  label: mode.name,
                  selected: settings.pageTurnMode == mode,
                  disabled: PageTurnModeUi.isHidden(mode),
                  onTap: () {
                    if (PageTurnModeUi.isHidden(mode)) return;
                    onSettingsChanged(settings.copyWith(pageTurnMode: mode));
                  },
                ),
            ],
          ),
        ),
        if (_supportsVolumeKeyPaging)
          _Section(
            title: '按键',
            child: _SwitchGroup(
              rows: [
                _SwitchRowData(
                  label: '音量键翻页',
                  value: settings.volumeKeyPage,
                  onChanged: (v) => onSettingsChanged(
                      settings.copyWith(volumeKeyPage: v)),
                ),
              ],
            ),
          ),
        const SizedBox(height: 14),
      ],
    );
  }
}

class _ModeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final bool disabled;
  final VoidCallback onTap;

  const _ModeChip({
    required this.label,
    required this.selected,
    required this.disabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;
    final accent = ReaderSettingsTokens.accent(isDark: isDark);
    final bgNormal = isDark
        ? CupertinoColors.white.withValues(alpha: 0.1)
        : CupertinoColors.tertiarySystemFill.resolveFrom(context);
    final textNormal = ReaderSettingsTokens.rowMetaColor(isDark: isDark);
    final baseColor =
        selected ? accent.withValues(alpha: isDark ? 0.18 : 0.12) : bgNormal;
    final textColor = selected ? accent : textNormal;
    final opacity = disabled ? 0.45 : 1.0;
    return Opacity(
      opacity: opacity,
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        minimumSize: Size.zero,
        onPressed: disabled ? null : onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: baseColor,
            borderRadius: BorderRadius.circular(10),
            border: selected
                ? Border.all(
                    color: accent.withValues(alpha: 0.5), width: 1.5)
                : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              color: textColor,
              fontSize: 13,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

class _SwitchRowData {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchRowData({
    required this.label,
    required this.value,
    required this.onChanged,
  });
}

class _SwitchGroup extends StatelessWidget {
  final List<_SwitchRowData> rows;

  const _SwitchGroup({required this.rows});

  @override
  Widget build(BuildContext context) {
    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;
    final dividerColor = isDark
        ? CupertinoColors.separator.darkColor
        : CupertinoColors.separator.color;
    final activeTrackColor = ReaderSettingsTokens.accent(isDark: isDark);
    final labelColor = ReaderSettingsTokens.rowTitleColor(isDark: isDark);

    return Column(
      children: [
        for (int i = 0; i < rows.length; i++) ...[
          SizedBox(
            height: 44,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  rows[i].label,
                  style: TextStyle(
                    color: labelColor,
                    fontSize: ReaderSettingsTokens.rowTitleSize,
                  ),
                ),
                Transform.scale(
                  scale: 0.85,
                  child: CupertinoSwitch(
                    value: rows[i].value,
                    onChanged: rows[i].onChanged,
                    activeTrackColor: activeTrackColor,
                  ),
                ),
              ],
            ),
          ),
          if (i < rows.length - 1)
            Container(
              height: 0.5,
              color: dividerColor,
            ),
        ],
      ],
    );
  }
}

class _SliderRowData {
  final String label;
  final double value;
  final double min;
  final double max;
  final String Function(double) format;
  final ValueChanged<double> onChanged;

  const _SliderRowData({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.format,
    required this.onChanged,
  });
}

class _SliderGroup extends StatelessWidget {
  final List<_SliderRowData> rows;

  const _SliderGroup({required this.rows});

  @override
  Widget build(BuildContext context) {
    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;
    final dividerColor = isDark
        ? CupertinoColors.separator.darkColor
        : CupertinoColors.separator.color;

    return Column(
      children: [
        for (int i = 0; i < rows.length; i++) ...[
          _SliderRow(
            label: rows[i].label,
            value: rows[i].value,
            min: rows[i].min,
            max: rows[i].max,
            format: rows[i].format,
            onChanged: rows[i].onChanged,
          ),
          if (i < rows.length - 1)
            Container(height: 0.5, color: dividerColor),
        ],
      ],
    );
  }
}

class _TextBoldRow extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;

  const _TextBoldRow({
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;
    final safeValue = (value == -1 || value == 0 || value == 1) ? value : 0;
    return Row(
      children: [
        Text(
          '字重',
          style: TextStyle(
            color: ReaderSettingsTokens.rowTitleColor(isDark: isDark),
            fontSize: ReaderSettingsTokens.rowTitleSize,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: CupertinoSlidingSegmentedControl<int>(
            groupValue: safeValue,
            onValueChanged: (v) {
              if (v == null) return;
              onChanged(v);
            },
            children: const <int, Widget>{
              -1: Padding(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Text('细体'),
              ),
              0: Padding(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Text('正常'),
              ),
              1: Padding(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Text('粗体'),
              ),
            },
          ),
        ),
      ],
    );
  }
}
