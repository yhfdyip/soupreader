// ignore_for_file: invalid_use_of_protected_member
part of 'simple_reader_view.dart';

extension _SimpleReaderBookmarkX on _SimpleReaderViewState {
  Future<void> _openAddBookmarkDialog() async {
    final draft = _buildBookmarkDraft();
    await _openBookmarkEditorFromDraft(draft);
  }

  Future<void> _openBookmarkEditorFromSelectedText(String selectedText) async {
    final baseDraft = _buildBookmarkDraft();
    if (baseDraft == null) {
      _showToast('创建书签失败');
      return;
    }
    final draft = _ReaderBookmarkDraft(
      chapterTitle: baseDraft.chapterTitle,
      chapterPos: baseDraft.chapterPos,
      pageText: selectedText.trim(),
    );
    await _openBookmarkEditorFromDraft(draft);
  }

  Future<void> _openBookmarkEditorFromDraft(_ReaderBookmarkDraft? draft) async {
    if (draft == null || !mounted) return;
    final result = await _showBookmarkEditorDialog(draft);
    if (result == null) return;

    try {
      await _bookmarkRepo.addBookmark(
        bookId: widget.bookId,
        bookName: widget.bookTitle,
        bookAuthor: _bookAuthor,
        chapterIndex: _currentChapterIndex,
        chapterTitle: draft.chapterTitle,
        chapterPos: draft.chapterPos,
        content: _composeBookmarkPreview(
          bookText: result.bookText,
          note: result.note,
        ),
      );
      _updateBookmarkStatus();
    } catch (e) {
      if (!mounted) return;
      _showToast('书签操作失败：$e');
    }
  }

  _ReaderBookmarkDraft? _buildBookmarkDraft() {
    if (_chapters.isEmpty ||
        _currentChapterIndex < 0 ||
        _currentChapterIndex >= _chapters.length) {
      return null;
    }
    final fallbackTitle = _chapters[_currentChapterIndex].title.trim();
    final chapterTitle =
        _currentTitle.trim().isNotEmpty ? _currentTitle.trim() : fallbackTitle;
    return _ReaderBookmarkDraft(
      chapterTitle: chapterTitle.isEmpty
          ? '第 ${_currentChapterIndex + 1} 章'
          : chapterTitle,
      chapterPos: _encodeCurrentBookmarkChapterPos(),
      pageText: _resolveCurrentBookmarkText(),
    );
  }

