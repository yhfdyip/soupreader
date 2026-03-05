import 'package:flutter/cupertino.dart';

import '../theme/design_tokens.dart';
import '../theme/ui_tokens.dart';
import 'app_squircle_surface.dart';

class AppManageSearchField extends StatelessWidget {
  static const EdgeInsets outerPadding = EdgeInsets.fromLTRB(12, 8, 12, 10);
  static const double height = 38;

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
    final isDark = ui.isDark;
    final shellColor = isDark
        ? AppDesignTokens.glassDarkMaterial.withValues(alpha: 0.9)
        : AppDesignTokens.glassLightMaterial.withValues(alpha: 0.9);
    final iconColor = ui.colors.secondaryLabel.withValues(alpha: 0.95);

    return SizedBox(
      height: height,
      child: AppSquircleSurface(
        padding: EdgeInsets.zero,
        backgroundColor: shellColor,
        borderColor: ui.colors.separator.withValues(alpha: 0.78),
        radius: ui.radii.control,
        borderWidth: AppDesignTokens.hairlineBorderWidth,
        blurBackground: true,
        shadows: <BoxShadow>[
          BoxShadow(
            color: (isDark ? CupertinoColors.black : const Color(0xFF0A2A5E))
                .withValues(alpha: isDark ? 0.24 : 0.1),
            offset: const Offset(0, 6),
            blurRadius: 14,
            spreadRadius: -9,
          ),
        ],
        child: CupertinoTextField(
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
        ),
      ),
    );
  }
}
