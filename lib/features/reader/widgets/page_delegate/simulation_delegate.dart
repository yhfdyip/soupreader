import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'page_delegate.dart';

/// 仿真翻页委托（完全对标 flutter_novel SimulationTurnPageAnimation）
/// 使用贝塞尔曲线模拟真实书页翻转效果
class SimulationDelegate extends PageDelegate {
  VoidCallback? _onUpdate;
  bool _isDragging = false;

  /// 翻页完成回调
  PageTurnCallback? onPageTurn;

  // 触摸点
  late Offset mTouch = Offset.zero;
  // 视图尺寸
  late Size currentSize = Size.zero;

  // Path 对象 (对标 flutter_novel)
  Path mTopPagePath = Path();
  Path mBottomPagePath = Path();
  Path mTopBackAreaPagePath = Path();

  // 拖拽点对应的页脚 (对标 flutter_novel)
  double mCornerX = 1;
  double mCornerY = 1;

  // 是否属于右上左下 (对标 flutter_novel)
  late bool mIsRTandLB = false;

  // 贝塞尔曲线控制点 (对标 flutter_novel)
  Offset mBezierStart1 = Offset.zero;
  Offset mBezierControl1 = Offset.zero;
  Offset mBezierVertex1 = Offset.zero;
  Offset mBezierEnd1 = Offset.zero;
  Offset mBezierStart2 = Offset.zero;
  Offset mBezierControl2 = Offset.zero;
  Offset mBezierVertex2 = Offset.zero;
  Offset mBezierEnd2 = Offset.zero;

  // 中点和最大长度 (对标 flutter_novel)
  double mMiddleX = 0;
  double mMiddleY = 0;
  double mTouchToCornerDis = 0;
  double mMaxLength = 0;

  // 是否翻向下一页 (对标 flutter_novel)
  bool isTurnToNext = false;
  bool isStartAnimation = false;
  bool isConfirmAnimation = false;

  // 页面 Picture 缓存
  ui.Picture? curPagePicture;
  ui.Picture? nextPagePicture;
  ui.Picture? prevPagePicture;

  // 页面 Image 缓存 (用于背面渲染)
  ui.Image? curPageImage;

  // 背景颜色
  Color backgroundColor = const Color(0xfffff2cc);

  // 动画 Tween
  Tween<Offset>? _animationTween;
  Animation<Offset>? _animation;

  @override
  void init(TickerProvider vsync, VoidCallback onUpdate) {
    _onUpdate = onUpdate;
    animationController = AnimationController(
      vsync: vsync,
      duration: const Duration(milliseconds: 300),
    );
  }

  @override
  double get currentOffset => 0;

  @override
  bool get showPrevPage => direction == PageDirection.prev;

  @override
  bool get showNextPage => direction == PageDirection.next;

