import 'package:flutter/material.dart';
import 'page_delegate.dart';

/// 滑动翻页委托
/// 当前页和下一页同时滑动
class SlidePageDelegate extends PageDelegate {
  double _dragOffset = 0.0;
  double _startX = 0.0;
  bool _isDragging = false;
  VoidCallback? _onUpdate;
  PageTurnCallback? onPageTurn;

  /// 滑动阈值
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
    final screenWidth = 400.0;
    final offsetRatio = _dragOffset.abs() / screenWidth;

    bool shouldComplete = false;
    if (velocity.abs() > 500) {
      shouldComplete = (direction == PageDirection.next && velocity < 0) ||
          (direction == PageDirection.prev && velocity > 0);
    } else {
      shouldComplete = offsetRatio > threshold;
    }

    if (shouldComplete && direction != PageDirection.none) {
      _animateToEnd();
    } else {
      _animateToStart();
    }
  }

  void _animateToEnd() {
    final endValue = direction == PageDirection.next ? -400.0 : 400.0;

    final animation = Tween<double>(
      begin: _dragOffset,
      end: endValue,
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
  bool get showPrevPage => direction == PageDirection.prev;

  @override
  bool get showNextPage => direction == PageDirection.next;

  @override
  Widget buildPageTransition({
    required Widget currentPage,
    required Widget prevPage,
    required Widget nextPage,
    required Size size,
  }) {
    final screenWidth = size.width;

    return Stack(
      children: [
        // 上一页（在左侧）
        if (direction == PageDirection.prev)
          Positioned(
            left: _dragOffset - screenWidth,
            top: 0,
            width: screenWidth,
            height: size.height,
            child: prevPage,
          ),

        // 当前页
        Positioned(
          left: _dragOffset,
          top: 0,
          width: screenWidth,
          height: size.height,
          child: currentPage,
        ),

        // 下一页（在右侧）
        if (direction == PageDirection.next)
          Positioned(
            left: screenWidth + _dragOffset,
            top: 0,
            width: screenWidth,
            height: size.height,
            child: nextPage,
          ),
      ],
    );
  }
}
