import 'package:flutter/material.dart';
import 'page_delegate.dart';

/// 无动画翻页委托
/// 直接切换页面，无过渡动画
class NoAnimPageDelegate extends PageDelegate {
  VoidCallback? _onUpdate;
  PageTurnCallback? onPageTurn;
  bool _shouldShowNext = false;
  bool _shouldShowPrev = false;

  @override
  void init(TickerProvider vsync, VoidCallback onUpdate) {
    _onUpdate = onUpdate;
    // 无动画模式不需要 AnimationController
  }

  @override
  void onDragStart(DragStartDetails details) {
    // 无动画模式不处理拖拽
  }

  @override
  void onDragUpdate(DragUpdateDetails details) {
    // 无动画模式不处理拖拽
  }

  @override
  void onDragEnd(DragEndDetails details) {
    // 无动画模式不处理拖拽
  }

  @override
  void nextPage({int animationDuration = 300}) {
    direction = PageDirection.next;
    onPageTurn?.call(direction).then((_) {
      direction = PageDirection.none;
      _onUpdate?.call();
    });
  }

  @override
  void prevPage({int animationDuration = 300}) {
    direction = PageDirection.prev;
    onPageTurn?.call(direction).then((_) {
      direction = PageDirection.none;
      _onUpdate?.call();
    });
  }

  @override
  void cancel() {
    direction = PageDirection.none;
    _onUpdate?.call();
  }

  @override
  double get currentOffset => 0.0;

  @override
  bool get showPrevPage => _shouldShowPrev;

  @override
  bool get showNextPage => _shouldShowNext;

  @override
  Widget buildPageTransition({
    required Widget currentPage,
    required Widget prevPage,
    required Widget nextPage,
    required Size size,
  }) {
    // 无动画模式直接显示当前页
    return currentPage;
  }

  @override
  void dispose() {
    // NoAnim 没有 AnimationController，不需要 dispose
  }
}
