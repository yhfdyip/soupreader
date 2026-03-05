import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../theme/design_tokens.dart';
import '../theme/ui_tokens.dart';
import 'app_squircle_surface.dart';

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
    final borderColor = tokens.colors.separator.withValues(alpha: 0.76);
    final cardBackground =
        tokens.colors.sectionBackground.withValues(alpha: 0.9);
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
          color: cardBackground,
          border: Border.fromBorderSide(
            BorderSide(
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

class AppCard extends StatelessWidget {
  final EdgeInsetsGeometry padding;
  final Widget child;
  final Color? backgroundColor;
  final Color? borderColor;
  final double borderWidth;
  final double? borderRadius;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(12),
    this.backgroundColor,
    this.borderColor,
    this.borderWidth = 0,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AppUiTokens.resolve(context);
    final resolvedBackground = backgroundColor ??
        tokens.colors.sectionBackground.withValues(alpha: 0.88);
    final resolvedBorder = borderColor ?? tokens.colors.separator;
    final radius = borderRadius ?? tokens.radii.card;
    final shadowColor = tokens.isDark
        ? CupertinoColors.black.withValues(alpha: 0.28)
        : const Color(0x16042852);

    return AppSquircleSurface(
      padding: padding,
      backgroundColor: resolvedBackground,
      borderColor: resolvedBorder.withValues(alpha: 0.74),
      borderWidth:
          borderWidth <= 0 ? AppDesignTokens.hairlineBorderWidth : borderWidth,
      radius: radius,
      blurBackground: true,
      shadows: <BoxShadow>[
        BoxShadow(
          color: shadowColor,
          offset: const Offset(0, 8),
          blurRadius: 24,
          spreadRadius: -12,
        ),
      ],
      child: child,
    );
  }
}
