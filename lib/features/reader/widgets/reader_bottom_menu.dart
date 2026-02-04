import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors, Slider, SliderTheme, SliderThemeData, RoundSliderThumbShape, RoundSliderOverlayShape;
import '../../../app/theme/colors.dart';
import '../models/reading_settings.dart';

/// 阅读器底部 Tab 菜单 - Cupertino 风格
/// 参考 Legado 和参考图片重新设计
class ReaderBottomMenuNew extends StatefulWidget {
  final int currentChapterIndex;
  final int totalChapters;
  final int currentPageIndex;  // 章节内当前页码
  final int totalPages;        // 章节内总页数
  final ReadingSettings settings;
  final ReadingThemeColors currentTheme;
  final ValueChanged<int> onChapterChanged;
  final ValueChanged<int> onPageChanged;  // 页码变化回调
  final ValueChanged<ReadingSettings> onSettingsChanged;
  final VoidCallback onShowChapterList;
  final VoidCallback onShowInterfaceSettings;
  final VoidCallback onShowMoreMenu;

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
    required this.onShowInterfaceSettings,
    required this.onShowMoreMenu,
  });

  @override
  State<ReaderBottomMenuNew> createState() => _ReaderBottomMenuNewState();
}

class _ReaderBottomMenuNewState extends State<ReaderBottomMenuNew> {
  // 当前选中的 Tab
  int _selectedTab = -1; // -1 表示未选中任何 Tab
  
  // 进度条拖动状态
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

            // 底部 Tab 导航栏 (精简为4个：目录/日夜/界面/设置)
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
                  _buildTabItem(2, CupertinoIcons.textformat_size, '界面',
                      widget.onShowInterfaceSettings),
                  _buildTabItem(3, CupertinoIcons.gear, '设置',
                      widget.onShowMoreMenu),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 章节内页码进度滑块
  Widget _buildChapterSlider() {
    final maxPage = (widget.totalPages - 1).clamp(0, 9999);
    
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center, // 垂直居中对齐
      children: [
        // 上一章按钮
        SizedBox(
          width: 60,
          child: CupertinoButton(
            padding: EdgeInsets.zero,

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
        ),

        // 页码进度滑块
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
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
                    value: _isDragging 
                        ? _dragValue.clamp(0, maxPage.toDouble())
                        : widget.currentPageIndex.toDouble().clamp(0, maxPage.toDouble()),
                    min: 0,
                    max: maxPage.toDouble(),
                    onChanged: (value) {
                      setState(() {
                        _isDragging = true;
                        _dragValue = value;
                      });
                    },
                    onChangeEnd: (value) {
                      setState(() {
                        _isDragging = false;
                      });
                      widget.onPageChanged(value.toInt());
                    },
                  ),
                ),
                Text(
                  '${widget.currentPageIndex + 1} / ${widget.totalPages}',
                  style: const TextStyle(
                    color: CupertinoColors.systemGrey,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ),

        // 下一章按钮
        SizedBox(
          width: 60,
          child: CupertinoButton(
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
}

