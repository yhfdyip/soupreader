import 'package:flutter/cupertino.dart';
import '../../../app/widgets/app_cover_image.dart';
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
    return AppCoverImage(
      urlOrPath: book.coverUrl,
      title: book.title,
      author: book.author,
      width: width,
      height: width * 1.4,
      borderRadius: 8,
      fit: BoxFit.cover,
    );
  }
}
