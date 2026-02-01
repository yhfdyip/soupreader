import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

/// 仿真翻页绘制器（完全对标 Legado SimulationPageDelegate）
/// 使用贝塞尔曲线模拟真实书页翻转效果
class SimulationPagePainter extends CustomPainter {
  /// 当前被翻起的页面图片（NEXT时是curPage，PREV时是prevPage）
  final ui.Image? curBitmap;

  /// 底层显示的页面图片（NEXT时是nextPage，PREV时是curPage）
  final ui.Image? nextBitmap;
  final double touchX;
  final double touchY;
  final int viewWidth;
  final int viewHeight;
  final bool isNext;
  final Color backgroundColor;

  /// 角点X（翻页的起始角）
  final int cornerX;

  /// 角点Y
  final int cornerY;

  SimulationPagePainter({
    required this.curBitmap,
    required this.nextBitmap,
    required this.touchX,
    required this.touchY,
    required this.viewWidth,
    required this.viewHeight,
    required this.isNext,
    required this.backgroundColor,
    required this.cornerX,
    required this.cornerY,
  });

  // 贝塞尔曲线控制点（对标 Legado 的 mBezierXxx）
  late double mTouchX;
  late double mTouchY;
  late double mMiddleX;
  late double mMiddleY;
  late double mTouchToCornerDis;
  late bool mIsRtOrLb;
  late double mDegrees;
  late double mMaxLength;

  late Offset mBezierStart1;
  late Offset mBezierControl1;
  late Offset mBezierVertex1;
  late Offset mBezierEnd1;
  late Offset mBezierStart2;
  late Offset mBezierControl2;
  late Offset mBezierVertex2;
  late Offset mBezierEnd2;

  @override
  void paint(Canvas canvas, Size size) {
    if (curBitmap == null) return;

    mMaxLength =
        math.sqrt(viewWidth * viewWidth + viewHeight * viewHeight).toDouble();

    // 计算角点类型
    mIsRtOrLb = (cornerX == 0 && cornerY == viewHeight) ||
        (cornerY == 0 && cornerX == viewWidth);

    // 计算贝塞尔曲线各点
    _calcPoints();

    // 按照 Legado 的绘制顺序
    // 1. 绘制当前页区域（被翻开后露出的部分 - 在贝塞尔路径之外）
    _drawCurrentPageArea(canvas, curBitmap!);

    // 2. 绘制下一页区域及阴影
    if (nextBitmap != null) {
      _drawNextPageAreaAndShadow(canvas, nextBitmap!);
    }

    // 3. 绘制当前页阴影
    _drawCurrentPageShadow(canvas);

    // 4. 绘制翻起页背面
    _drawCurrentBackArea(canvas, curBitmap!);
  }

