import 'package:flutter/cupertino.dart';

/// 分组管理入口承载弹窗（对应 legado: menu_group_manage -> GroupManageDialog）。
///
/// 说明：
/// - 本序号仅迁移入口层级与弹窗触发语义；
/// - 分组新增、编辑、显示开关、排序等动作按后续 seq 逐项收敛。
class BookshelfGroupManagePlaceholderDialog extends StatelessWidget {
  const BookshelfGroupManagePlaceholderDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoAlertDialog(
      title: const Text('分组管理（迁移中）'),
      content: const Padding(
        padding: EdgeInsets.only(top: 12),
        child: Text(
          '已按 legado 迁移“分组管理”菜单入口并保持弹窗层级语义。'
          '分组新增、重命名、显示开关、拖拽排序等动作将按后续序号逐项收敛。',
        ),
      ),
      actions: [
        CupertinoDialogAction(
          onPressed: () => Navigator.pop(context),
          child: const Text('完成'),
        ),
      ],
    );
  }
}
