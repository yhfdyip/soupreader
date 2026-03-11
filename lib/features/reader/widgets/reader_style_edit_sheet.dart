import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';

import '../models/reading_settings.dart';
import 'reader_color_picker_dialog.dart';

/// 阅读样式编辑面板（对标 legado BgTextConfigDialog）。
///
/// 支持修改样式名、文字色、背景色、背景类型（纯色/内置图片）、
/// 背景透明度、下划线开关，以及恢复预设和删除。
class ReaderStyleEditSheet extends StatefulWidget {
  final ReadStyleConfig config;
  final bool canDelete;
  final ValueChanged<ReadStyleConfig> onChanged;
  final VoidCallback? onDelete;

  const ReaderStyleEditSheet({
    super.key,
    required this.config,
    required this.canDelete,
    required this.onChanged,
    this.onDelete,
  });

  @override
  State<ReaderStyleEditSheet> createState() => _ReaderStyleEditSheetState();
}

class _ReaderStyleEditSheetState extends State<ReaderStyleEditSheet> {
  late ReadStyleConfig _draft;

  @override
  void initState() {
    super.initState();
    _draft = widget.config.sanitize();
  }

  void _update(ReadStyleConfig next) {
    final sanitized = next.sanitize();
    setState(() => _draft = sanitized);
    widget.onChanged(sanitized);
  }

  bool get _isDark =>
      CupertinoTheme.of(context).brightness == Brightness.dark;

  Color get _accent => _isDark
      ? const Color(0xFF0A84FF)
      : const Color(0xFF007AFF);

