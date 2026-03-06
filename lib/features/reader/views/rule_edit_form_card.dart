import 'package:flutter/cupertino.dart';

import '../../../app/theme/ui_tokens.dart';
import '../../../app/widgets/app_ui_kit.dart';

@immutable
class RuleEditFieldSpec {
  final String label;
  final String placeholder;
  final TextEditingController controller;

  const RuleEditFieldSpec({
    required this.label,
    required this.placeholder,
    required this.controller,
  });
}

class RuleEditFormCard extends StatelessWidget {
  final String sectionTitle;
  final List<RuleEditFieldSpec> fields;

  const RuleEditFormCard({
    super.key,
    required this.sectionTitle,
    required this.fields,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AppUiTokens.resolve(context);
    final borderColor = tokens.colors.separator.withValues(alpha: 0.72);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
          child: Text(
            sectionTitle,
            style: TextStyle(
              fontSize: 12,
              color: tokens.colors.secondaryLabel,
            ),
          ),
        ),
        AppCard(
          padding: EdgeInsets.zero,
          borderColor: borderColor,
          child: Column(
            children: [
              for (var index = 0; index < fields.length; index++) ...[
                _buildFieldBlock(tokens, fields[index]),
                if (index < fields.length - 1) _buildDivider(tokens),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDivider(AppUiTokens tokens) {
    return Container(
      height: tokens.sizes.dividerThickness,
      color: tokens.colors.separator.withValues(alpha: 0.72),
    );
  }

  Widget _buildFieldBlock(AppUiTokens tokens, RuleEditFieldSpec field) {
    final borderColor = tokens.colors.separator.withValues(alpha: 0.72);
    final fieldBackground = tokens.colors.surfaceBackground.withValues(
      alpha: tokens.isDark ? 0.72 : 0.94,
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            field.label,
            style: TextStyle(
              fontSize: 12,
              color: tokens.colors.secondaryLabel,
            ),
          ),
          const SizedBox(height: 6),
          DecoratedBox(
            decoration: BoxDecoration(
              color: fieldBackground,
              borderRadius: BorderRadius.circular(tokens.radii.control),
              border: Border.all(
                color: borderColor,
                width: tokens.sizes.dividerThickness,
              ),
            ),
            child: CupertinoTextField.borderless(
              controller: field.controller,
              placeholder: field.placeholder,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}
