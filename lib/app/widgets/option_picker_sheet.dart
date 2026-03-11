import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../theme/design_tokens.dart';
import '../theme/ui_tokens.dart';
import 'app_glass_sheet_panel.dart';
import 'app_ui_kit.dart';
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
    builder: (_) => _OptionPickerSheet<T>(
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
  static const double _maxHeightFactor = 0.58;
  static const double _minTopSpacing = 16.0;
  static const double _panelTopPadding = 8.0;
  static const double _minScrollableHeight = 120.0;

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
    final mediaQuery = MediaQuery.of(context);
    final bottomInset = math.max(mediaQuery.padding.bottom, 8.0);
    final sheetMaxHeight = _resolveSheetMaxHeight(mediaQuery);
    final maxHeight = _resolveScrollableMaxHeight(
      mediaQuery: mediaQuery,
      bottomInset: bottomInset,
      sheetMaxHeight: sheetMaxHeight,
    );

    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: sheetMaxHeight),
        child: AppGlassSheetPanel(
          contentPadding: EdgeInsets.fromLTRB(10, _panelTopPadding, 10, bottomInset),
          radius: ui.radii.sheet,
          child: OptionPickerBody<T>(
            header: OptionPickerHeader(
              title: title,
              message: message,
              handleColor: ui.colors.separator.withValues(alpha: 0.72),
              titleColor: ui.colors.label,
              subtitleColor: ui.colors.secondaryLabel,
            ),
            items: items,
            currentValue: currentValue,
            accent: accent,
            cancelText: cancelText,
            cancelColor: ui.colors.label,
            showCancel: showCancel,
            maxHeight: maxHeight,
            onSelect: (value) => _dismiss(context, value: value),
            onCancel: () => _dismiss(context),
          ),
        ),
      ),
    );
  }

  double _resolveSheetMaxHeight(MediaQueryData mediaQuery) {
    final availableHeight =
        mediaQuery.size.height - mediaQuery.padding.top - _minTopSpacing;
    return math.max(_minScrollableHeight, availableHeight);
  }

  double _resolveScrollableMaxHeight({
    required MediaQueryData mediaQuery,
    required double bottomInset,
    required double sheetMaxHeight,
  }) {
    final maxByFactor = mediaQuery.size.height * _maxHeightFactor;
    final maxByViewport = math.max(
      _minScrollableHeight,
      sheetMaxHeight - _panelTopPadding - bottomInset,
    );
    return math.min(maxByFactor, maxByViewport);
  }

  void _dismiss(BuildContext context, {T? value}) {
    HapticFeedback.selectionClick();
    Navigator.of(context).pop(value);
  }
}

class OptionPickerHeader extends StatelessWidget {
  final String title;
  final String? message;
  final Color handleColor;
  final Color titleColor;
  final Color subtitleColor;

  const OptionPickerHeader({
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
              fontWeight: FontWeight.w600,
              letterSpacing: -0.24,
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
                letterSpacing: -0.2,
              ),
            ),
          )
        else
          const SizedBox(height: 8),
      ],
    );
  }
}

class OptionPickerBody<T> extends StatelessWidget {
  final Widget header;
  final List<OptionPickerItem<T>> items;
  final T? currentValue;
  final Color accent;
  final String cancelText;
  final Color cancelColor;
  final bool showCancel;
  final double maxHeight;
  final ValueChanged<T> onSelect;
  final VoidCallback onCancel;

  const OptionPickerBody({
    required this.header,
    required this.items,
    required this.currentValue,
    required this.accent,
    required this.cancelText,
    required this.cancelColor,
    required this.showCancel,
    required this.maxHeight,
    required this.onSelect,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final ui = AppUiTokens.resolve(context);
    final cardColor = ui.colors.surfaceBackground;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: ListView(
        shrinkWrap: true,
        physics: const BouncingScrollPhysics(),
        children: [
          header,
          OptionPickerCard(
            color: cardColor,
            radius: ui.radii.card,
            child: AppListSection(
              margin: EdgeInsets.zero,
              hasLeading: false,
              children: [
                for (final item in items)
                  OptionPickerRow<T>(
                    item: item,
                    selected: item.value == currentValue,
                    accent: accent,
                    onTap: item.enabled ? () => onSelect(item.value) : null,
                  ),
              ],
            ),
          ),
          if (showCancel) ...[
            const SizedBox(height: 10),
            OptionPickerCard(
              color: cardColor,
              radius: ui.radii.card,
              child: AppListSection(
                margin: EdgeInsets.zero,
                hasLeading: false,
                children: [
                  CupertinoListTile.notched(
                    title: Text(
                      cancelText,
                      style: TextStyle(
                        color: cancelColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    onTap: onCancel,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class OptionPickerCard extends StatelessWidget {
  final Widget child;
  final Color color;
  final double radius;

  const OptionPickerCard({
    required this.child,
    required this.color,
    required this.radius,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: ColoredBox(
        color: color,
        child: child,
      ),
    );
  }
}

class OptionPickerRow<T> extends StatelessWidget {
  final OptionPickerItem<T> item;
  final bool selected;
  final Color accent;
  final VoidCallback? onTap;

  const OptionPickerRow({
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
      letterSpacing: -0.2,
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
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: accent.withValues(alpha: 0.28),
                    width: AppDesignTokens.hairlineBorderWidth,
                  ),
                ),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
            ),
        ],
      ),
      subtitle: subtitle.isEmpty
          ? null
          : Text(
              subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: subtitleColor,
                fontSize: 12,
                letterSpacing: -0.2,
              ),
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
