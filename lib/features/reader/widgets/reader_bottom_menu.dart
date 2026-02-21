import 'package:flutter/cupertino.dart';

import '../../../app/theme/colors.dart';
import '../../../app/theme/design_tokens.dart';
import '../models/reading_settings.dart';

/// 阅读器底部菜单：操作路径对齐 legado（目录/朗读/界面/设置）。
class ReaderBottomMenuNew extends StatefulWidget {
  final int currentChapterIndex;
  final int totalChapters;
  final int currentPageIndex;
  final int totalPages;
  final ReadingSettings settings;
  final ReadingThemeColors currentTheme;
  final ValueChanged<int> onChapterChanged;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<int> onSeekChapterProgress;
  final ValueChanged<ReadingSettings> onSettingsChanged;
  final VoidCallback onShowChapterList;
  final VoidCallback onShowReadAloud;
  final VoidCallback? onReadAloudLongPress;
  final VoidCallback onShowInterfaceSettings;
  final VoidCallback onShowBehaviorSettings;
  final bool readBarStyleFollowPage;
  final bool readAloudRunning;
  final bool readAloudPaused;

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
    required this.onSeekChapterProgress,
    required this.onSettingsChanged,
    required this.onShowChapterList,
    required this.onShowReadAloud,
    this.onReadAloudLongPress,
    required this.onShowInterfaceSettings,
    required this.onShowBehaviorSettings,
    this.readBarStyleFollowPage = false,
    this.readAloudRunning = false,
    this.readAloudPaused = false,
  });

  @override
  State<ReaderBottomMenuNew> createState() => _ReaderBottomMenuNewState();
}

class _ReaderBottomMenuNewState extends State<ReaderBottomMenuNew> {
  static const Key _brightnessPanelKey = Key('reader_brightness_panel');
  static const Key _brightnessAutoToggleKey = Key('reader_brightness_auto');
  static const Key _brightnessPositionToggleKey = Key('reader_brightness_pos');
  static const double _brightnessPanelTopOffset = 78.0;
  static const double _brightnessPanelTopOffsetWithTitleAddition = 94.0;
  static const double _brightnessPanelBottomOffset = 98.0;
  static const double _brightnessPanelWidth = 42.0;
  static const double _brightnessPanelButtonHeight = 40.0;
  static const double _brightnessPanelMinHeight = 180.0;
  static const double _brightnessPanelMaxHeight = 360.0;
  static const double _brightnessSliderMaxLength = 320.0;

  bool _isDragging = false;
  double _dragValue = 0;

  bool get _isDarkMode => widget.currentTheme.isDark;

  double _safeFinite(double value, {double fallback = 0.0}) {
    return value.isFinite ? value : fallback;
  }

