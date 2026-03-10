// ignore_for_file: invalid_use_of_protected_member
part of 'bookshelf_view.dart';

extension _BookshelfManageX on _BookshelfViewState {
  Future<void> _showAddBookByUrlDialog() async {
    final controller = TextEditingController();
    await showCupertinoBottomDialog<void>(
      context: context,
      builder: (dialogContext) {
        return CupertinoAlertDialog(
          title: const Text('添加书籍网址'),
          content: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: CupertinoTextField(
              controller: controller,
              placeholder: 'url',
              autofocus: true,
              maxLines: 4,
            ),
          ),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('取消'),
            ),
            CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: () {
                final input = controller.text;
                Navigator.pop(dialogContext);
                unawaited(_addBooksByUrl(input));
              },
              child: const Text('确定'),
            ),
          ],
        );
      },
    );
    controller.dispose();
  }

  Future<void> _exportBookshelf() async {
    final result = await _bookshelfIo.exportToFile(_books);
    if (!result.success) {
      if (result.cancelled) return;
      _showMessage(result.errorMessage ?? '导出书籍出错');
      return;
    }
    final hint = result.outputPathOrHint;
    if (hint == null || hint.isEmpty) {
      unawaited(showAppToast(context, message: '导出成功'));
      return;
    }
    _showExportSuccessDialog(hint);
  }

  void _showExportSuccessDialog(String pathOrHint) {
    showCupertinoBottomDialog<void>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: const Text('导出成功'),
        content: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(pathOrHint),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: pathOrHint));
              if (!mounted) return;
              Navigator.pop(dialogContext);
              unawaited(showAppToast(context, message: '已复制到剪贴板'));
            },
            child: const Text('复制'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('好'),
          ),
        ],
      ),
    );
  }

  Future<void> _showImportBookshelfDialog() async {
    final controller = TextEditingController();
    await showCupertinoBottomDialog<void>(
      context: context,
      builder: (dialogContext) {
        return CupertinoAlertDialog(
          title: const Text('导入书单'),
          content: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: CupertinoTextField(
              controller: controller,
              placeholder: 'url/json',
              autofocus: true,
              maxLines: 4,
            ),
          ),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('取消'),
            ),
            CupertinoDialogAction(
              onPressed: () {
                Navigator.pop(dialogContext);
                unawaited(_importBookshelfFromFile());
              },
              child: const Text('选择文件'),
            ),
            CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: () {
                final rawInput = controller.text;
                Navigator.pop(dialogContext);
                unawaited(_importBookshelfFromInput(rawInput));
              },
              child: const Text('确定'),
            ),
          ],
        );
      },
    );
    controller.dispose();
  }

  Future<void> _importBookshelfFromInput(String rawInput) async {
    if (_isImporting) return;
    setState(() => _isImporting = true);

    final parseResult = await _bookshelfIo.importFromInput(rawInput);
    await _startBooklistImport(parseResult);
  }

  Future<void> _importBookshelfFromFile() async {
    if (_isImporting) return;
    setState(() => _isImporting = true);

    final parseResult = await _bookshelfIo.importFromFile();
    await _startBooklistImport(parseResult);
  }

  Future<void> _startBooklistImport(
    BookshelfImportParseResult parseResult,
  ) async {
    if (!parseResult.success) {
      if (mounted) setState(() => _isImporting = false);
      if (parseResult.cancelled) return;
      _showMessage(parseResult.errorMessage ?? '导入失败');
      return;
    }

    final progress = ValueNotifier<BooklistImportProgress>(
      BooklistImportProgress(
        done: 0,
        total: parseResult.items.length,
        currentName: '',
        currentSource: '',
      ),
    );

    if (!mounted) return;
    showCupertinoBottomDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('正在导入书单'),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: ValueListenableBuilder<BooklistImportProgress>(
            valueListenable: progress,
            builder: (context, p, _) {
              final name = p.currentName.isEmpty ? '—' : p.currentName;
              final src = p.currentSource.isEmpty ? '—' : p.currentSource;
              return Column(
                children: [
                  const CupertinoActivityIndicator(),
                  const SizedBox(height: 10),
                  Text('进度：${p.done}/${p.total}'),
                  const SizedBox(height: 6),
                  Text('当前：$name'),
                  const SizedBox(height: 6),
                  Text('书源：$src'),
                ],
              );
            },
          ),
        ),
      ),
    );

    final summary = await _booklistImporter.importBySearching(
      parseResult.items,
      onProgress: (p) => progress.value = p,
    );

    if (mounted) {
      Navigator.pop(context);
      setState(() => _isImporting = false);
      _loadBooks();

      final details = summary.errors.isEmpty
          ? ''
          : '\n\n失败详情（最多 5 条）：\n${summary.errors.take(5).join('\n')}';
      _showMessage('${summary.summaryText}$details');
    }
    progress.dispose();
  }

  String _layoutLabel(int index) {
    switch (_normalizeLayoutIndex(index)) {
      case 0:
        return '列表';
      case 1:
        return '三列网格';
      case 2:
        return '四列网格';
      case 3:
        return '五列网格';
      case 4:
        return '六列网格';
      default:
        return '列表';
    }
  }

  String _legacySortLabel(int index) {
    switch (_normalizeSortIndex(index)) {
      case 0:
        return '最近阅读';
      case 1:
        return '最近更新';
      case 2:
        return '书名';
      case 3:
        return '手动';
      case 4:
        return '综合';
      case 5:
        return '作者';
      default:
        return '最近阅读';
    }
  }


  Future<void> _applyLayoutConfig({
    required int groupStyle,
    required bool showUnread,
    required bool showLastUpdateTime,
    required bool showWaitUpCount,
    required bool showFastScroller,
    required int layoutIndex,
    required int sortIndex,
  }) async {
    final normalizedGroupStyle = groupStyle.clamp(0, 1);
    final normalizedLayout = _normalizeLayoutIndex(layoutIndex);
    final normalizedSort = _normalizeSortIndex(sortIndex);
    final nextSettings = _settingsService.appSettings.copyWith(
      bookshelfGroupStyle: normalizedGroupStyle,
      bookshelfShowUnread: showUnread,
      bookshelfShowLastUpdateTime: showLastUpdateTime,
      bookshelfShowWaitUpCount: showWaitUpCount,
      bookshelfShowFastScroller: showFastScroller,
      bookshelfLayoutIndex: normalizedLayout,
      bookshelfViewMode: bookshelfViewModeFromLayoutIndex(normalizedLayout),
      bookshelfSortIndex: normalizedSort,
      bookshelfSortMode: bookshelfSortModeFromLegacyIndex(normalizedSort),
    );
    await _settingsService.saveAppSettings(nextSettings);
    if (!mounted) return;
    setState(() {
      _isGridView = normalizedLayout > 0;
      _gridCrossAxisCount = _gridColumnsForLayoutIndex(normalizedLayout);
      if (normalizedGroupStyle != 1) {
        _selectedGroupId = BookshelfBookGroup.idRoot;
      }
    });
    await _reloadBookGroupContext(showError: true);
    _loadBooks();
  }

  Future<void> _showLayoutConfigDialog() async {
    final settings = _settingsService.appSettings;
    var groupStyle = settings.bookshelfGroupStyle.clamp(0, 1);
    var showUnread = settings.bookshelfShowUnread;
    var showLastUpdateTime = settings.bookshelfShowLastUpdateTime;
    var showWaitUpCount = settings.bookshelfShowWaitUpCount;
    var showFastScroller = settings.bookshelfShowFastScroller;
    var layoutIndex = _normalizeLayoutIndex(settings.bookshelfLayoutIndex);
    var sortIndex = _normalizeSortIndex(settings.bookshelfSortIndex);

    await showCupertinoBottomSheetDialog<void>(
      context: context,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final isDark =
                CupertinoTheme.of(context).brightness == Brightness.dark;
            final bg = isDark
                ? CupertinoColors.systemGroupedBackground.resolveFrom(context).darkColor
                : CupertinoColors.systemGroupedBackground.resolveFrom(context).color;
            final h = MediaQuery.sizeOf(context).height;
            final secondaryLabel =
                CupertinoColors.secondaryLabel.resolveFrom(context);
            final primaryColor = CupertinoTheme.of(context).primaryColor;

            Widget hdr(String t) => Text(
                  t,
                  style: TextStyle(
                    color: secondaryLabel,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                );

            Widget sw(String title, bool value, ValueChanged<bool> cb) =>
                AppListTile(
                  title: Text(
                    title,
                    style: TextStyle(
                      color: CupertinoColors.label.resolveFrom(context),
                      fontSize: 15,
                    ),
                  ),
                  trailing: CupertinoSwitch(
                    value: value,
                    activeTrackColor: primaryColor,
                    onChanged: cb,
                  ),
                  onTap: () => cb(!value),
                  showChevron: false,
                );

            Widget choiceRow(String label, bool selected, VoidCallback onTap) =>
                AppListTile(
                  title: Text(
                    label,
                    style: TextStyle(
                      color: CupertinoColors.label.resolveFrom(context),
                      fontSize: 15,
                    ),
                  ),
                  trailing: selected
                      ? Icon(
                          CupertinoIcons.check_mark,
                          size: 17,
                          color: primaryColor,
                        )
                      : null,
                  onTap: onTap,
                  showChevron: false,
                );

            return ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppDesignTokens.radiusSheet),
              ),
              child: Container(
                color: bg,
                child: SafeArea(
                  top: false,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const AppSheetHeader(title: '书架布局'),
                      SizedBox(
                        height: h * 0.62,
                        child: ListView(
                          padding: const EdgeInsets.only(bottom: 24),
                          children: [
                            AppListSection(
                              header: hdr('分组样式'),
                              hasLeading: false,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 10,
                                  ),
                                  child: CupertinoSlidingSegmentedControl<int>(
                                    groupValue: groupStyle,
                                    children: const {
                                      0: Padding(
                                        padding: EdgeInsets.symmetric(vertical: 7),
                                        child: Text('样式一', textAlign: TextAlign.center),
                                      ),
                                      1: Padding(
                                        padding: EdgeInsets.symmetric(vertical: 7),
                                        child: Text('样式二', textAlign: TextAlign.center),
                                      ),
                                    },
                                    onValueChanged: (value) {
                                      if (value == null) return;
                                      setDialogState(() => groupStyle = value);
                                    },
                                  ),
                                ),
                              ],
                            ),
                            AppListSection(
                              header: hdr('显示'),
                              hasLeading: false,
                              children: [
                                sw('显示未读数量', showUnread,
                                    (v) => setDialogState(() => showUnread = v)),
                                sw('显示最新更新时间', showLastUpdateTime,
                                    (v) => setDialogState(() => showLastUpdateTime = v)),
                                sw('显示待更新计数', showWaitUpCount,
                                    (v) => setDialogState(() => showWaitUpCount = v)),
                                sw('显示快速滚动条', showFastScroller,
                                    (v) => setDialogState(() => showFastScroller = v)),
                              ],
                            ),
                            AppListSection(
                              header: hdr('视图'),
                              hasLeading: false,
                              children: [
                                for (var i = 0; i <= 4; i++)
                                  choiceRow(
                                    _layoutLabel(i),
                                    layoutIndex == i,
                                    () => setDialogState(() => layoutIndex = i),
                                  ),
                              ],
                            ),
                            AppListSection(
                              header: hdr('排序'),
                              hasLeading: false,
                              children: [
                                for (var i = 0; i <= 5; i++)
                                  choiceRow(
                                    _legacySortLabel(i),
                                    sortIndex == i,
                                    () => setDialogState(() => sortIndex = i),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: CupertinoButton(
                                color: CupertinoColors.systemFill.resolveFrom(context)
                                    .resolveFrom(context),
                                borderRadius: BorderRadius.circular(
                                    AppDesignTokens.radiusControl),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                onPressed: () => Navigator.pop(sheetContext),
                                child: Text(
                                  '取消',
                                  style: TextStyle(
                                    color: CupertinoColors.label.resolveFrom(context)
                                        .resolveFrom(context),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: CupertinoButton(
                                color: primaryColor,
                                borderRadius: BorderRadius.circular(
                                    AppDesignTokens.radiusControl),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                onPressed: () async {
                                  Navigator.pop(sheetContext);
                                  await _applyLayoutConfig(
                                    groupStyle: groupStyle,
                                    showUnread: showUnread,
                                    showLastUpdateTime: showLastUpdateTime,
                                    showWaitUpCount: showWaitUpCount,
                                    showFastScroller: showFastScroller,
                                    layoutIndex: layoutIndex,
                                    sortIndex: sortIndex,
                                  );
                                },
                                child: const Text(
                                  '确定',
                                  style: TextStyle(
                                    color: CupertinoColors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
  Future<void> _openAppLogDialog() async {
    await showAppLogDialog(context);
  }

  String _updateCatalogMenuText() {
    if (_isUpdatingCatalog) {
      return '更新目录（进行中）';
    }
    return '更新目录';
  }

  Future<void> _showMoreMenu() async {
    final action = await showAppPopoverMenu<_BookshelfMoreMenuAction>(
      context: context,
      anchorKey: _moreMenuKey,
      items: [
        AppPopoverMenuItem(
          value: _BookshelfMoreMenuAction.updateCatalog,
          icon: CupertinoIcons.refresh,
          label: _updateCatalogMenuText(),
        ),
        const AppPopoverMenuItem(
          value: _BookshelfMoreMenuAction.importLocal,
          icon: CupertinoIcons.folder,
          label: '添加本地',
        ),
        const AppPopoverMenuItem(
          value: _BookshelfMoreMenuAction.remoteBook,
          icon: CupertinoIcons.cloud,
          label: '远程书籍',
        ),
        AppPopoverMenuItem(
          value: _BookshelfMoreMenuAction.selectFolder,
          icon: CupertinoIcons.folder_open,
          label: _isSelectingImportFolder ? '选择文件夹（进行中）' : '选择文件夹',
        ),
        const AppPopoverMenuItem(
          value: _BookshelfMoreMenuAction.scanFolder,
          icon: CupertinoIcons.wand_rays,
          label: '智能扫描',
        ),
        const AppPopoverMenuItem(
          value: _BookshelfMoreMenuAction.importFileNameRule,
          icon: CupertinoIcons.doc_text,
          label: '导入文件名',
        ),
        const AppPopoverMenuItem(
          value: _BookshelfMoreMenuAction.addUrl,
          icon: CupertinoIcons.globe,
          label: '添加网址',
        ),
        const AppPopoverMenuItem(
          value: _BookshelfMoreMenuAction.manage,
          icon: CupertinoIcons.square_list,
          label: '书架管理',
        ),
        const AppPopoverMenuItem(
          value: _BookshelfMoreMenuAction.cacheExport,
          icon: CupertinoIcons.arrow_down_doc,
          label: '缓存/导出',
        ),
        const AppPopoverMenuItem(
          value: _BookshelfMoreMenuAction.groupManage,
          icon: CupertinoIcons.folder_badge_plus,
          label: '分组管理',
        ),
        const AppPopoverMenuItem(
          value: _BookshelfMoreMenuAction.layout,
          icon: CupertinoIcons.rectangle_grid_2x2,
          label: '书架布局',
        ),
        const AppPopoverMenuItem(
          value: _BookshelfMoreMenuAction.exportBooklist,
          icon: CupertinoIcons.square_arrow_up,
          label: '导出书单',
        ),
        const AppPopoverMenuItem(
          value: _BookshelfMoreMenuAction.importBooklist,
          icon: CupertinoIcons.square_arrow_down,
          label: '导入书单',
        ),
        const AppPopoverMenuItem(
          value: _BookshelfMoreMenuAction.log,
          icon: CupertinoIcons.doc_plaintext,
          label: '日志',
        ),
      ],
    );
    if (!mounted || action == null) return;
    switch (action) {
      case _BookshelfMoreMenuAction.updateCatalog:
        _updateBookshelfCatalog();
        break;
      case _BookshelfMoreMenuAction.importLocal:
        _importLocalBook();
        break;
      case _BookshelfMoreMenuAction.remoteBook:
        _openRemoteBook();
        break;
      case _BookshelfMoreMenuAction.selectFolder:
        _selectImportFolder();
        break;
      case _BookshelfMoreMenuAction.scanFolder:
        _scanImportFolder();
        break;
      case _BookshelfMoreMenuAction.importFileNameRule:
        _showImportFileNameRuleDialog();
        break;
      case _BookshelfMoreMenuAction.addUrl:
        _showAddBookByUrlDialog();
        break;
      case _BookshelfMoreMenuAction.manage:
        _openBookshelfManage();
        break;
      case _BookshelfMoreMenuAction.cacheExport:
        _openCacheExport();
        break;
      case _BookshelfMoreMenuAction.groupManage:
        _openBookshelfGroupManageDialog();
        break;
      case _BookshelfMoreMenuAction.layout:
        _showLayoutConfigDialog();
        break;
      case _BookshelfMoreMenuAction.exportBooklist:
        _exportBookshelf();
        break;
      case _BookshelfMoreMenuAction.importBooklist:
        _showImportBookshelfDialog();
        break;
      case _BookshelfMoreMenuAction.log:
        _openAppLogDialog();
        break;
    }
  }

  String _buildCatalogUpdateSummaryMessage(
      BookshelfCatalogUpdateSummary summary) {
    final lines = <String>[];
    if (summary.updateCandidateCount <= 0) {
      return '当前书架没有可更新的网络书籍';
    }

    lines.add(
      '目录更新完成：成功 ${summary.successCount} 本，失败 ${summary.failedCount} 本'
      '${summary.skippedCount > 0 ? '，跳过 ${summary.skippedCount} 本' : ''}',
    );
    if (summary.failedDetails.isNotEmpty) {
      lines.add('');
      lines.add('失败详情（最多 5 条）：');
      lines.addAll(summary.failedDetails.take(5));
    }
    return lines.join('\n');
  }

  Future<void> _updateBookshelfCatalog() async {
    if (_isImporting || _isUpdatingCatalog) return;

    final snapshot = _displayBooks();
    final remoteCandidates =
        snapshot.where((book) => !book.isLocal).toList(growable: false);
    if (remoteCandidates.isEmpty) {
      _showMessage('当前书架没有可更新的网络书籍');
      return;
    }
    final candidates = remoteCandidates
        .where((book) => _settingsService.getBookCanUpdate(book.id))
        .toList(growable: false);
    if (candidates.isEmpty) {
      _showMessage('当前书架没有可更新的网络书籍（可能已关闭“允许更新”）');
      return;
    }

    if (!mounted) return;
    setState(() {
      _isUpdatingCatalog = true;
      _updatingBookIds.clear();
    });

    try {
      final summary = await _catalogUpdater.updateBooks(
        candidates,
        onBookUpdatingChanged: (bookId, updating) {
          if (!mounted) return;
          setState(() {
            if (updating) {
              _updatingBookIds.add(bookId);
            } else {
              _updatingBookIds.remove(bookId);
            }
          });
        },
      );

      if (!mounted) return;
      setState(() {
        _isUpdatingCatalog = false;
        _updatingBookIds.clear();
      });
      _loadBooks();
      _showMessage(_buildCatalogUpdateSummaryMessage(summary));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isUpdatingCatalog = false;
        _updatingBookIds.clear();
      });
      _showMessage('更新目录失败：$e');
    }
  }

  void _showMessage(String message) {
    showCupertinoBottomDialog<void>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            child: const Text('好'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  void _showBottomHint(String message) {
    if (!mounted) return;
    unawaited(showAppToast(context, message: message));
  }

  int _waitUpCount(List<Book> books) {
    return books.where((book) {
      if (book.isLocal) return false;
      return _settingsService.getBookCanUpdate(book.id);
    }).length;
  }

  Widget? _buildBookshelfMiddleTitle() {
    final settings = _settingsService.appSettings;
    final pageTitle = _currentBookshelfTitle();
    if (_isStyle2Enabled && _selectedGroupId != BookshelfBookGroup.idRoot) {
      return Text(pageTitle);
    }
    if (!settings.bookshelfShowWaitUpCount) return null;
    final count = _waitUpCount(_displayBooks());
    if (count <= 0) {
      return Text(pageTitle);
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(pageTitle),
        const SizedBox(width: 6),
        DecoratedBox(
          decoration: BoxDecoration(
            color: CupertinoColors.systemRed.resolveFrom(context),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            child: Text(
              count > 99 ? '99+' : '$count',
              style: const TextStyle(
                fontSize: 11,
                color: CupertinoColors.white,
                fontWeight: FontWeight.w600,
                height: 1.1,
                letterSpacing: -0.2,
              ),
            ),
          ),
        ),
      ],
    );
  }

}
