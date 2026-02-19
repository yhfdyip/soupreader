/// RSS 文章排版样式 helper（对齐 legado `articleStyle` 轮换语义）。
class RssArticleStyleHelper {
  const RssArticleStyleHelper._();

  static const int minStyle = 0;
  static const int maxStyle = 2;
  static const int gridStyle = 2;

  static int normalize(int style) {
    if (style < minStyle || style > maxStyle) {
      return minStyle;
    }
    return style;
  }

  static int nextStyle(int style) {
    final current = normalize(style);
    if (current < maxStyle) return current + 1;
    return minStyle;
  }

  static bool isGridStyle(int style) {
    return normalize(style) == gridStyle;
  }
}
