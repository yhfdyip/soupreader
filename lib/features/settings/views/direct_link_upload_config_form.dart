import 'package:flutter/cupertino.dart';

import '../../../app/theme/ui_tokens.dart';
import '../../../app/widgets/app_ui_kit.dart';

class DirectLinkUploadConfigForm extends StatelessWidget {
  final TextEditingController uploadUrlController;
  final TextEditingController downloadUrlRuleController;
  final TextEditingController summaryController;
  final bool compress;
  final ValueChanged<bool> onCompressChanged;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;

  const DirectLinkUploadConfigForm({
    super.key,
    required this.uploadUrlController,
    required this.downloadUrlRuleController,
    required this.summaryController,
    required this.compress,
    required this.onCompressChanged,
    required this.onCancel,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AppUiTokens.resolve(context);
    return Column(
      children: [
        Expanded(
          child: AppListView(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            children: [
              _buildRuleCard(tokens),
              const SizedBox(height: 10),
              _buildCompressCard(tokens),
            ],
          ),
        ),
        _buildFooterActions(tokens),
      ],
    );
  }

  Widget _buildRuleCard(AppUiTokens tokens) {
    final borderColor = tokens.colors.separator.withValues(alpha: 0.72);
    return AppCard(
      padding: EdgeInsets.zero,
      borderColor: borderColor,
      child: Column(
        children: [
          _buildTextFieldBlock(
            tokens: tokens,
            label: '上传URL',
            controller: uploadUrlController,
            placeholder: '上传 URL',
          ),
          _buildFormDivider(tokens),
          _buildTextFieldBlock(
            tokens: tokens,
            label: '下载URL规则',
            controller: downloadUrlRuleController,
            placeholder: '下载URL规则(downloadUrls)',
          ),
          _buildFormDivider(tokens),
          _buildTextFieldBlock(
            tokens: tokens,
            label: '注释',
            controller: summaryController,
            placeholder: '注释',
          ),
        ],
      ),
    );
  }

  Widget _buildFormDivider(AppUiTokens tokens) {
    return Container(
      height: tokens.sizes.dividerThickness,
      color: tokens.colors.separator.withValues(alpha: 0.72),
    );
  }

  Widget _buildTextFieldBlock({
    required AppUiTokens tokens,
    required String label,
    required TextEditingController controller,
    required String placeholder,
  }) {
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
            label,
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
              controller: controller,
              placeholder: placeholder,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompressCard(AppUiTokens tokens) {
    final borderColor = tokens.colors.separator.withValues(alpha: 0.72);
    return AppCard(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      borderColor: borderColor,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '是否压缩',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '开启后上传内容会先压缩再发送',
                  style: TextStyle(
                    fontSize: 12,
                    color: tokens.colors.secondaryLabel,
                  ),
                ),
              ],
            ),
          ),
          CupertinoSwitch(
            value: compress,
            onChanged: onCompressChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildFooterActions(AppUiTokens tokens) {
    final borderColor = tokens.colors.separator.withValues(alpha: 0.68);
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: AppCard(
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
        borderColor: borderColor,
        child: Row(
          children: [
            CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              onPressed: onCancel,
              child: const Text('取消'),
            ),
            const Spacer(),
            CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              onPressed: onConfirm,
              child: const Text('确定'),
            ),
          ],
        ),
      ),
    );
  }
}
