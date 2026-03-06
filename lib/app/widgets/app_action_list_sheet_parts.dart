part of 'app_action_list_sheet.dart';

class _SheetHandle extends StatelessWidget {
  final Color color;

  const _SheetHandle({
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 5,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }
}

class _SheetCard extends StatelessWidget {
  final Widget child;
  final Color backgroundColor;
  final Color borderColor;
  final double radius;

  const _SheetCard({
    required this.child,
    required this.backgroundColor,
    required this.borderColor,
    required this.radius,
  });

  @override
  Widget build(BuildContext context) {
    return AppSquircleSurface(
      padding: EdgeInsets.zero,
      backgroundColor: backgroundColor,
      borderColor: borderColor,
      borderWidth: AppDesignTokens.hairlineBorderWidth,
      radius: radius,
      blurBackground: true,
      child: child,
    );
  }
}

class _SheetHeader extends StatelessWidget {
  final String title;
  final String message;
  final TextAlign titleAlign;
  final Color titleColor;
  final Color messageColor;

  const _SheetHeader({
    required this.title,
    required this.message,
    required this.titleAlign,
    required this.titleColor,
    required this.messageColor,
  });

  @override
  Widget build(BuildContext context) {
    final resolvedAlign = switch (titleAlign) {
      TextAlign.left => CrossAxisAlignment.start,
      TextAlign.right => CrossAxisAlignment.end,
      _ => CrossAxisAlignment.center,
    };

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: resolvedAlign,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 2),
          child: Text(
            title,
            textAlign: titleAlign,
            style: TextStyle(
              color: titleColor,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        if (message.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
            child: Text(
              message,
              textAlign: titleAlign,
              style: TextStyle(
                color: messageColor,
                                fontSize: 13,
                height: 1.3,
              ),
            ),
          )
        else
          const SizedBox(height: 8),
      ],
    );
  }
}

class _ActionRow<T> extends StatelessWidget {
  final double height;
  final AppActionListItem<T> item;
  final Color accent;
  final Color labelColor;
  final Color destructiveColor;
  final ValueChanged<T> onSelected;

  const _ActionRow({
    required this.height,
    required this.item,
    required this.accent,
    required this.labelColor,
    required this.destructiveColor,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final ui = AppUiTokens.resolve(context);
    final enabled = item.enabled;
    final textColor = item.isDestructiveAction ? destructiveColor : labelColor;
    final iconColor = item.isDestructiveAction ? destructiveColor : accent;

    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        minimumSize: ui.sizes.compactTapSquare,
        onPressed: enabled ? () => onSelected(item.value) : null,
        child: SizedBox(
          height: height,
          width: double.infinity,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Icon(item.icon, size: 18, color: iconColor),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    item.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: textColor,
                                            fontWeight: FontWeight.w600,
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

class _CancelRow extends StatelessWidget {
  final double height;
  final String label;
  final Color labelColor;
  final VoidCallback onTap;

  const _CancelRow({
    required this.height,
    required this.label,
    required this.labelColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final ui = AppUiTokens.resolve(context);
    return CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: ui.sizes.compactTapSquare,
      onPressed: onTap,
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: labelColor,
                            fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
