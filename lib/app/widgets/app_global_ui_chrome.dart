import 'package:flutter/cupertino.dart';

import '../theme/design_tokens.dart';

/// 全局界面氛围层：用于在应用入口统一叠加轻量玻璃质感。
///
/// 设计目标：
/// - 不改变页面布局与交互热区
/// - 仅在视觉层增加柔和的 ambient / tint
/// - 明暗主题自动适配
class AppGlobalUiChrome extends StatelessWidget {
  static const double _kTintAlphaLight = 0.12;
  static const double _kTintAlphaDark = 0.18;
  static const double _kGlowAlphaLight = 0.22;
  static const double _kGlowAlphaDark = 0.28;
  static const double _kTopOrbSize = 320;
  static const double _kBottomOrbSize = 280;

  final Widget child;

  const AppGlobalUiChrome({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = CupertinoTheme.of(context).brightness ??
        MediaQuery.maybeOf(context)?.platformBrightness ??
        Brightness.light;
    final isDark = brightness == Brightness.dark;
    final tintTop =
        (isDark ? AppDesignTokens.pageBgDark : AppDesignTokens.pageBgLight)
            .withValues(alpha: isDark ? _kTintAlphaDark : _kTintAlphaLight);
    final tintBottom =
        (isDark ? const Color(0xFF04060A) : const Color(0xFFE6F0FF))
            .withValues(alpha: isDark ? _kTintAlphaDark : _kTintAlphaLight);
    final topOrbColor = (isDark
            ? AppDesignTokens.ambientTopDark
            : AppDesignTokens.ambientTopLight)
        .withValues(alpha: isDark ? _kGlowAlphaDark : _kGlowAlphaLight);
    final bottomOrbColor = (isDark
            ? AppDesignTokens.ambientBottomDark
            : AppDesignTokens.ambientBottomLight)
        .withValues(alpha: isDark ? _kGlowAlphaDark : _kGlowAlphaLight);

    return Stack(
      fit: StackFit.expand,
      children: [
        child,
        IgnorePointer(
          child: RepaintBoundary(
            child: Stack(
              fit: StackFit.expand,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: <Color>[tintTop, tintBottom],
                      stops: const <double>[0.0, 1.0],
                    ),
                  ),
                ),
                Align(
                  alignment: const Alignment(-1.08, -1.12),
                  child: _OrbGlow(color: topOrbColor, size: _kTopOrbSize),
                ),
                Align(
                  alignment: const Alignment(1.15, 1.08),
                  child: _OrbGlow(color: bottomOrbColor, size: _kBottomOrbSize),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _OrbGlow extends StatelessWidget {
  const _OrbGlow({
    required this.color,
    required this.size,
  });

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: <Color>[
              color,
              color.withValues(alpha: color.a * 0.36),
              const Color(0x00000000),
            ],
            stops: const <double>[0.0, 0.55, 1.0],
          ),
        ),
      ),
    );
  }
}
