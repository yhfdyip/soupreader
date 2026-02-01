import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/reading_settings.dart';
import 'page_factory.dart';

/// 翻页阅读器组件（对标 Legado ReadView）
/// 三页面预加载架构：prevPage / curPage / nextPage
class PagedReaderWidget extends StatefulWidget {
  final PageFactory pageFactory;
  final PageTurnMode pageTurnMode;
  final TextStyle textStyle;
  final Color backgroundColor;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  final bool showStatusBar;

  static const double topOffset = 37;
  static const double bottomOffset = 37;

  const PagedReaderWidget({
    super.key,
    required this.pageFactory,
    required this.pageTurnMode,
    required this.textStyle,
    required this.backgroundColor,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.showStatusBar = true,
  });

  @override
  State<PagedReaderWidget> createState() => _PagedReaderWidgetState();
}

class _PagedReaderWidgetState extends State<PagedReaderWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;

  // 翻页状态
  double _dragOffset = 0;
  bool _isDragging = false;
  _PageDirection _direction = _PageDirection.none;
  bool _isAnimating = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    // 监听内容变化
    widget.pageFactory.onContentChanged = () {
      if (mounted) setState(() {});
    };
  }

  @override
  void didUpdateWidget(PagedReaderWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pageFactory != widget.pageFactory) {
      widget.pageFactory.onContentChanged = () {
        if (mounted) setState(() {});
      };
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  PageFactory get _factory => widget.pageFactory;

  void _onTap(Offset position) {
    if (_isAnimating) return;

    final screenWidth = MediaQuery.of(context).size.width;
    final xRate = position.dx / screenWidth;

    if (xRate > 0.33 && xRate < 0.66) {
      widget.onTap?.call();
    } else if (xRate >= 0.66) {
      _goNext();
    } else {
      _goPrev();
    }
  }

  void _goNext() {
    if (!_factory.hasNext()) return;
    _direction = _PageDirection.next;
    _startAnimation();
  }

  void _goPrev() {
    if (!_factory.hasPrev()) return;
    _direction = _PageDirection.prev;
    _startAnimation();
  }

  void _startAnimation() {
    if (_isAnimating) return;
    _isAnimating = true;

    final screenWidth = MediaQuery.of(context).size.width;
    final targetOffset =
        _direction == _PageDirection.next ? -screenWidth : screenWidth;
    final startOffset = _dragOffset;

    _animController.reset();

    void listener() {
      if (mounted) {
        setState(() {
          _dragOffset = startOffset +
              (targetOffset - startOffset) *
                  Curves.easeOutCubic.transform(_animController.value);
        });
      }
    }

    void statusListener(AnimationStatus status) {
      if (status == AnimationStatus.completed) {
        _onAnimStop();
        _animController.removeListener(listener);
        _animController.removeStatusListener(statusListener);
      }
    }

    _animController.addListener(listener);
    _animController.addStatusListener(statusListener);
    _animController.forward();
  }

  /// 对标 Legado onAnimStop + fillPage
  void _onAnimStop() {
    // 执行翻页
    if (_direction == _PageDirection.next) {
      _factory.moveToNext();
    } else if (_direction == _PageDirection.prev) {
      _factory.moveToPrev();
    }

    // 重置状态
    setState(() {
      _dragOffset = 0;
      _direction = _PageDirection.none;
      _isAnimating = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final topSafe = MediaQuery.of(context).padding.top;
    final bottomSafe = MediaQuery.of(context).padding.bottom;

    return Container(
      color: widget.backgroundColor,
      child: Stack(
        children: [
          Positioned.fill(
            child: _buildPageContent(),
          ),
          _buildOverlayer(topSafe, bottomSafe),
        ],
      ),
    );
  }

  Widget _buildOverlayer(double topSafe, double bottomSafe) {
    if (!widget.showStatusBar) return const SizedBox.shrink();

    final time = DateFormat('HH:mm').format(DateTime.now());
    final statusColor = widget.textStyle.color?.withValues(alpha: 0.4) ??
        const Color(0xff8B7961);

    return IgnorePointer(
      child: Container(
        padding: EdgeInsets.fromLTRB(
          widget.padding.left,
          10 + topSafe,
          widget.padding.right,
          10 + bottomSafe,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _factory.currentChapterTitle,
              style:
                  widget.textStyle.copyWith(fontSize: 14, color: statusColor),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const Expanded(child: SizedBox.shrink()),
            Row(
              children: [
                Text(time,
                    style: widget.textStyle
                        .copyWith(fontSize: 11, color: statusColor)),
                const Expanded(child: SizedBox.shrink()),
                Text(
                  '${_factory.currentPageIndex + 1}/${_factory.totalPages}',
                  style: widget.textStyle
                      .copyWith(fontSize: 11, color: statusColor),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPageContent() {
    if (widget.pageTurnMode == PageTurnMode.slide) {
      return _buildSlideMode();
    }
    return _buildCoverMode();
  }

  /// 滑动模式
  Widget _buildSlideMode() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapUp: (d) => _onTap(d.globalPosition),
      onHorizontalDragStart: _onDragStart,
      onHorizontalDragUpdate: _onDragUpdate,
      onHorizontalDragEnd: _onDragEnd,
      child: _buildThreePageStack(isSlide: true),
    );
  }

  /// 覆盖模式（cover/simulation/none）
  Widget _buildCoverMode() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapUp: (d) => _onTap(d.globalPosition),
      onHorizontalDragStart: _onDragStart,
      onHorizontalDragUpdate: _onDragUpdate,
      onHorizontalDragEnd: _onDragEnd,
      child: _buildThreePageStack(isSlide: false),
    );
  }

  /// 三页面堆叠（对标 Legado 的 prevPage/curPage/nextPage）
  Widget _buildThreePageStack({required bool isSlide}) {
    final screenWidth = MediaQuery.of(context).size.width;
    final offset = _dragOffset.clamp(-screenWidth, screenWidth);

    return Stack(
      children: [
        // 底层：目标页面
        if (_direction == _PageDirection.prev || offset > 0)
          Positioned.fill(
            child: _buildPageWidget(_factory.prevPage),
          ),
        if (_direction == _PageDirection.next || offset < 0)
          Positioned.fill(
            child: _buildPageWidget(_factory.nextPage),
          ),

        // 顶层：当前页面
        if (isSlide)
          // 滑动模式：两页同时移动
          Positioned(
            left: offset,
            top: 0,
            bottom: 0,
            width: screenWidth,
            child: _buildPageWidget(_factory.curPage),
          )
        else
          // 覆盖模式：当前页覆盖在上面
          _buildCoverCurrentPage(screenWidth, offset),
      ],
    );
  }

  Widget _buildCoverCurrentPage(double screenWidth, double offset) {
    double shadowOpacity = (offset.abs() / screenWidth * 0.3).clamp(0, 0.3);

    // none模式：不显示动画过渡
    if (widget.pageTurnMode == PageTurnMode.none && !_isAnimating) {
      return Positioned.fill(child: _buildPageWidget(_factory.curPage));
    }

    return Positioned(
      left: offset,
      top: 0,
      bottom: 0,
      width: screenWidth,
      child: Container(
        decoration: BoxDecoration(
          boxShadow: shadowOpacity > 0
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: shadowOpacity),
                    blurRadius: 15,
                    offset: Offset(offset > 0 ? -5 : 5, 0),
                  ),
                ]
              : null,
        ),
        child: _buildPageWidget(_factory.curPage),
      ),
    );
  }

  void _onDragStart(DragStartDetails details) {
    if (_isAnimating) return;
    _isDragging = true;
    _direction = _PageDirection.none;
  }

  void _onDragUpdate(DragUpdateDetails details) {
    if (!_isDragging || _isAnimating) return;

    setState(() {
      _dragOffset += details.delta.dx;

      // 确定方向
      if (_direction == _PageDirection.none && _dragOffset.abs() > 10) {
        _direction =
            _dragOffset > 0 ? _PageDirection.prev : _PageDirection.next;
      }

      // 边界阻尼
      if (_direction == _PageDirection.prev && !_factory.hasPrev()) {
        _dragOffset = (_dragOffset * 0.3).clamp(-50, 50);
      }
      if (_direction == _PageDirection.next && !_factory.hasNext()) {
        _dragOffset = (_dragOffset * 0.3).clamp(-50, 50);
      }
    });
  }

  void _onDragEnd(DragEndDetails details) {
    if (!_isDragging || _isAnimating) return;
    _isDragging = false;

    final screenWidth = MediaQuery.of(context).size.width;
    final velocity = details.primaryVelocity ?? 0;

    // 判断是否完成翻页
    final shouldTurn =
        _dragOffset.abs() > screenWidth * 0.25 || velocity.abs() > 800;

    if (shouldTurn && _direction != _PageDirection.none) {
      bool canTurn = _direction == _PageDirection.prev
          ? _factory.hasPrev()
          : _factory.hasNext();

      if (canTurn) {
        _startAnimation();
        return;
      }
    }

    // 回弹动画
    _cancelDrag();
  }

  void _cancelDrag() {
    _isAnimating = true;
    final startOffset = _dragOffset;

    _animController.reset();

    void listener() {
      if (mounted) {
        setState(() {
          _dragOffset = startOffset *
              (1 - Curves.easeOut.transform(_animController.value));
        });
      }
    }

    void statusListener(AnimationStatus status) {
      if (status == AnimationStatus.completed) {
        setState(() {
          _dragOffset = 0;
          _direction = _PageDirection.none;
          _isAnimating = false;
        });
        _animController.removeListener(listener);
        _animController.removeStatusListener(statusListener);
      }
    }

    _animController.addListener(listener);
    _animController.addStatusListener(statusListener);
    _animController.forward();
  }

  Widget _buildPageWidget(String content) {
    if (content.isEmpty) {
      return Container(color: widget.backgroundColor);
    }

    final topSafe = MediaQuery.of(context).padding.top;
    final bottomSafe = MediaQuery.of(context).padding.bottom;

    return Container(
      color: widget.backgroundColor,
      margin: EdgeInsets.fromLTRB(
        widget.padding.left,
        topSafe + PagedReaderWidget.topOffset,
        widget.padding.right,
        bottomSafe + PagedReaderWidget.bottomOffset,
      ),
      child: Text.rich(
        TextSpan(text: content, style: widget.textStyle),
        textAlign: TextAlign.justify,
      ),
    );
  }
}

enum _PageDirection { none, prev, next }