  /// 计算贝塞尔曲线各点（完全对标 Legado calcPoints）
  void _calcPoints() {
    mTouchX = touchX;
    mTouchY = touchY;

    mMiddleX = (mTouchX + cornerX) / 2;
    mMiddleY = (mTouchY + cornerY) / 2;

    double bezierControl1X;
    double bezierControl1Y = cornerY.toDouble();

    // 对标: mBezierControl1.x = mMiddleX - (mCornerY - mMiddleY) * (mCornerY - mMiddleY) / (mCornerX - mMiddleX)
    if ((cornerX - mMiddleX).abs() < 0.0001) {
      bezierControl1X = mMiddleX;
    } else {
      bezierControl1X = mMiddleX -
          (cornerY - mMiddleY) * (cornerY - mMiddleY) / (cornerX - mMiddleX);
    }

    double bezierControl2X = cornerX.toDouble();
    double bezierControl2Y;

    // 对标: mBezierControl2.y = mMiddleY - (mCornerX - mMiddleX) * (mCornerX - mMiddleX) / (mCornerY - mMiddleY)
    final f4 = cornerY - mMiddleY;
    if (f4.abs() < 0.0001) {
      bezierControl2Y =
          mMiddleY - (cornerX - mMiddleX) * (cornerX - mMiddleX) / 0.1;
    } else {
      bezierControl2Y =
          mMiddleY - (cornerX - mMiddleX) * (cornerX - mMiddleX) / f4;
    }

    double bezierStart1X = bezierControl1X - (cornerX - bezierControl1X) / 2;
    double bezierStart1Y = cornerY.toDouble();

    // 边界修正（对标 Legado 的边界处理）
    if (mTouchX > 0 && mTouchX < viewWidth) {
      if (bezierStart1X < 0 || bezierStart1X > viewWidth) {
        if (bezierStart1X < 0) {
          bezierStart1X = viewWidth - bezierStart1X;
        }

        final f1 = (cornerX - mTouchX).abs();
        final f2 = viewWidth * f1 / bezierStart1X;
        mTouchX = (cornerX - f2).abs();

        final f3 = (cornerX - mTouchX).abs() * (cornerY - mTouchY).abs() / f1;
        mTouchY = (cornerY - f3).abs();

        mMiddleX = (mTouchX + cornerX) / 2;
        mMiddleY = (mTouchY + cornerY) / 2;

        if ((cornerX - mMiddleX).abs() < 0.0001) {
          bezierControl1X = mMiddleX;
        } else {
          bezierControl1X = mMiddleX -
              (cornerY - mMiddleY) *
                  (cornerY - mMiddleY) /
                  (cornerX - mMiddleX);
        }
        bezierControl1Y = cornerY.toDouble();

        bezierControl2X = cornerX.toDouble();
        final f5 = cornerY - mMiddleY;
        if (f5.abs() < 0.0001) {
          bezierControl2Y =
              mMiddleY - (cornerX - mMiddleX) * (cornerX - mMiddleX) / 0.1;
        } else {
          bezierControl2Y =
              mMiddleY - (cornerX - mMiddleX) * (cornerX - mMiddleX) / f5;
        }

        bezierStart1X = bezierControl1X - (cornerX - bezierControl1X) / 2;
      }
    }

    double bezierStart2X = cornerX.toDouble();
    double bezierStart2Y = bezierControl2Y - (cornerY - bezierControl2Y) / 2;

    mTouchToCornerDis = math.sqrt((mTouchX - cornerX) * (mTouchX - cornerX) +
        (mTouchY - cornerY) * (mTouchY - cornerY));

    // 计算交点
    final end1 = _getCross(
      Offset(mTouchX, mTouchY),
      Offset(bezierControl1X, bezierControl1Y),
      Offset(bezierStart1X, bezierStart1Y),
      Offset(bezierStart2X, bezierStart2Y),
    );

    final end2 = _getCross(
      Offset(mTouchX, mTouchY),
      Offset(bezierControl2X, bezierControl2Y),
      Offset(bezierStart1X, bezierStart1Y),
      Offset(bezierStart2X, bezierStart2Y),
    );

    mBezierStart1 = Offset(bezierStart1X, bezierStart1Y);
    mBezierControl1 = Offset(bezierControl1X, bezierControl1Y);
    mBezierEnd1 = end1;
    mBezierVertex1 = Offset(
      (bezierStart1X + 2 * bezierControl1X + end1.dx) / 4,
      (2 * bezierControl1Y + bezierStart1Y + end1.dy) / 4,
    );

    mBezierStart2 = Offset(bezierStart2X, bezierStart2Y);
    mBezierControl2 = Offset(bezierControl2X, bezierControl2Y);
    mBezierEnd2 = end2;
    mBezierVertex2 = Offset(
      (bezierStart2X + 2 * bezierControl2X + end2.dx) / 4,
      (2 * bezierControl2Y + bezierStart2Y + end2.dy) / 4,
    );

    mDegrees = math.atan2(
          bezierControl1X - cornerX,
          bezierControl2Y - cornerY,
        ) *
        180 /
        math.pi;
  }

  /// 求两条直线的交点（对标 Legado getCross）
  Offset _getCross(Offset p1, Offset p2, Offset p3, Offset p4) {
    final a1 = (p2.dy - p1.dy) / (p2.dx - p1.dx);
    final b1 = (p1.dx * p2.dy - p2.dx * p1.dy) / (p1.dx - p2.dx);
    final a2 = (p4.dy - p3.dy) / (p4.dx - p3.dx);
    final b2 = (p3.dx * p4.dy - p4.dx * p3.dy) / (p3.dx - p4.dx);
    final x = (b2 - b1) / (a1 - a2);
    final y = a1 * x + b1;
    return Offset(x, y);
  }

