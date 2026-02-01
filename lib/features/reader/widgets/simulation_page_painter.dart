import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

/// 仿真翻页绘制器（完全移植自 Legado SimulationPageDelegate）
/// 使用贝塞尔曲线模拟真实书页翻转效果
class SimulationPagePainter extends CustomPainter {
  final ui.Image? curPageImage;
  final ui.Image? targetPageImage;
  final double touchX;
  final double touchY;
  final double startX;
  final double startY;
  final int viewWidth;
  final int viewHeight;
  final bool isNext; // true=下一页, false=上一页
  final Color backgroundColor;

  SimulationPagePainter({
    required this.curPageImage,
    required this.targetPageImage,
    required this.touchX,
    required this.touchY,
    required this.startX,
    required this.startY,
    required this.viewWidth,
    required this.viewHeight,
    required this.isNext,
    required this.backgroundColor,
  });

  // 贝塞尔曲线控制点
  late double _cornerX;
  late double _cornerY;
  late double _middleX;
  late double _middleY;
  late double _touchToCornerDis;
  late bool _isRtOrLb; // 是否右上或左下

  late Offset bezierStart1;
  late Offset bezierControl1;
  late Offset bezierVertex1;
  late Offset bezierEnd1;
  late Offset bezierStart2;
  late Offset bezierControl2;
  late Offset bezierVertex2;
  late Offset bezierEnd2;

  late double _mTouchX;
  late double _mTouchY;
  late double _degrees;
  late double _maxLength;

  @override
  void paint(Canvas canvas, Size size) {
    if (curPageImage == null) return;

    _maxLength = math.sqrt(viewWidth * viewWidth + viewHeight * viewHeight);

    // 计算角点
    _calcCornerXY();

    // 计算贝塞尔曲线点
    _calcPoints();

    // 绘制当前页区域（被翻开后露出的部分）
    _drawCurrentPageArea(canvas);

    // 绘制目标页及阴影
    _drawNextPageAreaAndShadow(canvas);

    // 绘制当前页阴影
    _drawCurrentPageShadow(canvas);

    // 绘制翻起页背面
    _drawCurrentBackArea(canvas);
  }

  void _calcCornerXY() {
    _cornerX = startX <= viewWidth / 2 ? 0 : viewWidth.toDouble();
    _cornerY = startY <= viewHeight / 2 ? 0 : viewHeight.toDouble();

    // 上一页强制从底部翻
    if (!isNext) {
      _cornerY = viewHeight.toDouble();
    }

    _isRtOrLb = (_cornerX == 0 && _cornerY == viewHeight) ||
        (_cornerY == 0 && _cornerX == viewWidth);
  }

