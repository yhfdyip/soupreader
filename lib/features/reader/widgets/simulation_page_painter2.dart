import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// 仿真翻页绘制器2（贝塞尔曲线版，参考 flutter_novel）
/// 使用 Canvas 绘制贝塞尔曲线实现翻页效果
class SimulationPagePainter2 extends CustomPainter {
  /// 当前页面 Picture（翻起的页面）
  final ui.Picture? curPagePicture;

  /// 目标页面 Picture（底层页面）
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

  // 贝塞尔曲线关键点
  late Offset _bezierStart1;
  late Offset _bezierControl1;
  late Offset _bezierVertex1;
  late Offset _bezierEnd1;

  late Offset _bezierStart2;
  late Offset _bezierControl2;
  late Offset _bezierVertex2;
  late Offset _bezierEnd2;

  late double _middleX;
  late double _middleY;

  // Path 对象
  final Path _bottomPagePath = Path();
  final Path _topBackAreaPagePath = Path();

  SimulationPagePainter2({
    required this.curPagePicture,
    required this.nextPagePicture,
    required this.touch,
    required this.viewSize,
    required this.isTurnToNext,
    required this.backgroundColor,
    required this.cornerX,
    required this.cornerY,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (curPagePicture == null) return;

    // 计算贝塞尔曲线关键点
    _calBezierPoint(size);
    _calPath(size);

    // 1. 绘制当前页面（顶层）
    canvas.save();
    canvas.drawPicture(curPagePicture!);
    canvas.restore();

    // 2. 绘制底层页面（在裁剪区域内）
    if (nextPagePicture != null) {
      _drawBottomPage(canvas, size);
    }

    // 3. 绘制翻页区域的阴影
    _drawShadowOfTopPageBackArea(canvas, size);

    // 4. 绘制翻页背面
    _drawBackSideOfTopPage(canvas, size);

    // 5. 绘制背面阴影
    _drawShadowOfBackSide(canvas, size);
  }

  /// 计算贝塞尔曲线的各个关键点坐标
  void _calBezierPoint(Size size) {
    _middleX = (touch.dx + cornerX) / 2;
    _middleY = (touch.dy + cornerY) / 2;

    _bezierControl1 = Offset(
      _middleX -
          (cornerY - _middleY) * (cornerY - _middleY) / (cornerX - _middleX),
      cornerY,
    );

    double f4 = cornerY - _middleY;
    if (f4 == 0) {
      _bezierControl2 = Offset(
        cornerX,
        _middleY - (cornerX - _middleX) * (cornerX - _middleX) / 0.1,
      );
    } else {
      _bezierControl2 = Offset(
        cornerX,
        _middleY -
            (cornerX - _middleX) * (cornerX - _middleX) / (cornerY - _middleY),
      );
    }

    _bezierStart1 = Offset(
      _bezierControl1.dx - (cornerX - _bezierControl1.dx) / 2,
      cornerY,
    );

    // 防止 BUG：当 bezierStart1.x < 0 或 > width 时进行修正
    if (touch.dx > 0 && touch.dx < size.width) {
      if (_bezierStart1.dx < 0 || _bezierStart1.dx > size.width) {
        Offset correctedTouch = touch;
        if (_bezierStart1.dx < 0) {
          _bezierStart1 =
              Offset(size.width - _bezierStart1.dx, _bezierStart1.dy);
        }

        double f1 = (cornerX - touch.dx).abs();
        double f2 = size.width * f1 / _bezierStart1.dx;
        correctedTouch = Offset((cornerX - f2).abs(), touch.dy);

        double f3 = (cornerX - correctedTouch.dx).abs() *
            (cornerY - correctedTouch.dy).abs() /
            f1;
        correctedTouch = Offset((cornerX - f2).abs(), (cornerY - f3).abs());

        _middleX = (correctedTouch.dx + cornerX) / 2;
        _middleY = (correctedTouch.dy + cornerY) / 2;

        _bezierControl1 = Offset(
          _middleX -
              (cornerY - _middleY) *
                  (cornerY - _middleY) /
                  (cornerX - _middleX),
          cornerY,
        );

        double f5 = cornerY - _middleY;
        if (f5 == 0) {
          _bezierControl2 = Offset(
            cornerX,
            _middleY - (cornerX - _middleX) * (cornerX - _middleX) / 0.1,
          );
        } else {
          _bezierControl2 = Offset(
            cornerX,
            _middleY -
                (cornerX - _middleX) *
                    (cornerX - _middleX) /
                    (cornerY - _middleY),
          );
        }

        _bezierStart1 = Offset(
          _bezierControl1.dx - (cornerX - _bezierControl1.dx) / 2,
          _bezierStart1.dy,
        );
      }
    }

    _bezierStart2 = Offset(
      cornerX,
      _bezierControl2.dy - (cornerY - _bezierControl2.dy) / 2,
    );

    _bezierEnd1 =
        _getCrossByPoint(touch, _bezierControl1, _bezierStart1, _bezierStart2);
    _bezierEnd2 =
        _getCrossByPoint(touch, _bezierControl2, _bezierStart1, _bezierStart2);

    _bezierVertex1 = Offset(
      (_bezierStart1.dx + 2 * _bezierControl1.dx + _bezierEnd1.dx) / 4,
      (2 * _bezierControl1.dy + _bezierStart1.dy + _bezierEnd1.dy) / 4,
    );

    _bezierVertex2 = Offset(
      (_bezierStart2.dx + 2 * _bezierControl2.dx + _bezierEnd2.dx) / 4,
      (2 * _bezierControl2.dy + _bezierStart2.dy + _bezierEnd2.dy) / 4,
    );
  }

  /// 根据四点获取交点
  Offset _getCrossByPoint(Offset p1, Offset p2, Offset p3, Offset p4) {
    var line1Info = _getLineInfo(p1, p2);
    var line2Info = _getLineInfo(p3, p4);
    return _getCrossByLine(
        line1Info.dx, line1Info.dy, line2Info.dx, line2Info.dy);
  }

  /// 根据 k 和 b 获取交点
  Offset _getCrossByLine(double k1, double b1, double k2, double b2) {
    double x = (b2 - b1) / (k1 - k2);
    return Offset(x, k1 * x + b1);
  }

  /// 根据两点获取直线的 k、b
  Offset _getLineInfo(Offset p1, Offset p2) {
    double k = (p2.dy - p1.dy) / (p2.dx - p1.dx);
    double b = ((p1.dx * p2.dy) - (p2.dx * p1.dy)) / (p1.dx - p2.dx);
    return Offset(k, b);
  }

  /// 计算两点间距离
  double _getDistanceOfTwoPoint(Offset p1, Offset p2) {
    return sqrt(pow(p2.dy - p1.dy, 2) + pow(p2.dx - p1.dx, 2));
  }

  /// 计算 Path
  void _calPath(Size size) {
    _bottomPagePath.reset();
    _bottomPagePath.moveTo(cornerX, cornerY);
    _bottomPagePath.lineTo(_bezierStart1.dx, _bezierStart1.dy);
    _bottomPagePath.quadraticBezierTo(
      _bezierControl1.dx,
      _bezierControl1.dy,
      _bezierEnd1.dx,
      _bezierEnd1.dy,
    );
    _bottomPagePath.lineTo(touch.dx, touch.dy);
    _bottomPagePath.lineTo(_bezierEnd2.dx, _bezierEnd2.dy);
    _bottomPagePath.quadraticBezierTo(
      _bezierControl2.dx,
      _bezierControl2.dy,
      _bezierStart2.dx,
      _bezierStart2.dy,
    );
    _bottomPagePath.close();

    _topBackAreaPagePath.reset();
    _topBackAreaPagePath.moveTo(touch.dx, touch.dy);
    _topBackAreaPagePath.lineTo(_bezierVertex1.dx, _bezierVertex1.dy);
    _topBackAreaPagePath.lineTo(_bezierVertex2.dx, _bezierVertex2.dy);
    _topBackAreaPagePath.close();

    if (!_topBackAreaPagePath.getBounds().isEmpty) {
      try {
        // 取交集
        final intersected = Path.combine(
          PathOperation.intersect,
          _topBackAreaPagePath,
          _bottomPagePath,
        );
        _topBackAreaPagePath.reset();
        _topBackAreaPagePath.addPath(intersected, Offset.zero);
      } catch (e) {
        // Path combine 失败时忽略
      }
    }
  }

  /// 绘制底层页面
  void _drawBottomPage(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipPath(_bottomPagePath);
    canvas.drawColor(Colors.yellow, BlendMode.clear);
    canvas.drawPicture(nextPagePicture!);
    canvas.restore();
  }

  /// 绘制翻页区域阴影
  void _drawShadowOfTopPageBackArea(Canvas canvas, Size size) {
    var line1Info = _getLineInfo(touch, _bezierEnd1);
    var line2Info = _getLineInfo(touch, _bezierEnd2);

    var bv1 = _bezierVertex1.dy - line1Info.dx * _bezierVertex1.dx;
    var bv2 = _bezierVertex2.dy - line2Info.dx * _bezierVertex2.dx;

    var targetBv1 = (bv1 + line1Info.dy) / 2;
    var targetBv2 = (bv2 + line2Info.dy) / 2;

    var shadowCornerPoint =
        _getCrossByLine(line1Info.dx, targetBv1, line2Info.dx, targetBv2);

    var lineVertexInfo = _getLineInfo(_bezierVertex1, _bezierVertex2);
    var shadowLine1ShadowCrossPoint = _getCrossByLine(
        line1Info.dx, targetBv1, lineVertexInfo.dx, lineVertexInfo.dy);
    var shadowLine2ShadowCrossPoint = _getCrossByLine(
        line2Info.dx, targetBv2, lineVertexInfo.dx, lineVertexInfo.dy);

    var path = Path()..moveTo(shadowCornerPoint.dx, shadowCornerPoint.dy);
    path.lineTo(shadowLine1ShadowCrossPoint.dx, shadowLine1ShadowCrossPoint.dy);
    path.lineTo(shadowLine2ShadowCrossPoint.dx, shadowLine2ShadowCrossPoint.dy);
    path.close();

    canvas.drawShadow(path, Colors.black, 5, true);
  }

  /// 绘制翻页背面
  void _drawBackSideOfTopPage(Canvas canvas, Size size) {
    if (curPagePicture == null) return;

    var angle = 2 * (pi / 2 - atan2(cornerY - touch.dy, cornerX - touch.dx));

    canvas.save();
    canvas.clipPath(_topBackAreaPagePath);

    // 背景色
    canvas.drawColor(backgroundColor, BlendMode.src);

    canvas.save();

    Path tempPath = Path()..moveTo(touch.dx, touch.dy);
    tempPath.lineTo(_bezierControl1.dx, _bezierControl1.dy);
    tempPath.lineTo(_bezierControl2.dx, _bezierControl2.dy);
    tempPath.close();

    Path limitPath = Path()
      ..moveTo(0, 0)
      ..lineTo(0, size.height)
      ..lineTo(size.width, size.height)
      ..lineTo(size.width, 0)
      ..close();

    if (!limitPath.getBounds().isEmpty && !tempPath.getBounds().isEmpty) {
      try {
        tempPath = Path.combine(PathOperation.intersect, limitPath, tempPath);
      } catch (e) {
        // 忽略
      }
    }

    canvas.clipPath(tempPath);

    Matrix4 matrix4 = Matrix4.identity();

    if (cornerY == 0) {
      // 构建变换矩阵：translate(width, 0) -> scale(-1, 1, 1) -> translate(-touchX, touchY) -> translate(cornerX, cornerY) -> rotateZ -> translate(-cornerX, -cornerY)
      matrix4 = Matrix4.translationValues(-cornerX, -cornerY, 0)
        ..multiply(Matrix4.rotationZ(angle - pi))
        ..multiply(Matrix4.translationValues(cornerX, cornerY, 0))
        ..multiply(Matrix4.translationValues(-touch.dx, touch.dy, 0))
        ..multiply(Matrix4.diagonal3Values(-1.0, 1.0, 1.0))
        ..multiply(Matrix4.translationValues(size.width, 0.0, 0));
    } else {
      // 构建变换矩阵：translate(0, height) -> scale(1, -1, 1) -> translate(...) -> translate -> rotateZ -> translate
      matrix4 = Matrix4.translationValues(-size.width, -size.height, 0)
        ..multiply(Matrix4.rotationZ(angle))
        ..multiply(Matrix4.translationValues(size.width, size.height, 0))
        ..multiply(
            Matrix4.translationValues(touch.dx - size.width, -touch.dy, 0))
        ..multiply(Matrix4.diagonal3Values(1.0, -1.0, 1.0))
        ..multiply(Matrix4.translationValues(0.0, size.height, 0));
    }

    canvas.transform(matrix4.storage);
    canvas.drawPicture(curPagePicture!);

    canvas.restore();
    canvas.restore();
  }

  /// 绘制背面阴影
  void _drawShadowOfBackSide(Canvas canvas, Size size) {
    var shadowLongerSideLength =
        _getDistanceOfTwoPoint(_bezierStart2, _bezierStart1);
    var shadowShorterSideLength =
        _getDistanceOfTwoPoint(touch, Offset(cornerX, cornerY)) / 4;

    var angle = (pi / 2) -
        atan2(
          _bezierStart1.dx - _bezierStart2.dx,
          _bezierStart1.dy - _bezierStart2.dy,
        ).abs();

    canvas.save();
    canvas.clipPath(_bottomPagePath);

    canvas.translate(_bezierStart1.dx, _bezierStart1.dy);
    canvas.rotate(-angle);
    canvas.translate(-_bezierStart1.dx, -_bezierStart1.dy);

    var shadowAreaRect = Rect.fromLTRB(
      _bezierStart1.dx,
      _bezierStart1.dy - (cornerY == 0 ? shadowShorterSideLength : 0),
      _bezierStart1.dx + shadowLongerSideLength,
      _bezierStart1.dy + (cornerY == 0 ? 0 : shadowShorterSideLength),
    );

    if (!shadowAreaRect.isEmpty && !shadowAreaRect.hasNaN) {
      canvas.drawRect(
        shadowAreaRect,
        Paint()
          ..isAntiAlias = false
          ..style = PaintingStyle.fill
          ..shader = ui.Gradient.linear(
            shadowAreaRect.topCenter,
            shadowAreaRect.bottomCenter,
            [Colors.transparent, const Color(0xAA000000), Colors.transparent],
            [0.0, 0.5, 1.0],
          ),
      );
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant SimulationPagePainter2 oldDelegate) {
    return touch != oldDelegate.touch ||
        curPagePicture != oldDelegate.curPagePicture ||
        nextPagePicture != oldDelegate.nextPagePicture ||
        cornerX != oldDelegate.cornerX ||
        cornerY != oldDelegate.cornerY;
  }
}
