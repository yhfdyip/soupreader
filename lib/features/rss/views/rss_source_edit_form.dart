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
  final TextEditingController loginUiController;
  final TextEditingController loginCheckJsController;
  final TextEditingController coverDecodeJsController;
  final TextEditingController sortUrlController;
  final TextEditingController customOrderController;
  final TextEditingController headerController;
  final TextEditingController variableCommentController;
  final TextEditingController concurrentRateController;
  final TextEditingController jsLibController;
  final bool enabled;
  final bool singleUrl;
  final bool enabledCookieJar;
  final ValueChanged<bool> onEnabledChanged;
  final ValueChanged<bool> onSingleUrlChanged;
  final ValueChanged<bool> onEnabledCookieJarChanged;

  const RssSourceEditForm({
    super.key,
    required this.nameController,
    required this.urlController,
    required this.groupController,
    required this.commentController,
    required this.loginUrlController,
    required this.loginUiController,
    required this.loginCheckJsController,
    required this.coverDecodeJsController,
    required this.sortUrlController,
    required this.customOrderController,
    required this.headerController,
    required this.variableCommentController,
    required this.concurrentRateController,
    required this.jsLibController,
    required this.enabled,
    required this.singleUrl,
    required this.enabledCookieJar,
    required this.onEnabledChanged,
    required this.onSingleUrlChanged,
    required this.onEnabledCookieJarChanged,
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
          label: '登录地址',
          placeholder: 'loginUrl',
          controller: loginUrlController,
          textInputAction: TextInputAction.next,
          keyboardType: TextInputType.url,
          autocorrect: false,
        ),
        _RssSourceFieldSpec(
          label: '登录UI',
          placeholder: 'loginUi（JSON）',
          controller: loginUiController,
          textInputAction: TextInputAction.next,
        ),
        _RssSourceFieldSpec(
          label: '登录校验JS',
          placeholder: 'loginCheckJs',
          controller: loginCheckJsController,
          textInputAction: TextInputAction.next,
        ),
        _RssSourceFieldSpec(
          label: '封面解码JS',
          placeholder: 'coverDecodeJs',
          controller: coverDecodeJsController,
          textInputAction: TextInputAction.next,
        ),
        _RssSourceFieldSpec(
          label: '分类',
          placeholder: '分类地址/脚本（可选）',
          controller: sortUrlController,
          textInputAction: TextInputAction.next,
        ),
        _RssSourceFieldSpec(
          label: 'Header',
          placeholder: 'header（JSON）',
          controller: headerController,
          textInputAction: TextInputAction.next,
        ),
        _RssSourceFieldSpec(
          label: '变量注释',
          placeholder: 'variableComment',
          controller: variableCommentController,
          textInputAction: TextInputAction.next,
        ),
        _RssSourceFieldSpec(
          label: '并发率',
          placeholder: 'concurrentRate',
          controller: concurrentRateController,
          textInputAction: TextInputAction.next,
        ),
        _RssSourceFieldSpec(
          label: 'JS库',
          placeholder: 'jsLib',
          controller: jsLibController,
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
          _buildDivider(tokens),
          _buildSwitchRow(
            tokens: tokens,
            label: '自动保存Cookie',
            value: enabledCookieJar,
            onChanged: onEnabledCookieJarChanged,
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

/// 包含3个Tab的RSS源编辑页面（对齐legado3-Tab结构：源设置/列表规则/WebView）
class RssSourceEditTabs extends StatefulWidget {
  const RssSourceEditTabs({
    required this.nameController,
    required this.urlController,
    required this.groupController,
    required this.commentController,
    required this.loginUrlController,
    required this.loginUiController,
    required this.loginCheckJsController,
    required this.coverDecodeJsController,
    required this.sortUrlController,
    required this.customOrderController,
    required this.headerController,
    required this.variableCommentController,
    required this.concurrentRateController,
    required this.jsLibController,
    required this.ruleArticlesController,
    required this.ruleNextPageController,
    required this.ruleTitleController,
    required this.rulePubDateController,
    required this.ruleDescriptionController,
    required this.ruleImageController,
    required this.ruleLinkController,
    required this.ruleContentController,
    required this.injectJsController,
    required this.contentWhitelistController,
    required this.contentBlacklistController,
    required this.shouldOverrideUrlLoadingController,
    required this.enabled,
    required this.singleUrl,
    required this.enabledCookieJar,
    required this.enableJs,
    required this.loadWithBaseUrl,
    required this.onEnabledChanged,
    required this.onSingleUrlChanged,
    required this.onEnabledCookieJarChanged,
    required this.onEnableJsChanged,
    required this.onLoadWithBaseUrlChanged,
  });

  final TextEditingController nameController;
  final TextEditingController urlController;
  final TextEditingController groupController;
  final TextEditingController commentController;
  final TextEditingController loginUrlController;
  final TextEditingController loginUiController;
  final TextEditingController loginCheckJsController;
  final TextEditingController coverDecodeJsController;
  final TextEditingController sortUrlController;
  final TextEditingController customOrderController;
  final TextEditingController headerController;
  final TextEditingController variableCommentController;
  final TextEditingController concurrentRateController;
  final TextEditingController jsLibController;
  final TextEditingController ruleArticlesController;
  final TextEditingController ruleNextPageController;
  final TextEditingController ruleTitleController;
  final TextEditingController rulePubDateController;
  final TextEditingController ruleDescriptionController;
  final TextEditingController ruleImageController;
  final TextEditingController ruleLinkController;
  final TextEditingController ruleContentController;
  final TextEditingController injectJsController;
  final TextEditingController contentWhitelistController;
  final TextEditingController contentBlacklistController;
  final TextEditingController shouldOverrideUrlLoadingController;
  final bool enabled;
  final bool singleUrl;
  final bool enabledCookieJar;
  final bool enableJs;
  final bool loadWithBaseUrl;
  final ValueChanged<bool> onEnabledChanged;
  final ValueChanged<bool> onSingleUrlChanged;
  final ValueChanged<bool> onEnabledCookieJarChanged;
  final ValueChanged<bool> onEnableJsChanged;
  final ValueChanged<bool> onLoadWithBaseUrlChanged;

  @override
  State<RssSourceEditTabs> createState() => _RssSourceEditTabsState();
}

class _RssSourceEditTabsState extends State<RssSourceEditTabs> {
  int _tabIndex = 0;

  @override
  Widget build(BuildContext context) {
    final tokens = AppUiTokens.resolve(context);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
          child: CupertinoSlidingSegmentedControl<int>(
            groupValue: _tabIndex,
            children: const {
              0: Padding(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Text('源设置'),
              ),
              1: Padding(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Text('列表规则'),
              ),
              2: Padding(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Text('WebView'),
              ),
            },
            onValueChanged: (v) {
              if (v != null) setState(() => _tabIndex = v);
            },
          ),
        ),
        Expanded(
          child: IndexedStack(
            index: _tabIndex,
            children: [
              // Tab 0: 源设置
              RssSourceEditForm(
                nameController: widget.nameController,
                urlController: widget.urlController,
                groupController: widget.groupController,
                commentController: widget.commentController,
                loginUrlController: widget.loginUrlController,
                loginUiController: widget.loginUiController,
                loginCheckJsController: widget.loginCheckJsController,
                coverDecodeJsController: widget.coverDecodeJsController,
                sortUrlController: widget.sortUrlController,
                customOrderController: widget.customOrderController,
                headerController: widget.headerController,
                variableCommentController: widget.variableCommentController,
                concurrentRateController: widget.concurrentRateController,
                jsLibController: widget.jsLibController,
                enabled: widget.enabled,
                singleUrl: widget.singleUrl,
                enabledCookieJar: widget.enabledCookieJar,
                onEnabledChanged: widget.onEnabledChanged,
                onSingleUrlChanged: widget.onSingleUrlChanged,
                onEnabledCookieJarChanged: widget.onEnabledCookieJarChanged,
              ),
              // Tab 1: 列表规则
              _RssListRulesForm(
                tokens: tokens,
                ruleArticlesController: widget.ruleArticlesController,
                ruleNextPageController: widget.ruleNextPageController,
                ruleTitleController: widget.ruleTitleController,
                rulePubDateController: widget.rulePubDateController,
                ruleDescriptionController: widget.ruleDescriptionController,
                ruleImageController: widget.ruleImageController,
                ruleLinkController: widget.ruleLinkController,
              ),
              // Tab 2: WebView
              _RssWebViewRulesForm(
                tokens: tokens,
                ruleContentController: widget.ruleContentController,
                injectJsController: widget.injectJsController,
                contentWhitelistController: widget.contentWhitelistController,
                contentBlacklistController: widget.contentBlacklistController,
                shouldOverrideUrlLoadingController:
                    widget.shouldOverrideUrlLoadingController,
                enableJs: widget.enableJs,
                loadWithBaseUrl: widget.loadWithBaseUrl,
                onEnableJsChanged: widget.onEnableJsChanged,
                onLoadWithBaseUrlChanged: widget.onLoadWithBaseUrlChanged,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RssListRulesForm extends StatelessWidget {
  const _RssListRulesForm({
    required this.tokens,
    required this.ruleArticlesController,
    required this.ruleNextPageController,
    required this.ruleTitleController,
    required this.rulePubDateController,
    required this.ruleDescriptionController,
    required this.ruleImageController,
    required this.ruleLinkController,
  });

  final AppUiTokens tokens;
  final TextEditingController ruleArticlesController;
  final TextEditingController ruleNextPageController;
  final TextEditingController ruleTitleController;
  final TextEditingController rulePubDateController;
  final TextEditingController ruleDescriptionController;
  final TextEditingController ruleImageController;
  final TextEditingController ruleLinkController;

  @override
  Widget build(BuildContext context) {
    final borderColor = tokens.colors.separator.withValues(alpha: 0.72);
    final fieldBackground = tokens.colors.surfaceBackground.withValues(
      alpha: tokens.isDark ? 0.72 : 0.94,
    );
    final fields = [
      ('ruleArticles', '文章列表规则', ruleArticlesController),
      ('ruleNextPage', '下一页规则', ruleNextPageController),
      ('ruleTitle', '标题规则', ruleTitleController),
      ('rulePubDate', '发布日期规则', rulePubDateController),
      ('ruleDescription', '摘要规则', ruleDescriptionController),
      ('ruleImage', '图片规则', ruleImageController),
      ('ruleLink', '链接规则', ruleLinkController),
    ];
    return AppListView(
      padding: const EdgeInsets.only(top: 12, bottom: 24),
      children: [
        AppCard(
          padding: EdgeInsets.zero,
          borderColor: borderColor,
          child: Column(
            children: [
              for (var i = 0; i < fields.length; i++) ...
                [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          fields[i].$1,
                          style: TextStyle(
                            fontSize: 12,
                            color: tokens.colors.secondaryLabel,
                          ),
                        ),
                        const SizedBox(height: 6),
                        DecoratedBox(
                          decoration: BoxDecoration(
                            color: fieldBackground,
                            borderRadius:
                                BorderRadius.circular(tokens.radii.control),
                            border: Border.all(
                              color: borderColor,
                              width: tokens.sizes.dividerThickness,
                            ),
                          ),
                          child: CupertinoTextField.borderless(
                            controller: fields[i].$3,
                            placeholder: fields[i].$2,
                            maxLines: 3,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 8),
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (i < fields.length - 1)
                    Container(
                      height: tokens.sizes.dividerThickness,
                      color: borderColor,
                    ),
                ],
            ],
          ),
        ),
      ],
    );
  }
}

class _RssWebViewRulesForm extends StatelessWidget {
  const _RssWebViewRulesForm({
    required this.tokens,
    required this.ruleContentController,
    required this.injectJsController,
    required this.contentWhitelistController,
    required this.contentBlacklistController,
    required this.shouldOverrideUrlLoadingController,
    required this.enableJs,
    required this.loadWithBaseUrl,
    required this.onEnableJsChanged,
    required this.onLoadWithBaseUrlChanged,
  });

  final AppUiTokens tokens;
  final TextEditingController ruleContentController;
  final TextEditingController injectJsController;
  final TextEditingController contentWhitelistController;
  final TextEditingController contentBlacklistController;
  final TextEditingController shouldOverrideUrlLoadingController;
  final bool enableJs;
  final bool loadWithBaseUrl;
  final ValueChanged<bool> onEnableJsChanged;
  final ValueChanged<bool> onLoadWithBaseUrlChanged;

  @override
  Widget build(BuildContext context) {
    final borderColor = tokens.colors.separator.withValues(alpha: 0.72);
    final fieldBackground = tokens.colors.surfaceBackground.withValues(
      alpha: tokens.isDark ? 0.72 : 0.94,
    );
    final fields = [
      ('ruleContent', '内容规则', ruleContentController),
      ('injectJs', '注入JS', injectJsController),
      ('contentWhitelist', '内容白名单', contentWhitelistController),
      ('contentBlacklist', '内容黑名单', contentBlacklistController),
      ('shouldOverrideUrlLoading', 'URL拦截规则',
          shouldOverrideUrlLoadingController),
    ];
    return AppListView(
      padding: const EdgeInsets.only(top: 12, bottom: 24),
      children: [
        AppCard(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
          borderColor: borderColor,
          child: Column(
            children: [
              AppListTile(
                title: const Text('启用JS'),
                trailing: CupertinoSwitch(
                  value: enableJs,
                  onChanged: onEnableJsChanged,
                ),
              ),
              Container(height: tokens.sizes.dividerThickness, color: borderColor),
              AppListTile(
                title: const Text('loadWithBaseUrl'),
                trailing: CupertinoSwitch(
                  value: loadWithBaseUrl,
                  onChanged: onLoadWithBaseUrlChanged,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        AppCard(
          padding: EdgeInsets.zero,
          borderColor: borderColor,
          child: Column(
            children: [
              for (var i = 0; i < fields.length; i++) ...
                [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          fields[i].$1,
                          style: TextStyle(
                            fontSize: 12,
                            color: tokens.colors.secondaryLabel,
                          ),
                        ),
                        const SizedBox(height: 6),
                        DecoratedBox(
                          decoration: BoxDecoration(
                            color: fieldBackground,
                            borderRadius:
                                BorderRadius.circular(tokens.radii.control),
                            border: Border.all(
                              color: borderColor,
                              width: tokens.sizes.dividerThickness,
                            ),
                          ),
                          child: CupertinoTextField.borderless(
                            controller: fields[i].$3,
                            placeholder: fields[i].$2,
                            maxLines: 3,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 8),
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (i < fields.length - 1)
                    Container(
                      height: tokens.sizes.dividerThickness,
                      color: borderColor,
                    ),
                ],
            ],
          ),
        ),
      ],
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
