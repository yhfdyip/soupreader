import 'dart:math' as math;

import 'package:flutter/cupertino.dart';

import '../theme/ui_tokens.dart';
import 'cupertino_bottom_dialog.dart';

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
  bool showCancel = false,
  Color? accentColor,
}) {
  return showCupertinoBottomSheetDialog<T>(
    context: context,
    barrierDismissible: true,
    builder: (sheetContext) => _OptionPickerSheet<T>(
      title: title,
      message: message,
      items: items,
      currentValue: currentValue,
      cancelText: cancelText,
      showCancel: showCancel,
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
  final bool showCancel;
  final Color? accentColor;

  const _OptionPickerSheet({
    required this.title,
    required this.message,
    required this.items,
    required this.currentValue,
    required this.cancelText,
    required this.showCancel,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final ui = AppUiTokens.resolve(context);
    final accent = accentColor ?? ui.colors.accent;
    final sheetBg = ui.colors.groupedBackground;
    final titleColor = ui.colors.label;
    final subtitleColor = ui.colors.secondaryLabel;
    final handleColor = ui.colors.separator.withValues(alpha: 0.72);
    final mediaQuery = MediaQuery.of(context);
    final bottomInset = math.max(mediaQuery.padding.bottom, 8.0);
    final maxHeight = mediaQuery.size.height * 0.58;

    return SafeArea(
      top: false,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: sheetBg,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(ui.radii.sheet),
          ),
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(10, 10, 10, bottomInset),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _OptionPickerHeader(
                title: title,
                message: message,
                handleColor: handleColor,
                titleColor: titleColor,
                subtitleColor: subtitleColor,
              ),
              _OptionPickerContent<T>(
                items: items,
                currentValue: currentValue,
                accent: accent,
                cancelText: cancelText,
                cancelColor: titleColor,
                showCancel: showCancel,
                maxHeight: maxHeight,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OptionPickerHeader extends StatelessWidget {
  final String title;
  final String? message;
  final Color handleColor;
  final Color titleColor;
  final Color subtitleColor;

  const _OptionPickerHeader({
    required this.title,
    required this.message,
    required this.handleColor,
    required this.titleColor,
    required this.subtitleColor,
  });

  @override
  Widget build(BuildContext context) {
    final trimmedMessage = (message ?? '').trim();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 36,
          height: 4,
          decoration: BoxDecoration(
            color: handleColor,
            borderRadius: BorderRadius.circular(999),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 2),
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: titleColor,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        if (trimmedMessage.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Text(
              trimmedMessage,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: subtitleColor,
                fontSize: 12,
              ),
            ),
          )
        else
          const SizedBox(height: 8),
      ],
    );
  }
}

class _OptionPickerContent<T> extends StatelessWidget {
  final List<OptionPickerItem<T>> items;
  final T? currentValue;
  final Color accent;
  final String cancelText;
  final Color cancelColor;
  final bool showCancel;
  final double maxHeight;

  const _OptionPickerContent({
    required this.items,
    required this.currentValue,
    required this.accent,
    required this.cancelText,
    required this.cancelColor,
    required this.showCancel,
    required this.maxHeight,
  });

  @override
  Widget build(BuildContext context) {
    final ui = AppUiTokens.resolve(context);
    final sectionDecoration = BoxDecoration(
      color: ui.colors.surfaceBackground,
      borderRadius: BorderRadius.circular(ui.radii.card),
    );

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: ListView(
        shrinkWrap: true,
        physics: const BouncingScrollPhysics(),
        children: [
          CupertinoListSection.insetGrouped(
            margin: EdgeInsets.zero,
            hasLeading: false,
            backgroundColor: ui.colors.groupedBackground,
            decoration: sectionDecoration,
            separatorColor: ui.colors.separator,
            children: [
              for (final item in items)
                _OptionPickerRow<T>(
                  item: item,
                  selected: item.value == currentValue,
                  accent: accent,
                  onTap: item.enabled
                      ? () => Navigator.of(context).pop(item.value)
                      : null,
                ),
            ],
          ),
          if (showCancel) ...[
            const SizedBox(height: 10),
            CupertinoListSection.insetGrouped(
              margin: EdgeInsets.zero,
              hasLeading: false,
              backgroundColor: ui.colors.groupedBackground,
              decoration: sectionDecoration,
              separatorColor: ui.colors.separator,
              children: [
                CupertinoListTile.notched(
                  title: Text(
                    cancelText,
                    style: TextStyle(
                      color: cancelColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onTap: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _OptionPickerRow<T> extends StatelessWidget {
  final OptionPickerItem<T> item;
  final bool selected;
  final Color accent;
  final VoidCallback? onTap;

  const _OptionPickerRow({
    required this.item,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final ui = AppUiTokens.resolve(context);
    final labelColor =
        item.enabled ? ui.colors.label : ui.colors.secondaryLabel;
    final subtitleColor = ui.colors.secondaryLabel;
    final titleStyle = TextStyle(
      color: labelColor,
      fontWeight: FontWeight.w600,
    );
    final subtitle = (item.subtitle ?? '').trim();

    return CupertinoListTile.notched(
      title: Row(
        children: [
          Expanded(
            child: Text(
              item.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: titleStyle,
            ),
          ),
          if (item.isRecommended)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '推荐',
                  style: TextStyle(
                    color: accent,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
      subtitle: subtitle.isEmpty
          ? null
          : Text(
              subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: subtitleColor, fontSize: 12),
            ),
      trailing: selected
          ? Icon(
              CupertinoIcons.check_mark,
              size: ui.iconSizes.listTrailing,
              color: accent,
            )
          : null,
      onTap: onTap,
    );
  }
}
