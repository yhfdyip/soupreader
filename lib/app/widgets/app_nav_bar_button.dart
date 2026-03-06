import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../theme/design_tokens.dart';
import '../theme/ui_tokens.dart';
import 'app_squircle_surface.dart';

/// 导航栏按钮统一封装：收敛 padding、最小热区与常见按钮形态。
///
/// 约定：
/// - 仅用于 `CupertinoNavigationBar` / `AppCupertinoPageScaffold` 的 leading/trailing。
/// - 默认最小热区使用 `kMinInteractiveDimensionCupertino`（通过 `AppUiTokens` 统一）。
class AppNavBarButton extends StatefulWidget {
  static const double _kDefaultGlassRadius = 12;

  final VoidCallback? onPressed;
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Size? minimumSize;
  final bool? useGlassBackground;
  final double glassRadius;

  const AppNavBarButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.padding = EdgeInsets.zero,
    this.minimumSize,
    this.useGlassBackground,
    this.glassRadius = _kDefaultGlassRadius,
  });

  @override
  State<AppNavBarButton> createState() => _AppNavBarButtonState();
}

class _AppNavBarButtonState extends State<AppNavBarButton> {
  static const double _kPressedScale = 0.94;
  static const double _kIdleScale = 1;
  static const double _kGlassDarkAlpha = 0.36;
  static const double _kGlassLightAlpha = 0.5;
  static const double _kGlassBorderAlpha = 0.7;
  static const double _kGlassShadowDarkAlpha = 0.22;
  static const double _kGlassShadowLightAlpha = 0.08;

  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final ui = AppUiTokens.resolve(context);
    final resolvedMinimumSize =
        widget.minimumSize ?? Size(ui.sizes.minTapSize, ui.sizes.minTapSize);
    final onTap = widget.onPressed == null
        ? null
        : () {
            HapticFeedback.lightImpact();
            widget.onPressed?.call();
          };
    final decoratedChild =
        _buildDecoratedChild(ui, _shouldUseGlassBackground());

    return Listener(
      onPointerDown: (_) => _setPressed(true),
      onPointerUp: (_) => _setPressed(false),
      onPointerCancel: (_) => _setPressed(false),
      child: AnimatedScale(
        scale: _pressed ? _kPressedScale : _kIdleScale,
        duration: AppDesignTokens.motionQuick,
        curve: Curves.easeOutQuart,
        child: CupertinoButton(
          padding: widget.padding,
          minimumSize: resolvedMinimumSize,
          pressedOpacity: 0.82,
          onPressed: onTap,
          child: decoratedChild,
        ),
      ),
    );
  }

  Widget _buildDecoratedChild(AppUiTokens ui, bool useGlass) {
    if (!useGlass) return widget.child;
    final style = _resolveGlassStyle(ui);
    return AppSquircleSurface(
      padding: const EdgeInsets.all(6),
      backgroundColor: style.background,
      borderColor: style.border,
      borderWidth: AppDesignTokens.hairlineBorderWidth,
      radius: widget.glassRadius,
      blurBackground: true,
      shadows: [
        BoxShadow(
          color: style.shadow,
          offset: const Offset(0, 5),
          blurRadius: 12,
          spreadRadius: -8,
        ),
      ],
      child: widget.child,
    );
  }

  _NavButtonGlassStyle _resolveGlassStyle(AppUiTokens ui) {
    final isDark = ui.isDark;
    final background = ui.colors.sectionBackground.withValues(
      alpha: isDark ? _kGlassDarkAlpha : _kGlassLightAlpha,
    );
    final border = ui.colors.separator.withValues(alpha: _kGlassBorderAlpha);
    final shadow =
        (isDark ? CupertinoColors.black : const Color(0xFF0A2A5E)).withValues(
      alpha: isDark ? _kGlassShadowDarkAlpha : _kGlassShadowLightAlpha,
    );
    return _NavButtonGlassStyle(
      background: background,
      border: border,
      shadow: shadow,
    );
  }

  bool _shouldUseGlassBackground() {
    final explicit = widget.useGlassBackground;
    if (explicit != null) return explicit;
    return widget.child is Icon;
  }

  void _setPressed(bool value) {
    if (widget.onPressed == null || _pressed == value) return;
    setState(() => _pressed = value);
  }
}

@immutable
class _NavButtonGlassStyle {
  const _NavButtonGlassStyle({
    required this.background,
    required this.border,
    required this.shadow,
  });

  final Color background;
  final Color border;
  final Color shadow;
}