  /// 计算贝塞尔曲线各点 (完全对标 flutter_novel calBezierPoint)
  void calBezierPoint() {
    mMiddleX = (mTouch.dx + mCornerX) / 2;
    mMiddleY = (mTouch.dy + mCornerY) / 2;

    mMaxLength = math
        .sqrt(math.pow(currentSize.width, 2) + math.pow(currentSize.height, 2));

    mBezierControl1 = Offset(
        mMiddleX -
            (mCornerY - mMiddleY) *
                (mCornerY - mMiddleY) /
                (mCornerX - mMiddleX),
        mCornerY);

    double f4 = mCornerY - mMiddleY;
    if (f4 == 0) {
      mBezierControl2 = Offset(mCornerX,
          mMiddleY - (mCornerX - mMiddleX) * (mCornerX - mMiddleX) / 0.1);
    } else {
      mBezierControl2 = Offset(
          mCornerX,
          mMiddleY -
              (mCornerX - mMiddleX) *
                  (mCornerX - mMiddleX) /
                  (mCornerY - mMiddleY));
    }

    mBezierStart1 = Offset(
        mBezierControl1.dx - (mCornerX - mBezierControl1.dx) / 2, mCornerY);

    // 当mBezierStart1.x < 0或者mBezierStart1.x > 480时，需要限制
    if (mTouch.dx > 0 && mTouch.dx < currentSize.width) {
      if (mBezierStart1.dx < 0 || mBezierStart1.dx > currentSize.width) {
        if (mBezierStart1.dx < 0) {
          mBezierStart1 =
              Offset(currentSize.width - mBezierStart1.dx, mBezierStart1.dy);
        }

        double f1 = (mCornerX - mTouch.dx).abs();
        double f2 = currentSize.width * f1 / mBezierStart1.dx;
        mTouch = Offset((mCornerX - f2).abs(), mTouch.dy);

        double f3 =
            (mCornerX - mTouch.dx).abs() * (mCornerY - mTouch.dy).abs() / f1;
        mTouch = Offset((mCornerX - f2).abs(), (mCornerY - f3).abs());

        mMiddleX = (mTouch.dx + mCornerX) / 2;
        mMiddleY = (mTouch.dy + mCornerY) / 2;

        mBezierControl1 = Offset(
            mMiddleX -
                (mCornerY - mMiddleY) *
                    (mCornerY - mMiddleY) /
                    (mCornerX - mMiddleX),
            mCornerY);

        double f5 = mCornerY - mMiddleY;
        if (f5 == 0) {
          mBezierControl2 = Offset(mCornerX,
              mMiddleY - (mCornerX - mMiddleX) * (mCornerX - mMiddleX) / 0.1);
        } else {
          mBezierControl2 = Offset(
              mCornerX,
              mMiddleY -
                  (mCornerX - mMiddleX) *
                      (mCornerX - mMiddleX) /
                      (mCornerY - mMiddleY));
        }

        mBezierStart1 = Offset(
            mBezierControl1.dx - (mCornerX - mBezierControl1.dx) / 2,
            mBezierStart1.dy);
      }
    }

    mBezierStart2 = Offset(
        mCornerX, mBezierControl2.dy - (mCornerY - mBezierControl2.dy) / 2);

    mTouchToCornerDis = math.sqrt(math.pow((mTouch.dx - mCornerX), 2) +
        math.pow((mTouch.dy - mCornerY), 2));

    mBezierEnd1 =
        getCross(mTouch, mBezierControl1, mBezierStart1, mBezierStart2);
    mBezierEnd2 =
        getCross(mTouch, mBezierControl2, mBezierStart1, mBezierStart2);

    mBezierVertex1 = Offset(
        (mBezierStart1.dx + 2 * mBezierControl1.dx + mBezierEnd1.dx) / 4,
        (2 * mBezierControl1.dy + mBezierStart1.dy + mBezierEnd1.dy) / 4);

    mBezierVertex2 = Offset(
        (mBezierStart2.dx + 2 * mBezierControl2.dx + mBezierEnd2.dx) / 4,
        (2 * mBezierControl2.dy + mBezierStart2.dy + mBezierEnd2.dy) / 4);
  }

  /// 获取交点 (完全对标 flutter_novel getCross)
  Offset getCross(Offset p1, Offset p2, Offset p3, Offset p4) {
    double k1 = (p2.dy - p1.dy) / (p2.dx - p1.dx);
    double b1 = ((p1.dx * p2.dy) - (p2.dx * p1.dy)) / (p1.dx - p2.dx);
    double k2 = (p4.dy - p3.dy) / (p4.dx - p3.dx);
    double b2 = ((p3.dx * p4.dy) - (p4.dx * p3.dy)) / (p3.dx - p4.dx);
    return Offset((b2 - b1) / (k1 - k2), k1 * ((b2 - b1) / (k1 - k2)) + b1);
  }

