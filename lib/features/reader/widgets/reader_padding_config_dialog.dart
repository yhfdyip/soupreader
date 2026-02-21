import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors;

import '../../../app/theme/design_tokens.dart';
import '../models/reading_settings.dart';

/// 阅读器边距设置弹窗（对标 legado PaddingConfigDialog）。
///
/// 语义约束：
/// - 仅承载页眉/正文/页脚边距与分割线开关；
/// - 变更实时回调，不在弹窗内做二次确认。
class ReaderPaddingConfigDialog extends StatefulWidget {
  final ReadingSettings settings;
  final ValueChanged<ReadingSettings> onSettingsChanged;
  final bool isDarkMode;

  const ReaderPaddingConfigDialog({
    super.key,
    required this.settings,
    required this.onSettingsChanged,
    required this.isDarkMode,
  });

  @override
  State<ReaderPaddingConfigDialog> createState() =>
      _ReaderPaddingConfigDialogState();
}

class _ReaderPaddingConfigDialogState extends State<ReaderPaddingConfigDialog> {
  late ReadingSettings _settings;

  Color get _panelBg => widget.isDarkMode
      ? ReaderOverlayTokens.panelDark
      : ReaderOverlayTokens.panelLight;

  Color get _lineColor => widget.isDarkMode
      ? ReaderOverlayTokens.borderDark
      : ReaderOverlayTokens.borderLight;

  Color get _textStrong => widget.isDarkMode
      ? ReaderOverlayTokens.textStrongDark
      : ReaderOverlayTokens.textStrongLight;

  Color get _textNormal => widget.isDarkMode
      ? ReaderOverlayTokens.textNormalDark
      : ReaderOverlayTokens.textNormalLight;

  Color get _sectionAccent => widget.isDarkMode
      ? AppDesignTokens.brandSecondary
      : AppDesignTokens.brandPrimary;

  Color get _accent => widget.isDarkMode
      ? AppDesignTokens.brandSecondary
      : AppDesignTokens.brandPrimary;

  @override
  void initState() {
    super.initState();
    _settings = widget.settings.sanitize();
  }

