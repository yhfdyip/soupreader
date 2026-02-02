import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

/// 仿真翻页绘制器（完全对标 flutter_novel SimulationTurnPageAnimation）
/// 核心优化：使用 Picture 预渲染，避免截图开销
class SimulationPagePainter extends CustomPainter {
  /// 当前页面 Picture（被翻起的页面）
  final ui.Picture? curPagePicture;

  /// 目标页面 Picture（底下露出的页面）
  final ui.Picture? nextPagePicture;

  /// 触摸点
  final Offset touch;

  /// 视图尺寸
  final Size viewSize;

  /// 是否翻向下一页
  final bool isTurnToNext;

  /// 背景颜色
  final Color backgroundColor;

  /// 角点X（翻页的起始角）
  final double cornerX;

  /// 角点Y
  final double cornerY;

  SimulationPagePainter({
    required this.curPagePicture,
    required this.nextPagePicture,
    required this.touch,
    required this.viewSize,
    required this.isTurnToNext,
    required this.backgroundColor,
    required this.cornerX,
    required this.cornerY,
  });

  // 贝塞尔曲线控制点
  late Offset mTouch;
  late double mCornerX;
  late double mCornerY;
  late bool mIsRTandLB;
  late double mMiddleX;
  late double mMiddleY;
  late double mMaxLength;
  late double mTouchToCornerDis;

  late Offset mBezierStart1;
  late Offset mBezierControl1;
  late Offset mBezierVertex1;
  late Offset mBezierEnd1;
  late Offset mBezierStart2;
  late Offset mBezierControl2;
  late Offset mBezierVertex2;
  late Offset mBezierEnd2;

  // Path 对象
  Path mTopPagePath = Path();
  Path mBottomPagePath = Path();
  Path mTopBackAreaPagePath = Path();

  @override
  void paint(Canvas canvas, Size size) {
    if (curPagePicture == null) return;
    if (touch.dx == 0 && touch.dy == 0) {
      // 静止状态，直接画当前页
      canvas.drawPicture(curPagePicture!);
      return;
    }

    // 初始化
    mTouch = touch;
    mCornerX = cornerX;
    mCornerY = cornerY;

    // 判断是否右上左下
    mIsRTandLB = (mCornerX == 0 && (mCornerY - viewSize.height).abs() < 0.5) ||
        ((mCornerX - viewSize.width).abs() < 0.5 && mCornerY == 0);

    // 计算贝塞尔曲线点
    _calBezierPoint();

    // 按照 flutter_novel 的绘制顺序
    _drawTopPageCanvas(canvas);
    _drawBottomPageCanvas(canvas);
    _drawTopPageBackArea(canvas);
  }

  /// 计算贝塞尔曲线各点
  void _calBezierPoint() {
    mMiddleX = (mTouch.dx + mCornerX) / 2;
    mMiddleY = (mTouch.dy + mCornerY) / 2;

    mMaxLength =
        math.sqrt(math.pow(viewSize.width, 2) + math.pow(viewSize.height, 2));

    mBezierControl1 = Offset(
      mMiddleX -
          (mCornerY - mMiddleY) * (mCornerY - mMiddleY) / (mCornerX - mMiddleX),
      mCornerY,
    );

    double f4 = mCornerY - mMiddleY;
    if (f4 == 0) {
      mBezierControl2 = Offset(
        mCornerX,
        mMiddleY - (mCornerX - mMiddleX) * (mCornerX - mMiddleX) / 0.1,
      );
    } else {
      mBezierControl2 = Offset(
        mCornerX,
        mMiddleY -
            (mCornerX - mMiddleX) *
                (mCornerX - mMiddleX) /
                (mCornerY - mMiddleY),
      );
    }

    mBezierStart1 = Offset(
      mBezierControl1.dx - (mCornerX - mBezierControl1.dx) / 2,
      mCornerY,
    );

    // 边界修正
    if (mTouch.dx > 0 && mTouch.dx < viewSize.width) {
      if (mBezierStart1.dx < 0 || mBezierStart1.dx > viewSize.width) {
        if (mBezierStart1.dx < 0) {
          mBezierStart1 =
              Offset(viewSize.width - mBezierStart1.dx, mBezierStart1.dy);
        }

        double f1 = (mCornerX - mTouch.dx).abs();
        double f2 = viewSize.width * f1 / mBezierStart1.dx;
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
          mCornerY,
        );

        double f5 = mCornerY - mMiddleY;
        if (f5 == 0) {
          mBezierControl2 = Offset(
            mCornerX,
            mMiddleY - (mCornerX - mMiddleX) * (mCornerX - mMiddleX) / 0.1,
          );
        } else {
          mBezierControl2 = Offset(
            mCornerX,
            mMiddleY -
                (mCornerX - mMiddleX) *
                    (mCornerX - mMiddleX) /
                    (mCornerY - mMiddleY),
          );
        }

        mBezierStart1 = Offset(
          mBezierControl1.dx - (mCornerX - mBezierControl1.dx) / 2,
          mBezierStart1.dy,
        );
      }
    }

