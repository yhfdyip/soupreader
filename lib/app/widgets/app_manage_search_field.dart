import 'package:flutter/cupertino.dart';

import '../theme/design_tokens.dart';
import '../theme/ui_tokens.dart';

class AppManageSearchField extends StatelessWidget {
  static const EdgeInsets outerPadding = EdgeInsets.fromLTRB(12, 8, 12, 10);
  static const double height = 38;
  static const double _focusedBorderAlpha = 0.9;
  static const double _idleBorderAlpha = 0.78;

  final TextEditingController controller;
  final String placeholder;
  final FocusNode? focusNode;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  const AppManageSearchField({
    super.key,
    required this.controller,
    required this.placeholder,
    this.focusNode,
    this.onChanged,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    final ui = AppUiTokens.resolve(context);
    final baseStyle = CupertinoTheme.of(context).textTheme.textStyle;
    final style = _resolveSurfaceStyle(context, ui, focusNode?.hasFocus ?? false);
    final iconColor = ui.colors.secondaryLabel.withValues(alpha: 0.95);
    return _buildSurface(
      ui: ui,
      baseStyle: baseStyle,
      iconColor: iconColor,
      style: style,
    );
  }

  _SearchSurfaceStyle _resolveSurfaceStyle(
    BuildContext context,
    AppUiTokens ui,
    bool isFocused,
  ) {
    // iOS 搜索框标准背景：tertiarySystemFill，随系统深浅色自动适配。
    final background = CupertinoColors.tertiarySystemFill.resolveFrom(context);
    final border = ui.colors.separator.withValues(
      alpha: isFocused ? _focusedBorderAlpha : _idleBorderAlpha,
    );
    return _SearchSurfaceStyle(
      background: background,
      border: border,
    );
  }

  Widget _buildSurface({
    required AppUiTokens ui,
    required TextStyle baseStyle,
    required Color iconColor,
    required _SearchSurfaceStyle style,
  }) {
    return SizedBox(
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: style.background,
          borderRadius: BorderRadius.circular(ui.radii.control),
          border: Border.all(
            color: style.border,
            width: AppDesignTokens.hairlineBorderWidth,
          ),
        ),
        child: _buildInputField(baseStyle, ui, iconColor),
      ),
    );
  }

  Widget _buildInputField(
    TextStyle baseStyle,
    AppUiTokens ui,
    Color iconColor,
  ) {
    return CupertinoTextField(
      controller: controller,
      focusNode: focusNode,
      placeholder: placeholder,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      clearButtonMode: OverlayVisibilityMode.editing,
      padding: const EdgeInsets.fromLTRB(10, 8, 12, 8),
      decoration: null,
      prefix: Padding(
        padding: const EdgeInsetsDirectional.only(start: 10, end: 8),
        child: Icon(CupertinoIcons.search, size: 17, color: iconColor),
      ),
      style: baseStyle.copyWith(
        fontSize: 14,
        color: ui.colors.label,
        letterSpacing: -0.2,
      ),
      placeholderStyle: baseStyle.copyWith(
        fontSize: 14,
        color: ui.colors.secondaryLabel,
        letterSpacing: -0.2,
      ),
    );
  }
}

@immutable
class _SearchSurfaceStyle {
  const _SearchSurfaceStyle({
    required this.background,
    required this.border,
  });

  final Color background;
  final Color border;
}
