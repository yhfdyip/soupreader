import 'package:flutter/cupertino.dart';

import '../../../app/theme/design_tokens.dart';
import '../models/reading_settings.dart';

/// 排版设置对话框 - Cupertino 风格
/// 参考 Legado PaddingConfigDialog
class TypographySettingsDialog extends StatefulWidget {
  final ReadingSettings settings;
  final ValueChanged<ReadingSettings> onSettingsChanged;

  const TypographySettingsDialog({
    super.key,
    required this.settings,
    required this.onSettingsChanged,
  });

  @override
  State<TypographySettingsDialog> createState() =>
      _TypographySettingsDialogState();
}

class _TypographySettingsDialogState extends State<TypographySettingsDialog> {
  late ReadingSettings _settings;

  bool get _isDark => CupertinoTheme.of(context).brightness == Brightness.dark;

  Color get _accent =>
      _isDark ? AppDesignTokens.brandSecondary : AppDesignTokens.brandPrimary;

  Color get _panelBg =>
      _isDark ? const Color(0xFF1C1C1E) : AppDesignTokens.surfaceLight;

  Color get _textStrong =>
      _isDark ? CupertinoColors.white : AppDesignTokens.textStrong;

  Color get _textSubtle => _isDark
      ? CupertinoColors.systemGrey.withValues(alpha: 0.75)
      : AppDesignTokens.textMuted;

  Color get _lineColor =>
      _isDark ? AppDesignTokens.borderDark : AppDesignTokens.borderLight;

  Color get _chipBg => _isDark
      ? CupertinoColors.systemGrey.withValues(alpha: 0.16)
      : AppDesignTokens.pageBgLight;

  @override
  void initState() {
    super.initState();
    _settings = widget.settings.sanitize();
  }

