import 'package:flutter/cupertino.dart';

import '../../../app/widgets/app_ui_kit.dart';

class SourceEditLegacyFieldSpec {
  const SourceEditLegacyFieldSpec({
    required this.key,
    required this.controller,
    this.maxLines = 1,
  });

  final String key;
  final TextEditingController controller;
  final int maxLines;
}

class SourceEditLegacyRuleTabSection extends StatelessWidget {
  const SourceEditLegacyRuleTabSection({
    super.key,
    required this.title,
    required this.fields,
    required this.activeFieldController,
    required this.labelBuilder,
    required this.onFieldActivated,
    required this.onShowInsertActions,
  });

  final String title;
  final List<SourceEditLegacyFieldSpec> fields;
  final TextEditingController? activeFieldController;
  final String Function(String key) labelBuilder;
  final void Function(String key, TextEditingController controller)
      onFieldActivated;
  final VoidCallback onShowInsertActions;

  @override
  Widget build(BuildContext context) {
    return AppListView(
      children: [
        AppListSection(
          header: Text(title),
          children: fields
              .map(
                (field) => _FieldTile(
                  field: field,
                  isActive: identical(activeFieldController, field.controller),
                  labelBuilder: labelBuilder,
                  onFieldActivated: onFieldActivated,
                  onShowInsertActions: onShowInsertActions,
                ),
              )
              .toList(growable: false),
        ),
      ],
    );
  }
}

class _FieldTile extends StatelessWidget {
  const _FieldTile({
    required this.field,
    required this.isActive,
    required this.labelBuilder,
    required this.onFieldActivated,
    required this.onShowInsertActions,
  });

  final SourceEditLegacyFieldSpec field;
  final bool isActive;
  final String Function(String key) labelBuilder;
  final void Function(String key, TextEditingController controller)
      onFieldActivated;
  final VoidCallback onShowInsertActions;

  @override
  Widget build(BuildContext context) {
    final titleStyle = CupertinoTheme.of(
      context,
    ).textTheme.textStyle.copyWith(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        );
    return AppListTile(
      title: Text(labelBuilder(field.key), style: titleStyle),
      subtitle: _FieldInput(
        field: field,
        onFieldActivated: onFieldActivated,
      ),
      trailing: isActive
          ? CupertinoButton(
              padding: EdgeInsets.zero,
              minimumSize: const Size(36, 36),
              onPressed: () {
                onFieldActivated(field.key, field.controller);
                onShowInsertActions();
              },
              child: const Icon(CupertinoIcons.wand_stars, size: 18),
            )
          : null,
      showChevron: false,
    );
  }
}

class _FieldInput extends StatelessWidget {
  const _FieldInput({
    required this.field,
    required this.onFieldActivated,
  });

  final SourceEditLegacyFieldSpec field;
  final void Function(String key, TextEditingController controller)
      onFieldActivated;

  @override
  Widget build(BuildContext context) {
    final textStyle = CupertinoTheme.of(context).textTheme.textStyle;
    final borderColor = CupertinoColors.separator.resolveFrom(context);
    final fieldColor = CupertinoColors.systemGrey6.resolveFrom(context);
    final placeholderColor = CupertinoColors.tertiaryLabel.resolveFrom(context);
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: CupertinoTextField(
        controller: field.controller,
        maxLines: field.maxLines,
        minLines: field.maxLines > 1 ? 2 : 1,
        placeholder: field.key,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: fieldColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: borderColor.withValues(alpha: 0.65),
            width: 0.6,
          ),
        ),
        style: textStyle.copyWith(fontSize: 14),
        placeholderStyle: textStyle.copyWith(
          fontSize: 13,
          color: placeholderColor,
        ),
        onTap: () => onFieldActivated(field.key, field.controller),
        onChanged: (_) => onFieldActivated(field.key, field.controller),
      ),
    );
  }
}
