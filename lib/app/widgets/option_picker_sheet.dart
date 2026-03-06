import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../theme/design_tokens.dart';
import '../theme/ui_tokens.dart';
import 'app_glass_sheet_panel.dart';
import 'app_ui_kit.dart';
import 'app_squircle_surface.dart';
import 'cupertino_bottom_dialog.dart';

part 'option_picker_sheet_parts.dart';
part 'option_picker_sheet_row.dart';

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
          child: _OptionPickerBody<T>(
            header: _OptionPickerHeader(
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
