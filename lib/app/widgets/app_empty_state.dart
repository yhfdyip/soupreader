import 'dart:math' as math;

import 'package:flutter/cupertino.dart';

import '../theme/design_tokens.dart';
import 'app_squircle_surface.dart';

/// iOS 风格的空态组件：对齐 .happy-attachments 截图中的留白、字号与插画比例。
///
/// 约定：
/// - 标题不使用大字号（避免“巨标题”压缩留白）
/// - 说明文字使用 secondaryLabel
/// - 插画默认用轻量 CustomPaint（无需额外资源文件）
class AppEmptyState extends StatelessWidget {
  final Widget illustration;
  final String title;
  final String? message;
  final Widget? action;

  const AppEmptyState({
    super.key,
    required this.illustration,
    required this.title,
    this.message,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final theme = CupertinoTheme.of(context);
    final labelColor = CupertinoColors.label.resolveFrom(context);
    final secondary = CupertinoColors.secondaryLabel.resolveFrom(context);
    final trimmedMessage = (message ?? '').trim();
    final isDark = (theme.brightness ?? Brightness.light) == Brightness.dark;
    final panelColor = isDark
        ? AppDesignTokens.glassDarkMaterial.withValues(alpha: 0.86)
        : AppDesignTokens.glassLightMaterial.withValues(alpha: 0.9);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              illustration,
              const SizedBox(height: 14),
              AppSquircleSurface(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                backgroundColor: panelColor,
                borderColor: CupertinoColors.separator
                    .resolveFrom(context)
                    .withValues(alpha: 0.72),
                radius: AppDesignTokens.radiusCard,
                borderWidth: AppDesignTokens.hairlineBorderWidth,
                blurBackground: true,
                shadows: <BoxShadow>[
                  BoxShadow(
                    color: (isDark
                            ? CupertinoColors.black
                            : const Color(0xFF0B2F66))
                        .withValues(alpha: isDark ? 0.26 : 0.12),
                    offset: const Offset(0, 10),
                    blurRadius: 24,
                    spreadRadius: -12,
                  ),
                ],
                child: Column(
                  children: [
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.textStyle.copyWith(
                        color: labelColor,
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        height: 1.15,
                        letterSpacing: -0.2,
                      ),
                    ),
                    if (trimmedMessage.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        trimmedMessage,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.textStyle.copyWith(
                          color: secondary,
                          fontSize: 13,
                          height: 1.25,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ],
                    if (action != null) ...[
                      const SizedBox(height: 16),
                      action!,
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 轻量“星球”插画，尽量贴近截图中的圆润蓝色风格，不依赖图片资源。
class AppEmptyPlanetIllustration extends StatelessWidget {
  static const double defaultSize = 82;
  final double size;

  const AppEmptyPlanetIllustration({
    super.key,
    this.size = defaultSize,
  });

  @override
  Widget build(BuildContext context) {
    final primary = CupertinoTheme.of(context).primaryColor;
    final ring = primary.withValues(alpha: 0.38);
    final fill = primary.withValues(alpha: 0.14);
    final dot = primary.withValues(alpha: 0.30);
    final accent = primary.withValues(alpha: 0.72);

    return CustomPaint(
      size: Size.square(size),
      painter: _PlanetPainter(
        ringColor: ring,
        fillColor: fill,
        dotColor: dot,
        accentColor: accent,
      ),
    );
  }
}

class _PlanetPainter extends CustomPainter {
  static const double _planetRadiusFactor = 0.22;
  static const double _ringStrokeFactor = 0.06;
  static const double _accentStrokeFactor = 0.05;
  static const double _ringTranslateYFactor = 0.04;
  static const double _planetTranslateYFactor = 0.02;
  static const double _ringWidthFactor = 0.78;
  static const double _ringHeightFactor = 0.36;

  static const double _ringBackStart = math.pi * 0.10;
  static const double _ringBackSweep = math.pi * 1.05;
  static const double _ringFrontStart = math.pi * 1.15;
  static const double _ringFrontSweep = math.pi * 0.92;

  static const double _dot1X = 0.26;
  static const double _dot1Y = 0.22;
  static const double _dot1R = 3.2;
  static const double _dot2X = 0.70;
  static const double _dot2Y = 0.18;
  static const double _dot2R = 2.6;
  static const double _dot3X = 0.74;
  static const double _dot3Y = 0.36;
  static const double _dot3R = 2.2;

  final Color ringColor;
  final Color fillColor;
  final Color dotColor;
  final Color accentColor;

  const _PlanetPainter({
    required this.ringColor,
    required this.fillColor,
    required this.dotColor,
    required this.accentColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final planetR = size.width * _planetRadiusFactor;

    final ringPaint = Paint()
      ..color = ringColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * _ringStrokeFactor
      ..strokeCap = StrokeCap.round;
    final fillPaint = Paint()
      ..color = fillColor
      ..style = PaintingStyle.fill;
    final accentPaint = Paint()
      ..color = accentColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * _accentStrokeFactor
      ..strokeCap = StrokeCap.round;

    final ringRect = Rect.fromCenter(
      center: center.translate(0, size.height * _ringTranslateYFactor),
      width: size.width * _ringWidthFactor,
      height: size.height * _ringHeightFactor,
    );

    // 背景环（后半段）
    canvas.drawArc(ringRect, _ringBackStart, _ringBackSweep, false, ringPaint);

    // 星球主体
    canvas.drawCircle(
      center.translate(0, size.height * _planetTranslateYFactor),
      planetR,
      fillPaint,
    );

    // 前景环（前半段）
    canvas.drawArc(
      ringRect,
      _ringFrontStart,
      _ringFrontSweep,
      false,
      accentPaint,
    );

    final dotPaint = Paint()
      ..color = dotColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(
      Offset(size.width * _dot1X, size.height * _dot1Y),
      _dot1R,
      dotPaint,
    );
    canvas.drawCircle(
      Offset(size.width * _dot2X, size.height * _dot2Y),
      _dot2R,
      dotPaint,
    );
    canvas.drawCircle(
      Offset(size.width * _dot3X, size.height * _dot3Y),
      _dot3R,
      dotPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _PlanetPainter oldDelegate) {
    return ringColor != oldDelegate.ringColor ||
        fillColor != oldDelegate.fillColor ||
        dotColor != oldDelegate.dotColor ||
        accentColor != oldDelegate.accentColor;
  }
}
