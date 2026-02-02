import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/reading_settings.dart';
import 'page_factory.dart';
import 'simulation_page_painter.dart';

/// 翻页阅读器组件（对标 Legado ReadView + flutter_novel）
/// 核心优化：使用 PictureRecorder 预渲染页面，避免截图开销
class PagedReaderWidget extends StatefulWidget {
  final PageFactory pageFactory;
  final PageTurnMode pageTurnMode;
  final TextStyle textStyle;
  final Color backgroundColor;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  final bool showStatusBar;

  // === 翻页动画增强 ===
  final int animDuration; // 动画时长 (100-600ms)
  final PageDirection pageDirection; // 翻页方向
  final int pageTouchSlop; // 翻页触发灵敏度 (0-100)

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
    // 翻页动画增强默认值
    this.animDuration = 300,
    this.pageDirection = PageDirection.horizontal,
    this.pageTouchSlop = 25,
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

  // 仿真翻页用的起始点和触摸点
  double _startX = 0;
  double _startY = 0;
  double _touchX = 0;
  double _touchY = 0;

  // 页面 Picture 缓存（仿真模式用）
  ui.Picture? _curPagePicture;
  ui.Picture? _targetPagePicture;
  Size? _lastSize;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: widget.animDuration),
    );

    widget.pageFactory.onContentChanged = () {
      if (mounted) {
        _invalidatePictures();
        setState(() {});
      }
    };
  }

  @override
  void didUpdateWidget(PagedReaderWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 动画时长变化时更新 AnimationController
    if (oldWidget.animDuration != widget.animDuration) {
      _animController.duration = Duration(milliseconds: widget.animDuration);
    }
    if (oldWidget.pageFactory != widget.pageFactory ||
        oldWidget.textStyle != widget.textStyle ||
        oldWidget.backgroundColor != widget.backgroundColor) {
      widget.pageFactory.onContentChanged = () {
        if (mounted) {
          _invalidatePictures();
          setState(() {});
        }
      };
      _invalidatePictures();
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    _invalidatePictures();
    super.dispose();
  }

  void _invalidatePictures() {
    _curPagePicture = null;
    _targetPagePicture = null;
  }

  PageFactory get _factory => widget.pageFactory;

  /// 使用 PictureRecorder 预渲染页面内容
  ui.Picture _recordPage(String content, Size size) {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    final topSafe = MediaQuery.of(context).padding.top;
    final bottomSafe = MediaQuery.of(context).padding.bottom;

    // 绘制背景
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = widget.backgroundColor,
    );

    if (content.isNotEmpty) {
      // 绘制文本
      final textPainter = TextPainter(
        text: TextSpan(text: content, style: widget.textStyle),
        textDirection: ui.TextDirection.ltr,
        textAlign: TextAlign.justify,
      );

      final contentWidth =
          size.width - widget.padding.left - widget.padding.right;
      textPainter.layout(maxWidth: contentWidth);

      textPainter.paint(
        canvas,
        Offset(
          widget.padding.left,
          topSafe + PagedReaderWidget.topOffset,
        ),
      );
    }

    // 绘制状态栏
    if (widget.showStatusBar) {
      final time = DateFormat('HH:mm').format(DateTime.now());
      final statusColor = widget.textStyle.color?.withValues(alpha: 0.4) ??
          const Color(0xff8B7961);

      // 章节标题
      final titlePainter = TextPainter(
        text: TextSpan(
          text: _factory.currentChapterTitle,
          style: widget.textStyle.copyWith(fontSize: 14, color: statusColor),
        ),
        textDirection: ui.TextDirection.ltr,
        maxLines: 1,
        ellipsis: '...',
      );
      titlePainter.layout(
          maxWidth: size.width - widget.padding.left - widget.padding.right);
      titlePainter.paint(canvas, Offset(widget.padding.left, 10 + topSafe));

      // 时间
      final timePainter = TextPainter(
        text: TextSpan(
          text: time,
          style: widget.textStyle.copyWith(fontSize: 11, color: statusColor),
        ),
        textDirection: ui.TextDirection.ltr,
      );
      timePainter.layout();
      timePainter.paint(
        canvas,
        Offset(widget.padding.left,
            size.height - 10 - bottomSafe - timePainter.height),
      );

      // 页码
      final pagePainter = TextPainter(
        text: TextSpan(
          text: '${_factory.currentPageIndex + 1}/${_factory.totalPages}',
          style: widget.textStyle.copyWith(fontSize: 11, color: statusColor),
        ),
        textDirection: ui.TextDirection.ltr,
      );
      pagePainter.layout();
      pagePainter.paint(
        canvas,
        Offset(
          size.width - widget.padding.right - pagePainter.width,
          size.height - 10 - bottomSafe - pagePainter.height,
        ),
      );
    }

    return recorder.endRecording();
  }

  void _ensurePictures(Size size) {
    if (_lastSize != size) {
      _invalidatePictures();
      _lastSize = size;
    }

    // 对标 flutter_novel：当前页永远是翻起的页面
    // drawTopPageCanvas: 画 getCurrentPage() - 当前页
    // drawBottomPageCanvas: 画 isTurnToNext ? getNextPage() : getPrePage()
    _curPagePicture ??= _recordPage(_factory.curPage, size);

    if (_direction == _PageDirection.next) {
      _targetPagePicture ??= _recordPage(_factory.nextPage, size);
    } else if (_direction == _PageDirection.prev) {
      _targetPagePicture ??= _recordPage(_factory.prevPage, size);
    }
  }

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

    _invalidatePictures();
    _ensurePictures(size);
    _startAnimation();
  }

  void _goPrev() {
    if (!_factory.hasPrev()) return;
    _direction = _PageDirection.prev;

    final size = MediaQuery.of(context).size;
    // PREV 方向：仿真模式需要从左下角翻起，向右翻露出左边的 prevPage
    // 起始点设置为左侧边缘
    _startX = size.width * 0.1;
    _startY = size.height * 0.9;
    _touchX = _startX;
    _touchY = _startY;

    _invalidatePictures();
    _ensurePictures(size);
    _startAnimation();
  }

  void _startAnimation() {
    if (_isAnimating) return;
    _isAnimating = true;

    final size = MediaQuery.of(context).size;
    final screenWidth = size.width;
    final screenHeight = size.height;

    // 目标点
    // NEXT: 从右下角向左翻走
    // PREV: 从左下角向右翻过来覆盖整个屏幕
    final targetX =
        _direction == _PageDirection.next ? -screenWidth : screenWidth + 50;
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
        _touchX = startTouchX + (targetX - startTouchX) * progress;
        _touchY = startTouchY + (targetY - startTouchY) * progress;
        _dragOffset =
            startDragOffset + (targetDragOffset - startDragOffset) * progress;
        // 使用 markNeedsPaint 而非 setState
        (context as Element).markNeedsBuild();
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
    // 1. 先保存方向
    final direction = _direction;

    // 2. 先更新 Factory（这会改变 curPage 的内容）
    //    必须在重置状态前执行，否则会闪烁
    if (direction == _PageDirection.next) {
      _factory.moveToNext();
    } else if (direction == _PageDirection.prev) {
      _factory.moveToPrev();
    }

    // 3. 清除缓存，下次渲染时会重新生成正确的 Picture
    _invalidatePictures();

    // 4. 重置状态（放在最后，避免中间状态渲染导致闪烁）
    _dragOffset = 0;
    _touchX = 0;
    _touchY = 0;
    _direction = _PageDirection.none;
    _isAnimating = false;

    // 5. 使用 setState 触发重绘
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: widget.backgroundColor,
      child: _buildPageContent(),
    );
  }

  Widget _buildPageContent() {
    final isVertical = widget.pageDirection == PageDirection.vertical;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapUp: (d) => _onTap(d.globalPosition),
      // 水平方向手势
      onHorizontalDragStart: isVertical ? null : _onDragStart,
      onHorizontalDragUpdate: isVertical ? null : _onDragUpdate,
      onHorizontalDragEnd: isVertical ? null : _onDragEnd,
      // 垂直方向手势
      onVerticalDragStart: isVertical ? _onVerticalDragStart : null,
      onVerticalDragUpdate: isVertical ? _onVerticalDragUpdate : null,
      onVerticalDragEnd: isVertical ? _onVerticalDragEnd : null,
      child: _buildAnimatedPages(),
    );
  }

  Widget _buildAnimatedPages() {
    final size = MediaQuery.of(context).size;
    final screenWidth = size.width;
    final screenHeight = size.height;
    final isVertical = widget.pageDirection == PageDirection.vertical;

    // 根据方向选择限制范围
    final maxOffset = isVertical ? screenHeight : screenWidth;
    final offset = _dragOffset.clamp(-maxOffset, maxOffset);

    switch (widget.pageTurnMode) {
      case PageTurnMode.slide:
        return isVertical
            ? _buildVerticalSlideAnimation(screenHeight, offset)
            : _buildSlideAnimation(screenWidth, offset);
      case PageTurnMode.cover:
        return isVertical
            ? _buildVerticalCoverAnimation(screenHeight, offset)
            : _buildCoverAnimation(screenWidth, offset);
      case PageTurnMode.simulation:
        // 仿真模式暂不支持垂直，使用滑动模式替代
        return isVertical
            ? _buildVerticalSlideAnimation(screenHeight, offset)
            : _buildSimulationAnimation(size);
      case PageTurnMode.none:
        return _buildNoAnimation(screenWidth, offset);
      default:
        return isVertical
            ? _buildVerticalSlideAnimation(screenHeight, offset)
            : _buildSlideAnimation(screenWidth, offset);
    }
  }

  /// 垂直滑动模式
  Widget _buildVerticalSlideAnimation(double screenHeight, double offset) {
    return Stack(
      children: [
        if (offset < 0)
          Positioned(
            left: 0,
            right: 0,
            top: screenHeight + offset,
            height: screenHeight,
            child: _buildPageWidget(_factory.nextPage),
          ),
        if (offset > 0)
          Positioned(
            left: 0,
            right: 0,
            top: offset - screenHeight,
            height: screenHeight,
            child: _buildPageWidget(_factory.prevPage),
          ),
        Positioned(
          left: 0,
          right: 0,
          top: offset,
          height: screenHeight,
          child: _buildPageWidget(_factory.curPage),
        ),
      ],
    );
  }

  /// 垂直覆盖模式
  Widget _buildVerticalCoverAnimation(double screenHeight, double offset) {
    final shadowOpacity = (offset.abs() / screenHeight * 0.4).clamp(0.0, 0.4);

    return Stack(
      children: [
        if (offset < 0)
          Positioned.fill(child: _buildPageWidget(_factory.nextPage)),
        if (offset > 0)
          Positioned.fill(child: _buildPageWidget(_factory.prevPage)),
        Positioned(
          left: 0,
          right: 0,
          top: offset,
          height: screenHeight,
          child: Container(
            decoration: BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: shadowOpacity),
                  blurRadius: 20,
                  spreadRadius: 5,
                  offset: Offset(0, offset > 0 ? -8 : 8),
                ),
              ],
            ),
            child: _buildPageWidget(_factory.curPage),
          ),
        ),
      ],
    );
  }

  /// 水平滑动模式
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

  /// 覆盖模式
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

  /// 仿真模式 - 使用 Picture 预渲染
  Widget _buildSimulationAnimation(Size size) {
    final isNext = _direction == _PageDirection.next;

    // 确保 Picture 已预渲染
    _ensurePictures(size);

    // 计算角点
    double cornerX;
    double cornerY;

    if (isNext) {
      cornerX = _startX <= size.width / 2 ? 0 : size.width;
      cornerY = _startY <= size.height / 2 ? 0 : size.height;
      if (size.width / 2 > _startX) {
        cornerX = size.width;
      }
    } else {
      cornerX = _startX > size.width / 2 ? size.width : 0;
      cornerY = size.height;
    }

    // 如果没有拖拽，静止状态显示当前页
    if (!_isDragging && !_isAnimating) {
      return CustomPaint(
        size: size,
        painter: _StaticPagePainter(
          picture: _recordPage(_factory.curPage, size),
        ),
      );
    }

    return CustomPaint(
      size: size,
      painter: SimulationPagePainter(
        curPagePicture: _curPagePicture,
        nextPagePicture: _targetPagePicture,
        touch: Offset(_touchX, _touchY),
        viewSize: size,
        isTurnToNext: isNext,
        backgroundColor: widget.backgroundColor,
        cornerX: cornerX,
        cornerY: cornerY,
      ),
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

    _invalidatePictures();
  }

  void _onDragUpdate(DragUpdateDetails details) {
    if (!_isDragging || _isAnimating) return;

    _dragOffset += details.delta.dx;
    _touchX = details.localPosition.dx;
    _touchY = details.localPosition.dy;

    if (_direction == _PageDirection.none && _dragOffset.abs() > 10) {
      _direction = _dragOffset > 0 ? _PageDirection.prev : _PageDirection.next;
      _invalidatePictures();
    }

    if (_direction == _PageDirection.prev && !_factory.hasPrev()) {
      _dragOffset = (_dragOffset * 0.3).clamp(-50, 50);
    }
    if (_direction == _PageDirection.next && !_factory.hasNext()) {
      _dragOffset = (_dragOffset * 0.3).clamp(-50, 50);
    }

    // 使用 setState 触发重绘
    setState(() {});
  }

  void _onDragEnd(DragEndDetails details) {
    if (!_isDragging || _isAnimating) return;
    _isDragging = false;

    final screenWidth = MediaQuery.of(context).size.width;
    final velocity = details.primaryVelocity ?? 0;

    // 使用配置的灵敏度 (pageTouchSlop 是百分比 0-100)
    final threshold = screenWidth * (widget.pageTouchSlop / 100);
    final shouldTurn = _dragOffset.abs() > threshold || velocity.abs() > 800;

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
        _dragOffset = startOffset * (1 - progress);
        _touchX = startTouchX + (_startX - startTouchX) * progress;
        _touchY = startTouchY + (_startY - startTouchY) * progress;
        setState(() {});
      }
    }

    void statusListener(AnimationStatus status) {
      if (status == AnimationStatus.completed) {
        _dragOffset = 0;
        _touchX = 0;
        _touchY = 0;
        _direction = _PageDirection.none;
        _isAnimating = false;
        _invalidatePictures();
        setState(() {});
        _animController.removeListener(listener);
        _animController.removeStatusListener(statusListener);
      }
    }

    _animController.addListener(listener);
    _animController.addStatusListener(statusListener);
    _animController.forward();
  }

  // === 垂直翻页手势处理 ===
  void _onVerticalDragStart(DragStartDetails details) {
    if (_isAnimating) return;
    _isDragging = true;
    _direction = _PageDirection.none;

    _startX = details.localPosition.dx;
    _startY = details.localPosition.dy;
    _touchX = _startX;
    _touchY = _startY;

    _invalidatePictures();
  }

  void _onVerticalDragUpdate(DragUpdateDetails details) {
    if (!_isDragging || _isAnimating) return;

    // 垂直方向：向上滑动为下一页，向下滑动为上一页
    _dragOffset += details.delta.dy;
    _touchX = details.localPosition.dx;
    _touchY = details.localPosition.dy;

    if (_direction == _PageDirection.none && _dragOffset.abs() > 10) {
      // 向上滑动（负值）= 下一页，向下滑动（正值）= 上一页
      _direction = _dragOffset > 0 ? _PageDirection.prev : _PageDirection.next;
      _invalidatePictures();
    }

    if (_direction == _PageDirection.prev && !_factory.hasPrev()) {
      _dragOffset = (_dragOffset * 0.3).clamp(-50.0, 50.0);
    }
    if (_direction == _PageDirection.next && !_factory.hasNext()) {
      _dragOffset = (_dragOffset * 0.3).clamp(-50.0, 50.0);
    }

    setState(() {});
  }

  void _onVerticalDragEnd(DragEndDetails details) {
    if (!_isDragging || _isAnimating) return;
    _isDragging = false;

    final screenHeight = MediaQuery.of(context).size.height;
    final velocity = details.primaryVelocity ?? 0;

    // 使用配置的灵敏度
    final threshold = screenHeight * (widget.pageTouchSlop / 100);
    final shouldTurn = _dragOffset.abs() > threshold || velocity.abs() > 800;

    if (shouldTurn && _direction != _PageDirection.none) {
      bool canTurn = _direction == _PageDirection.prev
          ? _factory.hasPrev()
          : _factory.hasNext();

      if (canTurn) {
        _startVerticalAnimation();
        return;
      }
    }

    _cancelDrag();
  }

  void _startVerticalAnimation() {
    if (_isAnimating) return;
    _isAnimating = true;

    final size = MediaQuery.of(context).size;
    final screenHeight = size.height;

    final startDragOffset = _dragOffset;
    final targetDragOffset =
        _direction == _PageDirection.next ? -screenHeight : screenHeight;

    _animController.reset();

    void listener() {
      if (mounted) {
        final progress = Curves.easeOutCubic.transform(_animController.value);
        _dragOffset =
            startDragOffset + (targetDragOffset - startDragOffset) * progress;
        (context as Element).markNeedsBuild();
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

  Widget _buildPageWidget(String content) {
    if (content.isEmpty) {
      return Container(color: widget.backgroundColor);
    }

    final topSafe = MediaQuery.of(context).padding.top;
    final bottomSafe = MediaQuery.of(context).padding.bottom;

    return Container(
      color: widget.backgroundColor,
      child: Stack(
        children: [
          Positioned.fill(
            child: Padding(
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
            ),
          ),
          if (widget.showStatusBar) _buildOverlay(topSafe, bottomSafe),
        ],
      ),
    );
  }

  Widget _buildOverlay(double topSafe, double bottomSafe) {
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
}

/// 静态页面绘制器
class _StaticPagePainter extends CustomPainter {
  final ui.Picture picture;

  _StaticPagePainter({required this.picture});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPicture(picture);
  }

  @override
  bool shouldRepaint(covariant _StaticPagePainter oldDelegate) {
    return picture != oldDelegate.picture;
  }
}

enum _PageDirection { none, prev, next }
