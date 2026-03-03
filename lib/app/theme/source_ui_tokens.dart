import 'package:flutter/cupertino.dart';

/// 书源相关页面的视觉令牌。
///
/// 仅用于书源管理/发现/发现二级等页面，统一字号、圆角、边框与语义色。
@immutable
class SourceUiTokens {
  const SourceUiTokens._();

  static const double radiusCard = 12;
  static const double radiusControl = 10;
  static const double borderWidth = 0.6;
  static const double pagePaddingHorizontal = 12;
  static const double discoveryHeaderGap = 8;
  static const double discoveryCardInnerGap = 8;
  static const double discoveryChipHorizontalPadding = 11;
  static const double discoveryChipVerticalPadding = 7;
  static const double discoveryExpandedCardBorderAlpha = 0.78;
  static const double discoveryMetaTextSize = 12;
  static const double discoveryResultCoverWidth = 42;
  static const double discoveryResultCoverHeight = 60;
  static const double itemTitleSize = 15;
  static const double itemMetaSize = 12;
  static const double itemSubMetaSize = 11;
  static const double actionTextSize = 13;
  static const double actionIconSize = 19;
  static const double detailTitleSize = 23;
  static const double emptyTitleSize = 20;
  static const double emptyMessageSize = 14;
  static const double minTapSize = kMinInteractiveDimensionCupertino;

  static Color resolvePrimaryActionColor(BuildContext context) {
    return CupertinoTheme.of(context).primaryColor;
  }

  static Color resolveDangerColor(BuildContext context) {
    return CupertinoColors.systemRed.resolveFrom(context);
  }

  static Color resolveSuccessColor(BuildContext context) {
    return CupertinoColors.systemGreen.resolveFrom(context);
  }

  static Color resolveSecondaryTextColor(BuildContext context) {
    return CupertinoColors.secondaryLabel.resolveFrom(context);
  }

  static Color resolveMutedTextColor(BuildContext context) {
    return CupertinoColors.tertiaryLabel.resolveFrom(context);
  }

  static Color resolveSeparatorColor(BuildContext context) {
    return CupertinoColors.separator.resolveFrom(context);
  }

  static Color resolveCardBackgroundColor(BuildContext context) {
    return CupertinoColors.secondarySystemGroupedBackground
        .resolveFrom(context);
  }
}
