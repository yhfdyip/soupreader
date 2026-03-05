import 'package:flutter/cupertino.dart';

import '../../../app/theme/design_tokens.dart';
import '../../../app/theme/ui_tokens.dart';
import '../../../app/widgets/app_squircle_surface.dart';
import '../../../core/models/app_settings.dart';

class SettingsProfileCard extends StatelessWidget {
  const SettingsProfileCard({
    super.key,
    required this.appearanceMode,
    required this.modeLabel,
  });

  static const double _cardRadius = 24;
  static const double _cardPaddingHorizontal = 14;
  static const double _cardPaddingVertical = 13;
  static const double _cardRevealOffset = 12;
  static const double _cardShadowBlur = 30;
  static const double _cardShadowSpread = -14;
  static const double _cardShadowY = 10;
  static const double _avatarSize = 42;
  static const double _avatarRadius = 14;
  static const double _chipRadius = 14;
  static const double _bezelAlpha = 0.56;
  static const double _darkMaterialAlpha = 0.84;
  static const double _lightMaterialAlpha = 0.9;
  static const double _borderAlpha = 0.86;
  static const double _ambientTopAlpha = 0.34;
  static const double _ambientBottomAlpha = 0.28;
  static const double _shadowDarkAlpha = 0.28;
  static const double _shadowLightAlpha = 0.11;

  final AppAppearanceMode appearanceMode;
  final String modeLabel;

  @override
  Widget build(BuildContext context) {
    final tokens = AppUiTokens.resolve(context);
    final appearanceIcon = _appearanceIconForMode(appearanceMode);
    final palette = _resolvePalette(tokens.isDark);
    final content = Row(
      children: [
        _buildAvatar(tokens),
        const SizedBox(width: 12),
        _buildIntro(context, tokens),
        _buildAppearanceChip(tokens, appearanceIcon),
      ],
    );

    return TweenAnimationBuilder<double>(
      duration: AppDesignTokens.motionSpring,
      curve: Curves.easeOutQuart,
      tween: Tween<double>(begin: 0, end: 1),
      child: _buildSurface(tokens, palette, content),
      builder: (_, value, child) {
        return Transform.translate(
          offset: Offset(0, (1 - value) * _cardRevealOffset),
          child: Opacity(opacity: value, child: child),
        );
      },
    );
  }

  IconData _appearanceIconForMode(AppAppearanceMode mode) {
    return switch (mode) {
      AppAppearanceMode.followSystem => CupertinoIcons.circle_lefthalf_fill,
      AppAppearanceMode.light => CupertinoIcons.sun_max,
      AppAppearanceMode.dark => CupertinoIcons.moon_stars,
      AppAppearanceMode.eInk => CupertinoIcons.rectangle_compress_vertical,
    };
  }

  _ProfileCardPalette _resolvePalette(bool isDark) {
    final background = isDark
        ? AppDesignTokens.glassDarkMaterial
            .withValues(alpha: _darkMaterialAlpha)
        : AppDesignTokens.glassLightMaterial.withValues(
            alpha: _lightMaterialAlpha,
          );
    final border =
        (isDark ? AppDesignTokens.borderDark : AppDesignTokens.borderLight)
            .withValues(alpha: _borderAlpha);
    final bezel = (isDark
            ? AppDesignTokens.glassInnerHighlightDark
            : AppDesignTokens.glassInnerHighlightLight)
        .withValues(alpha: _bezelAlpha);
    final shadow = (isDark ? CupertinoColors.black : const Color(0xFF052049))
        .withValues(alpha: isDark ? _shadowDarkAlpha : _shadowLightAlpha);
    return _ProfileCardPalette(
      background: background,
      border: border,
      bezel: bezel,
      shadow: shadow,
    );
  }

  Widget _buildSurface(
    AppUiTokens tokens,
    _ProfileCardPalette palette,
    Widget content,
  ) {
    return AppSquircleSurface(
      padding: EdgeInsets.zero,
      backgroundColor: palette.background,
      borderColor: palette.border,
      borderWidth: AppDesignTokens.hairlineBorderWidth,
      radius: _cardRadius,
      blurBackground: true,
      shadows: [
        BoxShadow(
          color: palette.shadow,
          offset: const Offset(0, _cardShadowY),
          blurRadius: _cardShadowBlur,
          spreadRadius: _cardShadowSpread,
        ),
      ],
      child: Stack(
        children: [
          Positioned.fill(child: _buildAmbient(tokens)),
          Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              height: AppDesignTokens.hairlineBorderWidth,
              child: ColoredBox(color: palette.bezel),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              _cardPaddingHorizontal,
              _cardPaddingVertical,
              _cardPaddingHorizontal,
              _cardPaddingVertical,
            ),
            child: content,
          ),
        ],
      ),
    );
  }

  Widget _buildAmbient(AppUiTokens tokens) {
    final isDark = tokens.isDark;
    final topColor = (isDark
            ? AppDesignTokens.ambientTopDark
            : AppDesignTokens.ambientTopLight)
        .withValues(alpha: _ambientTopAlpha);
    final bottomColor = (isDark
            ? AppDesignTokens.ambientBottomDark
            : AppDesignTokens.ambientBottomLight)
        .withValues(alpha: _ambientBottomAlpha);
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [topColor, bottomColor, const Color(0x00000000)],
            stops: const [0.0, 0.64, 1.0],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(AppUiTokens tokens) {
    final borderColor = (tokens.isDark
            ? AppDesignTokens.glassInnerHighlightDark
            : AppDesignTokens.glassInnerHighlightLight)
        .withValues(alpha: 0.7);
    return DecoratedBox(
      decoration: ShapeDecoration(
        shape: ContinuousRectangleBorder(
          borderRadius: const BorderRadius.all(Radius.circular(_avatarRadius)),
          side: BorderSide(
            color: borderColor,
            width: AppDesignTokens.hairlineBorderWidth,
          ),
        ),
        gradient: LinearGradient(
          colors: [
            tokens.colors.accent.withValues(alpha: 0.9),
            tokens.colors.accent.withValues(alpha: 0.62),
          ],
        ),
      ),
      child: const SizedBox(
        width: _avatarSize,
        height: _avatarSize,
        child: Icon(
          CupertinoIcons.person_crop_circle_fill,
          color: CupertinoColors.white,
          size: 24,
        ),
      ),
    );
  }

  Widget _buildIntro(BuildContext context, AppUiTokens tokens) {
    final textStyle = CupertinoTheme.of(context).textTheme.textStyle;
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'SoupReader',
            style: textStyle.copyWith(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.24,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            '你的阅读与规则管理中枢',
            style: textStyle.copyWith(
              fontSize: 12,
              color: tokens.colors.secondaryLabel,
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppearanceChip(AppUiTokens tokens, IconData appearanceIcon) {
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: tokens.colors.accent.withValues(alpha: 0.12),
        shape: ContinuousRectangleBorder(
          borderRadius: const BorderRadius.all(Radius.circular(_chipRadius)),
          side: BorderSide(
            color: tokens.colors.accent.withValues(alpha: 0.3),
            width: AppDesignTokens.hairlineBorderWidth,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              appearanceIcon,
              size: 12,
              color: tokens.colors.accent,
            ),
            const SizedBox(width: 4),
            Text(
              modeLabel,
              style: TextStyle(
                color: tokens.colors.accent,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

@immutable
class _ProfileCardPalette {
  const _ProfileCardPalette({
    required this.background,
    required this.border,
    required this.bezel,
    required this.shadow,
  });

  final Color background;
  final Color border;
  final Color bezel;
  final Color shadow;
}
