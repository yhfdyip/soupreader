import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/reading_settings.dart';
import 'page_factory.dart';

/// 翻页阅读器组件（对标 Legado ReadView）
/// 三页面预加载架构：prevPage / curPage / nextPage
class PagedReaderWidget extends StatefulWidget {
  final PageFactory pageFactory;
  final PageTurnMode pageTurnMode;
  final TextStyle textStyle;
  final Color backgroundColor;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  final bool showStatusBar;

  static const double topOffset = 37;
  static const double bottomOffset = 37;

  const PagedReaderWidget({
    super.key,
    required this.pageFactory,
    required this.pageTurnMode,
    required this.textStyle,
    required this.backgroundColor,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.showStatusBar = true,
  });

  @override
  State<PagedReaderWidget> createState() => _PagedReaderWidgetState();
}

class _PagedReaderWidgetState extends State<PagedReaderWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;

  // 翻页状态
  double _dragOffset = 0;
  bool _isDragging = false;
  _PageDirection _direction = _PageDirection.none;
  bool _isAnimating = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    widget.pageFactory.onContentChanged = () {
      if (mounted) setState(() {});
    };
  }

  @override
  void didUpdateWidget(PagedReaderWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pageFactory != widget.pageFactory) {
      widget.pageFactory.onContentChanged = () {
        if (mounted) setState(() {});
      };
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  PageFactory get _factory => widget.pageFactory;

  void _onTap(Offset position) {
    if (_isAnimating) return;

    final screenWidth = MediaQuery.of(context).size.width;
    final xRate = position.dx / screenWidth;

    if (xRate > 0.33 && xRate < 0.66) {
      widget.onTap?.call();
    } else if (xRate >= 0.66) {
      _goNext();
    } else {
      _goPrev();
    }
  }

  void _goNext() {
    if (!_factory.hasNext()) return;
    _direction = _PageDirection.next;
    _startAnimation();
  }

  void _goPrev() {
    if (!_factory.hasPrev()) return;
    _direction = _PageDirection.prev;
    _startAnimation();
  }

  void _startAnimation() {
    if (_isAnimating) return;
    _isAnimating = true;

    final screenWidth = MediaQuery.of(context).size.width;
    final targetOffset =
        _direction == _PageDirection.next ? -screenWidth : screenWidth;
    final startOffset = _dragOffset;

    _animController.reset();

    void listener() {
      if (mounted) {
        setState(() {
          _dragOffset = startOffset +
              (targetOffset - startOffset) *
                  Curves.easeOutCubic.transform(_animController.value);
        });
      }
    }

    void statusListener(AnimationStatus status) {
      if (status == AnimationStatus.completed) {
        _onAnimStop();
        _animController.removeListener(listener);
        _animController.removeStatusListener(statusListener);
      }
    }

    _animController.addListener(listener);
    _animController.addStatusListener(statusListener);
    _animController.forward();
  }

  void _onAnimStop() {
    if (_direction == _PageDirection.next) {
      _factory.moveToNext();
    } else if (_direction == _PageDirection.prev) {
      _factory.moveToPrev();
    }

    setState(() {
      _dragOffset = 0;
      _direction = _PageDirection.none;
      _isAnimating = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final topSafe = MediaQuery.of(context).padding.top;
    final bottomSafe = MediaQuery.of(context).padding.bottom;

    return Container(
      color: widget.backgroundColor,
      child: Stack(
        children: [
          Positioned.fill(
            child: _buildPageContent(),
          ),
          _buildOverlayer(topSafe, bottomSafe),
        ],
      ),
    );
  }

  Widget _buildOverlayer(double topSafe, double bottomSafe) {
    if (!widget.showStatusBar) return const SizedBox.shrink();

    final time = DateFormat('HH:mm').format(DateTime.now());
    final statusColor = widget.textStyle.color?.withValues(alpha: 0.4) ??
        const Color(0xff8B7961);

    return IgnorePointer(
      child: Container(
        padding: EdgeInsets.fromLTRB(
          widget.padding.left,
          10 + topSafe,
          widget.padding.right,
          10 + bottomSafe,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _factory.currentChapterTitle,
              style:
                  widget.textStyle.copyWith(fontSize: 14, color: statusColor),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const Expanded(child: SizedBox.shrink()),
            Row(
              children: [
                Text(time,
                    style: widget.textStyle
                        .copyWith(fontSize: 11, color: statusColor)),
                const Expanded(child: SizedBox.shrink()),
                Text(
                  '${_factory.currentPageIndex + 1}/${_factory.totalPages}',
                  style: widget.textStyle
                      .copyWith(fontSize: 11, color: statusColor),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPageContent() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapUp: (d) => _onTap(d.globalPosition),
      onHorizontalDragStart: _onDragStart,
      onHorizontalDragUpdate: _onDragUpdate,
      onHorizontalDragEnd: _onDragEnd,
      child: _buildAnimatedPages(),
    );
  }

  /// 根据翻页模式构建动画页面
  Widget _buildAnimatedPages() {
    final screenWidth = MediaQuery.of(context).size.width;
    final offset = _dragOffset.clamp(-screenWidth, screenWidth);

    switch (widget.pageTurnMode) {
      case PageTurnMode.slide:
        return _buildSlideAnimation(screenWidth, offset);
      case PageTurnMode.cover:
        return _buildCoverAnimation(screenWidth, offset);
      case PageTurnMode.simulation:
        return _buildSimulationAnimation(screenWidth, offset);
      case PageTurnMode.none:
        return _buildNoAnimation(screenWidth, offset);
      default:
        return _buildSlideAnimation(screenWidth, offset);
    }
  }

  /// 滑动模式：两页同时移动（对标 Legado SlidePageDelegate）
  Widget _buildSlideAnimation(double screenWidth, double offset) {
    return Stack(
      children: [
        // 向左滑（下一页）：下一页在右边，跟随移动
        if (offset < 0)
          Positioned(
            left: screenWidth + offset, // 下一页跟随当前页移动
            top: 0,
            bottom: 0,
            width: screenWidth,
            child: _buildPageWidget(_factory.nextPage),
          ),
        // 向右滑（上一页）：上一页在左边，跟随移动
        if (offset > 0)
          Positioned(
            left: offset - screenWidth, // 上一页跟随当前页移动
            top: 0,
            bottom: 0,
            width: screenWidth,
            child: _buildPageWidget(_factory.prevPage),
          ),
        // 当前页
        Positioned(
          left: offset,
          top: 0,
          bottom: 0,
          width: screenWidth,
          child: _buildPageWidget(_factory.curPage),
        ),
      ],
    );
  }

  /// 覆盖模式：当前页滑出覆盖，目标页静止（对标 Legado CoverPageDelegate）
  Widget _buildCoverAnimation(double screenWidth, double offset) {
    final shadowOpacity = (offset.abs() / screenWidth * 0.4).clamp(0.0, 0.4);

    return Stack(
      children: [
        // 底层：目标页面（静止不动）
        if (offset < 0)
          Positioned.fill(child: _buildPageWidget(_factory.nextPage)),
        if (offset > 0)
          Positioned.fill(child: _buildPageWidget(_factory.prevPage)),

        // 顶层：当前页面滑出 + 阴影
        Positioned(
          left: offset,
          top: 0,
          bottom: 0,
          width: screenWidth,
          child: Container(
            decoration: BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: shadowOpacity),
                  blurRadius: 20,
                  spreadRadius: 5,
                  offset: Offset(offset > 0 ? -8 : 8, 0),
                ),
              ],
            ),
            child: _buildPageWidget(_factory.curPage),
          ),
        ),
      ],
    );
  }

  /// 仿真模式：模拟书页翻转效果（简化版，使用 3D 透视）
  Widget _buildSimulationAnimation(double screenWidth, double offset) {
    final progress = (offset.abs() / screenWidth).clamp(0.0, 1.0);
    // 翻转角度：0° -> 90°
    final angle = progress * math.pi / 2;
    final isNext = offset < 0;

    return Stack(
      children: [
        // 底层：目标页面
        if (offset != 0)
          Positioned.fill(
            child: _buildPageWidget(
                isNext ? _factory.nextPage : _factory.prevPage),
          ),

        // 仿真翻页效果
        if (offset != 0)
          Positioned.fill(
            child: _buildSimulatedPage(screenWidth, angle, isNext),
          ),

        // 未翻页时显示当前页
        if (offset == 0)
          Positioned.fill(child: _buildPageWidget(_factory.curPage)),
      ],
    );
  }

  /// 仿真翻页效果：3D 透视 + 渐变阴影
  Widget _buildSimulatedPage(double screenWidth, double angle, bool isNext) {
    // 使用 ClipRect + Transform 模拟翻页
    return Stack(
      children: [
        // 左半边/右半边保持不动
        ClipRect(
          child: Align(
            alignment: isNext ? Alignment.centerLeft : Alignment.centerRight,
            widthFactor: 0.5,
            child: _buildPageWidget(_factory.curPage),
          ),
        ),

        // 翻转的半边
        Positioned(
          left: isNext ? screenWidth / 2 : 0,
          top: 0,
          bottom: 0,
          width: screenWidth / 2,
          child: Transform(
            alignment: isNext ? Alignment.centerLeft : Alignment.centerRight,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001) // 透视
              ..rotateY(isNext ? -angle : angle),
            child: Stack(
              children: [
                // 翻转的页面内容
                ClipRect(
                  child: Align(
                    alignment:
                        isNext ? Alignment.centerRight : Alignment.centerLeft,
                    widthFactor: 1.0,
                    child: SizedBox(
                      width: screenWidth / 2,
                      child: ClipRect(
                        child: Align(
                          alignment: isNext
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          widthFactor: 0.5,
                          child: SizedBox(
                            width: screenWidth,
                            child: _buildPageWidget(_factory.curPage),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                // 渐变阴影（模拟光照）
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin:
                          isNext ? Alignment.centerLeft : Alignment.centerRight,
                      end:
                          isNext ? Alignment.centerRight : Alignment.centerLeft,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: angle / math.pi * 0.5),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// 无动画模式：直接切换
  Widget _buildNoAnimation(double screenWidth, double offset) {
    // 超过阈值立即切换显示
    if (offset.abs() > screenWidth * 0.2 && !_isAnimating) {
      if (offset < 0 && _factory.hasNext()) {
        return _buildPageWidget(_factory.nextPage);
      } else if (offset > 0 && _factory.hasPrev()) {
        return _buildPageWidget(_factory.prevPage);
      }
    }
    return _buildPageWidget(_factory.curPage);
  }

  void _onDragStart(DragStartDetails details) {
    if (_isAnimating) return;
    _isDragging = true;
    _direction = _PageDirection.none;
  }

  void _onDragUpdate(DragUpdateDetails details) {
    if (!_isDragging || _isAnimating) return;

    setState(() {
      _dragOffset += details.delta.dx;

      if (_direction == _PageDirection.none && _dragOffset.abs() > 10) {
        _direction =
            _dragOffset > 0 ? _PageDirection.prev : _PageDirection.next;
      }

      // 边界阻尼
      if (_direction == _PageDirection.prev && !_factory.hasPrev()) {
        _dragOffset = (_dragOffset * 0.3).clamp(-50, 50);
      }
      if (_direction == _PageDirection.next && !_factory.hasNext()) {
        _dragOffset = (_dragOffset * 0.3).clamp(-50, 50);
      }
    });
  }

  void _onDragEnd(DragEndDetails details) {
    if (!_isDragging || _isAnimating) return;
    _isDragging = false;

    final screenWidth = MediaQuery.of(context).size.width;
    final velocity = details.primaryVelocity ?? 0;

    final shouldTurn =
        _dragOffset.abs() > screenWidth * 0.25 || velocity.abs() > 800;

    if (shouldTurn && _direction != _PageDirection.none) {
      bool canTurn = _direction == _PageDirection.prev
          ? _factory.hasPrev()
          : _factory.hasNext();

      if (canTurn) {
        _startAnimation();
        return;
      }
    }

    _cancelDrag();
  }

  void _cancelDrag() {
    _isAnimating = true;
    final startOffset = _dragOffset;

    _animController.reset();

    void listener() {
      if (mounted) {
        setState(() {
          _dragOffset = startOffset *
              (1 - Curves.easeOut.transform(_animController.value));
        });
      }
    }

    void statusListener(AnimationStatus status) {
      if (status == AnimationStatus.completed) {
        setState(() {
          _dragOffset = 0;
          _direction = _PageDirection.none;
          _isAnimating = false;
        });
        _animController.removeListener(listener);
        _animController.removeStatusListener(statusListener);
      }
    }

    _animController.addListener(listener);
    _animController.addStatusListener(statusListener);
    _animController.forward();
  }

  Widget _buildPageWidget(String content) {
    if (content.isEmpty) {
      return Container(color: widget.backgroundColor);
    }

    final topSafe = MediaQuery.of(context).padding.top;
    final bottomSafe = MediaQuery.of(context).padding.bottom;

    return Container(
      color: widget.backgroundColor,
      padding: EdgeInsets.fromLTRB(
        widget.padding.left,
        topSafe + PagedReaderWidget.topOffset,
        widget.padding.right,
        bottomSafe + PagedReaderWidget.bottomOffset,
      ),
      child: Text.rich(
        TextSpan(text: content, style: widget.textStyle),
        textAlign: TextAlign.justify,
      ),
    );
  }
}

enum _PageDirection { none, prev, next }
