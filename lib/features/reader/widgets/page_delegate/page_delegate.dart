import 'package:flutter/material.dart';

/// 翻页委托抽象类
/// 定义不同翻页动画模式的通用接口
abstract class PageDelegate {
  /// 动画控制器
  AnimationController? animationController;

  /// 是否正在执行动画
  bool get isAnimating => animationController?.isAnimating ?? false;

  /// 当前翻页方向
  PageDirection direction = PageDirection.none;

  /// 初始化
  void init(TickerProvider vsync, VoidCallback onUpdate);

  /// 处理拖拽开始
  void onDragStart(DragStartDetails details);

  /// 处理拖拽更新
  void onDragUpdate(DragUpdateDetails details);

  /// 处理拖拽结束
  void onDragEnd(DragEndDetails details);

  /// 执行下一页动画
  void nextPage({int animationDuration = 300});

  /// 执行上一页动画
  void prevPage({int animationDuration = 300});

  /// 取消动画
  void cancel();

  /// 获取当前偏移值 (0.0 - 1.0)
  double get currentOffset;

  /// 是否需要显示上一页
  bool get showPrevPage;

  /// 是否需要显示下一页
  bool get showNextPage;

  /// 构建翻页效果
  Widget buildPageTransition({
    required Widget currentPage,
    required Widget prevPage,
    required Widget nextPage,
    required Size size,
  });

  /// 释放资源
  void dispose() {
    animationController?.dispose();
  }
}

/// 翻页方向
enum PageDirection {
  none,
  prev,
  next,
}

/// 翻页完成回调
typedef PageTurnCallback = Future<bool> Function(PageDirection direction);
