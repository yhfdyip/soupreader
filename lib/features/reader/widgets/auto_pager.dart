import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/cupertino.dart';

import '../../../app/theme/design_tokens.dart';

class AutoPager {
  static const int minSpeedSeconds = 1;
  static const int maxSpeedSeconds = 120;
  static const int defaultSpeedSeconds = 10;
  static const Duration _scrollTick = Duration(milliseconds: 16);

  bool _isRunning = false;
  bool get isRunning => _isRunning;

  bool _isPaused = false;
  bool get isPaused => _isPaused;

  int _speed = defaultSpeedSeconds;
  int get speed => _speed;

  AutoPagerMode _mode = AutoPagerMode.scroll;
  AutoPagerMode get mode => _mode;

  /// 翻页模式下当前页的进度（0.0 = 刚开始，1.0 = 即将翻页）
  double _pageProgress = 0.0;
  double get pageProgress => _pageProgress;

  int _pageStartTime = 0;

  Timer? _timer;
  Timer? _progressTimer;
  ScrollController? _scrollController;
  VoidCallback? _onNextPage;
  final List<VoidCallback> _listeners = [];

  void setScrollController(ScrollController controller) {
    _scrollController = controller;
  }

  void setOnNextPage(VoidCallback callback) {
    _onNextPage = callback;
  }

  void addListener(VoidCallback listener) => _listeners.add(listener);
  void removeListener(VoidCallback listener) => _listeners.remove(listener);

  void _notifyListeners() {
    for (final l in _listeners) l();
  }

  void setSpeed(int speed) {
    _speed = speed.clamp(minSpeedSeconds, maxSpeedSeconds);
    if (_isRunning) {
      _timer?.cancel();
      _timer = null;
      _progressTimer?.cancel();
      _progressTimer = null;
      _mode == AutoPagerMode.scroll ? _startScrollMode() : _startPageMode();
    }
    _notifyListeners();
  }

  void setMode(AutoPagerMode mode) {
    _mode = mode;
    if (_isRunning) {
      _timer?.cancel();
      _timer = null;
      _progressTimer?.cancel();
      _progressTimer = null;
      _pageProgress = 0.0;
      _mode == AutoPagerMode.scroll ? _startScrollMode() : _startPageMode();
    }
    _notifyListeners();
  }

  void start() {
    if (_isRunning) return;
    _isRunning = true;
    _isPaused = false;
    _mode == AutoPagerMode.scroll ? _startScrollMode() : _startPageMode();
    _notifyListeners();
  }

  void _startScrollMode() {
    _timer = Timer.periodic(_scrollTick, (_) {
      final controller = _scrollController;
      if (controller == null || !controller.hasClients) return;
      final position = controller.position;
      final currentOffset = controller.offset;
      final maxOffset = position.maxScrollExtent;
      if (currentOffset >= maxOffset - 0.5) {
        _onNextPage?.call();
        return;
      }
      final viewport = position.viewportDimension;
      if (!viewport.isFinite || viewport <= 0) return;
      final pixelsPerMs = viewport / (_speed * 1000.0);
      final delta = pixelsPerMs * _scrollTick.inMilliseconds;
      if (delta <= 0) return;
      final nextOffset = (currentOffset + delta)
          .clamp(position.minScrollExtent, maxOffset)
          .toDouble();
      if (nextOffset <= currentOffset) return;
      try {
        controller.jumpTo(nextOffset);
      } catch (_) {
        return;
      }
      if (nextOffset >= maxOffset - 0.5) {
        _onNextPage?.call();
      }
    });
  }

  void _startPageMode() {
    _pageProgress = 0.0;
    _pageStartTime = DateTime.now().millisecondsSinceEpoch;
    final totalMs = _speed * 1000.0;
    _progressTimer = Timer.periodic(_scrollTick, (_) {
      final elapsed = DateTime.now().millisecondsSinceEpoch - _pageStartTime;
      _pageProgress = (elapsed / totalMs).clamp(0.0, 1.0);
      _notifyListeners();
    });
    _timer = Timer.periodic(Duration(seconds: _speed), (_) {
      // 对标 legado autoPager.reset()：翻页后重置进度计时
      _pageProgress = 0.0;
      _pageStartTime = DateTime.now().millisecondsSinceEpoch;
      _onNextPage?.call();
    });
  }

