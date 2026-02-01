import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:intl/intl.dart';
import '../models/reading_settings.dart';
import 'page_factory.dart';
import 'simulation_page_painter.dart';

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

  // 仿真翻页用的起始点
  double _startX = 0;
  double _startY = 0;
  double _touchX = 0;
  double _touchY = 0;

  // 页面截图（仿真模式用）
  ui.Image? _curPageImage;
  ui.Image? _targetPageImage;
  final GlobalKey _curPageKey = GlobalKey();
  final GlobalKey _targetPageKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    widget.pageFactory.onContentChanged = () {
      if (mounted) {
        setState(() {});
        _clearImages();
      }
    };
  }

  @override
  void didUpdateWidget(PagedReaderWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pageFactory != widget.pageFactory) {
      widget.pageFactory.onContentChanged = () {
        if (mounted) {
          setState(() {});
          _clearImages();
        }
      };
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    _clearImages();
    super.dispose();
  }

  void _clearImages() {
    _curPageImage?.dispose();
    _targetPageImage?.dispose();
    _curPageImage = null;
    _targetPageImage = null;
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

    final size = MediaQuery.of(context).size;
    _startX = size.width * 0.9;
    _startY = size.height * 0.9;
    _touchX = _startX;
    _touchY = _startY;

    _capturePages(() => _startAnimation());
  }

  void _goPrev() {
    if (!_factory.hasPrev()) return;
    _direction = _PageDirection.prev;

    final size = MediaQuery.of(context).size;
    _startX = size.width * 0.1;
    _startY = size.height * 0.9;
    _touchX = _startX;
    _touchY = _startY;

    _capturePages(() => _startAnimation());
  }

  /// 截取页面为图片（仿真模式需要）
  Future<void> _capturePages(VoidCallback onComplete) async {
    if (widget.pageTurnMode != PageTurnMode.simulation) {
      onComplete();
      return;
    }

    // 等待一帧让组件渲染
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        // 截取当前页
        if (_curPageKey.currentContext != null) {
          final boundary = _curPageKey.currentContext!.findRenderObject()
              as RenderRepaintBoundary?;
          if (boundary != null) {
            _curPageImage = await boundary.toImage(pixelRatio: 1.0);
          }
        }

        // 截取目标页
        if (_targetPageKey.currentContext != null) {
          final boundary = _targetPageKey.currentContext!.findRenderObject()
              as RenderRepaintBoundary?;
          if (boundary != null) {
            _targetPageImage = await boundary.toImage(pixelRatio: 1.0);
          }
        }

        onComplete();
      } catch (e) {
        onComplete();
      }
    });
  }

  void _startAnimation() {
    if (_isAnimating) return;
    _isAnimating = true;

    final size = MediaQuery.of(context).size;
    final screenWidth = size.width;
    final screenHeight = size.height;

    // 目标点
    final targetX =
        _direction == _PageDirection.next ? -screenWidth : screenWidth * 2;
    final targetY = screenHeight;

    final startTouchX = _touchX;
    final startTouchY = _touchY;
    final startDragOffset = _dragOffset;
    final targetDragOffset =
        _direction == _PageDirection.next ? -screenWidth : screenWidth;

    _animController.reset();

    void listener() {
      if (mounted) {
        final progress = Curves.easeOutCubic.transform(_animController.value);
        setState(() {
          _touchX = startTouchX + (targetX - startTouchX) * progress;
          _touchY = startTouchY + (targetY - startTouchY) * progress;
          _dragOffset =
              startDragOffset + (targetDragOffset - startDragOffset) * progress;
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
      _touchX = 0;
      _touchY = 0;
      _direction = _PageDirection.none;
      _isAnimating = false;
    });

    _clearImages();
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

  Widget _buildAnimatedPages() {
    final screenWidth = MediaQuery.of(context).size.width;
    final offset = _dragOffset.clamp(-screenWidth, screenWidth);

    switch (widget.pageTurnMode) {
      case PageTurnMode.slide:
        return _buildSlideAnimation(screenWidth, offset);
      case PageTurnMode.cover:
        return _buildCoverAnimation(screenWidth, offset);
      case PageTurnMode.simulation:
        return _buildSimulationAnimation();
      case PageTurnMode.none:
        return _buildNoAnimation(screenWidth, offset);
      default:
        return _buildSlideAnimation(screenWidth, offset);
    }
  }

  /// 滑动模式：两页同时移动
  Widget _buildSlideAnimation(double screenWidth, double offset) {
    return Stack(
      children: [
        if (offset < 0)
          Positioned(
            left: screenWidth + offset,
            top: 0,
            bottom: 0,
            width: screenWidth,
            child: _buildPageWidget(_factory.nextPage),
          ),
        if (offset > 0)
          Positioned(
            left: offset - screenWidth,
            top: 0,
            bottom: 0,
            width: screenWidth,
            child: _buildPageWidget(_factory.prevPage),
          ),
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

  /// 覆盖模式：当前页滑出覆盖
  Widget _buildCoverAnimation(double screenWidth, double offset) {
    final shadowOpacity = (offset.abs() / screenWidth * 0.4).clamp(0.0, 0.4);

    return Stack(
      children: [
        if (offset < 0)
          Positioned.fill(child: _buildPageWidget(_factory.nextPage)),
        if (offset > 0)
          Positioned.fill(child: _buildPageWidget(_factory.prevPage)),
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

  /// 仿真模式：使用 SimulationPagePainter 绘制贝塞尔曲线翻页
  Widget _buildSimulationAnimation() {
    final size = MediaQuery.of(context).size;
    final isNext = _direction == _PageDirection.next;

    // 如果正在动画且有图片，使用 CustomPaint
    if ((_isDragging || _isAnimating) && _curPageImage != null) {
      // 计算角点（对标 Legado calcCornerXY + setDirection）
      int cornerX;
      int cornerY;

      if (isNext) {
        // NEXT方向：从右下角或右上角翻
        cornerX = _startX <= size.width / 2 ? 0 : size.width.toInt();
        cornerY = _startY <= size.height / 2 ? 0 : size.height.toInt();
        // 如果从左边滑动，镜像到右边
        if (size.width / 2 > _startX) {
          cornerX = size.width.toInt();
        }
      } else {
        // PREV方向：强制从底部翻（上一页滑动不出现对角）
        cornerX = _startX > size.width / 2 ? size.width.toInt() : 0;
        cornerY = size.height.toInt();
      }

      return CustomPaint(
        size: size,
        painter: SimulationPagePainter(
          curPageImage: _curPageImage,
          nextPageImage: _targetPageImage,
          touch: Offset(_touchX, _touchY),
          viewSize: size,
          isTurnToNext: isNext,
          backgroundColor: widget.backgroundColor,
          cornerX: cornerX.toDouble(),
          cornerY: cornerY.toDouble(),
        ),
      );
    }

    // 准备截图用的组件
    return Stack(
      children: [
        // 当前页（用于截图）- NEXT时是curPage，PREV时是prevPage
        RepaintBoundary(
          key: _curPageKey,
          child: _buildPageWidget(
            _direction == _PageDirection.prev
                ? _factory.prevPage
                : _factory.curPage,
          ),
        ),
        // 目标页（隐藏但可截图）- NEXT时是nextPage，PREV时是curPage
        // 使用 Visibility 而非 Offstage，保持组件可截图
        Visibility(
          visible: false,
          maintainState: true,
          maintainSize: true,
          maintainAnimation: true,
          child: RepaintBoundary(
            key: _targetPageKey,
            child: _buildPageWidget(
              _direction == _PageDirection.next
                  ? _factory.nextPage
                  : _factory.curPage,
            ),
          ),
        ),
      ],
    );
  }

  /// 无动画模式
  Widget _buildNoAnimation(double screenWidth, double offset) {
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

    _startX = details.localPosition.dx;
    _startY = details.localPosition.dy;
    _touchX = _startX;
    _touchY = _startY;
  }

  void _onDragUpdate(DragUpdateDetails details) {
    if (!_isDragging || _isAnimating) return;

    setState(() {
      _dragOffset += details.delta.dx;
      _touchX = details.localPosition.dx;
      _touchY = details.localPosition.dy;

      if (_direction == _PageDirection.none && _dragOffset.abs() > 10) {
        _direction =
            _dragOffset > 0 ? _PageDirection.prev : _PageDirection.next;

        // 仿真模式需要截图
        if (widget.pageTurnMode == PageTurnMode.simulation) {
          _capturePages(() {});
        }
      }

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
    final startTouchX = _touchX;
    final startTouchY = _touchY;

    _animController.reset();

    void listener() {
      if (mounted) {
        final progress = Curves.easeOut.transform(_animController.value);
        setState(() {
          _dragOffset = startOffset * (1 - progress);
          _touchX = startTouchX + (_startX - startTouchX) * progress;
          _touchY = startTouchY + (_startY - startTouchY) * progress;
        });
      }
    }

    void statusListener(AnimationStatus status) {
      if (status == AnimationStatus.completed) {
        setState(() {
          _dragOffset = 0;
          _touchX = 0;
          _touchY = 0;
          _direction = _PageDirection.none;
          _isAnimating = false;
        });
        _clearImages();
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
