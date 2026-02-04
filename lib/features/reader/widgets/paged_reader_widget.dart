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
    this.enableGestures = true,
  });

  final bool enableGestures;

  @override
  State<PagedReaderWidget> createState() => _PagedReaderWidgetState();
}

class _PagedReaderWidgetState extends State<PagedReaderWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;

  // === 对标 Legado PageDelegate 的状态变量 ===
  bool _isMoved = false; // 是否已移动（触发方向判断）
  bool _isRunning = false; // 动画是否运行中（控制渲染）
  bool _isStarted = false; // Scroller 是否已启动
  bool _isCancel = false; // 是否取消翻页
  _PageDirection _direction = _PageDirection.none; // 翻页方向

  // === 坐标系统（对标 Legado ReadView） ===
  double _startX = 0; // 按下的起始点
  double _startY = 0;
  double _lastX = 0; // 上一帧触摸点
  double _lastY = 0;
  double _touchX = 0.1; // 当前触摸点（P1: 不让x,y为0,否则在点计算时会有问题）
  double _touchY = 0.1;

  // === P2: 角点状态变量（对标 Legado mCornerX, mCornerY）===
  double _cornerX = 0;
  double _cornerY = 0;

  // === Scroller 风格动画（对标 Legado Scroller） ===
  double _scrollStartX = 0;
  double _scrollStartY = 0;
  double _scrollDx = 0;
  double _scrollDy = 0;

  // 页面 Picture 缓存（仿真模式用）
  ui.Picture? _curPagePicture;
  ui.Picture? _targetPagePicture;
  Size? _lastSize;

  // Shader Program
  static ui.FragmentProgram? pageCurlProgram;
  ui.Image? _curPageImage;
  ui.Image? _targetPageImage;

  @override
  void initState() {
    super.initState();
    _loadShader();
    _animController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: widget.animDuration),
    );

    // === 对标 Legado computeScroll ===
    // 使用 AnimationController 的 listener 来驱动动画
    _animController.addListener(_computeScroll);
    _animController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _onAnimComplete();
      }
    });

    widget.pageFactory.onContentChanged = () {
      if (mounted) {
        _invalidatePictures();
        setState(() {});
      }
    };
  }

  Future<void> _loadShader() async {
    if (pageCurlProgram != null) return;
    try {
      pageCurlProgram = await ui.FragmentProgram.fromAsset(
          'lib/features/reader/shaders/page_curl.frag');
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      debugPrint('Failed to load shader: $e');
    }
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

  void _invalidatePictures() {
    _curPagePicture = null;
    _targetPagePicture = null;
    _curPageImage?.dispose();
    _curPageImage = null;
    _targetPageImage?.dispose();
    _targetPageImage = null;
  }

  Future<ui.Image> _convertToHighResImage(ui.Picture picture, Size size) async {
    final dpr = MediaQuery.of(context).devicePixelRatio;
    final int w = (size.width * dpr).toInt();
    final int h = (size.height * dpr).toInt();

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.scale(dpr);
    canvas.drawPicture(picture);
    final highResPicture = recorder.endRecording();

    final img = await highResPicture.toImage(w, h);
    // highResPicture.dispose(); // Picture.toImage consumes or we can dispose?
    // Actually ui.Picture.toImage doesn't consume, but we should dispose the picture after use.
    highResPicture.dispose();
    return img;
  }

  void _ensurePictures(Size size) {
    if (_lastSize != size) {
      _invalidatePictures();
      _lastSize = size;
    }

    // 对标 flutter_novel：当前页永远是翻起的页面
    if (_curPagePicture == null) {
      _curPagePicture = _recordPage(_factory.curPage, size);
      _convertToHighResImage(_curPagePicture!, size).then((img) {
        if (mounted) {
          setState(() {
            _curPageImage = img;
          });
        }
      });
    }

    if (_direction == _PageDirection.next) {
      if (_targetPagePicture == null) {
        _targetPagePicture = _recordPage(_factory.nextPage, size);
        _convertToHighResImage(_targetPagePicture!, size).then((img) {
          if (mounted) {
            setState(() {
              _targetPageImage = img;
            });
          }
        });
      }
    } else if (_direction == _PageDirection.prev) {
      if (_targetPagePicture == null) {
        _targetPagePicture = _recordPage(_factory.prevPage, size);
        _convertToHighResImage(_targetPagePicture!, size).then((img) {
          if (mounted) {
            setState(() {
              _targetPageImage = img;
            });
          }
        });
      }
    }
  }

  // === 对标 Legado: setStartPoint ===
  void _setStartPoint(double x, double y) {
    _startX = x;
    _startY = y;
    _lastX = x;
    _lastY = y;
    _touchX = x;
    _touchY = y;
  }

  // === 对标 Legado: setTouchPoint ===
  void _setTouchPoint(double x, double y) {
    _lastX = _touchX;
    _lastY = _touchY;
    _touchX = x;
    _touchY = y;
  }

  void _onTap(Offset position) {
    if (!widget.enableGestures) return;
    final screenWidth = MediaQuery.of(context).size.width;
    final xRate = position.dx / screenWidth;

    if (xRate > 0.33 && xRate < 0.66) {
      widget.onTap?.call();
    } else if (xRate >= 0.66) {
      _nextPageByAnim(startY: position.dy);
    } else {
      _prevPageByAnim(startY: position.dy);
    }
  }

  // === 对标 Legado: nextPageByAnim ===
  void _nextPageByAnim({double? startY}) {
    _abortAnim();
    if (!_factory.hasNext()) return;

    final size = MediaQuery.of(context).size;

    // 修正：点击翻页统一使用底部微偏位置，忽略点击的具体 Y 坐标
    // 固化为最佳体验值 0.96
    final y = size.height * 0.96;

    // 修正：先更新坐标，再设置方向，确保角点计算正确
    _setStartPoint(size.width * 0.9, y);
    _setDirection(_PageDirection.next);
    _onAnimStart();
  }

  // === 对标 Legado: prevPageByAnim ===
  void _prevPageByAnim({double? startY}) {
    _abortAnim();
    if (!_factory.hasPrev()) return;

    final size = MediaQuery.of(context).size;

    // 修正：点击翻页统一使用底部微偏位置
    // 固化为最佳体验值 0.96
    final y = size.height * 0.96;

    // 修正：先更新坐标，再设置方向
    _setStartPoint(0, y);
    _setDirection(_PageDirection.prev);
    _onAnimStart();
  }

  // === 对标 Legado: setDirection ===
  void _setDirection(_PageDirection direction) {
    _direction = direction;
    final size = MediaQuery.of(context).size;

    // === P2/P4: 在方向确定时计算角点（对标 Legado SimulationPageDelegate.setDirection）===
    if (direction == _PageDirection.prev) {
      // 上一页滑动不出现对角（原对标 Legado: 强制使用底边，现移除限制）
      // 现在跟随手指位置 (_startY)
      if (_startX > size.width / 2) {
        _calcCornerXY(_startX, _startY);
      } else {
        // P4: 左半边镜像处理
        _calcCornerXY(size.width - _startX, _startY);
      }
    } else if (direction == _PageDirection.next) {
      if (size.width / 2 > _startX) {
        // 左半边点击时，强制使用右边角点
        _calcCornerXY(size.width - _startX, _startY);
      } else {
        _calcCornerXY(_startX, _startY);
      }
    }

    _invalidatePictures();
    _ensurePictures(size);
  }

  // === P2: 计算角点（对标 Legado calcCornerXY）===
  void _calcCornerXY(double x, double y) {
    final size = MediaQuery.of(context).size;
    _cornerX = x <= size.width / 2 ? 0 : size.width;
    _cornerY = y <= size.height / 2 ? 0 : size.height;
  }

  // === 对标 Legado: abortAnim ===
  void _abortAnim() {
    _isStarted = false;
    _isMoved = false;
    _isRunning = false;
    if (_animController.isAnimating) {
      _animController.stop();
      if (!_isCancel) {
        _fillPage(_direction);
      }
    }
  }

  // === 对标 Legado: onAnimStart (SimulationPageDelegate) ===
  void _onAnimStart() {
    final size = MediaQuery.of(context).size;
    double dx, dy;

    // 使用预先计算的角点（对标 Legado mCornerX, mCornerY）
    // 不要重新计算，因为 _setDirection 已经计算好了

    if (_isCancel) {
      // === 取消翻页，回到原位 ===
      if (_cornerX > 0 && _direction == _PageDirection.next) {
        dx = size.width - _touchX;
      } else {
        dx = -_touchX;
      }
      if (_direction != _PageDirection.next) {
        dx = -(size.width + _touchX);
      }
      dy = _cornerY > 0 ? (size.height - _touchY) : -_touchY;
    } else {
      // === 完成翻页 ===
      if (_cornerX > 0 && _direction == _PageDirection.next) {
        dx = -(size.width + _touchX);
      } else {
        dx = size.width - _touchX;
      }
      dy = _cornerY > 0 ? (size.height - _touchY) : (1 - _touchY);
    }

    _startScroll(_touchX, _touchY, dx, dy, widget.animDuration);
  }

  // === 对标 Legado: startScroll ===
  // P5: 动态动画时长计算（对标 Legado PageDelegate.startScroll）
  void _startScroll(
      double startX, double startY, double dx, double dy, int animationSpeed) {
    final size = MediaQuery.of(context).size;
    // 根据移动距离动态计算时长
    int duration;
    if (dx != 0) {
      duration = (animationSpeed * dx.abs() / size.width).toInt();
    } else {
      duration = (animationSpeed * dy.abs() / size.height).toInt();
    }
    // 限制在合理范围内
    duration = duration.clamp(100, 600);

    _scrollStartX = startX;
    _scrollStartY = startY;
    _scrollDx = dx;
    _scrollDy = dy;

    _isRunning = true;
    _isStarted = true;
    _animController.duration = Duration(milliseconds: duration);
    _animController.forward(from: 0);
  }

  // === 对标 Legado: computeScroll (由 AnimationController 驱动) ===
  void _computeScroll() {
    if (!_isStarted || !mounted) return;

    final progress = Curves.easeOutCubic.transform(_animController.value);
    _touchX = _scrollStartX + _scrollDx * progress;
    _touchY = _scrollStartY + _scrollDy * progress;

    // 触发重绘
    (context as Element).markNeedsBuild();
  }

  // === 动画完成回调 ===
  void _onAnimComplete() {
    if (!_isStarted) return;
    _stopScroll();
  }

  // === 对标 Legado: fillPage ===
  void _fillPage(_PageDirection direction) {
    if (direction == _PageDirection.next) {
      _factory.moveToNext();
    } else if (direction == _PageDirection.prev) {
      _factory.moveToPrev();
    }
  }

  // === 对标 Legado: stopScroll ===
  void _stopScroll() {
    _isStarted = false;
    _isRunning = false;
    // 立即重置状态，确保在 _fillPage 触发 setState 之前 Offset 归零
    // 从而避免上一页内容消失但新页内容尚未加载的闪烁
    if (mounted) {
      _isMoved = false;

      final wasCancel = _isCancel;
      _isCancel = false;

      final direction = _direction;
      _direction = _PageDirection.none;

      // 重置坐标系统，使 offset = 0
      _touchX = 0;
      _startX = 0;
      _lastX = 0;
      _scrollDx = 0;

      _invalidatePictures();

      // 先重置视觉状态，再更新内容
      if (!wasCancel) {
        _fillPage(direction); // 更新内容
      }
      
      // 强制重绘以立即应用新的状态（offset=0），防止阴影残留
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

    // 计算偏移量（基于触摸点相对于起始点的位移）
    // 对于滑动/覆盖模式使用
    final double offset;
    if (isVertical) {
      offset = (_touchY - _startY).clamp(-screenHeight, screenHeight);
    } else {
      offset = (_touchX - _startX).clamp(-screenWidth, screenWidth);
    }

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
        // 仿真模式使用 touchX/touchY
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

    // 如果偏移量极小，不渲染阴影层，直接显示当前页内容（无阴影容器）
    // 这解决了动画结束后阴影可能残留 1 秒的问题
    final showShadow = offset.abs() > 1.0;

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
          child: showShadow
              ? Container(
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
                )
              : _buildPageWidget(_factory.curPage),
        ),
      ],
    );
  }

  /// 仿真模式 - 对标 Legado SimulationPageDelegate.onDraw
  /// 关键：只在 isRunning (拖拽或动画) 时渲染仿真效果
  Widget _buildSimulationAnimation(Size size) {
    // === 对标 Legado: if (!isRunning) return ===
    // 静止状态直接返回当前页面Widget，不使用 CustomPaint
    // 这样避免了状态切换时的闪烁
    final isRunning = _isMoved || _isRunning;
    if (!isRunning || pageCurlProgram == null || _curPageImage == null) {
      return _buildPageWidget(_factory.curPage);
    }

    final isNext = _direction == _PageDirection.next;

    // === P6: 仿真逻辑修正 ===
    // Next: Peel Current(Top) to reveal Next(Bottom). Curl from Right.
    // Prev: Un-curl Prev(Top) to cover Current(Bottom). Curl from Right (simulating unrolling).

    ui.Image? imageToCurl;
    ui.Picture? bottomPicture;
    double effectiveCornerX;

    if (isNext) {
      imageToCurl = _curPageImage;
      bottomPicture = _targetPagePicture;
      effectiveCornerX = _cornerX;
    } else {
      // Prev: Use Target as the Curling Page (Top), Current as Background (Bottom)
      imageToCurl = _targetPageImage;
      bottomPicture = _curPagePicture;
      // Force Corner to be Right side (simulating we are holding the right edge of the prev page)
      effectiveCornerX = size.width;
    }

    if (imageToCurl == null) {
      return _buildPageWidget(_factory.curPage);
    }

    double simulationTouchX = _touchX;
    if (!isNext) {
      // Prev: Apply coordinate mapping to ensure the page un-curls from the left edge (0)
      // instead of starting half-open.
      // Relationship: FoldX = (TouchX + CornerX) / 2
      // We want FoldX = _touchX (approximately, for visual tracking).
      // Since CornerX = width, we solve: _touchX = (VirtualTouchX + width) / 2
      // => VirtualTouchX = 2 * _touchX - size.width
      simulationTouchX = 2 * _touchX - size.width;
    }

    return CustomPaint(
      size: size,
      painter: SimulationPagePainter(
        // Note: 'curPagePicture' arg is unused in Painter logic for shader mode or used as fallback
        // We only care about 'nextPagePicture' which is the Bottom Layer.
        curPagePicture: null,
        nextPagePicture: bottomPicture,
        touch: Offset(simulationTouchX, _touchY),
        viewSize: size,
        isTurnToNext: isNext,
        backgroundColor: widget.backgroundColor,
        cornerX: effectiveCornerX,
        cornerY: _cornerY,
        shaderProgram: pageCurlProgram!,
        curPageImage: imageToCurl,
        devicePixelRatio: MediaQuery.of(context).devicePixelRatio,
      ),
    );
  }

  /// 无动画模式
  Widget _buildNoAnimation(double screenWidth, double offset) {
    if (offset.abs() > screenWidth * 0.2 && !_isRunning) {
      if (offset < 0 && _factory.hasNext()) {
        return _buildPageWidget(_factory.nextPage);
      } else if (offset > 0 && _factory.hasPrev()) {
        return _buildPageWidget(_factory.prevPage);
      }
    }
    return _buildPageWidget(_factory.curPage);
  }

  // === 对标 Legado HorizontalPageDelegate.onTouch ===
  void _onDragStart(DragStartDetails details) {
    if (!widget.enableGestures) return;
    // 动画已启动时不开始新拖拽
    if (_isStarted) return;
    _abortAnim();
    _setStartPoint(details.localPosition.dx, details.localPosition.dy);
    _isMoved = false;
    _isCancel = false;
    _direction = _PageDirection.none;
  }

  // === 对标 Legado HorizontalPageDelegate.onScroll ===
  void _onDragUpdate(DragUpdateDetails details) {
    // 动画已启动时不处理拖拽
    if (_isStarted) return;

    final focusX = details.localPosition.dx;
    final focusY = details.localPosition.dy;

    // 判断是否移动了
    if (!_isMoved) {
      final deltaX = (focusX - _startX).abs();
      final deltaY = (focusY - _startY).abs();
      final distance = deltaX * deltaX + deltaY * deltaY;
      final slopSquare = 20.0 * 20.0; // 触发阈值

      _isMoved = distance > slopSquare;

      if (_isMoved) {
        // 先保存原始起始点用于方向判断
        final originalStartX = _startX;

        // 判断方向
        final goingRight = focusX - originalStartX > 0;

        if (goingRight) {
          // 向右滑动 = 上一页
          if (!_factory.hasPrev()) {
            _isMoved = false;
            return;
          }
          // 先设置起始点，再设置方向（这样角点计算使用最新坐标）
          _setStartPoint(focusX, focusY);
          _setDirection(_PageDirection.prev);
        } else {
          // 向左滑动 = 下一页
          if (!_factory.hasNext()) {
            _isMoved = false;
            return;
          }
          // 先设置起始点，再设置方向（这样角点计算使用最新坐标）
          _setStartPoint(focusX, focusY);
          _setDirection(_PageDirection.next);
        }
      }
    }

    if (_isMoved) {
      final size = MediaQuery.of(context).size;

      // === P3: 中间区域Y坐标强制调整（对标 Legado SimulationPageDelegate.onTouch）===
      double adjustedY = focusY;
      if (widget.pageTurnMode == PageTurnMode.simulation) {
        // 中间区域：强制使用底边（仅保留中间区域点击的优化，移除上一页的强制锁定）
        // Fixed: Use 0.9 * height to create cone effect (avoid TouchY == CornerY)
        if (_startY > size.height / 3 && _startY < size.height * 2 / 3) {
          adjustedY = size.height * 0.9;
        }
        // 中间偏上区域且是下一页：强制使用顶边
        if (_startY > size.height / 3 &&
            _startY < size.height / 2 &&
            _direction == _PageDirection.next) {
          adjustedY = size.height * 0.1;
        }
      }

      // 判断是否取消（方向改变）
      _isCancel =
          _direction == _PageDirection.next ? focusX > _lastX : focusX < _lastX;
      _isRunning = true;

      // 设置触摸点
      _setTouchPoint(focusX, adjustedY);
      setState(() {});
    }
  }

  // === 对标 Legado HorizontalPageDelegate.onTouch ACTION_UP ===
  void _onDragEnd(DragEndDetails details) {
    if (!_isMoved) {
      _direction = _PageDirection.none;
      return;
    }

    // 开始动画（完成翻页或取消）
    _onAnimStart();
  }

  // === 垂直翻页手势处理（对标水平方式） ===
  void _onVerticalDragStart(DragStartDetails details) {
    if (!widget.enableGestures) return;
    // 动画已启动时不开始新拖拽
    if (_isStarted) return;
    _abortAnim();
    _setStartPoint(details.localPosition.dx, details.localPosition.dy);
    _isMoved = false;
    _isCancel = false;
    _direction = _PageDirection.none;
  }

  void _onVerticalDragUpdate(DragUpdateDetails details) {
    // 动画已启动时不处理拖拽
    if (_isStarted) return;

    final focusX = details.localPosition.dx;
    final focusY = details.localPosition.dy;

    if (!_isMoved) {
      final deltaX = (focusX - _startX).abs();
      final deltaY = (focusY - _startY).abs();
      final distance = deltaX * deltaX + deltaY * deltaY;
      final slopSquare = 20.0 * 20.0;

      _isMoved = distance > slopSquare;

      if (_isMoved) {
        if (focusY - _startY > 0) {
          // 向下滑动 = 上一页
          if (!_factory.hasPrev()) {
            return;
          }
          _setDirection(_PageDirection.prev);
        } else {
          // 向上滑动 = 下一页
          if (!_factory.hasNext()) {
            return;
          }
          _setDirection(_PageDirection.next);
        }
        _setStartPoint(focusX, focusY);
      }
    }

    if (_isMoved) {
      _isCancel =
          _direction == _PageDirection.next ? focusY > _lastY : focusY < _lastY;
      _isRunning = true;
      _setTouchPoint(focusX, focusY);
      setState(() {});
    }
  }

  void _onVerticalDragEnd(DragEndDetails details) {
    if (!_isMoved) {
      _direction = _PageDirection.none;
      return;
    }
    _onAnimStart();
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

enum _PageDirection { none, prev, next }
