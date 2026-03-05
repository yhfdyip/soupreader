part of 'app_popover_menu.dart';

class _PopoverSurface extends StatelessWidget {
  static const double _kAmbientTopAlpha = 0.2;
  static const double _kAmbientBottomAlpha = 0.16;
  static const double _kBezelAlpha = 0.5;

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
    final uiTokens = AppUiTokens.resolve(context);
    final isDark = uiTokens.isDark;
    final shadowColor =
        (isDark ? CupertinoColors.black : const Color(0xFF0B2F66))
            .withValues(alpha: isDark ? 0.3 : 0.14);
    final bezelColor = (isDark
            ? AppDesignTokens.glassInnerHighlightDark
            : AppDesignTokens.glassInnerHighlightLight)
        .withValues(alpha: _kBezelAlpha);
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
      child: Stack(
        children: [
          Positioned.fill(child: _buildAmbientLayer(isDark)),
          Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              height: AppDesignTokens.hairlineBorderWidth,
              child: ColoredBox(color: bezelColor),
            ),
          ),
          child,
        ],
      ),
    );
  }

  Widget _buildAmbientLayer(bool isDark) {
    final topColor = (isDark
            ? AppDesignTokens.ambientTopDark
            : AppDesignTokens.ambientTopLight)
        .withValues(alpha: _kAmbientTopAlpha);
    final bottomColor = (isDark
            ? AppDesignTokens.ambientBottomDark
            : AppDesignTokens.ambientBottomLight)
        .withValues(alpha: _kAmbientBottomAlpha);
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [topColor, bottomColor, const Color(0x00000000)],
            stops: const [0.0, 0.64, 1.0],
          ),
        ),
      ),
    );
  }
}

class _PopoverMenuRow extends StatelessWidget {
  static const double _kIconLeadingInset = 40;

  final double height;
  final IconData icon;
  final String label;
  final bool enabled;
  final bool showDivider;
  final Color dividerColor;
  final Color iconColor;
  final Color textColor;
  final VoidCallback? onTap;

  const _PopoverMenuRow({
    required this.height,
    required this.icon,
    required this.label,
    required this.enabled,
    required this.showDivider,
    required this.dividerColor,
    required this.iconColor,
    required this.textColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final uiTokens = AppUiTokens.resolve(context);
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CupertinoButton(
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
          if (showDivider)
            Padding(
              padding:
                  const EdgeInsetsDirectional.only(start: _kIconLeadingInset),
              child: SizedBox(
                height: AppDesignTokens.hairlineBorderWidth,
                child: ColoredBox(color: dividerColor),
              ),
            ),
        ],
      ),
    );
  }
}
