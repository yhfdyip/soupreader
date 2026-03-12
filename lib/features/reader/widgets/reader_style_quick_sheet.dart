import 'package:flutter/cupertino.dart';

import '../../../app/theme/colors.dart';
import '../../../app/theme/design_tokens.dart';
import '../../../app/theme/typography.dart';
import '../../../app/widgets/app_sheet_header.dart';
import '../models/reading_settings.dart';
import 'reader_style_edit_sheet.dart';

/// 阅读界面快速调整面板，对应底部菜单「界面」按钮。
///
/// 参考 legado ReadStyleDialog，用 iOS 方式重新设计：
/// chip 行（粗细/字体/缩进/简繁/边距/信息栏）+ 字号步进 + 字距/行距/段距滑杆 + 翻页模式 + 背景主题。
class ReaderStyleQuickSheet extends StatefulWidget {
  final ReadingSettings settings;
  final List<ReadingThemeColors> themes;
  final List<ReadStyleConfig> styleConfigs;
  final ValueChanged<ReadingSettings> onSettingsChanged;
  final VoidCallback? onOpenTipSettings;
  final VoidCallback? onOpenPaddingSettings;
  final VoidCallback? onImportStyle;
  final VoidCallback? onExportStyle;

  const ReaderStyleQuickSheet({
    super.key,
    required this.settings,
    required this.themes,
    required this.styleConfigs,
    required this.onSettingsChanged,
    this.onOpenTipSettings,
    this.onOpenPaddingSettings,
    this.onImportStyle,
    this.onExportStyle,
  });

  @override
  State<ReaderStyleQuickSheet> createState() =>
      _ReaderStyleQuickSheetState();
}

