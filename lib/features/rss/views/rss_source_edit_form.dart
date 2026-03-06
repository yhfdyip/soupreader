import 'package:flutter/cupertino.dart';

import '../../../app/theme/ui_tokens.dart';
import '../../../app/widgets/app_ui_kit.dart';

@immutable
class RssSourceEditForm extends StatelessWidget {
  final TextEditingController nameController;
  final TextEditingController urlController;
  final TextEditingController groupController;
  final TextEditingController commentController;
  final TextEditingController loginUrlController;
  final TextEditingController sortUrlController;
  final TextEditingController customOrderController;
  final bool enabled;
  final bool singleUrl;
  final ValueChanged<bool> onEnabledChanged;
  final ValueChanged<bool> onSingleUrlChanged;

  const RssSourceEditForm({
    super.key,
    required this.nameController,
    required this.urlController,
    required this.groupController,
    required this.commentController,
    required this.loginUrlController,
    required this.sortUrlController,
    required this.customOrderController,
    required this.enabled,
    required this.singleUrl,
    required this.onEnabledChanged,
    required this.onSingleUrlChanged,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AppUiTokens.resolve(context);
    return AppListView(
      padding: const EdgeInsets.only(top: 12, bottom: 24),
      children: [
        _buildSectionTitle(tokens, '基本信息'),
        _buildTextFieldCard(tokens, _basicFields),
        const SizedBox(height: 10),
        _buildSectionTitle(tokens, '规则与状态'),
        _buildTextFieldCard(tokens, _ruleFields),
        const SizedBox(height: 10),
        _buildSwitchCard(tokens),
      ],
    );
  }

  List<_RssSourceFieldSpec> get _basicFields => [
        _RssSourceFieldSpec(
          label: '名称',
          placeholder: '源名称',
          controller: nameController,
          textInputAction: TextInputAction.next,
        ),
        _RssSourceFieldSpec(
          label: 'URL',
          placeholder: 'https://example.com/rss',
          controller: urlController,
          textInputAction: TextInputAction.next,
          keyboardType: TextInputType.url,
          autocorrect: false,
        ),
        _RssSourceFieldSpec(
          label: '分组',
          placeholder: '分组A,分组B',
          controller: groupController,
          textInputAction: TextInputAction.next,
        ),
        _RssSourceFieldSpec(
          label: '注释',
          placeholder: '注释',
          controller: commentController,
          textInputAction: TextInputAction.next,
        ),
      ];

  List<_RssSourceFieldSpec> get _ruleFields => [
        _RssSourceFieldSpec(
          label: '登录',
          placeholder: '登录地址（可选）',
          controller: loginUrlController,
          textInputAction: TextInputAction.next,
          keyboardType: TextInputType.url,
          autocorrect: false,
        ),
        _RssSourceFieldSpec(
          label: '分类',
          placeholder: '分类地址/脚本（可选）',
          controller: sortUrlController,
          textInputAction: TextInputAction.next,
        ),
        _RssSourceFieldSpec(
          label: '排序',
          placeholder: '0',
          controller: customOrderController,
          textInputAction: TextInputAction.done,
          keyboardType: const TextInputType.numberWithOptions(
            signed: true,
            decimal: false,
          ),
        ),
      ];

  Widget _buildSectionTitle(AppUiTokens tokens, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          color: tokens.colors.secondaryLabel,
        ),
      ),
    );
  }

  Widget _buildTextFieldCard(
    AppUiTokens tokens,
    List<_RssSourceFieldSpec> fields,
  ) {
    final borderColor = tokens.colors.separator.withValues(alpha: 0.72);
    return AppCard(
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
    );
  }

  Widget _buildFieldBlock(AppUiTokens tokens, _RssSourceFieldSpec field) {
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
              textInputAction: field.textInputAction,
              keyboardType: field.keyboardType,
              autocorrect: field.autocorrect,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchCard(AppUiTokens tokens) {
    final borderColor = tokens.colors.separator.withValues(alpha: 0.72);
    return AppCard(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      borderColor: borderColor,
      child: Column(
        children: [
          _buildSwitchRow(
            tokens: tokens,
            label: '启用',
            value: enabled,
            onChanged: onEnabledChanged,
          ),
          _buildDivider(tokens),
          _buildSwitchRow(
            tokens: tokens,
            label: 'singleUrl',
            value: singleUrl,
            onChanged: onSingleUrlChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchRow({
    required AppUiTokens tokens,
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SizedBox(
      height: 42,
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          CupertinoSwitch(
            value: value,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildDivider(AppUiTokens tokens) {
    return Container(
      height: tokens.sizes.dividerThickness,
      color: tokens.colors.separator.withValues(alpha: 0.72),
    );
  }
}

@immutable
class _RssSourceFieldSpec {
  final String label;
  final String placeholder;
  final TextEditingController controller;
  final TextInputAction textInputAction;
  final TextInputType? keyboardType;
  final bool autocorrect;

  const _RssSourceFieldSpec({
    required this.label,
    required this.placeholder,
    required this.controller,
    required this.textInputAction,
    this.keyboardType,
    this.autocorrect = true,
  });
}
