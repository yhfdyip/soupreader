import 'package:flutter/cupertino.dart';

import '../theme/design_tokens.dart';
import '../theme/ui_tokens.dart';
import 'app_squircle_surface.dart';

class AppGlassSheetPanel extends StatelessWidget {
  static const double _kBackgroundAlpha = 0.92;
  static const double _kBorderAlpha = 0.72;
  static const double _kBezelAlpha = 0.46;
  static const double _kAmbientTopAlpha = 0.16;
  static const double _kAmbientBottomAlpha = 0.12;

  final Widget child;
  final EdgeInsetsGeometry contentPadding;
  final double? radius;

  const AppGlassSheetPanel({
    super.key,
    required this.child,
    required this.contentPadding,
    this.radius,
  });

  @override
  Widget build(BuildContext context) {
    final ui = AppUiTokens.resolve(context);
    final panelStyle = _resolvePanelStyle(ui);
    final borderWidth = AppDesignTokens.hairlineBorderWidth;
    return AppSquircleSurface(
      padding: EdgeInsets.zero,
      backgroundColor: panelStyle.background,
      borderColor: panelStyle.border,
      borderWidth: borderWidth,
      radius: radius ?? ui.radii.sheet,
      blurBackground: true,
      child: Stack(
        children: [
          Positioned.fill(child: _buildAmbientLayer(ui)),
          Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              height: borderWidth,
              child: ColoredBox(color: panelStyle.bezel),
            ),
          ),
          Padding(
            padding: contentPadding,
            child: child,
          ),
        ],
      ),
    );
  }

  _AppGlassSheetPanelStyle _resolvePanelStyle(AppUiTokens ui) {
    final backgroundBase =
        ui.isDark ? AppDesignTokens.pageBgDark : AppDesignTokens.pageBgLight;
    final border = ui.colors.separator.withValues(alpha: _kBorderAlpha);
    final bezel = (ui.isDark
            ? AppDesignTokens.glassInnerHighlightDark
            : AppDesignTokens.glassInnerHighlightLight)
        .withValues(alpha: _kBezelAlpha);
    return _AppGlassSheetPanelStyle(
      background: backgroundBase.withValues(alpha: _kBackgroundAlpha),
      border: border,
      bezel: bezel,
    );
  }

  Widget _buildAmbientLayer(AppUiTokens ui) {
    final topColor = (ui.isDark
            ? AppDesignTokens.ambientTopDark
            : AppDesignTokens.ambientTopLight)
        .withValues(alpha: _kAmbientTopAlpha);
    final bottomColor = (ui.isDark
            ? AppDesignTokens.ambientBottomDark
            : AppDesignTokens.ambientBottomLight)
        .withValues(alpha: _kAmbientBottomAlpha);
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[topColor, bottomColor, const Color(0x00000000)],
            stops: <double>[0.0, 0.64, 1.0],
          ),
        ),
      ),
    );
  }
}

@immutable
class _AppGlassSheetPanelStyle {
  const _AppGlassSheetPanelStyle({
    required this.background,
    required this.border,
    required this.bezel,
  });

  final Color background;
  final Color border;
  final Color bezel;
}
