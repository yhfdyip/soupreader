import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../theme/design_tokens.dart';
import 'app_squircle_surface.dart';

class AppWebViewToolbar extends StatelessWidget {
  static const double height = 50;
  static const double _iconSize = 20;
  static const double _buttonSize = 38;
  static const double _dividerHeight = AppDesignTokens.hairlineBorderWidth;

  final bool canGoBack;
  final bool canGoForward;
  final bool isLoading;
  final VoidCallback onBack;
  final VoidCallback onForward;
  final VoidCallback onReload;
  final VoidCallback? onMore;
  final VoidCallback? onToggleFullScreen;

  const AppWebViewToolbar({
    super.key,
    required this.canGoBack,
    required this.canGoForward,
    required this.isLoading,
    required this.onBack,
    required this.onForward,
    required this.onReload,
    this.onMore,
    this.onToggleFullScreen,
  });

  @override
  Widget build(BuildContext context) {
    final isDark =
        (CupertinoTheme.of(context).brightness ?? Brightness.light) ==
            Brightness.dark;
    final bgColor = isDark
        ? AppDesignTokens.glassDarkMaterial.withValues(alpha: 0.9)
        : AppDesignTokens.glassLightMaterial.withValues(alpha: 0.9);
    final dividerColor =
        CupertinoColors.separator.resolveFrom(context).withValues(alpha: 0.78);

    return DecoratedBox(
      decoration: BoxDecoration(
        border:
            Border(top: BorderSide(color: dividerColor, width: _dividerHeight)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: height,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            child: AppSquircleSurface(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              backgroundColor: bgColor,
              borderColor: dividerColor,
              radius: AppDesignTokens.radiusCard,
              borderWidth: AppDesignTokens.hairlineBorderWidth,
              blurBackground: true,
              shadows: <BoxShadow>[
                BoxShadow(
                  color:
                      (isDark ? CupertinoColors.black : const Color(0xFF0A2A5E))
                          .withValues(alpha: isDark ? 0.22 : 0.1),
                  offset: const Offset(0, 8),
                  blurRadius: 18,
                  spreadRadius: -12,
                ),
              ],
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _ToolbarIconButton(
                    icon: CupertinoIcons.chevron_back,
                    enabled: canGoBack,
                    onPressed: onBack,
                  ),
                  _ToolbarIconButton(
                    icon: CupertinoIcons.chevron_forward,
                    enabled: canGoForward,
                    onPressed: onForward,
                  ),
                  _ToolbarIconButton(
                    icon: isLoading
                        ? CupertinoIcons.xmark
                        : CupertinoIcons.refresh,
                    enabled: true,
                    onPressed: onReload,
                    isAccent: isLoading,
                  ),
                  if (onToggleFullScreen != null)
                    _ToolbarIconButton(
                      icon: CupertinoIcons.fullscreen,
                      enabled: true,
                      onPressed: onToggleFullScreen!,
                    )
                  else
                    const SizedBox(width: _buttonSize),
                  if (onMore != null)
                    _ToolbarIconButton(
                      icon: CupertinoIcons.ellipsis_circle,
                      enabled: true,
                      onPressed: onMore!,
                    )
                  else
                    const SizedBox(width: _buttonSize),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ToolbarIconButton extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final bool isAccent;
  final VoidCallback onPressed;

  const _ToolbarIconButton({
    required this.icon,
    required this.enabled,
    required this.onPressed,
    this.isAccent = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark =
        (CupertinoTheme.of(context).brightness ?? Brightness.light) ==
            Brightness.dark;
    final iconColor = _resolveIconColor(context, isDark);
    final bgColor = _resolveButtonBackground(isDark, iconColor);
    final borderColor =
        CupertinoColors.separator.resolveFrom(context).withValues(alpha: 0.7);

    return Opacity(
      opacity: enabled ? 1 : 0.42,
      child: SizedBox(
        width: AppWebViewToolbar._buttonSize,
        height: AppWebViewToolbar._buttonSize,
        child: AppSquircleSurface(
          padding: EdgeInsets.zero,
          backgroundColor: bgColor,
          borderColor: borderColor,
          radius: AppDesignTokens.radiusControl,
          borderWidth: AppDesignTokens.hairlineBorderWidth,
          blurBackground: false,
          child: CupertinoButton(
            padding: EdgeInsets.zero,
            minimumSize: const Size(44, 44),
            onPressed: enabled ? () => _onTap(context) : null,
            child: Icon(
              icon,
              size: AppWebViewToolbar._iconSize,
              color: iconColor,
            ),
          ),
        ),
      ),
    );
  }

  Color _resolveIconColor(BuildContext context, bool isDark) {
    if (!enabled) return CupertinoColors.secondaryLabel.resolveFrom(context);
    if (isAccent) return CupertinoTheme.of(context).primaryColor;
    return CupertinoColors.label.resolveFrom(context);
  }

  Color _resolveButtonBackground(bool isDark, Color iconColor) {
    if (!enabled) {
      return isDark
          ? CupertinoColors.white.withValues(alpha: 0.05)
          : CupertinoColors.black.withValues(alpha: 0.02);
    }
    if (isAccent) {
      return iconColor.withValues(alpha: isDark ? 0.22 : 0.14);
    }
    return isDark
        ? CupertinoColors.white.withValues(alpha: 0.08)
        : CupertinoColors.white.withValues(alpha: 0.66);
  }

  void _onTap(BuildContext context) {
    HapticFeedback.lightImpact();
    onPressed();
  }
}
