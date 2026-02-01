import 'package:flutter/material.dart';
import '../models/reading_settings.dart';

/// 翻页阅读器组件（基于 flutter_reader 架构重写）
/// 使用 PageView.builder 实现平滑翻页
class PagedReaderWidget extends StatefulWidget {
  final List<String> pages;
  final int initialPage;
  final PageTurnMode pageTurnMode;
  final TextStyle textStyle;
  final Color backgroundColor;
  final EdgeInsets padding;
  final Function(int pageIndex)? onPageChanged;
  final VoidCallback? onPrevChapter;
  final VoidCallback? onNextChapter;
  final VoidCallback? onTap;

  // 状态栏参数
  final bool showStatusBar;
  final String chapterTitle;

  const PagedReaderWidget({
    super.key,
    required this.pages,
    this.initialPage = 0,
    required this.pageTurnMode,
    required this.textStyle,
    required this.backgroundColor,
    this.padding = const EdgeInsets.all(16),
    this.onPageChanged,
    this.onPrevChapter,
    this.onNextChapter,
    this.onTap,
    this.showStatusBar = true,
    this.chapterTitle = '',
  });

  @override
  State<PagedReaderWidget> createState() => _PagedReaderWidgetState();
}

class _PagedReaderWidgetState extends State<PagedReaderWidget> {
  late PageController _pageController;
  late int _currentPage;

  @override
  void initState() {
    super.initState();
    _currentPage = widget.initialPage.clamp(0, widget.pages.length - 1);
    _pageController = PageController(
      initialPage: _currentPage,
      keepPage: false,
    );
  }

  @override
  void didUpdateWidget(PagedReaderWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pages != widget.pages) {
      _currentPage = widget.initialPage.clamp(0, widget.pages.length - 1);
      // 重置 PageController
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_pageController.hasClients) {
          _pageController.jumpToPage(_currentPage);
        }
      });
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onTap(Offset position) {
    final screenWidth = MediaQuery.of(context).size.width;
    final xRate = position.dx / screenWidth;

    if (xRate > 0.33 && xRate < 0.66) {
      // 中间区域：显示菜单
      widget.onTap?.call();
    } else if (xRate >= 0.66) {
      // 右侧区域：下一页
      _nextPage();
    } else {
      // 左侧区域：上一页
      _previousPage();
    }
  }

  void _previousPage() {
    if (_currentPage == 0) {
      // 已是第一页，尝试上一章
      widget.onPrevChapter?.call();
      return;
    }
    _pageController.previousPage(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  void _nextPage() {
    if (_currentPage >= widget.pages.length - 1) {
      // 已是最后一页，尝试下一章
      widget.onNextChapter?.call();
      return;
    }
    _pageController.nextPage(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentPage = index;
    });
    widget.onPageChanged?.call(index);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.pages.isEmpty) {
      return Container(
        color: widget.backgroundColor,
        child: Center(
          child: Text('暂无内容', style: widget.textStyle),
        ),
      );
    }

    final safeBottom = MediaQuery.of(context).padding.bottom;

    return Container(
      color: widget.backgroundColor,
      child: Stack(
        children: [
          // 翻页内容
          Positioned.fill(
            child: _buildPageView(),
          ),
          // 底部状态栏
          if (widget.showStatusBar)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: EdgeInsets.only(
                  bottom: safeBottom + 4,
                  top: 4,
                  left: widget.padding.left,
                  right: widget.padding.right,
                ),
                color: widget.backgroundColor,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // 时间
                    Text(
                      _getCurrentTime(),
                      style: widget.textStyle.copyWith(
                        fontSize: 11,
                        color: widget.textStyle.color?.withValues(alpha: 0.4),
                      ),
                    ),
                    // 章节标题
                    Expanded(
                      child: Text(
                        widget.chapterTitle,
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        style: widget.textStyle.copyWith(
                          fontSize: 11,
                          color: widget.textStyle.color?.withValues(alpha: 0.4),
                        ),
                      ),
                    ),
                    // 页码进度
                    Text(
                      '${_currentPage + 1}/${widget.pages.length}',
                      style: widget.textStyle.copyWith(
                        fontSize: 11,
                        color: widget.textStyle.color?.withValues(alpha: 0.4),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPageView() {
    // 根据翻页模式选择物理效果
    ScrollPhysics physics;
    switch (widget.pageTurnMode) {
      case PageTurnMode.none:
        physics = const NeverScrollableScrollPhysics();
        break;
      case PageTurnMode.scroll:
        physics = const BouncingScrollPhysics();
        break;
      default:
        physics = const BouncingScrollPhysics();
        break;
    }

    return PageView.builder(
      controller: _pageController,
      physics: physics,
      itemCount: widget.pages.length,
      onPageChanged: _onPageChanged,
      itemBuilder: (context, index) {
        return GestureDetector(
          onTapUp: (details) => _onTap(details.globalPosition),
          child: _buildPage(index),
        );
      },
    );
  }

  Widget _buildPage(int index) {
    if (index < 0 || index >= widget.pages.length) {
      return Container(color: widget.backgroundColor);
    }

    final safeTop = MediaQuery.of(context).padding.top;

    return Container(
      color: widget.backgroundColor,
      padding: EdgeInsets.only(
        left: widget.padding.left,
        right: widget.padding.right,
        top: widget.padding.top + safeTop,
        bottom: widget.showStatusBar ? 30 : widget.padding.bottom,
      ),
      child: Text(
        widget.pages[index],
        style: widget.textStyle,
        textAlign: TextAlign.justify,
      ),
    );
  }

  String _getCurrentTime() {
    final now = DateTime.now();
    return '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  }
}
