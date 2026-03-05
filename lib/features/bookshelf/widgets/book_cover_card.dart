import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../../../app/theme/design_tokens.dart';
import '../../../app/theme/ui_tokens.dart';
import '../../../app/widgets/app_cover_image.dart';
import '../models/book.dart';

/// 书籍封面卡片组件
class BookCoverCard extends StatelessWidget {
  static const double _coverRatio = 1.4;

  final Book book;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double width;
  final bool showProgress;

  const BookCoverCard({
    super.key,
    required this.book,
    this.onTap,
    this.onLongPress,
    this.width = 100,
    this.showProgress = true,
  });

  @override
  Widget build(BuildContext context) {
    final uiTokens = AppUiTokens.resolve(context);
    return GestureDetector(
      onTap: _wrappedTap,
      onLongPress: _wrappedLongPress,
      child: SizedBox(
        width: width,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCoverArea(uiTokens),
            const SizedBox(height: 9),
            _buildTitle(context, uiTokens),
            const SizedBox(height: 3),
            _buildAuthor(context, uiTokens),
          ],
        ),
      ),
    );
  }

  Widget _buildCoverArea(AppUiTokens uiTokens) {
    final height = width * _coverRatio;
    final coverRadius = AppDesignTokens.radiusControl;
    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          AppCoverImage(
            urlOrPath: book.coverUrl,
            title: book.title,
            author: book.author,
            width: width,
            height: height,
            borderRadius: coverRadius,
            fit: BoxFit.cover,
          ),
          if (showProgress && book.readProgress > 0)
            _buildProgressIndicator(uiTokens),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator(AppUiTokens uiTokens) {
    final progress = book.readProgress.clamp(0.0, 1.0).toDouble();
    return Positioned(
      left: 8,
      right: 8,
      bottom: 8,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: SizedBox(
          height: 4,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: CupertinoColors.black.withValues(alpha: 0.25),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: progress,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: <Color>[
                      uiTokens.colors.accent.withValues(alpha: 0.9),
                      uiTokens.colors.accent,
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTitle(BuildContext context, AppUiTokens uiTokens) {
    final textStyle = CupertinoTheme.of(context).textTheme.textStyle;
    return Text(
      book.title,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: textStyle.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: uiTokens.colors.label,
        letterSpacing: -0.2,
      ),
    );
  }

  Widget _buildAuthor(BuildContext context, AppUiTokens uiTokens) {
    final textStyle = CupertinoTheme.of(context).textTheme.textStyle;
    return Text(
      book.author,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: textStyle.copyWith(
        fontSize: 12,
        color: uiTokens.colors.mutedForeground,
        letterSpacing: -0.2,
      ),
    );
  }

  void _wrappedTap() {
    if (onTap == null) return;
    HapticFeedback.selectionClick();
    onTap?.call();
  }

  void _wrappedLongPress() {
    if (onLongPress == null) return;
    HapticFeedback.mediumImpact();
    onLongPress?.call();
  }
}
