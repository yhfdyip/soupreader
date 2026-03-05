part of 'app_popover_menu.dart';

class _PopoverSurface extends StatelessWidget {
  final Widget child;
  final Color backgroundColor;
  final Color borderColor;
  final double radius;

  const _PopoverSurface({
    required this.child,
    required this.backgroundColor,
    required this.borderColor,
    required this.radius,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppUiTokens.resolve(context).isDark;
    final shadowColor =
        (isDark ? CupertinoColors.black : const Color(0xFF0B2F66))
            .withValues(alpha: isDark ? 0.3 : 0.14);
    return AppSquircleSurface(
      padding: EdgeInsets.zero,
      backgroundColor: backgroundColor,
      borderColor: borderColor,
      borderWidth: AppDesignTokens.hairlineBorderWidth,
      radius: radius,
      blurBackground: true,
      shadows: <BoxShadow>[
        BoxShadow(
          color: shadowColor,
          blurRadius: 22,
          offset: const Offset(0, 10),
          spreadRadius: -10,
        ),
      ],
      child: child,
    );
  }
}

class _PopoverMenuRow extends StatelessWidget {
  final double height;
  final IconData icon;
  final String label;
  final bool enabled;
  final Color iconColor;
  final Color textColor;
  final VoidCallback? onTap;

  const _PopoverMenuRow({
    required this.height,
    required this.icon,
    required this.label,
    required this.enabled,
    required this.iconColor,
    required this.textColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final uiTokens = AppUiTokens.resolve(context);
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        minimumSize: uiTokens.sizes.compactTapSquare,
        onPressed: onTap,
        child: SizedBox(
          height: height,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Icon(icon, size: 18, color: iconColor),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: textColor,
                      fontFamily: AppTypography.fontFamilySans,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      letterSpacing: -0.2,
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
