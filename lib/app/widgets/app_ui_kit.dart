import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

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
    // 使用系统标准色，与 iOS insetGrouped 列表视觉完全一致。
    return CupertinoListSection.insetGrouped(
      header: header,
      footer: footer,
      hasLeading: hasLeading,
      margin: margin,
      backgroundColor: tokens.colors.groupedBackground,
      decoration: BoxDecoration(
        color: tokens.colors.sectionBackground,
      ),
      separatorColor: tokens.colors.separator,
      children: children,
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

    // CupertinoListTile.notched 在 onTap=null 时整行不接收触摸，
    // 导致 trailing 中的 Switch/Button 也无法响应。
    // 当有 trailing 且无 onTap 时，传入空回调使触摸可穿透到 trailing。
    final resolvedOnTap = _resolveOnTap() ??
        (resolvedTrailing != null ? () {} : null);
    return CupertinoListTile.notched(
      title: resolvedTitle,
      subtitle: subtitle,
      additionalInfo: additionalInfo,
      leading: resolvedLeading,
      trailing: resolvedTrailing,
      onTap: resolvedOnTap,
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
