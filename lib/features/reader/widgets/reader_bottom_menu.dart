import 'package:flutter/cupertino.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

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
  final VoidCallback onShowInterfaceSettings;
  final VoidCallback onShowBehaviorSettings;
  final bool readBarStyleFollowPage;

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
    required this.onShowInterfaceSettings,
    required this.onShowBehaviorSettings,
    this.readBarStyleFollowPage = false,
  });

  @override
  State<ReaderBottomMenuNew> createState() => _ReaderBottomMenuNewState();
}

class _ReaderBottomMenuNewState extends State<ReaderBottomMenuNew> {
  static const Key _brightnessPanelKey = Key('reader_brightness_panel');
  static const Key _brightnessAutoToggleKey = Key('reader_brightness_auto');
  static const Key _brightnessPositionToggleKey = Key('reader_brightness_pos');
  static const double _brightnessPanelTopOffset = 78.0;
  static const double _brightnessPanelBottomOffset = 98.0;

  bool _isDragging = false;
  double _dragValue = 0;

  bool get _isDarkMode => widget.currentTheme.isDark;

  double _safeFinite(double value, {double fallback = 0.0}) {
    return value.isFinite ? value : fallback;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = ShadTheme.of(context).colorScheme;
    final followPage = widget.readBarStyleFollowPage;
    final panelBg = followPage
        ? widget.currentTheme.background.withValues(alpha: 0.96)
        : (_isDarkMode
            ? scheme.popover.withValues(alpha: 0.98)
            : scheme.background.withValues(alpha: 0.97));
    final panelForeground =
        followPage ? widget.currentTheme.text : scheme.foreground;
    final panelMutedForeground = followPage
        ? widget.currentTheme.text.withValues(alpha: 0.62)
        : scheme.mutedForeground;
    final panelBorder = followPage
        ? widget.currentTheme.text.withValues(alpha: 0.22)
        : scheme.border.withValues(alpha: _isDarkMode ? 0.72 : 0.58);
    final mediaQuery = MediaQuery.of(context);
    final bottomPadding = mediaQuery.padding.bottom;

    return Positioned.fill(
      child: Stack(
        children: [
          if (widget.settings.showBrightnessView)
            Positioned(
              top: mediaQuery.padding.top + _brightnessPanelTopOffset,
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
                ),
                padding: EdgeInsets.only(bottom: bottomPadding > 0 ? 4 : 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildChapterSlider(
                      foreground: panelForeground,
                      mutedForeground: panelMutedForeground,
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
      padding: const EdgeInsets.fromLTRB(20, 5, 20, 5),
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
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: color,
            fontWeight: enabled ? FontWeight.w500 : FontWeight.w400,
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
    final panelColor = panelBg.withValues(alpha: _isDarkMode ? 0.48 : 0.66);

    return Align(
      alignment: Alignment.topCenter,
      child: Container(
        key: _brightnessPanelKey,
        width: 40,
        decoration: BoxDecoration(
          color: panelColor,
          borderRadius: BorderRadius.circular(5),
          border: Border.all(
            color: borderColor,
          ),
        ),
        child: Column(
          children: [
            GestureDetector(
              key: _brightnessAutoToggleKey,
              behavior: HitTestBehavior.opaque,
              onTap: () {
                widget.onSettingsChanged(
                  widget.settings.copyWith(
                    useSystemBrightness: !widget.settings.useSystemBrightness,
                  ),
                );
              },
              child: SizedBox(
                width: 40,
                height: 40,
                child: Icon(
                  CupertinoIcons.brightness,
                  size: 22,
                  color: iconColor,
                ),
              ),
            ),
            Expanded(
              child: IgnorePointer(
                ignoring: autoBrightness,
                child: Opacity(
                  opacity: autoBrightness ? 0.35 : 1.0,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final sliderLength = (constraints.maxHeight - 6)
                          .clamp(64.0, 320.0)
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
                              thumbColor:
                                  _isDarkMode ? CupertinoColors.white : accent,
                              onChanged: (value) {
                                widget.onSettingsChanged(
                                  widget.settings.copyWith(brightness: value),
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
                width: 40,
                height: 40,
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
    );
  }

  Widget _buildBottomTabs({required Color foreground}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
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
            icon: CupertinoIcons.speaker_2_fill,
            label: '朗读',
            onTap: widget.onShowReadAloud,
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
  }) {
    return SizedBox(
      width: 60,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
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
                    color: foreground,
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
                  color: foreground,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
