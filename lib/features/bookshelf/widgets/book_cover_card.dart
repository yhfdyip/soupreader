import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import '../models/book.dart';
import '../../../app/theme/colors.dart';

/// 书籍封面卡片组件
class BookCoverCard extends StatelessWidget {
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
    final height = width * 1.4; // 封面比例
    final textTheme = CupertinoTheme.of(context).textTheme;

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: SizedBox(
        width: width,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 封面图片
            Container(
              width: width,
              height: height,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF000000).withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // 封面图或占位
                    _buildCover(),

                    // 阅读进度条
                    if (showProgress && book.readProgress > 0)
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          height: 3,
                          decoration: BoxDecoration(
                            color:
                                const Color(0xFF000000).withValues(alpha: 0.3),
                          ),
                          child: FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: book.readProgress,
                            child: Container(
                              decoration: const BoxDecoration(
                                color: AppColors.accent,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 8),

            // 书名
            Text(
              book.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: textTheme.textStyle.copyWith(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),

            const SizedBox(height: 2),

            // 作者
            Text(
              book.author,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textTheme.textStyle.copyWith(
                fontSize: 12,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCover() {
    final coverUrl = book.coverUrl;
    if (coverUrl != null && coverUrl.isNotEmpty) {
      if (_isRemoteCover(coverUrl)) {
        return Image.network(
          coverUrl,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return _buildPlaceholderCover();
          },
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return _buildPlaceholderCover(isLoading: true);
          },
        );
      }

      if (kIsWeb) {
        return _buildPlaceholderCover();
      }

      return Image.file(
        File(coverUrl),
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return _buildPlaceholderCover();
        },
      );
    }
    return _buildPlaceholderCover();
  }

  bool _isRemoteCover(String value) {
    final uri = Uri.tryParse(value);
    final scheme = uri?.scheme.toLowerCase();
    return scheme == 'http' || scheme == 'https';
  }

  Widget _buildPlaceholderCover({bool isLoading = false}) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary.withValues(alpha: 0.8),
            AppColors.secondary
          ],
        ),
      ),
      child: Center(
        child: isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CupertinoActivityIndicator(radius: 12),
              )
            : Padding(
                padding: const EdgeInsets.all(8),
                child: Text(
                  book.title,
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textLight,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
      ),
    );
  }
}
