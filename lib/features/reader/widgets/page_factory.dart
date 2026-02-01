import 'package:flutter/material.dart';
import 'reader_page_agent.dart';

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

  // 回调
  VoidCallback? onContentChanged;

  PageFactory();

  /// 初始化章节数据
  void setChapters(List<ChapterData> chapters, int initialChapterIndex) {
    _chapters = chapters;
    _currentChapterIndex = initialChapterIndex.clamp(0, _chapters.length - 1);
    _currentPageIndex = 0;
  }

  /// 设置布局参数
  void setLayoutParams({
    required double contentHeight,
    required double contentWidth,
    required double fontSize,
    double lineHeight = 1.5,
    double letterSpacing = 0,
  }) {
    _contentHeight = contentHeight;
    _contentWidth = contentWidth;
    _fontSize = fontSize;
    _lineHeight = lineHeight;
    _letterSpacing = letterSpacing;
  }

  /// 分页所有章节
  void paginateAll() {
    _paginateChapter(_currentChapterIndex - 1);
    _paginateChapter(_currentChapterIndex);
    _paginateChapter(_currentChapterIndex + 1);
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
      title: chapter.title,
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
      onContentChanged?.call();
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
      onContentChanged?.call();
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

    onContentChanged?.call();
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

    onContentChanged?.call();
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

    onContentChanged?.call();
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
  int get currentPageIndex => _currentPageIndex;
  int get totalPages => _currentChapterPages.length;
  String get currentChapterTitle =>
      _chapters.isNotEmpty && _currentChapterIndex < _chapters.length
          ? _chapters[_currentChapterIndex].title
          : '';

  List<String> get currentPages => _currentChapterPages;
}

/// 章节数据
class ChapterData {
  final String title;
  final String content;

  ChapterData({required this.title, required this.content});
}
