import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

/// 仿真翻页绘制器（对标 flutter_novel SimulationTurnPageAnimation）
/// 核心优化：直接Canvas绘制，避免截图开销
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
    mIsRTandLB = (mCornerX == 0 && mCornerY == viewSize.height) ||
        (mCornerX == viewSize.width && mCornerY == 0);

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
    mTopPagePath.reset();

    mTopPagePath.moveTo(mCornerX == 0 ? viewSize.width : 0, mCornerY);
    mTopPagePath.lineTo(mBezierStart1.dx, mBezierStart1.dy);
    mTopPagePath.quadraticBezierTo(
        mBezierControl1.dx, mBezierControl1.dy, mBezierEnd1.dx, mBezierEnd1.dy);
    mTopPagePath.lineTo(mTouch.dx, mTouch.dy);
    mTopPagePath.lineTo(mBezierEnd2.dx, mBezierEnd2.dy);
    mTopPagePath.quadraticBezierTo(mBezierControl2.dx, mBezierControl2.dy,
        mBezierStart2.dx, mBezierStart2.dy);
    mTopPagePath.lineTo(mCornerX, mCornerY == 0 ? viewSize.height : 0);
    mTopPagePath.lineTo(mCornerX == 0 ? viewSize.width : 0,
        mCornerY == 0 ? viewSize.height : 0);
    mTopPagePath.close();

    // 去掉PATH圈在屏幕外的区域
    mTopPagePath = Path.combine(
      PathOperation.intersect,
      Path()
        ..moveTo(0, 0)
        ..lineTo(viewSize.width, 0)
        ..lineTo(viewSize.width, viewSize.height)
        ..lineTo(0, viewSize.height)
        ..close(),
      mTopPagePath,
    );

    canvas.save();
    canvas.clipPath(mTopPagePath);
    canvas.drawPicture(curPagePicture!);
    _drawTopPageShadow(canvas);
    canvas.restore();
  }

  /// 画顶部页的阴影
  void _drawTopPageShadow(Canvas canvas) {
    int dx = mCornerX == 0 ? 5 : -5;
    int dy = mCornerY == 0 ? 5 : -5;

    Path shadowPath = Path.combine(
      PathOperation.intersect,
      Path()
        ..moveTo(0, 0)
        ..lineTo(viewSize.width, 0)
        ..lineTo(viewSize.width, viewSize.height)
        ..lineTo(0, viewSize.height)
        ..close(),
      Path()
        ..moveTo(mTouch.dx + dx, mTouch.dy + dy)
        ..lineTo(mBezierControl2.dx + dx, mBezierControl2.dy + dy)
        ..lineTo(mBezierControl1.dx + dx, mBezierControl1.dy + dy)
        ..close(),
    );

    canvas.drawShadow(shadowPath, Colors.black, 5, true);
  }

  /// 画翻起来的底下那页
  void _drawBottomPageCanvas(Canvas canvas) {
    if (nextPagePicture == null) return;

    mBottomPagePath.reset();
    mBottomPagePath.moveTo(mCornerX, mCornerY);
    mBottomPagePath.lineTo(mBezierStart1.dx, mBezierStart1.dy);
    mBottomPagePath.quadraticBezierTo(
        mBezierControl1.dx, mBezierControl1.dy, mBezierEnd1.dx, mBezierEnd1.dy);
    mBottomPagePath.lineTo(mBezierEnd2.dx, mBezierEnd2.dy);
    mBottomPagePath.quadraticBezierTo(mBezierControl2.dx, mBezierControl2.dy,
        mBezierStart2.dx, mBezierStart2.dy);
    mBottomPagePath.close();

    // 排除三角形区域
    Path extraRegion = Path();
    extraRegion.moveTo(mTouch.dx, mTouch.dy);
    extraRegion.lineTo(mBezierVertex1.dx, mBezierVertex1.dy);
    extraRegion.lineTo(mBezierVertex2.dx, mBezierVertex2.dy);
    extraRegion.close();

    mBottomPagePath =
        Path.combine(PathOperation.difference, mBottomPagePath, extraRegion);

    // 去掉PATH圈在屏幕外的区域
    mBottomPagePath = Path.combine(
      PathOperation.intersect,
      Path()
        ..moveTo(0, 0)
        ..lineTo(viewSize.width, 0)
        ..lineTo(viewSize.width, viewSize.height)
        ..lineTo(0, viewSize.height)
        ..close(),
      mBottomPagePath,
    );

    canvas.save();
    canvas.clipPath(mBottomPagePath, doAntiAlias: false);
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
    tempBackAreaPath.moveTo(mBezierVertex1.dx, mBezierVertex1.dy);
    tempBackAreaPath.lineTo(mBezierVertex2.dx, mBezierVertex2.dy);
    tempBackAreaPath.lineTo(mTouch.dx, mTouch.dy);
    tempBackAreaPath.close();

    // 取path相交部分
    mTopBackAreaPagePath = Path.combine(
        PathOperation.intersect, tempBackAreaPath, mBottomPagePath);

    // 去掉PATH圈在屏幕外的区域
    mTopBackAreaPagePath = Path.combine(
      PathOperation.intersect,
      Path()
        ..moveTo(0, 0)
        ..lineTo(viewSize.width, 0)
        ..lineTo(viewSize.width, viewSize.height)
        ..lineTo(0, viewSize.height)
        ..close(),
      mTopBackAreaPagePath,
    );

    canvas.save();
    canvas.clipPath(mTopBackAreaPagePath);

    // 先画背景色
    canvas.drawPaint(Paint()..color = backgroundColor);

    canvas.save();
    canvas.translate(mBezierControl1.dx, mBezierControl1.dy);

    // 矩阵变换实现镜像翻转
    double dis = math.sqrt(math.pow(mCornerX - mBezierControl1.dx, 2) +
        math.pow(mBezierControl2.dy - mCornerY, 2));
    double sinAngle = (mCornerX - mBezierControl1.dx) / dis;
    double cosAngle = (mBezierControl2.dy - mCornerY) / dis;

    // 使用镜像变换矩阵
    final a = -(1 - 2 * sinAngle * sinAngle);
    final b = 2 * sinAngle * cosAngle;
    final c = 2 * sinAngle * cosAngle;
    final d = 1 - 2 * sinAngle * sinAngle;

    Matrix4 matrix4 = Matrix4(
      a,
      c,
      0,
      0,
      b,
      d,
      0,
      0,
      0,
      0,
      1,
      0,
      -mBezierControl1.dx * a - mBezierControl1.dy * b,
      -mBezierControl1.dx * c - mBezierControl1.dy * d,
      0,
      1,
    );
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
    double width;

    if (mIsRTandLB) {
      left = mBezierStart1.dx - 1;
      right = mBezierStart1.dx + f3 + 1;
      width = right - left;
    } else {
      left = mBezierStart1.dx - f3 - 1;
      right = mBezierStart1.dx + 1;
      width = left - right;
    }

    canvas.translate(mBezierStart1.dx, mBezierStart1.dy);
    canvas.rotate(math.atan2(
        mBezierControl1.dx - mCornerX, mBezierControl2.dy - mCornerY));

    final shadowPaint = Paint()
      ..isAntiAlias = true
      ..style = PaintingStyle.fill
      ..shader = const LinearGradient(
        colors: [Colors.transparent, Color(0xAA000000)],
      ).createShader(Rect.fromLTRB(0, 0, width, mMaxLength));

    canvas.drawRect(Rect.fromLTRB(0, 0, width, mMaxLength), shadowPaint);
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