class _ReaderStyleQuickSheetState
    extends State<ReaderStyleQuickSheet> {
  late ReadingSettings _draft;

  @override
  void initState() {
    super.initState();
    _draft = widget.settings;
  }

  void _apply(ReadingSettings next) {
    setState(() => _draft = next);
    widget.onSettingsChanged(next);
  }

  bool get _isDark =>
      CupertinoTheme.of(context).brightness == Brightness.dark;

  Color get _accent =>
      _isDark ? AppDesignTokens.brandSecondary : AppDesignTokens.brandPrimary;

  @override
  Widget build(BuildContext context) {
    final isDark = _isDark;
    final sheetBg = isDark
        ? CupertinoColors.systemGroupedBackground.resolveFrom(context).darkColor
        : CupertinoColors.systemGroupedBackground.resolveFrom(context).color;
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(AppDesignTokens.radiusSheet),
      ),
      child: Container(
        color: sheetBg,
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const AppSheetHeader(title: '界面'),
              _buildChipRow(),
              _buildDivider(),
              _buildFontSizeRow(),
              _buildLetterSpacingRow(),
              _buildLineHeightRow(),
              _buildParagraphSpacingRow(),
              _buildDivider(),
              _buildPageTurnRow(),
              _buildDivider(),
              _buildThemeRow(),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 0.5,
      color: CupertinoColors.separator.resolveFrom(context),
    );
  }

  Widget _buildChipRow() {
    final isDark = _isDark;
    // 粗细
    const boldLabels = {0: '正常', 1: '粗体', 2: '细体'};
    final boldLabel = boldLabels[_draft.textBold] ?? '正常';
    final nextBold = (_draft.textBold + 1) % 3;
    // 字体
    final fontName = ReadingFontFamily.getFontName(_draft.fontFamilyIndex);
    // 缩进
    final indentOptions = ['', '　', '　　', '　　　'];
    final indentLabels = ['无缩进', '缩进1', '缩进2', '缩进3'];
    final indentIndex = indentOptions.indexOf(_draft.paragraphIndent)
        .clamp(0, indentOptions.length - 1);
    final nextIndent = (indentIndex + 1) % indentOptions.length;
    final indentLabel = indentLabels[indentIndex];
    // 简繁
    final converterLabels = {0: '简繁', 1: '繁→简', 2: '简→繁'};
    final converterLabel = converterLabels[_draft.chineseConverterType] ?? '简繁';
    final nextConverter = (_draft.chineseConverterType + 1) % 3;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(child: _buildChip(label: boldLabel, onTap: () => _apply(_draft.copyWith(textBold: nextBold)), isDark: isDark)),
          const SizedBox(width: 8),
          Expanded(child: _buildChip(label: fontName, onTap: () { final next = (_draft.fontFamilyIndex + 1) % ReadingFontFamily.presets.length; _apply(_draft.copyWith(fontFamilyIndex: next)); }, isDark: isDark)),
          const SizedBox(width: 8),
          Expanded(child: _buildChip(label: indentLabel, onTap: () => _apply(_draft.copyWith(paragraphIndent: indentOptions[nextIndent])), isDark: isDark)),
          const SizedBox(width: 8),
          Expanded(child: _buildChip(label: converterLabel, onTap: () => _apply(_draft.copyWith(chineseConverterType: nextConverter)), isDark: isDark)),
          const SizedBox(width: 8),
          Expanded(child: _buildChip(label: '边距', onTap: () { Navigator.pop(context); widget.onOpenPaddingSettings?.call(); }, isDark: isDark)),
          const SizedBox(width: 8),
          Expanded(child: _buildChip(label: '信息栏', onTap: () { Navigator.pop(context); widget.onOpenTipSettings?.call(); }, isDark: isDark)),
        ],
      ),
    );
  }

  Widget _buildChip({
    required String label,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    final bg = isDark
        ? CupertinoColors.white.withValues(alpha: 0.1)
        : CupertinoColors.tertiarySystemFill.resolveFrom(context);
    final textColor = isDark
        ? CupertinoColors.white.withValues(alpha: 0.85)
        : CupertinoColors.label.resolveFrom(context);
    return CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: Size.zero,
      onPressed: onTap,
      child: Container(
        height: 34,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(AppDesignTokens.radiusControl),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: textColor,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildFontSizeRow() {
    final isDark = _isDark;
    final labelColor = isDark
        ? CupertinoColors.white
        : CupertinoColors.label.resolveFrom(context);
    final mutedColor = isDark
        ? CupertinoColors.white.withValues(alpha: 0.5)
        : CupertinoColors.secondaryLabel.resolveFrom(context);
    const double minSize = 8, maxSize = 50, step = 1;
    final sv = _draft.fontSize.isFinite
        ? _draft.fontSize.clamp(minSize, maxSize)
        : 18.0;
    final canDec = sv > minSize;
    final canInc = sv < maxSize;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: SizedBox(
        height: 44,
        child: Row(
          children: [
            Text('字号',
                style: TextStyle(
                    color: labelColor,
                    fontSize: 15,
                    fontWeight: FontWeight.w400)),
            const Spacer(),
            CupertinoButton(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              minimumSize: Size.zero,
              onPressed: canDec
                  ? () => _apply(
                        _draft.copyWith(
                            fontSize: (sv - step).clamp(minSize, maxSize)),
                      )
                  : null,
              child: Text('A',
                  style: TextStyle(
                      color: canDec ? _accent : mutedColor,
                      fontSize: 14,
                      fontWeight: FontWeight.w500)),
            ),
            SizedBox(
              width: 36,
              child: Text(sv.toStringAsFixed(0),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: labelColor,
                      fontSize: 17,
                      fontWeight: FontWeight.w600)),
            ),
            CupertinoButton(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              minimumSize: Size.zero,
              onPressed: canInc
                  ? () => _apply(
                        _draft.copyWith(
                            fontSize: (sv + step).clamp(minSize, maxSize)),
                      )
                  : null,
              child: Text('A',
                  style: TextStyle(
                      color: canInc ? _accent : mutedColor,
                      fontSize: 20,
                      fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLineHeightRow() {
    final isDark = _isDark;
    final labelColor = isDark
        ? CupertinoColors.white
        : CupertinoColors.label.resolveFrom(context);
    final metaColor = isDark
        ? CupertinoColors.white.withValues(alpha: 0.5)
        : CupertinoColors.secondaryLabel.resolveFrom(context);
    final sv = _draft.lineHeight.isFinite
        ? _draft.lineHeight.clamp(1.0, 3.0)
        : 1.8;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: SizedBox(
        height: 44,
        child: Row(
          children: [
            Text('行距',
                style: TextStyle(
                    color: labelColor,
                    fontSize: 15,
                    fontWeight: FontWeight.w400)),
            const SizedBox(width: 12),
            Expanded(
              child: CupertinoSlider(
                value: sv.toDouble(),
                min: 1.0,
                max: 3.0,
                activeColor: _accent,
                onChanged: (v) =>
                    _apply(_draft.copyWith(lineHeight: v)),
              ),
            ),
            SizedBox(
              width: 36,
              child: Text(sv.toStringAsFixed(1),
                  textAlign: TextAlign.end,
                  style: TextStyle(color: metaColor, fontSize: 13)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLetterSpacingRow() {
    final isDark = _isDark;
    final labelColor = isDark
        ? CupertinoColors.white
        : CupertinoColors.label.resolveFrom(context);
    final metaColor = isDark
        ? CupertinoColors.white.withValues(alpha: 0.5)
        : CupertinoColors.secondaryLabel.resolveFrom(context);
    final sv = _draft.letterSpacing.isFinite
        ? _draft.letterSpacing.clamp(-2.0, 5.0)
        : 0.0;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: SizedBox(
        height: 44,
        child: Row(
          children: [
            Text('字距',
                style: TextStyle(
                    color: labelColor,
                    fontSize: 15,
                    fontWeight: FontWeight.w400)),
            const SizedBox(width: 12),
            Expanded(
              child: CupertinoSlider(
                value: sv.toDouble(),
                min: -2.0,
                max: 5.0,
                activeColor: _accent,
                onChanged: (v) => _apply(_draft.copyWith(letterSpacing: v)),
              ),
            ),
            SizedBox(
              width: 40,
              child: Text(sv.toStringAsFixed(1),
                  textAlign: TextAlign.end,
                  style: TextStyle(color: metaColor, fontSize: 13)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildParagraphSpacingRow() {
    final isDark = _isDark;
    final labelColor = isDark
        ? CupertinoColors.white
        : CupertinoColors.label.resolveFrom(context);
    final metaColor = isDark
        ? CupertinoColors.white.withValues(alpha: 0.5)
        : CupertinoColors.secondaryLabel.resolveFrom(context);
    final sv = _draft.paragraphSpacing.isFinite
        ? _draft.paragraphSpacing.clamp(0.0, 50.0)
        : 0.0;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: SizedBox(
        height: 44,
        child: Row(
          children: [
            Text('段距',
                style: TextStyle(
                    color: labelColor,
                    fontSize: 15,
                    fontWeight: FontWeight.w400)),
            const SizedBox(width: 12),
            Expanded(
              child: CupertinoSlider(
                value: sv.toDouble(),
                min: 0.0,
                max: 50.0,
                activeColor: _accent,
                onChanged: (v) => _apply(_draft.copyWith(paragraphSpacing: v)),
              ),
            ),
            SizedBox(
              width: 40,
              child: Text(sv.toStringAsFixed(0),
                  textAlign: TextAlign.end,
                  style: TextStyle(color: metaColor, fontSize: 13)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPageTurnRow() {
    final isDark = _isDark;
    final labelColor = isDark
        ? CupertinoColors.white
        : CupertinoColors.label.resolveFrom(context);
    final modes = [
      PageTurnMode.cover,
      PageTurnMode.slide,
      PageTurnMode.simulation,
      PageTurnMode.scroll,
      PageTurnMode.none,
    ];
    final bg = isDark
        ? CupertinoColors.white.withValues(alpha: 0.1)
        : CupertinoColors.tertiarySystemFill.resolveFrom(context);
    final textNormal = isDark
        ? CupertinoColors.white.withValues(alpha: 0.7)
        : CupertinoColors.secondaryLabel.resolveFrom(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Text('翻页',
              style: TextStyle(
                  color: labelColor,
                  fontSize: 15,
                  fontWeight: FontWeight.w400)),
          const SizedBox(width: 12),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: modes.map((mode) {
                final selected = _draft.pageTurnMode == mode;
                final chipBg = selected
                    ? _accent.withValues(alpha: isDark ? 0.18 : 0.12)
                    : bg;
                final chipText = selected ? _accent : textNormal;
                return Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: CupertinoButton(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    onPressed: () =>
                        _apply(_draft.copyWith(pageTurnMode: mode)),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 7),
                      decoration: BoxDecoration(
                        color: chipBg,
                        borderRadius: BorderRadius.circular(
                            AppDesignTokens.radiusControl),
                        border: selected
                            ? Border.all(
                                color: _accent.withValues(alpha: 0.5),
                                width: 1.5)
                            : null,
                      ),
                      child: Text(
                        mode.name,
                        style: TextStyle(
                          color: chipText,
                          fontSize: 13,
                          fontWeight: selected
                              ? FontWeight.w600
                              : FontWeight.w400,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThemeRow() {
    final isDark = _isDark;
    final labelColor = isDark
        ? CupertinoColors.white
        : CupertinoColors.label.resolveFrom(context);
    final mutedColor = isDark
        ? CupertinoColors.white.withValues(alpha: 0.5)
        : CupertinoColors.secondaryLabel.resolveFrom(context);
    // 从 _draft 实时派生，确保新增/编辑后立即反映在列表中
    final configs = _draft.readStyleConfigs.isNotEmpty
        ? _draft.readStyleConfigs
        : widget.styleConfigs;
    final themes = configs
        .map(
          (c) => ReadingThemeColors(
            background: Color(c.backgroundColor),
            text: Color(c.textColor),
            name: c.name.trim().isEmpty ? '文字' : c.name.trim(),
          ),
        )
        .toList(growable: false);
    final safeSelected =
        (_draft.themeIndex >= 0 && _draft.themeIndex < themes.length)
            ? _draft.themeIndex
            : 0;
    final borderNormal = CupertinoColors.separator.resolveFrom(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('背景文字样式',
                  style: TextStyle(
                      color: labelColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w400)),
              const Spacer(),
              if (widget.onImportStyle != null)
                CupertinoButton(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                  onPressed: widget.onImportStyle,
                  child: Text('导入',
                      style: TextStyle(
                          color: _accent,
                          fontSize: 13)),
                ),
              if (widget.onExportStyle != null)
                CupertinoButton(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                  onPressed: widget.onExportStyle,
                  child: Text('导出',
                      style: TextStyle(
                          color: _accent,
                          fontSize: 13)),
                ),
              Text('共用排版',
                  style: TextStyle(
                      color: mutedColor,
                      fontSize: 13)),
              const SizedBox(width: 4),
              CupertinoSwitch(
                value: _draft.shareLayout,
                activeTrackColor: _accent,
                onChanged: (v) => _apply(_draft.copyWith(shareLayout: v)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 94),
            child: SingleChildScrollView(
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
            children: [
              // 「+」按钮放在第一位
              _buildAddCell(isDark, borderNormal),
              ...List.generate(themes.length, (i) {
                final selected = i == safeSelected;
                final t = themes[i];
                final config = i < configs.length ? configs[i] : null;
                return GestureDetector(
                  onTap: () => _apply(_draft.copyWith(themeIndex: i)),
                  onLongPress: config != null
                      ? () => _openEditSheet(i, config, configs)
                      : null,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 56,
                    height: 44,
                    decoration: BoxDecoration(
                      color: t.background,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: selected ? _accent : borderNormal,
                        width: selected ? 2.0 : 0.5,
                      ),
                      boxShadow: selected
                          ? [
                              BoxShadow(
                                color: _accent.withValues(alpha: 0.25),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              )
                            ]
                          : null,
                    ),
                    padding: const EdgeInsets.all(6),
                    child: Stack(
                      children: [
                        Align(
                          alignment: Alignment.bottomLeft,
                          child: Text(
                            t.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: t.text.withValues(alpha: 0.9),
                              fontSize: 10,
                              fontWeight: selected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                          ),
                        ),
                        if (selected)
                          Positioned(
                            top: 0,
                            right: 0,
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
              }),
            ],
          ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddCell(bool isDark, Color borderNormal) {
    final bg = isDark
        ? CupertinoColors.white.withValues(alpha: 0.08)
        : CupertinoColors.tertiarySystemFill.resolveFrom(context);
    return CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: Size.zero,
      onPressed: _addNewStyle,
      child: Container(
        width: 56,
        height: 44,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: borderNormal, width: 0.5),
        ),
        child: Icon(
          CupertinoIcons.add,
          color: isDark
              ? CupertinoColors.white.withValues(alpha: 0.5)
              : CupertinoColors.secondaryLabel.resolveFrom(context),
          size: 22,
        ),
      ),
    );
  }

  void _addNewStyle() {
    final configs = _draft.readStyleConfigs.isNotEmpty
        ? _draft.readStyleConfigs
        : widget.styleConfigs;
    final newConfig = const ReadStyleConfig(
      name: '新样式',
      backgroundColor: 0xFFFFFFFF,
      textColor: 0xFF333333,
      bgType: ReadStyleConfig.bgTypeColor,
      bgStr: '#FFFFFF',
      bgAlpha: 100,
    );
    final newIndex = configs.length;
    final newConfigs = List<ReadStyleConfig>.from(configs)..add(newConfig);
    _apply(_draft.copyWith(
      readStyleConfigs: newConfigs,
      themeIndex: newIndex,
    ));
    // 打开编辑面板
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _openEditSheet(newIndex, newConfig, newConfigs);
    });
  }

  void _openEditSheet(
    int index,
    ReadStyleConfig config,
    List<ReadStyleConfig> configs,
  ) {
    final canDelete = configs.length > ReadStyleConfig.minEditableCount;
    showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => ReaderStyleEditSheet(
        config: config,
        canDelete: canDelete,
        onChanged: (updated) {
          final newConfigs = List<ReadStyleConfig>.from(configs);
          if (index < newConfigs.length) {
            newConfigs[index] = updated;
          }
          _apply(_draft.copyWith(readStyleConfigs: newConfigs));
        },
        onDelete: () {
          final newConfigs = List<ReadStyleConfig>.from(configs);
          if (index < newConfigs.length) {
            newConfigs.removeAt(index);
          }
          final newIndex = _draft.themeIndex >= newConfigs.length
              ? newConfigs.length - 1
              : _draft.themeIndex;
          _apply(_draft.copyWith(
            readStyleConfigs: newConfigs,
            themeIndex: newIndex.clamp(0, newConfigs.length - 1),
          ));
        },
      ),
    );
  }
}
