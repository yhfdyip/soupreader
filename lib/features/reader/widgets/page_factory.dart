import 'package:flutter/widgets.dart';
import 'reader_page_agent.dart';

enum PageRenderSlot { prev, current, next }

class PageRenderPosition {
  final int chapterIndex;
  final int pageIndex;
  final int totalPages;
  final String chapterTitle;

  const PageRenderPosition({
    required this.chapterIndex,
    required this.pageIndex,
    required this.totalPages,
    required this.chapterTitle,
  });
}

/// 页面工厂（对标 Legado TextPageFactory）
/// 管理三章节页面数据，支持跨章节翻页
class PageFactory {
  // 章节数据
  List<ChapterData> _chapters = [];
  int _currentChapterIndex = 0;
  int _currentPageIndex = 0;

  // 分页后的页面内容
  List<String> _prevChapterPages = [];
  List<String> _currentChapterPages = [];
  List<String> _nextChapterPages = [];

  // 分页参数
  double _contentHeight = 0;
  double _contentWidth = 0;
  double _fontSize = 18;
  double _lineHeight = 1.5;
  double _letterSpacing = 0;
  double _paragraphSpacing = 0;
  String? _fontFamily;
  String _paragraphIndent = '';
  TextAlign _textAlign = TextAlign.left;
  double? _titleFontSize;
  TextAlign _titleAlign = TextAlign.left;
  double _titleTopSpacing = 0;
  double _titleBottomSpacing = 0;
  FontWeight? _fontWeight;
  bool _underline = false;
  bool _showTitle = true;

  // 兼容旧调用方：保留单回调入口（建议改用 add/removeContentChangedListener）
  VoidCallback? onContentChanged;
  final Set<VoidCallback> _contentChangedListeners = <VoidCallback>{};

  PageFactory();

  void addContentChangedListener(VoidCallback listener) {
    _contentChangedListeners.add(listener);
  }

  void removeContentChangedListener(VoidCallback listener) {
    _contentChangedListeners.remove(listener);
  }

  void _notifyContentChanged() {
    onContentChanged?.call();
    for (final listener in List<VoidCallback>.from(_contentChangedListeners)) {
      listener();
    }
  }

  /// 初始化章节数据
  void setChapters(List<ChapterData> chapters, int initialChapterIndex) {
    _chapters = chapters;
    _currentChapterIndex = initialChapterIndex.clamp(0, _chapters.length - 1);
    _currentPageIndex = 0;
  }

  /// 更新章节数据，但尽量保持当前阅读位置（章节/页码不重置）。
  ///
  /// 适用于：仅内容格式化发生变化（如缩进、繁简转换、净化标题）时刷新分页。
  void replaceChaptersKeepingPosition(List<ChapterData> chapters) {
    _chapters = chapters;
    if (_chapters.isEmpty) {
      _currentChapterIndex = 0;
      _currentPageIndex = 0;
      _prevChapterPages = [];
      _currentChapterPages = [];
      _nextChapterPages = [];
      return;
    }
    _currentChapterIndex = _currentChapterIndex.clamp(0, _chapters.length - 1);
    if (_currentPageIndex < 0) _currentPageIndex = 0;
  }

  /// 设置布局参数
  void setLayoutParams({
    required double contentHeight,
    required double contentWidth,
    required double fontSize,
    double lineHeight = 1.5,
    double letterSpacing = 0,
    double paragraphSpacing = 0,
    String? fontFamily,
    String paragraphIndent = '',
    TextAlign textAlign = TextAlign.left,
    double? titleFontSize,
    TextAlign titleAlign = TextAlign.left,
    double titleTopSpacing = 0,
    double titleBottomSpacing = 0,
    FontWeight? fontWeight,
    bool underline = false,
    bool showTitle = true,
  }) {
    _contentHeight = contentHeight;
    _contentWidth = contentWidth;
    _fontSize = fontSize;
    _lineHeight = lineHeight;
    _letterSpacing = letterSpacing;
    _paragraphSpacing = paragraphSpacing;
    _fontFamily = fontFamily;
    _paragraphIndent = paragraphIndent;
    _textAlign = textAlign;
    _titleFontSize = titleFontSize;
    _titleAlign = titleAlign;
    _titleTopSpacing = titleTopSpacing;
    _titleBottomSpacing = titleBottomSpacing;
    _fontWeight = fontWeight;
    _underline = underline;
    _showTitle = showTitle;
  }