  @override
  Widget build(BuildContext context) {
    final isDark = _isDark;
    final sheetBg = isDark
        ? CupertinoColors.systemGroupedBackground
            .resolveFrom(context)
            .darkColor
        : CupertinoColors.systemGroupedBackground
            .resolveFrom(context)
            .color;
    final labelColor = isDark
        ? CupertinoColors.white
        : CupertinoColors.label.resolveFrom(context);
    final mutedColor = isDark
        ? CupertinoColors.white.withValues(alpha: 0.5)
        : CupertinoColors.secondaryLabel.resolveFrom(context);
    final separatorColor = CupertinoColors.separator.resolveFrom(context);

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(13)),
      child: Container(
        color: sheetBg,
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildGrabber(separatorColor),
              _buildHeader(labelColor, isDark),
              _buildDivider(separatorColor),
              Flexible(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    children: [
                      _buildNameRow(labelColor, mutedColor, separatorColor),
                      _buildDivider(separatorColor),
                      _buildColorRow(
                        label: '文字颜色',
                        colorValue: _draft.textColor,
                        labelColor: labelColor,
                        separatorColor: separatorColor,
                        onTap: _pickTextColor,
                      ),
                      _buildDivider(separatorColor),
                      _buildColorRow(
                        label: '背景颜色',
                        colorValue: _draft.backgroundColor,
                        labelColor: labelColor,
                        separatorColor: separatorColor,
                        onTap: _draft.bgType == ReadStyleConfig.bgTypeColor
                            ? _pickBgColor
                            : null,
                      ),
                      _buildDivider(separatorColor),
                      _buildBgTypeRow(labelColor, mutedColor, isDark),
                      if (_draft.bgType == ReadStyleConfig.bgTypeAsset) ...[
                        _buildDivider(separatorColor),
                        _buildAssetPicker(separatorColor),
                      ],
                      if (_draft.bgType == ReadStyleConfig.bgTypeFile) ...[
                        _buildDivider(separatorColor),
                        _buildFilePickerRow(labelColor, mutedColor),
                      ],
                      _buildDivider(separatorColor),
                      _buildAlphaRow(labelColor, mutedColor),
                      _buildDivider(separatorColor),
                      _buildPresetRow(labelColor, isDark),
                      if (widget.canDelete) ...[
                        _buildDivider(separatorColor),
                        _buildDeleteRow(),
                      ],
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGrabber(Color color) {
    return Center(
      child: Container(
        margin: const EdgeInsets.only(top: 8, bottom: 6),
        width: 36,
        height: 4,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  Widget _buildHeader(Color labelColor, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 2, 8, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '编辑样式',
              style: TextStyle(
                color: labelColor,
                fontSize: 15,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.3,
              ),
            ),
          ),
          CupertinoButton(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            minimumSize: Size.zero,
            onPressed: () => Navigator.pop(context),
            child: Text(
              '完成',
              style: TextStyle(
                color: _accent,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider(Color color) {
    return Container(height: 0.5, color: color);
  }

  Widget _buildNameRow(
    Color labelColor,
    Color mutedColor,
    Color separatorColor,
  ) {
    return CupertinoButton(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      minimumSize: Size.zero,
      onPressed: _editName,
      child: Row(
        children: [
          Text(
            '样式名称',
            style: TextStyle(color: labelColor, fontSize: 15),
          ),
          const Spacer(),
          Text(
            _draft.name.isEmpty ? '未命名' : _draft.name,
            style: TextStyle(color: mutedColor, fontSize: 14),
          ),
          const SizedBox(width: 4),
          Icon(
            CupertinoIcons.chevron_right,
            color: mutedColor,
            size: 14,
          ),
        ],
      ),
    );
  }

  Widget _buildColorRow({
    required String label,
    required int colorValue,
    required Color labelColor,
    required Color separatorColor,
    VoidCallback? onTap,
  }) {
    final color = Color(colorValue);
    final enabled = onTap != null;
    return Opacity(
      opacity: enabled ? 1.0 : 0.4,
      child: CupertinoButton(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        minimumSize: Size.zero,
        onPressed: onTap,
        child: Row(
          children: [
            Text(
              label,
              style: TextStyle(color: labelColor, fontSize: 15),
            ),
            const Spacer(),
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: separatorColor, width: 0.8),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '#${_hexRgb(colorValue)}',
              style: TextStyle(
                color: CupertinoColors.secondaryLabel.resolveFrom(context),
                fontSize: 13,
              ),
            ),
            if (enabled) ...[
              const SizedBox(width: 4),
              Icon(
                CupertinoIcons.chevron_right,
                color: CupertinoColors.secondaryLabel.resolveFrom(context),
                size: 14,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBgTypeRow(Color labelColor, Color mutedColor, bool isDark) {
    final types = [
      (ReadStyleConfig.bgTypeColor, '纯色'),
      (ReadStyleConfig.bgTypeAsset, '内置图片'),
      (ReadStyleConfig.bgTypeFile, '自定义图片'),
    ];
    final chipBg = isDark
        ? CupertinoColors.white.withValues(alpha: 0.1)
        : CupertinoColors.tertiarySystemFill.resolveFrom(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Text(
            '背景类型',
            style: TextStyle(color: labelColor, fontSize: 15),
          ),
          const Spacer(),
          for (final (type, name) in types)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: CupertinoButton(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                onPressed: () => _setBgType(type),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: _draft.bgType == type
                        ? _accent.withValues(alpha: isDark ? 0.18 : 0.12)
                        : chipBg,
                    borderRadius: BorderRadius.circular(8),
                    border: _draft.bgType == type
                        ? Border.all(
                            color: _accent.withValues(alpha: 0.5),
                            width: 1.5)
                        : null,
                  ),
                  child: Text(
                    name,
                    style: TextStyle(
                      color: _draft.bgType == type ? _accent : mutedColor,
                      fontSize: 13,
                      fontWeight: _draft.bgType == type
                          ? FontWeight.w600
                          : FontWeight.w400,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAssetPicker(Color separatorColor) {
    return SizedBox(
      height: 72,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        itemCount: kBundledBgAssets.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final fileName = kBundledBgAssets[i];
          final assetPath = 'assets/bg/$fileName';
          final selected = _draft.bgStr == fileName ||
              _draft.bgStr == assetPath ||
              _draft.bgStr == 'assets/bg/$fileName';
          return GestureDetector(
            onTap: () => _update(_draft.copyWith(
              bgType: ReadStyleConfig.bgTypeAsset,
              bgStr: fileName,
            )),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 80,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: selected ? _accent : separatorColor,
                  width: selected ? 2.0 : 0.5,
                ),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: _accent.withValues(alpha: 0.25),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ]
                    : null,
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(
                    assetPath,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: CupertinoColors.systemGrey5
                          .resolveFrom(context),
                    ),
                  ),
                  Positioned(
                    bottom: 2,
                    left: 2,
                    right: 2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 3, vertical: 1),
                      decoration: BoxDecoration(
                        color: const Color(0x88000000),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Text(
                        fileName.replaceAll('.jpg', ''),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: CupertinoColors.white,
                          fontSize: 9,
                        ),
                      ),
                    ),
                  ),
                  if (selected)
                    Positioned(
                      top: 3,
                      right: 3,
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: _accent,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          CupertinoIcons.checkmark,
                          color: CupertinoColors.white,
                          size: 9,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAlphaRow(Color labelColor, Color mutedColor) {
    final alpha = _draft.bgAlpha.clamp(0, 100);
    final enabled = _draft.bgType != ReadStyleConfig.bgTypeColor;
    return Opacity(
      opacity: enabled ? 1.0 : 0.4,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: SizedBox(
          height: 44,
          child: Row(
            children: [
              Text(
                '背景透明度',
                style: TextStyle(color: labelColor, fontSize: 15),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: CupertinoSlider(
                  value: alpha.toDouble(),
                  min: 0,
                  max: 100,
                  activeColor: _accent,
                  onChanged: enabled
                      ? (v) => _update(_draft.copyWith(bgAlpha: v.round()))
                      : null,
                ),
              ),
              SizedBox(
                width: 40,
                child: Text(
                  '$alpha%',
                  textAlign: TextAlign.end,
                  style: TextStyle(color: mutedColor, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPresetRow(Color labelColor, bool isDark) {
    return CupertinoButton(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      minimumSize: Size.zero,
      onPressed: _showPresetPicker,
      child: Row(
        children: [
          Text(
            '恢复预设',
            style: TextStyle(color: labelColor, fontSize: 15),
          ),
          const Spacer(),
          Icon(
            CupertinoIcons.chevron_right,
            color: CupertinoColors.secondaryLabel.resolveFrom(context),
            size: 14,
          ),
        ],
      ),
    );
  }

  Widget _buildDeleteRow() {
    return CupertinoButton(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      minimumSize: Size.zero,
      onPressed: _confirmDelete,
      child: Row(
        children: [
          Text(
            '删除样式',
            style: TextStyle(
              color: CupertinoColors.systemRed.resolveFrom(context),
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _editName() async {
    final controller =
        TextEditingController(text: _draft.name);
    final result = await showCupertinoDialog<String>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('样式名称'),
        content: Padding(
          padding: const EdgeInsets.only(top: 10),
          child: CupertinoTextField(
            controller: controller,
            autofocus: true,
            placeholder: '请输入名称',
          ),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            onPressed: () =>
                Navigator.pop(ctx, controller.text.trim()),
            child: const Text('确定'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result == null) return;
    _update(_draft.copyWith(name: result));
  }

  Future<void> _pickTextColor() async {
    final picked = await showReaderColorPickerDialog(
      context: context,
      title: '文字颜色',
      initialColor: _draft.textColor,
    );
    if (picked == null) return;
    _update(_draft.copyWith(textColor: picked));
  }

  Future<void> _pickBgColor() async {
    final picked = await showReaderColorPickerDialog(
      context: context,
      title: '背景颜色',
      initialColor: _draft.backgroundColor,
    );
    if (picked == null) return;
    _update(_draft.copyWith(
      backgroundColor: picked,
      bgStr: '#${_hexRgb(picked)}',
    ));
  }

  void _setBgType(int type) {
    if (type == _draft.bgType) return;
    if (type == ReadStyleConfig.bgTypeColor) {
      _update(_draft.copyWith(
        bgType: ReadStyleConfig.bgTypeColor,
        bgStr: '#${_hexRgb(_draft.backgroundColor)}',
        bgAlpha: 100,
      ));
    } else if (type == ReadStyleConfig.bgTypeFile) {
      _update(_draft.copyWith(
        bgType: ReadStyleConfig.bgTypeFile,
        bgStr: _draft.bgType == ReadStyleConfig.bgTypeFile ? _draft.bgStr : '',
        bgAlpha: _draft.bgAlpha == 100 ? 80 : _draft.bgAlpha,
      ));
    } else {
      final defaultAsset = kBundledBgAssets.isNotEmpty
          ? kBundledBgAssets.first
          : '';
      _update(_draft.copyWith(
        bgType: type,
        bgStr: defaultAsset,
        bgAlpha: _draft.bgAlpha == 100 ? 80 : _draft.bgAlpha,
      ));
    }
  }

  Future<void> _pickBgFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );
    if (!mounted) return;
    final path = result?.files.firstOrNull?.path;
    if (path == null || path.isEmpty) return;
    _update(_draft.copyWith(
      bgType: ReadStyleConfig.bgTypeFile,
      bgStr: path,
      bgAlpha: _draft.bgAlpha == 100 ? 80 : _draft.bgAlpha,
    ));
  }

  Widget _buildFilePickerRow(Color labelColor, Color mutedColor) {
    final hasFile =
        _draft.bgStr.isNotEmpty && File(_draft.bgStr).existsSync();
    final fileName = hasFile
        ? _draft.bgStr.split('/').last
        : '未选择图片';
    return CupertinoButton(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      onPressed: _pickBgFile,
      child: Row(
        children: [
          Text(
            '选择图片',
            style: TextStyle(color: labelColor, fontSize: 15),
          ),
          const Spacer(),
          Flexible(
            child: Text(
              fileName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: mutedColor, fontSize: 13),
            ),
          ),
          const SizedBox(width: 4),
          Icon(
            CupertinoIcons.chevron_right,
            size: 16,
            color: mutedColor,
          ),
        ],
      ),
    );
  }

  void _showPresetPicker() {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: const Text('选择预设'),
        actions: [
          for (final preset in kDefaultReadStyleConfigs)
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(ctx);
                _update(preset.copyWith(name: _draft.name));
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      color: Color(preset.backgroundColor),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: CupertinoColors.separator
                            .resolveFrom(context),
                        width: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(preset.name),
                ],
              ),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('取消'),
        ),
      ),
    );
  }

  void _confirmDelete() {
    showCupertinoDialog<void>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('删除样式'),
        content: Text('确定删除「${_draft.name.isEmpty ? '未命名' : _draft.name}」吗？'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
              widget.onDelete?.call();
            },
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  static String _hexRgb(int colorValue) {
    final rgb = colorValue & 0x00FFFFFF;
    return rgb.toRadixString(16).padLeft(6, '0').toUpperCase();
  }
}
