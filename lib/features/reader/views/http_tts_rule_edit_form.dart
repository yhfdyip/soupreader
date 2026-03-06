import 'package:flutter/cupertino.dart';

import '../../../app/theme/ui_tokens.dart';
import '../../../app/widgets/app_ui_kit.dart';

class HttpTtsRuleEditForm extends StatelessWidget {
  final TextEditingController nameController;
  final TextEditingController urlController;
  final TextEditingController contentTypeController;
  final TextEditingController concurrentRateController;
  final TextEditingController loginUrlController;
  final TextEditingController loginUiController;
  final TextEditingController loginCheckJsController;
  final TextEditingController headersController;

  const HttpTtsRuleEditForm({
    super.key,
    required this.nameController,
    required this.urlController,
    required this.contentTypeController,
    required this.concurrentRateController,
    required this.loginUrlController,
    required this.loginUiController,
    required this.loginCheckJsController,
    required this.headersController,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AppUiTokens.resolve(context);
    return AppListView(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 20),
      children: [
        _buildSectionTitle(tokens, '基础'),
        _buildFieldCard(tokens, _baseFields),
        const SizedBox(height: 10),
        _buildSectionTitle(tokens, '登录'),
        _buildFieldCard(tokens, _loginFields),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Text(
            '更多菜单中的“登录”会先保存当前输入，再进入登录流程。',
            style: TextStyle(
              fontSize: 12,
              color: tokens.colors.secondaryLabel,
            ),
          ),
        ),
      ],
    );
  }

  List<_HttpTtsFieldSpec> get _baseFields => [
        _HttpTtsFieldSpec(
          label: '名称',
          placeholder: 'name',
          controller: nameController,
        ),
        _HttpTtsFieldSpec(
          label: 'URL',
          placeholder: 'url',
          controller: urlController,
        ),
        _HttpTtsFieldSpec(
          label: 'ContentType',
          placeholder: 'contentType',
          controller: contentTypeController,
        ),
        _HttpTtsFieldSpec(
          label: '并发率',
          placeholder: 'concurrentRate',
          controller: concurrentRateController,
        ),
      ];

  List<_HttpTtsFieldSpec> get _loginFields => [
        _HttpTtsFieldSpec(
          label: '登录 URL',
          placeholder: 'loginUrl',
          controller: loginUrlController,
        ),
        _HttpTtsFieldSpec(
          label: '登录 UI',
          placeholder: 'loginUi',
          controller: loginUiController,
          minLines: 3,
          maxLines: 6,
        ),
        _HttpTtsFieldSpec(
          label: '登录校验 JS',
          placeholder: 'loginCheckJs',
          controller: loginCheckJsController,
          minLines: 2,
          maxLines: 5,
        ),
        _HttpTtsFieldSpec(
          label: '请求头',
          placeholder: 'header(JSON)',
          controller: headersController,
          minLines: 2,
          maxLines: 5,
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

  Widget _buildFieldCard(AppUiTokens tokens, List<_HttpTtsFieldSpec> fields) {
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

  Widget _buildFieldBlock(AppUiTokens tokens, _HttpTtsFieldSpec field) {
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
              color: tokens.colors.secondaryLabel,
              fontSize: 12,
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
              minLines: field.minLines,
              maxLines: field.maxLines,
              clearButtonMode: OverlayVisibilityMode.editing,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              style: const TextStyle(fontSize: 14),
            ),
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
class _HttpTtsFieldSpec {
  final String label;
  final String placeholder;
  final TextEditingController controller;
  final int minLines;
  final int maxLines;

  const _HttpTtsFieldSpec({
    required this.label,
    required this.placeholder,
    required this.controller,
    this.minLines = 1,
    this.maxLines = 1,
  });
}