  void pause() {
    if (!_isRunning) return;
    _timer?.cancel();
    _timer = null;
    _progressTimer?.cancel();
    _progressTimer = null;
    _isRunning = false;
    _isPaused = true;
    _notifyListeners();
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _progressTimer?.cancel();
    _progressTimer = null;
    _pageProgress = 0.0;
    _isRunning = false;
    _isPaused = false;
    _notifyListeners();
  }

  void resume() {
    if (_isRunning) return;
    _isPaused = false;
    start();
  }

  void toggle() {
    if (_isRunning) {
      pause();
    } else if (_isPaused) {
      resume();
    } else {
      start();
    }
  }

  void dispose() {
    _progressTimer?.cancel();
    _progressTimer = null;
    stop();
    _listeners.clear();
    _scrollController = null;
    _onNextPage = null;
  }
}

enum AutoPagerMode { scroll, page }

extension AutoPagerModeLabel on AutoPagerMode {
  String get label => switch (this) {
        AutoPagerMode.scroll => '滚动模式',
        AutoPagerMode.page => '翻页模式',
      };
}

/// 自动阅读控制面板
class AutoReadPanel extends StatefulWidget {
  final AutoPager autoPager;
  final VoidCallback? onClose;
  final ValueChanged<int>? onSpeedChanged;
  final VoidCallback? onShowMainMenu;
  final VoidCallback? onOpenChapterList;
  final VoidCallback? onOpenPageAnimSettings;
  final VoidCallback? onStop;
  final VoidCallback? onPause;
  final VoidCallback? onResume;

  const AutoReadPanel({
    super.key,
    required this.autoPager,
    this.onClose,
    this.onSpeedChanged,
    this.onShowMainMenu,
    this.onOpenChapterList,
    this.onOpenPageAnimSettings,
    this.onStop,
    this.onPause,
    this.onResume,
  });

  @override
  State<AutoReadPanel> createState() => _AutoReadPanelState();
}

class _AutoReadPanelState extends State<AutoReadPanel> {
  double? _previewSlider;

  AutoPager get _pager => widget.autoPager;

  bool get _isDark =>
      CupertinoTheme.of(context).brightness == Brightness.dark;

  Color get _accent =>
      _isDark ? AppDesignTokens.brandSecondary : AppDesignTokens.brandPrimary;

  Color get _panelBg =>
      CupertinoColors.systemGroupedBackground.resolveFrom(context)
          .withValues(alpha: 0.98);

  Color get _textStrong => CupertinoColors.label.resolveFrom(context);
  Color get _textNormal =>
      CupertinoColors.secondaryLabel.resolveFrom(context);
  Color get _divider => CupertinoColors.separator.resolveFrom(context);

  @override
  void initState() {
    super.initState();
    _pager.addListener(_onPagerChanged);
  }

  @override
  void dispose() {
    _pager.removeListener(_onPagerChanged);
    super.dispose();
  }

  void _onPagerChanged() {
    if (mounted) setState(() {});
  }

  // slider=0 最慢（120s），slider=1 最快（1s）
  double _speedToSlider(int speed) {
    final maxS = AutoPager.maxSpeedSeconds.toDouble();
    final normalized = math.log(speed) / math.log(maxS);
    return (1.0 - normalized).clamp(0.0, 1.0);
  }

  int _sliderToSpeed(double slider) {
    final maxS = AutoPager.maxSpeedSeconds.toDouble();
    final s = math.pow(maxS, 1.0 - slider).round();
    return s.clamp(AutoPager.minSpeedSeconds, AutoPager.maxSpeedSeconds);
  }

