import 'package:flutter/material.dart';
import '../models/reading_settings.dart';
import 'page_delegate/page_delegate.dart';
import 'page_delegate/cover_delegate.dart';
import 'page_delegate/slide_delegate.dart';
import 'page_delegate/no_anim_delegate.dart';

/// 翻页阅读器组件（对标 Legado ReadView）
/// 采用 prevPage/curPage/nextPage 三视图架构
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
  });

  @override
  State<PagedReaderWidget> createState() => _PagedReaderWidgetState();
}

class _PagedReaderWidgetState extends State<PagedReaderWidget>
    with TickerProviderStateMixin {
  late int _currentPage;
  PageDelegate? _pageDelegate;

  // 触摸状态
  double _startX = 0;
  double _startY = 0;
  bool _isMoving = false;

  @override
  void initState() {
    super.initState();
    _currentPage = widget.initialPage.clamp(0, widget.pages.length - 1);
    _initPageDelegate();
  }

  @override
  void didUpdateWidget(PagedReaderWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pageTurnMode != widget.pageTurnMode) {
      _initPageDelegate();
    }
    if (oldWidget.pages != widget.pages) {
      _currentPage = widget.initialPage.clamp(0, widget.pages.length - 1);
    }
  }

  void _initPageDelegate() {
    _pageDelegate?.dispose();

    switch (widget.pageTurnMode) {
      case PageTurnMode.cover:
        _pageDelegate = CoverPageDelegate();
        break;
      case PageTurnMode.slide:
        _pageDelegate = SlidePageDelegate();
        break;
      case PageTurnMode.none:
        _pageDelegate = NoAnimPageDelegate();
        break;
      case PageTurnMode.simulation:
        // 仿真翻页暂未实现，使用覆盖翻页
        _pageDelegate = CoverPageDelegate();
        break;
      case PageTurnMode.scroll:
        // 滚动模式不使用PageDelegate
        _pageDelegate = null;
        break;
    }

    if (_pageDelegate != null) {
      _pageDelegate!.init(this, () {
        if (mounted) setState(() {});
      });

      // 设置翻页回调
      if (_pageDelegate is CoverPageDelegate) {
        (_pageDelegate as CoverPageDelegate).onPageTurn = _handlePageTurn;
      } else if (_pageDelegate is SlidePageDelegate) {
        (_pageDelegate as SlidePageDelegate).onPageTurn = _handlePageTurn;
      } else if (_pageDelegate is NoAnimPageDelegate) {
        (_pageDelegate as NoAnimPageDelegate).onPageTurn = _handlePageTurn;
      }
    }
  }

  Future<bool> _handlePageTurn(PageDirection direction) async {
    if (direction == PageDirection.next) {
      return _goToNextPage();
    } else if (direction == PageDirection.prev) {
      return _goToPrevPage();
    }
    return false;
  }

  bool _goToNextPage() {
    if (_currentPage < widget.pages.length - 1) {
      setState(() {
        _currentPage++;
      });
      widget.onPageChanged?.call(_currentPage);
      return true;
    } else {
      // 触发下一章
      widget.onNextChapter?.call();
      return false;
    }
  }

  bool _goToPrevPage() {
    if (_currentPage > 0) {
      setState(() {
        _currentPage--;
      });
      widget.onPageChanged?.call(_currentPage);
      return true;
    } else {
      // 触发上一章
      widget.onPrevChapter?.call();
      return false;
    }
  }

  @override
  void dispose() {
    _pageDelegate?.dispose();
    super.dispose();
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

    final size = MediaQuery.of(context).size;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanStart: _onPanStart,
      onPanUpdate: _onPanUpdate,
      onPanEnd: _onPanEnd,
      onTapUp: _onTapUp,
      child: Container(
        width: size.width,
        height: size.height,
        color: widget.backgroundColor,
        child: _pageDelegate != null
            ? _pageDelegate!.buildPageTransition(
                currentPage: _buildPage(_currentPage),
                prevPage: _currentPage > 0
                    ? _buildPage(_currentPage - 1)
                    : _buildEmptyPage('已是第一页'),
                nextPage: _currentPage < widget.pages.length - 1
                    ? _buildPage(_currentPage + 1)
                    : _buildEmptyPage('本章结束\n点击右侧进入下一章'),
                size: size,
              )
            : _buildPage(_currentPage),
      ),
    );
  }

  void _onPanStart(DragStartDetails details) {
    _startX = details.localPosition.dx;
    _startY = details.localPosition.dy;
    _isMoving = false;
    _pageDelegate?.onDragStart(details);
  }

  void _onPanUpdate(DragUpdateDetails details) {
    final dx = (details.localPosition.dx - _startX).abs();
    final dy = (details.localPosition.dy - _startY).abs();

    // 水平滑动阈值
    if (dx > 10 || dy > 10) {
      _isMoving = true;
    }

    if (_isMoving && dx > dy) {
      _pageDelegate?.onDragUpdate(details);
    }
  }

  void _onPanEnd(DragEndDetails details) {
    if (_isMoving) {
      _pageDelegate?.onDragEnd(details);
    }
    _isMoving = false;
  }

  /// 点击处理 - 对标 Legado 9宫格
  void _onTapUp(TapUpDetails details) {
    if (_isMoving) return;

    final size = MediaQuery.of(context).size;
    final tapX = details.localPosition.dx;
    final tapY = details.localPosition.dy;

    // 9宫格区域划分
    final leftBound = size.width / 3;
    final rightBound = size.width * 2 / 3;
    final topBound = size.height / 3;
    final bottomBound = size.height * 2 / 3;

    // 中间区域 - 显示菜单
    if (tapX >= leftBound &&
        tapX <= rightBound &&
        tapY >= topBound &&
        tapY <= bottomBound) {
      widget.onTap?.call();
      return;
    }

    // 左侧区域 - 上一页
    if (tapX < leftBound) {
      _pageDelegate?.prevPage();
      return;
    }

    // 右侧区域 - 下一页
    if (tapX > rightBound) {
      _pageDelegate?.nextPage();
      return;
    }

    // 上中/下中区域 - 也可以翻页
    if (tapY < topBound) {
      // 上方区域 - 上一页
      _pageDelegate?.prevPage();
    } else if (tapY > bottomBound) {
      // 下方区域 - 下一页
      _pageDelegate?.nextPage();
    }
  }

  Widget _buildPage(int index) {
    if (index < 0 || index >= widget.pages.length) {
      return Container(color: widget.backgroundColor);
    }

    return Container(
      color: widget.backgroundColor,
      padding: widget.padding,
      child: Text(
        widget.pages[index],
        style: widget.textStyle,
      ),
    );
  }

  Widget _buildEmptyPage(String message) {
    return Container(
      color: widget.backgroundColor,
      padding: widget.padding,
      child: Center(
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: widget.textStyle.copyWith(
            fontSize: 16,
            color: widget.textStyle.color?.withValues(alpha: 0.6),
          ),
        ),
      ),
    );
  }
}
