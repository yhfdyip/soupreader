import 'package:flutter/material.dart';
import 'page_delegate.dart';

/// 覆盖翻页委托
/// 当前页向左滑出覆盖在下一页之上，带阴影效果
class CoverPageDelegate extends PageDelegate {
  double _dragOffset = 0.0;
  double _startX = 0.0;
  bool _isDragging = false;
  VoidCallback? _onUpdate;
  PageTurnCallback? onPageTurn;

  /// 滑动阈值 (超过屏幕宽度的这个比例时触发翻页)
  final double threshold = 0.3;

  @override
  void init(TickerProvider vsync, VoidCallback onUpdate) {
    _onUpdate = onUpdate;
    animationController = AnimationController(
      vsync: vsync,
      duration: const Duration(milliseconds: 300),
    );
    animationController!.addListener(() {
      _onUpdate?.call();
    });
  }

  @override
  void onDragStart(DragStartDetails details) {
    if (isAnimating) {
      animationController?.stop();
    }
    _startX = details.localPosition.dx;
    _isDragging = true;
    _dragOffset = 0.0;
  }

  @override
  void onDragUpdate(DragUpdateDetails details) {
    if (!_isDragging) return;

    final delta = details.localPosition.dx - _startX;
    _dragOffset = delta;

    // 确定方向
    if (delta > 0) {
      direction = PageDirection.prev;
    } else if (delta < 0) {
      direction = PageDirection.next;
    }

    _onUpdate?.call();
  }

  @override
  void onDragEnd(DragEndDetails details) {
    if (!_isDragging) return;
    _isDragging = false;

    final velocity = details.primaryVelocity ?? 0;
    final screenWidth = 400.0; // 将在实际使用时传入
    final offsetRatio = _dragOffset.abs() / screenWidth;

    // 根据速度和偏移量判断是否完成翻页
    bool shouldComplete = false;
    if (velocity.abs() > 500) {
      // 快速滑动
      shouldComplete = (direction == PageDirection.next && velocity < 0) ||
          (direction == PageDirection.prev && velocity > 0);
    } else {
      // 慢速滑动，看偏移量
      shouldComplete = offsetRatio > threshold;
    }

    if (shouldComplete && direction != PageDirection.none) {
      _animateToEnd();
    } else {
      _animateToStart();
    }
  }

  void _animateToEnd() {
    final animation = Tween<double>(
      begin: _dragOffset,
      end: direction == PageDirection.next ? -400.0 : 400.0,
    ).animate(CurvedAnimation(
      parent: animationController!,
      curve: Curves.easeOut,
    ));

    animation.addListener(() {
      _dragOffset = animation.value;
    });

    animationController!.forward(from: 0).then((_) {
      onPageTurn?.call(direction);
      _dragOffset = 0;
      direction = PageDirection.none;
      _onUpdate?.call();
    });
  }

  void _animateToStart() {
    final animation = Tween<double>(
      begin: _dragOffset,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: animationController!,
      curve: Curves.easeOut,
    ));

    animation.addListener(() {
      _dragOffset = animation.value;
    });

    animationController!.forward(from: 0).then((_) {
      direction = PageDirection.none;
      _onUpdate?.call();
    });
  }

  @override
  void nextPage({int animationDuration = 300}) {
    if (isAnimating) return;
    direction = PageDirection.next;
    animationController!.duration = Duration(milliseconds: animationDuration);

    final animation = Tween<double>(
      begin: 0.0,
      end: -400.0,
    ).animate(CurvedAnimation(
      parent: animationController!,
      curve: Curves.easeOut,
    ));

    animation.addListener(() {
      _dragOffset = animation.value;
    });

    animationController!.forward(from: 0).then((_) {
      onPageTurn?.call(direction);
      _dragOffset = 0;
      direction = PageDirection.none;
      _onUpdate?.call();
    });
  }

  @override
  void prevPage({int animationDuration = 300}) {
    if (isAnimating) return;
    direction = PageDirection.prev;
    animationController!.duration = Duration(milliseconds: animationDuration);

    final animation = Tween<double>(
      begin: 0.0,
      end: 400.0,
    ).animate(CurvedAnimation(
      parent: animationController!,
      curve: Curves.easeOut,
    ));

    animation.addListener(() {
      _dragOffset = animation.value;
    });

    animationController!.forward(from: 0).then((_) {
      onPageTurn?.call(direction);
      _dragOffset = 0;
      direction = PageDirection.none;
      _onUpdate?.call();
    });
  }

  @override
  void cancel() {
    animationController?.stop();
    _dragOffset = 0;
    direction = PageDirection.none;
    _onUpdate?.call();
  }

  @override
  double get currentOffset => _dragOffset;

  @override
  bool get showPrevPage => direction == PageDirection.prev && _dragOffset > 0;

  @override
  bool get showNextPage => direction == PageDirection.next && _dragOffset < 0;

  @override
  Widget buildPageTransition({
    required Widget currentPage,
    required Widget prevPage,
    required Widget nextPage,
    required Size size,
  }) {
    // 更新动画终点为实际屏幕宽度
    final screenWidth = size.width;

    return Stack(
      children: [
        // 下一页（在最底层，翻到下一页时显示）
        if (direction == PageDirection.next || direction == PageDirection.none)
          Positioned.fill(child: nextPage),

        // 上一页（翻到上一页时从左边滑入）
        if (direction == PageDirection.prev)
          Positioned(
            left: _dragOffset - screenWidth,
            top: 0,
            width: screenWidth,
            height: size.height,
            child: prevPage,
          ),

        // 当前页（带阴影效果）
        if (_dragOffset != 0 || direction == PageDirection.none)
          Positioned(
            left: direction == PageDirection.next ? _dragOffset : 0,
            top: 0,
            width: screenWidth,
            height: size.height,
            child: Container(
              decoration: BoxDecoration(
                boxShadow: direction != PageDirection.none
                    ? [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 10,
                          offset: const Offset(-5, 0),
                        ),
                      ]
                    : null,
              ),
              child: currentPage,
            ),
          ),

        // 如果没有拖拽，显示当前页
        if (_dragOffset == 0 && direction == PageDirection.none)
          Positioned.fill(child: currentPage),
      ],
    );
  }
}