  /// 计算拖拽点对应的拖拽脚 (完全对标 flutter_novel calcCornerXY)
  void calcCornerXY(double x, double y) {
    if (x <= currentSize.width / 2) {
      mCornerX = 0;
    } else {
      mCornerX = currentSize.width;
    }
    if (y <= currentSize.height / 2) {
      mCornerY = 0;
    } else {
      mCornerY = currentSize.height;
    }

    if ((mCornerX == 0 && mCornerY == currentSize.height) ||
        (mCornerX == currentSize.width && mCornerY == 0)) {
      mIsRTandLB = true;
    } else {
      mIsRTandLB = false;
    }
  }

  @override
  void onDragStart(DragStartDetails details) {
    if (isAnimating) return;
    _isDragging = true;
    direction = PageDirection.none;
    mTouch = details.localPosition;
    calcCornerXY(mTouch.dx, mTouch.dy);
  }

  @override
  void onDragUpdate(DragUpdateDetails details) {
    if (!_isDragging || isAnimating) return;

    mTouch = details.localPosition;

    // 判断翻页方向 (完全对标 flutter_novel)
    isTurnToNext = mTouch.dx - mCornerX < 0;

    if (direction == PageDirection.none) {
      direction = isTurnToNext ? PageDirection.next : PageDirection.prev;
    }

    isStartAnimation = true;
    calBezierPoint();
    _onUpdate?.call();
  }

  @override
  void onDragEnd(DragEndDetails details) {
    if (!_isDragging || isAnimating) return;
    _isDragging = false;

    // 判断是否在取消区域 (完全对标 flutter_novel)
    if (isCancelArea()) {
      _startCancelAnimation();
    } else if (isConfirmArea()) {
      _startConfirmAnimation();
    }
  }

  /// 是否在取消区域 (完全对标 flutter_novel isCancelArea)
  bool isCancelArea() {
    return isTurnToNext
        ? (mTouch.dx).abs() > (currentSize.width / 4 * 3)
        : (mTouch.dx).abs() < (currentSize.width / 4);
  }

  /// 是否在确认区域 (完全对标 flutter_novel isConfirmArea)
  bool isConfirmArea() {
    return isTurnToNext
        ? (mTouch.dx).abs() < (currentSize.width / 4 * 3)
        : (mTouch.dx).abs() > (currentSize.width / 4);
  }

  /// 开始取消动画 (完全对标 flutter_novel getCancelAnimation)
  void _startCancelAnimation() {
    isConfirmAnimation = false;

    _animationTween = Tween(begin: mTouch, end: Offset(mCornerX, mCornerY));
    _animation = _animationTween!.animate(
      CurvedAnimation(parent: animationController!, curve: Curves.easeOut),
    );

    _animation!.addListener(_onAnimationUpdate);
    _animation!.addStatusListener(_onCancelAnimationStatus);

    animationController!.reset();
    animationController!.forward();
  }

  /// 开始确认动画 (完全对标 flutter_novel getConfirmAnimation)
  void _startConfirmAnimation() {
    isConfirmAnimation = true;

    // 目标点 (完全对标 flutter_novel)
    final targetX =
        mCornerX == 0 ? currentSize.width * 3 / 2 : 0 - currentSize.width / 2;
    final targetY = mCornerY == 0 ? 0.0 : currentSize.height;

    _animationTween = Tween(begin: mTouch, end: Offset(targetX, targetY));
    _animation = _animationTween!.animate(
      CurvedAnimation(parent: animationController!, curve: Curves.easeOut),
    );

    _animation!.addListener(_onAnimationUpdate);
    _animation!.addStatusListener(_onConfirmAnimationStatus);

    animationController!.reset();
    animationController!.forward();
  }

  void _onAnimationUpdate() {
    mTouch = _animation!.value;
    calBezierPoint();
    _onUpdate?.call();
  }

