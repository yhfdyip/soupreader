import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart'
    show
        Colors,
        RoundSliderOverlayShape,
        RoundSliderThumbShape,
        Slider,
        SliderTheme,
        SliderThemeData;

import '../../../app/theme/colors.dart';
import '../models/reading_settings.dart';

/// 阅读器底部菜单（对标同类阅读器：章节进度 + 高频设置 + 底部导航）
class ReaderBottomMenuNew extends StatefulWidget {
  final int currentChapterIndex;
  final int totalChapters;
  final int currentPageIndex;
  final int totalPages;
  final ReadingSettings settings;
  final ReadingThemeColors currentTheme;
  final ValueChanged<int> onChapterChanged;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<ReadingSettings> onSettingsChanged;
  final VoidCallback onShowChapterList;
  final VoidCallback onShowTypography;
  final VoidCallback onShowTheme;
  final VoidCallback onShowPage;
  final VoidCallback onOpenFullSettings;
  final VoidCallback onToggleAutoRead;
  final bool autoReadRunning;

  const ReaderBottomMenuNew({
    super.key,
    required this.currentChapterIndex,
    required this.totalChapters,
    required this.currentPageIndex,
    required this.totalPages,
    required this.settings,
    required this.currentTheme,
    required this.onChapterChanged,
    required this.onPageChanged,
    required this.onSettingsChanged,
    required this.onShowChapterList,
    required this.onShowTypography,
    required this.onShowTheme,
    required this.onShowPage,
    required this.onOpenFullSettings,
    required this.onToggleAutoRead,
    required this.autoReadRunning,
  });

  @override
  State<ReaderBottomMenuNew> createState() => _ReaderBottomMenuNewState();
}

