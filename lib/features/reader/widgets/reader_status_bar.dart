import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors;
import 'package:battery_plus/battery_plus.dart';
import '../../../app/theme/colors.dart';
import '../models/reading_settings.dart';

/// 阅读器状态栏 - 支持电量显示和可配置内容
/// 参考 Legado TipConfigDialog
class ReaderStatusBar extends StatefulWidget {
  final ReadingSettings settings;
  final ReadingThemeColors currentTheme;
  final String currentTime;
  final String title;
  final String bookTitle;
  final double progress;
  final int currentPage;
  final int totalPages;

  const ReaderStatusBar({
    super.key,
    required this.settings,
    required this.currentTheme,
    required this.currentTime,
    required this.title,
    this.bookTitle = '',
    required this.progress,
    this.currentPage = 1,
    this.totalPages = 1,
  });

  @override
  State<ReaderStatusBar> createState() => _ReaderStatusBarState();
}

class _ReaderStatusBarState extends State<ReaderStatusBar> {
  final Battery _battery = Battery();
  int _batteryLevel = 100;
  BatteryState _batteryState = BatteryState.full;
  StreamSubscription<BatteryState>? _batteryStateSubscription;

  @override
  void initState() {
    super.initState();
    _initBattery();
  }

  @override
  void dispose() {
    _batteryStateSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initBattery() async {
    try {
      _batteryLevel = await _battery.batteryLevel;
      _batteryState = await _battery.batteryState;

      _batteryStateSubscription = _battery.onBatteryStateChanged.listen((state) {
        setState(() {
          _batteryState = state;
        });
        _updateBatteryLevel();
      });

      if (mounted) setState(() {});
    } catch (_) {
      // 某些平台可能不支持电池读取
    }
  }

  Future<void> _updateBatteryLevel() async {
    try {
      _batteryLevel = await _battery.batteryLevel;
      if (mounted) setState(() {});
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    // 如果隐藏页脚则不显示
    if (widget.settings.hideFooter) return const SizedBox.shrink();

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).padding.bottom + 4,
          top: 4,
          left: widget.settings.paddingLeft,
          right: widget.settings.paddingRight,
        ),
        decoration: BoxDecoration(
          color: widget.currentTheme.background,
          border: widget.settings.showFooterLine
              ? Border(
                  top: BorderSide(
                    color: widget.currentTheme.text.withValues(alpha: 0.1),
                    width: 0.5,
                  ),
                )
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // 左侧内容
            _buildContent(widget.settings.footerLeftContent),
            // 中间内容
            Expanded(
              child: Center(
                child: _buildContent(widget.settings.footerCenterContent),
              ),
            ),
            // 右侧内容
            _buildContent(widget.settings.footerRightContent),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(int contentType) {
    switch (contentType) {
      case 0: // 进度
        return _buildProgressText();
      case 1: // 页码
        return _buildPageNumber();
      case 2: // 时间
        return _buildTimeText();
      case 3: // 电量
        return _buildBatteryIndicator();
      case 4: // 章节名
        return _buildChapterTitle();
      case 5: // 书名
        return _buildBookTitle();
      default: // 无
        return const SizedBox.shrink();
    }
  }

  Widget _buildProgressText() {
    if (!widget.settings.showProgress) return const SizedBox.shrink();
    return Text(
      '${(widget.progress * 100).toStringAsFixed(1)}%',
      style: _textStyle,
    );
  }

  Widget _buildPageNumber() {
    return Text(
      '${widget.currentPage}/${widget.totalPages}',
      style: _textStyle,
    );
  }

  Widget _buildTimeText() {
    if (!widget.settings.showTime) return const SizedBox.shrink();
    return Text(
      widget.currentTime,
      style: _textStyle,
    );
  }

  Widget _buildBatteryIndicator() {
    if (!widget.settings.showBattery) return const SizedBox.shrink();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 电池图标
        _buildBatteryIcon(),
        const SizedBox(width: 4),
        // 电量百分比
        Text(
          '$_batteryLevel%',
          style: _textStyle,
        ),
      ],
    );
  }

  Widget _buildBatteryIcon() {
    final isCharging = _batteryState == BatteryState.charging;
    final color = _getBatteryColor();

    return SizedBox(
      width: 22,
      height: 11,
      child: CustomPaint(
        painter: _BatteryPainter(
          level: _batteryLevel,
          color: color,
          isCharging: isCharging,
        ),
      ),
    );
  }

  Color _getBatteryColor() {
    if (_batteryLevel <= 20) {
      return Colors.red;
    } else if (_batteryLevel <= 50) {
      return Colors.orange;
    } else {
      return widget.currentTheme.text.withValues(alpha: 0.4);
    }
  }

  Widget _buildChapterTitle() {
    return Text(
      widget.title,
      overflow: TextOverflow.ellipsis,
      style: _textStyle,
    );
  }

  Widget _buildBookTitle() {
    return Text(
      widget.bookTitle,
      overflow: TextOverflow.ellipsis,
      style: _textStyle,
    );
  }

  TextStyle get _textStyle => TextStyle(
        color: widget.currentTheme.text.withValues(alpha: 0.4),
        fontSize: 11,
      );
}

/// 电池图标绘制
class _BatteryPainter extends CustomPainter {
  final int level;
  final Color color;
  final bool isCharging;

  _BatteryPainter({
    required this.level,
    required this.color,
    required this.isCharging,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    // 电池外框
    final bodyWidth = size.width - 3;
    final bodyRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, bodyWidth, size.height),
      const Radius.circular(2),
    );
    canvas.drawRRect(bodyRect, paint);

    // 电池头
    final headPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawRect(
      Rect.fromLTWH(bodyWidth + 1, size.height * 0.25, 2, size.height * 0.5),
      headPaint,
    );

    // 电量填充
    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final fillWidth = (bodyWidth - 4) * (level / 100.0);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(2, 2, fillWidth, size.height - 4),
        const Radius.circular(1),
      ),
      fillPaint,
    );

    // 充电图标
    if (isCharging) {
      final iconPaint = Paint()
        ..color = Colors.green
        ..style = PaintingStyle.fill;
      final path = Path()
        ..moveTo(size.width * 0.5, 2)
        ..lineTo(size.width * 0.35, size.height * 0.5)
        ..lineTo(size.width * 0.45, size.height * 0.5)
        ..lineTo(size.width * 0.4, size.height - 2)
        ..lineTo(size.width * 0.6, size.height * 0.4)
        ..lineTo(size.width * 0.5, size.height * 0.4)
        ..close();
      canvas.drawPath(path, iconPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _BatteryPainter oldDelegate) {
    return level != oldDelegate.level ||
        color != oldDelegate.color ||
        isCharging != oldDelegate.isCharging;
  }
}