  void _updateSettings(ReadingSettings newSettings) {
    final safeSettings = newSettings.sanitize();
    setState(() {
      _settings = safeSettings;
    });
    widget.onSettingsChanged(safeSettings);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(
        color: _panelBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            _buildGrabber(),
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 14),
                    _buildSectionHeader('文字大小和间距'),
                    const SizedBox(height: 12),
                    _buildSliderRow(
                      '正文字号',
                      _settings.fontSize,
                      10,
                      40,
                      (val) =>
                          _updateSettings(_settings.copyWith(fontSize: val)),
                      displayValue: '${_settings.fontSize.toInt()}',
                    ),
                    _buildSliderRow(
                      '正文字距',
                      _settings.letterSpacing,
                      -2,
                      5,
                      (val) => _updateSettings(
                          _settings.copyWith(letterSpacing: val)),
                      displayValue: _settings.letterSpacing.toStringAsFixed(1),
                    ),
                    _buildSliderRow(
                      '正文行距',
                      _settings.lineHeight,
                      1.0,
                      3.0,
                      (val) =>
                          _updateSettings(_settings.copyWith(lineHeight: val)),
                      displayValue: _settings.lineHeight.toStringAsFixed(1),
                    ),
                    _buildSliderRow(
                      '正文段距',
                      _settings.paragraphSpacing,
                      0,
                      50,
                      (val) => _updateSettings(
                        _settings.copyWith(paragraphSpacing: val),
                      ),
                      displayValue: '${_settings.paragraphSpacing.toInt()}',
                    ),
                    _buildSliderRow(
                      '章节名字号',
                      (_settings.fontSize + _settings.titleSize).clamp(10, 50),
                      10,
                      50,
                      (val) => _updateSettings(
                        _settings.copyWith(
                          titleSize: (val - _settings.fontSize).toInt(),
                        ),
                      ),
                      displayValue:
                          '${(_settings.fontSize + _settings.titleSize).toInt()}',
                    ),
                    const SizedBox(height: 24),
                    _buildSectionHeader('对齐和缩进'),
                    const SizedBox(height: 12),
                    _buildSegmentRow(
                      '正文对齐',
                      ['左对齐', '两端对齐'],
                      _settings.textFullJustify ? 1 : 0,
                      (index) => _updateSettings(
                        _settings.copyWith(textFullJustify: index == 1),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildSegmentRow(
                      '章节名显示',
                      ['居左', '居中', '隐藏'],
                      _settings.titleMode,
                      (index) => _updateSettings(
                        _settings.copyWith(titleMode: index),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildSegmentRow(
                      '首行缩进',
                      ['无', '一个字', '两个字', '三个字'],
                      _getIndentIndex(),
                      (index) {
                        final indents = ['', '　', '　　', '　　　'];
                        _updateSettings(_settings.copyWith(
                          paragraphIndent: indents[index],
                        ));
                      },
                    ),
                    const SizedBox(height: 24),
                    _buildSectionHeader('内容边距'),
                    const SizedBox(height: 12),
                    _buildSliderRow(
                      '内容上边距',
                      _settings.paddingTop,
                      0,
                      60,
                      (val) =>
                          _updateSettings(_settings.copyWith(paddingTop: val)),
                      displayValue: '${_settings.paddingTop.toInt()}',
                    ),
                    _buildSliderRow(
                      '内容左边距',
                      _settings.paddingLeft,
                      0,
                      60,
                      (val) =>
                          _updateSettings(_settings.copyWith(paddingLeft: val)),
                      displayValue: '${_settings.paddingLeft.toInt()}',
                    ),
                    _buildSliderRow(
                      '内容下边距',
                      _settings.paddingBottom,
                      0,
                      60,
                      (val) => _updateSettings(
                        _settings.copyWith(paddingBottom: val),
                      ),
                      displayValue: '${_settings.paddingBottom.toInt()}',
                    ),
                    _buildSliderRow(
                      '内容右边距',
                      _settings.paddingRight,
                      0,
                      60,
                      (val) => _updateSettings(
                          _settings.copyWith(paddingRight: val)),
                      displayValue: '${_settings.paddingRight.toInt()}',
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGrabber() {
    final color = _isDark
        ? CupertinoColors.white.withValues(alpha: 0.24)
        : AppDesignTokens.textMuted.withValues(alpha: 0.35);
    return Center(
      child: Container(
        margin: const EdgeInsets.only(top: 10),
        width: 38,
        height: 4,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 12, 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: _lineColor),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '排版设置',
              style: TextStyle(
                color: _textStrong,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          CupertinoButton(
            padding: const EdgeInsets.all(6),
            minimumSize: const Size(30, 30),
            onPressed: () => Navigator.pop(context),
            child: Icon(
              CupertinoIcons.xmark,
              color: _textSubtle,
              size: 18,
            ),
          ),
        ],
      ),
    );
  }

  int _getIndentIndex() {
    final indent = _settings.paragraphIndent;
    if (indent.isEmpty) return 0;
    if (indent.length >= 3) return 3;
    if (indent.length >= 2) return 2;
    return 1;
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: TextStyle(
        color: _textSubtle,
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildSliderRow(
    String label,
    double value,
    double min,
    double max,
    ValueChanged<double> onChanged, {
    required String displayValue,
  }) {
    final safeMin = min.isFinite ? min : 0.0;
    final safeMax = max.isFinite && max > safeMin ? max : safeMin + 1.0;
    final safeValue = (value.isFinite ? value : safeMin)
        .clamp(safeMin, safeMax)
        .toDouble();
    final canSlide = min.isFinite && max.isFinite && max > min;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(
                color: _textStrong,
                fontSize: 14,
              ),
            ),
          ),
          _buildCircleButton(
            CupertinoIcons.minus,
            () {
              if (safeValue > safeMin) {
                onChanged((safeValue - 1).clamp(safeMin, safeMax));
              }
            },
          ),
          Expanded(
            child: CupertinoSlider(
              value: safeValue,
              min: safeMin,
              max: safeMax,
              activeColor: _accent,
              thumbColor: _accent,
              onChanged: canSlide ? onChanged : null,
            ),
          ),
          _buildCircleButton(
            CupertinoIcons.plus,
            () {
              if (safeValue < safeMax) {
                onChanged((safeValue + 1).clamp(safeMin, safeMax));
              }
            },
          ),
          SizedBox(
            width: 40,
            child: Text(
              displayValue,
              textAlign: TextAlign.end,
              style: TextStyle(
                color: _textStrong,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCircleButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _chipBg,
          border: Border.all(color: _lineColor),
        ),
        child: Icon(
          icon,
          color: _textStrong,
          size: 16,
        ),
      ),
    );
  }

  Widget _buildSegmentRow(
    String label,
    List<String> options,
    int selectedIndex,
    ValueChanged<int> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: _textStrong,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: List.generate(options.length, (index) {
              final isSelected = selectedIndex == index;
              return Expanded(
                child: GestureDetector(
                  onTap: () => onChanged(index),
                  child: Container(
                    margin: EdgeInsets.only(
                      right: index < options.length - 1 ? 8 : 0,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color:
                          isSelected ? _accent.withValues(alpha: 0.2) : _chipBg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected ? _accent : _lineColor,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        options[index],
                        style: TextStyle(
                          color: isSelected ? _accent : _textStrong,
                          fontSize: 13,
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

/// 显示排版设置对话框
void showTypographySettingsDialog(
  BuildContext context, {
  required ReadingSettings settings,
  required ValueChanged<ReadingSettings> onSettingsChanged,
}) {
  showCupertinoModalPopup(
    context: context,
    builder: (context) => TypographySettingsDialog(
      settings: settings,
      onSettingsChanged: onSettingsChanged,
    ),
  );
}