class _ReaderBottomMenuNewState extends State<ReaderBottomMenuNew> {
  int _selectedTab = -1;
  bool _isDragging = false;
  double _dragValue = 0;

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C1E).withValues(alpha: 0.98),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 22,
              offset: const Offset(0, -6),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.only(
              left: 12,
              right: 12,
              top: 8,
              bottom: bottomPadding > 0 ? 6 : 10,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildGrabber(),
                _buildSectionCard(_buildChapterSlider()),
                const SizedBox(height: 8),
                _buildSectionCard(_buildBrightnessAndFontRow()),
                const SizedBox(height: 8),
                _buildSectionCard(_buildPageModeAndOtherRow()),
                const SizedBox(height: 10),
                _buildBottomTabs(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGrabber() {
    return Container(
      margin: const EdgeInsets.only(top: 2, bottom: 8),
      width: 36,
      height: 4,
      decoration: BoxDecoration(
        color: Colors.white24,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Widget _buildSectionCard(Widget child) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: child,
    );
  }

  Widget _buildChapterSlider() {
    final maxPage = (widget.totalPages - 1).clamp(0, 9999);
    final chapterLabel =
        '第${widget.currentChapterIndex + 1}章 / ${widget.totalChapters}章';
    final pageLabel = '${widget.currentPageIndex + 1}/${widget.totalPages}页';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              chapterLabel,
              style: const TextStyle(
                color: CupertinoColors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            Text(
              pageLabel,
              style: const TextStyle(
                color: CupertinoColors.systemGrey,
                fontSize: 12,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              onPressed: widget.currentChapterIndex > 0
                  ? () =>
                      widget.onChapterChanged(widget.currentChapterIndex - 1)
                  : null,
              child: Text(
                '上一章',
                style: TextStyle(
                  fontSize: 12,
                  color: widget.currentChapterIndex > 0
                      ? CupertinoColors.activeBlue
                      : CupertinoColors.systemGrey,
                ),
              ),
            ),
            Expanded(
              child: SliderTheme(
                data: SliderThemeData(
                  trackHeight: 4,
                  thumbShape:
                      const RoundSliderThumbShape(enabledThumbRadius: 8),
                  overlayShape:
                      const RoundSliderOverlayShape(overlayRadius: 15),
                  activeTrackColor: CupertinoColors.activeBlue,
                  inactiveTrackColor:
                      CupertinoColors.systemGrey.withValues(alpha: 0.28),
                  thumbColor: CupertinoColors.white,
                ),
                child: Slider(
                  value: _isDragging
                      ? _dragValue.clamp(0, maxPage.toDouble())
                      : widget.currentPageIndex
                          .toDouble()
                          .clamp(0, maxPage.toDouble()),
                  min: 0,
                  max: maxPage.toDouble(),
                  onChanged: (value) {
                    setState(() {
                      _isDragging = true;
                      _dragValue = value;
                    });
                  },
                  onChangeEnd: (value) {
                    setState(() => _isDragging = false);
                    widget.onPageChanged(value.toInt());
                  },
                ),
              ),
            ),
            CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              onPressed: widget.currentChapterIndex < widget.totalChapters - 1
                  ? () =>
                      widget.onChapterChanged(widget.currentChapterIndex + 1)
                  : null,
              child: Text(
                '下一章',
                style: TextStyle(
                  fontSize: 12,
                  color: widget.currentChapterIndex < widget.totalChapters - 1
                      ? CupertinoColors.activeBlue
                      : CupertinoColors.systemGrey,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBrightnessAndFontRow() {
    final fontSize = widget.settings.fontSize;
    final canDecrease = fontSize > 10;
    final canIncrease = fontSize < 40;

    return Column(
      children: [
        Row(
          children: [
            const SizedBox(
              width: 34,
              child: Text(
                '亮度',
                style:
                    TextStyle(color: CupertinoColors.systemGrey, fontSize: 12),
              ),
            ),
            Expanded(
              child: IgnorePointer(
                ignoring: widget.settings.useSystemBrightness,
                child: Opacity(
                  opacity: widget.settings.useSystemBrightness ? 0.35 : 1.0,
                  child: SliderTheme(
                    data: SliderThemeData(
                      trackHeight: 3,
                      thumbShape:
                          const RoundSliderThumbShape(enabledThumbRadius: 7),
                      activeTrackColor: CupertinoColors.activeGreen,
                      inactiveTrackColor:
                          CupertinoColors.systemGrey.withValues(alpha: 0.25),
                      thumbColor: CupertinoColors.activeGreen,
                    ),
                    child: Slider(
                      value: widget.settings.brightness.clamp(0.0, 1.0),
                      min: 0.0,
                      max: 1.0,
                      onChanged: (value) {
                        widget.onSettingsChanged(
                          widget.settings.copyWith(brightness: value),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            _buildStateChip(
              label: '跟随系统',
              active: widget.settings.useSystemBrightness,
              onTap: () {
                widget.onSettingsChanged(
                  widget.settings.copyWith(
                    useSystemBrightness: !widget.settings.useSystemBrightness,
                  ),
                );
              },
            ),
            const SizedBox(width: 8),
            _buildStateChip(
              label: '常亮',
              active: widget.settings.keepScreenOn,
              onTap: () {
                widget.onSettingsChanged(
                  widget.settings.copyWith(
                    keepScreenOn: !widget.settings.keepScreenOn,
                  ),
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            const SizedBox(
              width: 34,
              child: Text(
                '字体',
                style:
                    TextStyle(color: CupertinoColors.systemGrey, fontSize: 12),
              ),
            ),
            _buildRoundAction(
              label: 'A-',
              enabled: canDecrease,
              onTap: () {
                if (!canDecrease) return;
                widget.onSettingsChanged(
                  widget.settings.copyWith(fontSize: fontSize - 1),
                );
              },
            ),
            const SizedBox(width: 8),
            Text(
              fontSize.toInt().toString(),
              style: const TextStyle(
                color: CupertinoColors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 8),
            _buildRoundAction(
              label: 'A+',
              enabled: canIncrease,
              onTap: () {
                if (!canIncrease) return;
                widget.onSettingsChanged(
                  widget.settings.copyWith(fontSize: fontSize + 1),
                );
              },
            ),
            const Spacer(),
            _buildStateChip(
              label: '排版',
              active: false,
              onTap: widget.onShowTypography,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPageModeAndOtherRow() {
    final modes = [
      PageTurnMode.simulation,
      PageTurnMode.cover,
      PageTurnMode.scroll,
      PageTurnMode.slide,
      PageTurnMode.none,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '翻页',
          style: TextStyle(color: CupertinoColors.systemGrey, fontSize: 12),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final mode in modes)
              _buildStateChip(
                label: _pageModeLabel(mode),
                active: widget.settings.pageTurnMode == mode,
                onTap: () => widget.onSettingsChanged(
                  widget.settings.copyWith(pageTurnMode: mode),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        const Text(
          '其他',
          style: TextStyle(color: CupertinoColors.systemGrey, fontSize: 12),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildStateChip(
              label: '音量键翻页',
              active: widget.settings.volumeKeyPage,
              onTap: () {
                widget.onSettingsChanged(
                  widget.settings.copyWith(
                    volumeKeyPage: !widget.settings.volumeKeyPage,
                  ),
                );
              },
            ),
            _buildStateChip(
              label: '净化标题',
              active: widget.settings.cleanChapterTitle,
              onTap: () {
                widget.onSettingsChanged(
                  widget.settings.copyWith(
                    cleanChapterTitle: !widget.settings.cleanChapterTitle,
                  ),
                );
              },
            ),
            _buildStateChip(
              label: '自动阅读',
              active: widget.autoReadRunning,
              onTap: widget.onToggleAutoRead,
            ),
            _buildStateChip(
              label: '更多',
              active: false,
              onTap: widget.onOpenFullSettings,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBottomTabs() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _buildTabItem(
            0, CupertinoIcons.list_bullet, '目录', widget.onShowChapterList),
        _buildTabItem(
          1,
          CupertinoIcons.textformat_size,
          '字体',
          widget.onShowTypography,
        ),
        _buildTabItem(
          2,
          CupertinoIcons.circle_grid_3x3,
          '界面',
          widget.onShowTheme,
        ),
        _buildTabItem(
          3,
          CupertinoIcons.gear,
          '设置',
          widget.onShowPage,
        ),
      ],
    );
  }

  Widget _buildTabItem(
    int index,
    IconData icon,
    String label,
    VoidCallback onTap,
  ) {
    final isSelected = _selectedTab == index;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        setState(() => _selectedTab = index);
        onTap();
      },
      child: SizedBox(
        width: 70,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 22,
              color: isSelected
                  ? CupertinoColors.activeGreen
                  : CupertinoColors.white,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: isSelected
                    ? CupertinoColors.activeGreen
                    : CupertinoColors.white,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoundAction({
    required String label,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: enabled
              ? Colors.white.withValues(alpha: 0.14)
              : Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: enabled ? Colors.white24 : Colors.white10,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: enabled ? CupertinoColors.white : CupertinoColors.systemGrey,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildStateChip({
    required String label,
    required bool active,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: active
              ? CupertinoColors.activeGreen.withValues(alpha: 0.2)
              : Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: active ? CupertinoColors.activeGreen : Colors.white24,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? CupertinoColors.activeGreen : CupertinoColors.white,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  String _pageModeLabel(PageTurnMode mode) {
    switch (mode) {
      case PageTurnMode.simulation:
        return '仿真';
      case PageTurnMode.cover:
        return '覆盖';
      case PageTurnMode.scroll:
        return '上下';
      case PageTurnMode.slide:
        return '平移';
      case PageTurnMode.none:
        return '无';
      case PageTurnMode.simulation2:
        return '仿真2';
    }
  }
}
