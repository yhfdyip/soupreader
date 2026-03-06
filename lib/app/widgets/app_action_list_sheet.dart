import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../theme/design_tokens.dart';
import '../theme/ui_tokens.dart';
import 'app_glass_sheet_panel.dart';
import 'app_squircle_surface.dart';
import 'cupertino_bottom_dialog.dart';

part 'app_action_list_sheet_parts.dart';

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
  static const double _minTopSpacing = 16.0;
  static const double _panelTopPadding = 8.0;
  static const double _handleHeight = 5.0;
  static const double _handleSpacing = 8.0;
  static const double _minScrollableHeight = _rowHeight * 2;

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
    final accent = accentColor ?? ui.colors.accent;
    final mediaQuery = MediaQuery.of(context);
    final bottomInset = math.max(mediaQuery.padding.bottom, 8.0);
    final trimmedMessage = (message ?? '').trim();
    final sheetMaxHeight = _resolveSheetMaxHeight(mediaQuery);
    final maxHeight = _resolveScrollableMaxHeight(
      mediaQuery: mediaQuery,
      bottomInset: bottomInset,
      sheetMaxHeight: sheetMaxHeight,
    );
    final children = _buildChildren(
      context,
      ui: ui,
      accent: accent,
      trimmedMessage: trimmedMessage,
    );

    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: sheetMaxHeight),
        child: AppGlassSheetPanel(
          contentPadding: EdgeInsets.fromLTRB(10, _panelTopPadding, 10, bottomInset),
          radius: ui.radii.sheet,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _SheetHandle(
                color: ui.colors.secondaryLabel.withValues(alpha: 0.38),
              ),
              const SizedBox(height: _handleSpacing),
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: maxHeight),
                child: ListView(
                  shrinkWrap: true,
                  physics: const BouncingScrollPhysics(),
                  children: children,
                ),
              ),
            ],
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
    final fixedChromeHeight =
        _panelTopPadding + bottomInset + _handleHeight + _handleSpacing;
    final maxByViewport = math.max(
      _minScrollableHeight,
      sheetMaxHeight - fixedChromeHeight,
    );
    return math.min(maxByFactor, maxByViewport);
  }

  void _dismissWithFeedback(BuildContext context, [T? value]) {
    HapticFeedback.selectionClick();
    Navigator.of(context).pop(value);
  }

  List<Widget> _buildChildren(
    BuildContext context, {
    required AppUiTokens ui,
    required Color accent,
    required String trimmedMessage,
  }) {
    final dividerColor = ui.colors.separator.withValues(alpha: 0.78);
    final cardRadius = ui.radii.card;
    final cardBg = ui.colors.surfaceBackground.withValues(alpha: 0.9);
    final children = <Widget>[
      _SheetCard(
        backgroundColor: cardBg,
        borderColor: dividerColor,
        radius: cardRadius,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: _buildActionCardChildren(
            context,
            ui: ui,
            accent: accent,
            dividerColor: dividerColor,
            trimmedMessage: trimmedMessage,
          ),
        ),
      ),
    ];

    if (showCancel) {
      children.addAll(
        <Widget>[
          const SizedBox(height: 10),
          _SheetCard(
            backgroundColor: cardBg,
            borderColor: dividerColor,
            radius: cardRadius,
            child: _CancelRow(
              height: _rowHeight,
              label: cancelText,
              labelColor: ui.colors.label,
              onTap: () => _dismissWithFeedback(context),
            ),
          ),
        ],
      );
    }
    return children;
  }

  List<Widget> _buildActionCardChildren(
    BuildContext context, {
    required AppUiTokens ui,
    required Color accent,
    required Color dividerColor,
    required String trimmedMessage,
  }) {
    final dividerHeight = ui.sizes.dividerThickness;
    final actionRows = <Widget>[];
    for (var i = 0; i < items.length; i++) {
      actionRows.add(
        _ActionRow<T>(
          height: _rowHeight,
          item: items[i],
          accent: accent,
          labelColor: ui.colors.label,
          destructiveColor: ui.colors.destructive,
          onSelected: (value) => _dismissWithFeedback(context, value),
        ),
      );
      if (i != items.length - 1) {
        actionRows.add(Container(height: dividerHeight, color: dividerColor));
      }
    }
    return <Widget>[
      _SheetHeader(
        title: title,
        message: trimmedMessage,
        titleAlign: titleAlign,
        titleColor: ui.colors.label,
        messageColor: ui.colors.secondaryLabel,
      ),
      if (items.isNotEmpty)
        Container(height: dividerHeight, color: dividerColor),
      ...actionRows,
    ];
  }
}