    mBezierStart2 = Offset(
      mCornerX,
      mBezierControl2.dy - (mCornerY - mBezierControl2.dy) / 2,
    );

    mTouchToCornerDis = math.sqrt(
        math.pow(mTouch.dx - mCornerX, 2) + math.pow(mTouch.dy - mCornerY, 2));

    mBezierEnd1 =
        _getCross(mTouch, mBezierControl1, mBezierStart1, mBezierStart2);
    mBezierEnd2 =
        _getCross(mTouch, mBezierControl2, mBezierStart1, mBezierStart2);

    mBezierVertex1 = Offset(
      (mBezierStart1.dx + 2 * mBezierControl1.dx + mBezierEnd1.dx) / 4,
      (2 * mBezierControl1.dy + mBezierStart1.dy + mBezierEnd1.dy) / 4,
    );

    mBezierVertex2 = Offset(
      (mBezierStart2.dx + 2 * mBezierControl2.dx + mBezierEnd2.dx) / 4,
      (2 * mBezierControl2.dy + mBezierStart2.dy + mBezierEnd2.dy) / 4,
    );
  }

  /// 获取交点
  Offset _getCross(Offset p1, Offset p2, Offset p3, Offset p4) {
    double k1 = (p2.dy - p1.dy) / (p2.dx - p1.dx);
    double b1 = ((p1.dx * p2.dy) - (p2.dx * p1.dy)) / (p1.dx - p2.dx);
    double k2 = (p4.dy - p3.dy) / (p4.dx - p3.dx);
    double b2 = ((p3.dx * p4.dy) - (p4.dx * p3.dy)) / (p3.dx - p4.dx);
    return Offset((b2 - b1) / (k1 - k2), k1 * ((b2 - b1) / (k1 - k2)) + b1);
  }

  /// 画在最顶上的那页
  void _drawTopPageCanvas(Canvas canvas) {
    // 构造 mTopPagePath 为“被卷起的区域” (Lifted Area)
    // 路径: Start1 -> Control1 -> End1 -> Touch -> End2 -> Control2 -> Start2 -> Corner
    mTopPagePath.reset();
    mTopPagePath.moveTo(mBezierStart1.dx, mBezierStart1.dy);
    mTopPagePath.quadraticBezierTo(
        mBezierControl1.dx, mBezierControl1.dy, mBezierEnd1.dx, mBezierEnd1.dy);
    mTopPagePath.lineTo(mTouch.dx, mTouch.dy);
    mTopPagePath.lineTo(mBezierEnd2.dx, mBezierEnd2.dy);
    mTopPagePath.quadraticBezierTo(mBezierControl2.dx, mBezierControl2.dy,
        mBezierStart2.dx, mBezierStart2.dy);
    mTopPagePath.lineTo(mCornerX, mCornerY);
    mTopPagePath.close();

    canvas.save();
    // 使用 inverseWinding 裁剪，保留路径“外部”的区域（即剩余的平整页面）
    // 这比 Path.combine(Difference) 更稳定且性能更好
    mTopPagePath.fillType = PathFillType.inverseWinding;
    canvas.clipPath(mTopPagePath);
    
    canvas.drawPicture(curPagePicture!);
    _drawTopPageShadow(canvas);
    canvas.restore();
  }

  /// 画顶部页的阴影
  void _drawTopPageShadow(Canvas canvas) {
    // Canvas 已经被裁剪为“剩余区域”，直接绘制阴影即可，超出部分会自动被裁剪
    
    // === 第一条阴影 ===
    final double degree = mIsRTandLB
        ? math.pi / 4 - math.atan2(mBezierControl1.dy - mTouch.dy, mTouch.dx - mBezierControl1.dx)
        : math.pi / 4 - math.atan2(mTouch.dy - mBezierControl1.dy, mTouch.dx - mBezierControl1.dx);
    
    final double d1 = 25.0 * 1.414 * math.cos(degree);
    final double d2 = 25.0 * 1.414 * math.sin(degree);
    final double x = mTouch.dx + d1;
    final double y = mIsRTandLB ? (mTouch.dy + d2) : (mTouch.dy - d2);
    
    Path shadowPath1 = Path()
      ..moveTo(x, y)
      ..lineTo(mTouch.dx, mTouch.dy)
      ..lineTo(mBezierControl1.dx, mBezierControl1.dy)
      ..lineTo(mBezierStart1.dx, mBezierStart1.dy)
      ..close();
    
    // 绘制第一条阴影
    canvas.save();
    canvas.clipPath(shadowPath1);
    
    double leftX = mIsRTandLB ? mBezierControl1.dx : (mBezierControl1.dx - 25);
    double rightX = mIsRTandLB ? (mBezierControl1.dx + 25) : (mBezierControl1.dx + 1);
    List<Color> colors1 = mIsRTandLB
        ? [const Color(0x80111111), Colors.transparent]
        : [Colors.transparent, const Color(0x80111111)];
    
    double rotateDegrees = math.atan2(
      mTouch.dx - mBezierControl1.dx,
      mBezierControl1.dy - mTouch.dy,
    );
    
    canvas.translate(mBezierControl1.dx, mBezierControl1.dy);
    canvas.rotate(rotateDegrees);
    
    final paint1 = Paint()
      ..isAntiAlias = true
      ..style = PaintingStyle.fill
      ..shader = LinearGradient(colors: colors1)
          .createShader(Rect.fromLTRB(leftX - mBezierControl1.dx, -mMaxLength, 
                                      rightX - mBezierControl1.dx, 0));
    
    canvas.drawRect(
      Rect.fromLTRB(leftX - mBezierControl1.dx, -mMaxLength, 
                    rightX - mBezierControl1.dx, 0),
      paint1,
    );
    canvas.restore();
    
    // === 第二条阴影 ===
    Path shadowPath2 = Path()
      ..moveTo(x, y)
      ..lineTo(mTouch.dx, mTouch.dy)
      ..lineTo(mBezierControl2.dx, mBezierControl2.dy)
      ..lineTo(mBezierStart2.dx, mBezierStart2.dy)
      ..close();
    
    canvas.save();
    canvas.clipPath(shadowPath2);
    
    double topY = mIsRTandLB ? mBezierControl2.dy : (mBezierControl2.dy - 25);
    double bottomY = mIsRTandLB ? (mBezierControl2.dy + 25) : (mBezierControl2.dy + 1);
    List<Color> colors2 = mIsRTandLB
        ? [const Color(0x80111111), Colors.transparent]
        : [Colors.transparent, const Color(0x80111111)];
    
    double rotateDegrees2 = math.atan2(
      mBezierControl2.dy - mTouch.dy,
      mBezierControl2.dx - mTouch.dx,
    );
    
    canvas.translate(mBezierControl2.dx, mBezierControl2.dy);
    canvas.rotate(rotateDegrees2);
    
    final paint2 = Paint()
      ..isAntiAlias = true
      ..style = PaintingStyle.fill
      ..shader = LinearGradient(colors: colors2)
          .createShader(Rect.fromLTRB(-mMaxLength, topY - mBezierControl2.dy, 
                                      0, bottomY - mBezierControl2.dy));
    
    canvas.drawRect(
      Rect.fromLTRB(-mMaxLength, topY - mBezierControl2.dy, 
                    0, bottomY - mBezierControl2.dy),
      paint2,
    );
    canvas.restore();
  }

  /// 画翻起来的底下那页
  void _drawBottomPageCanvas(Canvas canvas) {
    if (nextPagePicture == null) return;

    // 构造 mBottomPagePath 为“露出的下一页区域” (Revealed Area)
    // 对应 Legado 的做法，只绘制折痕以下的部分，避免使用复杂的布尔运算
    // 路径: Corner -> Start1 -> Vertex1 -> Vertex2 -> Start2 -> Corner
    mBottomPagePath.reset();
    mBottomPagePath.moveTo(mCornerX, mCornerY);
    mBottomPagePath.lineTo(mBezierStart1.dx, mBezierStart1.dy);
    mBottomPagePath.lineTo(mBezierVertex1.dx, mBezierVertex1.dy);
    mBottomPagePath.lineTo(mBezierVertex2.dx, mBezierVertex2.dy);
    mBottomPagePath.lineTo(mBezierStart2.dx, mBezierStart2.dy);
    mBottomPagePath.close();

    canvas.save();
    canvas.clipPath(mBottomPagePath, doAntiAlias: true);
    canvas.drawPicture(nextPagePicture!);
    _drawBottomPageShadow(canvas);
    canvas.restore();
  }

  /// 画底下那页的阴影
  void _drawBottomPageShadow(Canvas canvas) {
    double left;
    double right;
    List<Color> colors;

    if (mIsRTandLB) {
      left = 0;
      right = mTouchToCornerDis / 4;
      colors = [const Color(0xAA000000), Colors.transparent];
    } else {
      left = -mTouchToCornerDis / 4;
      right = 0;
      colors = [Colors.transparent, const Color(0xAA000000)];
    }

    canvas.translate(mBezierStart1.dx, mBezierStart1.dy);
    canvas.rotate(math.atan2(
        mBezierControl1.dx - mCornerX, mBezierControl2.dy - mCornerY));

    final shadowPaint = Paint()
      ..isAntiAlias = false
      ..style = PaintingStyle.fill
      ..shader = LinearGradient(colors: colors)
          .createShader(Rect.fromLTRB(left, 0, right, mMaxLength));

    canvas.drawRect(Rect.fromLTRB(left, 0, right, mMaxLength), shadowPaint);
  }

  /// 画在最顶上的那页的翻转过来的部分
  void _drawTopPageBackArea(Canvas canvas) {
    if (curPagePicture == null) return;

    mBottomPagePath.reset();
    mBottomPagePath.moveTo(mCornerX, mCornerY);
    mBottomPagePath.lineTo(mBezierStart1.dx, mBezierStart1.dy);
    mBottomPagePath.quadraticBezierTo(
        mBezierControl1.dx, mBezierControl1.dy, mBezierEnd1.dx, mBezierEnd1.dy);
    mBottomPagePath.lineTo(mTouch.dx, mTouch.dy);
    mBottomPagePath.lineTo(mBezierEnd2.dx, mBezierEnd2.dy);
    mBottomPagePath.quadraticBezierTo(mBezierControl2.dx, mBezierControl2.dy,
        mBezierStart2.dx, mBezierStart2.dy);
    mBottomPagePath.close();

    Path tempBackAreaPath = Path();
    tempBackAreaPath.moveTo(mBezierVertex2.dx, mBezierVertex2.dy);
    tempBackAreaPath.lineTo(mBezierVertex1.dx, mBezierVertex1.dy);
    tempBackAreaPath.lineTo(mBezierEnd1.dx, mBezierEnd1.dy);
    tempBackAreaPath.lineTo(mTouch.dx, mTouch.dy);
    tempBackAreaPath.lineTo(mBezierEnd2.dx, mBezierEnd2.dy);
    tempBackAreaPath.close();

    // 不需要使用 Path.combine
    canvas.save();
    // 1. 裁剪到“被卷起的区域”内 (mTopPagePath 已经是 Lifted Area)
    mTopPagePath.fillType = PathFillType.winding; // 恢复正常 winding
    canvas.clipPath(mTopPagePath); 
    // 2. 裁剪到“背面五边形”内
    canvas.clipPath(tempBackAreaPath);

    // 先画背景色
    canvas.drawPaint(Paint()..color = backgroundColor);

    canvas.save();
    canvas.translate(mBezierControl1.dx, mBezierControl1.dy);

    // 矩阵变换实现镜像翻转
    double dis = math.sqrt(math.pow(mCornerX - mBezierControl1.dx, 2) +
        math.pow(mBezierControl2.dy - mCornerY, 2));
    double sinAngle = (mCornerX - mBezierControl1.dx) / dis;
    double cosAngle = (mBezierControl2.dy - mCornerY) / dis;

    // 使用镜像变换矩阵（沿着翻页方向的轴镜像）
    // 注意: Matrix4 是 column-major, 需要按列填充
    final a = -(1 - 2 * sinAngle * sinAngle);
    final b = 2 * sinAngle * cosAngle;
    final c = 2 * sinAngle * cosAngle;
    final d = 1 - 2 * sinAngle * sinAngle;
    
    // 使用 Matrix4.identity() 并通过 setEntry 设置，更清晰且不易出错
    final matrix4 = Matrix4.identity();
    // 设置 2x2 变换矩阵 (column-major)
    matrix4.setEntry(0, 0, a);  // 第0列第0行
    matrix4.setEntry(1, 0, c);  // 第0列第1行
    matrix4.setEntry(0, 1, b);  // 第1列第0行
    matrix4.setEntry(1, 1, d);  // 第1列第1行
    // 设置平移分量
    matrix4.setEntry(0, 3, -mBezierControl1.dx * a - mBezierControl1.dy * b);
    matrix4.setEntry(1, 3, -mBezierControl1.dx * c - mBezierControl1.dy * d);
    
    canvas.transform(matrix4.storage);

    // 绘制翻转的页面
    canvas.drawPicture(curPagePicture!);

    // 添加半透明遮罩模拟纸张背面
    canvas.drawPaint(Paint()..color = backgroundColor.withValues(alpha: 0.67));

    canvas.restore();

    _drawTopPageBackAreaShadow(canvas);
    canvas.restore();
  }

  /// 画翻起页的阴影
  void _drawTopPageBackAreaShadow(Canvas canvas) {
    double i = (mBezierStart1.dx + mBezierControl1.dx) / 2;
    double f1 = (i - mBezierControl1.dx).abs();
    double i1 = (mBezierStart2.dy + mBezierControl2.dy) / 2;
    double f2 = (i1 - mBezierControl2.dy).abs();
    double f3 = math.min(f1, f2);

    double left;
    double right;
    List<Color> colors;

    // 阴影颜色配置：Legado 使用的是 0x333333 (透明) -> 0xB0333333 (深色)
    // 也就是从折痕(Start1)向外变深，模拟圆柱体的光照效果(折痕处是高光)
    const Color shadowColor = Color(0xAA000000); // 对应 Legado 的 -0x4fcccccd (approx)
    const Color transparentColor = Colors.transparent; // 对应 Legado 的 0x333333

    if (mIsRTandLB) {
      // 阴影在折痕右侧 (0 -> f3)
      left = -1;
      right = f3 + 1;
      // Legado (LL): Left(Near/Fold) -> Right(Far). Colors: [Transp, Dark]
      colors = [transparentColor, shadowColor];
    } else {
      // 阴影在折痕左侧 (-f3 -> 0)
      left = -f3 - 1;
      right = 1;
      // Legado (RL): Right(Near/Fold) -> Left(Far). Colors: [Transp, Dark]
      // Canvas Gradient is Left->Right.
      // So Left(Far)=Dark, Right(Near)=Transp.
      colors = [shadowColor, transparentColor];
    }

    canvas.translate(mBezierStart1.dx, mBezierStart1.dy);
    canvas.rotate(math.atan2(
        mBezierControl1.dx - mCornerX, mBezierControl2.dy - mCornerY));

    final shadowPaint = Paint()
      ..isAntiAlias = true
      ..style = PaintingStyle.fill
      ..shader = LinearGradient(
        colors: colors,
      ).createShader(Rect.fromLTRB(left, 0, right, mMaxLength));

    canvas.drawRect(Rect.fromLTRB(left, 0, right, mMaxLength), shadowPaint);
  }

  @override
  bool shouldRepaint(covariant SimulationPagePainter oldDelegate) {
    return touch != oldDelegate.touch ||
        curPagePicture != oldDelegate.curPagePicture ||
        nextPagePicture != oldDelegate.nextPagePicture ||
        cornerX != oldDelegate.cornerX ||
        cornerY != oldDelegate.cornerY;
  }
}
