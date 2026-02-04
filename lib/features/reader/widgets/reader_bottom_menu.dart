import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors, Slider, SliderTheme, SliderThemeData, RoundSliderThumbShape, RoundSliderOverlayShape;
import '../../../app/theme/colors.dart';
import '../models/reading_settings.dart';

/// 阅读器底部 Tab 菜单 - Cupertino 风格
/// 参考 Legado 和参考图片重新设计
class ReaderBottomMenuNew extends StatefulWidget {
  final int currentChapterIndex;
  final int totalChapters;
  final ReadingSettings settings;
  final ReadingThemeColors currentTheme;
  final ValueChanged<int> onChapterChanged;
  final ValueChanged<ReadingSettings> onSettingsChanged;
  final VoidCallback onShowChapterList;
  final VoidCallback onShowInterfaceSettings;
  final VoidCallback onShowMoreMenu;

  const ReaderBottomMenuNew({
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
  State<ReaderBottomMenuNew> createState() => _ReaderBottomMenuNewState();
}

class _ReaderBottomMenuNewState extends State<ReaderBottomMenuNew> {
  // 当前选中的 Tab
  int _selectedTab = -1; // -1 表示未选中任何 Tab

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
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 拖动指示器
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 8),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // 章节进度滑块
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: _buildChapterSlider(),
            ),

            // 底部 Tab 导航栏
            Container(
              padding: EdgeInsets.only(
                left: 8,
                right: 8,
                top: 8,
                bottom: bottomPadding + 8,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildTabItem(0, CupertinoIcons.list_bullet, '目录',
                      widget.onShowChapterList),
                  _buildTabItem(1, _getDayNightIcon(), _getDayNightLabel(),
                      _toggleDayNight),
                  _buildTabItem(2, CupertinoIcons.paintbrush, '主题',
                      _showThemePanel),
                  _buildTabItem(3, CupertinoIcons.textformat, '界面',
                      widget.onShowInterfaceSettings),
                  _buildTabItem(4, CupertinoIcons.gear, '设置',
                      widget.onShowMoreMenu),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 章节进度滑块
  Widget _buildChapterSlider() {
    return Row(
      children: [
        // 上一章按钮
        CupertinoButton(
          padding: EdgeInsets.zero,
          // minimumSize 需要 Size 类型，这里暂时省略或使用默认值
          onPressed: widget.currentChapterIndex > 0
              ? () => widget.onChapterChanged(widget.currentChapterIndex - 1)
              : null,
          child: Text(
            '上一章',
            style: TextStyle(
              fontSize: 13,
              color: widget.currentChapterIndex > 0
                  ? CupertinoColors.activeBlue
                  : CupertinoColors.systemGrey,
            ),
          ),
        ),

        // 进度滑块
        Expanded(
          child: Column(
            children: [
              SliderTheme(
                data: SliderThemeData(
                  trackHeight: 4,
                  thumbShape:
                      const RoundSliderThumbShape(enabledThumbRadius: 8),
                  overlayShape:
                      const RoundSliderOverlayShape(overlayRadius: 16),
                  activeTrackColor: CupertinoColors.activeBlue,
                  inactiveTrackColor:
                      CupertinoColors.systemGrey.withValues(alpha: 0.3),
                  thumbColor: CupertinoColors.white,
                ),
                child: Slider(
                  value: widget.currentChapterIndex.toDouble(),
                  min: 0,
                  max: (widget.totalChapters - 1).toDouble().clamp(0, double.infinity),
                  onChanged: (value) {},
                  onChangeEnd: (value) {
                    widget.onChapterChanged(value.toInt());
                  },
                ),
              ),
              Text(
                '${widget.currentChapterIndex + 1} / ${widget.totalChapters}',
                style: const TextStyle(
                  color: CupertinoColors.systemGrey,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),

        // 下一章按钮
        CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: widget.currentChapterIndex < widget.totalChapters - 1
              ? () => widget.onChapterChanged(widget.currentChapterIndex + 1)
              : null,
          child: Text(
            '下一章',
            style: TextStyle(
              fontSize: 13,
              color: widget.currentChapterIndex < widget.totalChapters - 1
                  ? CupertinoColors.activeBlue
                  : CupertinoColors.systemGrey,
            ),
          ),
        ),
      ],
    );
  }

  /// Tab 项构建
  Widget _buildTabItem(
      int index, IconData icon, String label, VoidCallback onTap) {
    final isSelected = _selectedTab == index;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedTab = index;
        });
        onTap();
      },
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? CupertinoColors.activeBlue.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected
                  ? CupertinoColors.activeBlue
                  : CupertinoColors.white,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected
                    ? CupertinoColors.activeBlue
                    : CupertinoColors.white,
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 日夜切换图标
  IconData _getDayNightIcon() {
    return widget.currentTheme.isDark
        ? CupertinoIcons.moon_fill
        : CupertinoIcons.sun_max_fill;
  }

  /// 日夜切换标签
  String _getDayNightLabel() {
    return widget.currentTheme.isDark ? '夜间' : '日间';
  }

  /// 切换日夜模式
  void _toggleDayNight() {
    final isDark = widget.currentTheme.isDark;
    // 找到一个相反亮度的主题
    final targetIndex = AppColors.readingThemes
        .indexWhere((t) => isDark ? !t.isDark : t.isDark);
    if (targetIndex != -1) {
      widget.onSettingsChanged(widget.settings.copyWith(themeIndex: targetIndex));
    }
  }

  /// 显示主题选择面板
  void _showThemePanel() {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => _ThemeSelectorSheet(
        currentThemeIndex: widget.settings.themeIndex,
        onThemeChanged: (index) {
          widget.onSettingsChanged(widget.settings.copyWith(themeIndex: index));
        },
      ),
    );
  }
}

/// 主题选择面板
class _ThemeSelectorSheet extends StatelessWidget {
  final int currentThemeIndex;
  final ValueChanged<int> onThemeChanged;

  const _ThemeSelectorSheet({
    required this.currentThemeIndex,
    required this.onThemeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).padding.bottom + 16,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF1C1C1E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 拖动指示器
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),

          // 标题
          const Text(
            '阅读主题',
            style: TextStyle(
              color: CupertinoColors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),

          // 主题网格
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: List.generate(AppColors.readingThemes.length, (index) {
              final theme = AppColors.readingThemes[index];
              final isSelected = currentThemeIndex == index;

              return GestureDetector(
                onTap: () {
                  onThemeChanged(index);
                  Navigator.pop(context);
                },
                child: Container(
                  width: 70,
                  height: 90,
                  decoration: BoxDecoration(
                    color: theme.background,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? CupertinoColors.activeBlue
                          : Colors.white12,
                      width: isSelected ? 3 : 1,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color:
                                  CupertinoColors.activeBlue.withValues(alpha: 0.4),
                              blurRadius: 8,
                            )
                          ]
                        : null,
                  ),
                  child: Stack(
                    children: [
                      Center(
                        child: Text(
                          theme.name,
                          style: TextStyle(
                            color: theme.text,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      if (isSelected)
                        Positioned(
                          bottom: 6,
                          right: 6,
                          child: Container(
                            width: 20,
                            height: 20,
                            decoration: const BoxDecoration(
                              color: CupertinoColors.activeBlue,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              CupertinoIcons.checkmark,
                              color: CupertinoColors.white,
                              size: 12,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}
