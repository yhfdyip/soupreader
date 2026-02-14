import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';
import '../models/reading_settings.dart';
import 'package:battery_plus/battery_plus.dart';
import 'page_factory.dart';
import 'simulation_page_painter.dart';
import 'simulation_page_painter2.dart';

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
  final String bookTitle;
  final Map<String, int> clickActions;
  final ValueChanged<int>? onAction;

  // === 翻页动画增强 ===
  final int animDuration; // 动画时长 (100-600ms)
  final PageDirection pageDirection; // 翻页方向
  final int pageTouchSlop; // 翻页触发灵敏度 (0-100)

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
    required this.settings,
    required this.bookTitle,
    this.clickActions = const {},
    this.onAction,
    // 翻页动画增强默认值
    this.animDuration = 300,
    this.pageDirection = PageDirection.horizontal,
    this.pageTouchSlop = 25,
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

  // Shader Program
  static ui.FragmentProgram? pageCurlProgram;
  ui.Image? _curPageImage;
  ui.Image? _targetPageImage;
  bool _isCurImageLoading = false;
  bool _isTargetImageLoading = false;

  // 手势拖拽期间尽量不做同步预渲染，避免卡顿
  bool _gestureInProgress = false;

  // 预渲染调度（拆分为多帧，避免一次性卡住 UI）
  bool _precacheScheduled = false;
  int _precacheEpoch = 0;

  // 仿真翻页门闩：启动动画前必须等待关键帧资源就绪
  bool _isPreparingSimulationTurn = false;
  int _simulationPrepareToken = 0;

  // 电池状态
  final Battery _battery = Battery();
  int _batteryLevel = 100;
  StreamSubscription<BatteryState>? _batteryStateSubscription;

  void _onPageFactoryContentChangedForRender() {
    if (!mounted) return;
    _cancelPendingSimulationPreparation();
    _invalidatePictures();
    setState(() {});
    _schedulePrecache();
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
        oldWidget.settings != widget.settings) {
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
    super.dispose();
  }

  Future<void> _initBattery() async {
    try {
      _batteryLevel = await _battery.batteryLevel;
      _batteryStateSubscription =
          _battery.onBatteryStateChanged.listen((state) {
        setState(() {});
        _updateBatteryLevel();
      });
      if (mounted) setState(() {});
    } catch (_) {}
  }

  Future<void> _updateBatteryLevel() async {
    try {
      _batteryLevel = await _battery.batteryLevel;
      if (mounted) setState(() {});
    } catch (_) {}
  }

  PageFactory get _factory => widget.pageFactory;

  bool get _needsPictureCache =>
      widget.pageTurnMode == PageTurnMode.simulation ||
      widget.pageTurnMode == PageTurnMode.simulation2 ||
      widget.pageTurnMode == PageTurnMode.slide ||
      widget.pageTurnMode == PageTurnMode.cover ||
      widget.pageTurnMode == PageTurnMode.none;

  bool get _needsShaderImages => widget.pageTurnMode == PageTurnMode.simulation;

  double get _topOffset => (!widget.showStatusBar || widget.settings.hideHeader)
      ? 0.0
      : PagedReaderWidget.topOffset;
  double get _bottomOffset =>
      (!widget.showStatusBar || widget.settings.hideFooter)
          ? 0.0
          : PagedReaderWidget.bottomOffset;

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
        textAlign: widget.settings.textFullJustify
            ? TextAlign.justify
            : TextAlign.left,
      );

      final contentWidth =
          size.width - widget.padding.left - widget.padding.right;
      textPainter.layout(maxWidth: contentWidth);

      textPainter.paint(
        canvas,
        Offset(
          widget.padding.left,
          topSafe + _topOffset + widget.padding.top,
        ),
      );
    }

    // 绘制状态栏
    if (widget.showStatusBar) {
      _paintHeaderFooter(canvas, size, topSafe, bottomSafe);
    }

    return recorder.endRecording();
  }

  void _paintHeaderFooter(
      Canvas canvas, Size size, double topSafe, double bottomSafe) {
    final statusColor = widget.textStyle.color?.withValues(alpha: 0.4) ??
        const Color(0xff8B7961);
    final headerStyle =
        widget.textStyle.copyWith(fontSize: 12, color: statusColor);
    final footerStyle =
        widget.textStyle.copyWith(fontSize: 11, color: statusColor);

    if (!widget.settings.hideHeader) {
      final y = topSafe + 6;
      _paintTipRow(
        canvas,
        size,
        y,
        headerStyle,
        _tipTextForHeader(widget.settings.headerLeftContent),
        _tipTextForHeader(widget.settings.headerCenterContent),
        _tipTextForHeader(widget.settings.headerRightContent),
      );
      if (widget.settings.showHeaderLine) {
        final lineY = y + headerStyle.fontSize!.toDouble() + 6;
        final paint = Paint()
          ..color = statusColor.withValues(alpha: 0.2)
          ..strokeWidth = 0.5;
        canvas.drawLine(
          Offset(widget.padding.left, lineY),
          Offset(size.width - widget.padding.right, lineY),
          paint,
        );
      }
    }

    if (!widget.settings.hideFooter) {
      final sample = _tipTextForFooter(widget.settings.footerLeftContent) ??
          _tipTextForFooter(widget.settings.footerCenterContent) ??
          _tipTextForFooter(widget.settings.footerRightContent) ??
          '';
      final samplePainter = TextPainter(
        text: TextSpan(text: sample, style: footerStyle),
        textDirection: ui.TextDirection.ltr,
      )..layout();
      final y = size.height - bottomSafe - 6 - samplePainter.height;
      _paintTipRow(
        canvas,
        size,
        y,
        footerStyle,
        _tipTextForFooter(widget.settings.footerLeftContent),
        _tipTextForFooter(widget.settings.footerCenterContent),
        _tipTextForFooter(widget.settings.footerRightContent),
      );
      if (widget.settings.showFooterLine) {
        final lineY = y - 6;
        final paint = Paint()
          ..color = statusColor.withValues(alpha: 0.2)
          ..strokeWidth = 0.5;
        canvas.drawLine(
          Offset(widget.padding.left, lineY),
          Offset(size.width - widget.padding.right, lineY),
          paint,
        );
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
    String? right,
  ) {
    if (left != null && left.isNotEmpty) {
      final painter = TextPainter(
        text: TextSpan(text: left, style: style),
        textDirection: ui.TextDirection.ltr,
      )..layout();
      painter.paint(canvas, Offset(widget.padding.left, y));
    }
    if (center != null && center.isNotEmpty) {
      final painter = TextPainter(
        text: TextSpan(text: center, style: style),
        textDirection: ui.TextDirection.ltr,
        maxLines: 1,
        ellipsis: '...',
      )..layout(
          maxWidth: size.width - widget.padding.left - widget.padding.right);
      final x = (size.width - painter.width) / 2;
      painter.paint(canvas, Offset(x, y));
    }
    if (right != null && right.isNotEmpty) {
      final painter = TextPainter(
        text: TextSpan(text: right, style: style),
        textDirection: ui.TextDirection.ltr,
      )..layout();
      painter.paint(
        canvas,
        Offset(size.width - widget.padding.right - painter.width, y),
      );
    }
  }

  String? _tipTextForHeader(int type) {
    return _tipText(
      type,
      isHeader: true,
    );
  }

  String? _tipTextForFooter(int type) {
    return _tipText(
      type,
      isHeader: false,
    );
  }

  String? _tipText(int type, {required bool isHeader}) {
    final time = DateFormat('HH:mm').format(DateTime.now());
    final bookProgress = _bookProgress;
    final chapterProgress = _chapterProgress;
    switch (type) {
      case 0:
        return isHeader
            ? widget.bookTitle
            : _progressText(bookProgress,
                enabled: widget.settings.showProgress);
      case 1:
        return isHeader
            ? _factory.currentChapterTitle
            : _pageText(includeTotal: true);
      case 2:
        return isHeader ? '' : _timeText(time);
      case 3:
        return isHeader ? _timeText(time) : _batteryText();
      case 4:
        return isHeader ? _batteryText() : '';
      case 5:
        return isHeader
            ? _progressText(bookProgress, enabled: widget.settings.showProgress)
            : _factory.currentChapterTitle;
      case 6:
        return isHeader ? _pageText(includeTotal: true) : widget.bookTitle;
      case 7:
        return _progressText(chapterProgress,
            enabled: widget.settings.showChapterProgress);
      case 8:
        return _pageText(includeTotal: true);
      case 9:
        return _timeBatteryText(time);
      default:
        return '';
    }
  }

  String _pageText({bool includeTotal = true}) {
    final current = _factory.currentPageIndex + 1;
    final total = _factory.totalPages.clamp(1, 9999);
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

  double get _chapterProgress {
    final total = _factory.totalPages;
    if (total <= 0) return 0;
    return ((_factory.currentPageIndex + 1) / total).clamp(0.0, 1.0);
  }

  double get _bookProgress {
    final totalChapters = _factory.totalChapters;
    if (totalChapters <= 0) return 0;
    return ((_factory.currentChapterIndex + _chapterProgress) / totalChapters)
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
    _ensureShaderImages(size, allowRecord: true);
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

  void _ensurePagePictures(Size size, {bool allowRecord = true}) {
    if (_lastSize != size) {
      _invalidatePictures();
      _lastSize = size;
    }

    if (!allowRecord) return;

    // 当前页
    _curPagePicture ??= _recordPage(_factory.curPage, size);

    // 相邻页：预渲染上一页/下一页，避免拖拽时临时生成导致卡顿
    if (_factory.hasPrev()) {
      _prevPagePicture ??= _recordPage(_factory.prevPage, size);
    } else {
      _prevPagePicture?.dispose();
      _prevPagePicture = null;
    }

    if (_factory.hasNext()) {
      _nextPagePicture ??= _recordPage(_factory.nextPage, size);
    } else {
      _nextPagePicture?.dispose();
      _nextPagePicture = null;
    }
  }

  void _ensureShaderImages(Size size, {bool allowRecord = true}) {
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
        setState(() {
          _curPageImage?.dispose();
          _curPageImage = img;
          _isCurImageLoading = false;
        });
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
        setState(() {
          _targetPageImage?.dispose();
          _targetPageImage = img;
          _isTargetImageLoading = false;
        });
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
      if (didWork) {
        // 仍有缺口，继续调度下一帧
        _schedulePrecache();
      }
    });
  }

  bool _precacheOnePicture(Size size) {
    if (_lastSize != size) {
      _invalidatePictures();
      _lastSize = size;
    }

    if (_curPagePicture == null) {
      _curPagePicture = _recordPage(_factory.curPage, size);
      return true;
    }

    if (_factory.hasPrev() && _prevPagePicture == null) {
      _prevPagePicture = _recordPage(_factory.prevPage, size);
      return true;
    }

    if (_factory.hasNext() && _nextPagePicture == null) {
      _nextPagePicture = _recordPage(_factory.nextPage, size);
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

    _ensureShaderImages(size, allowRecord: true);
    if (_isSimulationTurnReady(direction)) return true;

    final deadline = DateTime.now().add(const Duration(milliseconds: 1800));
    while (mounted) {
      if (token != _simulationPrepareToken) return false;
      if (_isSimulationTurnReady(direction)) return true;
      if (DateTime.now().isAfter(deadline)) return false;
      await Future<void>.delayed(const Duration(milliseconds: 16));
      if (!mounted) return false;
      _ensureShaderImages(size, allowRecord: true);
    }
    return false;
  }

  void _startTurnAnimation() {
    if (_direction == _PageDirection.none) return;
    if (widget.pageTurnMode == PageTurnMode.simulation) {
      unawaited(_startSimulationTurnWhenReady());
      return;
    }
    _onAnimStart();
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
    final config = Map<String, int>.from(ClickAction.defaultZoneConfig)
      ..addAll(widget.clickActions);
    return config[zone] ?? ClickAction.showMenu;
  }

  // === 对标 Legado: nextPageByAnim ===
  void _nextPageByAnim({double? startY}) {
    _abortAnim();
    if (!_factory.hasNext()) return;

    final size = MediaQuery.of(context).size;

    // 修正：点击翻页统一使用底部微偏位置，忽略点击的具体 Y 坐标
    // 固化为最佳体验值 0.96
    final y = size.height * 0.96;

    // 修正：先更新坐标，再设置方向，确保角点计算正确
    _setStartPoint(size.width * 0.9, y);
    _setDirection(_PageDirection.next);
    _startTurnAnimation();
  }

  // === 对标 Legado: prevPageByAnim ===
  void _prevPageByAnim({double? startY}) {
    _abortAnim();
    if (!_factory.hasPrev()) return;

    final size = MediaQuery.of(context).size;

    // 修正：点击翻页统一使用底部微偏位置
    // 固化为最佳体验值 0.96
    final y = size.height * 0.96;

    // 修正：先更新坐标，再设置方向
    _setStartPoint(0, y);
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
      // 方向变化时目标页 Image 需要更新；拖拽期间避免同步生成 Picture
      _ensureShaderImages(size, allowRecord: !_gestureInProgress);
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
    _isStarted = false;
    _isMoved = false;
    _isRunning = false;
    if (_animController.isAnimating) {
      _animController.stop();
      if (!_isCancel) {
        _fillPage(_direction);
      }
    }
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
    // 根据移动距离动态计算时长
    int duration;
    if (dx != 0) {
      duration = (animationSpeed * dx.abs() / size.width).toInt();
    } else {
      duration = (animationSpeed * dy.abs() / size.height).toInt();
    }
    // 限制在合理范围内
    duration = duration.clamp(100, 600);

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

    final progress = Curves.easeOutCubic.transform(_animController.value);
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
    _stopScroll();
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
  void _stopScroll() {
    _isStarted = false;
    _isRunning = false;
    // 对齐 legado：动画完成后仅做状态收尾，不在此处触发换页。
    if (mounted) {
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
    if (!isRunning) {
      // 静止态提前预渲染相邻页，避免首次拖拽时同步生成导致的卡顿
      _schedulePrecache();
    }

    // 计算偏移量（基于触摸点相对于起始点的位移）
    // 对于滑动/覆盖模式使用
    final offset = (_touchX - _startX).clamp(-screenWidth, screenWidth);

    switch (widget.pageTurnMode) {
      case PageTurnMode.slide:
        if (!isRunning) return _buildPageWidget(_factory.curPage);
        if (_needsPictureCache) {
          _ensurePagePictures(size, allowRecord: !_gestureInProgress);
        }
        return _buildSlideAnimation(screenWidth, offset);
      case PageTurnMode.cover:
        if (!isRunning) return _buildPageWidget(_factory.curPage);
        if (_needsPictureCache) {
          _ensurePagePictures(size, allowRecord: !_gestureInProgress);
        }
        return _buildCoverAnimation(screenWidth, offset);
      case PageTurnMode.simulation:
        // 仿真模式使用 touchX/touchY (Shader)
        if (_needsShaderImages) _ensureShaderImages(size);
        return _buildSimulationAnimation(size);
      case PageTurnMode.simulation2:
        // 仿真模式2 使用贝塞尔曲线
        if (_needsPictureCache) {
          _ensurePagePictures(size, allowRecord: !_gestureInProgress);
        }
        return _buildSimulation2Animation(size);
      case PageTurnMode.none:
        if (!isRunning) return _buildPageWidget(_factory.curPage);
        if (_needsPictureCache) {
          _ensurePagePictures(size, allowRecord: !_gestureInProgress);
        }
        return _buildNoAnimation(screenWidth, offset);
      default:
        return _buildSlideAnimation(screenWidth, offset);
    }
  }

  Widget _buildRecordedPage(ui.Picture? picture, String fallbackContent) {
    if (picture == null) return _buildPageWidget(fallbackContent);
    return RepaintBoundary(
      child: SizedBox.expand(
        child: CustomPaint(
          painter: _PagePicturePainter(picture),
          isComplex: true,
        ),
      ),
    );
  }

  /// 水平滑动模式
  Widget _buildSlideAnimation(double screenWidth, double offset) {
    if (_direction == _PageDirection.none) {
      return _buildRecordedPage(_curPagePicture, _factory.curPage);
    }
    final clamped = offset.clamp(-screenWidth, screenWidth);
    return Stack(
      children: [
        if (_direction == _PageDirection.next)
          Transform.translate(
            offset: Offset(screenWidth + clamped, 0),
            child: _buildRecordedPage(_nextPagePicture, _factory.nextPage),
          ),
        if (_direction == _PageDirection.prev)
          Transform.translate(
            offset: Offset(clamped - screenWidth, 0),
            child: _buildRecordedPage(_prevPagePicture, _factory.prevPage),
          ),
        Transform.translate(
          offset: Offset(clamped, 0),
          child: _buildRecordedPage(_curPagePicture, _factory.curPage),
        ),
      ],
    );
  }

  /// 覆盖模式
  Widget _buildCoverAnimation(double screenWidth, double offset) {
    if (_direction == _PageDirection.none) {
      return _buildRecordedPage(_curPagePicture, _factory.curPage);
    }
    final clamped = offset.clamp(-screenWidth, screenWidth);
    final shadowOpacity = (clamped.abs() / screenWidth * 0.4).clamp(0.0, 0.4);

    // 如果偏移量极小，不渲染阴影层，直接显示当前页内容（无阴影容器）
    // 这解决了动画结束后阴影可能残留 1 秒的问题
    final showShadow = clamped.abs() > 1.0;

    return Stack(
      children: [
        if (_direction == _PageDirection.next)
          Positioned.fill(
            child: _buildRecordedPage(_nextPagePicture, _factory.nextPage),
          ),
        if (_direction == _PageDirection.prev)
          Positioned.fill(
            child: _buildRecordedPage(_prevPagePicture, _factory.prevPage),
          ),
        Transform.translate(
          offset: Offset(clamped, 0),
          child: showShadow
              ? Container(
                  decoration: BoxDecoration(
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF000000)
                            .withValues(alpha: shadowOpacity),
                        blurRadius: 20,
                        spreadRadius: 5,
                        offset: Offset(clamped > 0 ? -8 : 8, 0),
                      ),
                    ],
                  ),
                  child: _buildRecordedPage(_curPagePicture, _factory.curPage),
                )
              : _buildRecordedPage(_curPagePicture, _factory.curPage),
        ),
      ],
    );
  }

  /// 仿真模式 - 对标 Legado SimulationPageDelegate.onDraw
  /// 关键：只在 isRunning (拖拽或动画) 时渲染仿真效果
  Widget _buildSimulationAnimation(Size size) {
    // === 对标 Legado: if (!isRunning) return ===
    // 静止状态直接返回当前页面Widget，不使用 CustomPaint
    // 这样避免了状态切换时的闪烁
    final isRunning = _isMoved || _isRunning;
    if (!isRunning || pageCurlProgram == null) {
      return _buildPageWidget(_factory.curPage);
    }

    final isNext = _direction == _PageDirection.next;
    if (_direction == _PageDirection.none) {
      return _buildPageWidget(_factory.curPage);
    }
    if (isNext && _curPageImage == null) {
      return _buildPageWidget(_factory.curPage);
    }
    if (!isNext && _targetPageImage == null) {
      return _buildPageWidget(_factory.curPage);
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
      return _buildPageWidget(_factory.curPage);
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
    final isRunning = _isMoved || _isRunning;
    if (!isRunning) {
      return _buildPageWidget(_factory.curPage);
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
      return _buildPageWidget(_factory.curPage);
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
  Widget _buildNoAnimation(double screenWidth, double offset) {
    // 无动画：拖拽超过阈值时直接显示目标页，否则显示当前页
    final clamped = offset.clamp(-screenWidth, screenWidth);
    if (_direction == _PageDirection.next &&
        clamped.abs() > screenWidth * 0.2 &&
        _factory.hasNext()) {
      return _buildRecordedPage(_nextPagePicture, _factory.nextPage);
    }
    if (_direction == _PageDirection.prev &&
        clamped.abs() > screenWidth * 0.2 &&
        _factory.hasPrev()) {
      return _buildRecordedPage(_prevPagePicture, _factory.prevPage);
    }
    return _buildRecordedPage(_curPagePicture, _factory.curPage);
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
      final slop = 5.0 + (widget.pageTouchSlop.clamp(0, 100) / 100) * 45.0;
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
      if (widget.pageTurnMode == PageTurnMode.simulation) {
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
      return;
    }

    // 开始动画（完成翻页或取消）
    _startTurnAnimation();
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
                topSafe + _topOffset + widget.padding.top,
                widget.padding.right,
                bottomSafe + _bottomOffset + widget.padding.bottom,
              ),
              child: Text.rich(
                TextSpan(text: content, style: widget.textStyle),
                textAlign: widget.settings.textFullJustify
                    ? TextAlign.justify
                    : TextAlign.left,
              ),
            ),
          ),
          if (widget.showStatusBar) _buildOverlay(topSafe, bottomSafe),
        ],
      ),
    );
  }

  Widget _buildOverlay(double topSafe, double bottomSafe) {
    if (widget.settings.hideHeader && widget.settings.hideFooter) {
      return const SizedBox.shrink();
    }
    final statusColor = widget.textStyle.color?.withValues(alpha: 0.4) ??
        const Color(0xff8B7961);

    return IgnorePointer(
      child: Container(
        padding: EdgeInsets.fromLTRB(
          widget.padding.left,
          6 + topSafe,
          widget.padding.right,
          6 + bottomSafe,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!widget.settings.hideHeader)
              _buildTipRowWidget(
                _tipTextForHeader(widget.settings.headerLeftContent),
                _tipTextForHeader(widget.settings.headerCenterContent),
                _tipTextForHeader(widget.settings.headerRightContent),
                widget.textStyle.copyWith(fontSize: 12, color: statusColor),
              ),
            if (!widget.settings.hideHeader && widget.settings.showHeaderLine)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Container(
                  height: 0.5,
                  color: statusColor.withValues(alpha: 0.2),
                ),
              ),
            const Expanded(child: SizedBox.shrink()),
            if (!widget.settings.hideFooter && widget.settings.showFooterLine)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Container(
                  height: 0.5,
                  color: statusColor.withValues(alpha: 0.2),
                ),
              ),
            if (!widget.settings.hideFooter)
              _buildTipRowWidget(
                _tipTextForFooter(widget.settings.footerLeftContent),
                _tipTextForFooter(widget.settings.footerCenterContent),
                _tipTextForFooter(widget.settings.footerRightContent),
                widget.textStyle.copyWith(fontSize: 11, color: statusColor),
              ),
          ],
        ),
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

enum _PageDirection { none, prev, next }