  void _calcPoints() {
    _mTouchX = touchX.clamp(0.1, viewWidth - 0.1);
    _mTouchY = touchY.clamp(0.1, viewHeight - 0.1);

    _middleX = (_mTouchX + _cornerX) / 2;
    _middleY = (_mTouchY + _cornerY) / 2;

    double bezierControl1X;
    double bezierControl1Y = _cornerY;

    if ((_cornerX - _middleX).abs() < 0.001) {
      bezierControl1X = _middleX;
    } else {
      bezierControl1X = _middleX -
          (_cornerY - _middleY) * (_cornerY - _middleY) / (_cornerX - _middleX);
    }

    double bezierControl2X = _cornerX;
    double bezierControl2Y;

    if ((_cornerY - _middleY).abs() < 0.001) {
      bezierControl2Y =
          _middleY - (_cornerX - _middleX) * (_cornerX - _middleX) / 0.1;
    } else {
      bezierControl2Y = _middleY -
          (_cornerX - _middleX) * (_cornerX - _middleX) / (_cornerY - _middleY);
    }

    double bezierStart1X = bezierControl1X - (_cornerX - bezierControl1X) / 2;
    double bezierStart1Y = _cornerY;

    // 边界修正
    if (_mTouchX > 0 && _mTouchX < viewWidth) {
      if (bezierStart1X < 0 || bezierStart1X > viewWidth) {
        if (bezierStart1X < 0) {
          bezierStart1X = viewWidth - bezierStart1X;
        }

        final f1 = (_cornerX - _mTouchX).abs();
        final f2 = viewWidth * f1 / bezierStart1X;
        _mTouchX = (_cornerX - f2).abs();

        final f3 =
            (_cornerX - _mTouchX).abs() * (_cornerY - _mTouchY).abs() / f1;
        _mTouchY = (_cornerY - f3).abs();

        _middleX = (_mTouchX + _cornerX) / 2;
        _middleY = (_mTouchY + _cornerY) / 2;

        if ((_cornerX - _middleX).abs() < 0.001) {
          bezierControl1X = _middleX;
        } else {
          bezierControl1X = _middleX -
              (_cornerY - _middleY) *
                  (_cornerY - _middleY) /
                  (_cornerX - _middleX);
        }
        bezierControl1Y = _cornerY;

        bezierControl2X = _cornerX;
        if ((_cornerY - _middleY).abs() < 0.001) {
          bezierControl2Y =
              _middleY - (_cornerX - _middleX) * (_cornerX - _middleX) / 0.1;
        } else {
          bezierControl2Y = _middleY -
              (_cornerX - _middleX) *
                  (_cornerX - _middleX) /
                  (_cornerY - _middleY);
        }

        bezierStart1X = bezierControl1X - (_cornerX - bezierControl1X) / 2;
      }
    }

    double bezierStart2X = _cornerX;
    double bezierStart2Y = bezierControl2Y - (_cornerY - bezierControl2Y) / 2;

    _touchToCornerDis = math.sqrt(
        (_mTouchX - _cornerX) * (_mTouchX - _cornerX) +
            (_mTouchY - _cornerY) * (_mTouchY - _cornerY));

    // 计算交点
    final end1 = _getCross(
      Offset(_mTouchX, _mTouchY),
      Offset(bezierControl1X, bezierControl1Y),
      Offset(bezierStart1X, bezierStart1Y),
      Offset(bezierStart2X, bezierStart2Y),
    );

    final end2 = _getCross(
      Offset(_mTouchX, _mTouchY),
      Offset(bezierControl2X, bezierControl2Y),
      Offset(bezierStart1X, bezierStart1Y),
      Offset(bezierStart2X, bezierStart2Y),
    );

    // 更新所有贝塞尔点
    bezierStart1 = Offset(bezierStart1X, bezierStart1Y);
    bezierControl1 = Offset(bezierControl1X, bezierControl1Y);
    bezierEnd1 = end1;
    bezierVertex1 = Offset(
      (bezierStart1X + 2 * bezierControl1X + end1.dx) / 4,
      (2 * bezierControl1Y + bezierStart1Y + end1.dy) / 4,
    );

    bezierStart2 = Offset(bezierStart2X, bezierStart2Y);
    bezierControl2 = Offset(bezierControl2X, bezierControl2Y);
    bezierEnd2 = end2;
    bezierVertex2 = Offset(
      (bezierStart2X + 2 * bezierControl2X + end2.dx) / 4,
      (2 * bezierControl2Y + bezierStart2Y + end2.dy) / 4,
    );

    _degrees = math.atan2(
          bezierControl1X - _cornerX,
          bezierControl2Y - _cornerY,
        ) *
        180 /
        math.pi;
  }

  /// 求两条直线的交点
  Offset _getCross(Offset p1, Offset p2, Offset p3, Offset p4) {
    final a1 = (p2.dy - p1.dy) / (p2.dx - p1.dx);
    final b1 = (p1.dx * p2.dy - p2.dx * p1.dy) / (p1.dx - p2.dx);
    final a2 = (p4.dy - p3.dy) / (p4.dx - p3.dx);
    final b2 = (p3.dx * p4.dy - p4.dx * p3.dy) / (p3.dx - p4.dx);
    final x = (b2 - b1) / (a1 - a2);
    final y = a1 * x + b1;
    return Offset(x, y);
  }

  /// 绘制当前页区域（贝塞尔曲线裁剪）
  void _drawCurrentPageArea(Canvas canvas) {
    if (curPageImage == null) return;

    final path = Path();
    path.moveTo(bezierStart1.dx, bezierStart1.dy);
    path.quadraticBezierTo(
        bezierControl1.dx, bezierControl1.dy, bezierEnd1.dx, bezierEnd1.dy);
    path.lineTo(_mTouchX, _mTouchY);
    path.lineTo(bezierEnd2.dx, bezierEnd2.dy);
    path.quadraticBezierTo(
        bezierControl2.dx, bezierControl2.dy, bezierStart2.dx, bezierStart2.dy);
    path.lineTo(_cornerX, _cornerY);
    path.close();

    canvas.save();
    // 使用差集裁剪（显示翻页后露出的区域）
    canvas.clipPath(path, doAntiAlias: true);
    // 反向裁剪
    final fullPath = Path()
      ..addRect(
          Rect.fromLTWH(0, 0, viewWidth.toDouble(), viewHeight.toDouble()));
    canvas.clipPath(Path.combine(PathOperation.difference, fullPath, path),
        doAntiAlias: true);
    canvas.drawImage(curPageImage!, Offset.zero, Paint());
    canvas.restore();
  }