  /// 绘制当前页区域（对标 Legado drawCurrentPageArea）
  /// 重点：使用 clipOutPath 在贝塞尔曲线路径之外绘制
  void _drawCurrentPageArea(Canvas canvas, ui.Image bitmap) {
    // 构建贝塞尔曲线路径 mPath0
    final path0 = Path();
    path0.moveTo(mBezierStart1.dx, mBezierStart1.dy);
    path0.quadraticBezierTo(
        mBezierControl1.dx, mBezierControl1.dy, mBezierEnd1.dx, mBezierEnd1.dy);
    path0.lineTo(mTouchX, mTouchY);
    path0.lineTo(mBezierEnd2.dx, mBezierEnd2.dy);
    path0.quadraticBezierTo(mBezierControl2.dx, mBezierControl2.dy,
        mBezierStart2.dx, mBezierStart2.dy);
    path0.lineTo(cornerX.toDouble(), cornerY.toDouble());
    path0.close();

    canvas.save();
    // 对标 Android: canvas.clipOutPath(mPath0) - 在路径之外绘制
    // Flutter 使用 PathOperation.difference 实现
    final fullRect = Path()
      ..addRect(
          Rect.fromLTWH(0, 0, viewWidth.toDouble(), viewHeight.toDouble()));
    canvas.clipPath(Path.combine(PathOperation.difference, fullRect, path0));
    canvas.drawImage(bitmap, Offset.zero, Paint());
    canvas.restore();
  }

  /// 绘制下一页区域及阴影（对标 Legado drawNextPageAreaAndShadow）
  void _drawNextPageAreaAndShadow(Canvas canvas, ui.Image bitmap) {
    // mPath1: 由贝塞尔顶点围成的区域
    final path1 = Path();
    path1.moveTo(mBezierStart1.dx, mBezierStart1.dy);
    path1.lineTo(mBezierVertex1.dx, mBezierVertex1.dy);
    path1.lineTo(mBezierVertex2.dx, mBezierVertex2.dy);
    path1.lineTo(mBezierStart2.dx, mBezierStart2.dy);
    path1.lineTo(cornerX.toDouble(), cornerY.toDouble());
    path1.close();

    // mPath0: 贝塞尔曲线路径
    final path0 = Path();
    path0.moveTo(mBezierStart1.dx, mBezierStart1.dy);
    path0.quadraticBezierTo(
        mBezierControl1.dx, mBezierControl1.dy, mBezierEnd1.dx, mBezierEnd1.dy);
    path0.lineTo(mTouchX, mTouchY);
    path0.lineTo(mBezierEnd2.dx, mBezierEnd2.dy);
    path0.quadraticBezierTo(mBezierControl2.dx, mBezierControl2.dy,
        mBezierStart2.dx, mBezierStart2.dy);
    path0.lineTo(cornerX.toDouble(), cornerY.toDouble());
    path0.close();

    canvas.save();
    // 先裁剪到 path0，再裁剪到 path1（交集）
    canvas.clipPath(path0);
    canvas.clipPath(path1);
    canvas.drawImage(bitmap, Offset.zero, Paint());

    // 绘制阴影
    final shadowWidth = mTouchToCornerDis / 4;
    final leftX = mIsRtOrLb ? mBezierStart1.dx : mBezierStart1.dx - shadowWidth;
    final rightX =
        mIsRtOrLb ? mBezierStart1.dx + shadowWidth : mBezierStart1.dx;

    canvas.save();
    canvas.translate(mBezierStart1.dx, mBezierStart1.dy);
    canvas.rotate(mDegrees * math.pi / 180);

    final shadowPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(leftX - mBezierStart1.dx, 0),
        Offset(rightX - mBezierStart1.dx, 0),
        mIsRtOrLb
            ? [const Color(0x00111111), const Color(0xEE111111)]
            : [const Color(0xEE111111), const Color(0x00111111)],
      );

