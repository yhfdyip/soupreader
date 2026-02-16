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
  });

  @override
  State<ReaderBottomMenuNew> createState() => _ReaderBottomMenuNewState();
}

enum _ReaderMenuTab {
  catalog,
  readAloud,
  interface,
  settings,
}

class _ReaderBottomMenuNewState extends State<ReaderBottomMenuNew> {
  _ReaderMenuTab? _selectedTab;
  bool _isDragging = false;
  double _dragValue = 0;

  bool get _isDarkMode => widget.currentTheme.isDark;

  double _safeFinite(double value, {double fallback = 0.0}) {
    return value.isFinite ? value : fallback;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = ShadTheme.of(context).colorScheme;
    final panelBg = _isDarkMode
        ? scheme.popover.withValues(alpha: 0.98)
        : scheme.background.withValues(alpha: 0.97);
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        decoration: BoxDecoration(
          color: panelBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
          boxShadow: [
            BoxShadow(
              color: _isDarkMode
                  ? const Color(0xFF000000).withValues(alpha: 0.35)
                  : const Color(0xFF000000).withValues(alpha: 0.12),
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
                _buildGrabber(scheme),
                _buildSectionCard(
                  child: _buildChapterSlider(scheme),
                ),
                if (widget.settings.showBrightnessView) ...[
                  const SizedBox(height: 8),
                  _buildSectionCard(
                    child: _buildBrightnessRow(scheme),
                  ),
                ],
                const SizedBox(height: 10),
                _buildBottomTabs(scheme),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGrabber(ShadColorScheme scheme) {
    return Container(
      margin: const EdgeInsets.only(top: 2, bottom: 8),
      width: 36,
      height: 4,
      decoration: BoxDecoration(
        color: scheme.mutedForeground.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Widget _buildSectionCard({required Widget child}) {
    return ShadCard(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      child: child,
    );
  }

  Widget _buildChapterSlider(ShadColorScheme scheme) {
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
    final leftLabel = chapterMode
        ? '章节跳转'
        : '第${widget.currentChapterIndex + 1}章 / ${widget.totalChapters}章';
    final rightLabel = chapterMode
        ? '${widget.currentChapterIndex + 1}/${widget.totalChapters}章'
        : '${widget.currentPageIndex + 1}/${widget.totalPages}页';
    final accent = _isDarkMode
        ? AppDesignTokens.brandSecondary
        : AppDesignTokens.brandPrimary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              leftLabel,
              style: TextStyle(
                color: scheme.foreground,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            Text(
              rightLabel,
              style: TextStyle(
                color: scheme.mutedForeground,
                fontSize: 12,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            ShadButton.ghost(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              onPressed: widget.currentChapterIndex > 0
                  ? () =>
                      widget.onChapterChanged(widget.currentChapterIndex - 1)
                  : null,
              child: Text(
                '上一章',
                style: TextStyle(
                  fontSize: 12,
                  color: widget.currentChapterIndex > 0
                      ? accent
                      : scheme.mutedForeground,
                ),
              ),
            ),
            Expanded(
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
            ShadButton.ghost(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              onPressed: widget.currentChapterIndex < widget.totalChapters - 1
                  ? () =>
                      widget.onChapterChanged(widget.currentChapterIndex + 1)
                  : null,
              child: Text(
                '下一章',
                style: TextStyle(
                  fontSize: 12,
                  color: widget.currentChapterIndex < widget.totalChapters - 1
                      ? accent
                      : scheme.mutedForeground,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBrightnessRow(ShadColorScheme scheme) {
    final accent = _isDarkMode
        ? AppDesignTokens.brandSecondary
        : AppDesignTokens.brandPrimary;

    return Row(
      children: [
        SizedBox(
          width: 34,
          child: Text(
            '亮度',
            style: TextStyle(color: scheme.mutedForeground, fontSize: 12),
          ),
        ),
        Expanded(
          child: IgnorePointer(
            ignoring: widget.settings.useSystemBrightness,
            child: Opacity(
              opacity: widget.settings.useSystemBrightness ? 0.35 : 1.0,
              child: CupertinoSlider(
                value: _safeFinite(
                  widget.settings.brightness,
                  fallback: 1.0,
                ).clamp(0.0, 1.0).toDouble(),
                min: 0.0,
                max: 1.0,
                activeColor: accent,
                thumbColor: accent,
                onChanged: (value) {
                  widget.onSettingsChanged(
                    widget.settings.copyWith(brightness: value),
                  );
                },
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        _buildStateChip(
          scheme: scheme,
          label: '跟随系统',
          active: widget.settings.useSystemBrightness,
          accent: accent,
          onTap: () {
            widget.onSettingsChanged(
              widget.settings.copyWith(
                useSystemBrightness: !widget.settings.useSystemBrightness,
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildBottomTabs(ShadColorScheme scheme) {
    final accent = _isDarkMode
        ? AppDesignTokens.brandSecondary
        : AppDesignTokens.brandPrimary;
    return Row(
      children: [
        _buildTabItem(
          scheme: scheme,
          tab: _ReaderMenuTab.catalog,
          icon: CupertinoIcons.list_bullet,
          label: '目录',
          onTap: widget.onShowChapterList,
          accent: accent,
        ),
        _buildTabItem(
          scheme: scheme,
          tab: _ReaderMenuTab.readAloud,
          icon: CupertinoIcons.speaker_2_fill,
          label: '朗读',
          onTap: widget.onShowReadAloud,
          accent: accent,
        ),
        _buildTabItem(
          scheme: scheme,
          tab: _ReaderMenuTab.interface,
          icon: CupertinoIcons.circle_grid_3x3,
          label: '界面',
          onTap: widget.onShowInterfaceSettings,
          accent: accent,
        ),
        _buildTabItem(
          scheme: scheme,
          tab: _ReaderMenuTab.settings,
          icon: CupertinoIcons.gear,
          label: '设置',
          onTap: widget.onShowBehaviorSettings,
          accent: accent,
        ),
      ],
    );
  }

  Widget _buildTabItem({
    required ShadColorScheme scheme,
    required _ReaderMenuTab tab,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required Color accent,
  }) {
    final isSelected = _selectedTab == tab;
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? accent.withValues(alpha: _isDarkMode ? 0.2 : 0.12)
              : const Color(0x00000000),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? accent.withValues(alpha: 0.8)
                : scheme.border.withValues(alpha: 0.7),
          ),
        ),
        child: ShadButton.ghost(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          onPressed: () {
            setState(() => _selectedTab = tab);
            onTap();
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 18,
                color: isSelected ? accent : scheme.foreground,
              ),
              const SizedBox(height: 3),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: isSelected ? accent : scheme.mutedForeground,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStateChip({
    required ShadColorScheme scheme,
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
              : scheme.muted.withValues(alpha: _isDarkMode ? 0.25 : 0.35),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: active
                ? accent
                : scheme.border.withValues(alpha: _isDarkMode ? 0.9 : 0.75),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? accent : scheme.foreground,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
