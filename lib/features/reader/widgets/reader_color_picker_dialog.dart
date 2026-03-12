import 'dart:math' as math;

import 'package:flutter/cupertino.dart';

import '../../../app/widgets/cupertino_bottom_dialog.dart';

Future<int?> showReaderColorPickerDialog({
  required BuildContext context,
  required String title,
  required int initialColor,
  String hexPlaceholder = '输入 6 位十六进制，如 FF6600',
  String invalidHexMessage = '请输入 6 位十六进制颜色（如 FF6600）',
}) {
  final safeInitialColor = 0xFF000000 | (initialColor & 0x00FFFFFF);
  return showCupertinoBottomSheetDialog<int>(
    context: context,
    builder: (dialogContext) => _ReaderColorPickerDialog(
      title: title,
      initialColor: safeInitialColor,
      hexPlaceholder: hexPlaceholder,
      invalidHexMessage: invalidHexMessage,
    ),
  );
}

class _ReaderColorPickerDialog extends StatefulWidget {
  final String title;
  final int initialColor;
  final String hexPlaceholder;
  final String invalidHexMessage;

  const _ReaderColorPickerDialog({
    required this.title,
    required this.initialColor,
    required this.hexPlaceholder,
    required this.invalidHexMessage,
  });

  @override
  State<_ReaderColorPickerDialog> createState() =>
      _ReaderColorPickerDialogState();
}

class _ReaderColorPickerDialogState extends State<_ReaderColorPickerDialog> {
  static const int _maxRecentColors = 16;
  static const double _panelWidth = 252;
  static const double _svPanelHeight = 152;
  static const double _hueTrackHeight = 24;
  static final List<int> _recentColors = <int>[];

  // legado 的 TYPE_CUSTOM 是自由取色盘；这里保留一组常用预设作为补充，不再依赖样例色。
  static const List<int> _presetColors = <int>[
    0xFF000000,
    0xFF333333,
    0xFF666666,
    0xFF999999,
    0xFFCCCCCC,
    0xFFFFFFFF,
    0xFF7F0000,
    0xFFD32F2F,
    0xFFFF6F00,
    0xFFFFA000,
    0xFFFDD835,
    0xFF1B5E20,
    0xFF2E7D32,
    0xFF00897B,
    0xFF015A86,
    0xFF1565C0,
    0xFF3949AB,
    0xFF5E35B1,
    0xFF6D4C41,
    0xFF8D6E63,
    0xFFA1887F,
    0xFFFDF6E3,
    0xFFFAF3DD,
    0xFFEAE0C8,
  ];

  late HSVColor _hsvColor;
  late final int _originalColor;
  late TextEditingController _hexController;
  String? _errorText;
  bool _suppressHexListener = false;

  @override
  void initState() {
    super.initState();
    final initial = Color(widget.initialColor);
    _originalColor = initial.toARGB32();
    _hsvColor = HSVColor.fromColor(initial);
    _hexController = TextEditingController(text: _hexRgb(initial.toARGB32()));
    _hexController.addListener(_onHexChanged);
  }

  @override
  void dispose() {
    _hexController
      ..removeListener(_onHexChanged)
      ..dispose();
    super.dispose();
  }

  Color get _currentColor => _hsvColor.toColor();

  void _setColor(Color color) {
    final next = HSVColor.fromColor(color);
    final hex = _hexRgb(color.toARGB32());
    setState(() {
      _hsvColor = HSVColor.fromAHSV(
        1,
        next.hue,
        next.saturation.clamp(0, 1),
        next.value.clamp(0, 1),
      );
      _errorText = null;
    });
    _setHexText(hex);
  }

  void _setHexText(String hex) {
    _suppressHexListener = true;
    _hexController.value = _hexController.value.copyWith(
      text: hex,
      selection: TextSelection.collapsed(offset: hex.length),
      composing: TextRange.empty,
    );
    _suppressHexListener = false;
  }

  void _onHexChanged() {
    if (_suppressHexListener) return;
    final parsed = _parseRgb(_hexController.text);
    if (parsed == null) {
      if (_errorText != null) {
        setState(() => _errorText = null);
      }
      return;
    }
    final next = HSVColor.fromColor(Color(parsed));
    setState(() {
      _hsvColor = HSVColor.fromAHSV(
        1,
        next.hue,
        next.saturation.clamp(0, 1),
        next.value.clamp(0, 1),
      );
      _errorText = null;
    });
  }

  void _updateHsv({
    double? hue,
    double? saturation,
    double? value,
  }) {
    final next = HSVColor.fromAHSV(
      1,
      (hue ?? _hsvColor.hue).clamp(0, 360),
      (saturation ?? _hsvColor.saturation).clamp(0, 1),
      (value ?? _hsvColor.value).clamp(0, 1),
    );
    final color = next.toColor();
    setState(() {
      _hsvColor = next;
      _errorText = null;
    });
    _setHexText(_hexRgb(color.toARGB32()));
  }

