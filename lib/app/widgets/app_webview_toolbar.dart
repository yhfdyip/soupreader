import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../theme/design_tokens.dart';

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
    final dividerColor =
        CupertinoColors.separator.resolveFrom(context).withValues(alpha: 0.78);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: CupertinoTheme.of(context).barBackgroundColor,
        border:
            Border(top: BorderSide(color: dividerColor, width: _dividerHeight)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: height,
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
    final iconColor = _resolveIconColor(context);
    return Opacity(
      opacity: enabled ? 1 : 0.42,
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        minimumSize: const Size(
          AppWebViewToolbar._buttonSize,
          AppWebViewToolbar._buttonSize,
        ),
        onPressed: enabled ? () => _onTap(context) : null,
        child: Icon(
          icon,
          size: AppWebViewToolbar._iconSize,
          color: iconColor,
        ),
      ),
    );
  }

  Color _resolveIconColor(BuildContext context) {
    if (!enabled) return CupertinoColors.secondaryLabel.resolveFrom(context);
    if (isAccent) return CupertinoTheme.of(context).primaryColor;
    return CupertinoColors.label.resolveFrom(context);
  }

  void _onTap(BuildContext context) {
    HapticFeedback.lightImpact();
    onPressed();
  }
}
