import 'dart:math' as math;

import 'package:flutter/cupertino.dart';

import '../theme/typography.dart';
import '../theme/ui_tokens.dart';
import 'cupertino_bottom_dialog.dart';

class AppActionListItem<T> {
  final T value;
  final IconData icon;
  final String label;
  final bool enabled;
  final bool isDestructiveAction;

  const AppActionListItem({
    required this.value,
    required this.icon,
    required this.label,
    this.enabled = true,
    this.isDestructiveAction = false,
  });
}

Future<T?> showAppActionListSheet<T>({
  required BuildContext context,
  required String title,
  String? message,
  required List<AppActionListItem<T>> items,
  String cancelText = '取消',
  TextAlign titleAlign = TextAlign.left,
  bool showCancel = false,
  bool barrierDismissible = true,
  Color? accentColor,
}) {
  return showCupertinoBottomSheetDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    builder: (_) => _AppActionListSheet<T>(
      title: title,
      message: message,
      items: items,
      cancelText: cancelText,
      titleAlign: titleAlign,
      showCancel: showCancel,
      accentColor: accentColor,
    ),
  );
}

class _AppActionListSheet<T> extends StatelessWidget {
  static const double _maxHeightFactor = 0.74;
  static const double _rowHeight = 48;

  final String title;
  final String? message;
  final List<AppActionListItem<T>> items;
  final String cancelText;
  final TextAlign titleAlign;
  final bool showCancel;
  final Color? accentColor;

  const _AppActionListSheet({
    required this.title,
    required this.message,
    required this.items,
    required this.cancelText,
    required this.titleAlign,
    required this.showCancel,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final ui = AppUiTokens.resolve(context);
    final resolvedAccent = accentColor ?? ui.colors.accent;
    final bottomInset = math.max(MediaQuery.of(context).padding.bottom, 8.0);
    final trimmedMessage = (message ?? '').trim();
    final maxHeight = MediaQuery.sizeOf(context).height * _maxHeightFactor;
    final children = _buildChildren(
      context,
      ui: ui,
      accent: resolvedAccent,
      trimmedMessage: trimmedMessage,
    );

    return SafeArea(
      top: false,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: ui.colors.groupedBackground,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(ui.radii.sheet),
          ),
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(10, 10, 10, bottomInset),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxHeight),
            child: ListView(
              shrinkWrap: true,
              physics: const BouncingScrollPhysics(),
              children: children,
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildChildren(
    BuildContext context, {
    required AppUiTokens ui,
    required Color accent,
    required String trimmedMessage,
  }) {
    final dividerColor = ui.colors.separator;
    final dividerHeight = ui.sizes.dividerThickness;
    final cardRadius = ui.radii.card;
    final cardBg = ui.colors.surfaceBackground;

    final actionCardChildren = <Widget>[
      _SheetHeader(
        title: title,
        message: trimmedMessage,
        titleAlign: titleAlign,
        titleColor: ui.colors.label,
        messageColor: ui.colors.secondaryLabel,
      ),
      if (items.isNotEmpty)
        Container(height: dividerHeight, color: dividerColor),
      if (items.isNotEmpty)
        for (var i = 0; i < items.length; i++) ...[
          _ActionRow<T>(
            height: _rowHeight,
            item: items[i],
            accent: accent,
            labelColor: ui.colors.label,
            destructiveColor: ui.colors.destructive,
          ),
          if (i != items.length - 1)
            Container(height: dividerHeight, color: dividerColor),
        ],
    ];

    final children = <Widget>[
      _SheetCard(
        backgroundColor: cardBg,
        radius: cardRadius,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: actionCardChildren,
        ),
      ),
    ];

    if (showCancel) {
      children.addAll(
        [
          const SizedBox(height: 10),
          _SheetCard(
            backgroundColor: cardBg,
            radius: cardRadius,
            child: _CancelRow(
              height: _rowHeight,
              label: cancelText,
              labelColor: ui.colors.label,
              onTap: () => Navigator.of(context).pop(),
            ),
          ),
        ],
      );
    }
    return children;
  }
}

class _SheetCard extends StatelessWidget {
  final Widget child;
  final Color backgroundColor;
  final double radius;

  const _SheetCard({
    required this.child,
    required this.backgroundColor,
    required this.radius,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(radius),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}

class _SheetHeader extends StatelessWidget {
  final String title;
  final String message;
  final TextAlign titleAlign;
  final Color titleColor;
  final Color messageColor;

  const _SheetHeader({
    required this.title,
    required this.message,
    required this.titleAlign,
    required this.titleColor,
    required this.messageColor,
  });

  @override
  Widget build(BuildContext context) {
    final resolvedAlign = switch (titleAlign) {
      TextAlign.left => CrossAxisAlignment.start,
      TextAlign.right => CrossAxisAlignment.end,
      _ => CrossAxisAlignment.center,
    };

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: resolvedAlign,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 2),
          child: Text(
            title,
            textAlign: titleAlign,
            style: TextStyle(
              color: titleColor,
              fontFamily: AppTypography.fontFamilySans,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        if (message.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
            child: Text(
              message,
              textAlign: titleAlign,
              style: TextStyle(
                color: messageColor,
                fontFamily: AppTypography.fontFamilySans,
                fontSize: 13,
                height: 1.3,
              ),
            ),
          )
        else
          const SizedBox(height: 8),
      ],
    );
  }
}

class _ActionRow<T> extends StatelessWidget {
  final double height;
  final AppActionListItem<T> item;
  final Color accent;
  final Color labelColor;
  final Color destructiveColor;

  const _ActionRow({
    required this.height,
    required this.item,
    required this.accent,
    required this.labelColor,
    required this.destructiveColor,
  });

  @override
  Widget build(BuildContext context) {
    final ui = AppUiTokens.resolve(context);
    final enabled = item.enabled;
    final textColor = item.isDestructiveAction ? destructiveColor : labelColor;
    final iconColor = item.isDestructiveAction ? destructiveColor : accent;

    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        minimumSize: ui.sizes.compactTapSquare,
        onPressed: enabled ? () => Navigator.of(context).pop(item.value) : null,
        child: SizedBox(
          height: height,
          width: double.infinity,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Icon(item.icon, size: 18, color: iconColor),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    item.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: textColor,
                      fontFamily: AppTypography.fontFamilySans,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CancelRow extends StatelessWidget {
  final double height;
  final String label;
  final Color labelColor;
  final VoidCallback onTap;

  const _CancelRow({
    required this.height,
    required this.label,
    required this.labelColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final ui = AppUiTokens.resolve(context);
    return CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: ui.sizes.compactTapSquare,
      onPressed: onTap,
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: labelColor,
              fontFamily: AppTypography.fontFamilySans,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
