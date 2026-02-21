import 'dart:math' as math;

import 'package:flutter/cupertino.dart';

import '../theme/design_tokens.dart';

/// 通用单选底部面板（用于替换纯“选项选择器”类 ActionSheet）。
class OptionPickerItem<T> {
  final T value;
  final String label;
  final String? subtitle;
  final bool enabled;
  final bool isRecommended;

  const OptionPickerItem({
    required this.value,
    required this.label,
    this.subtitle,
    this.enabled = true,
    this.isRecommended = false,
  });
}

Future<T?> showOptionPickerSheet<T>({
  required BuildContext context,
  required String title,
  String? message,
  required List<OptionPickerItem<T>> items,
  required T? currentValue,
  String cancelText = '取消',
  Color? accentColor,
}) {
  final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;
  final barrier = isDark ? const Color(0x80000000) : const Color(0x4D000000);
  return showCupertinoModalPopup<T>(
    context: context,
    barrierColor: barrier,
    builder: (sheetContext) => _OptionPickerSheet<T>(
      title: title,
      message: message,
      items: items,
      currentValue: currentValue,
      cancelText: cancelText,
      accentColor: accentColor,
    ),
  );
}

class _OptionPickerSheet<T> extends StatelessWidget {
  final String title;
  final String? message;
  final List<OptionPickerItem<T>> items;
  final T? currentValue;
  final String cancelText;
  final Color? accentColor;

  const _OptionPickerSheet({
    required this.title,
    required this.message,
    required this.items,
    required this.currentValue,
    required this.cancelText,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;
    final panelBg =
        isDark ? ReaderOverlayTokens.panelDark : ReaderOverlayTokens.panelLight;
    final cardBg =
        isDark ? ReaderOverlayTokens.cardDark : ReaderOverlayTokens.cardLight;
    final border = isDark
        ? ReaderOverlayTokens.borderDark
        : ReaderOverlayTokens.borderLight;
    final textStrong = isDark
        ? ReaderOverlayTokens.textStrongDark
        : ReaderOverlayTokens.textStrongLight;
    final textNormal = isDark
        ? ReaderOverlayTokens.textNormalDark
        : ReaderOverlayTokens.textNormalLight;
    final textSubtle = isDark
        ? ReaderOverlayTokens.textSubtleDark
        : ReaderOverlayTokens.textSubtleLight;
    final accent = accentColor ??
        (isDark
            ? AppDesignTokens.brandSecondary
            : AppDesignTokens.brandPrimary);
    final mediaQuery = MediaQuery.of(context);
    final bottomInset = math.max(mediaQuery.padding.bottom, 8.0);

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(10, 0, 10, bottomInset),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              decoration: BoxDecoration(
                color: panelBg,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: border),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 8),
                  Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: textSubtle.withValues(alpha: 0.36),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: Text(
                      title,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: textStrong,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (message != null && message!.trim().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                      child: Text(
                        message!.trim(),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: textSubtle,
                          fontSize: 12,
                        ),
                      ),
                    )
                  else
                    const SizedBox(height: 8),
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: mediaQuery.size.height * 0.56,
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final item = items[index];
                        final selected = item.value == currentValue;
                        return _OptionTile<T>(
                          item: item,
                          selected: selected,
                          accent: accent,
                          cardBg: cardBg,
                          border: border,
                          textStrong: textStrong,
                          textNormal: textNormal,
                          onTap: item.enabled
                              ? () {
                                  Navigator.of(context).pop(item.value);
                                }
                              : null,
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: panelBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: border),
              ),
              child: CupertinoButton(
                padding:
                    const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  cancelText,
                  style: TextStyle(
                    color: textStrong,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OptionTile<T> extends StatelessWidget {
  final OptionPickerItem<T> item;
  final bool selected;
  final Color accent;
  final Color cardBg;
  final Color border;
  final Color textStrong;
  final Color textNormal;
  final VoidCallback? onTap;

  const _OptionTile({
    required this.item,
    required this.selected,
    required this.accent,
    required this.cardBg,
    required this.border,
    required this.textStrong,
    required this.textNormal,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tileBorder = selected ? accent : border;
    final tileBg = selected ? accent.withValues(alpha: 0.16) : cardBg;
    return Opacity(
      opacity: item.enabled ? 1 : 0.45,
      child: Container(
        decoration: BoxDecoration(
          color: tileBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: tileBorder, width: selected ? 1.2 : 1),
        ),
        child: CupertinoButton(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          minSize: 0,
          onPressed: onTap,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.label,
                            style: TextStyle(
                              color: selected ? accent : textStrong,
                              fontSize: 15,
                              fontWeight:
                                  selected ? FontWeight.w700 : FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (item.isRecommended)
                          Container(
                            margin: const EdgeInsets.only(left: 8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: accent.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              '推荐',
                              style: TextStyle(
                                color: accent,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                      ],
                    ),
                    if (item.subtitle != null &&
                        item.subtitle!.trim().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Text(
                          item.subtitle!.trim(),
                          style: TextStyle(
                            color: textNormal,
                            fontSize: 12,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              if (selected)
                Icon(
                  CupertinoIcons.check_mark_circled_solid,
                  color: accent,
                  size: 18,
                )
              else
                Icon(
                  CupertinoIcons.circle,
                  color: border,
                  size: 17,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