    canvas.drawRect(
      Rect.fromLTRB(
          leftX - mBezierStart1.dx, 0, rightX - mBezierStart1.dx, mMaxLength),
      shadowPaint,
    );
    canvas.restore();
    canvas.restore();
  }

  /// 绘制当前页阴影（对标 Legado drawCurrentPageShadow）
  void _drawCurrentPageShadow(Canvas canvas) {
    final degree = mIsRtOrLb
        ? math.pi / 4 -
            math.atan2(
                mBezierControl1.dy - mTouchY, mTouchX - mBezierControl1.dx)
        : math.pi / 4 -
            math.atan2(
                mTouchY - mBezierControl1.dy, mTouchX - mBezierControl1.dx);

    final d1 = 25.0 * 1.414 * math.cos(degree);
    final d2 = 25.0 * 1.414 * math.sin(degree);
    final x = mTouchX + d1;
    final y = mIsRtOrLb ? (mTouchY + d2) : (mTouchY - d2);

    final path1 = Path();
    path1.moveTo(x, y);
    path1.lineTo(mTouchX, mTouchY);
    path1.lineTo(mBezierControl1.dx, mBezierControl1.dy);
    path1.lineTo(mBezierStart1.dx, mBezierStart1.dy);
    path1.close();

    final path0 = Path();
    path0.moveTo(mBezierStart1.dx, mBezierStart1.dy);
    path0.quadraticBezierTo(
        mBezierControl1.dx, mBezierControl1.dy, mBezierEnd1.dx, mBezierEnd1.dy);
    path0.lineTo(mTouchX, mTouchY);
    path0.lineTo(mBezierEnd2.dx, mBezierEnd2.dy);
    path0.quadraticBezierTo(mBezierControl2.dx, mBezierControl2.dy,
        mBezierStart2.dx, mBezierStart2.dy);
    path0.lineTo(cornerX.toDouble(), cornerY.toDouble());
    path0.close();

    canvas.save();
    // clipOutPath(path0) + clipPath(path1)
    final fullRect = Path()
      ..addRect(
          Rect.fromLTWH(0, 0, viewWidth.toDouble(), viewHeight.toDouble()));
    canvas.clipPath(Path.combine(PathOperation.difference, fullRect, path0));
    canvas.clipPath(path1);

    final leftX = mIsRtOrLb ? mBezierControl1.dx : mBezierControl1.dx - 25;
    final rightX = mIsRtOrLb ? mBezierControl1.dx + 25 : mBezierControl1.dx + 1;

    final rotateDegrees =
        math.atan2(mTouchX - mBezierControl1.dx, mBezierControl1.dy - mTouchY);

    canvas.translate(mBezierControl1.dx, mBezierControl1.dy);
    canvas.rotate(rotateDegrees);

    final shadowPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(leftX - mBezierControl1.dx, -mMaxLength),
        Offset(rightX - mBezierControl1.dx, -mMaxLength),
        mIsRtOrLb
            ? [const Color(0x00111111), const Color(0x80111111)]
            : [const Color(0x80111111), const Color(0x00111111)],
      );

    canvas.drawRect(
      Rect.fromLTRB(leftX - mBezierControl1.dx, -mMaxLength,
          rightX - mBezierControl1.dx, 0),
      shadowPaint,
    );
    canvas.restore();

    // 第二部分阴影（垂直方向）
    final path1b = Path();
    path1b.moveTo(x, y);
    path1b.lineTo(mTouchX, mTouchY);
    path1b.lineTo(mBezierControl2.dx, mBezierControl2.dy);
    path1b.lineTo(mBezierStart2.dx, mBezierStart2.dy);
    path1b.close();

    canvas.save();
    canvas.clipPath(Path.combine(PathOperation.difference, fullRect, path0));
    canvas.clipPath(path1b);

    final leftY = mIsRtOrLb ? mBezierControl2.dy : mBezierControl2.dy - 25;
    final rightY = mIsRtOrLb ? mBezierControl2.dy + 25 : mBezierControl2.dy + 1;

    final rotateDegrees2 =
        math.atan2(mBezierControl2.dy - mTouchY, mBezierControl2.dx - mTouchX);

    canvas.translate(mBezierControl2.dx, mBezierControl2.dy);
    canvas.rotate(rotateDegrees2);

    final hmg = math.sqrt(mBezierControl2.dx * mBezierControl2.dx +
        (mBezierControl2.dy < 0
            ? (mBezierControl2.dy - viewHeight) *
                (mBezierControl2.dy - viewHeight)
            : mBezierControl2.dy * mBezierControl2.dy));

    final shadowPaint2 = Paint()
      ..shader = ui.Gradient.linear(
        Offset(hmg > mMaxLength ? -25 - hmg + mMaxLength : -mMaxLength,
            leftY - mBezierControl2.dy),
        Offset(hmg > mMaxLength ? mMaxLength - hmg : 0,
            rightY - mBezierControl2.dy),
        mIsRtOrLb
            ? [const Color(0x00111111), const Color(0x80111111)]
            : [const Color(0x80111111), const Color(0x00111111)],
      );

    canvas.drawRect(
      Rect.fromLTRB(
        hmg > mMaxLength ? -25 - hmg + mMaxLength : -mMaxLength,
        leftY - mBezierControl2.dy,
        hmg > mMaxLength ? mMaxLength - hmg : 0,
        rightY - mBezierControl2.dy,
      ),
      shadowPaint2,
    );
    canvas.restore();
  }

  /// 绘制翻起页背面（对标 Legado drawCurrentBackArea）
  void _drawCurrentBackArea(Canvas canvas, ui.Image bitmap) {
    final i = ((mBezierStart1.dx + mBezierControl1.dx) / 2).toInt();
    final f1 = (i - mBezierControl1.dx).abs();
    final i1 = ((mBezierStart2.dy + mBezierControl2.dy) / 2).toInt();
    final f2 = (i1 - mBezierControl2.dy).abs();
    final f3 = math.min(f1, f2);

    // mPath1: 翻起部分的区域
    final path1 = Path();
    path1.moveTo(mBezierVertex2.dx, mBezierVertex2.dy);
    path1.lineTo(mBezierVertex1.dx, mBezierVertex1.dy);
    path1.lineTo(mBezierEnd1.dx, mBezierEnd1.dy);
    path1.lineTo(mTouchX, mTouchY);
    path1.lineTo(mBezierEnd2.dx, mBezierEnd2.dy);
    path1.close();

    // mPath0
    final path0 = Path();
    path0.moveTo(mBezierStart1.dx, mBezierStart1.dy);
    path0.quadraticBezierTo(
        mBezierControl1.dx, mBezierControl1.dy, mBezierEnd1.dx, mBezierEnd1.dy);
    path0.lineTo(mTouchX, mTouchY);
    path0.lineTo(mBezierEnd2.dx, mBezierEnd2.dy);
    path0.quadraticBezierTo(mBezierControl2.dx, mBezierControl2.dy,
        mBezierStart2.dx, mBezierStart2.dy);
    path0.lineTo(cornerX.toDouble(), cornerY.toDouble());
    path0.close();

    canvas.save();
    canvas.clipPath(path0);
    canvas.clipPath(path1);

    // 绘制背景色
    canvas.drawRect(
      Rect.fromLTWH(0, 0, viewWidth.toDouble(), viewHeight.toDouble()),
      Paint()..color = backgroundColor,
    );

    // 绘制镜像翻转的页面
    final dis = math.sqrt(
        (cornerX - mBezierControl1.dx) * (cornerX - mBezierControl1.dx) +
            (mBezierControl2.dy - cornerY) * (mBezierControl2.dy - cornerY));

    if (dis > 0.0001) {
      final f8 = (cornerX - mBezierControl1.dx) / dis;
      final f9 = (mBezierControl2.dy - cornerY) / dis;

      // 创建镜像变换矩阵（对标 Legado 的 mMatrixArray）
      final matrix = Matrix4.identity();
      matrix.setEntry(0, 0, 1 - 2 * f9 * f9);
      matrix.setEntry(0, 1, 2 * f8 * f9);
      matrix.setEntry(1, 0, 2 * f8 * f9);
      matrix.setEntry(1, 1, 1 - 2 * f8 * f8);

      canvas.save();
      canvas.translate(mBezierControl1.dx, mBezierControl1.dy);
      canvas.transform(matrix.storage);
      canvas.translate(-mBezierControl1.dx, -mBezierControl1.dy);

      // 添加暗色滤镜模拟纸张背面
      final darkPaint = Paint()
        ..colorFilter = const ColorFilter.matrix([
          0.9,
          0,
          0,
          0,
          0,
          0,
          0.9,
          0,
          0,
          0,
          0,
          0,
          0.9,
          0,
          0,
          0,
          0,
          0,
          1,
          0,
        ]);

      canvas.drawImage(bitmap, Offset.zero, darkPaint);
      canvas.restore();
    }

    // 绘制折叠阴影
    final leftFold =
        mIsRtOrLb ? (mBezierStart1.dx - 1) : (mBezierStart1.dx - f3 - 1);
    final rightFold =
        mIsRtOrLb ? (mBezierStart1.dx + f3 + 1) : (mBezierStart1.dx + 1);

    canvas.translate(mBezierStart1.dx, mBezierStart1.dy);
    canvas.rotate(mDegrees * math.pi / 180);

    final foldShadowPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(leftFold - mBezierStart1.dx, 0),
        Offset(rightFold - mBezierStart1.dx, 0),
        mIsRtOrLb
            ? [const Color(0x00333333), const Color(0xB0333333)]
            : [const Color(0xB0333333), const Color(0x00333333)],
      );

    canvas.drawRect(
      Rect.fromLTRB(leftFold - mBezierStart1.dx, 0,
          rightFold - mBezierStart1.dx, mMaxLength),
      foldShadowPaint,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant SimulationPagePainter oldDelegate) {
    return touchX != oldDelegate.touchX ||
        touchY != oldDelegate.touchY ||
        curBitmap != oldDelegate.curBitmap ||
        nextBitmap != oldDelegate.nextBitmap ||
        cornerX != oldDelegate.cornerX ||
        cornerY != oldDelegate.cornerY;
  }
}