  void _updateSaturationAndValue(Offset localPosition, Size panelSize) {
    final width = panelSize.width <= 0 ? 1.0 : panelSize.width;
    final height = panelSize.height <= 0 ? 1.0 : panelSize.height;
    final saturation = (localPosition.dx / width).clamp(0.0, 1.0);
    final value = 1 - (localPosition.dy / height).clamp(0.0, 1.0);
    _updateHsv(saturation: saturation, value: value);
  }

  void _updateHueFromPosition(Offset localPosition, double width) {
    final safeWidth = width <= 0 ? 1.0 : width;
    final hue = (localPosition.dx / safeWidth).clamp(0.0, 1.0) * 360;
    _updateHsv(hue: hue);
  }

  void _confirm() {
    final parsed = _parseRgb(_hexController.text);
    if (parsed == null) {
      setState(() => _errorText = widget.invalidHexMessage);
      return;
    }
    _rememberRecentColor(parsed);
    Navigator.pop(context, parsed);
  }

  void _rememberRecentColor(int color) {
    final normalized = 0xFF000000 | (color & 0x00FFFFFF);
    _recentColors.removeWhere(
      (item) => (item & 0x00FFFFFF) == (normalized & 0x00FFFFFF),
    );
    _recentColors.insert(0, normalized);
    if (_recentColors.length > _maxRecentColors) {
      _recentColors.removeRange(_maxRecentColors, _recentColors.length);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentColor = _currentColor;
    return CupertinoAlertDialog(
      title: Text(widget.title),
      content: Padding(
        padding: const EdgeInsets.only(top: 10),
        child: SizedBox(
          width: 280,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildPreview(currentColor),
                const SizedBox(height: 10),
                _buildSaturationValuePanel(),
                const SizedBox(height: 10),
                _buildHueSlider(),
                const SizedBox(height: 8),
                _buildHsvSummary(),
                const SizedBox(height: 10),
                CupertinoTextField(
                  key: const Key('reader_color_hex_input'),
                  controller: _hexController,
                  textCapitalization: TextCapitalization.characters,
                  placeholder: widget.hexPlaceholder,
                  prefix: const Padding(
                    padding: EdgeInsets.only(left: 8),
                    child: Text('#'),
                  ),
                ),
                if (_errorText != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    _errorText!,
                    style: TextStyle(
                      color: CupertinoColors.systemRed.resolveFrom(context),
                      fontSize: 12,
                    ),
                  ),
                ],
                if (_recentColors.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _buildColorSection(
                    label: '最近使用',
                    colors: _recentColors,
                    currentColor: currentColor,
                    keyPrefix: 'reader_recent_color',
                  ),
                ],
                const SizedBox(height: 10),
                _buildColorSection(
                  label: '常用预设',
                  colors: _presetColors,
                  currentColor: currentColor,
                  keyPrefix: 'reader_color',
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        CupertinoDialogAction(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        CupertinoDialogAction(
          onPressed: _confirm,
          child: const Text('确定'),
        ),
      ],
    );
  }

  Widget _buildPreview(Color currentColor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: CupertinoColors.systemGrey6.resolveFrom(context),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          _buildPreviewChip(
            label: '当前',
            color: Color(_originalColor),
            keyName: 'reader_color_original_preview',
          ),
          const SizedBox(width: 8),
          _buildPreviewChip(
            label: '选择',
            color: currentColor,
            keyName: 'reader_color_selected_preview',
          ),
          const Spacer(),
          Text('#${_hexRgb(currentColor.toARGB32())}'),
        ],
      ),
    );
  }

