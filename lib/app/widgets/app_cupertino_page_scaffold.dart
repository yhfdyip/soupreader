import 'package:flutter/cupertino.dart';

import '../theme/design_tokens.dart';

typedef AppSliverBodyBuilder = Widget Function(BuildContext context);

/// 统一页面容器：导航栏 + 页面背景 + SafeArea。
class AppCupertinoPageScaffold extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? middle;
  final Widget? leading;
  final Widget? trailing;
  final bool transitionBetweenRoutes;
  final bool includeTopSafeArea;
  final bool includeBottomSafeArea;
  final bool useSliverNavigationBar;
  final bool showLargeTitle;
  final Widget? largeTitle;
  final AppSliverBodyBuilder? sliverBodyBuilder;
  final ScrollController? sliverScrollController;
  final ScrollPhysics? sliverScrollPhysics;
  final Color? navigationBarBackgroundColor;
  final Border? navigationBarBorder;
  final bool navigationBarEnableBackgroundFilterBlur;
  final bool navigationBarAutomaticBackgroundVisibility;

  const AppCupertinoPageScaffold({
    super.key,
    required this.title,
    required this.child,
    this.middle,
    this.leading,
    this.trailing,
    // 默认关闭路由间导航栏联动过渡，避免二级页进场时右上角动作按钮瞬时叠加。
    this.transitionBetweenRoutes = false,
    this.includeTopSafeArea = true,
    this.includeBottomSafeArea = true,
    this.useSliverNavigationBar = false,
    this.showLargeTitle = false,
    this.largeTitle,
    this.sliverBodyBuilder,
    this.sliverScrollController,
    this.sliverScrollPhysics,
    this.navigationBarBackgroundColor,
    this.navigationBarBorder,
    this.navigationBarEnableBackgroundFilterBlur = true,
    this.navigationBarAutomaticBackgroundVisibility = true,
  });

  Widget? _buildNavBarItem(
    BuildContext context,
    Widget? child, {
    required Alignment alignment,
  }) {
    if (child == null) return null;
    final width = MediaQuery.sizeOf(context).width;
    final maxWidth = width * 0.42;
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: alignment,
        child: child,
      ),
    );
  }

  Widget _buildBackground({
    required Color backgroundColor,
    required Widget child,
  }) {
    return DecoratedBox(
      decoration: BoxDecoration(color: backgroundColor),
      child: child,
    );
  }

  Widget _buildDefaultSliverBody() {
    return SliverSafeArea(
      // Sliver 模式下使用 CupertinoNavigationBar（可能为半透明）。
      // 当导航栏半透明时，CupertinoPageScaffold 会通过 MediaQuery.padding.top
      // 传递“被导航栏遮挡的区域高度”，需要由 SliverSafeArea 在滚动内容里消化，
      // 否则首屏内容会被导航栏覆盖（看起来像“顶部菜单项消失”）。
      top: includeTopSafeArea,
      bottom: includeBottomSafeArea,
      sliver: SliverFillRemaining(
        hasScrollBody: true,
        child: PrimaryScrollController.none(
          child: child,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    try {
      return _buildInner(context);
    } catch (e, st) {
      debugPrint('[AppCupertinoPageScaffold] build error: $e');
      debugPrintStack(stackTrace: st);
      // 降级为最简单的非 Sliver 页面，显示具体异常信息。
      return CupertinoPageScaffold(
        navigationBar: CupertinoNavigationBar(
          middle: Text(title),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Text(
              '页面框架异常:\n$e\n\n$st',
              style: const TextStyle(fontSize: 11),
            ),
          ),
        ),
      );
    }
  }

  Widget _buildInner(BuildContext context) {
    final theme = CupertinoTheme.of(context);
    final brightness = theme.brightness ??
        MediaQuery.maybeOf(context)?.platformBrightness ??
        Brightness.light;
    final isDark = brightness == Brightness.dark;
    final borderColor = isDark
        ? AppDesignTokens.borderDark.withValues(alpha: 0.85)
        : AppDesignTokens.borderLight;
    final baseBackground = theme.scaffoldBackgroundColor;
    final navSurface = isDark
        ? AppDesignTokens.surfaceDark.withValues(alpha: 0.78)
        : AppDesignTokens.surfaceLight.withValues(alpha: 0.96);
    final defaultNavBarBackground = Color.alphaBlend(
      navSurface,
      theme.barBackgroundColor,
    );
    final border = Border(bottom: BorderSide(color: borderColor, width: 0.5));
    final resolvedNavBarBackground =
        navigationBarBackgroundColor ?? defaultNavBarBackground;
    final resolvedNavBarBorder = navigationBarBorder ?? border;

    final navBar = CupertinoNavigationBar(
      middle: middle ?? Text(title),
      previousPageTitle: '',
      leading: _buildNavBarItem(
        context,
        leading,
        alignment: Alignment.centerLeft,
      ),
      trailing: _buildNavBarItem(
        context,
        trailing,
        alignment: Alignment.centerRight,
      ),
      transitionBetweenRoutes: transitionBetweenRoutes,
      backgroundColor: resolvedNavBarBackground,
      border: resolvedNavBarBorder,
      enableBackgroundFilterBlur: navigationBarEnableBackgroundFilterBlur,
      automaticBackgroundVisibility: navigationBarAutomaticBackgroundVisibility,
    );

    if (!useSliverNavigationBar) {
      return CupertinoPageScaffold(
        navigationBar: navBar,
        child: _buildBackground(
          backgroundColor: baseBackground,
          child: SafeArea(
            top: includeTopSafeArea,
            bottom: includeBottomSafeArea,
            child: child,
          ),
        ),
      );
    }

    // Sliver 模式：使用普通 CupertinoNavigationBar + CustomScrollView 承载 bodySliver。
    // ⚠️ CupertinoSliverNavigationBar 在 iOS Release 模式下 layout 阶段崩溃导致灰屏，
    // 即使 primary: false 也无法解决。暂用普通导航栏替代。
    // primary 强制为 false，避免多个 tab 的 CustomScrollView 竞争同一 PrimaryScrollController。
    Widget bodySliver;
    try {
      bodySliver =
          sliverBodyBuilder?.call(context) ?? _buildDefaultSliverBody();
    } catch (e, st) {
      debugPrint('[scaffold] sliverBodyBuilder error: $e');
      debugPrintStack(stackTrace: st);
      bodySliver = SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              '页面构建异常:\n$e',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ),
      );
    }

    // 底部留白：TabBar 嵌套在 CupertinoTabScaffold 中时，
    // SliverSafeArea(bottom: true) 只处理物理安全区（Home Indicator），
    // 不包含 TabBar 占据的空间。由于本组件被广泛用作 Tab 的子页面根组件，
    // 需要确保底部内容不被 TabBar 遮挡。这里统一加上标准的 TabBar 高度 + 安全区。
    final bottomPadding = includeBottomSafeArea
        ? MediaQuery.paddingOf(context).bottom +
            50.0 // 50.0 is standard CupertinoTabBar height
        : 50.0;

    return CupertinoPageScaffold(
      backgroundColor: baseBackground,
      navigationBar: navBar,
      child: CustomScrollView(
        primary: false,
        controller: sliverScrollController,
        physics: sliverScrollPhysics,
        slivers: [
          bodySliver,
          SliverPadding(
            padding: EdgeInsets.only(bottom: bottomPadding),
          ),
        ],
      ),
    );
  }
}
