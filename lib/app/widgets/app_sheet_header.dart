import 'package:flutter/cupertino.dart';

/// 标准底部弹窗标题栏：grabber + 居中标题 + 底部分隔线。
///
/// 用于不需要操作按钮的简单 sheet，依赖下滑/点击外部关闭。
class AppSheetHeader extends StatelessWidget {
  final String title;

  const AppSheetHeader({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    final sep = CupertinoColors.separator.resolveFrom(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Center(
          child: Container(
            margin: const EdgeInsets.only(top: 8, bottom: 4),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: sep,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Center(
            child: Text(
              title,
              style: TextStyle(
                color: CupertinoColors.label.resolveFrom(context),
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        Container(height: 0.5, color: sep),
      ],
    );
  }
}
