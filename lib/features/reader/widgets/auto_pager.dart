import 'dart:async';

import 'package:flutter/cupertino.dart';

import '../../../app/theme/design_tokens.dart';

/// 自动翻页器
/// 支持滚动模式和翻页模式。
/// 对齐 legado：速度语义为“每页秒数”，数值越大越慢。
class AutoPager {
  static const int minSpeedSeconds = 1;
  static const int maxSpeedSeconds = 120;
  static const int defaultSpeedSeconds = 10;
  static const Duration _scrollTick = Duration(milliseconds: 16);

  /// 是否正在运行
  bool _isRunning = false;
  bool get isRunning => _isRunning;

  /// 自动阅读速度（秒/页）
  int _speed = defaultSpeedSeconds;
  int get speed => _speed;

  /// 模式：scroll / page
  AutoPagerMode _mode = AutoPagerMode.scroll;
  AutoPagerMode get mode => _mode;

  /// 定时器
  Timer? _timer;

  /// 滚动控制器（滚动模式使用）
  ScrollController? _scrollController;

  /// 翻页回调（翻页模式使用）
  VoidCallback? _onNextPage;

  /// 状态变化监听
  final List<VoidCallback> _listeners = [];

  /// 设置滚动控制器
  void setScrollController(ScrollController controller) {
    _scrollController = controller;
  }

  /// 设置翻页回调
  void setOnNextPage(VoidCallback callback) {
    _onNextPage = callback;
  }

  /// 添加监听器
  void addListener(VoidCallback listener) {
    _listeners.add(listener);
  }

  /// 移除监听器
  void removeListener(VoidCallback listener) {
    _listeners.remove(listener);
  }

  void _notifyListeners() {
    for (final listener in _listeners) {
      listener();
    }
  }

  /// 设置速度
  void setSpeed(int speed) {
    _speed = speed.clamp(minSpeedSeconds, maxSpeedSeconds);
    if (_isRunning) {
      // 重新启动以应用新速度
      stop();
      start();
    }
    _notifyListeners();
  }

  /// 设置模式
  void setMode(AutoPagerMode mode) {
    _mode = mode;
    if (_isRunning) {
      stop();
      start();
    }
    _notifyListeners();
  }

  /// 开始自动阅读
  void start() {
    if (_isRunning) return;
    _isRunning = true;

    if (_mode == AutoPagerMode.scroll) {
      _startScrollMode();
    } else {
      _startPageMode();
    }

    _notifyListeners();
  }