  int get _displaySpeed =>
      _previewSlider != null ? _sliderToSpeed(_previewSlider!) : _pager.speed;

  double get _sliderValue =>
      _previewSlider ?? _speedToSlider(_pager.speed);

  void _onSliderChanged(double value) {
    if (mounted) setState(() => _previewSlider = value);
  }

  void _onSliderChangeEnd(double value) {
    final speed = _sliderToSpeed(value);
    setState(() => _previewSlider = null);
    _pager.setSpeed(speed);
    widget.onSpeedChanged?.call(speed);
  }

  void _handlePauseResume() {
    if (_pager.isRunning) {
      _pager.pause();
      widget.onPause?.call();
    } else if (_pager.isPaused) {
      _pager.resume();
      widget.onResume?.call();
    }
  }

  void _handleStop() {
    _pager.stop();
    widget.onStop?.call();
    widget.onClose?.call();
  }

  String get _speedLabel {
    final s = _displaySpeed;
    return _pager.mode == AutoPagerMode.scroll ? '每屏 ${s}s' : '每页 ${s}s';
  }

  String get _statusLabel {
    if (_pager.isPaused) return '已暂停';
    return _pager.mode.label;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      decoration: BoxDecoration(
        color: _panelBg,
        border: Border(top: BorderSide(color: _divider, width: 0.5)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Grabber(color: CupertinoColors.separator.resolveFrom(context)),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _statusLabel,
                  style: TextStyle(
                    fontSize: 12,
                    color: _pager.isPaused ? _accent : _textNormal,
                    fontWeight: _pager.isPaused
                        ? FontWeight.w500
                        : FontWeight.w400,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _speedLabel,
                  style: TextStyle(
                    fontSize: 12,
                    color: _textNormal,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _SpeedSliderRow(
              sliderValue: _sliderValue,
              displaySpeed: _displaySpeed,
              isScrollMode: _pager.mode == AutoPagerMode.scroll,
              accent: _accent,
              textNormal: _textNormal,
              textStrong: _textStrong,
              onChanged: _onSliderChanged,
              onChangeEnd: _onSliderChangeEnd,
            ),
            const SizedBox(height: 6),
            _ActionBar(
              isPaused: _pager.isPaused,
              isRunning: _pager.isRunning,
              accent: _accent,
              textStrong: _textStrong,
              onOpenChapterList: widget.onOpenChapterList,
              onShowMainMenu: widget.onShowMainMenu,
              onPauseResume: _handlePauseResume,
              onStop: _handleStop,
              onOpenSettings: widget.onOpenPageAnimSettings,
            ),
          ],
        ),
      ),
    );
  }
}