  @override
  Widget build(BuildContext context) {
    final followPage = widget.readBarStyleFollowPage;
    final panelBase = followPage
        ? widget.currentTheme.background
        : (_isDarkMode
            ? ReaderOverlayTokens.panelDark
            : ReaderOverlayTokens.panelLight);
    final panelBg = panelBase.withValues(
      alpha: followPage ? (_isDarkMode ? 0.98 : 0.97) : 1.0,
    );
    final panelForeground = followPage
        ? widget.currentTheme.text
        : (_isDarkMode
            ? ReaderOverlayTokens.textStrongDark
            : ReaderOverlayTokens.textStrongLight);
    final panelMutedForeground = followPage
        ? widget.currentTheme.text.withValues(alpha: _isDarkMode ? 0.66 : 0.62)
        : (_isDarkMode
            ? ReaderOverlayTokens.textNormalDark
            : ReaderOverlayTokens.textNormalLight);
    final panelBorder = followPage
        ? widget.currentTheme.text.withValues(alpha: _isDarkMode ? 0.30 : 0.24)
        : (_isDarkMode
            ? ReaderOverlayTokens.borderDark
            : ReaderOverlayTokens.borderLight);
    final panelShadow = followPage
        ? widget.currentTheme.text.withValues(alpha: _isDarkMode ? 0.12 : 0.1)
        : CupertinoColors.black.withValues(alpha: _isDarkMode ? 0.3 : 0.11);
    final mediaQuery = MediaQuery.of(context);
    final bottomPadding = mediaQuery.padding.bottom;
    final brightnessTopOffset = widget.settings.showReadTitleAddition
        ? _brightnessPanelTopOffsetWithTitleAddition
        : _brightnessPanelTopOffset;

    return Positioned.fill(
      child: Stack(
        children: [
          if (widget.settings.showBrightnessView)
            Positioned(
              top: mediaQuery.padding.top + brightnessTopOffset,
              bottom: bottomPadding + _brightnessPanelBottomOffset,
              left: widget.settings.brightnessViewOnRight ? null : 16,
              right: widget.settings.brightnessViewOnRight ? 16 : null,
              child: _buildBrightnessPanel(
                panelBg,
                foreground: panelForeground,
                mutedForeground: panelMutedForeground,
                borderColor: panelBorder,
              ),
            ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: Container(
                decoration: BoxDecoration(
                  color: panelBg,
                  border: Border(
                    top: BorderSide(color: panelBorder),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: panelShadow,
                      blurRadius: 14,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                padding: EdgeInsets.only(bottom: bottomPadding > 0 ? 4 : 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildChapterSlider(
                      foreground: panelForeground,
                      mutedForeground: panelMutedForeground,
                    ),
                    Container(
                      height: 0.9,
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      color: panelBorder.withValues(
                          alpha: _isDarkMode ? 0.78 : 0.62),
                    ),
                    _buildBottomTabs(foreground: panelForeground),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChapterSlider({
    required Color foreground,
    required Color mutedForeground,
  }) {
    final chapterMode =
        widget.settings.progressBarBehavior == ProgressBarBehavior.chapter;
    final maxChapter = (widget.totalChapters - 1).clamp(0, 9999);
    final maxPage = (widget.totalPages - 1).clamp(0, 9999);
    final canSlide = chapterMode ? maxChapter > 0 : maxPage > 0;
    // CupertinoSlider 在 min==max 时语义层会触发 0 除，导致 NaN 崩溃。
    final sliderMax = canSlide
        ? (chapterMode ? maxChapter.toDouble() : maxPage.toDouble())
        : 1.0;
    final rawSliderValue = _isDragging
        ? _safeFinite(_dragValue)
        : _safeFinite(chapterMode
            ? widget.currentChapterIndex.toDouble()
            : widget.currentPageIndex.toDouble());
    final sliderValue = rawSliderValue.clamp(0.0, sliderMax).toDouble();
    final accent = _isDarkMode
        ? AppDesignTokens.brandSecondary
        : AppDesignTokens.brandPrimary;
    final canPrev = widget.currentChapterIndex > 0;
    final canNext = widget.currentChapterIndex < widget.totalChapters - 1;

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 6),
      child: Row(
        children: [
          _buildChapterTextButton(
            label: '上一章',
            enabled: canPrev,
            color: canPrev ? foreground : mutedForeground,
            onTap: canPrev
                ? () => widget.onChapterChanged(widget.currentChapterIndex - 1)
                : null,
          ),
          Expanded(
            child: SizedBox(
              height: 25,
              child: CupertinoSlider(
                value: sliderValue,
                min: 0,
                max: sliderMax,
                activeColor: accent,
                thumbColor: _isDarkMode ? CupertinoColors.white : accent,
                onChanged: canSlide
                    ? (value) {
                        setState(() {
                          _isDragging = true;
                          _dragValue = value;
                        });
                      }
                    : null,
                onChangeEnd: canSlide
                    ? (value) {
                        setState(() => _isDragging = false);
                        if (chapterMode) {
                          final targetChapter =
                              value.round().clamp(0, maxChapter).toInt();
                          widget.onSeekChapterProgress(targetChapter);
                        } else {
                          final targetPage =
                              value.round().clamp(0, maxPage).toInt();
                          widget.onPageChanged(targetPage);
                        }
                      }
                    : null,
              ),
            ),
          ),
          _buildChapterTextButton(
            label: '下一章',
            enabled: canNext,
            color: canNext ? foreground : mutedForeground,
            onTap: canNext
                ? () => widget.onChapterChanged(widget.currentChapterIndex + 1)
                : null,
          ),
        ],
      ),
    );
  }

  Widget _buildChapterTextButton({
    required String label,
    required bool enabled,
    required Color color,
    required VoidCallback? onTap,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13.5,
            color: color,
            fontWeight: enabled ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }

  Widget _buildBrightnessPanel(
    Color panelBg, {
    required Color foreground,
    required Color mutedForeground,
    required Color borderColor,
  }) {
    final accent = _isDarkMode
        ? AppDesignTokens.brandSecondary
        : AppDesignTokens.brandPrimary;
    final autoBrightness = widget.settings.useSystemBrightness;
    final iconColor = autoBrightness ? accent : mutedForeground;
    // legado 亮度栏语义保持不变：顶部自动亮度 + 中段滑杆 + 底部左右切换。
    // 仅限制面板可见高度，避免长屏设备出现过长白条。
    final panelOverlay = _isDarkMode
        ? CupertinoColors.white.withValues(alpha: 0.02)
        : CupertinoColors.black.withValues(alpha: 0.08);
    final panelColor = Color.alphaBlend(
      panelOverlay,
      panelBg.withValues(alpha: _isDarkMode ? 0.54 : 0.42),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final rawAvailableHeight = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : _brightnessPanelMaxHeight;
        final availableHeight = rawAvailableHeight
            .clamp(
              0.0,
              double.infinity,
            )
            .toDouble();
        final panelHeight = availableHeight < _brightnessPanelMinHeight
            ? availableHeight
            : availableHeight
                .clamp(
                  _brightnessPanelMinHeight,
                  _brightnessPanelMaxHeight,
                )
                .toDouble();
        final sliderRegionHeight =
            (panelHeight - _brightnessPanelButtonHeight * 2)
                .clamp(0.0, _brightnessSliderMaxLength)
                .toDouble();

        return Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            key: _brightnessPanelKey,
            width: _brightnessPanelWidth,
            height: panelHeight,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: panelColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: borderColor),
              ),
              child: Column(
                children: [
                  GestureDetector(
                    key: _brightnessAutoToggleKey,
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      widget.onSettingsChanged(
                        widget.settings.copyWith(
                          useSystemBrightness:
                              !widget.settings.useSystemBrightness,
                        ),
                      );
                    },
                    child: SizedBox(
                      width: _brightnessPanelWidth,
                      height: _brightnessPanelButtonHeight,
                      child: Icon(
                        CupertinoIcons.brightness,
                        size: 22,
                        color: iconColor,
                      ),
                    ),
                  ),
                  SizedBox(
                    height: sliderRegionHeight,
                    child: IgnorePointer(
                      ignoring: autoBrightness,
                      child: Opacity(
                        opacity: autoBrightness ? 0.35 : 1.0,
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final sliderLength = (constraints.maxHeight - 6)
                                .clamp(24.0, _brightnessSliderMaxLength)
                                .toDouble();
                            return Center(
                              child: SizedBox(
                                width: sliderLength,
                                child: RotatedBox(
                                  quarterTurns: 3,
                                  child: CupertinoSlider(
                                    value: _safeFinite(
                                      widget.settings.brightness,
                                      fallback: 1.0,
                                    ).clamp(0.0, 1.0).toDouble(),
                                    min: 0.0,
                                    max: 1.0,
                                    activeColor: accent,
                                    thumbColor: _isDarkMode
                                        ? CupertinoColors.white
                                        : accent,
                                    onChanged: (value) {
                                      widget.onSettingsChanged(
                                        widget.settings
                                            .copyWith(brightness: value),
                                      );
                                    },
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                  GestureDetector(
                    key: _brightnessPositionToggleKey,
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      widget.onSettingsChanged(
                        widget.settings.copyWith(
                          brightnessViewOnRight:
                              !widget.settings.brightnessViewOnRight,
                        ),
                      );
                    },
                    child: SizedBox(
                      width: _brightnessPanelWidth,
                      height: _brightnessPanelButtonHeight,
                      child: Icon(
                        CupertinoIcons.arrow_left_right,
                        size: 20,
                        color: foreground,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBottomTabs({required Color foreground}) {
    final readAloudActive = widget.readAloudRunning;
    final readAloudIcon = widget.readAloudPaused
        ? CupertinoIcons.pause_circle
        : CupertinoIcons.speaker_2_fill;
    final accent = _isDarkMode
        ? AppDesignTokens.brandSecondary
        : AppDesignTokens.brandPrimary;

    return Padding(
      padding: const EdgeInsets.only(bottom: 0, top: 0),
      child: Row(
        children: [
          const Spacer(),
          _buildTabItem(
            foreground: foreground,
            icon: CupertinoIcons.list_bullet,
            label: '目录',
            onTap: widget.onShowChapterList,
          ),
          const Spacer(flex: 2),
          _buildTabItem(
            foreground: foreground,
            icon: readAloudIcon,
            label: '朗读',
            onTap: widget.onShowReadAloud,
            onLongPress: widget.onReadAloudLongPress,
            active: readAloudActive,
            activeColor: accent,
          ),
          const Spacer(flex: 2),
          _buildTabItem(
            foreground: foreground,
            icon: CupertinoIcons.circle_grid_3x3,
            label: '界面',
            onTap: widget.onShowInterfaceSettings,
          ),
          const Spacer(flex: 2),
          _buildTabItem(
            foreground: foreground,
            icon: CupertinoIcons.gear,
            label: '设置',
            onTap: widget.onShowBehaviorSettings,
          ),
          const Spacer(),
        ],
      ),
    );
  }

  Widget _buildTabItem({
    required Color foreground,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    VoidCallback? onLongPress,
    bool active = false,
    Color? activeColor,
  }) {
    final contentColor = active ? (activeColor ?? foreground) : foreground;
    return SizedBox(
      width: 60,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 7),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 20,
                child: Center(
                  child: Icon(
                    icon,
                    size: 20,
                    color: contentColor,
                  ),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: contentColor,
                  fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
