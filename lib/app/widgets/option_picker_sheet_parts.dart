part of 'option_picker_sheet.dart';

class _OptionPickerHeader extends StatelessWidget {
  final String title;
  final String? message;
  final Color handleColor;
  final Color titleColor;
  final Color subtitleColor;

  const _OptionPickerHeader({
    required this.title,
    required this.message,
    required this.handleColor,
    required this.titleColor,
    required this.subtitleColor,
  });

  @override
  Widget build(BuildContext context) {
    final trimmedMessage = (message ?? '').trim();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 36,
          height: 4,
          decoration: BoxDecoration(
            color: handleColor,
            borderRadius: BorderRadius.circular(999),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 2),
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: titleColor,
              fontSize: 16,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.24,
            ),
          ),
        ),
        if (trimmedMessage.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Text(
              trimmedMessage,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: subtitleColor,
                fontSize: 12,
                letterSpacing: -0.2,
              ),
            ),
          )
        else
          const SizedBox(height: 8),
      ],
    );
  }
}

class _OptionPickerBody<T> extends StatelessWidget {
  final Widget header;
  final List<OptionPickerItem<T>> items;
  final T? currentValue;
  final Color accent;
  final String cancelText;
  final Color cancelColor;
  final bool showCancel;
  final double maxHeight;
  final ValueChanged<T> onSelect;
  final VoidCallback onCancel;

  const _OptionPickerBody({
    required this.header,
    required this.items,
    required this.currentValue,
    required this.accent,
    required this.cancelText,
    required this.cancelColor,
    required this.showCancel,
    required this.maxHeight,
    required this.onSelect,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final ui = AppUiTokens.resolve(context);
    final borderColor = ui.colors.separator.withValues(alpha: 0.78);
    final cardColor = ui.colors.surfaceBackground.withValues(alpha: 0.9);

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: ListView(
        shrinkWrap: true,
        physics: const BouncingScrollPhysics(),
        children: [
          header,
          _OptionPickerCard(
            color: cardColor,
            borderColor: borderColor,
            radius: ui.radii.card,
            child: AppListSection(
              margin: EdgeInsets.zero,
              hasLeading: false,
              children: [
                for (final item in items)
                  _OptionPickerRow<T>(
                    item: item,
                    selected: item.value == currentValue,
                    accent: accent,
                    onTap: item.enabled ? () => onSelect(item.value) : null,
                  ),
              ],
            ),
          ),
          if (showCancel) ...[
            const SizedBox(height: 10),
            _OptionPickerCard(
              color: cardColor,
              borderColor: borderColor,
              radius: ui.radii.card,
              child: AppListSection(
                margin: EdgeInsets.zero,
                hasLeading: false,
                children: [
                  CupertinoListTile.notched(
                    title: Text(
                      cancelText,
                      style: TextStyle(
                        color: cancelColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    onTap: onCancel,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _OptionPickerCard extends StatelessWidget {
  final Widget child;
  final Color color;
  final Color borderColor;
  final double radius;

  const _OptionPickerCard({
    required this.child,
    required this.color,
    required this.borderColor,
    required this.radius,
  });

  @override
  Widget build(BuildContext context) {
    return AppSquircleSurface(
      padding: EdgeInsets.zero,
      backgroundColor: color,
      borderColor: borderColor,
      borderWidth: AppDesignTokens.hairlineBorderWidth,
      radius: radius,
      blurBackground: true,
      child: child,
    );
  }
}