  /// 绘制目标页及阴影
  void _drawNextPageAreaAndShadow(Canvas canvas) {
    if (targetPageImage == null) return;

    final path1 = Path();
    path1.moveTo(bezierStart1.dx, bezierStart1.dy);
    path1.lineTo(bezierVertex1.dx, bezierVertex1.dy);
    path1.lineTo(bezierVertex2.dx, bezierVertex2.dy);
    path1.lineTo(bezierStart2.dx, bezierStart2.dy);
    path1.lineTo(_cornerX, _cornerY);
    path1.close();

    final path0 = Path();
    path0.moveTo(bezierStart1.dx, bezierStart1.dy);
    path0.quadraticBezierTo(
        bezierControl1.dx, bezierControl1.dy, bezierEnd1.dx, bezierEnd1.dy);
    path0.lineTo(_mTouchX, _mTouchY);
    path0.lineTo(bezierEnd2.dx, bezierEnd2.dy);
    path0.quadraticBezierTo(
        bezierControl2.dx, bezierControl2.dy, bezierStart2.dx, bezierStart2.dy);
    path0.lineTo(_cornerX, _cornerY);
    path0.close();

    canvas.save();
    canvas.clipPath(path0, doAntiAlias: true);
    canvas.clipPath(path1, doAntiAlias: true);
    canvas.drawImage(targetPageImage!, Offset.zero, Paint());

    // 绘制阴影
    final shadowWidth = _touchToCornerDis / 4;
    final leftX = _isRtOrLb ? bezierStart1.dx : bezierStart1.dx - shadowWidth;
    final rightX = _isRtOrLb ? bezierStart1.dx + shadowWidth : bezierStart1.dx;

    canvas.save();
    canvas.translate(bezierStart1.dx, bezierStart1.dy);
    canvas.rotate(_degrees * math.pi / 180);

    final shadowPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(leftX - bezierStart1.dx, 0),
        Offset(rightX - bezierStart1.dx, 0),
        _isRtOrLb
            ? [const Color(0x00111111), const Color(0x66111111)]
            : [const Color(0x66111111), const Color(0x00111111)],
      );

