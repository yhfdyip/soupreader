part of 'speak_engine_manage_view.dart';

extension _SpeakEngineManageUi on _SpeakEngineManageViewState {
  Widget _buildManageBody() {
    if (_loading) {
      return const Center(child: CupertinoActivityIndicator());
    }
    final tokens = AppUiTokens.resolve(context);
    return AppListView(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 20),
      children: [
        _buildSectionHeader(tokens, '系统引擎'),
        AppCard(
          padding: EdgeInsets.zero,
          borderColor: tokens.colors.separator.withValues(alpha: 0.72),
          child: const AppListTile(
            title: Text('系统默认'),
            subtitle: Text('跟随设备 TTS 设置'),
            showChevron: false,
          ),
        ),
        if (_rules.isEmpty)
          const Padding(
            padding: EdgeInsets.fromLTRB(4, 10, 4, 0),
            child: AppEmptyState(
              illustration: AppEmptyPlanetIllustration(size: 86),
              title: '暂无规则',
              message: '点击右上角添加，或从更多菜单导入默认规则。',
            ),
          )
        else
          _buildRuleSection(tokens),
      ],
    );
  }

  Widget _buildRuleSection(AppUiTokens tokens) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 10),
        _buildSectionHeader(tokens, 'HTTP 朗读引擎'),
        AppCard(
          padding: EdgeInsets.zero,
          borderColor: tokens.colors.separator.withValues(alpha: 0.72),
          child: Column(
            children: [
              for (var i = 0; i < _rules.length; i++) ...[
                _buildRuleTile(_rules[i]),
                if (i < _rules.length - 1) _buildDivider(tokens),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRuleTile(HttpTtsRule rule) {
    final fallbackTitle = rule.url.trim().isEmpty ? '未命名引擎' : rule.url.trim();
    final title = rule.name.trim().isEmpty ? fallbackTitle : rule.name.trim();
    final subtitle = rule.url.trim().isEmpty ? '未配置 URL' : rule.url.trim();
    return AppListTile(
      title: Text(title),
      subtitle: Text(
        subtitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      additionalInfo: rule.isDefaultRule ? const Text('默认') : null,
      onTap: () => _openRuleEditor(rule),
    );
  }

  Widget _buildSectionHeader(AppUiTokens tokens, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 6),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          color: tokens.colors.secondaryLabel,
        ),
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

class _ImportCandidateTile extends StatelessWidget {
  const _ImportCandidateTile({
    required this.candidate,
    required this.selected,
    required this.onTap,
  });

  final HttpTtsImportCandidate candidate;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final stateLabel = _stateLabel(candidate.state);
    final stateColor = _stateColor(context, candidate.state);
    final name = candidate.rule.name.trim();
    final url = candidate.rule.url.trim();
    final title = name.isEmpty ? (url.isEmpty ? '未命名引擎' : url) : name;
    final subtitle = url.isEmpty ? '未配置 URL' : url;
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onTap,
      child: AppCard(
        backgroundColor: selected
            ? CupertinoColors.systemGrey5.resolveFrom(context)
            : CupertinoColors.systemBackground.resolveFrom(context),
        borderColor: CupertinoColors.separator.resolveFrom(context),
        borderWidth: 0.5,
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Row(
          children: [
            Icon(
              selected
                  ? CupertinoIcons.check_mark_circled_solid
                  : CupertinoIcons.circle,
              color: selected
                  ? CupertinoColors.activeBlue.resolveFrom(context)
                  : CupertinoColors.secondaryLabel.resolveFrom(context),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color:
                          CupertinoColors.secondaryLabel.resolveFrom(context),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            DecoratedBox(
              decoration: BoxDecoration(
                color: stateColor.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 2,
                ),
                child: Text(
                  stateLabel,
                  style: TextStyle(
                    color: stateColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _stateLabel(HttpTtsImportCandidateState state) {
    return switch (state) {
      HttpTtsImportCandidateState.newRule => '新增',
      HttpTtsImportCandidateState.update => '更新',
      HttpTtsImportCandidateState.existing => '已有',
    };
  }

  static Color _stateColor(
    BuildContext context,
    HttpTtsImportCandidateState state,
  ) {
    return switch (state) {
      HttpTtsImportCandidateState.newRule =>
        CupertinoColors.systemGreen.resolveFrom(context),
      HttpTtsImportCandidateState.update =>
        CupertinoColors.systemOrange.resolveFrom(context),
      HttpTtsImportCandidateState.existing =>
        CupertinoColors.secondaryLabel.resolveFrom(context),
    };
  }
}

class _BlockingProgressContent extends StatelessWidget {
  const _BlockingProgressContent({
    required this.text,
  });

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CupertinoActivityIndicator(),
          const SizedBox(height: 10),
          Text(text),
        ],
      ),
    );
  }
}
