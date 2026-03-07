import 'package:flutter/cupertino.dart';

import 'boot_build_info_text.dart';

/// 展示启动阶段统一格式的构建信息标签。
class BootBuildInfoLabel extends StatelessWidget {
  /// 是否显示 `BOOT HOST` 前缀。
  final bool includeBootHostPrefix;

  /// 创建一个构建信息标签。
  const BootBuildInfoLabel({
    super.key,
    this.includeBootHostPrefix = false,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      buildBootInfoText(includeBootHostPrefix: includeBootHostPrefix),
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: CupertinoColors.secondaryLabel.resolveFrom(context),
      ),
    );
  }
}
