import 'package:flutter/cupertino.dart';

import '../../../app/theme/design_tokens.dart';
import '../../../app/theme/source_ui_tokens.dart';
import '../../../app/theme/ui_tokens.dart';
import '../../../app/widgets/app_manage_search_field.dart';

class DiscoverySearchHeader extends StatelessWidget {
  const DiscoverySearchHeader({
    super.key,
    required this.controller,
    required this.searchFocusNode,
    required this.query,
    required this.visibleCount,
    required this.onClear,
    this.activeFilterChip,
  });

  // _shellRadius removed: now uses SourceUiTokens.radiusCard
  static const double _shellTopPadding = 10;
  static const double _shellHorizontalPadding = 10;
  static const double _shellBottomPadding = 8;
  static const double _shellRevealOffset = 10;
  static const double _shadowDarkAlpha = 0.18;
  static const double _shadowLightAlpha = 0.08;
  static const double _cancelButtonHorizontalPadding = 10;

  final TextEditingController controller;
  final FocusNode searchFocusNode;
  final String query;
  final int visibleCount;
  final VoidCallback onClear;
  final Widget? activeFilterChip;

  @override
  Widget build(BuildContext context) {
    final uiTokens = AppUiTokens.resolve(context);
    final shell = _resolveShellStyle(uiTokens);

    return Padding(
      padding: AppManageSearchField.outerPadding,
      child: TweenAnimationBuilder<double>(
        duration: AppDesignTokens.motionSpring,
        curve: Curves.easeOutQuart,
        tween: Tween<double>(begin: 0, end: 1),
        child: _buildSurface(context, uiTokens, shell),
        builder: (_, value, child) {
          return Transform.translate(
            offset: Offset(0, (1 - value) * _shellRevealOffset),
            child: Opacity(opacity: value, child: child),
          );
        },
      ),
    );
  }

  _DiscoveryHeaderShellStyle _resolveShellStyle(AppUiTokens uiTokens) {
    final isDark = uiTokens.isDark;
    final shadow = (isDark ? CupertinoColors.black : AppDesignTokens.shadowLight)
        .withValues(alpha: isDark ? _shadowDarkAlpha : _shadowLightAlpha);
    return _DiscoveryHeaderShellStyle(
      background: uiTokens.colors.sectionBackground,
      border: uiTokens.colors.separator,
      shadow: shadow,
    );
  }

  Widget _buildSurface(
    BuildContext context,
    AppUiTokens uiTokens,
    _DiscoveryHeaderShellStyle shell,
  ) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: shell.background,
        borderRadius: BorderRadius.circular(SourceUiTokens.radiusCard),
        boxShadow: [
          BoxShadow(
            color: shell.shadow,
            offset: const Offset(0, 4),
            blurRadius: 12,
            spreadRadius: -6,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          _shellHorizontalPadding,
          _shellTopPadding,
          _shellHorizontalPadding,
          _shellBottomPadding,
        ),
        child: _buildContent(context, uiTokens),
      ),
    );
  }

  Widget _buildContent(BuildContext context, AppUiTokens uiTokens) {
    final theme = CupertinoTheme.of(context);
    return Column(
      children: [
        _buildSearchRow(context, theme),
        const SizedBox(height: SourceUiTokens.discoveryHeaderGap),
        _buildMetaRow(theme, uiTokens),
      ],
    );
  }

  Widget _buildSearchRow(BuildContext context, CupertinoThemeData theme) {
    final showCancel = searchFocusNode.hasFocus || query.isNotEmpty;
    return Row(
      children: [
        Expanded(
          child: AppManageSearchField(
            controller: controller,
            focusNode: searchFocusNode,
            placeholder: '请输入关键字搜索书源...',
          ),
        ),
        AnimatedSwitcher(
          duration: AppDesignTokens.motionQuick,
          switchInCurve: Curves.easeOutQuart,
          switchOutCurve: Curves.easeInCubic,
          child: showCancel
              ? CupertinoButton(
                  key: const ValueKey<String>('discovery_search_cancel'),
                  padding: const EdgeInsets.symmetric(
                    horizontal: _cancelButtonHorizontalPadding,
                  ),
                  minimumSize: const Size(
                    SourceUiTokens.minTapSize,
                    SourceUiTokens.minTapSize,
                  ),
                  onPressed: onClear,
                  child: Text(
                    '取消',
                    style: theme.textTheme.actionTextStyle.copyWith(
                      color: SourceUiTokens.resolvePrimaryActionColor(context),
                    ),
                  ),
                )
              : const SizedBox(
                  key: ValueKey<String>('discovery_search_cancel_placeholder'),
                  width: 0,
                  height: SourceUiTokens.minTapSize,
                ),
        ),
      ],
    );
  }

  Widget _buildMetaRow(CupertinoThemeData theme, AppUiTokens uiTokens) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          '书源（$visibleCount）',
          style: theme.textTheme.textStyle.copyWith(
            fontSize: SourceUiTokens.discoveryMetaTextSize,
            color: uiTokens.colors.mutedForeground,
          ),
        ),
        if (activeFilterChip != null)
          Flexible(
            child: Align(
              alignment: Alignment.centerRight,
              child: activeFilterChip!,
            ),
          ),
      ],
    );
  }
}

@immutable
class _DiscoveryHeaderShellStyle {
  const _DiscoveryHeaderShellStyle({
    required this.background,
    required this.border,
    required this.shadow,
  });

  final Color background;
  final Color border;
  final Color shadow;
}