  void _onCancelAnimationStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      isStartAnimation = false;
      direction = PageDirection.none;
      _animation?.removeListener(_onAnimationUpdate);
      _animation?.removeStatusListener(_onCancelAnimationStatus);
      _onUpdate?.call();
    }
  }

  void _onConfirmAnimationStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      isStartAnimation = false;
      _animation?.removeListener(_onAnimationUpdate);
      _animation?.removeStatusListener(_onConfirmAnimationStatus);
      // 调用翻页回调
      onPageTurn?.call(direction);
      direction = PageDirection.none;
      _onUpdate?.call();
    }
  }

  @override
  void nextPage({int animationDuration = 300}) {
    if (isAnimating) return;
    direction = PageDirection.next;
    isTurnToNext = true;
    isStartAnimation = true;

    // 模拟从右下角开始
    mTouch = Offset(currentSize.width * 0.9, currentSize.height * 0.9);
    mCornerX = currentSize.width;
    mCornerY = currentSize.height;
    mIsRTandLB = false;

    calBezierPoint();
    _onUpdate?.call();

    _startConfirmAnimation();
  }

  @override
  void prevPage({int animationDuration = 300}) {
    if (isAnimating) return;
    direction = PageDirection.prev;
    isTurnToNext = false;
    isStartAnimation = true;

    // 模拟从左下角开始
    mTouch = Offset(currentSize.width * 0.1, currentSize.height * 0.9);
    mCornerX = 0;
    mCornerY = currentSize.height;
    mIsRTandLB = true;

    calBezierPoint();
    _onUpdate?.call();

    _startConfirmAnimation();
  }

  @override
  void cancel() {
    if (isAnimating) {
      animationController?.stop();
      isStartAnimation = false;
      direction = PageDirection.none;
      _onUpdate?.call();
    }
  }

  @override
  Widget buildPageTransition({
    required Widget currentPage,
    required Widget prevPage,
    required Widget nextPage,
    required Size size,
  }) {
    currentSize = size;

    return CustomPaint(
      size: size,
      painter: SimulationPainter(
        delegate: this,
        currentPagePicture: curPagePicture,
        nextPagePicture: isTurnToNext ? nextPagePicture : prevPagePicture,
        currentPageImage: curPageImage,
        backgroundColor: backgroundColor,
      ),
      child: currentPage,
    );
  }

  @override
  void dispose() {
    _animation?.removeListener(_onAnimationUpdate);
    curPagePicture = null;
    nextPagePicture = null;
    prevPagePicture = null;
    curPageImage?.dispose();
    curPageImage = null;
    super.dispose();
  }
}

/// 仿真翻页绘制器 (完全对标 flutter_novel)
class SimulationPainter extends CustomPainter {
  final SimulationDelegate delegate;
  final ui.Picture? currentPagePicture;
  final ui.Picture? nextPagePicture;
  final ui.Image? currentPageImage;
  final Color backgroundColor;

