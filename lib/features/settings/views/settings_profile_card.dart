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

  static const double _cardPaddingHorizontal = 14;
  static const double _cardPaddingVertical = 13;
  static const double _cardRevealOffset = 12;
  static const double _avatarSize = 42;
  static const double _avatarRadius = 12;
  static const double _shadowDarkAlpha = 0.22;
  static const double _shadowLightAlpha = 0.08;

  final AppAppearanceMode appearanceMode;
  final String modeLabel;

  @override
  Widget build(BuildContext context) {
    final tokens = AppUiTokens.resolve(context);
    final appearanceIcon = _appearanceIconForMode(appearanceMode);
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
      child: _buildSurface(tokens, content),
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

  Widget _buildSurface(AppUiTokens tokens, Widget content) {
    final isDark = tokens.isDark;
    final shadow = (isDark ? CupertinoColors.black : const Color(0xFF052049))
        .withValues(alpha: isDark ? _shadowDarkAlpha : _shadowLightAlpha);
    return AppSquircleSurface(
      padding: EdgeInsets.zero,
      backgroundColor: tokens.colors.sectionBackground,
      borderColor: tokens.colors.separator,
      borderWidth: AppDesignTokens.hairlineBorderWidth,
      radius: AppDesignTokens.radiusCard,
      blurBackground: false,
      shadows: [
        BoxShadow(
          color: shadow,
          offset: const Offset(0, 2),
          blurRadius: 12,
          spreadRadius: -4,
        ),
      ],
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          _cardPaddingHorizontal,
          _cardPaddingVertical,
          _cardPaddingHorizontal,
          _cardPaddingVertical,
        ),
        child: content,
      ),
    );
  }

  Widget _buildAvatar(AppUiTokens tokens) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tokens.colors.accent,
        borderRadius: BorderRadius.circular(_avatarRadius),
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
      decoration: BoxDecoration(
        color: tokens.colors.accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: tokens.colors.accent.withValues(alpha: 0.25),
          width: AppDesignTokens.hairlineBorderWidth,
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