  /// 分页所有章节
  void paginateAll() {
    _paginateChapter(_currentChapterIndex - 1);
    _paginateChapter(_currentChapterIndex);
    _paginateChapter(_currentChapterIndex + 1);

    // 内容/排版变化后，当前页码可能超出范围，进行一次安全夹取
    if (_currentChapterPages.isEmpty) {
      _currentPageIndex = 0;
    } else {
      _currentPageIndex =
          _currentPageIndex.clamp(0, _currentChapterPages.length - 1);
    }
  }

  void _paginateChapter(int chapterIndex) {
    if (chapterIndex < 0 || chapterIndex >= _chapters.length) return;

    final chapter = _chapters[chapterIndex];
    final pages = ReaderPageAgent.paginateContent(
      chapter.content,
      _contentHeight,
      _contentWidth,
      _fontSize,
      lineHeight: _lineHeight,
      letterSpacing: _letterSpacing,
      paragraphSpacing: _paragraphSpacing,
      fontFamily: _fontFamily,
      title: _showTitle ? chapter.title : null,
      paragraphIndent: _paragraphIndent,
      textAlign: _textAlign,
      titleFontSize: _titleFontSize,
      titleAlign: _titleAlign,
      titleTopSpacing: _titleTopSpacing,
      titleBottomSpacing: _titleBottomSpacing,
      fontWeight: _fontWeight,
      underline: _underline,
    );

    if (chapterIndex == _currentChapterIndex - 1) {
      _prevChapterPages = pages;
    } else if (chapterIndex == _currentChapterIndex) {
      _currentChapterPages = pages;
    } else if (chapterIndex == _currentChapterIndex + 1) {
      _nextChapterPages = pages;
    }
  }

  // ============ 对标 Legado TextPageFactory ============

  /// 是否有上一页（包含上一章）
  bool hasPrev() {
    return _currentPageIndex > 0 || hasPrevChapter();
  }

  /// 是否有下一页（包含下一章）
  bool hasNext() {
    return _currentPageIndex < _currentChapterPages.length - 1 ||
        hasNextChapter();
  }

  /// 是否有上一章
  bool hasPrevChapter() {
    return _currentChapterIndex > 0;
  }

  /// 是否有下一章
  bool hasNextChapter() {
    return _currentChapterIndex < _chapters.length - 1;
  }

  /// 移动到下一页（自动跨章节）
  bool moveToNext() {
    if (_currentPageIndex < _currentChapterPages.length - 1) {
      // 章节内下一页
      _currentPageIndex++;
      _notifyContentChanged();
      return true;
    } else if (hasNextChapter()) {
      // 跨章节：移动到下一章第一页
      _moveToNextChapter();
      return true;
    }
    return false;
  }

  /// 移动到上一页（自动跨章节）
  bool moveToPrev() {
    if (_currentPageIndex > 0) {
      // 章节内上一页
      _currentPageIndex--;
      _notifyContentChanged();
      return true;
    } else if (hasPrevChapter()) {
      // 跨章节：移动到上一章最后一页
      _moveToPrevChapter();
      return true;
    }
    return false;
  }

  void _moveToNextChapter() {
    _currentChapterIndex++;
    _currentPageIndex = 0;

    // 轮换章节页面
    _prevChapterPages = _currentChapterPages;
    _currentChapterPages = _nextChapterPages;
    _nextChapterPages = [];

    // 预加载下一章
    _paginateChapter(_currentChapterIndex + 1);

    _notifyContentChanged();
  }

  void _moveToPrevChapter() {
    _currentChapterIndex--;

    // 轮换章节页面（跳到上一章最后一页）
    _nextChapterPages = _currentChapterPages;
    _currentChapterPages = _prevChapterPages;
    _prevChapterPages = [];

    _currentPageIndex =
        _currentChapterPages.isNotEmpty ? _currentChapterPages.length - 1 : 0;

    // 预加载上一章
    _paginateChapter(_currentChapterIndex - 1);

    _notifyContentChanged();
  }

  /// 跳转到指定章节
  void jumpToChapter(int chapterIndex, {bool goToLastPage = false}) {
    if (chapterIndex < 0 || chapterIndex >= _chapters.length) return;

    _currentChapterIndex = chapterIndex;
    _currentPageIndex = 0;

    // 重新分页三个章节
    _prevChapterPages = [];
    _currentChapterPages = [];
    _nextChapterPages = [];
    paginateAll();

    if (goToLastPage && _currentChapterPages.isNotEmpty) {
      _currentPageIndex = _currentChapterPages.length - 1;
    }

    _notifyContentChanged();
  }

  /// 章节内跳转到指定页（不会跨章节）。
  ///
  /// 用于“滚动/翻页模式切换”时尽量保持阅读位置。
  void jumpToPage(int pageIndex) {
    if (_currentChapterPages.isEmpty) {
      _currentPageIndex = 0;
      _notifyContentChanged();
      return;
    }
    _currentPageIndex = pageIndex.clamp(0, _currentChapterPages.length - 1);
    _notifyContentChanged();
  }

