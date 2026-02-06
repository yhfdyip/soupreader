import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../app/theme/colors.dart';
import '../models/reading_settings.dart';

class ReaderTopMenu extends StatelessWidget {
  final String bookTitle;
  final String chapterTitle;
  final VoidCallback onShowChapterList;

  const ReaderTopMenu({
    super.key,
    required this.bookTitle,
    required this.chapterTitle,
    required this.onShowChapterList,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C1E).withValues(alpha: 0.95),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 顶部导航栏
            SizedBox(
              height: 44,
              child: Row(
                children: [
                  // 返回按钮
                  CupertinoButton(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    onPressed: () => Navigator.pop(context),
                    child: const Icon(CupertinoIcons.back,
                        color: CupertinoColors.white),
                  ),
                  // 书名
                  Expanded(
                    child: Text(
                      bookTitle,
                      style: const TextStyle(
                        color: CupertinoColors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  // 目录按钮
                  CupertinoButton(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    onPressed: onShowChapterList,
                    child: const Icon(CupertinoIcons.list_bullet,
                        color: CupertinoColors.white),
                  ),
                ],
              ),
            ),
            // 章节名
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                      color: CupertinoColors.white.withValues(alpha: 0.1)),
                ),
              ),
              child: Text(
                chapterTitle,
                style: TextStyle(
                  color: CupertinoColors.white.withValues(alpha: 0.7),
                  fontSize: 13,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ],
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
                      Slider(
                        value: currentChapterIndex.toDouble(),
                        min: 0,
                        max: (totalChapters - 1).toDouble(),
                        activeColor: CupertinoColors.activeBlue,
                        inactiveColor:
                            CupertinoColors.systemGrey.withValues(alpha: 0.3),
                        onChanged: (value) {
                          // 实时更新章节（拖动时立即跳转）
                          onChapterChanged(value.toInt());
                        },
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
                  child: Slider(
                    value: settings.brightness,
                    min: 0.0,
                    max: 1.0,
                    activeColor: CupertinoColors.activeBlue,
                    inactiveColor:
                        CupertinoColors.systemGrey.withValues(alpha: 0.3),
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
                          ? CupertinoColors.activeBlue
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
              ? CupertinoColors.activeBlue
              : CupertinoColors.systemGrey,
          size: 24),
    );
  }

  Widget _buildMenuBtn(IconData icon, String label, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        splashColor: CupertinoColors.activeBlue.withValues(alpha: 0.3),
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
        actions: PageTurnModeUi.values(current: settings.pageTurnMode).map((mode) {
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
                      ? CupertinoColors.activeBlue
                      : PageTurnModeUi.isHidden(mode)
                          ? CupertinoColors.inactiveGray
                          : CupertinoColors.label,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  PageTurnModeUi.isHidden(mode) ? '${mode.name}（隐藏）' : mode.name,
                  style: TextStyle(
                    color: isSelected
                        ? CupertinoColors.activeBlue
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
                    color: CupertinoColors.activeBlue,
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
