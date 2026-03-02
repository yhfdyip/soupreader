import 'package:flutter/cupertino.dart';

import '../theme/ui_tokens.dart';

class AppManageSearchField extends StatelessWidget {
  static const EdgeInsets outerPadding = EdgeInsets.fromLTRB(12, 8, 12, 10);
  static const double height = 36;

  final TextEditingController controller;
  final String placeholder;
  final ValueChanged<String>? onChanged;

  const AppManageSearchField({
    super.key,
    required this.controller,
    required this.placeholder,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final ui = AppUiTokens.resolve(context);
    final baseStyle = CupertinoTheme.of(context).textTheme.textStyle;
    return SizedBox(
      height: height,
      child: CupertinoSearchTextField(
        controller: controller,
        placeholder: placeholder,
        onChanged: onChanged,
        itemColor: ui.colors.secondaryLabel,
        style: baseStyle.copyWith(
          fontSize: 14,
          color: ui.colors.label,
        ),
        placeholderStyle: baseStyle.copyWith(
          fontSize: 14,
          color: ui.colors.secondaryLabel,
        ),
      ),
    );
  }
}
