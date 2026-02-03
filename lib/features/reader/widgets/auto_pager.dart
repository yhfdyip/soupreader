import 'dart:async';
import 'package:flutter/material.dart';

/// 自动翻页器
/// 支持滚动模式和翻页模式
class AutoPager {
  /// 是否正在运行
  bool _isRunning = false;
  bool get isRunning => _isRunning;

  /// 自动阅读速度 (1-100)
  int _speed = 50;
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
    _speed = speed.clamp(1, 100);
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
    // 速度转换为每帧滚动的像素数
    // speed 1 = 0.5px/frame, speed 100 = 5px/frame
    final pixelsPerFrame = 0.5 + (_speed - 1) * (5.0 - 0.5) / 99;

    // 60fps 定时器
    _timer = Timer.periodic(const Duration(milliseconds: 16), (_) {
      if (_scrollController != null && _scrollController!.hasClients) {
        final currentOffset = _scrollController!.offset;
        final maxOffset = _scrollController!.position.maxScrollExtent;

        if (currentOffset < maxOffset) {
          _scrollController!.jumpTo(currentOffset + pixelsPerFrame);
        } else {
          // 到达底部，触发下一章
          _onNextPage?.call();
        }
      }
    });
  }

  /// 翻页模式
  void _startPageMode() {
    // 速度转换为翻页间隔
    // speed 1 = 10秒, speed 100 = 1秒
    final intervalMs = 10000 - (_speed - 1) * (10000 - 1000) ~/ 99;

    _timer = Timer.periodic(Duration(milliseconds: intervalMs), (_) {
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

  const AutoReadPanel({
    super.key,
    required this.autoPager,
    this.onClose,
  });

  @override
  State<AutoReadPanel> createState() => _AutoReadPanelState();
}

class _AutoReadPanelState extends State<AutoReadPanel> {
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

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.8),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 标题栏
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '自动阅读',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () {
                    widget.autoPager.stop();
                    widget.onClose?.call();
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 播放/暂停按钮
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  iconSize: 48,
                  icon: Icon(
                    widget.autoPager.isRunning
                        ? Icons.pause_circle_filled
                        : Icons.play_circle_filled,
                    color: Colors.white,
                  ),
                  onPressed: widget.autoPager.toggle,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 速度调节
            Row(
              children: [
                const Icon(Icons.slow_motion_video,
                    color: Colors.white70, size: 20),
                Expanded(
                  child: Slider(
                    value: widget.autoPager.speed.toDouble(),
                    min: 1,
                    max: 100,
                    divisions: 99,
                    activeColor: Colors.amber,
                    inactiveColor: Colors.white24,
                    onChanged: (value) {
                      widget.autoPager.setSpeed(value.round());
                    },
                  ),
                ),
                const Icon(Icons.speed, color: Colors.white70, size: 20),
              ],
            ),

            // 显示当前速度
            Text(
              '速度: ${widget.autoPager.speed}',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
            const SizedBox(height: 8),

            // 模式切换
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildModeButton(
                  '滚动',
                  AutoPagerMode.scroll,
                  Icons.swap_vert,
                ),
                const SizedBox(width: 16),
                _buildModeButton(
                  '翻页',
                  AutoPagerMode.page,
                  Icons.auto_stories,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeButton(String label, AutoPagerMode mode, IconData icon) {
    final isSelected = widget.autoPager.mode == mode;
    return GestureDetector(
      onTap: () => widget.autoPager.setMode(mode),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.amber : Colors.white24,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                color: isSelected ? Colors.black : Colors.white, size: 18),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.black : Colors.white,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
