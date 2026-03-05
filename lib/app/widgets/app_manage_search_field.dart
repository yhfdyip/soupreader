import 'package:flutter/cupertino.dart';

import '../theme/design_tokens.dart';
import '../theme/ui_tokens.dart';
import 'app_squircle_surface.dart';

class AppManageSearchField extends StatelessWidget {
  static const EdgeInsets outerPadding = EdgeInsets.fromLTRB(12, 8, 12, 10);
  static const double height = 38;
  static const double _focusedBorderAlpha = 0.9;
  static const double _idleBorderAlpha = 0.78;
  static const double _focusedShadowDarkAlpha = 0.28;
  static const double _idleShadowDarkAlpha = 0.24;
  static const double _focusedShadowLightAlpha = 0.14;
  static const double _idleShadowLightAlpha = 0.1;
  static const double _bezelAlpha = 0.56;

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
    final style = _resolveSurfaceStyle(ui, focusNode?.hasFocus ?? false);
    final iconColor = ui.colors.secondaryLabel.withValues(alpha: 0.95);
    return _buildSurface(
      ui: ui,
      baseStyle: baseStyle,
      iconColor: iconColor,
      style: style,
    );
  }

  _SearchSurfaceStyle _resolveSurfaceStyle(AppUiTokens ui, bool isFocused) {
    final isDark = ui.isDark;
    final background = isDark
        ? AppDesignTokens.glassDarkMaterial.withValues(alpha: 0.9)
        : AppDesignTokens.glassLightMaterial.withValues(alpha: 0.9);
    final border = ui.colors.separator.withValues(
      alpha: isFocused ? _focusedBorderAlpha : _idleBorderAlpha,
    );
    final shadow =
        (isDark ? CupertinoColors.black : const Color(0xFF0A2A5E)).withValues(
      alpha: isDark
          ? (isFocused ? _focusedShadowDarkAlpha : _idleShadowDarkAlpha)
          : (isFocused ? _focusedShadowLightAlpha : _idleShadowLightAlpha),
    );
    final bezel = (isDark
            ? AppDesignTokens.glassInnerHighlightDark
            : AppDesignTokens.glassInnerHighlightLight)
        .withValues(alpha: _bezelAlpha);
    return _SearchSurfaceStyle(
      background: background,
      border: border,
      shadow: shadow,
      bezel: bezel,
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
      child: AppSquircleSurface(
        padding: EdgeInsets.zero,
        backgroundColor: style.background,
        borderColor: style.border,
        radius: ui.radii.control,
        borderWidth: AppDesignTokens.hairlineBorderWidth,
        blurBackground: true,
        shadows: <BoxShadow>[
          BoxShadow(
            color: style.shadow,
            offset: const Offset(0, 6),
            blurRadius: 14,
            spreadRadius: -9,
          ),
        ],
        child: Stack(
          children: [
            Align(
              alignment: Alignment.topCenter,
              child: SizedBox(
                height: AppDesignTokens.hairlineBorderWidth,
                child: ColoredBox(color: style.bezel),
              ),
            ),
            _buildInputField(baseStyle, ui, iconColor),
          ],
        ),
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
    required this.shadow,
    required this.bezel,
  });

  final Color background;
  final Color border;
  final Color shadow;
  final Color bezel;
}