  void _updateSettings(ReadingSettings next) {
    final safeNext = next.sanitize();
    setState(() => _settings = safeNext);
    widget.onSettingsChanged(safeNext);
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final maxWidth = (screenSize.width * 0.9).clamp(280.0, 560.0).toDouble();
    final maxHeight = (screenSize.height * 0.85).clamp(360.0, 760.0).toDouble();
    return Center(
      child: Container(
        width: maxWidth,
        constraints: BoxConstraints(maxHeight: maxHeight),
        decoration: BoxDecoration(
          color: _panelBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _lineColor),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildSectionHeaderWithSwitch(
                  title: '页眉',
                  value: _settings.showHeaderLine,
                  onChanged: (value) {
                    _updateSettings(_settings.copyWith(showHeaderLine: value));
                  },
                ),
                _buildSliderRow(
                  label: '上边距',
                  value: _settings.headerPaddingTop,
                  max: 100,
                  onChanged: (value) {
                    _updateSettings(
                        _settings.copyWith(headerPaddingTop: value));
                  },
                ),
                _buildSliderRow(
                  label: '下边距',
                  value: _settings.headerPaddingBottom,
                  max: 100,
                  onChanged: (value) {
                    _updateSettings(
                      _settings.copyWith(headerPaddingBottom: value),
                    );
                  },
                ),
                _buildSliderRow(
                  label: '左边距',
                  value: _settings.headerPaddingLeft,
                  max: 100,
                  onChanged: (value) {
                    _updateSettings(
                        _settings.copyWith(headerPaddingLeft: value));
                  },
                ),
                _buildSliderRow(
                  label: '右边距',
                  value: _settings.headerPaddingRight,
                  max: 100,
                  onChanged: (value) {
                    _updateSettings(
                      _settings.copyWith(headerPaddingRight: value),
                    );
                  },
                ),
                _buildSectionHeader(title: '正文'),
                _buildSliderRow(
                  label: '上边距',
                  value: _settings.paddingTop,
                  max: 200,
                  onChanged: (value) {
                    _updateSettings(
                      _settings.copyWith(
                        paddingTop: value,
                        marginVertical: value,
                      ),
                    );
                  },
                ),
                _buildSliderRow(
                  label: '下边距',
                  value: _settings.paddingBottom,
                  max: 100,
                  onChanged: (value) {
                    _updateSettings(
                      _settings.copyWith(
                        paddingBottom: value,
                        marginVertical: value,
                      ),
                    );
                  },
                ),
                _buildSliderRow(
                  label: '左边距',
                  value: _settings.paddingLeft,
                  max: 100,
                  onChanged: (value) {
                    _updateSettings(
                      _settings.copyWith(
                        paddingLeft: value,
                        marginHorizontal: value,
                      ),
                    );
                  },
                ),
                _buildSliderRow(
                  label: '右边距',
                  value: _settings.paddingRight,
                  max: 100,
                  onChanged: (value) {
                    _updateSettings(
                      _settings.copyWith(
                        paddingRight: value,
                        marginHorizontal: value,
                      ),
                    );
                  },
                ),
                _buildSectionHeaderWithSwitch(
                  title: '页脚',
                  value: _settings.showFooterLine,
                  onChanged: (value) {
                    _updateSettings(_settings.copyWith(showFooterLine: value));
                  },
                ),
                _buildSliderRow(
                  label: '上边距',
                  value: _settings.footerPaddingTop,
                  max: 100,
                  onChanged: (value) {
                    _updateSettings(
                        _settings.copyWith(footerPaddingTop: value));
                  },
                ),
                _buildSliderRow(
                  label: '下边距',
                  value: _settings.footerPaddingBottom,
                  max: 100,
                  onChanged: (value) {
                    _updateSettings(
                      _settings.copyWith(footerPaddingBottom: value),
                    );
                  },
                ),
                _buildSliderRow(
                  label: '左边距',
                  value: _settings.footerPaddingLeft,
                  max: 100,
                  onChanged: (value) {
                    _updateSettings(
                        _settings.copyWith(footerPaddingLeft: value));
                  },
                ),
                _buildSliderRow(
                  label: '右边距',
                  value: _settings.footerPaddingRight,
                  max: 100,
                  onChanged: (value) {
                    _updateSettings(
                      _settings.copyWith(footerPaddingRight: value),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader({
    required String title,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 10, 0, 6),
      child: Text(
        title,
        style: TextStyle(
          color: _sectionAccent,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildSectionHeaderWithSwitch({
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: _sectionAccent,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(
            '显示分割线',
            style: TextStyle(
              color: _textNormal,
              fontSize: 13,
            ),
          ),
          const SizedBox(width: 6),
          CupertinoSwitch(
            value: value,
            activeTrackColor: _accent,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildSliderRow({
    required String label,
    required double value,
    required double max,
    required ValueChanged<double> onChanged,
  }) {
    final safeValue = value.isFinite ? value.clamp(0, max).toDouble() : 0.0;
    final canSlide = max > 0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 44,
            child: Text(
              label,
              style: TextStyle(
                color: _textNormal,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: CupertinoSlider(
              value: safeValue,
              min: 0,
              max: max,
              activeColor: _accent,
              thumbColor: _accent,
              onChanged: canSlide ? onChanged : null,
            ),
          ),
          SizedBox(
            width: 40,
            child: Text(
              safeValue.toInt().toString(),
              textAlign: TextAlign.end,
              style: TextStyle(
                color: _textStrong,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> showReaderPaddingConfigDialog(
  BuildContext context, {
  required ReadingSettings settings,
  required ValueChanged<ReadingSettings> onSettingsChanged,
  required bool isDarkMode,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: '边距设置',
    barrierColor: Colors.transparent,
    transitionDuration: AppDesignTokens.motionNormal,
    pageBuilder: (context, animation, secondaryAnimation) {
      return ReaderPaddingConfigDialog(
        settings: settings,
        onSettingsChanged: onSettingsChanged,
        isDarkMode: isDarkMode,
      );
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curved =
          CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.96, end: 1.0).animate(curved),
          child: child,
        ),
      );
    },
  );
}
