import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/reading_settings.dart';

/// 翻页阅读器组件（完全对标 flutter_reader 架构）
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

  // 边距常量（对标 flutter_reader ReaderUtils）
  static const double topOffset = 37;
  static const double bottomOffset = 37;

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
    _pageController.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(PagedReaderWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pages != widget.pages) {
      _currentPage = widget.initialPage.clamp(0, widget.pages.length - 1);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_pageController.hasClients) {
          _pageController.jumpToPage(_currentPage);
        }
      });
    }
  }

  @override
  void dispose() {
    _pageController.removeListener(_onScroll);
    _pageController.dispose();
    super.dispose();
  }

  /// 滚动监听（对标 flutter_reader onScroll）
  void _onScroll() {
    // 可在此处添加章节切换逻辑
  }

  void _onTap(Offset position) {
    final screenWidth = MediaQuery.of(context).size.width;
    final xRate = position.dx / screenWidth;

    // 对标 flutter_reader 的点击区域划分
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

    final topSafeHeight = MediaQuery.of(context).padding.top;
    final bottomSafeHeight = MediaQuery.of(context).padding.bottom;

    // 对标 flutter_reader ReaderView 结构
    return Container(
      color: widget.backgroundColor,
      child: Stack(
        children: [
          // 翻页内容
          Positioned.fill(
            child: _buildPageView(),
          ),
          // 覆盖层（对标 ReaderOverlayer）
          _buildOverlayer(topSafeHeight, bottomSafeHeight),
        ],
      ),
    );
  }

  /// 构建覆盖层（对标 flutter_reader ReaderOverlayer）
  Widget _buildOverlayer(double topSafeHeight, double bottomSafeHeight) {
    if (!widget.showStatusBar) return const SizedBox.shrink();

    final format = DateFormat('HH:mm');
    final time = format.format(DateTime.now());
    final statusColor = widget.textStyle.color?.withValues(alpha: 0.4) ??
        const Color(0xff8B7961);

    return Container(
      padding: EdgeInsets.fromLTRB(
        widget.padding.left,
        10 + topSafeHeight,
        widget.padding.right,
        10 + bottomSafeHeight,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 顶部：章节标题
          Text(
            widget.chapterTitle,
            style: widget.textStyle.copyWith(
              fontSize: 14,
              color: statusColor,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const Expanded(child: SizedBox.shrink()),
          // 底部：时间 + 页码
          Row(
            children: [
              // 时间
              Text(
                time,
                style: widget.textStyle.copyWith(
                  fontSize: 11,
                  color: statusColor,
                ),
              ),
              const Expanded(child: SizedBox.shrink()),
              // 页码
              Text(
                '第${_currentPage + 1}页',
                style: widget.textStyle.copyWith(
                  fontSize: 11,
                  color: statusColor,
                ),
              ),
            ],
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

  /// 构建单页内容（对标 flutter_reader ReaderView.buildContent）
  Widget _buildPage(int index) {
    if (index < 0 || index >= widget.pages.length) {
      return Container(color: widget.backgroundColor);
    }

    final topSafeHeight = MediaQuery.of(context).padding.top;
    final bottomSafeHeight = MediaQuery.of(context).padding.bottom;

    // 对标 flutter_reader 的 margin 布局
    // margin: EdgeInsets.fromLTRB(15, topSafeHeight + topOffset, 10, bottomSafeHeight + bottomOffset)
    return Container(
      color: Colors.transparent,
      margin: EdgeInsets.fromLTRB(
        widget.padding.left,
        topSafeHeight + PagedReaderWidget.topOffset,
        widget.padding.right,
        bottomSafeHeight + PagedReaderWidget.bottomOffset,
      ),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: widget.pages[index],
              style: widget.textStyle,
            ),
          ],
        ),
        textAlign: TextAlign.justify,
      ),
    );
  }
}
