import 'dart:ui' as ui;
import 'package:flutter/material.dart';

/// 仿真翻页绘制器（Shader版）
/// 完全摒弃贝塞尔曲线，使用 GLSL Fragment Shader 实现柱面映射与阴影
class SimulationPagePainter extends CustomPainter {
  /// 当前页面 Picture（未使用，仅兼容旧接口保留，或用于Bottom页绘制）
  final ui.Picture? curPagePicture;

  /// 目标页面 Picture（未使用，仅兼容旧接口保留，或用于Bottom页绘制）
  final ui.Picture? nextPagePicture;

  /// Shader 需要的 Image (当前被卷起的页面纹理)
  final ui.Image? curPageImage;

  /// Shader 程序
  final ui.FragmentProgram? shaderProgram;

  /// 设备像素比 (用于传给 Shader 物理坐标)
  final double devicePixelRatio;

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
    this.shaderProgram,
    this.curPageImage,
    this.devicePixelRatio = 1.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (shaderProgram == null || curPageImage == null) {
      // Fallback: just draw current page if shader not ready
      if (curPagePicture != null) canvas.drawPicture(curPagePicture!);
      return;
    }

    // 1. 绘制底层页面 (Bottom Page)
    // 如果是翻向下一页 (Next): 底层是 NextPage
    // 如果是翻向上一页 (Prev): 底层是 CurPage (因为 PrevPage 是卷进来的那个)
    // 注意：PagedReaderWidget 传参时:
    // curPagePicture = Factory.curPage
    // nextPagePicture = Factory.nextPage OR Factory.prevPage
    // 所以逻辑如下：
    final bottomPicture = isTurnToNext ? nextPagePicture : curPagePicture;
    if (bottomPicture != null) {
      canvas.save();
      canvas.drawPicture(bottomPicture);
      canvas.restore();
    } else {
      // 绘制背景色
      canvas.drawRect(Offset.zero & size, Paint()..color = backgroundColor);
    }

    // 2. 绘制顶层卷起页面 (Top Page) using Shader
    // Shader 将负责绘制 curled area, shadow, 和 backside.
    // Shader 会自动剔除已卷走的部分(透明)，从而露出底下的 Bottom Page
    
    final shader = shaderProgram!.fragmentShader();
    
    // Uniforms:
    // float resolution.x
    // float resolution.y
    // float iMouse.x (touch x)
    // float iMouse.y (touch y)
    // float iMouse.z (click x - unused)
    // float iMouse.w (corner y - used to determine corner side)
    
    // Uniforms:
    // float resolution.x
    // float resolution.y
    // float iMouse.x (touch x)
    // float iMouse.y (touch y)
    // float iMouse.z (click x - unused)
    // float iMouse.w (corner y - used to determine corner side)

    // FIX: Flutter Shader uses Logical Coordinates for FragCoord usually (or local).
    // Passing physical resolution while FragCoord is logical causes zooming effect.
    // Let's us Logical Size for resolution and touch.
    
    // final double physicalWidth = size.width * devicePixelRatio;
    // final double physicalHeight = size.height * devicePixelRatio;
    
    shader.setFloat(0, size.width);
    shader.setFloat(1, size.height);
    
    // config iMouse
    shader.setFloat(2, touch.dx);
    shader.setFloat(3, touch.dy);
    shader.setFloat(4, cornerX); // Pass cornerX (logical)
    shader.setFloat(5, cornerY); // pass cornerY (logical)
    
    // Sampler: image
    shader.setImageSampler(0, curPageImage!);
    
    final paint = Paint()..shader = shader;
    
    canvas.drawRect(Offset.zero & size, paint);
  }

  @override
  bool shouldRepaint(covariant SimulationPagePainter oldDelegate) {
    return touch != oldDelegate.touch ||
        curPagePicture != oldDelegate.curPagePicture ||
        nextPagePicture != oldDelegate.nextPagePicture ||
        cornerX != oldDelegate.cornerX ||
        cornerY != oldDelegate.cornerY ||
        curPageImage != oldDelegate.curPageImage;
  }
}
