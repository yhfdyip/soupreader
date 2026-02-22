import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:intl/intl.dart';
import '../models/reading_settings.dart';
import 'package:battery_plus/battery_plus.dart';
import '../services/reader_image_marker_codec.dart';
import '../services/reader_image_request_parser.dart';
import 'legacy_justified_text.dart';
import 'page_factory.dart';
import 'simulation_page_painter.dart';
import 'simulation_page_painter2.dart';

class PagedReaderLongPressSelection {
  const PagedReaderLongPressSelection({
    required this.text,
    required this.globalPosition,
  });

  final String text;
  final Offset globalPosition;
}

/// 翻页阅读器组件（对标 Legado ReadView + flutter_novel）
/// 核心优化：使用 PictureRecorder 预渲染页面，避免截图开销
class PagedReaderWidget extends StatefulWidget {
  final PageFactory pageFactory;
  final PageTurnMode pageTurnMode;
  final TextStyle textStyle;
  final Color backgroundColor;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  final bool showStatusBar;
  final ReadingSettings settings;
  final bool paddingDisplayCutouts;
  final String bookTitle;
  final Map<String, int> clickActions;
  final ValueChanged<int>? onAction;
  final String? searchHighlightQuery;
  final Color? searchHighlightColor;
  final Color? searchHighlightTextColor;
  final String legacyImageStyle;
  final VoidCallback? onImageSizeCacheUpdated;
  final void Function(String src, Size resolvedSize)? onImageSizeResolved;
  final bool showTipBars;
  final ValueChanged<PagedReaderLongPressSelection>? onTextLongPress;

  // === 翻页动画增强 ===
  final int animDuration; // 动画时长 (100-600ms)
  final PageDirection pageDirection; // 翻页方向
  final int pageTouchSlop; // 翻页触发阈值（0=系统默认，1-9999=自定义）

  // legado 提示层基线参数：用于分页模式的页眉/页脚占位计算（含边缘间距与分割线节奏）。
  static const double _tipHeaderFontSize = 12.0;
  static const double _tipFooterFontSize = 11.0;
  static const double _tipEdgeInset = 6.0;
  static const double _tipLineGap = 6.0;
  static const double _tipDividerThickness = 0.5;
  static const double topOffset = 37;
  static const double bottomOffset = 37;

  static double resolveHeaderSlotHeight({
    required ReadingSettings settings,
    required bool showStatusBar,
  }) {
    if (!settings.shouldShowHeader(showStatusBar: showStatusBar)) return 0.0;
    final dividerHeight =
        settings.showHeaderLine ? _tipLineGap + _tipDividerThickness : 0.0;
    return _tipEdgeInset +
        settings.headerPaddingTop +
        _tipHeaderFontSize +
        settings.headerPaddingBottom +
        dividerHeight;
  }

  static double resolveFooterSlotHeight({
    required ReadingSettings settings,
  }) {
    if (!settings.shouldShowFooter()) return 0.0;
    final dividerHeight =
        settings.showFooterLine ? _tipLineGap + _tipDividerThickness : 0.0;
    return _tipEdgeInset +
        settings.footerPaddingBottom +
        _tipFooterFontSize +
        settings.footerPaddingTop +
        dividerHeight;
  }

  const PagedReaderWidget({
    super.key,
    required this.pageFactory,
    required this.pageTurnMode,
    required this.textStyle,
    required this.backgroundColor,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.showStatusBar = true,
    required this.settings,
    this.paddingDisplayCutouts = false,
    required this.bookTitle,
    this.clickActions = const {},
    this.onAction,
    this.searchHighlightQuery,
    this.searchHighlightColor,
    this.searchHighlightTextColor,
    this.legacyImageStyle = 'DEFAULT',
    this.onImageSizeCacheUpdated,
    this.onImageSizeResolved,
    this.showTipBars = true,
    this.onTextLongPress,
    // 翻页动画增强默认值
    this.animDuration = 300,
    this.pageDirection = PageDirection.horizontal,
    this.pageTouchSlop = 0,
    this.enableGestures = true,
  });

  final bool enableGestures;

  @override
  State<PagedReaderWidget> createState() => _PagedReaderWidgetState();
}