class _Grabber extends StatelessWidget {
  final Color color;
  const _Grabber({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 4,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

class _SpeedSliderRow extends StatelessWidget {
  final double sliderValue;
  final int displaySpeed;
  final bool isScrollMode;
  final Color accent;
  final Color textNormal;
  final Color textStrong;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onChangeEnd;

  const _SpeedSliderRow({
    required this.sliderValue,
    required this.displaySpeed,
    required this.isScrollMode,
    required this.accent,
    required this.textNormal,
    required this.textStrong,
    required this.onChanged,
    required this.onChangeEnd,
  });

  @override
  Widget build(BuildContext context) {
    final unitLabel = isScrollMode ? '每屏' : '每页';
    return Row(
      children: [
        Text('慢', style: TextStyle(fontSize: 11, color: textNormal)),
        const SizedBox(width: 4),
        Expanded(
          child: CupertinoSlider(
            value: sliderValue,
            min: 0.0,
            max: 1.0,
            activeColor: accent,
            onChanged: onChanged,
            onChangeEnd: onChangeEnd,
          ),
        ),
        const SizedBox(width: 4),
        Text('快', style: TextStyle(fontSize: 11, color: textNormal)),
        const SizedBox(width: 8),
        SizedBox(
          width: 58,
          child: Text(
            '$unitLabel ${displaySpeed}s',
            textAlign: TextAlign.end,
            style: TextStyle(
              fontSize: 12,
              color: textStrong,
              fontWeight: FontWeight.w500,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ],
    );
  }
}

class _ActionBar extends StatelessWidget {
  final bool isPaused;
  final bool isRunning;
  final Color accent;
  final Color textStrong;
  final VoidCallback? onOpenChapterList;
  final VoidCallback? onShowMainMenu;
  final VoidCallback? onPauseResume;
  final VoidCallback? onStop;
  final VoidCallback? onOpenSettings;

  const _ActionBar({
    required this.isPaused,
    required this.isRunning,
    required this.accent,
    required this.textStrong,
    required this.onOpenChapterList,
    required this.onShowMainMenu,
    required this.onPauseResume,
    required this.onStop,
    required this.onOpenSettings,
  });

  @override
  Widget build(BuildContext context) {
    final pauseIcon =
        isPaused ? CupertinoIcons.play_fill : CupertinoIcons.pause_fill;
    final pauseLabel = isPaused ? '继续' : '暂停';

    return Row(
      children: [
        Expanded(
          child: _ActionItem(
            icon: CupertinoIcons.list_bullet,
            label: '目录',
            color: textStrong,
            onTap: onOpenChapterList,
          ),
        ),
        Expanded(
          child: _ActionItem(
            icon: CupertinoIcons.square_grid_2x2,
            label: '主菜单',
            color: textStrong,
            onTap: onShowMainMenu,
          ),
        ),
        Expanded(
          child: _ActionItem(
            icon: pauseIcon,
            label: pauseLabel,
            color: isPaused ? accent : textStrong,
            fontWeight: isPaused ? FontWeight.w600 : FontWeight.w500,
            onTap: onPauseResume,
          ),
        ),
        Expanded(
          child: _ActionItem(
            icon: CupertinoIcons.stop_circle_fill,
            label: '停止',
            color: accent,
            fontWeight: FontWeight.w600,
            onTap: onStop,
          ),
        ),
        Expanded(
          child: _ActionItem(
            icon: CupertinoIcons.circle_grid_3x3,
            label: '设置',
            color: textStrong,
            onTap: onOpenSettings,
          ),
        ),
      ],
    );
  }
}

class _ActionItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final FontWeight fontWeight;
  final VoidCallback? onTap;

  const _ActionItem({
    required this.icon,
    required this.label,
    required this.color,
    this.fontWeight = FontWeight.w500,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: Size.zero,
      onPressed: onTap,
      child: SizedBox(
        width: double.infinity,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 22, color: color),
              const SizedBox(height: 3),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  color: color,
                  fontWeight: fontWeight,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 翻页模式自动阅读进度线，对标 legado AutoPager.onDraw 的彩色横线。
///
/// 随页面进度从顶部向底部移动，到达底部时触发翻页。
class AutoPageProgressLine extends StatefulWidget {
  final AutoPager autoPager;
  final Color color;

  const AutoPageProgressLine({
    super.key,
    required this.autoPager,
    required this.color,
  });

  @override
  State<AutoPageProgressLine> createState() => _AutoPageProgressLineState();
}

class _AutoPageProgressLineState extends State<AutoPageProgressLine> {
  @override
  void initState() {
    super.initState();
    widget.autoPager.addListener(_onChanged);
  }

  @override
  void dispose() {
    widget.autoPager.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final pager = widget.autoPager;
    if (!pager.isRunning ||
        pager.mode != AutoPagerMode.page ||
        pager.pageProgress <= 0) {
      return const SizedBox.shrink();
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final h = constraints.maxHeight;
        final y = (pager.pageProgress * h).clamp(0.0, h);
        return Stack(
          children: [
            Positioned(
              top: y - 1,
              left: 0,
              right: 0,
              child: Container(
                height: 1.5,
                color: widget.color,
              ),
            ),
          ],
        );
      },
    );
  }
}
