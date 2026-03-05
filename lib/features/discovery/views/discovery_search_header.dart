import 'package:flutter/cupertino.dart';

import '../../../app/theme/design_tokens.dart';
import '../../../app/theme/source_ui_tokens.dart';
import '../../../app/theme/ui_tokens.dart';
import '../../../app/widgets/app_manage_search_field.dart';
import '../../../app/widgets/app_squircle_surface.dart';

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

  static const double _shellRadius = 20;
  static const double _shellTopPadding = 10;
  static const double _shellHorizontalPadding = 10;
  static const double _shellBottomPadding = 8;
  static const double _shellRevealOffset = 10;
  static const double _glassDarkAlpha = 0.84;
  static const double _glassLightAlpha = 0.9;
  static const double _borderAlpha = 0.82;
  static const double _bezelAlpha = 0.52;
  static const double _shadowDarkAlpha = 0.24;
  static const double _shadowLightAlpha = 0.1;
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
    final background = isDark
        ? AppDesignTokens.glassDarkMaterial.withValues(alpha: _glassDarkAlpha)
        : AppDesignTokens.glassLightMaterial
            .withValues(alpha: _glassLightAlpha);
    final border =
        (isDark ? AppDesignTokens.borderDark : AppDesignTokens.borderLight)
            .withValues(alpha: _borderAlpha);
    final bezel = (isDark
            ? AppDesignTokens.glassInnerHighlightDark
            : AppDesignTokens.glassInnerHighlightLight)
        .withValues(alpha: _bezelAlpha);
    final shadow = (isDark ? CupertinoColors.black : const Color(0xFF0A2A5E))
        .withValues(alpha: isDark ? _shadowDarkAlpha : _shadowLightAlpha);
    return _DiscoveryHeaderShellStyle(
      background: background,
      border: border,
      bezel: bezel,
      shadow: shadow,
    );
  }

  Widget _buildSurface(
    BuildContext context,
    AppUiTokens uiTokens,
    _DiscoveryHeaderShellStyle shell,
  ) {
    return AppSquircleSurface(
      padding: EdgeInsets.zero,
      backgroundColor: shell.background,
      borderColor: shell.border,
      borderWidth: AppDesignTokens.hairlineBorderWidth,
      radius: _shellRadius,
      blurBackground: true,
      shadows: [
        BoxShadow(
          color: shell.shadow,
          offset: const Offset(0, 8),
          blurRadius: 20,
          spreadRadius: -12,
        ),
      ],
      child: Stack(
        children: [
          Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              height: AppDesignTokens.hairlineBorderWidth,
              child: ColoredBox(color: shell.bezel),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              _shellHorizontalPadding,
              _shellTopPadding,
              _shellHorizontalPadding,
              _shellBottomPadding,
            ),
            child: _buildContent(context, uiTokens),
          ),
        ],
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
    required this.bezel,
    required this.shadow,
  });

  final Color background;
  final Color border;
  final Color bezel;
  final Color shadow;
}
