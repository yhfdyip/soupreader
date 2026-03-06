part of 'option_picker_sheet.dart';

class _OptionPickerRow<T> extends StatelessWidget {
  final OptionPickerItem<T> item;
  final bool selected;
  final Color accent;
  final VoidCallback? onTap;

  const _OptionPickerRow({
    required this.item,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final ui = AppUiTokens.resolve(context);
    final labelColor =
        item.enabled ? ui.colors.label : ui.colors.secondaryLabel;
    final subtitleColor = ui.colors.secondaryLabel;
    final titleStyle = TextStyle(
      color: labelColor,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.2,
    );
    final subtitle = (item.subtitle ?? '').trim();

    return CupertinoListTile.notched(
      title: Row(
        children: [
          Expanded(
            child: Text(
              item.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: titleStyle,
            ),
          ),
          if (item.isRecommended)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: accent.withValues(alpha: 0.28),
                    width: AppDesignTokens.hairlineBorderWidth,
                  ),
                ),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  child: Text(
                    '推荐',
                    style: TextStyle(
                      color: accent,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      subtitle: subtitle.isEmpty
          ? null
          : Text(
              subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: subtitleColor,
                fontSize: 12,
                letterSpacing: -0.2,
              ),
            ),
      trailing: selected
          ? Icon(
              CupertinoIcons.check_mark,
              size: ui.iconSizes.listTrailing,
              color: accent,
            )
          : null,
      onTap: onTap,
    );
  }
}
