import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../theme/design_tokens.dart';
import '../theme/ui_tokens.dart';
import 'app_squircle_surface.dart';
import 'cupertino_bottom_dialog.dart';

part 'option_picker_sheet_parts.dart';

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
  static const double _kMaxHeightFactor = 0.58;

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
    final maxHeight = mediaQuery.size.height * _kMaxHeightFactor;

    return SafeArea(
      top: false,
      child: DecoratedBox(
        decoration: _buildPanelDecoration(ui),
        child: Padding(
          padding: EdgeInsets.fromLTRB(10, 8, 10, bottomInset),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _OptionPickerHeader(
                title: title,
                message: message,
                handleColor: ui.colors.separator.withValues(alpha: 0.72),
                titleColor: ui.colors.label,
                subtitleColor: ui.colors.secondaryLabel,
              ),
              _OptionPickerBody<T>(
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
            ],
          ),
        ),
      ),
    );
  }

  BoxDecoration _buildPanelDecoration(AppUiTokens ui) {
    final panelTop = ui.isDark
        ? AppDesignTokens.pageBgDark.withValues(alpha: 0.96)
        : AppDesignTokens.pageBgLight.withValues(alpha: 0.96);
    final panelBottom = ui.isDark
        ? AppDesignTokens.surfaceDark.withValues(alpha: 0.96)
        : AppDesignTokens.surfaceLight.withValues(alpha: 0.96);
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[panelTop, panelBottom],
      ),
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(ui.radii.sheet),
      ),
    );
  }

  void _dismiss(BuildContext context, {T? value}) {
    HapticFeedback.selectionClick();
    Navigator.of(context).pop(value);
  }
}
