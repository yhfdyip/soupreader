import 'package:flutter/cupertino.dart';

import '../../../app/theme/colors.dart';
import '../../../app/theme/design_tokens.dart';
import '../../../app/theme/typography.dart';
import '../models/reading_settings.dart';

class ReaderFontQuickSheet extends StatefulWidget {
  final ReadingSettings settings;
  final List<ReadingThemeColors> themes;
  final ValueChanged<ReadingSettings> onSettingsChanged;
  final VoidCallback onOpenFullSettings;

  const ReaderFontQuickSheet({
    super.key,
    required this.settings,
    required this.themes,
    required this.onSettingsChanged,
    required this.onOpenFullSettings,
  });

  @override
  State<ReaderFontQuickSheet> createState() => _ReaderFontQuickSheetState();
}

class _ReaderFontQuickSheetState extends State<ReaderFontQuickSheet> {
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

  @override
  Widget build(BuildContext context) {
    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;
    final sheetBg = ReaderSettingsTokens.sheetBackground(isDark: isDark);
    final height = MediaQuery.sizeOf(context).height * 0.52;
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: Container(
        height: height,
        color: sheetBg,
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              _Grabber(),
              _Header(isDark: isDark, onDone: () => Navigator.pop(context)),
              Expanded(
                child: ListView(
                  physics: const BouncingScrollPhysics(),
                  children: [
                    _FontSection(settings: _draft, onSettingsChanged: _apply),
                    _SpacingSection(settings: _draft, onSettingsChanged: _apply),
                    _ThemeSection(
                      themes: widget.themes,
                      settings: _draft,
                      onSettingsChanged: _apply,
                    ),
                    const SizedBox(height: 8),
                    _FullSettingsLink(onTap: widget.onOpenFullSettings),
                    const SizedBox(height: 14),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Grabber extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;
    final color = isDark
        ? CupertinoColors.white.withValues(alpha: 0.3)
        : CupertinoColors.separator.resolveFrom(context);
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
}

class _Header extends StatelessWidget {
  final bool isDark;
  final VoidCallback onDone;
  const _Header({required this.isDark, required this.onDone});

  @override
  Widget build(BuildContext context) {
    final tc = isDark
        ? CupertinoColors.white
        : CupertinoColors.label.resolveFrom(context);
    final ac = ReaderSettingsTokens.accent(isDark: isDark);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 2, 8, 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '字体与排版',
              style: TextStyle(
                color: tc,
                fontSize: 15,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.3,
              ),
            ),
          ),
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            minimumSize: Size.zero,
            onPressed: onDone,
            child: Text(
              '完成',
              style: TextStyle(
                color: ac,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FqsSection extends StatelessWidget {
  final String title;
  final Widget child;
  const _FqsSection({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;
    final cc = ReaderSettingsTokens.sectionBackground(isDark: isDark);
    final tc = ReaderSettingsTokens.titleColor(isDark: isDark);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 5),
          child: Text(
            title,
            style: TextStyle(
              color: tc,
              fontSize: 12,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 14),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: cc,
            borderRadius:
                BorderRadius.circular(ReaderSettingsTokens.sectionRadius),
          ),
          child: child,
        ),
      ],
    );
  }
}

class _FontSection extends StatelessWidget {
  final ReadingSettings settings;
  final ValueChanged<ReadingSettings> onSettingsChanged;
  const _FontSection({required this.settings, required this.onSettingsChanged});

  @override
  Widget build(BuildContext context) {
    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;
    final dv = Container(
      height: 0.5,
      margin: const EdgeInsets.symmetric(vertical: 4),
      color: isDark
          ? CupertinoColors.separator.darkColor
          : CupertinoColors.separator.color,
    );
    return _FqsSection(
      title: '字体',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _FontFamilyRow(
            fontFamilyIndex: settings.fontFamilyIndex,
            onChanged: (i) =>
                onSettingsChanged(settings.copyWith(fontFamilyIndex: i)),
          ),
          dv,
          _FontSizeStepRow(
            value: settings.fontSize,
            onChanged: (v) =>
                onSettingsChanged(settings.copyWith(fontSize: v)),
          ),
        ],
      ),
    );
  }
}

class _SpacingSection extends StatelessWidget {
  final ReadingSettings settings;
  final ValueChanged<ReadingSettings> onSettingsChanged;
  const _SpacingSection({required this.settings, required this.onSettingsChanged});

  @override
  Widget build(BuildContext context) {
    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;
    final dividerColor = isDark
        ? CupertinoColors.separator.darkColor
        : CupertinoColors.separator.color;
    Widget dv() => Container(height: 0.5, color: dividerColor);
    return _FqsSection(
      title: '间距',
      child: Column(
        children: [
          _FqsSliderRow(label: '行距', value: settings.lineHeight, min: 1.0, max: 2.2, format: (v) => v.toStringAsFixed(1), onChanged: (v) => onSettingsChanged(settings.copyWith(lineHeight: v))),
          dv(),
          _FqsSliderRow(label: '字距', value: settings.letterSpacing, min: -2.0, max: 5.0, format: (v) => v.toStringAsFixed(1), onChanged: (v) => onSettingsChanged(settings.copyWith(letterSpacing: v))),
          dv(),
          _FqsSliderRow(label: '段距', value: settings.paragraphSpacing, min: 0, max: 18, format: (v) => v.toStringAsFixed(0), onChanged: (v) => onSettingsChanged(settings.copyWith(paragraphSpacing: v))),
        ],
      ),
    );
  }
}

class _ThemeSection extends StatelessWidget {
  final List<ReadingThemeColors> themes;
  final ReadingSettings settings;
  final ValueChanged<ReadingSettings> onSettingsChanged;
  const _ThemeSection({required this.themes, required this.settings, required this.onSettingsChanged});

  @override
  Widget build(BuildContext context) =>
      _FqsSection(
        title: '背景主题',
        child: _ThemeRow(
          themes: themes,
          selectedIndex: settings.themeIndex,
          onSelected: (i) => onSettingsChanged(settings.copyWith(themeIndex: i)),
        ),
      );
}

class _FullSettingsLink extends StatelessWidget {
  final VoidCallback onTap;
  const _FullSettingsLink({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;
    final lc = ReaderSettingsTokens.rowTitleColor(isDark: isDark);
    final cc = ReaderSettingsTokens.sectionBackground(isDark: isDark);
    final chv = isDark
        ? CupertinoColors.white.withValues(alpha: 0.25)
        : CupertinoColors.tertiaryLabel.resolveFrom(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        minimumSize: Size.zero,
        onPressed: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            color: cc,
            borderRadius: BorderRadius.circular(ReaderSettingsTokens.sectionRadius),
          ),
          child: Row(
            children: [
              Expanded(child: Text('完整阅读设置', style: TextStyle(color: lc, fontSize: ReaderSettingsTokens.rowTitleSize))),
              Icon(CupertinoIcons.chevron_right, size: 14, color: chv),
            ],
          ),
        ),
      ),
    );
  }
}