class _PagedReaderWidgetState extends State<PagedReaderWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;

  // === 对标 Legado PageDelegate 的状态变量 ===
  bool _isMoved = false; // 是否已移动（触发方向判断）
  bool _isRunning = false; // 动画是否运行中（控制渲染）
  bool _isStarted = false; // Scroller 是否已启动
  bool _isCancel = false; // 是否取消翻页
  _PageDirection _direction = _PageDirection.none; // 翻页方向

  // === 坐标系统（对标 Legado ReadView） ===
  double _startX = 0; // 按下的起始点
  double _startY = 0;
  double _lastX = 0; // 上一帧触摸点
  double _touchX = 0.1; // 当前触摸点（P1: 不让x,y为0,否则在点计算时会有问题）
  double _touchY = 0.1;

  // === P2: 角点状态变量（对标 Legado mCornerX, mCornerY）===
  double _cornerX = 0;
  double _cornerY = 0;

  // === Scroller 风格动画（对标 Legado Scroller） ===
  double _scrollStartX = 0;
  double _scrollStartY = 0;
  double _scrollDx = 0;
  double _scrollDy = 0;

  // 页面 Picture 缓存（仿真模式用）
  ui.Picture? _curPagePicture;
  ui.Picture? _prevPagePicture;
  ui.Picture? _nextPagePicture;
  Size? _lastSize;

  // 页眉/页脚坐标使用稳定系统安全区，避免系统栏 inset 延迟变化导致分割线抖动
  EdgeInsets? _stableSystemPadding;
  Orientation? _stablePaddingOrientation;
  bool? _stableShowHeader;
  bool? _stableShowFooter;
  bool _pendingSystemPaddingRefresh = false;

  // Shader Program
  static ui.FragmentProgram? pageCurlProgram;
  ui.Image? _curPageImage;
  ui.Image? _targetPageImage;
  bool _isCurImageLoading = false;
  bool _isTargetImageLoading = false;
  final Set<String> _imageSizeTrackingInFlight = <String>{};

  // 手势拖拽期间尽量不做同步预渲染，避免卡顿
  bool _gestureInProgress = false;

  // 预渲染调度（拆分为多帧，避免一次性卡住 UI）
  bool _precacheScheduled = false;
  int _precacheEpoch = 0;
  // 动画/拖拽期间延迟执行 Picture 失效，避免收尾阶段出现二次重绘。
  bool _pendingPictureInvalidation = false;
  bool _pendingPictureInvalidationFlushScheduled = false;

  // 仿真翻页门闩：启动动画前必须等待关键帧资源就绪
  bool _isPreparingSimulationTurn = false;
  int _simulationPrepareToken = 0;

  // 电池状态
  final Battery _battery = Battery();
  int _batteryLevel = 100;
  StreamSubscription<BatteryState>? _batteryStateSubscription;

  bool get _isInteractionRunning =>
      _gestureInProgress || _isMoved || _isRunning || _isStarted;

  void _debugTrace(String message) {
    assert(() {
      debugPrint('[PagedReaderWidget] $message');
      return true;
    }());
  }

  void _onPageFactoryContentChangedForRender() {
    if (!mounted) return;
    _cancelPendingSimulationPreparation();
    if (_isInteractionRunning) {
      _markPictureInvalidationPending();
      return;
    }
    _pendingPictureInvalidation = false;
    _invalidatePictures();
    setState(() {});
    _schedulePrecache();
  }

  void _markPictureInvalidationPending() {
    _pendingPictureInvalidation = true;
    _schedulePendingPictureInvalidationFlush();
  }

  void _schedulePendingPictureInvalidationFlush() {
    if (!mounted) return;
    if (_pendingPictureInvalidationFlushScheduled) return;
    _pendingPictureInvalidationFlushScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pendingPictureInvalidationFlushScheduled = false;
      if (!mounted) return;
      _flushPendingPictureInvalidationIfIdle();
      if (_pendingPictureInvalidation) {
        _schedulePendingPictureInvalidationFlush();
      }
    });
  }

  void _flushPendingPictureInvalidationIfIdle({bool rebuild = true}) {
    if (!_pendingPictureInvalidation) return;
    if (_isInteractionRunning) return;
    _pendingPictureInvalidation = false;
    _invalidatePictures();
    if (rebuild && mounted) {
      setState(() {});
    }
  }

  @override
  void initState() {
    super.initState();
    _loadShader();
    _initBattery();
    _animController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: widget.animDuration),
    );

    // === 对标 Legado computeScroll ===
    // 使用 AnimationController 的 listener 来驱动动画
    _animController.addListener(_computeScroll);
    _animController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _onAnimComplete();
      }
    });

    widget.pageFactory
        .addContentChangedListener(_onPageFactoryContentChangedForRender);

    // 首次进入页面后，利用空闲帧预渲染当前/相邻页，避免首次拖拽翻页卡顿
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _schedulePrecache();
      _warmupSimulationFrames();
    });
  }

  Future<void> _loadShader() async {
    if (pageCurlProgram != null) return;
    try {
      pageCurlProgram = await ui.FragmentProgram.fromAsset(
          'lib/features/reader/shaders/page_curl.frag');
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      debugPrint('Failed to load shader: $e');
    }
  }

  @override
  void didUpdateWidget(PagedReaderWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 动画时长变化时更新 AnimationController
    if (oldWidget.animDuration != widget.animDuration) {
      _animController.duration = Duration(milliseconds: widget.animDuration);
    }
    if (oldWidget.pageFactory != widget.pageFactory) {
      oldWidget.pageFactory.removeContentChangedListener(
        _onPageFactoryContentChangedForRender,
      );
      widget.pageFactory.addContentChangedListener(
        _onPageFactoryContentChangedForRender,
      );
    }
    if (oldWidget.pageFactory != widget.pageFactory ||
        oldWidget.textStyle != widget.textStyle ||
        oldWidget.backgroundColor != widget.backgroundColor ||
        oldWidget.padding != widget.padding ||
        oldWidget.settings != widget.settings ||
        oldWidget.searchHighlightQuery != widget.searchHighlightQuery ||
        oldWidget.searchHighlightColor != widget.searchHighlightColor ||
        oldWidget.searchHighlightTextColor != widget.searchHighlightTextColor) {
      _invalidatePictures();
      _schedulePrecache();
    }
    if (oldWidget.pageTurnMode != widget.pageTurnMode &&
        widget.pageTurnMode == PageTurnMode.simulation) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _warmupSimulationFrames();
      });
    }
  }

  @override
  void dispose() {
    _cancelPendingSimulationPreparation();
    _batteryStateSubscription?.cancel();
    widget.pageFactory.removeContentChangedListener(
      _onPageFactoryContentChangedForRender,
    );
    _animController.dispose();
    _invalidatePictures();
    _imageSizeTrackingInFlight.clear();
    super.dispose();
  }

  Future<void> _initBattery() async {
    try {
      _applyBatteryLevel(await _battery.batteryLevel, forceRebuild: true);
      _batteryStateSubscription =
          _battery.onBatteryStateChanged.listen((state) {
        unawaited(_updateBatteryLevel());
      });
    } catch (_) {}
  }

  Future<void> _updateBatteryLevel() async {
    try {
      _applyBatteryLevel(await _battery.batteryLevel);
    } catch (_) {}
  }

  void _applyBatteryLevel(int rawLevel, {bool forceRebuild = false}) {
    final nextLevel = rawLevel.clamp(0, 100).toInt();
    final changed = _batteryLevel != nextLevel;
    _batteryLevel = nextLevel;
    if (!mounted) return;
    if (!changed && !forceRebuild) return;
    if (_isInteractionRunning && !forceRebuild) {
      if (_needsPictureCache) {
        _markPictureInvalidationPending();
      }
      return;
    }
    if (_needsPictureCache && _showAnyTipBar && widget.settings.showBattery) {
      _pendingPictureInvalidation = false;
      _invalidatePictures();
      _schedulePrecache();
    }
    setState(() {});
  }

  PageFactory get _factory => widget.pageFactory;

  static const String _legacyImageStyleDefault = 'DEFAULT';
  static const String _legacyImageStyleFull = 'FULL';
  static const String _legacyImageStyleSingle = 'SINGLE';

  PageTurnMode get _effectivePageTurnMode => widget.pageTurnMode;

  bool _contentHasImageMarker(String content) {
    return ReaderImageMarkerCodec.containsMarker(content);
  }

  bool get _needsPictureCache =>
      _effectivePageTurnMode == PageTurnMode.simulation ||
      _effectivePageTurnMode == PageTurnMode.simulation2 ||
      _effectivePageTurnMode == PageTurnMode.slide ||
      _effectivePageTurnMode == PageTurnMode.cover ||
      _effectivePageTurnMode == PageTurnMode.none;

  bool get _needsShaderImages =>
      _effectivePageTurnMode == PageTurnMode.simulation;

  bool get _isLegacyNonSimulationMode =>
      _effectivePageTurnMode == PageTurnMode.slide ||
      _effectivePageTurnMode == PageTurnMode.cover ||
      _effectivePageTurnMode == PageTurnMode.none;

  bool get _hasHeaderSlot =>
      widget.settings.shouldShowHeader(showStatusBar: widget.showStatusBar);
  bool get _hasFooterSlot => widget.settings.shouldShowFooter();
  bool get _showHeader => widget.showTipBars && _hasHeaderSlot;
  bool get _showFooter => widget.showTipBars && _hasFooterSlot;
  bool get _showAnyTipBar => _showHeader || _showFooter;

  Color get _tipTextColor {
    final contentColor = widget.textStyle.color ?? const Color(0xff8B7961);
    return widget.settings.resolveTipTextColor(contentColor);
  }

  Color get _tipDividerColor {
    final defaultDivider = widget.textStyle.color?.withValues(alpha: 0.2) ??
        const Color(0x4C8B7961);
    return widget.settings.resolveTipDividerColor(
      contentColor: _tipTextColor,
      defaultDividerColor: defaultDivider,
    );
  }

  double get _headerSlotHeight {
    return PagedReaderWidget.resolveHeaderSlotHeight(
      settings: widget.settings,
      showStatusBar: widget.showStatusBar,
    );
  }

  double get _footerSlotHeight {
    return PagedReaderWidget.resolveFooterSlotHeight(
      settings: widget.settings,
    );
  }

  // 页眉/页脚占位保持稳定，避免仅隐藏提示条时正文发生上下跳动。
  double get _topOffset => _hasHeaderSlot ? _headerSlotHeight : 0.0;
  double get _bottomOffset => _hasFooterSlot ? _footerSlotHeight : 0.0;

  void _applyStableSystemPadding({
    required EdgeInsets padding,
    required Orientation orientation,
  }) {
    _stableSystemPadding = padding;
    _stablePaddingOrientation = orientation;
    _stableShowHeader = _hasHeaderSlot;
    _stableShowFooter = _hasFooterSlot;
    _pendingSystemPaddingRefresh = false;
    _debugTrace(
      'apply_stable_padding top=${padding.top.toStringAsFixed(1)} bottom=${padding.bottom.toStringAsFixed(1)} orientation=$orientation',
    );
  }

  bool _flushPendingSystemPaddingRefresh() {
    if (!_pendingSystemPaddingRefresh) return false;
    if (!mounted || _isInteractionRunning) return false;
    final mediaQuery = MediaQuery.of(context);
    _applyStableSystemPadding(
      padding: _resolveSystemPaddingForLayout(mediaQuery),
      orientation: mediaQuery.orientation,
    );
    _debugTrace('flush_pending_padding_refresh');
    return true;
  }

  EdgeInsets _resolveSystemPaddingForLayout(MediaQueryData mediaQuery) {
    final systemPadding = mediaQuery.padding;
    final viewPadding = mediaQuery.viewPadding;
    if (!widget.paddingDisplayCutouts) {
      return EdgeInsets.only(
        top: widget.showStatusBar ? systemPadding.top : 0.0,
        bottom: widget.settings.hideNavigationBar ? 0.0 : systemPadding.bottom,
      );
    }
    return EdgeInsets.only(
      left: viewPadding.left,
      top: widget.showStatusBar ? systemPadding.top : viewPadding.top,
      right: viewPadding.right,
      bottom: widget.settings.hideNavigationBar
          ? viewPadding.bottom
          : systemPadding.bottom,
    );
  }

  EdgeInsets _resolveStableSystemPadding() {
    final mediaQuery = MediaQuery.of(context);
    final mediaPadding = _resolveSystemPaddingForLayout(mediaQuery);
    final orientation = mediaQuery.orientation;
    final shouldRefresh = _stableSystemPadding == null ||
        _stablePaddingOrientation != orientation ||
        _stableShowHeader != _hasHeaderSlot ||
        _stableShowFooter != _hasFooterSlot;
    if (shouldRefresh) {
      if (_isInteractionRunning && _stableSystemPadding != null) {
        _pendingSystemPaddingRefresh = true;
        _debugTrace('defer_padding_refresh_during_interaction');
      } else {
        _applyStableSystemPadding(
          padding: mediaPadding,
          orientation: orientation,
        );
      }
    }
    return _stableSystemPadding ?? mediaPadding;
  }

  /// 使用 PictureRecorder 预渲染页面内容
  ui.Picture _recordPage(
    String content,
    Size size, {
    required PageRenderSlot slot,
  }) {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    final systemPadding = _resolveStableSystemPadding();
    final topSafe = systemPadding.top;
    final bottomSafe = systemPadding.bottom;
    final renderPosition = _factory.resolveRenderPosition(slot);

    // 绘制背景
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = widget.backgroundColor,
    );

    final pictureContent = _contentForPictureSnapshot(content);
    if (pictureContent.isNotEmpty) {
      final contentWidth =
          size.width - widget.padding.left - widget.padding.right;
      final contentHeight = size.height -
          (topSafe + _topOffset + widget.padding.top) -
          (bottomSafe + _bottomOffset + widget.padding.bottom);
      final titleData = _resolvePageTitleRenderData(
        content: pictureContent,
        renderPosition: renderPosition,
      );
      var bodyOriginY = topSafe + _topOffset + widget.padding.top;
      var bodyHeight = contentHeight;
      if (titleData.shouldRenderTitle) {
        final consumed = _paintPageTitleOnCanvas(
          canvas: canvas,
          origin: Offset(widget.padding.left, bodyOriginY),
          maxWidth: contentWidth,
          maxHeight: bodyHeight,
          title: titleData.title!,
        );
        bodyOriginY += consumed;
        bodyHeight -= consumed;
      }
      if (bodyHeight > 0) {
        LegacyJustifyComposer.paintContentOnCanvas(
          canvas: canvas,
          origin: Offset(
            widget.padding.left,
            bodyOriginY,
          ),
          content: titleData.bodyContent,
          style: widget.textStyle,
          maxWidth: contentWidth,
          justify: widget.settings.textFullJustify,
          paragraphIndent: widget.settings.paragraphIndent,
          applyParagraphIndent: false,
          preserveEmptyLines: true,
          maxHeight: bodyHeight,
          bottomJustify: widget.settings.textBottomJustify,
          highlightQuery: widget.searchHighlightQuery,
          highlightBackgroundColor: widget.searchHighlightColor,
          highlightTextColor: widget.searchHighlightTextColor,
        );
      }
    }

    // 绘制状态栏
    if (_showAnyTipBar) {
      _paintHeaderFooter(
        canvas,
        size,
        topSafe,
        bottomSafe,
        renderPosition: renderPosition,
      );
    }

    return recorder.endRecording();
  }

  void _paintHeaderFooter(
    Canvas canvas,
    Size size,
    double topSafe,
    double bottomSafe, {
    required PageRenderPosition renderPosition,
  }) {
    final statusColor = _tipTextColor;
    final dividerColor = _tipDividerColor;
    final headerStyle =
        widget.textStyle.copyWith(fontSize: 12, color: statusColor);
    final footerStyle =
        widget.textStyle.copyWith(fontSize: 11, color: statusColor);

    if (_showHeader) {
      final y = topSafe +
          PagedReaderWidget._tipEdgeInset +
          widget.settings.headerPaddingTop;
      _paintTipRow(
        canvas,
        size,
        y,
        headerStyle,
        _tipTextForHeader(
          widget.settings.headerLeftContent,
          renderPosition: renderPosition,
        ),
        _tipTextForHeader(
          widget.settings.headerCenterContent,
          renderPosition: renderPosition,
        ),
        _tipTextForHeader(
          widget.settings.headerRightContent,
          renderPosition: renderPosition,
        ),
        leftPadding: widget.settings.headerPaddingLeft,
        rightPadding: widget.settings.headerPaddingRight,
      );
      if (widget.settings.showHeaderLine) {
        final lineY = topSafe +
            _headerSlotHeight -
            (PagedReaderWidget._tipDividerThickness / 2);
        final paint = Paint()
          ..color = dividerColor
          ..strokeWidth = PagedReaderWidget._tipDividerThickness;
        final lineStart =
            widget.settings.headerPaddingLeft.clamp(0.0, size.width).toDouble();
        final lineEnd = (size.width - widget.settings.headerPaddingRight)
            .clamp(0.0, size.width)
            .toDouble();
        if (lineEnd > lineStart) {
          canvas.drawLine(
            Offset(lineStart, lineY),
            Offset(lineEnd, lineY),
            paint,
          );
        }
      }
    }

    if (_showFooter) {
      final sample = _tipTextForFooter(
            widget.settings.footerLeftContent,
            renderPosition: renderPosition,
          ) ??
          _tipTextForFooter(
            widget.settings.footerCenterContent,
            renderPosition: renderPosition,
          ) ??
          _tipTextForFooter(
            widget.settings.footerRightContent,
            renderPosition: renderPosition,
          ) ??
          '';
      final samplePainter = TextPainter(
        text: TextSpan(text: sample, style: footerStyle),
        textDirection: ui.TextDirection.ltr,
      )..layout();
      final y = size.height -
          bottomSafe -
          PagedReaderWidget._tipEdgeInset -
          widget.settings.footerPaddingBottom -
          samplePainter.height;
      _paintTipRow(
        canvas,
        size,
        y,
        footerStyle,
        _tipTextForFooter(
          widget.settings.footerLeftContent,
          renderPosition: renderPosition,
        ),
        _tipTextForFooter(
          widget.settings.footerCenterContent,
          renderPosition: renderPosition,
        ),
        _tipTextForFooter(
          widget.settings.footerRightContent,
          renderPosition: renderPosition,
        ),
        leftPadding: widget.settings.footerPaddingLeft,
        rightPadding: widget.settings.footerPaddingRight,
      );
      if (widget.settings.showFooterLine) {
        final lineY = size.height -
            bottomSafe -
            _footerSlotHeight +
            (PagedReaderWidget._tipDividerThickness / 2);
        final paint = Paint()
          ..color = dividerColor
          ..strokeWidth = PagedReaderWidget._tipDividerThickness;
        final lineStart =
            widget.settings.footerPaddingLeft.clamp(0.0, size.width).toDouble();
        final lineEnd = (size.width - widget.settings.footerPaddingRight)
            .clamp(0.0, size.width)
            .toDouble();
        if (lineEnd > lineStart) {
          canvas.drawLine(
            Offset(lineStart, lineY),
            Offset(lineEnd, lineY),
            paint,
          );
        }
      }
    }
  }

  void _paintTipRow(
    Canvas canvas,
    Size size,
    double y,
    TextStyle style,
    String? left,
    String? center,
    String? right, {
    required double leftPadding,
    required double rightPadding,
  }) {
    final safeLeft = leftPadding.clamp(0.0, size.width).toDouble();
    final safeRight = rightPadding.clamp(0.0, size.width).toDouble();
    final maxWidth = (size.width - safeLeft - safeRight).clamp(0.0, size.width);
    if (maxWidth <= 0) return;

    if (left != null && left.isNotEmpty) {
      final painter = TextPainter(
        text: TextSpan(text: left, style: style),
        textDirection: ui.TextDirection.ltr,
        maxLines: 1,
        ellipsis: '...',
      )..layout(maxWidth: maxWidth);
      painter.paint(canvas, Offset(safeLeft, y));
    }
    if (center != null && center.isNotEmpty) {
      final painter = TextPainter(
        text: TextSpan(text: center, style: style),
        textDirection: ui.TextDirection.ltr,
        maxLines: 1,
        ellipsis: '...',
      )..layout(maxWidth: maxWidth);
      final x = safeLeft + (maxWidth - painter.width) / 2;
      painter.paint(canvas, Offset(x, y));
    }
    if (right != null && right.isNotEmpty) {
      final painter = TextPainter(
        text: TextSpan(text: right, style: style),
        textDirection: ui.TextDirection.ltr,
        maxLines: 1,
        ellipsis: '...',
      )..layout(maxWidth: maxWidth);
      painter.paint(
        canvas,
        Offset(size.width - safeRight - painter.width, y),
      );
    }
  }

  String? _tipTextForHeader(
    int type, {
    required PageRenderPosition renderPosition,
  }) {
    return _tipText(
      type,
      isHeader: true,
      renderPosition: renderPosition,
    );
  }

  String? _tipTextForFooter(
    int type, {
    required PageRenderPosition renderPosition,
  }) {
    return _tipText(
      type,
      isHeader: false,
      renderPosition: renderPosition,
    );
  }

  String? _tipText(
    int type, {
    required bool isHeader,
    required PageRenderPosition renderPosition,
  }) {
    final time = DateFormat('HH:mm').format(DateTime.now());
    final bookProgress = _bookProgress(renderPosition);
    final chapterProgress = _chapterProgress(renderPosition);
    switch (type) {
      case 0:
        return isHeader
            ? widget.bookTitle
            : _progressText(bookProgress,
                enabled: widget.settings.showProgress);
      case 1:
        return isHeader
            ? renderPosition.chapterTitle
            : _pageText(renderPosition, includeTotal: true);
      case 2:
        return isHeader ? '' : _timeText(time);
      case 3:
        return isHeader ? _timeText(time) : _batteryText();
      case 4:
        return isHeader ? _batteryText() : '';
      case 5:
        return isHeader
            ? _progressText(bookProgress, enabled: widget.settings.showProgress)
            : renderPosition.chapterTitle;
      case 6:
        return isHeader
            ? _pageText(renderPosition, includeTotal: true)
            : widget.bookTitle;
      case 7:
        return _progressText(chapterProgress,
            enabled: widget.settings.showChapterProgress);
      case 8:
        return _pageText(renderPosition, includeTotal: true);
      case 9:
        return _timeBatteryText(time);
      default:
        return '';
    }
  }

  String _pageText(
    PageRenderPosition renderPosition, {
    bool includeTotal = true,
  }) {
    final current = renderPosition.pageIndex + 1;
    final total = renderPosition.totalPages.clamp(1, 9999);
    return includeTotal ? '$current/$total' : '$current';
  }

  String _progressText(double progress, {bool enabled = true}) {
    if (!enabled) return '';
    return '${(progress * 100).toStringAsFixed(1)}%';
  }

  String _batteryText() {
    if (!widget.settings.showBattery) return '';
    return '$_batteryLevel%';
  }

  String _timeText(String time) {
    if (!widget.settings.showTime) return '';
    return time;
  }

  String _timeBatteryText(String time) {
    final parts = <String>[];
    if (widget.settings.showTime) parts.add(time);
    if (widget.settings.showBattery) parts.add('$_batteryLevel%');
    return parts.join(' ');
  }

  double _chapterProgress(PageRenderPosition renderPosition) {
    final total = renderPosition.totalPages;
    if (total <= 0) return 0;
    return ((renderPosition.pageIndex + 1) / total).clamp(0.0, 1.0);
  }

  double _bookProgress(PageRenderPosition renderPosition) {
    final totalChapters = _factory.totalChapters;
    if (totalChapters <= 0) return 0;
    final chapterProgress = _chapterProgress(renderPosition);
    return ((renderPosition.chapterIndex + chapterProgress) / totalChapters)
        .clamp(0.0, 1.0);
  }

  void _invalidatePictures() {
    // 取消未执行的预渲染回调（通过 epoch 失效化）
    _precacheEpoch++;
    _curPagePicture?.dispose();
    _curPagePicture = null;
    _prevPagePicture?.dispose();
    _prevPagePicture = null;
    _nextPagePicture?.dispose();
    _nextPagePicture = null;
    _curPageImage?.dispose();
    _curPageImage = null;
    _targetPageImage?.dispose();
    _targetPageImage = null;
    _isCurImageLoading = false;
    _isTargetImageLoading = false;
  }

  void _invalidateTargetCache() {
    _targetPageImage?.dispose();
    _targetPageImage = null;
    _isTargetImageLoading = false;
  }

  void _cancelPendingSimulationPreparation() {
    _simulationPrepareToken++;
    _isPreparingSimulationTurn = false;
  }

  void _warmupSimulationFrames() {
    if (!mounted || !_needsShaderImages) return;
    final size = MediaQuery.of(context).size;
    _ensureShaderImages(
      size,
      allowRecord: true,
      requestVisualUpdate: false,
    );
  }

  Future<ui.Image> _convertToHighResImage(ui.Picture picture, Size size) async {
    final dpr = MediaQuery.of(context).devicePixelRatio;
    final int w = (size.width * dpr).toInt();
    final int h = (size.height * dpr).toInt();

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.scale(dpr);
    canvas.drawPicture(picture);
    final highResPicture = recorder.endRecording();

    final img = await highResPicture.toImage(w, h);
    // highResPicture.dispose(); // Picture.toImage consumes or we can dispose?
    // Actually ui.Picture.toImage doesn't consume, but we should dispose the picture after use.
    highResPicture.dispose();
    return img;
  }

  void _ensurePictureCacheSize(Size size) {
    if (_lastSize != size) {
      _invalidatePictures();
      _lastSize = size;
    }
  }

  void _syncAdjacentPictureAvailability() {
    if (!_factory.hasPrev()) {
      _prevPagePicture?.dispose();
      _prevPagePicture = null;
    }
    if (!_factory.hasNext()) {
      _nextPagePicture?.dispose();
      _nextPagePicture = null;
    }
  }

  bool _shouldUsePicturePathForContent(String content) {
    if (!_contentHasImageMarker(content)) {
      return true;
    }
    final mode = _effectivePageTurnMode;
    return mode == PageTurnMode.simulation || mode == PageTurnMode.simulation2;
  }

  String _contentForPictureSnapshot(String content) {
    if (!_contentHasImageMarker(content)) {
      return content;
    }
    final lines = content.replaceAll('\r\n', '\n').split('\n');
    final buffer = StringBuffer();
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final text = ReaderImageMarkerCodec.decodeMetaLine(line) == null
          ? line
          : ReaderImageMarkerCodec.textFallbackPlaceholder;
      buffer.write(text);
      if (i != lines.length - 1) {
        buffer.write('\n');
      }
    }
    return buffer.toString();
  }

  void _ensureCurrentPagePicture(
    Size size, {
    bool allowRecord = true,
  }) {
    _ensurePictureCacheSize(size);
    _syncAdjacentPictureAvailability();
    if (!allowRecord) return;
    if (!_shouldUsePicturePathForContent(_factory.curPage)) {
      _curPagePicture?.dispose();
      _curPagePicture = null;
      return;
    }
    _curPagePicture ??=
        _recordPage(_factory.curPage, size, slot: PageRenderSlot.current);
  }

  void _ensureDirectionTargetPicture(
    Size size, {
    required _PageDirection direction,
    bool allowRecord = true,
  }) {
    _ensureCurrentPagePicture(size, allowRecord: allowRecord);
    if (!allowRecord) return;

    if (direction == _PageDirection.prev && _factory.hasPrev()) {
      if (_shouldUsePicturePathForContent(_factory.prevPage)) {
        _prevPagePicture ??=
            _recordPage(_factory.prevPage, size, slot: PageRenderSlot.prev);
      } else {
        _prevPagePicture?.dispose();
        _prevPagePicture = null;
      }
    } else if (direction == _PageDirection.next && _factory.hasNext()) {
      if (_shouldUsePicturePathForContent(_factory.nextPage)) {
        _nextPagePicture ??=
            _recordPage(_factory.nextPage, size, slot: PageRenderSlot.next);
      } else {
        _nextPagePicture?.dispose();
        _nextPagePicture = null;
      }
    }
  }

  void _ensurePagePictures(Size size, {bool allowRecord = true}) {
    _ensureCurrentPagePicture(size, allowRecord: allowRecord);
    if (!allowRecord) return;

    // 相邻页：预渲染上一页/下一页，避免拖拽时临时生成导致卡顿
    if (_factory.hasPrev()) {
      if (_shouldUsePicturePathForContent(_factory.prevPage)) {
        _prevPagePicture ??=
            _recordPage(_factory.prevPage, size, slot: PageRenderSlot.prev);
      } else {
        _prevPagePicture?.dispose();
        _prevPagePicture = null;
      }
    } else {
      _prevPagePicture?.dispose();
      _prevPagePicture = null;
    }

    if (_factory.hasNext()) {
      if (_shouldUsePicturePathForContent(_factory.nextPage)) {
        _nextPagePicture ??=
            _recordPage(_factory.nextPage, size, slot: PageRenderSlot.next);
      } else {
        _nextPagePicture?.dispose();
        _nextPagePicture = null;
      }
    } else {
      _nextPagePicture?.dispose();
      _nextPagePicture = null;
    }
  }

  bool _shouldRebuildForShaderImageUpdate({
    required bool requestVisualUpdate,
  }) {
    if (requestVisualUpdate &&
        !_isInteractionRunning &&
        !_isPreparingSimulationTurn) {
      _debugTrace('skip_shader_setstate_when_idle');
    }
    return _isInteractionRunning || _isPreparingSimulationTurn;
  }

  void _ensureShaderImages(
    Size size, {
    bool allowRecord = true,
    bool requestVisualUpdate = false,
  }) {
    _ensurePagePictures(size, allowRecord: allowRecord);
    if (!_needsShaderImages) return;

    // 当前页 Image
    if (_curPagePicture != null &&
        _curPageImage == null &&
        !_isCurImageLoading) {
      _isCurImageLoading = true;
      _convertToHighResImage(_curPagePicture!, size).then((img) {
        if (!mounted) {
          img.dispose();
          _isCurImageLoading = false;
          return;
        }
        if (!_needsShaderImages) {
          img.dispose();
          _isCurImageLoading = false;
          return;
        }
        _curPageImage?.dispose();
        _curPageImage = img;
        _isCurImageLoading = false;
        if (_shouldRebuildForShaderImageUpdate(
          requestVisualUpdate: requestVisualUpdate,
        )) {
          setState(() {});
        }
      }).catchError((_) {
        _isCurImageLoading = false;
      });
    }

    // 目标页 Image
    final targetPicture = _direction == _PageDirection.next
        ? _nextPagePicture
        : _direction == _PageDirection.prev
            ? _prevPagePicture
            : null;

    if (targetPicture != null &&
        _targetPageImage == null &&
        !_isTargetImageLoading) {
      _isTargetImageLoading = true;
      _convertToHighResImage(targetPicture, size).then((img) {
        if (!mounted) {
          img.dispose();
          _isTargetImageLoading = false;
          return;
        }
        if (!_needsShaderImages) {
          img.dispose();
          _isTargetImageLoading = false;
          return;
        }
        _targetPageImage?.dispose();
        _targetPageImage = img;
        _isTargetImageLoading = false;
        if (_shouldRebuildForShaderImageUpdate(
          requestVisualUpdate: requestVisualUpdate,
        )) {
          setState(() {});
        }
      }).catchError((_) {
        _isTargetImageLoading = false;
      });
    }
  }

  /// 拆分式预渲染：每帧最多生成一张 Picture，避免一次性生成导致拖拽/动画掉帧。
  void _schedulePrecache() {
    if (!mounted) return;
    if (!_needsPictureCache) return;
    if (_precacheScheduled) return;

    // 正在拖拽/动画时不预渲染，避免争用 UI 线程
    if (_gestureInProgress || _isMoved || _isRunning || _isStarted) return;

    _precacheScheduled = true;
    final epoch = ++_precacheEpoch;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _precacheScheduled = false;
      if (!mounted) return;
      if (epoch != _precacheEpoch) return;
      if (_gestureInProgress || _isMoved || _isRunning || _isStarted) return;

      final size = MediaQuery.of(context).size;
      final didWork = _precacheOnePicture(size);
      if (_needsShaderImages) {
        _ensureShaderImages(
          size,
          allowRecord: true,
          requestVisualUpdate: false,
        );
      }
      if (didWork) {
        // 仍有缺口，继续调度下一帧
        _schedulePrecache();
      }
    });
  }

  bool _precacheOnePicture(Size size) {
    _ensurePictureCacheSize(size);
    _syncAdjacentPictureAvailability();

    if (_curPagePicture == null &&
        _shouldUsePicturePathForContent(_factory.curPage)) {
      _curPagePicture =
          _recordPage(_factory.curPage, size, slot: PageRenderSlot.current);
      return true;
    }

    if (_factory.hasPrev() &&
        _prevPagePicture == null &&
        _shouldUsePicturePathForContent(_factory.prevPage)) {
      _prevPagePicture =
          _recordPage(_factory.prevPage, size, slot: PageRenderSlot.prev);
      return true;
    }

    if (_factory.hasNext() &&
        _nextPagePicture == null &&
        _shouldUsePicturePathForContent(_factory.nextPage)) {
      _nextPagePicture =
          _recordPage(_factory.nextPage, size, slot: PageRenderSlot.next);
      return true;
    }

    return false;
  }

  bool _isSimulationTurnReady(_PageDirection direction) {
    switch (direction) {
      case _PageDirection.next:
        return _curPageImage != null && _nextPagePicture != null;
      case _PageDirection.prev:
        return _targetPageImage != null && _curPagePicture != null;
      case _PageDirection.none:
        return false;
    }
  }

  Future<bool> _prepareSimulationTurnFrames({
    required Size size,
    required _PageDirection direction,
    required int token,
  }) async {
    if (direction == _PageDirection.none) return false;
    if (direction == _PageDirection.next && !_factory.hasNext()) return false;
    if (direction == _PageDirection.prev && !_factory.hasPrev()) return false;

    _ensureShaderImages(
      size,
      allowRecord: true,
      requestVisualUpdate: true,
    );
    if (_isSimulationTurnReady(direction)) return true;

    final deadline = DateTime.now().add(const Duration(milliseconds: 1800));
    while (mounted) {
      if (token != _simulationPrepareToken) return false;
      if (_isSimulationTurnReady(direction)) return true;
      if (DateTime.now().isAfter(deadline)) return false;
      await Future<void>.delayed(const Duration(milliseconds: 16));
      if (!mounted) return false;
      _ensureShaderImages(
        size,
        allowRecord: !_gestureInProgress,
        requestVisualUpdate: true,
      );
    }
    return false;
  }

  void _startTurnAnimation() {
    if (_direction == _PageDirection.none) return;
    final effectiveMode = _effectivePageTurnMode;
    if (effectiveMode == PageTurnMode.none) {
      if (_needsPictureCache) {
        final size = MediaQuery.of(context).size;
        _ensureDirectionTargetPicture(
          size,
          direction: _direction,
          allowRecord: true,
        );
      }
      _completeNoAnimationTurn();
      return;
    }
    if (effectiveMode == PageTurnMode.simulation) {
      unawaited(_startSimulationTurnWhenReady());
      return;
    }
    if (_needsPictureCache) {
      final size = MediaQuery.of(context).size;
      _ensureDirectionTargetPicture(
        size,
        direction: _direction,
        allowRecord: true,
      );
    }
    if (effectiveMode == PageTurnMode.slide ||
        effectiveMode == PageTurnMode.cover) {
      _onAnimStartHorizontalLegacy();
      return;
    }
    _onAnimStart();
  }

  void _completeNoAnimationTurn() {
    final direction = _direction;
    final wasCancel = _isCancel;
    if (!wasCancel) {
      _fillPage(direction);
    }
    _stopScroll(direction: direction, wasCancel: wasCancel);
  }

  Future<void> _startSimulationTurnWhenReady() async {
    if (!mounted || _isPreparingSimulationTurn) return;
    if (_direction == _PageDirection.none) return;

    final direction = _direction;
    final token = ++_simulationPrepareToken;
    _isPreparingSimulationTurn = true;
    final size = MediaQuery.of(context).size;

    try {
      final ready = await _prepareSimulationTurnFrames(
        size: size,
        direction: direction,
        token: token,
      );
      if (!mounted || token != _simulationPrepareToken) return;
      if (_direction != direction) return;

      if (!ready) {
        _isMoved = false;
        _isRunning = false;
        _isStarted = false;
        _isCancel = false;
        _direction = _PageDirection.none;
        _touchX = _startX;
        _touchY = _startY;
        setState(() {});
        return;
      }
      _onAnimStart();
    } finally {
      if (token == _simulationPrepareToken) {
        _isPreparingSimulationTurn = false;
      }
    }
  }

  // === 对标 Legado: setStartPoint ===
  void _setStartPoint(double x, double y) {
    _startX = x;
    _startY = y;
    _lastX = x;
    _touchX = x;
    _touchY = y;
  }

  // === 对标 Legado: setTouchPoint ===
  void _setTouchPoint(double x, double y) {
    _lastX = _touchX;
    _touchX = x;
    _touchY = y;
  }

  void _onTap(Offset position) {
    final action = _resolveClickAction(position);
    switch (action) {
      case ClickAction.showMenu:
        widget.onTap?.call();
        break;
      case ClickAction.nextPage:
        if (widget.enableGestures) {
          _nextPageByAnim(startY: position.dy);
        }
        break;
      case ClickAction.prevPage:
        if (widget.enableGestures) {
          _prevPageByAnim(startY: position.dy);
        }
        break;
      default:
        widget.onAction?.call(action);
    }
  }

  void _onLongPressStart(Offset globalPosition) {
    if (!mounted) return;
    if (!widget.enableGestures) return;
    if (_isInteractionRunning) return;
    final callback = widget.onTextLongPress;
    if (callback == null) return;

    final text = _resolveLongPressSelectedText(globalPosition).trim();
    if (text.isEmpty) return;
    callback(
      PagedReaderLongPressSelection(
        text: text,
        globalPosition: globalPosition,
      ),
    );
  }

  String _resolveLongPressSelectedText(Offset globalPosition) {
    final content = _factory.curPage;
    if (content.trim().isEmpty) return '';

    final size = MediaQuery.of(context).size;
    final contentWidth =
        size.width - widget.padding.left - widget.padding.right;
    if (!contentWidth.isFinite || contentWidth <= 0) {
      return '';
    }

    final systemPadding = _resolveStableSystemPadding();
    final topSafe = systemPadding.top;
    final renderPosition =
        _factory.resolveRenderPosition(PageRenderSlot.current);
    final titleData = _resolvePageTitleRenderData(
      content: content,
      renderPosition: renderPosition,
    );
    final bodyText = _stripImageMarkersFromContent(titleData.bodyContent);

    final contentLeft = widget.padding.left;
    final contentTopBase = topSafe + _topOffset + widget.padding.top;
    var contentTop = contentTopBase;

    if (titleData.shouldRenderTitle) {
      final title = titleData.title!.trim();
      if (title.isNotEmpty) {
        final titlePainter = TextPainter(
          text: TextSpan(text: title, style: _pageTitleStyle),
          textDirection: ui.TextDirection.ltr,
          textAlign: _pageTitleAlign,
          maxLines: null,
        )..layout(maxWidth: contentWidth);

        final titleStart = contentTop + _pageTitleTopSpacing;
        final titleEnd = titleStart + titlePainter.height;
        if (globalPosition.dy >= titleStart && globalPosition.dy <= titleEnd) {
          final localDx =
              (globalPosition.dx - contentLeft).clamp(0.0, contentWidth);
          final offset = titlePainter
              .getPositionForOffset(Offset(localDx, 0))
              .offset
              .clamp(0, title.length - 1)
              .toInt();
          return _extractWordAtIndex(title, offset);
        }
      }
      contentTop += _pageTitleTopSpacing +
          _titlePainterHeight(titleData.title!, contentWidth) +
          _pageTitleBottomSpacing;
    }

    if (bodyText.trim().isEmpty) {
      return '';
    }

    final localY = globalPosition.dy - contentTop;
    if (!localY.isFinite || localY < 0) {
      return '';
    }

    final lines = LegacyJustifyComposer.composeContentLines(
      content: bodyText,
      style: widget.textStyle,
      maxWidth: contentWidth,
      justify: widget.settings.textFullJustify,
      paragraphIndent: widget.settings.paragraphIndent,
      applyParagraphIndent: false,
      preserveEmptyLines: true,
    );
    if (lines.isEmpty) {
      return '';
    }

    LegacyComposedLine? targetLine;
    var lineStartY = 0.0;
    for (final line in lines) {
      final lineEndY = lineStartY + line.height;
      if (localY <= lineEndY) {
        targetLine = line;
        break;
      }
      lineStartY = lineEndY;
    }
    targetLine ??= lines.last;

    final localDx = (globalPosition.dx - contentLeft).clamp(0.0, contentWidth);
    final charIndex = _resolveCharacterIndexInLine(
      line: targetLine,
      x: localDx,
      style: widget.textStyle,
      maxWidth: contentWidth,
    );
    return _extractWordAtIndex(targetLine.plainText, charIndex);
  }

  double _titlePainterHeight(String title, double maxWidth) {
    final painter = TextPainter(
      text: TextSpan(text: title, style: _pageTitleStyle),
      textDirection: ui.TextDirection.ltr,
      textAlign: _pageTitleAlign,
      maxLines: null,
    )..layout(maxWidth: maxWidth);
    return painter.height;
  }

  String _stripImageMarkersFromContent(String content) {
    final lines = content.replaceAll('\r\n', '\n').split('\n');
    final buffer = StringBuffer();
    var first = true;
    for (final line in lines) {
      if (ReaderImageMarkerCodec.decodeLine(line) != null) {
        continue;
      }
      if (!first) {
        buffer.writeln();
      }
      buffer.write(line);
      first = false;
    }
    return buffer.toString();
  }

  int _resolveCharacterIndexInLine({
    required LegacyComposedLine line,
    required double x,
    required TextStyle style,
    required double maxWidth,
  }) {
    final text = line.plainText;
    if (text.isEmpty) return -1;

    if (!line.justified || line.segments.length <= 1) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: ui.TextDirection.ltr,
        maxLines: 1,
      )..layout(maxWidth: maxWidth);
      return painter
          .getPositionForOffset(Offset(x, 0))
          .offset
          .clamp(0, text.length - 1)
          .toInt();
    }

    var cursor = 0;
    var drawX = 0.0;
    for (final segment in line.segments) {
      final segmentText = segment.text;
      for (var i = 0; i < segmentText.length; i++) {
        final char = segmentText.substring(i, i + 1);
        final width = _measureSingleCharWidth(char, style);
        final center = drawX + width / 2;
        if (x <= center) {
          return cursor.clamp(0, text.length - 1).toInt();
        }
        drawX += width;
        cursor += 1;
      }
      if (segment.extraAfter > 0) {
        final center = drawX + segment.extraAfter / 2;
        if (x <= center) {
          return (cursor - 1).clamp(0, text.length - 1).toInt();
        }
        drawX += segment.extraAfter;
      }
    }
    return text.length - 1;
  }

  double _measureSingleCharWidth(String char, TextStyle style) {
    if (char.isEmpty) return 0;
    final painter = TextPainter(
      text: TextSpan(text: char, style: style),
      textDirection: ui.TextDirection.ltr,
      maxLines: 1,
    )..layout(minWidth: 0, maxWidth: double.infinity);
    return painter.width;
  }

  String _extractWordAtIndex(String text, int index) {
    final normalized = text.trimRight();
    if (normalized.isEmpty) return '';
    var safeIndex = index.clamp(0, normalized.length - 1).toInt();
    if (_isWhitespace(normalized[safeIndex])) {
      final left = _findNearestNonWhitespace(
        text: normalized,
        start: safeIndex,
        step: -1,
      );
      final right = _findNearestNonWhitespace(
        text: normalized,
        start: safeIndex,
        step: 1,
      );
      if (left == null && right == null) return '';
      if (left == null) {
        safeIndex = right!;
      } else if (right == null) {
        safeIndex = left;
      } else {
        final leftDistance = (safeIndex - left).abs();
        final rightDistance = (right - safeIndex).abs();
        safeIndex = leftDistance <= rightDistance ? left : right;
      }
    }

    final current = normalized[safeIndex];
    if (!_isWordLike(current)) {
      return current.trim();
    }
    final currentIsCjk = _isCjk(current);

    var start = safeIndex;
    while (start > 0) {
      final previous = normalized[start - 1];
      if (!_isWordLike(previous)) break;
      if (currentIsCjk != _isCjk(previous)) break;
      start -= 1;
    }

    var end = safeIndex + 1;
    while (end < normalized.length) {
      final next = normalized[end];
      if (!_isWordLike(next)) break;
      if (currentIsCjk != _isCjk(next)) break;
      end += 1;
    }

    return normalized.substring(start, end).trim();
  }

  bool _isWhitespace(String value) => value.trim().isEmpty;

  bool _isWordLike(String value) {
    if (value.trim().isEmpty) return false;
    return RegExp(r'[A-Za-z0-9_\u3400-\u9FFF]').hasMatch(value);
  }

  bool _isCjk(String value) => RegExp(r'[\u3400-\u9FFF]').hasMatch(value);

  int? _findNearestNonWhitespace({
    required String text,
    required int start,
    required int step,
  }) {
    var index = start;
    while (true) {
      index += step;
      if (index < 0 || index >= text.length) return null;
      if (!_isWhitespace(text[index])) {
        return index;
      }
    }
  }

  int _resolveClickAction(Offset position) {
    final size = MediaQuery.of(context).size;
    final col = (position.dx / size.width * 3).floor().clamp(0, 2);
    final row = (position.dy / size.height * 3).floor().clamp(0, 2);
    const zones = [
      ['tl', 'tc', 'tr'],
      ['ml', 'mc', 'mr'],
      ['bl', 'bc', 'br'],
    ];
    final zone = zones[row][col];
    final config = ClickAction.normalizeConfig(widget.clickActions);
    return config[zone] ?? ClickAction.showMenu;
  }

  // === 对标 Legado: nextPageByAnim ===
  void _nextPageByAnim({double? startY}) {
    _abortAnim();
    if (!_factory.hasNext()) return;

    final size = MediaQuery.of(context).size;
    final touchStartY = startY ?? size.height * 0.9;
    final y = touchStartY > size.height / 2 ? size.height * 0.9 : 1.0;

    _setStartPoint(size.width * 0.9, y);
    _setDirection(_PageDirection.next);
    _startTurnAnimation();
  }

  // === 对标 Legado: prevPageByAnim ===
  void _prevPageByAnim({double? startY}) {
    _abortAnim();
    if (!_factory.hasPrev()) return;

    final size = MediaQuery.of(context).size;
    _setStartPoint(0, size.height);
    _setDirection(_PageDirection.prev);
    _startTurnAnimation();
  }

  // === 对标 Legado: setDirection ===
  void _setDirection(_PageDirection direction) {
    _direction = direction;
    final size = MediaQuery.of(context).size;

    // === P2/P4: 在方向确定时计算角点（对标 Legado SimulationPageDelegate.setDirection）===
    if (direction == _PageDirection.prev) {
      // 上一页滑动不出现对角（原对标 Legado: 强制使用底边，现移除限制）
      // 现在跟随手指位置 (_startY)
      if (_startX > size.width / 2) {
        _calcCornerXY(_startX, _startY);
      } else {
        // P4: 左半边镜像处理
        _calcCornerXY(size.width - _startX, _startY);
      }
    } else if (direction == _PageDirection.next) {
      if (size.width / 2 > _startX) {
        // 左半边点击时，强制使用右边角点
        _calcCornerXY(size.width - _startX, _startY);
      } else {
        _calcCornerXY(_startX, _startY);
      }
    }

    _invalidateTargetCache();
    if (_needsShaderImages) {
      // 方向变化时立即准备目标帧，避免仿真模式在翻页完成后再异步补帧触发二次重绘。
      _ensureShaderImages(
        size,
        allowRecord: true,
        requestVisualUpdate: true,
      );
    }
    _schedulePrecache();
  }

  // === P2: 计算角点（对标 Legado calcCornerXY）===
  void _calcCornerXY(double x, double y) {
    final size = MediaQuery.of(context).size;
    _cornerX = x <= size.width / 2 ? 0 : size.width;
    _cornerY = y <= size.height / 2 ? 0 : size.height;
  }

  // === 对标 Legado: abortAnim ===
  void _abortAnim() {
    _cancelPendingSimulationPreparation();
    final committedDirection = _direction;
    _isStarted = false;
    _isMoved = false;
    _isRunning = false;
    if (_animController.isAnimating) {
      _animController.stop();
      if (!_isCancel && committedDirection != _PageDirection.none) {
        _fillPage(committedDirection);
        if (_needsPictureCache) {
          final promoted =
              _promoteCachedPicturesOnPageFilled(committedDirection);
          if (promoted) {
            _pendingPictureInvalidation = false;
          } else {
            _markPictureInvalidationPending();
          }
        }
        if (mounted) {
          setState(() {});
          _schedulePrecache();
        }
      }
    }
  }

  // === 对标 Legado: Cover/Slide onAnimStart ===
  void _onAnimStartHorizontalLegacy() {
    final size = MediaQuery.of(context).size;
    double distanceX;
    if (_direction == _PageDirection.next) {
      if (_isCancel) {
        var dis = size.width - _startX + _touchX;
        if (dis > size.width) {
          dis = size.width;
        }
        distanceX = size.width - dis;
      } else {
        distanceX = -(_touchX + (size.width - _startX));
      }
    } else {
      if (_isCancel) {
        distanceX = -(_touchX - _startX);
      } else {
        distanceX = size.width - (_touchX - _startX);
      }
    }
    _startScroll(_touchX, 0, distanceX, 0, widget.animDuration);
  }

  // === 对标 Legado: onAnimStart (SimulationPageDelegate) ===
  void _onAnimStart() {
    final size = MediaQuery.of(context).size;
    double dx, dy;

    // 使用预先计算的角点（对标 Legado mCornerX, mCornerY）
    // 不要重新计算，因为 _setDirection 已经计算好了

    if (_isCancel) {
      // === 取消翻页，回到原位 ===
      if (_cornerX > 0 && _direction == _PageDirection.next) {
        dx = size.width - _touchX;
      } else {
        dx = -_touchX;
      }
      if (_direction != _PageDirection.next) {
        dx = -(size.width + _touchX);
      }
      dy = _cornerY > 0 ? (size.height - _touchY) : -_touchY;
    } else {
      // === 完成翻页 ===
      if (_cornerX > 0 && _direction == _PageDirection.next) {
        dx = -(size.width + _touchX);
      } else {
        dx = size.width - _touchX;
      }
      dy = _cornerY > 0 ? (size.height - _touchY) : (1 - _touchY);
    }

    _startScroll(_touchX, _touchY, dx, dy, widget.animDuration);
  }

  // === 对标 Legado: startScroll ===
  // P5: 动态动画时长计算（对标 Legado PageDelegate.startScroll）
  void _startScroll(
      double startX, double startY, double dx, double dy, int animationSpeed) {
    final size = MediaQuery.of(context).size;
    int duration;
    if (dx != 0) {
      duration = (animationSpeed * dx.abs() / size.width).toInt();
    } else {
      duration = (animationSpeed * dy.abs() / size.height).toInt();
    }

    _scrollStartX = startX;
    _scrollStartY = startY;
    _scrollDx = dx;
    _scrollDy = dy;

    _isRunning = true;
    _isStarted = true;
    _animController.duration = Duration(milliseconds: duration);
    _animController.forward(from: 0);
  }

  // === 对标 Legado: computeScroll (由 AnimationController 驱动) ===
  void _computeScroll() {
    if (!_isStarted || !mounted) return;

    final progress = _animController.value;
    _touchX = _scrollStartX + _scrollDx * progress;
    _touchY = _scrollStartY + _scrollDy * progress;

    // 触发重绘
    (context as Element).markNeedsBuild();
  }

  // === 动画完成回调 ===
  void _onAnimComplete() {
    if (!_isStarted) return;
    final direction = _direction;
    final wasCancel = _isCancel;
    if (!wasCancel) {
      _fillPage(direction);
    }
    _stopScroll(direction: direction, wasCancel: wasCancel);
  }

  // === 对标 Legado: fillPage ===
  void _fillPage(_PageDirection direction) {
    if (direction == _PageDirection.next) {
      _factory.moveToNext();
    } else if (direction == _PageDirection.prev) {
      _factory.moveToPrev();
    }
  }

  // === 对标 Legado: stopScroll ===
  bool _promoteCachedPicturesOnPageFilled(_PageDirection direction) {
    ui.Picture? oldCur = _curPagePicture;
    switch (direction) {
      case _PageDirection.next:
        final promotedCur = _nextPagePicture;
        if (promotedCur == null) return false;
        _prevPagePicture?.dispose();
        _curPagePicture = promotedCur;
        _prevPagePicture = oldCur;
        _nextPagePicture = null;
        break;
      case _PageDirection.prev:
        final promotedCur = _prevPagePicture;
        if (promotedCur == null) return false;
        _nextPagePicture?.dispose();
        _curPagePicture = promotedCur;
        _nextPagePicture = oldCur;
        _prevPagePicture = null;
        break;
      case _PageDirection.none:
        return false;
    }

    _invalidateTargetCache();
    _curPageImage?.dispose();
    _curPageImage = null;
    _isCurImageLoading = false;
    _syncAdjacentPictureAvailability();
    return true;
  }

  void _flushPendingPictureInvalidationAfterSettle({
    required _PageDirection settledDirection,
    required bool wasCancel,
  }) {
    if (!_pendingPictureInvalidation) return;
    if (_isInteractionRunning) return;

    final promoted =
        !wasCancel && _promoteCachedPicturesOnPageFilled(settledDirection);
    if (!promoted) {
      _invalidatePictures();
    }
    _pendingPictureInvalidation = false;
  }

  void _stopScroll({
    required _PageDirection direction,
    required bool wasCancel,
  }) {
    _isStarted = false;
    _isRunning = false;
    // 对齐 legado：动画完成后仅做状态收尾，不在此处触发换页。
    if (mounted) {
      _gestureInProgress = false;
      _isMoved = false;
      _isCancel = false;
      _direction = _PageDirection.none;

      // 重置坐标系统，确保下一次交互从干净状态开始。
      _touchX = 0.1;
      _touchY = 0.1;
      _startX = 0;
      _startY = 0;
      _lastX = 0;
      _scrollDx = 0;
      _scrollDy = 0;
      _cornerX = 0;
      _cornerY = 0;

      _flushPendingPictureInvalidationAfterSettle(
        settledDirection: direction,
        wasCancel: wasCancel,
      );
      _flushPendingSystemPaddingRefresh();
      setState(() {});
      _schedulePrecache();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: widget.backgroundColor,
      child: _buildPageContent(),
    );
  }

  Widget _buildPageContent() {
    // 产品约束：除了“滚动”以外，所有翻页模式都只允许水平手势/水平渲染。
    // 说明：
    // - 滚动模式不使用 PagedReaderWidget（见 SimpleReaderView），因此这里直接兜底为水平。
    // - 这样即使历史配置里残留 `pageDirection=vertical`，也不会把 slide/cover/none/simulation 变成垂直翻页。
    final isVertical = false;
    // 只有启用手势时才允许滑动翻页
    final enableDrag = widget.enableGestures;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapUp: (d) => _onTap(d.globalPosition),
      onLongPressStart: (widget.enableGestures && !_isInteractionRunning)
          ? (details) => _onLongPressStart(details.globalPosition)
          : null,
      // 水平方向手势（仅在启用手势且为水平方向时）
      onHorizontalDragStart: (!isVertical && enableDrag) ? _onDragStart : null,
      onHorizontalDragUpdate:
          (!isVertical && enableDrag) ? _onDragUpdate : null,
      onHorizontalDragEnd: (!isVertical && enableDrag) ? _onDragEnd : null,
      // 垂直方向手势：按产品约束禁用（滚动模式不走这里）
      onVerticalDragStart: null,
      onVerticalDragUpdate: null,
      onVerticalDragEnd: null,
      child: _buildAnimatedPages(),
    );
  }

  Widget _buildAnimatedPages() {
    final size = MediaQuery.of(context).size;
    final screenWidth = size.width;
    final isRunning = _isMoved || _isRunning || _isStarted;
    final effectiveMode = _effectivePageTurnMode;
    if (!isRunning) {
      // 静止态提前预渲染相邻页，避免首次拖拽时同步生成导致的卡顿
      _schedulePrecache();
    }

    // 计算偏移量（基于触摸点相对于起始点的位移）
    // 对于滑动/覆盖模式使用
    final offset = _touchX - _startX;

    switch (effectiveMode) {
      case PageTurnMode.slide:
        if (!isRunning) {
          return _buildStaticRecordedPage(size);
        }
        if (_needsPictureCache) {
          _ensureDirectionTargetPicture(
            size,
            direction: _direction,
            allowRecord: !_gestureInProgress,
          );
        }
        return _buildSlideAnimation(screenWidth, offset);
      case PageTurnMode.cover:
        if (!isRunning) {
          return _buildStaticRecordedPage(size);
        }
        if (_needsPictureCache) {
          _ensureDirectionTargetPicture(
            size,
            direction: _direction,
            allowRecord: !_gestureInProgress,
          );
        }
        return _buildCoverAnimation(screenWidth, offset);
      case PageTurnMode.simulation:
        if (!isRunning) {
          return _buildStaticRecordedPage(size);
        }
        return _buildSimulationAnimation(size);
      case PageTurnMode.simulation2:
        if (!isRunning) {
          return _buildStaticRecordedPage(size);
        }
        return _buildSimulation2Animation(size);
      case PageTurnMode.none:
        if (!isRunning) {
          return _buildStaticRecordedPage(size);
        }
        if (_needsPictureCache) {
          _ensureDirectionTargetPicture(
            size,
            direction: _direction,
            allowRecord: !_gestureInProgress,
          );
        }
        return _buildNoAnimation();
      default:
        return _buildSlideAnimation(screenWidth, offset);
    }
  }

  Widget _buildRecordedPage(
    ui.Picture? picture,
    String fallbackContent, {
    required PageRenderSlot slot,
  }) {
    if (_contentHasImageMarker(fallbackContent)) {
      return _buildPageWidget(fallbackContent, slot: slot);
    }
    // 对齐 legado：动画期间保持快照渲染路径稳定，避免因单帧缓存 miss 回退到 Widget
    // 引发页眉/正文二次重排。
    final resolvedPicture =
        picture ?? _resolveFallbackPictureForAnimation(slot);
    if (resolvedPicture == null) {
      final lockSnapshotDuringInteraction =
          _isInteractionRunning && _isLegacyNonSimulationMode;
      if (lockSnapshotDuringInteraction) {
        final emergencyPicture =
            _curPagePicture ?? _nextPagePicture ?? _prevPagePicture;
        if (emergencyPicture != null) {
          _debugTrace('interaction_running_emergency_picture slot=$slot');
          return RepaintBoundary(
            child: SizedBox.expand(
              child: CustomPaint(
                painter: _PagePicturePainter(emergencyPicture),
                isComplex: true,
              ),
            ),
          );
        }
        _debugTrace('interaction_running_block_widget_fallback slot=$slot');
        return Container(color: widget.backgroundColor);
      }
      return _buildPageWidget(fallbackContent, slot: slot);
    }
    return RepaintBoundary(
      child: SizedBox.expand(
        child: CustomPaint(
          painter: _PagePicturePainter(resolvedPicture),
          isComplex: true,
        ),
      ),
    );
  }

  ui.Picture? _resolveFallbackPictureForAnimation(PageRenderSlot slot) {
    if (!_isInteractionRunning) return null;
    switch (slot) {
      case PageRenderSlot.prev:
        return _prevPagePicture ?? _curPagePicture ?? _nextPagePicture;
      case PageRenderSlot.current:
        return _curPagePicture ?? _nextPagePicture ?? _prevPagePicture;
      case PageRenderSlot.next:
        return _nextPagePicture ?? _curPagePicture ?? _prevPagePicture;
    }
  }

  Widget _buildStaticRecordedPage(Size size) {
    if (_needsPictureCache) {
      // 静止态仅同步确保当前页快照，邻页通过分帧预渲染补齐，减少收尾重绘抖动。
      _ensureCurrentPagePicture(size, allowRecord: true);
    }
    return _buildRecordedPage(
      _curPagePicture,
      _factory.curPage,
      slot: PageRenderSlot.current,
    );
  }

  /// 水平滑动模式
  Widget _buildSlideAnimation(double screenWidth, double offset) {
    final currentPage = _buildRecordedPage(
      _curPagePicture,
      _factory.curPage,
      slot: PageRenderSlot.current,
    );
    if (_direction == _PageDirection.none) {
      return currentPage;
    }
    if ((_direction == _PageDirection.next && offset > 0) ||
        (_direction == _PageDirection.prev && offset < 0)) {
      return currentPage;
    }
    final distanceX = offset > 0 ? offset - screenWidth : offset + screenWidth;
    return Stack(
      children: [
        if (_direction == _PageDirection.prev)
          Transform.translate(
            offset: Offset(distanceX + screenWidth, 0),
            child: currentPage,
          ),
        if (_direction == _PageDirection.prev)
          Transform.translate(
            offset: Offset(distanceX, 0),
            child: _buildRecordedPage(
              _prevPagePicture,
              _factory.prevPage,
              slot: PageRenderSlot.prev,
            ),
          ),
        if (_direction == _PageDirection.next)
          Transform.translate(
            offset: Offset(distanceX, 0),
            child: _buildRecordedPage(
              _nextPagePicture,
              _factory.nextPage,
              slot: PageRenderSlot.next,
            ),
          ),
        if (_direction == _PageDirection.next)
          Transform.translate(
            offset: Offset(distanceX - screenWidth, 0),
            child: currentPage,
          ),
      ],
    );
  }

  /// 覆盖模式
  Widget _buildCoverAnimation(double screenWidth, double offset) {
    final currentPage = _buildRecordedPage(
      _curPagePicture,
      _factory.curPage,
      slot: PageRenderSlot.current,
    );
    if (_direction == _PageDirection.none) {
      return currentPage;
    }
    if ((_direction == _PageDirection.next && offset > 0) ||
        (_direction == _PageDirection.prev && offset < 0)) {
      return currentPage;
    }
    final distanceX = offset > 0 ? offset - screenWidth : offset + screenWidth;

    if (_direction == _PageDirection.next) {
      final revealLeft =
          (screenWidth + offset).clamp(0.0, screenWidth).toDouble();
      return Stack(
        children: [
          Positioned.fill(
            child: ClipRect(
              clipper: _CoverNextRevealClipper(left: revealLeft),
              child: _buildRecordedPage(
                _nextPagePicture,
                _factory.nextPage,
                slot: PageRenderSlot.next,
              ),
            ),
          ),
          Transform.translate(
            offset: Offset(distanceX - screenWidth, 0),
            child: _buildRecordedPage(
              _curPagePicture,
              _factory.curPage,
              slot: PageRenderSlot.current,
            ),
          ),
          _buildLegacyCoverShadow(left: distanceX, screenWidth: screenWidth),
        ],
      );
    }

    if (offset > screenWidth) {
      return Stack(
        children: [
          currentPage,
          _buildRecordedPage(
            _prevPagePicture,
            _factory.prevPage,
            slot: PageRenderSlot.prev,
          ),
        ],
      );
    }

    return Stack(
      children: [
        currentPage,
        Transform.translate(
          offset: Offset(distanceX, 0),
          child: _buildRecordedPage(
            _prevPagePicture,
            _factory.prevPage,
            slot: PageRenderSlot.prev,
          ),
        ),
        _buildLegacyCoverShadow(left: distanceX, screenWidth: screenWidth),
      ],
    );
  }

  Widget _buildLegacyCoverShadow({
    required double left,
    required double screenWidth,
  }) {
    if (left == 0) {
      return const SizedBox.shrink();
    }
    final x = left < 0 ? left + screenWidth : left;
    return Positioned(
      left: x,
      top: 0,
      bottom: 0,
      child: IgnorePointer(
        child: Container(
          width: 30,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [Color(0x66111111), Color(0x00000000)],
            ),
          ),
        ),
      ),
    );
  }

  /// 仿真模式 - 对标 Legado SimulationPageDelegate.onDraw
  /// 关键：只在 isRunning (拖拽或动画) 时渲染仿真效果
  Widget _buildSimulationAnimation(Size size) {
    // === 对标 Legado: if (!isRunning) return ===
    // 静止状态直接返回当前页面Widget，不使用 CustomPaint
    // 这样避免了状态切换时的闪烁
    final isRunning = _isMoved || _isRunning || _isStarted;
    if (!isRunning || pageCurlProgram == null) {
      return _buildStaticRecordedPage(size);
    }

    final isNext = _direction == _PageDirection.next;
    if (_direction == _PageDirection.none) {
      return _buildStaticRecordedPage(size);
    }
    if (isNext && _curPageImage == null) {
      return _buildRecordedPage(
        _curPagePicture,
        _factory.curPage,
        slot: PageRenderSlot.current,
      );
    }
    if (!isNext && _targetPageImage == null) {
      return _buildRecordedPage(
        _curPagePicture,
        _factory.curPage,
        slot: PageRenderSlot.current,
      );
    }

    // === P6: 仿真逻辑修正 ===
    // Next: Peel Current(Top) to reveal Next(Bottom). Curl from Right.
    // Prev: Un-curl Prev(Top) to cover Current(Bottom). Curl from Right (simulating unrolling).

    ui.Image? imageToCurl;
    ui.Picture? bottomPicture;
    double effectiveCornerX;

    if (isNext) {
      imageToCurl = _curPageImage;
      bottomPicture = _nextPagePicture;
      effectiveCornerX = _cornerX;
    } else {
      // Prev: Use Target as the Curling Page (Top), Current as Background (Bottom)
      imageToCurl = _targetPageImage;
      bottomPicture = _curPagePicture;
      // Force Corner to be Right side (simulating we are holding the right edge of the prev page)
      effectiveCornerX = size.width;
    }

    if (imageToCurl == null) {
      return _buildRecordedPage(
        _curPagePicture,
        _factory.curPage,
        slot: PageRenderSlot.current,
      );
    }

    double simulationTouchX = _touchX;
    if (!isNext) {
      // Prev: Apply coordinate mapping to ensure the page un-curls from the left edge (0)
      // instead of starting half-open.
      // Relationship: FoldX = (TouchX + CornerX) / 2
      // We want FoldX = _touchX (approximately, for visual tracking).
      // Since CornerX = width, we solve: _touchX = (VirtualTouchX + width) / 2
      // => VirtualTouchX = 2 * _touchX - size.width
      simulationTouchX = 2 * _touchX - size.width;
    }

    return CustomPaint(
      size: size,
      painter: SimulationPagePainter(
        // Note: 'curPagePicture' arg is unused in Painter logic for shader mode or used as fallback
        // We only care about 'nextPagePicture' which is the Bottom Layer.
        curPagePicture: null,
        nextPagePicture: bottomPicture,
        touch: Offset(simulationTouchX, _touchY),
        viewSize: size,
        isTurnToNext: isNext,
        backgroundColor: widget.backgroundColor,
        cornerX: effectiveCornerX,
        cornerY: _cornerY,
        shaderProgram: pageCurlProgram!,
        curPageImage: imageToCurl,
        devicePixelRatio: MediaQuery.of(context).devicePixelRatio,
      ),
    );
  }

  /// 仿真模式2 - 使用贝塞尔曲线（参考 flutter_novel）
  Widget _buildSimulation2Animation(Size size) {
    final isRunning = _isMoved || _isRunning || _isStarted;
    if (!isRunning) {
      return _buildStaticRecordedPage(size);
    }

    final isNext = _direction == _PageDirection.next;

    // 确保 Picture 已生成（拖拽期间如未命中缓存，则允许降级为普通渲染以避免卡顿）
    _ensurePagePictures(size, allowRecord: !_gestureInProgress);

    ui.Picture? pictureToCurl;
    ui.Picture? bottomPicture;
    double effectiveCornerX;

    if (isNext) {
      pictureToCurl = _curPagePicture;
      bottomPicture = _nextPagePicture;
      effectiveCornerX = _cornerX;
    } else {
      pictureToCurl = _prevPagePicture;
      bottomPicture = _curPagePicture;
      effectiveCornerX = size.width;
    }

    if (pictureToCurl == null) {
      return _buildRecordedPage(
        _curPagePicture,
        _factory.curPage,
        slot: PageRenderSlot.current,
      );
    }

    double simulationTouchX = _touchX;
    if (!isNext) {
      simulationTouchX = 2 * _touchX - size.width;
    }

    return CustomPaint(
      size: size,
      painter: SimulationPagePainter2(
        curPagePicture: pictureToCurl,
        nextPagePicture: bottomPicture,
        touch: Offset(simulationTouchX, _touchY),
        viewSize: size,
        isTurnToNext: isNext,
        backgroundColor: widget.backgroundColor,
        cornerX: effectiveCornerX,
        cornerY: _cornerY,
      ),
    );
  }

  /// 无动画模式
  Widget _buildNoAnimation() {
    // 对齐 legado NoAnimPageDelegate：交互期间不渲染中间过渡帧，始终保持当前页。
    return _buildRecordedPage(
      _curPagePicture,
      _factory.curPage,
      slot: PageRenderSlot.current,
    );
  }

  // === 对标 Legado HorizontalPageDelegate.onTouch ===
  void _onDragStart(DragStartDetails details) {
    if (!widget.enableGestures) return;
    _gestureInProgress = true;
    _cancelPendingSimulationPreparation();
    // 允许中断正在进行的动画，实现连续翻页
    _abortAnim();
    _setStartPoint(details.localPosition.dx, details.localPosition.dy);
    _isMoved = false;
    _isCancel = false;
    _direction = _PageDirection.none;
    if (_needsShaderImages) {
      final size = MediaQuery.of(context).size;
      _ensureShaderImages(
        size,
        allowRecord: true,
        requestVisualUpdate: false,
      );
    }
  }

  // === 对标 Legado HorizontalPageDelegate.onScroll ===
  void _onDragUpdate(DragUpdateDetails details) {
    // _onDragStart 已处理动画中断，此处直接处理拖拽

    final focusX = details.localPosition.dx;
    final focusY = details.localPosition.dy;

    // 判断是否移动了
    if (!_isMoved) {
      final deltaX = (focusX - _startX).abs();
      final deltaY = (focusY - _startY).abs();
      final distance = deltaX * deltaX + deltaY * deltaY;
      // 对齐 legado：0 使用系统 touch slop；非 0 直接作为阈值像素。
      final configuredSlop = widget.pageTouchSlop;
      final slop = configuredSlop == 0 ? kTouchSlop : configuredSlop.toDouble();
      final slopSquare = slop * slop; // 触发阈值

      _isMoved = distance > slopSquare;

      if (_isMoved) {
        // 先保存原始起始点用于方向判断
        final originalStartX = _startX;

        // 判断方向
        final goingRight = focusX - originalStartX > 0;

        if (goingRight) {
          // 向右滑动 = 上一页
          if (!_factory.hasPrev()) {
            _isMoved = false;
            return;
          }
          // 先设置起始点，再设置方向（这样角点计算使用最新坐标）
          _setStartPoint(focusX, focusY);
          _setDirection(_PageDirection.prev);
        } else {
          // 向左滑动 = 下一页
          if (!_factory.hasNext()) {
            _isMoved = false;
            return;
          }
          // 先设置起始点，再设置方向（这样角点计算使用最新坐标）
          _setStartPoint(focusX, focusY);
          _setDirection(_PageDirection.next);
        }
      }
    }

    if (_isMoved) {
      final size = MediaQuery.of(context).size;

      // === P3: 中间区域Y坐标强制调整（对标 Legado SimulationPageDelegate.onTouch）===
      double adjustedY = focusY;
      if (_effectivePageTurnMode == PageTurnMode.simulation) {
        // 中间区域：强制使用底边（仅保留中间区域点击的优化，移除上一页的强制锁定）
        // Fixed: Use 0.9 * height to create cone effect (avoid TouchY == CornerY)
        if (_startY > size.height / 3 && _startY < size.height * 2 / 3) {
          adjustedY = size.height * 0.9;
        }
        // 中间偏上区域且是下一页：强制使用顶边
        if (_startY > size.height / 3 &&
            _startY < size.height / 2 &&
            _direction == _PageDirection.next) {
          adjustedY = size.height * 0.1;
        }
      }

      // 判断是否取消（方向改变）
      _isCancel =
          _direction == _PageDirection.next ? focusX > _lastX : focusX < _lastX;
      _isRunning = true;

      // 设置触摸点
      _setTouchPoint(focusX, adjustedY);
      setState(() {});
    }
  }

  // === 对标 Legado HorizontalPageDelegate.onTouch ACTION_UP ===
  void _onDragEnd(DragEndDetails details) {
    _gestureInProgress = false;
    if (!_isMoved) {
      _direction = _PageDirection.none;
      _flushPendingPictureInvalidationIfIdle();
      final refreshedPadding = _flushPendingSystemPaddingRefresh();
      if (refreshedPadding) {
        setState(() {});
      }
      _schedulePrecache();
      return;
    }

    // 开始动画（完成翻页或取消）
    _startTurnAnimation();
  }

  Widget _buildPageWidget(
    String content, {
    required PageRenderSlot slot,
  }) {
    if (content.isEmpty) {
      return Container(color: widget.backgroundColor);
    }

    final systemPadding = _resolveStableSystemPadding();
    final topSafe = systemPadding.top;
    final bottomSafe = systemPadding.bottom;

    final renderPosition = _factory.resolveRenderPosition(slot);
    return Container(
      color: widget.backgroundColor,
      child: Stack(
        children: [
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                widget.padding.left,
                topSafe + _topOffset + widget.padding.top,
                widget.padding.right,
                bottomSafe + _bottomOffset + widget.padding.bottom,
              ),
              child: _buildPageBodyContent(
                content,
                renderPosition: renderPosition,
              ),
            ),
          ),
          if (_showAnyTipBar)
            _buildOverlay(
              topSafe,
              bottomSafe,
              slot: slot,
            ),
        ],
      ),
    );
  }

  Widget _buildPageBodyContent(
    String content, {
    required PageRenderPosition renderPosition,
  }) {
    final titleData = _resolvePageTitleRenderData(
      content: content,
      renderPosition: renderPosition,
    );
    final blocks = _parsePageRenderBlocks(titleData.bodyContent);
    Widget body;
    if (!blocks.any((block) => block.isImage)) {
      body = LegacyJustifiedTextBlock(
        content: titleData.bodyContent,
        style: widget.textStyle,
        justify: widget.settings.textFullJustify,
        bottomJustify: widget.settings.textBottomJustify,
        paragraphIndent: widget.settings.paragraphIndent,
        applyParagraphIndent: false,
        preserveEmptyLines: true,
      );
    } else {
      body = LayoutBuilder(
        builder: (context, constraints) => _buildImageAwarePageBody(
          blocks: blocks,
          maxWidth: constraints.maxWidth,
          maxHeight: constraints.maxHeight,
        ),
      );
    }
    return _wrapPageBodyWithTitle(body: body, titleData: titleData);
  }

  String _normalizeLegacyImageStyleValue(String style) {
    final normalized = style.trim().toUpperCase();
    if (normalized.isEmpty) {
      return _legacyImageStyleDefault;
    }
    return normalized;
  }

  List<_PagedRenderBlock> _parsePageRenderBlocks(String content) {
    if (!_contentHasImageMarker(content)) {
      return <_PagedRenderBlock>[_PagedRenderBlock.text(content)];
    }
    final lines = content.replaceAll('\r\n', '\n').split('\n');
    final blocks = <_PagedRenderBlock>[];
    final textBuffer = StringBuffer();

    void flushText() {
      final value = textBuffer.toString();
      if (value.trim().isNotEmpty) {
        blocks.add(_PagedRenderBlock.text(value));
      }
      textBuffer.clear();
    }

    for (final line in lines) {
      final src = ReaderImageMarkerCodec.decodeLine(line);
      if (src != null) {
        flushText();
        blocks.add(_PagedRenderBlock.image(src));
      } else {
        textBuffer.writeln(line);
      }
    }
    flushText();

    if (blocks.isEmpty) {
      return <_PagedRenderBlock>[_PagedRenderBlock.text(content)];
    }
    return blocks;
  }

  Widget _buildImageAwarePageBody({
    required List<_PagedRenderBlock> blocks,
    required double maxWidth,
    required double maxHeight,
  }) {
    final style = _normalizeLegacyImageStyleValue(widget.legacyImageStyle);
    final spacing =
        widget.settings.paragraphSpacing.clamp(4.0, 24.0).toDouble();
    final children = <Widget>[];

    for (var i = 0; i < blocks.length; i++) {
      final block = blocks[i];
      if (block.isImage) {
        children.add(
          _buildPagedImageBlock(
            src: block.imageSrc ?? '',
            imageStyle: style,
            maxWidth: maxWidth,
            maxHeight: maxHeight,
          ),
        );
      } else if ((block.text ?? '').trim().isNotEmpty) {
        children.add(
          LegacyJustifiedTextBlock(
            content: block.text ?? '',
            style: widget.textStyle,
            justify: widget.settings.textFullJustify,
            bottomJustify: widget.settings.textBottomJustify,
            paragraphIndent: widget.settings.paragraphIndent,
            applyParagraphIndent: false,
            preserveEmptyLines: true,
          ),
        );
      }
      if (i != blocks.length - 1) {
        children.add(SizedBox(height: spacing));
      }
    }

    if (children.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }

  _PageTitleRenderData _resolvePageTitleRenderData({
    required String content,
    required PageRenderPosition renderPosition,
  }) {
    final normalizedContent = content.replaceAll('\r\n', '\n');
    if (normalizedContent.isEmpty) {
      return _PageTitleRenderData.none(normalizedContent);
    }
    if (widget.settings.titleMode == 2 || renderPosition.pageIndex != 0) {
      return _PageTitleRenderData.none(normalizedContent);
    }
    final normalizedTitle = renderPosition.chapterTitle.trim();
    if (normalizedTitle.isEmpty ||
        !normalizedContent.startsWith(normalizedTitle)) {
      return _PageTitleRenderData.none(normalizedContent);
    }
    return _PageTitleRenderData(
      title: normalizedTitle,
      bodyContent: normalizedContent.substring(normalizedTitle.length),
    );
  }

  TextStyle get _pageTitleStyle => widget.textStyle.copyWith(
        fontSize:
            ((widget.textStyle.fontSize ?? 16.0) + widget.settings.titleSize)
                .clamp(10.0, 72.0),
        fontWeight: FontWeight.w600,
      );

  TextAlign get _pageTitleAlign =>
      widget.settings.titleMode == 1 ? TextAlign.center : TextAlign.left;

  double get _pageTitleTopSpacing => (widget.settings.titleTopSpacing > 0
          ? widget.settings.titleTopSpacing
          : 20.0)
      .clamp(0.0, double.infinity);

  double get _pageTitleBottomSpacing => (widget.settings.titleBottomSpacing > 0
          ? widget.settings.titleBottomSpacing
          : widget.settings.paragraphSpacing * 1.5)
      .clamp(0.0, double.infinity);

  Widget _wrapPageBodyWithTitle({
    required Widget body,
    required _PageTitleRenderData titleData,
  }) {
    if (!titleData.shouldRenderTitle) {
      return body;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: _pageTitleTopSpacing),
        SizedBox(
          width: double.infinity,
          child: Text(
            titleData.title!,
            style: _pageTitleStyle,
            textAlign: _pageTitleAlign,
          ),
        ),
        SizedBox(height: _pageTitleBottomSpacing),
        body,
      ],
    );
  }

  double _paintPageTitleOnCanvas({
    required Canvas canvas,
    required Offset origin,
    required double maxWidth,
    required double maxHeight,
    required String title,
  }) {
    if (maxHeight <= 0 || title.trim().isEmpty) {
      return 0;
    }
    final topSpacing = _pageTitleTopSpacing.clamp(0.0, maxHeight);
    final titlePainter = TextPainter(
      text: TextSpan(text: title, style: _pageTitleStyle),
      textDirection: ui.TextDirection.ltr,
      textAlign: _pageTitleAlign,
      maxLines: null,
    )..layout(maxWidth: maxWidth);
    final restHeight = (maxHeight - topSpacing).clamp(0.0, maxHeight);
    final paintableTitleHeight = titlePainter.height.clamp(0.0, restHeight);
    titlePainter.paint(canvas, Offset(origin.dx, origin.dy + topSpacing));
    final remainingAfterTitle =
        (restHeight - paintableTitleHeight).clamp(0.0, restHeight);
    final bottomSpacing =
        _pageTitleBottomSpacing.clamp(0.0, remainingAfterTitle);
    return topSpacing + paintableTitleHeight + bottomSpacing;
  }

  double _estimatePagedImageHeight({
    required String imageStyle,
    required double maxWidth,
    required double maxHeight,
  }) {
    final width = maxWidth <= 0 ? 320.0 : maxWidth;
    final base = (widget.textStyle.fontSize ?? 16) *
        ((widget.textStyle.height ?? 1.5).clamp(1.0, 2.8));
    final minHeight = base.clamp(14.0, maxHeight);
    switch (imageStyle) {
      case _legacyImageStyleSingle:
        return maxHeight.clamp(minHeight, maxHeight).toDouble();
      case _legacyImageStyleFull:
        final candidate = width * 0.75;
        return candidate.clamp(minHeight * 3, maxHeight).toDouble();
      default:
        final candidate = width * 0.62;
        return candidate.clamp(minHeight * 2, maxHeight * 0.72).toDouble();
    }
  }

  Widget _buildPagedImageBlock({
    required String src,
    required String imageStyle,
    required double maxWidth,
    required double maxHeight,
  }) {
    final request = ReaderImageRequestParser.parse(src);
    final displaySrc = request.url.trim().isEmpty ? src.trim() : request.url;
    final imageProvider = _resolvePagedImageProvider(request);
    if (imageProvider == null) {
      return _buildPagedImageFallback(displaySrc);
    }
    _trackPagedImageIntrinsicSize(
      src: src,
      imageProvider: imageProvider,
    );

    final constrainedHeight = _estimatePagedImageHeight(
      imageStyle: imageStyle,
      maxWidth: maxWidth,
      maxHeight: maxHeight,
    );
    final forceFullWidth = imageStyle == _legacyImageStyleFull ||
        imageStyle == _legacyImageStyleSingle;
    final image = Image(
      image: imageProvider,
      width: forceFullWidth ? maxWidth : null,
      fit: forceFullWidth ? BoxFit.fitWidth : BoxFit.contain,
      filterQuality: FilterQuality.medium,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return const SizedBox(
          width: double.infinity,
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(child: CupertinoActivityIndicator()),
          ),
        );
      },
      errorBuilder: (_, __, ___) => _buildPagedImageFallback(displaySrc),
    );
    final imageBox = ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: maxWidth,
        maxHeight: constrainedHeight,
      ),
      child: image,
    );
    if (imageStyle == _legacyImageStyleSingle) {
      return SizedBox(
        height: constrainedHeight,
        child: Center(child: imageBox),
      );
    }
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: _spacingForImage(imageStyle)),
        child: imageBox,
      ),
    );
  }

  double _spacingForImage(String imageStyle) {
    if (imageStyle == _legacyImageStyleSingle) {
      return 0;
    }
    return (widget.settings.paragraphSpacing / 2).clamp(6.0, 20.0).toDouble();
  }

  Widget _buildPagedImageFallback(String src) {
    final message = src.isEmpty ? '图片加载失败' : '图片加载失败：$src';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8),
      alignment: Alignment.centerLeft,
      child: Text(
        message,
        style: widget.textStyle.copyWith(
          fontSize: ((widget.textStyle.fontSize ?? 16) - 2)
              .clamp(10.0, 22.0)
              .toDouble(),
          color: (widget.textStyle.color ?? const Color(0xFF8B7961))
              .withValues(alpha: 0.72),
        ),
      ),
    );
  }

  ImageProvider<Object>? _resolvePagedImageProvider(
      ReaderImageRequest request) {
    final value = request.url.trim();
    if (value.isEmpty) return null;
    final lower = value.toLowerCase();
    if (lower.startsWith('data:image')) {
      final commaIndex = value.indexOf(',');
      if (commaIndex <= 0 || commaIndex >= value.length - 1) {
        return null;
      }
      try {
        final bytes = base64Decode(value.substring(commaIndex + 1));
        return MemoryImage(bytes);
      } catch (_) {
        return null;
      }
    }
    final uri = Uri.tryParse(value);
    if (uri == null) {
      return null;
    }
    if (!uri.hasScheme) {
      return null;
    }
    final scheme = uri.scheme.toLowerCase();
    if (scheme != 'http' && scheme != 'https') {
      return null;
    }
    if (request.headers.isEmpty) {
      return NetworkImage(value);
    }
    return NetworkImage(value, headers: request.headers);
  }

  void _trackPagedImageIntrinsicSize({
    required String src,
    required ImageProvider<Object> imageProvider,
  }) {
    final key = src.trim();
    if (key.isEmpty) return;
    if (ReaderImageMarkerCodec.lookupResolvedSize(key) != null) return;
    if (_imageSizeTrackingInFlight.contains(key)) return;

    _imageSizeTrackingInFlight.add(key);
    final stream = imageProvider.resolve(const ImageConfiguration());
    ImageStreamListener? listener;
    listener = ImageStreamListener(
      (ImageInfo info, bool synchronousCall) {
        stream.removeListener(listener!);
        _imageSizeTrackingInFlight.remove(key);
        final changed = ReaderImageMarkerCodec.rememberResolvedSize(
          key,
          width: info.image.width.toDouble(),
          height: info.image.height.toDouble(),
        );
        if (changed && mounted) {
          widget.onImageSizeResolved?.call(
            key,
            Size(
              info.image.width.toDouble(),
              info.image.height.toDouble(),
            ),
          );
          widget.onImageSizeCacheUpdated?.call();
        }
      },
      onError: (Object error, StackTrace? stackTrace) {
        stream.removeListener(listener!);
        _imageSizeTrackingInFlight.remove(key);
      },
    );
    stream.addListener(listener);
  }

  EdgeInsets _resolveTipHorizontalInsets(
    double maxWidth, {
    required double left,
    required double right,
  }) {
    if (!maxWidth.isFinite || maxWidth <= 0) {
      return EdgeInsets.zero;
    }
    var safeLeft = left.isFinite ? left.clamp(0.0, maxWidth).toDouble() : 0.0;
    var safeRight =
        right.isFinite ? right.clamp(0.0, maxWidth).toDouble() : 0.0;
    final overflow = safeLeft + safeRight - maxWidth;
    if (overflow > 0) {
      final shrink = overflow / 2;
      safeLeft = (safeLeft - shrink).clamp(0.0, maxWidth).toDouble();
      safeRight = (safeRight - shrink).clamp(0.0, maxWidth).toDouble();
    }
    return EdgeInsets.only(left: safeLeft, right: safeRight);
  }

  Widget _buildOverlay(
    double topSafe,
    double bottomSafe, {
    required PageRenderSlot slot,
  }) {
    if (!_showAnyTipBar) {
      return const SizedBox.shrink();
    }
    final statusColor = _tipTextColor;
    final dividerColor = _tipDividerColor;
    final renderPosition = _factory.resolveRenderPosition(slot);
    final headerStyle = widget.textStyle.copyWith(
      fontSize: PagedReaderWidget._tipHeaderFontSize,
      color: statusColor,
    );
    final footerStyle = widget.textStyle.copyWith(
      fontSize: PagedReaderWidget._tipFooterFontSize,
      color: statusColor,
    );

    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxWidth = constraints.maxWidth;
          final headerInsets = _resolveTipHorizontalInsets(
            maxWidth,
            left: widget.settings.headerPaddingLeft,
            right: widget.settings.headerPaddingRight,
          );
          final footerInsets = _resolveTipHorizontalInsets(
            maxWidth,
            left: widget.settings.footerPaddingLeft,
            right: widget.settings.footerPaddingRight,
          );
          return Stack(
            children: [
              if (_showHeader)
                Positioned(
                  top: topSafe +
                      PagedReaderWidget._tipEdgeInset +
                      widget.settings.headerPaddingTop,
                  left: headerInsets.left,
                  right: headerInsets.right,
                  child: _buildTipRowWidget(
                    _tipTextForHeader(
                      widget.settings.headerLeftContent,
                      renderPosition: renderPosition,
                    ),
                    _tipTextForHeader(
                      widget.settings.headerCenterContent,
                      renderPosition: renderPosition,
                    ),
                    _tipTextForHeader(
                      widget.settings.headerRightContent,
                      renderPosition: renderPosition,
                    ),
                    headerStyle,
                  ),
                ),
              if (_showHeader && widget.settings.showHeaderLine)
                Positioned(
                  top: topSafe +
                      _headerSlotHeight -
                      PagedReaderWidget._tipDividerThickness,
                  left: headerInsets.left,
                  right: headerInsets.right,
                  child: Container(
                    height: PagedReaderWidget._tipDividerThickness,
                    color: dividerColor,
                  ),
                ),
              if (_showFooter && widget.settings.showFooterLine)
                Positioned(
                  bottom: bottomSafe +
                      _footerSlotHeight -
                      PagedReaderWidget._tipDividerThickness,
                  left: footerInsets.left,
                  right: footerInsets.right,
                  child: Container(
                    height: PagedReaderWidget._tipDividerThickness,
                    color: dividerColor,
                  ),
                ),
              if (_showFooter)
                Positioned(
                  bottom: bottomSafe +
                      PagedReaderWidget._tipEdgeInset +
                      widget.settings.footerPaddingBottom,
                  left: footerInsets.left,
                  right: footerInsets.right,
                  child: _buildTipRowWidget(
                    _tipTextForFooter(
                      widget.settings.footerLeftContent,
                      renderPosition: renderPosition,
                    ),
                    _tipTextForFooter(
                      widget.settings.footerCenterContent,
                      renderPosition: renderPosition,
                    ),
                    _tipTextForFooter(
                      widget.settings.footerRightContent,
                      renderPosition: renderPosition,
                    ),
                    footerStyle,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTipRowWidget(
    String? left,
    String? center,
    String? right,
    TextStyle style,
  ) {
    return Row(
      children: [
        _tipTextWidget(left, style),
        const Expanded(child: SizedBox.shrink()),
        if (center != null && center.isNotEmpty)
          Expanded(
            flex: 2,
            child: Text(
              center,
              style: style,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          )
        else
          const Expanded(flex: 2, child: SizedBox.shrink()),
        const Expanded(child: SizedBox.shrink()),
        _tipTextWidget(right, style),
      ],
    );
  }

  Widget _tipTextWidget(String? text, TextStyle style) {
    if (text == null || text.isEmpty) return const SizedBox.shrink();
    return Text(text, style: style);
  }
}

class _PagedRenderBlock {
  final String? text;
  final String? imageSrc;

  const _PagedRenderBlock._({
    this.text,
    this.imageSrc,
  });

  const _PagedRenderBlock.text(String value)
      : this._(
          text: value,
        );

  const _PagedRenderBlock.image(String src)
      : this._(
          imageSrc: src,
        );

  bool get isImage => imageSrc != null;
}

class _PageTitleRenderData {
  final String? title;
  final String bodyContent;

  const _PageTitleRenderData({
    required this.title,
    required this.bodyContent,
  });

  const _PageTitleRenderData.none(this.bodyContent) : title = null;

  bool get shouldRenderTitle => title != null && title!.isNotEmpty;
}

class _PagePicturePainter extends CustomPainter {
  final ui.Picture picture;

  const _PagePicturePainter(this.picture);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPicture(picture);
  }

  @override
  bool shouldRepaint(covariant _PagePicturePainter oldDelegate) {
    return oldDelegate.picture != picture;
  }
}

class _CoverNextRevealClipper extends CustomClipper<Rect> {
  final double left;

  const _CoverNextRevealClipper({required this.left});

  @override
  Rect getClip(Size size) {
    final safeLeft = left.clamp(0.0, size.width).toDouble();
    final width = (size.width - safeLeft).clamp(0.0, size.width).toDouble();
    return Rect.fromLTWH(safeLeft, 0, width, size.height);
  }

  @override
  bool shouldReclip(covariant _CoverNextRevealClipper oldClipper) {
    return oldClipper.left != left;
  }
}

enum _PageDirection { none, prev, next }
