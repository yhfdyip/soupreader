import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors, Slider;
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

  @override
  void initState() {
    super.initState();
    _settings = widget.settings;
  }

  void _updateSettings(ReadingSettings newSettings) {
    setState(() {
      _settings = newSettings;
    });
    widget.onSettingsChanged(newSettings);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: Color(0xFF1C1C1E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // 拖动指示器
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 8),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // 标题栏
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    '排版设置',
                    style: TextStyle(
                      color: CupertinoColors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: () => Navigator.pop(context),
                  child: const Icon(
                    CupertinoIcons.xmark_circle_fill,
                    color: CupertinoColors.systemGrey,
                    size: 28,
                  ),
                ),
              ],
            ),
          ),

          // 内容区域
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // === 文字大小和间距 ===
                  _buildSectionHeader('文字大小和间距'),
                  const SizedBox(height: 12),
                  _buildSliderRow(
                    '正文字号',
                    _settings.fontSize,
                    10,
                    40,
                    (val) => _updateSettings(_settings.copyWith(fontSize: val)),
                    displayValue: '${_settings.fontSize.toInt()}',
                  ),
                  _buildSliderRow(
                    '正文字距',
                    _settings.letterSpacing,
                    -2,
                    5,
                    (val) =>
                        _updateSettings(_settings.copyWith(letterSpacing: val)),
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
                    (val) =>
                        _updateSettings(_settings.copyWith(paragraphSpacing: val)),
                    displayValue: '${_settings.paragraphSpacing.toInt()}',
                  ),
                  _buildSliderRow(
                    '章节名字号',
                    (_settings.fontSize + _settings.titleSize).clamp(10, 50),
                    10,
                    50,
                    (val) => _updateSettings(_settings.copyWith(
                        titleSize: (val - _settings.fontSize).toInt())),
                    displayValue:
                        '${(_settings.fontSize + _settings.titleSize).toInt()}',
                  ),

                  const SizedBox(height: 24),

                  // === 对齐和缩进 ===
                  _buildSectionHeader('对齐和缩进'),
                  const SizedBox(height: 12),
                  _buildSegmentRow(
                    '正文对齐',
                    ['左对齐', '两端对齐', '右对齐'],
                    _settings.textFullJustify ? 1 : 0,
                    (index) {
                      _updateSettings(
                          _settings.copyWith(textFullJustify: index == 1));
                    },
                  ),
                  const SizedBox(height: 12),
                  _buildSegmentRow(
                    '章节名对齐',
                    ['左对齐', '两端对齐', '右对齐'],
                    _settings.titleMode,
                    (index) {
                      _updateSettings(_settings.copyWith(titleMode: index));
                    },
                  ),
                  const SizedBox(height: 12),
                  _buildSegmentRow(
                    '首行缩进',
                    ['一个字', '两个字', '三个字'],
                    _getIndentIndex(),
                    (index) {
                      final indents = ['　', '　　', '　　　'];
                      _updateSettings(
                          _settings.copyWith(paragraphIndent: indents[index]));
                    },
                  ),

                  const SizedBox(height: 24),

                  // === 内容边距 ===
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
                    (val) =>
                        _updateSettings(_settings.copyWith(paddingBottom: val)),
                    displayValue: '${_settings.paddingBottom.toInt()}',
                  ),
                  _buildSliderRow(
                    '内容右边距',
                    _settings.paddingRight,
                    0,
                    60,
                    (val) =>
                        _updateSettings(_settings.copyWith(paddingRight: val)),
                    displayValue: '${_settings.paddingRight.toInt()}',
                  ),

                  const SizedBox(height: 24),

                  // === 页眉页脚边距 ===
                  _buildSectionHeader('页眉边距'),
                  const SizedBox(height: 12),
                  _buildSliderRow(
                    '页眉上边距',
                    _settings.marginVertical,
                    0,
                    40,
                    (val) =>
                        _updateSettings(_settings.copyWith(marginVertical: val)),
                    displayValue: '${_settings.marginVertical.toInt()}',
                  ),

                  const SizedBox(height: 24),

                  // === 页脚边距 ===
                  _buildSectionHeader('页脚边距'),
                  const SizedBox(height: 12),
                  _buildSliderRow(
                    '页脚下边距',
                    _settings.marginVertical,
                    0,
                    40,
                    (val) =>
                        _updateSettings(_settings.copyWith(marginVertical: val)),
                    displayValue: '${_settings.marginVertical.toInt()}',
                  ),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  int _getIndentIndex() {
    final indent = _settings.paragraphIndent;
    if (indent.length >= 3) return 2;
    if (indent.length >= 2) return 1;
    return 0;
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: TextStyle(
        color: CupertinoColors.white.withValues(alpha: 0.6),
        fontSize: 13,
        fontWeight: FontWeight.w500,
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(
                color: CupertinoColors.white,
                fontSize: 14,
              ),
            ),
          ),
          // 减少按钮
          _buildCircleButton(
            CupertinoIcons.minus,
            () {
              if (value > min) {
                onChanged((value - 1).clamp(min, max));
              }
            },
          ),
          // 滑块
          Expanded(
            child: Slider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              activeColor: CupertinoColors.activeBlue,
              inactiveColor: CupertinoColors.systemGrey.withValues(alpha: 0.3),
              onChanged: onChanged,
            ),
          ),
          // 增加按钮
          _buildCircleButton(
            CupertinoIcons.plus,
            () {
              if (value < max) {
                onChanged((value + 1).clamp(min, max));
              }
            },
          ),
          // 数值显示
          SizedBox(
            width: 40,
            child: Text(
              displayValue,
              textAlign: TextAlign.end,
              style: const TextStyle(
                color: CupertinoColors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
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
          color: CupertinoColors.systemGrey.withValues(alpha: 0.2),
          border: Border.all(
            color: CupertinoColors.systemGrey.withValues(alpha: 0.3),
          ),
        ),
        child: Icon(
          icon,
          color: CupertinoColors.white,
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
            style: const TextStyle(
              color: CupertinoColors.white,
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
                      color: isSelected
                          ? CupertinoColors.activeBlue.withValues(alpha: 0.2)
                          : CupertinoColors.systemGrey.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected
                            ? CupertinoColors.activeBlue
                            : CupertinoColors.systemGrey.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Center(
                      child: Text(
                        options[index],
                        style: TextStyle(
                          color: isSelected
                              ? CupertinoColors.activeBlue
                              : CupertinoColors.white,
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