  // ============ 获取三个页面内容 ============

  /// 上一页内容
  String get prevPage {
    if (_currentPageIndex > 0) {
      return _currentChapterPages[_currentPageIndex - 1];
    } else if (_prevChapterPages.isNotEmpty) {
      return _prevChapterPages.last;
    }
    return '';
  }

  /// 当前页内容
  String get curPage {
    if (_currentChapterPages.isEmpty) return '';
    return _currentChapterPages[
        _currentPageIndex.clamp(0, _currentChapterPages.length - 1)];
  }

  /// 下一页内容
  String get nextPage {
    if (_currentPageIndex < _currentChapterPages.length - 1) {
      return _currentChapterPages[_currentPageIndex + 1];
    } else if (_nextChapterPages.isNotEmpty) {
      return _nextChapterPages.first;
    }
    return '';
  }

  // ============ Getters ============

  int get currentChapterIndex => _currentChapterIndex;
  int get totalChapters => _chapters.length;
  int get currentPageIndex => _currentPageIndex;
  int get totalPages => _currentChapterPages.length;
  String get currentChapterTitle =>
      _chapters.isNotEmpty && _currentChapterIndex < _chapters.length
          ? _chapters[_currentChapterIndex].title
          : '';

  PageRenderPosition resolveRenderPosition(PageRenderSlot slot) {
    switch (slot) {
      case PageRenderSlot.current:
        return _resolveCurrentRenderPosition();
      case PageRenderSlot.prev:
        return _resolvePrevRenderPosition();
      case PageRenderSlot.next:
        return _resolveNextRenderPosition();
    }
  }

  PageRenderPosition _resolveCurrentRenderPosition() {
    final total = _currentChapterPages.length;
    final safePage = total <= 0 ? 0 : _currentPageIndex.clamp(0, total - 1);
    final safeChapter = _chapters.isEmpty
        ? 0
        : _currentChapterIndex.clamp(0, _chapters.length - 1);
    return PageRenderPosition(
      chapterIndex: safeChapter,
      pageIndex: safePage,
      totalPages: total,
      chapterTitle: currentChapterTitle,
    );
  }

  PageRenderPosition _resolvePrevRenderPosition() {
    if (_currentPageIndex > 0 && _currentChapterPages.isNotEmpty) {
      final safeChapter = _chapters.isEmpty
          ? 0
          : _currentChapterIndex.clamp(0, _chapters.length - 1);
      return PageRenderPosition(
        chapterIndex: safeChapter,
        pageIndex: _currentPageIndex - 1,
        totalPages: _currentChapterPages.length,
        chapterTitle: currentChapterTitle,
      );
    }

    if (_prevChapterPages.isNotEmpty) {
      final chapterIndex = _chapters.isEmpty
          ? 0
          : (_currentChapterIndex - 1).clamp(0, _chapters.length - 1);
      final title = _chapters.isNotEmpty
          ? _chapters[chapterIndex].title
          : currentChapterTitle;
      return PageRenderPosition(
        chapterIndex: chapterIndex,
        pageIndex: _prevChapterPages.length - 1,
        totalPages: _prevChapterPages.length,
        chapterTitle: title,
      );
    }

    return _resolveCurrentRenderPosition();
  }

  PageRenderPosition _resolveNextRenderPosition() {
    if (_currentPageIndex < _currentChapterPages.length - 1 &&
        _currentChapterPages.isNotEmpty) {
      final safeChapter = _chapters.isEmpty
          ? 0
          : _currentChapterIndex.clamp(0, _chapters.length - 1);
      return PageRenderPosition(
        chapterIndex: safeChapter,
        pageIndex: _currentPageIndex + 1,
        totalPages: _currentChapterPages.length,
        chapterTitle: currentChapterTitle,
      );
    }

    if (_nextChapterPages.isNotEmpty) {
      final chapterIndex = _chapters.isEmpty
          ? 0
          : (_currentChapterIndex + 1).clamp(0, _chapters.length - 1);
      final title = _chapters.isNotEmpty
          ? _chapters[chapterIndex].title
          : currentChapterTitle;
      return PageRenderPosition(
        chapterIndex: chapterIndex,
        pageIndex: 0,
        totalPages: _nextChapterPages.length,
        chapterTitle: title,
      );
    }

    return _resolveCurrentRenderPosition();
  }

  List<String> get currentPages => _currentChapterPages;
}

/// 章节数据
class ChapterData {
  final String title;
  final String content;

  ChapterData({required this.title, required this.content});
}