  SimulationPainter({
    required this.delegate,
    required this.currentPagePicture,
    required this.nextPagePicture,
    required this.currentPageImage,
    required this.backgroundColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (!delegate.isStartAnimation ||
        (delegate.mTouch.dx == 0 && delegate.mTouch.dy == 0)) {
      // 静止状态，绘制当前页
      if (currentPagePicture != null) {
        canvas.drawPicture(currentPagePicture!);
      }
      return;
    }

    // 按照 flutter_novel 的绘制顺序
    _drawTopPageCanvas(canvas, size);
    _drawBottomPageCanvas(canvas, size);
    _drawTopPageBackArea(canvas, size);
  }

  /// 画在最顶上的那页 (完全对标 flutter_novel drawTopPageCanvas)
  void _drawTopPageCanvas(Canvas canvas, Size size) {
    delegate.mTopPagePath.reset();

    delegate.mTopPagePath
        .moveTo(delegate.mCornerX == 0 ? size.width : 0, delegate.mCornerY);
    delegate.mTopPagePath
        .lineTo(delegate.mBezierStart1.dx, delegate.mBezierStart1.dy);
    delegate.mTopPagePath.quadraticBezierTo(
        delegate.mBezierControl1.dx,
        delegate.mBezierControl1.dy,
        delegate.mBezierEnd1.dx,
        delegate.mBezierEnd1.dy);
    delegate.mTopPagePath.lineTo(delegate.mTouch.dx, delegate.mTouch.dy);
    delegate.mTopPagePath
        .lineTo(delegate.mBezierEnd2.dx, delegate.mBezierEnd2.dy);
    delegate.mTopPagePath.quadraticBezierTo(
        delegate.mBezierControl2.dx,
        delegate.mBezierControl2.dy,
        delegate.mBezierStart2.dx,
        delegate.mBezierStart2.dy);
    delegate.mTopPagePath
        .lineTo(delegate.mCornerX, delegate.mCornerY == 0 ? size.height : 0);
    delegate.mTopPagePath.lineTo(delegate.mCornerX == 0 ? size.width : 0,
        delegate.mCornerY == 0 ? size.height : 0);
    delegate.mTopPagePath.close();

    // 去掉PATH圈在屏幕外的区域
    delegate.mTopPagePath = Path.combine(
        PathOperation.intersect,
        Path()
          ..moveTo(0, 0)
          ..lineTo(size.width, 0)
          ..lineTo(size.width, size.height)
          ..lineTo(0, size.height)
          ..close(),
        delegate.mTopPagePath);

    canvas.save();
    canvas.clipPath(delegate.mTopPagePath);

    if (currentPagePicture != null) {
      canvas.drawPicture(currentPagePicture!);
    }

    _drawTopPageShadow(canvas, size);
    canvas.restore();
  }

  /// 画顶部页的阴影 (完全对标 flutter_novel drawTopPageShadow)
  void _drawTopPageShadow(Canvas canvas, Size size) {
    int dx = delegate.mCornerX == 0 ? 5 : -5;
    int dy = delegate.mCornerY == 0 ? 5 : -5;

    Path shadowPath = Path.combine(
        PathOperation.intersect,
        Path()
          ..moveTo(0, 0)
          ..lineTo(size.width, 0)
          ..lineTo(size.width, size.height)
          ..lineTo(0, size.height)
          ..close(),
        Path()
          ..moveTo(delegate.mTouch.dx + dx, delegate.mTouch.dy + dy)
          ..lineTo(delegate.mBezierControl2.dx + dx,
              delegate.mBezierControl2.dy + dy)
          ..lineTo(delegate.mBezierControl1.dx + dx,
              delegate.mBezierControl1.dy + dy)
          ..close());

    canvas.drawShadow(shadowPath, Colors.black, 5, true);
  }

  /// 画翻起来的底下那页 (完全对标 flutter_novel drawBottomPageCanvas)
  void _drawBottomPageCanvas(Canvas canvas, Size size) {
    if (nextPagePicture == null) return;

    delegate.mBottomPagePath.reset();
    delegate.mBottomPagePath.moveTo(delegate.mCornerX, delegate.mCornerY);
    delegate.mBottomPagePath
        .lineTo(delegate.mBezierStart1.dx, delegate.mBezierStart1.dy);
    delegate.mBottomPagePath.quadraticBezierTo(
        delegate.mBezierControl1.dx,
        delegate.mBezierControl1.dy,
        delegate.mBezierEnd1.dx,
        delegate.mBezierEnd1.dy);
    delegate.mBottomPagePath
        .lineTo(delegate.mBezierEnd2.dx, delegate.mBezierEnd2.dy);
    delegate.mBottomPagePath.quadraticBezierTo(
        delegate.mBezierControl2.dx,
        delegate.mBezierControl2.dy,
        delegate.mBezierStart2.dx,
        delegate.mBezierStart2.dy);
    delegate.mBottomPagePath.close();

    // 排除三角形区域
    Path extraRegion = Path();
    extraRegion.moveTo(delegate.mTouch.dx, delegate.mTouch.dy);
    extraRegion.lineTo(delegate.mBezierVertex1.dx, delegate.mBezierVertex1.dy);
    extraRegion.lineTo(delegate.mBezierVertex2.dx, delegate.mBezierVertex2.dy);
    extraRegion.close();

    delegate.mBottomPagePath = Path.combine(
        PathOperation.difference, delegate.mBottomPagePath, extraRegion);

    // 去掉PATH圈在屏幕外的区域
    delegate.mBottomPagePath = Path.combine(
        PathOperation.intersect,
        Path()
          ..moveTo(0, 0)
          ..lineTo(size.width, 0)
          ..lineTo(size.width, size.height)
          ..lineTo(0, size.height)
          ..close(),
        delegate.mBottomPagePath);

    canvas.save();
    canvas.clipPath(delegate.mBottomPagePath, doAntiAlias: false);
    canvas.drawPicture(nextPagePicture!);
    _drawBottomPageShadow(canvas, size);
    canvas.restore();
  }

  /// 画底下那页的阴影 (完全对标 flutter_novel drawBottomPageShadow)
  void _drawBottomPageShadow(Canvas canvas, Size size) {
    double left;
    double right;
    List<Color> colors;

    if (delegate.mIsRTandLB) {
      left = 0;
      right = delegate.mTouchToCornerDis / 4;
      colors = [const Color(0xAA000000), Colors.transparent];
    } else {
      left = -delegate.mTouchToCornerDis / 4;
      right = 0;
      colors = [Colors.transparent, const Color(0xAA000000)];
    }

    canvas.translate(delegate.mBezierStart1.dx, delegate.mBezierStart1.dy);
    canvas.rotate(math.atan2(delegate.mBezierControl1.dx - delegate.mCornerX,
        delegate.mBezierControl2.dy - delegate.mCornerY));

    final shadowPaint = Paint()
      ..isAntiAlias = false
      ..style = PaintingStyle.fill
      ..shader = LinearGradient(colors: colors)
          .createShader(Rect.fromLTRB(left, 0, right, delegate.mMaxLength));

    canvas.drawRect(
        Rect.fromLTRB(left, 0, right, delegate.mMaxLength), shadowPaint);
  }

  /// 画在最顶上的那页的翻转过来的部分 (完全对标 flutter_novel drawTopPageBackArea)
  void _drawTopPageBackArea(Canvas canvas, Size size) {
    if (currentPageImage == null) return;

    delegate.mBottomPagePath.reset();
    delegate.mBottomPagePath.moveTo(delegate.mCornerX, delegate.mCornerY);
    delegate.mBottomPagePath
        .lineTo(delegate.mBezierStart1.dx, delegate.mBezierStart1.dy);
    delegate.mBottomPagePath.quadraticBezierTo(
        delegate.mBezierControl1.dx,
        delegate.mBezierControl1.dy,
        delegate.mBezierEnd1.dx,
        delegate.mBezierEnd1.dy);
    delegate.mBottomPagePath.lineTo(delegate.mTouch.dx, delegate.mTouch.dy);
    delegate.mBottomPagePath
        .lineTo(delegate.mBezierEnd2.dx, delegate.mBezierEnd2.dy);
    delegate.mBottomPagePath.quadraticBezierTo(
        delegate.mBezierControl2.dx,
        delegate.mBezierControl2.dy,
        delegate.mBezierStart2.dx,
        delegate.mBezierStart2.dy);
    delegate.mBottomPagePath.close();

    Path tempBackAreaPath = Path();
    tempBackAreaPath.moveTo(
        delegate.mBezierVertex1.dx, delegate.mBezierVertex1.dy);
    tempBackAreaPath.lineTo(
        delegate.mBezierVertex2.dx, delegate.mBezierVertex2.dy);
    tempBackAreaPath.lineTo(delegate.mTouch.dx, delegate.mTouch.dy);
    tempBackAreaPath.close();

    // 取path相交部分
    delegate.mTopBackAreaPagePath = Path.combine(
        PathOperation.intersect, tempBackAreaPath, delegate.mBottomPagePath);

    // 去掉PATH圈在屏幕外的区域
    delegate.mTopBackAreaPagePath = Path.combine(
        PathOperation.intersect,
        Path()
          ..moveTo(0, 0)
          ..lineTo(size.width, 0)
          ..lineTo(size.width, size.height)
          ..lineTo(0, size.height)
          ..close(),
        delegate.mTopBackAreaPagePath);

    canvas.save();
    canvas.clipPath(delegate.mTopBackAreaPagePath);
    canvas.drawPaint(Paint()..color = backgroundColor);

    canvas.save();
    canvas.translate(delegate.mBezierControl1.dx, delegate.mBezierControl1.dy);

    // 矩阵变换 (完全对标 flutter_novel)
    double dis = math.sqrt(
        math.pow((delegate.mCornerX - delegate.mBezierControl1.dx), 2) +
            math.pow((delegate.mBezierControl2.dy - delegate.mCornerY), 2));
    double sinAngle = (delegate.mCornerX - delegate.mBezierControl1.dx) / dis;
    double cosAngle = (delegate.mBezierControl2.dy - delegate.mCornerY) / dis;

    // 使用 Matrix4.identity() 构建变换矩阵
    Matrix4 matrix4 = Matrix4.identity();
    matrix4.setEntry(0, 0, -(1 - 2 * sinAngle * sinAngle));
    matrix4.setEntry(0, 1, 2 * sinAngle * cosAngle);
    matrix4.setEntry(1, 0, 2 * sinAngle * cosAngle);
    matrix4.setEntry(1, 1, 1 - 2 * sinAngle * sinAngle);
    matrix4.setEntry(0, 3, -delegate.mBezierControl1.dx);
    matrix4.setEntry(1, 3, -delegate.mBezierControl1.dy);

    canvas.transform(matrix4.storage);

    // 使用 Image 绘制背面 (对标 flutter_novel 注释)
    canvas.drawImageRect(currentPageImage!, Offset.zero & size,
        Offset.zero & size, Paint()..isAntiAlias = true);

    // 半透明遮罩
    canvas.drawPaint(Paint()..color = backgroundColor.withAlpha(0xAA));

    canvas.restore();

    _drawTopPageBackAreaShadow(canvas, size);
    canvas.restore();
  }

  /// 画翻起页的阴影 (完全对标 flutter_novel drawTopPageBackAreaShadow)
  void _drawTopPageBackAreaShadow(Canvas canvas, Size size) {
    double i = (delegate.mBezierStart1.dx + delegate.mBezierControl1.dx) / 2;
    double f1 = (i - delegate.mBezierControl1.dx).abs();
    double i1 = (delegate.mBezierStart2.dy + delegate.mBezierControl2.dy) / 2;
    double f2 = (i1 - delegate.mBezierControl2.dy).abs();
    double f3 = math.min(f1, f2);

    double left;
    double right;
    double width;

    if (delegate.mIsRTandLB) {
      left = delegate.mBezierStart1.dx - 1;
      right = delegate.mBezierStart1.dx + f3 + 1;
      width = right - left;
    } else {
      left = delegate.mBezierStart1.dx - f3 - 1;
      right = delegate.mBezierStart1.dx + 1;
      width = left - right;
    }

    canvas.translate(delegate.mBezierStart1.dx, delegate.mBezierStart1.dy);
    canvas.rotate(math.atan2(delegate.mBezierControl1.dx - delegate.mCornerX,
        delegate.mBezierControl2.dy - delegate.mCornerY));

    final shadowPaint = Paint()
      ..isAntiAlias = true
      ..style = PaintingStyle.fill
      ..shader = const LinearGradient(
        colors: [Colors.transparent, Color(0xAA000000)],
      ).createShader(Rect.fromLTRB(0, 0, width, delegate.mMaxLength));

    canvas.drawRect(
        Rect.fromLTRB(0, 0, width, delegate.mMaxLength), shadowPaint);
  }

  @override
  bool shouldRepaint(covariant SimulationPainter oldDelegate) {
    return delegate.mTouch != oldDelegate.delegate.mTouch ||
        delegate.isStartAnimation != oldDelegate.delegate.isStartAnimation ||
        currentPagePicture != oldDelegate.currentPagePicture ||
        nextPagePicture != oldDelegate.nextPagePicture;
  }
}