    canvas.drawRect(
      Rect.fromLTRB(
          leftX - bezierStart1.dx, 0, rightX - bezierStart1.dx, _maxLength),
      shadowPaint,
    );
    canvas.restore();
    canvas.restore();
  }

  /// 绘制当前页阴影
  void _drawCurrentPageShadow(Canvas canvas) {
    final degree = _isRtOrLb
        ? math.pi / 4 -
            math.atan2(
                bezierControl1.dy - _mTouchY, _mTouchX - bezierControl1.dx)
        : math.pi / 4 -
            math.atan2(
                _mTouchY - bezierControl1.dy, _mTouchX - bezierControl1.dx);

    final d1 = 25 * 1.414 * math.cos(degree);
    final d2 = 25 * 1.414 * math.sin(degree);
    final x = (_mTouchX + d1);
    final y = _isRtOrLb ? (_mTouchY + d2) : (_mTouchY - d2);

    final path1 = Path();
    path1.moveTo(x, y);
    path1.lineTo(_mTouchX, _mTouchY);
    path1.lineTo(bezierControl1.dx, bezierControl1.dy);
    path1.lineTo(bezierStart1.dx, bezierStart1.dy);
    path1.close();

    final path0 = Path();
    path0.moveTo(bezierStart1.dx, bezierStart1.dy);
    path0.quadraticBezierTo(
        bezierControl1.dx, bezierControl1.dy, bezierEnd1.dx, bezierEnd1.dy);
    path0.lineTo(_mTouchX, _mTouchY);
    path0.lineTo(bezierEnd2.dx, bezierEnd2.dy);
    path0.quadraticBezierTo(
        bezierControl2.dx, bezierControl2.dy, bezierStart2.dx, bezierStart2.dy);
    path0.lineTo(_cornerX, _cornerY);
    path0.close();

    canvas.save();
    // 裁剪出 path0 之外 且 path1 之内的区域
    final fullPath = Path()
      ..addRect(
          Rect.fromLTWH(0, 0, viewWidth.toDouble(), viewHeight.toDouble()));
    canvas.clipPath(Path.combine(PathOperation.difference, fullPath, path0),
        doAntiAlias: true);
    canvas.clipPath(path1, doAntiAlias: true);

    final leftX = _isRtOrLb ? bezierControl1.dx : bezierControl1.dx - 25;
    final rightX = _isRtOrLb ? bezierControl1.dx + 25 : bezierControl1.dx + 1;

    final rotateDegrees =
        math.atan2(_mTouchX - bezierControl1.dx, bezierControl1.dy - _mTouchY);

    canvas.translate(bezierControl1.dx, bezierControl1.dy);
    canvas.rotate(rotateDegrees);

    final shadowPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(leftX - bezierControl1.dx, -_maxLength),
        Offset(rightX - bezierControl1.dx, -_maxLength),
        _isRtOrLb
            ? [const Color(0x00111111), const Color(0x44111111)]
            : [const Color(0x44111111), const Color(0x00111111)],
      );

    canvas.drawRect(
      Rect.fromLTRB(leftX - bezierControl1.dx, -_maxLength,
          rightX - bezierControl1.dx, 0),
      shadowPaint,
    );
    canvas.restore();
  }

  /// 绘制翻起页背面
  void _drawCurrentBackArea(Canvas canvas) {
    if (curPageImage == null) return;

    final i = ((bezierStart1.dx + bezierControl1.dx) / 2).toInt();
    final f1 = (i - bezierControl1.dx).abs();
    final i1 = ((bezierStart2.dy + bezierControl2.dy) / 2).toInt();
    final f2 = (i1 - bezierControl2.dy).abs();
    final f3 = math.min(f1, f2);

    final path1 = Path();
    path1.moveTo(bezierVertex2.dx, bezierVertex2.dy);
    path1.lineTo(bezierVertex1.dx, bezierVertex1.dy);
    path1.lineTo(bezierEnd1.dx, bezierEnd1.dy);
    path1.lineTo(_mTouchX, _mTouchY);
    path1.lineTo(bezierEnd2.dx, bezierEnd2.dy);
    path1.close();

    final path0 = Path();
    path0.moveTo(bezierStart1.dx, bezierStart1.dy);
    path0.quadraticBezierTo(
        bezierControl1.dx, bezierControl1.dy, bezierEnd1.dx, bezierEnd1.dy);
    path0.lineTo(_mTouchX, _mTouchY);
    path0.lineTo(bezierEnd2.dx, bezierEnd2.dy);
    path0.quadraticBezierTo(
        bezierControl2.dx, bezierControl2.dy, bezierStart2.dx, bezierStart2.dy);
    path0.lineTo(_cornerX, _cornerY);
    path0.close();

    canvas.save();
    canvas.clipPath(path0, doAntiAlias: true);
    canvas.clipPath(path1, doAntiAlias: true);

    // 绘制背景色
    canvas.drawRect(
      Rect.fromLTWH(0, 0, viewWidth.toDouble(), viewHeight.toDouble()),
      Paint()..color = backgroundColor,
    );

    // 绘制镜像翻转的页面
    final dis = math.sqrt(
        (_cornerX - bezierControl1.dx) * (_cornerX - bezierControl1.dx) +
            (bezierControl2.dy - _cornerY) * (bezierControl2.dy - _cornerY));

    if (dis > 0.001) {
      final f8 = (_cornerX - bezierControl1.dx) / dis;
      final f9 = (bezierControl2.dy - _cornerY) / dis;

      // 创建镜像变换矩阵
      final matrix = Matrix4.identity();
      matrix.setEntry(0, 0, 1 - 2 * f9 * f9);
      matrix.setEntry(0, 1, 2 * f8 * f9);
      matrix.setEntry(1, 0, 2 * f8 * f9);
      matrix.setEntry(1, 1, 1 - 2 * f8 * f8);

      canvas.save();
      canvas.translate(bezierControl1.dx, bezierControl1.dy);
      canvas.transform(matrix.storage);
      canvas.translate(-bezierControl1.dx, -bezierControl1.dy);

      // 添加暗色滤镜
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

      canvas.drawImage(curPageImage!, Offset.zero, darkPaint);
      canvas.restore();
    }

    // 绘制折叠阴影
    final leftFold =
        _isRtOrLb ? (bezierStart1.dx - 1) : (bezierStart1.dx - f3 - 1);
    final rightFold =
        _isRtOrLb ? (bezierStart1.dx + f3 + 1) : (bezierStart1.dx + 1);

    canvas.translate(bezierStart1.dx, bezierStart1.dy);
    canvas.rotate(_degrees * math.pi / 180);

    final foldShadowPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(leftFold - bezierStart1.dx, 0),
        Offset(rightFold - bezierStart1.dx, 0),
        _isRtOrLb
            ? [const Color(0x00333333), const Color(0x66333333)]
            : [const Color(0x66333333), const Color(0x00333333)],
      );

    canvas.drawRect(
      Rect.fromLTRB(leftFold - bezierStart1.dx, 0, rightFold - bezierStart1.dx,
          _maxLength),
      foldShadowPaint,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant SimulationPagePainter oldDelegate) {
    return touchX != oldDelegate.touchX ||
        touchY != oldDelegate.touchY ||
        curPageImage != oldDelegate.curPageImage ||
        targetPageImage != oldDelegate.targetPageImage;
  }
}
