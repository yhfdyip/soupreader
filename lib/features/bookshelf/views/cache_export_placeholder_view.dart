import 'package:flutter/cupertino.dart';

import 'cache_export_view.dart';

/// 兼容旧引用：缓存/导出页已迁移至 `CacheExportView`。
class CacheExportPlaceholderView extends StatelessWidget {
  const CacheExportPlaceholderView({
    super.key,
    this.initialGroupId,
  });

  final int? initialGroupId;

  @override
  Widget build(BuildContext context) {
    return CacheExportView(initialGroupId: initialGroupId);
  }
}
