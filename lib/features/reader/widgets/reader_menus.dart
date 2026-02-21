import 'package:flutter/cupertino.dart';
import '../../../app/theme/colors.dart';
import '../../../app/theme/design_tokens.dart';
import '../models/reading_settings.dart';

class ReaderTopMenu extends StatelessWidget {
  final String bookTitle;
  final String chapterTitle;
  final String? chapterUrl;
  final String? sourceName;
  final ReadingThemeColors currentTheme;
  final VoidCallback onOpenBookInfo;
  final VoidCallback onOpenChapterLink;
  final VoidCallback onToggleChapterLinkOpenMode;
  final VoidCallback onShowSourceActions;
  final VoidCallback onShowMoreMenu;
  final bool showSourceAction;
  final bool showChapterLink;
  final bool showTitleAddition;
  final bool readBarStyleFollowPage;

  const ReaderTopMenu({
    super.key,
    required this.bookTitle,
    required this.chapterTitle,
    this.chapterUrl,
    this.sourceName,
    required this.currentTheme,
    required this.onOpenBookInfo,
    required this.onOpenChapterLink,
    required this.onToggleChapterLinkOpenMode,
    required this.onShowSourceActions,
    required this.onShowMoreMenu,
    this.showSourceAction = true,
    this.showChapterLink = true,
    this.showTitleAddition = true,
    this.readBarStyleFollowPage = false,
  });

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final screenWidth = mediaQuery.size.width;
    final narrowScreen = screenWidth < 390;
    final horizontalPadding = narrowScreen ? 8.0 : 12.0;
    final source = sourceName?.trim() ?? '';
    final chapterLabel = chapterTitle.trim().isEmpty ? '暂无章节' : chapterTitle;
    final chapterUrlLabel = chapterUrl?.trim() ?? '';
    final sourceActionLabel = source.isEmpty ? '书源' : source;
    final isDarkTheme = currentTheme.isDark;
    final menuBgBase = readBarStyleFollowPage
        ? currentTheme.background
        : (isDarkTheme
            ? ReaderOverlayTokens.panelDark
            : const Color(0xFF1F2937));
    final menuSurfaceColor = menuBgBase.withValues(
      alpha: readBarStyleFollowPage ? (isDarkTheme ? 0.98 : 0.97) : 0.96,
    );
    final menuPrimaryText =
        readBarStyleFollowPage ? currentTheme.text : CupertinoColors.white;
    final menuSecondaryText = menuPrimaryText.withValues(alpha: 0.78);
    final menuTertiaryText = menuPrimaryText.withValues(alpha: 0.62);
    final controlBg = menuBgBase.withValues(
      alpha: readBarStyleFollowPage ? (isDarkTheme ? 0.22 : 0.14) : 0.26,
    );
    final controlBorder = menuPrimaryText.withValues(
      alpha: readBarStyleFollowPage ? (isDarkTheme ? 0.32 : 0.26) : 0.24,
    );

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.only(
          top: mediaQuery.padding.top + 7,
          left: horizontalPadding,
          right: horizontalPadding,
          bottom: 9,
        ),
        decoration: BoxDecoration(
          color: menuSurfaceColor,
          border: Border(
            bottom: BorderSide(
              color: menuPrimaryText.withValues(alpha: 0.18),
              width: 0.9,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: CupertinoColors.black
                  .withValues(alpha: isDarkTheme ? 0.22 : 0.08),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                _buildRoundIcon(
                  icon: CupertinoIcons.back,
                  onTap: () => Navigator.pop(context),
                  iconColor: menuPrimaryText,
                  backgroundColor: controlBg,
                  borderColor: controlBorder,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onOpenBookInfo,
                    child: Text(
                      bookTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: menuPrimaryText,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _buildRoundIcon(
                  icon: CupertinoIcons.ellipsis,
                  onTap: onShowMoreMenu,
                  iconColor: menuPrimaryText,
                  backgroundColor: controlBg,
                  borderColor: controlBorder,
                ),
              ],
            ),
            if (showTitleAddition) ...[
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final compactInfo =
                            narrowScreen || constraints.maxWidth < 340;
                        final showUrl = showTitleAddition &&
                            showChapterLink &&
                            chapterUrlLabel.isNotEmpty &&
                            !compactInfo;
                        final chapterFontSize = compactInfo ? 12.0 : 12.5;
                        final urlFontSize = compactInfo ? 10.5 : 11.0;
                        final sourceMaxWidth = compactInfo ? 96.0 : 120.0;

                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onTap: onOpenChapterLink,
                                    onLongPress: onToggleChapterLinkOpenMode,
                                    child: Text(
                                      chapterLabel,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: menuSecondaryText,
                                        fontSize: chapterFontSize,
                                      ),
                                    ),
                                  ),
                                  if (showUrl) ...[
                                    const SizedBox(height: 1),
                                    GestureDetector(
                                      behavior: HitTestBehavior.opaque,
                                      onTap: onOpenChapterLink,
                                      onLongPress: onToggleChapterLinkOpenMode,
                                      child: Text(
                                        chapterUrlLabel,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: menuTertiaryText,
                                          fontSize: urlFontSize,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            if (showSourceAction) ...[
                              const SizedBox(width: 8),
                              _buildSourceActionChip(
                                label: sourceActionLabel,
                                onTap: onShowSourceActions,
                                textColor: menuPrimaryText,
                                backgroundColor: controlBg,
                                borderColor: controlBorder,
                                maxWidth: sourceMaxWidth,
                              ),
                            ],
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRoundIcon({
    required IconData icon,
    required VoidCallback onTap,
    required Color iconColor,
    required Color backgroundColor,
    required Color borderColor,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: borderColor,
          ),
        ),
        child: Icon(
          icon,
          color: iconColor,
          size: 17,
        ),
      ),
    );
  }

  Widget _buildSourceActionChip({
    required String label,
    required VoidCallback onTap,
    required Color textColor,
    required Color backgroundColor,
    required Color borderColor,
    required double maxWidth,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        constraints: BoxConstraints(maxWidth: maxWidth),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: borderColor,
          ),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: textColor,
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class ReaderBottomMenu extends StatelessWidget {
  final int currentChapterIndex;
  final int totalChapters;
  final ReadingSettings settings;
  final ReadingThemeColors currentTheme;
  final ValueChanged<int> onChapterChanged;
  final ValueChanged<ReadingSettings> onSettingsChanged;
  final VoidCallback onShowChapterList;
  final VoidCallback onShowInterfaceSettings;
  final VoidCallback onShowMoreMenu;

  const ReaderBottomMenu({
    super.key,
    required this.currentChapterIndex,
    required this.totalChapters,
    required this.settings,
    required this.currentTheme,
    required this.onChapterChanged,
    required this.onSettingsChanged,
    required this.onShowChapterList,
    required this.onShowInterfaceSettings,
    required this.onShowMoreMenu,
  });

  @override
  Widget build(BuildContext context) {
    final maxChapterIndex = (totalChapters - 1).clamp(0, 9999);
    final canSlideChapter = maxChapterIndex > 0;
    // CupertinoSlider 在 min==max 时语义计算会除 0，需保证可渲染范围大于 0。
    final chapterSliderMax = canSlideChapter ? maxChapterIndex.toDouble() : 1.0;
    final chapterSliderValue =
        currentChapterIndex.toDouble().clamp(0.0, chapterSliderMax).toDouble();
    final safeBrightness =
        settings.brightness.isFinite ? settings.brightness : 1.0;

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).padding.bottom + 8,
          top: 16,
          left: 16,
          right: 16,
        ),
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C1E).withValues(alpha: 0.95),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 第一行：章节进度
            Row(
              children: [
                _buildIconBtn(
                    CupertinoIcons.arrow_left,
                    currentChapterIndex > 0
                        ? () => onChapterChanged(currentChapterIndex - 1)
                        : null),
                Expanded(
                  child: Column(
                    children: [
                      CupertinoSlider(
                        value: chapterSliderValue,
                        min: 0,
                        max: chapterSliderMax,
                        activeColor: AppDesignTokens.brandSecondary,
                        thumbColor: AppDesignTokens.brandSecondary,
                        onChanged: canSlideChapter
                            ? (value) {
                                // 实时更新章节（拖动时立即跳转）
                                onChapterChanged(
                                  value
                                      .round()
                                      .clamp(0, maxChapterIndex)
                                      .toInt(),
                                );
                              }
                            : null,
                      ),
                      Text(
                        '${currentChapterIndex + 1} / $totalChapters',
                        style: const TextStyle(
                            color: CupertinoColors.systemGrey, fontSize: 10),
                      ),
                    ],
                  ),
                ),
                _buildIconBtn(
                    CupertinoIcons.arrow_right,
                    currentChapterIndex < totalChapters - 1
                        ? () => onChapterChanged(currentChapterIndex + 1)
                        : null),
              ],
            ),
            const SizedBox(height: 16),

            // 第二行：亮度调节
            Row(
              children: [
                const Icon(CupertinoIcons.sun_min,
                    color: CupertinoColors.systemGrey, size: 20),
                Expanded(
                  child: CupertinoSlider(
                    value: safeBrightness.clamp(0.0, 1.0).toDouble(),
                    min: 0.0,
                    max: 1.0,
                    activeColor: AppDesignTokens.brandSecondary,
                    thumbColor: AppDesignTokens.brandSecondary,
                    onChanged: (value) {
                      onSettingsChanged(settings.copyWith(brightness: value));
                    },
                  ),
                ),
                const Icon(CupertinoIcons.sun_max,
                    color: CupertinoColors.systemGrey, size: 20),
                const SizedBox(width: 16),
                GestureDetector(
                  onTap: () {
                    onSettingsChanged(settings.copyWith(
                        useSystemBrightness: !settings.useSystemBrightness));
                  },
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: settings.useSystemBrightness
                          ? AppDesignTokens.brandSecondary
                          : CupertinoColors.systemGrey.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      '跟随系统',
                      style: TextStyle(
                        color: settings.useSystemBrightness
                            ? CupertinoColors.white
                            : CupertinoColors.systemGrey,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 第三行：底部功能栏
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildMenuBtn(
                    CupertinoIcons.list_bullet, '目录', onShowChapterList),
                _buildMenuBtn(CupertinoIcons.slider_horizontal_3, '界面',
                    onShowInterfaceSettings),
                _buildMenuBtn(
                    currentTheme.isDark
                        ? CupertinoIcons.moon_fill
                        : CupertinoIcons.sun_max,
                    currentTheme.isDark ? '夜间' : '日间', () {
                  final isDark = currentTheme.isDark;
                  final targetIndex = AppColors.readingThemes
                      .indexWhere((t) => isDark ? !t.isDark : t.isDark);
                  if (targetIndex != -1) {
                    onSettingsChanged(
                        settings.copyWith(themeIndex: targetIndex));
                  }
                }),
                // 翻页模式切换（点击弹窗选择）
                Builder(
                  builder: (context) => _buildMenuBtn(
                      _getPageTurnModeIcon(settings.pageTurnMode),
                      settings.pageTurnMode.name, () {
                    _showPageTurnModeSheet(
                        context, settings, onSettingsChanged);
                  }),
                ),
                _buildMenuBtn(
                    CupertinoIcons.ellipsis_circle, '更多', onShowMoreMenu),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIconBtn(IconData icon, VoidCallback? onTap) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onTap,
      child: Icon(icon,
          color: onTap != null
              ? AppDesignTokens.brandSecondary
              : CupertinoColors.systemGrey,
          size: 24),
    );
  }

  Widget _buildMenuBtn(IconData icon, String label, VoidCallback onTap) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: Size.zero,
      onPressed: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: CupertinoColors.white, size: 22),
            const SizedBox(height: 4),
            Text(
              label,
              style:
                  const TextStyle(color: CupertinoColors.white, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }

  /// 根据翻页模式返回对应图标
  IconData _getPageTurnModeIcon(PageTurnMode mode) {
    switch (mode) {
      case PageTurnMode.slide:
        return CupertinoIcons.arrow_left_right;
      case PageTurnMode.simulation:
      case PageTurnMode.simulation2:
        return CupertinoIcons.book;
      case PageTurnMode.cover:
        return CupertinoIcons.square_stack;
      case PageTurnMode.none:
        return CupertinoIcons.stop;
      case PageTurnMode.scroll:
        return CupertinoIcons.arrow_up_arrow_down;
    }
  }

  /// 显示翻页模式选择弹窗
  void _showPageTurnModeSheet(
    BuildContext context,
    ReadingSettings settings,
    ValueChanged<ReadingSettings> onSettingsChanged,
  ) {
    final rootContext = context;
    showCupertinoModalPopup(
      context: rootContext,
      builder: (sheetContext) => CupertinoActionSheet(
        title: const Text('选择翻页模式'),
        actions:
            PageTurnModeUi.values(current: settings.pageTurnMode).map((mode) {
          final isSelected = mode == settings.pageTurnMode;
          return CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(sheetContext);
              if (PageTurnModeUi.isHidden(mode)) {
                _showMessage(rootContext, '仿真2模式已隐藏');
                return;
              }
              onSettingsChanged(settings.copyWith(pageTurnMode: mode));
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _getPageTurnModeIcon(mode),
                  color: isSelected
                      ? AppDesignTokens.brandSecondary
                      : PageTurnModeUi.isHidden(mode)
                          ? CupertinoColors.inactiveGray
                          : CupertinoColors.label,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  PageTurnModeUi.isHidden(mode)
                      ? '${mode.name}（隐藏）'
                      : mode.name,
                  style: TextStyle(
                    color: isSelected
                        ? AppDesignTokens.brandSecondary
                        : PageTurnModeUi.isHidden(mode)
                            ? CupertinoColors.inactiveGray
                            : CupertinoColors.label,
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                if (isSelected) ...[
                  const SizedBox(width: 8),
                  const Icon(
                    CupertinoIcons.checkmark,
                    color: AppDesignTokens.brandSecondary,
                    size: 18,
                  ),
                ],
              ],
            ),
          );
        }).toList(),
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
      ),
    );
  }

  void _showMessage(BuildContext context, String message) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('提示'),
        content: Text('\n$message'),
        actions: [
          CupertinoDialogAction(
            child: const Text('好'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }
}
