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
import '../../../app/theme/design_tokens.dart';
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

  bool get _isDarkMode => widget.currentTheme.isDark;

  Color get _accentColor => _isDarkMode
      ? AppDesignTokens.brandSecondary
      : AppDesignTokens.brandPrimary;

  Color get _panelColor => _isDarkMode
      ? const Color(0xFF1C1C1E).withValues(alpha: 0.98)
      : Colors.white.withValues(alpha: 0.94);

  Color get _textStrong =>
      _isDarkMode ? CupertinoColors.white : const Color(0xFF1E293B);

  Color get _textMuted =>
      _isDarkMode ? CupertinoColors.systemGrey : const Color(0xFF64748B);

  Color get _cardColor => _isDarkMode
      ? Colors.white.withValues(alpha: 0.06)
      : const Color(0xFFF8FAFC);

  Color get _cardBorderColor =>
      _isDarkMode ? Colors.white12 : const Color(0xFFE2E8F0);

  Color get _chipBgColor => _isDarkMode
      ? Colors.white.withValues(alpha: 0.08)
      : const Color(0xFFF1F5F9);

  Color get _chipBorderColor =>
      _isDarkMode ? Colors.white24 : const Color(0xFFE2E8F0);

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        decoration: BoxDecoration(
          color: _panelColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
          boxShadow: [
            BoxShadow(
              color: _isDarkMode
                  ? Colors.black.withValues(alpha: 0.35)
                  : Colors.black.withValues(alpha: 0.12),
              blurRadius: _isDarkMode ? 22 : 16,
              offset: const Offset(0, -4),
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
        color: _textMuted.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Widget _buildSectionCard(Widget child) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _cardBorderColor),
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
              style: TextStyle(
                color: _textStrong,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            Text(
              pageLabel,
              style: TextStyle(
                color: _textMuted,
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
                      ? _accentColor
                      : _textMuted,
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
                  activeTrackColor: _accentColor,
                  inactiveTrackColor: _textMuted.withValues(alpha: 0.28),
                  thumbColor:
                      _isDarkMode ? CupertinoColors.white : _accentColor,
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
                      ? _accentColor
                      : _textMuted,
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
            SizedBox(
              width: 34,
              child: Text(
                '亮度',
                style: TextStyle(color: _textMuted, fontSize: 12),
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
                      activeTrackColor: _accentColor,
                      inactiveTrackColor: _textMuted.withValues(alpha: 0.25),
                      thumbColor: _accentColor,
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
              accent: _accentColor,
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
              accent: _accentColor,
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
            SizedBox(
              width: 34,
              child: Text(
                '字体',
                style: TextStyle(color: _textMuted, fontSize: 12),
              ),
            ),
            _buildRoundAction(
              label: 'A-',
              enabled: canDecrease,
              accent: _accentColor,
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
              style: TextStyle(
                color: _textStrong,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 8),
            _buildRoundAction(
              label: 'A+',
              enabled: canIncrease,
              accent: _accentColor,
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
              accent: _accentColor,
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
        Text(
          '翻页',
          style: TextStyle(color: _textMuted, fontSize: 12),
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
                accent: _accentColor,
                onTap: () => widget.onSettingsChanged(
                  widget.settings.copyWith(pageTurnMode: mode),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          '其他',
          style: TextStyle(color: _textMuted, fontSize: 12),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildStateChip(
              label: '音量键翻页',
              active: widget.settings.volumeKeyPage,
              accent: _accentColor,
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
              accent: _accentColor,
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
              accent: _accentColor,
              onTap: widget.onToggleAutoRead,
            ),
            _buildStateChip(
              label: '更多',
              active: false,
              accent: _accentColor,
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
          0,
          CupertinoIcons.list_bullet,
          '目录',
          widget.onShowChapterList,
          accent: _accentColor,
        ),
        _buildTabItem(
          1,
          CupertinoIcons.textformat_size,
          '字体',
          widget.onShowTypography,
          accent: _accentColor,
        ),
        _buildTabItem(
          2,
          CupertinoIcons.circle_grid_3x3,
          '界面',
          widget.onShowTheme,
          accent: _accentColor,
        ),
        _buildTabItem(
          3,
          CupertinoIcons.gear,
          '设置',
          widget.onShowPage,
          accent: _accentColor,
        ),
      ],
    );
  }

  Widget _buildTabItem(
    int index,
    IconData icon,
    String label,
    VoidCallback onTap, {
    required Color accent,
  }) {
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
              color: isSelected ? accent : _textStrong,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: isSelected ? accent : _textMuted,
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
    required Color accent,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: enabled
              ? (_isDarkMode
                  ? Colors.white.withValues(alpha: 0.14)
                  : const Color(0xFFE2E8F0))
              : (_isDarkMode
                  ? Colors.white.withValues(alpha: 0.06)
                  : const Color(0xFFF1F5F9)),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: enabled
                ? (_isDarkMode ? Colors.white24 : const Color(0xFFCBD5E1))
                : (_isDarkMode ? Colors.white10 : const Color(0xFFE2E8F0)),
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: enabled
                ? (_isDarkMode ? CupertinoColors.white : accent)
                : CupertinoColors.systemGrey,
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
    required Color accent,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: active
              ? accent.withValues(alpha: _isDarkMode ? 0.2 : 0.14)
              : _chipBgColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: active ? accent : _chipBorderColor,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active
                ? accent
                : (_isDarkMode
                    ? CupertinoColors.white
                    : const Color(0xFF334155)),
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