  Future<_ReaderBookmarkEditResult?> _showBookmarkEditorDialog(
    _ReaderBookmarkDraft draft,
  ) async {
    final bookTextController = TextEditingController(text: draft.pageText);
    final noteController = TextEditingController();
    final result = await showCupertinoBottomDialog<_ReaderBookmarkEditResult>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: const Text('书签'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              draft.chapterTitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 10),
            CupertinoTextField(
              controller: bookTextController,
              placeholder: '内容',
              maxLines: 3,
            ),
            const SizedBox(height: 8),
            CupertinoTextField(
              controller: noteController,
              placeholder: '备注',
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () {
              Navigator.pop(
                dialogContext,
                _ReaderBookmarkEditResult(
                  bookText: bookTextController.text,
                  note: noteController.text,
                ),
              );
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
    bookTextController.dispose();
    noteController.dispose();
    return result;
  }

  String _resolveCurrentBookmarkText() {
    final pageText = _pageFactory.curPage.trim();
    if (pageText.isNotEmpty) {
      return pageText;
    }
    final content = _currentContent.trim();
    if (content.isEmpty) {
      return '';
    }
    final progress = _getChapterProgress().clamp(0.0, 1.0).toDouble();
    final center =
        (content.length * progress).round().clamp(0, content.length).toInt();
    final start = (center - 90).clamp(0, content.length).toInt();
    final end = (start + 180).clamp(0, content.length).toInt();
    return content.substring(start, end).trim();
  }

  String _composeBookmarkPreview({
    required String bookText,
    required String note,
  }) {
    final trimmedText = bookText.trim();
    final trimmedNote = note.trim();
    if (trimmedText.isEmpty) {
      return trimmedNote;
    }
    if (trimmedNote.isEmpty) {
      return trimmedText;
    }
    return '$trimmedText\n\n笔记：$trimmedNote';
  }

  int _encodeCurrentBookmarkChapterPos() {
    return (_getChapterProgress().clamp(0.0, 1.0) * 10000).round();
  }

  double _decodeBookmarkChapterProgress(int chapterPos) {
    return (chapterPos / 10000.0).clamp(0.0, 1.0).toDouble();
  }

  /// 更新书签状态
  void _updateBookmarkStatus() {
    if (!mounted) return;
    bool hasBookmark = false;
    try {
      hasBookmark =
          _bookmarkRepo.hasBookmark(widget.bookId, _currentChapterIndex);
    } catch (_) {
      hasBookmark = false;
    }
    if (_hasBookmarkAtCurrent == hasBookmark) return;
    setState(() {
      _hasBookmarkAtCurrent = hasBookmark;
    });
  }

  Future<ChapterCacheInfo> _clearBookCache() async {
    final info = await _chapterRepo.clearDownloadedCacheForBook(widget.bookId);

    if (!mounted) return info;

    setState(() {
      // 保持当前阅读不中断：不强行清空当前章节的内存内容，但把“已下载标记”与缓存阶段清空。
      _replaceStageCache.clear();

      final currentId =
          _chapters.isNotEmpty ? _chapters[_currentChapterIndex].id : null;
      _chapters = _chapters.map((chapter) {
        if (!chapter.isDownloaded) return chapter;
        final keepContent = chapter.id == currentId ? chapter.content : null;
        return chapter.copyWith(isDownloaded: false, content: keepContent);
      }).toList(growable: false);
    });

    _syncPageFactoryChapters(
      keepPosition: _settings.pageTurnMode != PageTurnMode.scroll,
    );
    return info;
  }

  String _normalizeReaderErrorMessage(Object error) {
    final raw = error.toString().trim();
    const stateErrorPrefix = 'Bad state:';
    if (raw.startsWith(stateErrorPrefix)) {
      final message = raw.substring(stateErrorPrefix.length).trim();
      return message.isEmpty ? raw : message;
    }
    return raw;
  }

  String _legacyUpdateTocErrorMessage({
    required bool isLocalBook,
    required Object error,
  }) {
    if (!isLocalBook) {
      return '加载目录失败';
    }
    final message = _normalizeReaderErrorMessage(error);
    if (message.isEmpty) {
      return 'LoadTocError:unknown';
    }
    if (message.startsWith('LoadTocError:')) {
      return message;
    }
    return 'LoadTocError:$message';
  }

  String _extractCatalogUpdateFailureReason(List<String> failedDetails) {
    if (failedDetails.isEmpty) return '加载目录失败';
    final raw = failedDetails.first.trim();
    final separatorIndex = raw.indexOf('：');
    if (separatorIndex <= -1 || separatorIndex >= raw.length - 1) {
      return raw.isEmpty ? '加载目录失败' : raw;
    }
    final reason = raw.substring(separatorIndex + 1).trim();
    return reason.isEmpty ? '加载目录失败' : reason;
  }

  String _resolveLocalBookFileExtension(Book book) {
    final localPath = (book.localPath ?? '').trim();
    if (localPath.isNotEmpty) {
      return p.extension(localPath).toLowerCase();
    }

    final rawBookUrl = (book.bookUrl ?? '').trim();
    if (rawBookUrl.isEmpty) return '';
    final uri = Uri.tryParse(rawBookUrl);
    if (uri != null && uri.hasScheme && uri.scheme == 'file') {
      final filePath = uri.toFilePath();
      if (filePath.trim().isNotEmpty) {
        return p.extension(filePath).toLowerCase();
      }
    }
    return p.extension(rawBookUrl).toLowerCase();
  }

  Future<void> _clearLocalCatalogCacheBeforeRefresh() async {
    if (!widget.isEphemeral) {
      await _chapterRepo.clearDownloadedCacheForBook(widget.bookId);
    }

    if (!mounted || _chapters.isEmpty) {
      return;
    }

    setState(() {
      _replaceStageCache.clear();
      _catalogDisplayTitleCacheByChapterId.clear();
      _chapterContentInFlight.clear();
      _chapters = _chapters
          .map(
            (chapter) => chapter.copyWith(
              isDownloaded: false,
              content: null,
            ),
          )
          .toList(growable: false);
    });
    _syncPageFactoryChapters(
      keepPosition: _settings.pageTurnMode != PageTurnMode.scroll,
    );
  }

  Future<List<Chapter>> _applyLocalRefreshedCatalog({
    required SearchBookInfoLocalRefreshResult refreshed,
  }) async {
    final newChapters = refreshed.chapters;
    if (newChapters.isEmpty) {
      throw StateError('LoadTocError:重解析后章节为空');
    }

    final previousRawTitle = _chapters.isEmpty
        ? _currentTitle
        : _chapters[_currentChapterIndex.clamp(0, _chapters.length - 1)].title;
    final targetIndex = ReaderSourceSwitchHelper.resolveTargetChapterIndex(
      newChapters: newChapters,
      currentChapterTitle: previousRawTitle,
      currentChapterIndex: _currentChapterIndex,
      oldChapterCount: _chapters.length,
    );

    if (!widget.isEphemeral) {
      await _chapterRepo.clearChaptersForBook(widget.bookId);
      await _chapterRepo.addChapters(newChapters);
      await _bookRepo.updateBook(
        refreshed.book.copyWith(
          totalChapters: newChapters.length,
          latestChapter: newChapters.last.title,
          currentChapter: targetIndex,
        ),
      );
    }

    if (!mounted) return newChapters;
    setState(() {
      _bookAuthor = refreshed.book.author;
      _bookCoverUrl = refreshed.book.coverUrl;
      _replaceStageCache.clear();
      _catalogDisplayTitleCacheByChapterId.clear();
      _chapterContentInFlight.clear();
      _chapters = newChapters;
      _chapterVipByUrl.clear();
      _chapterPayByUrl.clear();
    });
    await _loadChapter(
      _clampChapterIndexToReadableRange(targetIndex),
      restoreOffset: true,
    );
    return newChapters;
  }

  Future<List<Chapter>> _refreshLocalCatalogFromSource(Book book) async {
    try {
      final extension = _resolveLocalBookFileExtension(book);
      if (extension == '.epub' || extension == '.mobi') {
        await _clearLocalCatalogCacheBeforeRefresh();
      }

      final preferredCharset = _readerCharsetService.getBookCharset(
            widget.bookId,
          ) ??
          ReaderCharsetService.defaultCharset;
      final refreshed = await SearchBookInfoRefreshHelper.refreshLocalBook(
        book: book,
        preferredTxtCharset: preferredCharset,
        splitLongChapter: _settingsService.getBookSplitLongChapter(
          widget.bookId,
        ),
        txtTocRuleRegex: _settingsService.getBookTxtTocRule(widget.bookId),
      );
      return _applyLocalRefreshedCatalog(refreshed: refreshed);
    } catch (error) {
      final message = _normalizeReaderErrorMessage(error);
      if (message.startsWith('LoadTocError:')) {
        throw StateError(message);
      }
      throw StateError(
        message.isEmpty ? 'LoadTocError:unknown' : 'LoadTocError:$message',
      );
    }
  }

  Future<List<Chapter>> _refreshCatalogFromSource() async {
    final book = _bookRepo.getBookById(widget.bookId);
    if (book == null) {
      throw StateError('书籍信息不存在');
    }
    if (book.isLocal) {
      return _refreshLocalCatalogFromSource(book);
    }

    final summary = await _catalogUpdateService.updateBooks([book]);
    if (summary.failedCount > 0) {
      final reason = _extractCatalogUpdateFailureReason(summary.failedDetails);
      ExceptionLogService().record(
        node: 'reader.menu.update_toc.online_failed',
        message: '阅读页在线更新目录失败',
        error: reason,
        context: <String, dynamic>{
          'bookId': widget.bookId,
          'bookTitle': widget.bookTitle,
          'sourceUrl': _currentSourceUrl,
          'failedDetails': summary.failedDetails,
        },
      );
      throw StateError('加载目录失败');
    }
    if (summary.updateCandidateCount <= 0) {
      throw StateError('加载目录失败');
    }

    final updated = _chapterRepo.getChaptersForBook(widget.bookId);
    if (updated.isEmpty) {
      throw StateError('加载目录失败');
    }

    if (!mounted) return updated;

    final maxChapter = updated.length - 1;
    final refreshedBook = _bookRepo.getBookById(widget.bookId);
    setState(() {
      _chapters = updated;
      _currentChapterIndex = _currentChapterIndex.clamp(0, maxChapter).toInt();
      _currentTitle = _postProcessTitle(updated[_currentChapterIndex].title);
      if (refreshedBook != null) {
        _bookAuthor = refreshedBook.author;
        _bookCoverUrl = refreshedBook.coverUrl;
        _currentSourceUrl =
            (refreshedBook.sourceUrl ?? refreshedBook.sourceId ?? '').trim();
      }
      _chapterVipByUrl.clear();
      _chapterPayByUrl.clear();
    });
    _refreshCurrentSourceName();
    _syncPageFactoryChapters(
      keepPosition: _settings.pageTurnMode != PageTurnMode.scroll,
    );

    return updated;
  }

  Future<void> _applyCatalogSplitLongChapterSetting(bool enabled) async {
    final bookId = widget.bookId.trim();
    if (bookId.isNotEmpty && !widget.isEphemeral) {
      await _settingsService.saveBookSplitLongChapter(bookId, enabled);
    }

    if (!_isCurrentBookLocalTxt()) {
      return;
    }

    final book = _bookRepo.getBookById(widget.bookId);
    if (book == null) {
      throw StateError('书籍信息不存在');
    }

    if (!mounted) return;
    setState(() => _isLoadingChapter = true);
    try {
      final charset = _readerCharsetService.getBookCharset(widget.bookId) ??
          ReaderCharsetService.defaultCharset;
      await _reparseLocalTxtBookWithCharset(
        book: book,
        charset: charset,
        splitLongChapter: enabled,
      );
    } finally {
      if (mounted) {
        setState(() => _isLoadingChapter = false);
      }
    }
  }

  void _showChapterList() {
    if (_showSearchMenu) {
      _setSearchMenuVisible(false);
    }
    if (_showMenu) {
      _setReaderMenuVisible(false);
    }
    showCupertinoBottomSheetDialog(
      context: context,
      builder: (popupContext) => ReaderCatalogSheet(
        bookId: widget.bookId,
        bookTitle: widget.bookTitle,
        bookAuthor: _bookAuthor,
        coverUrl: _bookCoverUrl,
        chapters: _effectiveReadableChapters(),
        currentChapterIndex: _currentChapterIndex,
        bookmarks: _bookmarkRepo.getBookmarksForBook(widget.bookId),
        onClearBookCache: _clearBookCache,
        onRefreshCatalog: _refreshCatalogFromSource,
        onChapterSelected: (index) {
          Navigator.pop(popupContext);
          _loadChapter(index);
        },
        onBookmarkSelected: (bookmark) {
          Navigator.pop(popupContext);
          final progress = _decodeBookmarkChapterProgress(bookmark.chapterPos);
          _loadChapter(
            bookmark.chapterIndex,
            restoreOffset: true,
            targetChapterProgress: progress,
          );
        },
        onDeleteBookmark: (bookmark) async {
          await _bookmarkRepo.removeBookmark(bookmark.id);
          _updateBookmarkStatus();
        },
        isLocalTxtBook: _isCurrentBookLocalTxt(),
        initialUseReplace: _tocUiUseReplace,
        initialLoadWordCount: _tocUiLoadWordCount,
        initialSplitLongChapter: _tocUiSplitLongChapter,
        onUseReplaceChanged: (value) {
          _tocUiUseReplace = value;
          _catalogDisplayTitleCacheByChapterId.clear();
          unawaited(_settingsService.saveTocUiUseReplace(value));
        },
        onLoadWordCountChanged: (value) {
          _tocUiLoadWordCount = value;
          unawaited(_settingsService.saveTocUiLoadWordCount(value));
        },
        onSplitLongChapterChanged: (value) {
          _tocUiSplitLongChapter = value;
        },
        onApplySplitLongChapter: _applyCatalogSplitLongChapterSetting,
        onOpenLogs: _openExceptionLogsFromReader,
        onExportBookmark: () async {
          await _exportBookmarksFromReader(markdown: false);
        },
        onExportBookmarkMarkdown: () async {
          await _exportBookmarksFromReader(markdown: true);
        },
        onEditTocRule: () {
          Navigator.pop(popupContext);
          unawaited(_showTxtTocRuleDialogFromMenu());
        },
        initialDisplayTitlesByIndex: _buildCatalogInitialDisplayTitlesByIndex(),
        resolveDisplayTitle: _resolveCatalogDisplayTitle,
      ),
    );
  }

}
