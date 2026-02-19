import 'package:flutter/cupertino.dart';

import '../../../app/theme/colors.dart';
import '../../../app/theme/design_tokens.dart';
import '../models/reading_settings.dart';

enum ReaderQuickSettingsTab {
  typography,
  interface,
  page,
  more,
}

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
    final sheetBg = isDark
        ? const Color(0xFF1C1C1E)
        : AppDesignTokens.surfaceLight.withValues(alpha: 0.98);
    final height = MediaQuery.of(context).size.height * 0.62;
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: sheetBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
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
    );
  }

  Widget _buildGrabber() {
    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;
    final grabberColor = isDark
        ? CupertinoColors.white.withValues(alpha: 0.24)
        : AppDesignTokens.textMuted.withValues(alpha: 0.35);
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
        isDark ? CupertinoColors.white : AppDesignTokens.textStrong;
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
    showCupertinoModalPopup<void>(
      context: context,
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
    showCupertinoDialog<void>(
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
    final cardColor = isDark
        ? CupertinoColors.white.withValues(alpha: 0.1)
        : AppDesignTokens.surfaceLight.withValues(alpha: 0.9);
    final borderColor = isDark
        ? CupertinoColors.white.withValues(alpha: 0.12)
        : AppDesignTokens.borderLight;
    final titleColor = isDark
        ? CupertinoColors.white.withValues(alpha: 0.6)
        : AppDesignTokens.textMuted;
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 10, 14, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: titleColor,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
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
    final labelColor =
        isDark ? CupertinoColors.white : AppDesignTokens.textStrong;
    final valueColor =
        isDark ? CupertinoColors.white : AppDesignTokens.textNormal;
    final activeColor =
        isDark ? AppDesignTokens.brandSecondary : AppDesignTokens.brandPrimary;
    final safeMin = _safeMin();
    final safeMax = _safeMax();
    final safeValue = _safeValue();
    final canSlide = min.isFinite && max.isFinite && max > min;
    return Row(
      children: [
        SizedBox(
          width: 44,
          child: Text(
            label,
            style: TextStyle(color: labelColor, fontSize: 13),
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
          child: Column(
            children: [
              _SliderRow(
                label: '字号',
                value: settings.fontSize,
                min: 12,
                max: 30,
                format: (v) => v.toStringAsFixed(0),
                onChanged: (v) => onSettingsChanged(
                  settings.copyWith(fontSize: v),
                ),
              ),
              const SizedBox(height: 6),
              _SliderRow(
                label: '行距',
                value: settings.lineHeight,
                min: 1.0,
                max: 2.2,
                format: (v) => v.toStringAsFixed(1),
                onChanged: (v) => onSettingsChanged(
                  settings.copyWith(lineHeight: v),
                ),
              ),
              const SizedBox(height: 6),
              _SliderRow(
                label: '字距',
                value: settings.letterSpacing,
                min: -2.0,
                max: 5.0,
                format: (v) => v.toStringAsFixed(1),
                onChanged: (v) => onSettingsChanged(
                  settings.copyWith(letterSpacing: v),
                ),
              ),
              const SizedBox(height: 6),
              _SliderRow(
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
        : AppDesignTokens.surfaceLight.withValues(alpha: 0.92);
    final chipBorder = isDark
        ? CupertinoColors.white.withValues(alpha: 0.12)
        : AppDesignTokens.borderLight;
    final textNormal = isDark
        ? CupertinoColors.white.withValues(alpha: 0.7)
        : AppDesignTokens.textNormal;
    Widget chip(String label, _MarginPreset v) {
      final selected = preset == v;
      return GestureDetector(
        onTap: () => onSettingsChanged(_apply(v)),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? accent.withValues(alpha: isDark ? 0.18 : 0.12)
                : chipBg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? accent : chipBorder,
            ),
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
              _SwitchRow(
                label: '跟随系统',
                value: settings.useSystemBrightness,
                onChanged: (v) => onSettingsChanged(
                    settings.copyWith(useSystemBrightness: v)),
              ),
              const SizedBox(height: 10),
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
          child: Column(
            children: [
              _SliderRow(
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
              const SizedBox(height: 8),
              _SliderRow(
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
              const SizedBox(height: 8),
              _SliderRow(
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
              const SizedBox(height: 8),
              _SliderRow(
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
          child: Column(
            children: [
              _SwitchRow(
                label: '隐藏页眉',
                value: settings.hideHeader,
                onChanged: (v) =>
                    onSettingsChanged(settings.copyWith(hideHeader: v)),
              ),
              const SizedBox(height: 8),
              _SwitchRow(
                label: '隐藏页脚',
                value: settings.hideFooter,
                onChanged: (v) =>
                    onSettingsChanged(settings.copyWith(hideFooter: v)),
              ),
              const SizedBox(height: 8),
              _SwitchRow(
                label: '页眉分割线',
                value: settings.showHeaderLine,
                onChanged: (v) =>
                    onSettingsChanged(settings.copyWith(showHeaderLine: v)),
              ),
              const SizedBox(height: 8),
              _SwitchRow(
                label: '页脚分割线',
                value: settings.showFooterLine,
                onChanged: (v) =>
                    onSettingsChanged(settings.copyWith(showFooterLine: v)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
      ],
    );
  }
}

class _SwitchRow extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;
    final labelColor =
        isDark ? CupertinoColors.white : AppDesignTokens.textStrong;
    final activeTrackColor =
        isDark ? AppDesignTokens.brandSecondary : AppDesignTokens.brandPrimary;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(color: labelColor, fontSize: 14),
        ),
        CupertinoSwitch(
          value: value,
          onChanged: onChanged,
          activeTrackColor: activeTrackColor,
        ),
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
            color: isDark ? CupertinoColors.white : AppDesignTokens.textStrong,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 6),
        CupertinoSlidingSegmentedControl<int>(
          groupValue: safeType,
          backgroundColor: isDark
              ? CupertinoColors.white.withValues(alpha: 0.08)
              : AppDesignTokens.pageBgLight,
          thumbColor: isDark
              ? AppDesignTokens.brandSecondary
              : AppDesignTokens.brandPrimary,
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
                        : AppDesignTokens.textStrong,
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
              _SwitchRow(
                label: '屏幕常亮',
                value: settings.keepScreenOn,
                onChanged: (v) => onSettingsChanged(
                  settings.copyWith(keepScreenOn: v),
                ),
              ),
              const SizedBox(height: 8),
              _SwitchRow(
                label: '净化章节标题',
                value: settings.cleanChapterTitle,
                onChanged: (v) => onSettingsChanged(
                  settings.copyWith(cleanChapterTitle: v),
                ),
              ),
              const SizedBox(height: 8),
              _SwitchRow(
                label: '音量键翻页',
                value: settings.volumeKeyPage,
                onChanged: (v) =>
                    onSettingsChanged(settings.copyWith(volumeKeyPage: v)),
              ),
              const SizedBox(height: 8),
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
    final accent =
        isDark ? AppDesignTokens.brandSecondary : AppDesignTokens.brandPrimary;
    final borderColor = selected ? accent : AppDesignTokens.borderLight;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: theme.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor, width: selected ? 1.4 : 1),
        ),
        padding: const EdgeInsets.all(8),
        child: Align(
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
    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;
    final labelColor =
        isDark ? CupertinoColors.white : AppDesignTokens.textStrong;
    final activeTrackColor =
        isDark ? AppDesignTokens.brandSecondary : AppDesignTokens.brandPrimary;
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
        _Section(
          title: '动画与按键',
          child: Column(
            children: [
              _SliderRow(
                label: '动画',
                value: settings.pageAnimDuration.toDouble(),
                min: 100,
                max: 600,
                format: (v) => '${v.round()}ms',
                onChanged: (v) => onSettingsChanged(
                  settings.copyWith(pageAnimDuration: v.round()),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '音量键翻页',
                    style: TextStyle(color: labelColor, fontSize: 14),
                  ),
                  CupertinoSwitch(
                    value: settings.volumeKeyPage,
                    onChanged: (v) =>
                        onSettingsChanged(settings.copyWith(volumeKeyPage: v)),
                    activeTrackColor: activeTrackColor,
                  ),
                ],
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
    final accent =
        isDark ? AppDesignTokens.brandSecondary : AppDesignTokens.brandPrimary;
    final bgNormal = isDark
        ? CupertinoColors.white.withValues(alpha: 0.1)
        : AppDesignTokens.surfaceLight.withValues(alpha: 0.92);
    final borderNormal = isDark
        ? CupertinoColors.white.withValues(alpha: 0.12)
        : AppDesignTokens.borderLight;
    final textNormal =
        isDark ? CupertinoColors.white : AppDesignTokens.textNormal;
    final baseColor =
        selected ? accent.withValues(alpha: isDark ? 0.18 : 0.12) : bgNormal;
    final borderColor = selected ? accent : borderNormal;
    final textColor = selected ? accent : textNormal;
    final opacity = disabled ? 0.45 : 1.0;
    return Opacity(
      opacity: opacity,
      child: GestureDetector(
        onTap: disabled ? null : onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: baseColor,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: borderColor),
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