  Widget _buildPreviewChip({
    required String label,
    required Color color,
    required String keyName,
  }) {
    return Row(
      key: Key(keyName),
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: CupertinoColors.separator.resolveFrom(context),
              width: 0.8,
            ),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: CupertinoColors.systemGrey.resolveFrom(context),
          ),
        ),
      ],
    );
  }

  Widget _buildSaturationValuePanel() {
    const panelSize = Size(_panelWidth, _svPanelHeight);
    final saturation = _hsvColor.saturation.clamp(0.0, 1.0);
    final value = _hsvColor.value.clamp(0.0, 1.0);
    final dotX =
        (saturation * panelSize.width).clamp(0.0, panelSize.width).toDouble();
    final dotY = ((1 - value) * panelSize.height)
        .clamp(0.0, panelSize.height)
        .toDouble();
    final markerRadius = 8.0;
    final markerLeft = (dotX - markerRadius)
        .clamp(0.0, math.max(0.0, panelSize.width - 16))
        .toDouble();
    final markerTop = (dotY - markerRadius)
        .clamp(0.0, math.max(0.0, panelSize.height - 16))
        .toDouble();

    return GestureDetector(
      key: const Key('reader_color_sv_board'),
      behavior: HitTestBehavior.opaque,
      onTapDown: (details) =>
          _updateSaturationAndValue(details.localPosition, panelSize),
      onPanDown: (details) =>
          _updateSaturationAndValue(details.localPosition, panelSize),
      onPanUpdate: (details) =>
          _updateSaturationAndValue(details.localPosition, panelSize),
      child: SizedBox(
        width: panelSize.width,
        height: panelSize.height,
        child: Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: CupertinoColors.separator.resolveFrom(context),
                  width: 0.8,
                ),
                color: HSVColor.fromAHSV(1, _hsvColor.hue, 1, 1).toColor(),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFFFFFFFF),
                    Color(0x00FFFFFF),
                  ],
                ),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0x00000000),
                    Color(0xFF000000),
                  ],
                ),
              ),
            ),
            Positioned(
              left: markerLeft,
              top: markerTop,
              child: Container(
                width: markerRadius * 2,
                height: markerRadius * 2,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: CupertinoColors.white,
                    width: 2,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x66000000),
                      blurRadius: 2,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHueSlider() {
    const sliderWidth = _panelWidth;
    final normalizedHue = (_hsvColor.hue / 360).clamp(0.0, 1.0);
    final dotX = normalizedHue * sliderWidth;
    final markerLeft =
        (dotX - 9).clamp(0.0, math.max(0.0, sliderWidth - 18)).toDouble();

    return GestureDetector(
      key: const Key('reader_color_hue_slider'),
      behavior: HitTestBehavior.opaque,
      onTapDown: (details) =>
          _updateHueFromPosition(details.localPosition, sliderWidth),
      onHorizontalDragStart: (details) =>
          _updateHueFromPosition(details.localPosition, sliderWidth),
      onHorizontalDragUpdate: (details) =>
          _updateHueFromPosition(details.localPosition, sliderWidth),
      child: SizedBox(
        width: sliderWidth,
        height: _hueTrackHeight + 12,
        child: Stack(
          alignment: Alignment.centerLeft,
          children: [
            Container(
              height: _hueTrackHeight,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: CupertinoColors.separator.resolveFrom(context),
                  width: 0.8,
                ),
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFFFF0000),
                    Color(0xFFFFFF00),
                    Color(0xFF00FF00),
                    Color(0xFF00FFFF),
                    Color(0xFF0000FF),
                    Color(0xFFFF00FF),
                    Color(0xFFFF0000),
                  ],
                ),
              ),
            ),
            Positioned(
              left: markerLeft,
              child: Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _currentColor,
                  border: Border.all(
                    color: CupertinoColors.white,
                    width: 2,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x55000000),
                      blurRadius: 2,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHsvSummary() {
    final h = _hsvColor.hue.round();
    final s = (_hsvColor.saturation * 100).round();
    final v = (_hsvColor.value * 100).round();

    Widget chip(String label, String value) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: CupertinoColors.systemGrey6.resolveFrom(context),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: CupertinoColors.separator.resolveFrom(context),
            width: 0.6,
          ),
        ),
        child: Text(
          '$label $value',
          style: const TextStyle(fontSize: 11),
        ),
      );
    }

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        chip('H', '$h°'),
        chip('S', '$s%'),
        chip('V', '$v%'),
      ],
    );
  }

  Widget _buildColorSection({
    required String label,
    required List<int> colors,
    required Color currentColor,
    required String keyPrefix,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: CupertinoColors.systemGrey.resolveFrom(context),
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 7,
          runSpacing: 7,
          children: colors.map((value) {
            final color = Color(0xFF000000 | (value & 0x00FFFFFF));
            final selected = (currentColor.toARGB32() & 0x00FFFFFF) ==
                (color.toARGB32() & 0x00FFFFFF);
            final keyHex = _hexRgb(color.toARGB32());
            return GestureDetector(
              key: Key('$keyPrefix\_$keyHex'),
              onTap: () => _setColor(color),
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected
                        ? CupertinoColors.activeBlue.resolveFrom(context)
                        : CupertinoColors.separator.resolveFrom(context),
                    width: selected ? 2 : 1,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  int? _parseRgb(String raw) {
    var text = raw.trim();
    if (text.isEmpty) return null;
    if (text.startsWith('#')) {
      text = text.substring(1);
    }
    if (text.startsWith('0x') || text.startsWith('0X')) {
      text = text.substring(2);
    }
    if (text.length == 3) {
      final r = text[0];
      final g = text[1];
      final b = text[2];
      text = '$r$r$g$g$b$b';
    }
    if (text.length == 8) {
      // 支持 AARRGGBB 输入，但对齐 legado 语义只保留 RGB。
      text = text.substring(2);
    }
    if (text.length != 6) return null;
    final rgb = int.tryParse(text, radix: 16);
    if (rgb == null) return null;
    return 0xFF000000 | (rgb & 0x00FFFFFF);
  }

  String _hexRgb(int colorValue) {
    final rgb = colorValue & 0x00FFFFFF;
    return rgb.toRadixString(16).padLeft(6, '0').toUpperCase();
  }
}
