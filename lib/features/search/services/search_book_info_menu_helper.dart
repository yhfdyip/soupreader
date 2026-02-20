/// 搜索详情页菜单可见性辅助（对齐 legado `BookInfoActivity.onMenuOpened`）。
class SearchBookInfoMenuHelper {
  const SearchBookInfoMenuHelper._();

  /// legado 仅在 `bookSource.loginUrl` 非空时展示“登录”入口。
  static bool shouldShowLogin({
    required String? loginUrl,
  }) {
    return (loginUrl ?? '').trim().isNotEmpty;
  }
}