  /// 滚动模式
  void _startScrollMode() {
    _timer = Timer.periodic(_scrollTick, (_) {
      final controller = _scrollController;
      if (controller == null || !controller.hasClients) {
        return;
      }

      final position = controller.position;
      final currentOffset = controller.offset;
      final maxOffset = position.maxScrollExtent;
      if (currentOffset >= maxOffset - 0.5) {
        _onNextPage?.call();
        return;
      }

      final viewport = position.viewportDimension;
      if (!viewport.isFinite || viewport <= 0) {
        return;
      }

      final pixelsPerMs = viewport / (_speed * 1000.0);
      final delta = pixelsPerMs * _scrollTick.inMilliseconds;
      if (delta <= 0) {
        return;
      }
      final nextOffset = (currentOffset + delta)
          .clamp(position.minScrollExtent, maxOffset)
          .toDouble();
      if (nextOffset <= currentOffset) {
        return;
      }
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

  /// 翻页模式
  void _startPageMode() {
    _timer = Timer.periodic(Duration(seconds: _speed), (_) {
      _onNextPage?.call();
    });
  }

  /// 暂停
  void pause() {
    _timer?.cancel();
    _timer = null;
    _isRunning = false;
    _notifyListeners();
  }

  /// 停止
  void stop() {
    pause();
  }

  /// 恢复
  void resume() {
    if (!_isRunning) {
      start();
    }
  }

  /// 切换运行状态
  void toggle() {
    if (_isRunning) {
      pause();
    } else {
      start();
    }
  }

  /// 释放资源
  void dispose() {
    stop();
    _listeners.clear();
    _scrollController = null;
    _onNextPage = null;
  }
}

/// 自动翻页模式
enum AutoPagerMode {
  /// 滚动模式 - 持续滚动
  scroll,

  /// 翻页模式 - 定时翻页
  page,
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

  const AutoReadPanel({
    super.key,
    required this.autoPager,
    this.onClose,
    this.onSpeedChanged,
    this.onShowMainMenu,
    this.onOpenChapterList,
    this.onOpenPageAnimSettings,
    this.onStop,
  });

  @override
  State<AutoReadPanel> createState() => _AutoReadPanelState();
}

class _AutoReadPanelState extends State<AutoReadPanel> {
  int? _previewSpeed;

  int get _displaySpeed => _previewSpeed ?? widget.autoPager.speed;

  bool get _isDark => CupertinoTheme.of(context).brightness == Brightness.dark;

  Color get _accent =>
      _isDark ? AppDesignTokens.brandSecondary : AppDesignTokens.brandPrimary;

  Color get _panelBg => _isDark
      ? const Color(0xFF1C1C1E).withValues(alpha: 0.98)
      : AppDesignTokens.surfaceLight.withValues(alpha: 0.98);

  Color get _textStrong =>
      _isDark ? CupertinoColors.white : AppDesignTokens.textStrong;

  Color get _textNormal => _isDark
      ? CupertinoColors.systemGrey.resolveFrom(context)
      : AppDesignTokens.textNormal;

  Color get _divider =>
      _isDark ? AppDesignTokens.borderDark : AppDesignTokens.borderLight;

  Color get _shadow =>
      CupertinoColors.black.withValues(alpha: _isDark ? 0.2 : 0.08);

  @override
  void initState() {
    super.initState();
    widget.autoPager.addListener(_onAutoPagerChanged);
  }

  @override
  void dispose() {
    widget.autoPager.removeListener(_onAutoPagerChanged);
    super.dispose();
  }

  void _onAutoPagerChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  int _normalizeSpeed(double value) {
    return value
        .round()
        .clamp(AutoPager.minSpeedSeconds, AutoPager.maxSpeedSeconds)
        .toInt();
  }

  void _handleSpeedChanged(double value) {
    final next = _normalizeSpeed(value);
    if (_previewSpeed == next) return;
    setState(() {
      _previewSpeed = next;
    });
  }

  void _handleSpeedChangeEnd(double value) {
    final speed = _normalizeSpeed(value);
    setState(() {
      _previewSpeed = null;
    });
    widget.autoPager.setSpeed(speed);
    widget.onSpeedChanged?.call(speed);
  }

  void _handleStop() {
    widget.autoPager.stop();
    widget.onStop?.call();
    widget.onClose?.call();
  }

  Widget _buildActionItem({
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
    bool highlighted = false,
  }) {
    final color = highlighted ? _accent : _textStrong;
    return SizedBox(
      width: 58,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 20,
                child: Center(
                  child: Icon(
                    icon,
                    size: 20,
                    color: color,
                  ),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: color,
                  fontWeight: highlighted ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      decoration: BoxDecoration(
        color: _panelBg,
        border: Border(
          top: BorderSide(color: _divider),
        ),
        boxShadow: [
          BoxShadow(
            color: _shadow,
            blurRadius: 14,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: _textNormal.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '自动阅读速度',
                  style: TextStyle(
                    color: _textStrong,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '${_displaySpeed}s',
                  style: TextStyle(
                    color: _textNormal,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            CupertinoSlider(
              value: _displaySpeed.toDouble(),
              min: AutoPager.minSpeedSeconds.toDouble(),
              max: AutoPager.maxSpeedSeconds.toDouble(),
              divisions: AutoPager.maxSpeedSeconds - AutoPager.minSpeedSeconds,
              activeColor: _accent,
              onChanged: _handleSpeedChanged,
              onChangeEnd: _handleSpeedChangeEnd,
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Spacer(),
                _buildActionItem(
                  icon: CupertinoIcons.list_bullet,
                  label: '目录',
                  onTap: widget.onOpenChapterList,
                ),
                const Spacer(flex: 2),
                _buildActionItem(
                  icon: CupertinoIcons.square_grid_2x2,
                  label: '主菜单',
                  onTap: widget.onShowMainMenu,
                ),
                const Spacer(flex: 2),
                _buildActionItem(
                  icon: CupertinoIcons.stop_circle_fill,
                  label: '停止',
                  onTap: _handleStop,
                  highlighted: true,
                ),
                const Spacer(flex: 2),
                _buildActionItem(
                  icon: CupertinoIcons.circle_grid_3x3,
                  label: '设置',
                  onTap: widget.onOpenPageAnimSettings,
                ),
                const Spacer(),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