class _FontSizeStepRow extends StatelessWidget {
  final double value;
  final ValueChanged<double> onChanged;
  const _FontSizeStepRow({required this.value, required this.onChanged});
  static const double _mn = 12, _mx = 30, _st = 1;

  @override
  Widget build(BuildContext context) {
    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;
    final ac = ReaderSettingsTokens.accent(isDark: isDark);
    final lc = ReaderSettingsTokens.rowTitleColor(isDark: isDark);
    final mc = ReaderSettingsTokens.rowMetaColor(isDark: isDark);
    final sv = value.isFinite ? value.clamp(_mn, _mx) : 18.0;
    return SizedBox(
      height: 44,
      child: Row(
        children: [
          Text('字号', style: TextStyle(color: lc, fontSize: ReaderSettingsTokens.rowTitleSize)),
          const Spacer(),
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            minimumSize: Size.zero,
            onPressed: sv > _mn ? () => onChanged((sv - _st).clamp(_mn, _mx)) : null,
            child: Text('A', style: TextStyle(color: sv > _mn ? ac : mc, fontSize: 13, fontWeight: FontWeight.w500)),
          ),
          SizedBox(width: 32, child: Text(sv.toStringAsFixed(0), textAlign: TextAlign.center, style: TextStyle(color: lc, fontSize: 15, fontWeight: FontWeight.w600))),
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            minimumSize: Size.zero,
            onPressed: sv < _mx ? () => onChanged((sv + _st).clamp(_mn, _mx)) : null,
            child: Text('A', style: TextStyle(color: sv < _mx ? ac : mc, fontSize: 19, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

class _FqsSliderRow extends StatelessWidget {
  final String label;
  final double value, min, max;
  final String Function(double) format;
  final ValueChanged<double> onChanged;
  const _FqsSliderRow({required this.label, required this.value, required this.min, required this.max, required this.format, required this.onChanged});

  double get _mn => min.isFinite ? min : 0.0;
  double get _mx { final m = _mn; return max.isFinite && max > m ? max : m + 1.0; }
  double get _sv { final r = value.isFinite ? value : _mn; return r.clamp(_mn, _mx).toDouble(); }

  @override
  Widget build(BuildContext context) {
    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;
    final lc = ReaderSettingsTokens.rowTitleColor(isDark: isDark);
    final mc = ReaderSettingsTokens.rowMetaColor(isDark: isDark);
    final ac = ReaderSettingsTokens.accent(isDark: isDark);
    final can = min.isFinite && max.isFinite && max > min;
    return SizedBox(
      height: 44,
      child: Row(
        children: [
          SizedBox(width: 44, child: Text(label, style: TextStyle(color: lc, fontSize: ReaderSettingsTokens.rowMetaSize))),
          Expanded(child: CupertinoSlider(value: _sv, min: _mn, max: _mx, activeColor: ac, onChanged: can ? onChanged : null)),
          SizedBox(width: 46, child: Text(format(_sv), textAlign: TextAlign.end, style: TextStyle(color: mc, fontSize: 12))),
        ],
      ),
    );
  }
}

class _FontFamilyRow extends StatelessWidget {
  final int fontFamilyIndex;
  final ValueChanged<int> onChanged;
  const _FontFamilyRow({required this.fontFamilyIndex, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;
    final si = (fontFamilyIndex >= 0 && fontFamilyIndex < ReadingFontFamily.presets.length) ? fontFamilyIndex : 0;
    final ac = ReaderSettingsTokens.accent(isDark: isDark);
    final bg = isDark ? CupertinoColors.white.withValues(alpha: 0.1) : CupertinoColors.tertiarySystemFill.resolveFrom(context);
    final tc = ReaderSettingsTokens.rowMetaColor(isDark: isDark);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (var i = 0; i < ReadingFontFamily.presets.length; i++)
          _FontChip(label: ReadingFontFamily.presets[i].name, selected: si == i, accent: ac, bgNormal: bg, textNormal: tc, isDark: isDark, onTap: () => onChanged(i)),
      ],
    );
  }
}

class _FontChip extends StatelessWidget {
  final String label;
  final bool selected, isDark;
  final Color accent, bgNormal, textNormal;
  final VoidCallback onTap;
  const _FontChip({required this.label, required this.selected, required this.accent, required this.bgNormal, required this.textNormal, required this.isDark, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final bg = selected ? accent.withValues(alpha: isDark ? 0.18 : 0.12) : bgNormal;
    final tc = selected ? accent : textNormal;
    return CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: Size.zero,
      onPressed: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
          border: selected ? Border.all(color: accent.withValues(alpha: 0.5), width: 1.5) : null,
        ),
        child: Text(label, style: TextStyle(color: tc, fontSize: 13, fontWeight: selected ? FontWeight.w600 : FontWeight.w500)),
      ),
    );
  }
}

class _ThemeRow extends StatelessWidget {
  final List<ReadingThemeColors> themes;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  const _ThemeRow({required this.themes, required this.selectedIndex, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;
    final ss = (selectedIndex >= 0 && selectedIndex < themes.length) ? selectedIndex : 0;
    final ac = ReaderSettingsTokens.accent(isDark: isDark);
    final bn = ReaderSettingsTokens.sectionBorder(isDark: isDark);
    return SizedBox(
      height: 54,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: themes.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final sel = i == ss;
          final t = themes[i];
          return CupertinoButton(
            padding: EdgeInsets.zero,
            minimumSize: Size.zero,
            onPressed: () => onSelected(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 72,
              height: 54,
              decoration: BoxDecoration(
                color: t.background,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: sel ? ac : bn, width: sel ? 2.0 : 0.5),
                boxShadow: sel ? [BoxShadow(color: ac.withValues(alpha: 0.25), blurRadius: 6, offset: const Offset(0, 2))] : null,
              ),
              padding: const EdgeInsets.all(8),
              child: Stack(
                children: [
                  Align(
                    alignment: Alignment.bottomLeft,
                    child: Text(t.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: t.text.withValues(alpha: 0.9), fontSize: 11, fontWeight: sel ? FontWeight.w700 : FontWeight.w500)),
                  ),
                  if (sel)
                    Positioned(
                      top: 0, right: 0,
                      child: Container(
                        width: 16, height: 16,
                        decoration: const BoxDecoration(color: Color(0xFF007AFF), shape: BoxShape.circle),
                        child: const Icon(CupertinoIcons.checkmark, color: CupertinoColors.white, size: 10),
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
}
