import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/reading_settings.dart';
import 'page_factory.dart';
import 'page_delegate/page_delegate.dart';
import 'page_delegate/slide_delegate.dart';
import 'page_delegate/cover_delegate.dart';
import 'page_delegate/no_anim_delegate.dart';
import 'page_delegate/simulation_delegate.dart';

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
    with TickerProviderStateMixin {
  late PageDelegate _delegate;

  // 仿真翻页用的 Picture 缓存
  ui.Picture? _curPagePicture;
  ui.Picture? _nextPagePicture;
  ui.Picture? _prevPagePicture;
  ui.Image? _curPageImage;
  Size? _lastSize;

  @override
  void initState() {
    super.initState();
    _initDelegate();

    widget.pageFactory.onContentChanged = () {
      if (mounted) {
        _invalidateCache();
        setState(() {});
      }
    };
  }

  void _initDelegate() {
    _delegate = _createDelegate(widget.pageTurnMode);
    _delegate.init(this, () {
      if (mounted) setState(() {});
    });

    // 设置翻页回调
    if (_delegate is SlidePageDelegate) {
      (_delegate as SlidePageDelegate).onPageTurn = _onPageTurn;
    } else if (_delegate is CoverPageDelegate) {
      (_delegate as CoverPageDelegate).onPageTurn = _onPageTurn;
    } else if (_delegate is SimulationDelegate) {
      (_delegate as SimulationDelegate).onPageTurn = _onPageTurn;
    }
  }

  PageDelegate _createDelegate(PageTurnMode mode) {
    switch (mode) {
      case PageTurnMode.slide:
        return SlidePageDelegate();
      case PageTurnMode.cover:
        return CoverPageDelegate();
      case PageTurnMode.simulation:
        return SimulationDelegate();
      case PageTurnMode.none:
        return NoAnimPageDelegate();
      default:
        return SlidePageDelegate();
    }
  }

  Future<bool> _onPageTurn(PageDirection direction) async {
    if (direction == PageDirection.next) {
      return widget.pageFactory.moveToNext();
    } else if (direction == PageDirection.prev) {
      return widget.pageFactory.moveToPrev();
    }
    return false;
  }

  @override
  void didUpdateWidget(PagedReaderWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.pageTurnMode != widget.pageTurnMode) {
      _delegate.dispose();
      _initDelegate();
    }

    if (oldWidget.pageFactory != widget.pageFactory ||
        oldWidget.textStyle != widget.textStyle ||
        oldWidget.backgroundColor != widget.backgroundColor) {
      widget.pageFactory.onContentChanged = () {
        if (mounted) {
          _invalidateCache();
          setState(() {});
        }
      };
      _invalidateCache();
    }
  }

  @override
  void dispose() {
    _delegate.dispose();
    _invalidateCache();
    super.dispose();
  }

  void _invalidateCache() {
    _curPagePicture = null;
    _nextPagePicture = null;
    _prevPagePicture = null;
    _curPageImage?.dispose();
    _curPageImage = null;
  }

  PageFactory get _factory => widget.pageFactory;

  /// 使用 PictureRecorder 预渲染页面内容
  ui.Picture _recordPage(String content, Size size) {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    final topSafe = MediaQuery.of(context).padding.top;
    final bottomSafe = MediaQuery.of(context).padding.bottom;

    // 绘制背景
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = widget.backgroundColor,
    );

    if (content.isNotEmpty) {
      // 绘制文本
      final textPainter = TextPainter(
        text: TextSpan(text: content, style: widget.textStyle),
        textDirection: ui.TextDirection.ltr,
        textAlign: TextAlign.justify,
      );

      final contentWidth =
          size.width - widget.padding.left - widget.padding.right;
      textPainter.layout(maxWidth: contentWidth);

      textPainter.paint(
        canvas,
        Offset(
          widget.padding.left,
          topSafe + PagedReaderWidget.topOffset,
        ),
      );
    }

    // 绘制状态栏
    if (widget.showStatusBar) {
      final time = DateFormat('HH:mm').format(DateTime.now());
      final statusColor = widget.textStyle.color?.withValues(alpha: 0.4) ??
          const Color(0xff8B7961);

      // 章节标题
      final titlePainter = TextPainter(
        text: TextSpan(
          text: _factory.currentChapterTitle,
          style: widget.textStyle.copyWith(fontSize: 14, color: statusColor),
        ),
        textDirection: ui.TextDirection.ltr,
        maxLines: 1,
        ellipsis: '...',
      );
      titlePainter.layout(
          maxWidth: size.width - widget.padding.left - widget.padding.right);
      titlePainter.paint(canvas, Offset(widget.padding.left, 10 + topSafe));

      // 时间
      final timePainter = TextPainter(
        text: TextSpan(
          text: time,
          style: widget.textStyle.copyWith(fontSize: 11, color: statusColor),
        ),
        textDirection: ui.TextDirection.ltr,
      );
      timePainter.layout();
      timePainter.paint(
        canvas,
        Offset(widget.padding.left,
            size.height - 10 - bottomSafe - timePainter.height),
      );

      // 页码
      final pagePainter = TextPainter(
        text: TextSpan(
          text: '${_factory.currentPageIndex + 1}/${_factory.totalPages}',
          style: widget.textStyle.copyWith(fontSize: 11, color: statusColor),
        ),
        textDirection: ui.TextDirection.ltr,
      );
      pagePainter.layout();
      pagePainter.paint(
        canvas,
        Offset(
          size.width - widget.padding.right - pagePainter.width,
          size.height - 10 - bottomSafe - pagePainter.height,
        ),
      );
    }

    return recorder.endRecording();
  }

  /// 为仿真模式预渲染 Picture（同步）
  void _ensureSimulationPictures(Size size) {
    if (_delegate is! SimulationDelegate) return;

    final simDelegate = _delegate as SimulationDelegate;
    simDelegate.currentSize = size;
    simDelegate.backgroundColor = widget.backgroundColor;

    if (_lastSize != size) {
      _invalidateCache();
      _lastSize = size;
    }

    // 预渲染当前页 Picture（同步）
    _curPagePicture ??= _recordPage(_factory.curPage, size);
    simDelegate.curPagePicture = _curPagePicture;

    // 预渲染下一页 Picture（同步）
    _nextPagePicture ??= _recordPage(_factory.nextPage, size);
    simDelegate.nextPagePicture = _nextPagePicture;

    // 预渲染上一页 Picture（同步）
    _prevPagePicture ??= _recordPage(_factory.prevPage, size);
    simDelegate.prevPagePicture = _prevPagePicture;

    // 异步生成当前页 Image（用于背面渲染），不阻塞
    if (_curPageImage == null && _curPagePicture != null) {
      _curPagePicture!
          .toImage(
        size.width.toInt(),
        size.height.toInt(),
      )
          .then((image) {
        if (mounted) {
          _curPageImage = image;
          simDelegate.curPageImage = _curPageImage;
          // 触发重绘
          setState(() {});
        }
      });
    }
  }

  void _onTap(Offset position) {
    if (_delegate.isAnimating) return;

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
    _delegate.nextPage();
  }

  void _goPrev() {
    if (!_factory.hasPrev()) return;
    _delegate.prevPage();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    // 为仿真模式准备 Picture
    if (_delegate is SimulationDelegate) {
      _ensureSimulationPictures(size);
    }

    return Container(
      color: widget.backgroundColor,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapUp: (d) => _onTap(d.globalPosition),
        onHorizontalDragStart: _delegate.onDragStart,
        onHorizontalDragUpdate: _delegate.onDragUpdate,
        onHorizontalDragEnd: _delegate.onDragEnd,
        child: _delegate.buildPageTransition(
          currentPage: _buildPageWidget(_factory.curPage),
          prevPage: _buildPageWidget(_factory.prevPage),
          nextPage: _buildPageWidget(_factory.nextPage),
          size: size,
        ),
      ),
    );
  }

  Widget _buildPageWidget(String content) {
    if (content.isEmpty) {
      return Container(color: widget.backgroundColor);
    }

    final topSafe = MediaQuery.of(context).padding.top;
    final bottomSafe = MediaQuery.of(context).padding.bottom;

    return Container(
      color: widget.backgroundColor,
      child: Stack(
        children: [
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                widget.padding.left,
                topSafe + PagedReaderWidget.topOffset,
                widget.padding.right,
                bottomSafe + PagedReaderWidget.bottomOffset,
              ),
              child: Text.rich(
                TextSpan(text: content, style: widget.textStyle),
                textAlign: TextAlign.justify,
              ),
            ),
          ),
          if (widget.showStatusBar) _buildOverlay(topSafe, bottomSafe),
        ],
      ),
    );
  }

  Widget _buildOverlay(double topSafe, double bottomSafe) {
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
}
