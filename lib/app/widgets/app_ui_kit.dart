import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../theme/design_tokens.dart';
import '../theme/ui_tokens.dart';

export 'app_card.dart';

/// 管理页统一 UI Kit（薄封装，强制收敛列表/分组/卡片的基础样式）。
///
/// 该文件只做“默认值统一”，不改变 Cupertino 的语义与交互行为。

class AppListView extends StatelessWidget {
  final List<Widget> children;
  final EdgeInsetsGeometry? padding;
  final ScrollController? controller;
  final ScrollPhysics? physics;

  const AppListView({
    super.key,
    required this.children,
    this.padding,
    this.controller,
    this.physics,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AppUiTokens.resolve(context);
    return ListView(
      controller: controller,
      padding: padding ?? tokens.spacings.pageListPadding,
      physics: physics ?? const BouncingScrollPhysics(),
      children: children,
    );
  }
}

class AppListSection extends StatelessWidget {
  static const double _kDarkSectionAlpha = 0.84;
  static const double _kLightSectionAlpha = 0.88;
  static const double _kAmbientTopAlpha = 0.18;
  static const double _kAmbientBottomAlpha = 0.14;

  final Widget? header;
  final Widget? footer;
  final List<Widget> children;
  final bool hasLeading;
  final EdgeInsetsGeometry? margin;

  const AppListSection({
    super.key,
    this.header,
    this.footer,
    required this.children,
    this.hasLeading = true,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AppUiTokens.resolve(context);
    final borderColor = tokens.colors.separator.withValues(alpha: 0.74);
    final cardBackground = tokens.colors.sectionBackground.withValues(
      alpha: tokens.isDark ? _kDarkSectionAlpha : _kLightSectionAlpha,
    );
    final bezelColor = (tokens.isDark
            ? AppDesignTokens.glassInnerHighlightDark
            : AppDesignTokens.glassInnerHighlightLight)
        .withValues(alpha: 0.54);
    final ambientTop = (tokens.isDark
            ? AppDesignTokens.ambientTopDark
            : AppDesignTokens.ambientTopLight)
        .withValues(alpha: _kAmbientTopAlpha);
    final ambientBottom = (tokens.isDark
            ? AppDesignTokens.ambientBottomDark
            : AppDesignTokens.ambientBottomLight)
        .withValues(alpha: _kAmbientBottomAlpha);
    final sectionShape = ContinuousRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(tokens.radii.card)),
      side: BorderSide(
        color: borderColor,
        width: AppDesignTokens.hairlineBorderWidth,
      ),
    );
    return ClipPath(
      clipper: ShapeBorderClipper(shape: sectionShape),
      child: CupertinoListSection.insetGrouped(
        header: header,
        footer: footer,
        hasLeading: hasLeading,
        margin: margin,
        backgroundColor: tokens.colors.groupedBackground,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [ambientTop, cardBackground, ambientBottom],
            stops: const [0.0, 0.52, 1.0],
          ),
          border: Border(
            top: BorderSide(
              color: bezelColor,
              width: AppDesignTokens.hairlineBorderWidth,
            ),
            left: BorderSide(
              color: borderColor,
              width: AppDesignTokens.hairlineBorderWidth,
            ),
            right: BorderSide(
              color: borderColor,
              width: AppDesignTokens.hairlineBorderWidth,
            ),
            bottom: BorderSide(
              color: borderColor,
              width: AppDesignTokens.hairlineBorderWidth,
            ),
          ),
        ),
        separatorColor: borderColor,
        children: children,
      ),
    );
  }
}

class AppListTile extends StatelessWidget {
  final Widget title;
  final Widget? subtitle;
  final Widget? additionalInfo;
  final Widget? leading;
  final IconData? leadingIcon;
  final Widget? trailing;
  final FutureOr<void> Function()? onTap;
  final bool showChevron;
  final bool isDestructiveAction;

  const AppListTile({
    super.key,
    required this.title,
    this.subtitle,
    this.additionalInfo,
    this.leading,
    this.leadingIcon,
    this.trailing,
    this.onTap,
    this.showChevron = true,
    this.isDestructiveAction = false,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AppUiTokens.resolve(context);
    final resolvedLeading = leading ??
        (leadingIcon == null
            ? null
            : Icon(
                leadingIcon,
                size: tokens.iconSizes.listLeading,
                color: isDestructiveAction
                    ? tokens.colors.destructive
                    : tokens.colors.accent,
              ));

    final resolvedTrailing = trailing ??
        (onTap == null || !showChevron
            ? null
            : const CupertinoListTileChevron());

    final resolvedTitle = isDestructiveAction
        ? DefaultTextStyle.merge(
            style: TextStyle(color: tokens.colors.destructive),
            child: title,
          )
        : title;

    return CupertinoListTile.notched(
      title: resolvedTitle,
      subtitle: subtitle,
      additionalInfo: additionalInfo,
      leading: resolvedLeading,
      trailing: resolvedTrailing,
      onTap: _resolveOnTap(),
    );
  }

  VoidCallback? _resolveOnTap() {
    final action = onTap;
    if (action == null) return null;
    return () {
      HapticFeedback.lightImpact();
      final result = action();
      if (result is Future<void>) {
        unawaited(result);
      }
    };
  }
}
