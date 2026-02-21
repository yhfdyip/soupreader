import 'dart:async';
import 'package:flutter/cupertino.dart';
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
  final double bookProgress;
  final double chapterProgress;
  final int currentPage;
  final int totalPages;

  const ReaderStatusBar({
    super.key,
    required this.settings,
    required this.currentTheme,
    required this.currentTime,
    required this.title,
    this.bookTitle = '',
    required this.bookProgress,
    required this.chapterProgress,
    this.currentPage = 1,
    this.totalPages = 1,
  });

  @override
  State<ReaderStatusBar> createState() => _ReaderStatusBarState();
}

const double _legacyTipEdgeInset = 6.0;

class _ReaderStatusBarState extends State<ReaderStatusBar> {
  final Battery _battery = Battery();
  int _batteryLevel = 100;
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

      _batteryStateSubscription =
          _battery.onBatteryStateChanged.listen((state) {
        setState(() {});
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
    if (!widget.settings.shouldShowFooter()) {
      return const SizedBox.shrink();
    }

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: IgnorePointer(
        child: Padding(
          padding: EdgeInsets.only(
            left: widget.settings.footerPaddingLeft,
            right: widget.settings.footerPaddingRight,
            top: widget.settings.footerPaddingTop,
            bottom: MediaQuery.of(context).padding.bottom +
                widget.settings.footerPaddingBottom +
                _legacyTipEdgeInset,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.settings.showFooterLine)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Container(
                    height: 0.5,
                    color: _lineColor,
                  ),
                ),
              Row(
                children: [
                  _buildFooterContent(widget.settings.footerLeftContent),
                  Expanded(
                    child: Center(
                      child: _buildFooterContent(
                          widget.settings.footerCenterContent),
                    ),
                  ),
                  _buildFooterContent(widget.settings.footerRightContent),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFooterContent(int contentType) {
    switch (contentType) {
      case 0: // 进度
        return _buildProgressText(
            widget.bookProgress, widget.settings.showProgress);
      case 1: // 页码
        return _buildPageNumber();
      case 2: // 时间
        return _buildTimeText();
      case 3: // 电量
        return _buildBatteryIndicator();
      case 4: // 无
        return const SizedBox.shrink();
      case 5: // 章节名
        return _buildChapterTitle();
      case 6: // 书名
        return _buildBookTitle();
      case 7: // 章节进度
        return _buildProgressText(
            widget.chapterProgress, widget.settings.showChapterProgress);
      case 8: // 页码/总页
        return _buildPageNumber();
      case 9: // 时间+电量
        return _buildTimeBatteryText();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildProgressText(double progress, bool enabled) {
    if (!enabled) return const SizedBox.shrink();
    return Text(
      '${(progress * 100).toStringAsFixed(1)}%',
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

  Widget _buildTimeBatteryText() {
    if (!widget.settings.showTime && !widget.settings.showBattery) {
      return const SizedBox.shrink();
    }
    final time = widget.settings.showTime ? widget.currentTime : '';
    final battery = widget.settings.showBattery ? '$_batteryLevel%' : '';
    final text = [time, battery].where((part) => part.isNotEmpty).join(' ');
    if (text.isEmpty) return const SizedBox.shrink();
    return Text(text, style: _textStyle);
  }

  Widget _buildBatteryIndicator() {
    if (!widget.settings.showBattery) return const SizedBox.shrink();
    return Text(
      '$_batteryLevel%',
      style: _textStyle,
    );
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

  bool get _isDarkTheme => widget.currentTheme.isDark;

  Color get _textColor => widget.settings.resolveTipTextColor(
        widget.currentTheme.text,
      );

  Color get _lineColor => widget.settings.resolveTipDividerColor(
        contentColor: _textColor,
        defaultDividerColor: widget.currentTheme.text
            .withValues(alpha: _isDarkTheme ? 0.14 : 0.18),
      );

  TextStyle get _textStyle => TextStyle(
        color: _textColor,
        fontSize: 11,
      );
}

/// 阅读器页眉 - 支持可配置内容
class ReaderHeaderBar extends StatefulWidget {
  final ReadingSettings settings;
  final ReadingThemeColors currentTheme;
  final String currentTime;
  final String title;
  final String bookTitle;
  final double bookProgress;
  final double chapterProgress;
  final int currentPage;
  final int totalPages;

  const ReaderHeaderBar({
    super.key,
    required this.settings,
    required this.currentTheme,
    required this.currentTime,
    required this.title,
    this.bookTitle = '',
    required this.bookProgress,
    required this.chapterProgress,
    this.currentPage = 1,
    this.totalPages = 1,
  });

  @override
  State<ReaderHeaderBar> createState() => _ReaderHeaderBarState();
}

class _ReaderHeaderBarState extends State<ReaderHeaderBar> {
  final Battery _battery = Battery();
  int _batteryLevel = 100;
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

  @override
  Widget build(BuildContext context) {
    if (!widget.settings.shouldShowHeader(
      showStatusBar: widget.settings.showStatusBar,
    )) {
      return const SizedBox.shrink();
    }

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: IgnorePointer(
        child: Padding(
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top +
                widget.settings.headerPaddingTop +
                _legacyTipEdgeInset,
            bottom: widget.settings.headerPaddingBottom,
            left: widget.settings.headerPaddingLeft,
            right: widget.settings.headerPaddingRight,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  _buildHeaderContent(widget.settings.headerLeftContent),
                  Expanded(
                    child: Center(
                      child: _buildHeaderContent(
                          widget.settings.headerCenterContent),
                    ),
                  ),
                  _buildHeaderContent(widget.settings.headerRightContent),
                ],
              ),
              if (widget.settings.showHeaderLine)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Container(
                    height: 0.5,
                    color: _lineColor,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderContent(int contentType) {
    switch (contentType) {
      case 0: // 书名
        return _buildBookTitle();
      case 1: // 章节名
        return _buildChapterTitle();
      case 2: // 无
        return const SizedBox.shrink();
      case 3: // 时间
        return _buildTimeText();
      case 4: // 电量
        return _buildBatteryIndicator();
      case 5: // 进度
        return _buildProgressText(
            widget.bookProgress, widget.settings.showProgress);
      case 6: // 页码
        return _buildPageNumber();
      case 7: // 章节进度
        return _buildProgressText(
            widget.chapterProgress, widget.settings.showChapterProgress);
      case 8: // 页码/总页
        return _buildPageNumber();
      case 9: // 时间+电量
        return _buildTimeBatteryText();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildProgressText(double progress, bool enabled) {
    if (!enabled) return const SizedBox.shrink();
    return Text(
      '${(progress * 100).toStringAsFixed(1)}%',
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

  Widget _buildTimeBatteryText() {
    if (!widget.settings.showTime && !widget.settings.showBattery) {
      return const SizedBox.shrink();
    }
    final time = widget.settings.showTime ? widget.currentTime : '';
    final battery = widget.settings.showBattery ? '$_batteryLevel%' : '';
    final text = [time, battery].where((part) => part.isNotEmpty).join(' ');
    if (text.isEmpty) return const SizedBox.shrink();
    return Text(text, style: _textStyle);
  }

  Widget _buildBatteryIndicator() {
    if (!widget.settings.showBattery) return const SizedBox.shrink();
    return Text(
      '$_batteryLevel%',
      style: _textStyle,
    );
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

  bool get _isDarkTheme => widget.currentTheme.isDark;

  Color get _textColor => widget.settings.resolveTipTextColor(
        widget.currentTheme.text,
      );

  Color get _lineColor => widget.settings.resolveTipDividerColor(
        contentColor: _textColor,
        defaultDividerColor: widget.currentTheme.text
            .withValues(alpha: _isDarkTheme ? 0.14 : 0.18),
      );

  TextStyle get _textStyle => TextStyle(
        color: _textColor,
        fontSize: 12,
      );
}
