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
  final bool includeTopSafeArea;
  final bool includeBottomSafeArea;
  final bool useSliverNavigationBar;
  final bool showLargeTitle;
  final Widget? largeTitle;
  final AppSliverBodyBuilder? sliverBodyBuilder;
  final ScrollController? sliverScrollController;
  final ScrollPhysics? sliverScrollPhysics;

  const AppCupertinoPageScaffold({
    super.key,
    required this.title,
    required this.child,
    this.middle,
    this.leading,
    this.trailing,
    this.includeTopSafeArea = true,
    this.includeBottomSafeArea = true,
    this.useSliverNavigationBar = false,
    this.showLargeTitle = false,
    this.largeTitle,
    this.sliverBodyBuilder,
    this.sliverScrollController,
    this.sliverScrollPhysics,
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
      // Sliver 导航栏已处理顶部安全区，这里只处理底部，避免双重 SafeArea。
      top: false,
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
    final navBarBackground = Color.alphaBlend(
      navSurface,
      theme.barBackgroundColor,
    );
    final border = Border(bottom: BorderSide(color: borderColor, width: 0.5));

    if (!useSliverNavigationBar) {
      return CupertinoPageScaffold(
        navigationBar: CupertinoNavigationBar(
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
          backgroundColor: navBarBackground,
          border: border,
        ),
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
    final resolvedMiddle = middle ?? Text(title);
    final resolvedLargeTitle =
        showLargeTitle ? (largeTitle ?? Text(title)) : null;

    return CupertinoPageScaffold(
      child: _buildBackground(
        backgroundColor: baseBackground,
        child: CustomScrollView(
          primary: sliverScrollController == null,
          controller: sliverScrollController,
          physics: sliverScrollPhysics,
          slivers: [
            CupertinoSliverNavigationBar(
              largeTitle: resolvedLargeTitle,
              middle: resolvedMiddle,
              alwaysShowMiddle: !showLargeTitle,
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
              backgroundColor: navBarBackground,
              border: border,
            ),
            bodySliver,
          ],
        ),
      ),
    );
  }
}
