import 'package:flutter/cupertino.dart';

import '../theme/design_tokens.dart';
import 'app_error_widget.dart';

typedef AppSliverBodyBuilder = Widget Function(BuildContext context);

/// 统一页面容器：导航栏 + 页面背景 + SafeArea。
class AppCupertinoPageScaffold extends StatelessWidget {
  static const double _kTabBarHeight = 50.0;

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
      return AppErrorWidget(
        title: title,
        message: '页面框架异常: $e',
        stackTrace: '$st',
      );
    }
  }

  Widget _buildInner(BuildContext context) {
    final theme = CupertinoTheme.of(context);
    final brightness = theme.brightness ??
        MediaQuery.maybeOf(context)?.platformBrightness ??
        Brightness.light;
    final isDark = brightness == Brightness.dark;
    final baseBackground = theme.scaffoldBackgroundColor;
    final navSurface = isDark
        ? AppDesignTokens.glassDarkMaterial.withValues(alpha: 0.9)
        : AppDesignTokens.glassLightMaterial.withValues(alpha: 0.9);
    // 保留半透明玻璃层，避免 alphaBlend 后退化为不透明背景导致失去系统模糊。
    final defaultNavBarBackground = navSurface;
    // 原生 iOS 导航栏只有底部一条分隔线。
    final border = Border(
      bottom: BorderSide(
        color: isDark
            ? AppDesignTokens.borderDark
            : AppDesignTokens.borderLight,
        width: AppDesignTokens.hairlineBorderWidth,
      ),
    );
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
        child: SafeArea(
          top: includeTopSafeArea,
          bottom: includeBottomSafeArea,
          child: child,
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
        child: AppErrorWidget(
          title: title,
          message: '页面构建异常: $e',
          stackTrace: '$st',
        ),
      );
    }

    // 底部留白：TabBar 嵌套在 CupertinoTabScaffold 中时，
    // SliverSafeArea(bottom: true) 只处理物理安全区（Home Indicator），
    // 不包含 TabBar 占据的空间。由于本组件被广泛用作 Tab 的子页面根组件，
    // 需要确保底部内容不被 TabBar 遮挡。这里统一加上标准的 TabBar 高度 + 安全区。
    final bottomPadding = includeBottomSafeArea
        ? MediaQuery.paddingOf(context).bottom +
            _kTabBarHeight // Standard CupertinoTabBar height.
        : _kTabBarHeight;

    return CupertinoPageScaffold(
      backgroundColor: baseBackground,
      navigationBar: navBar,
      child: CustomScrollView(
        primary: false,
        controller: sliverScrollController,
        physics: sliverScrollPhysics ??
            const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
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
