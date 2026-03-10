// ignore_for_file: invalid_use_of_protected_member
part of 'bookshelf_view.dart';

extension _BookshelfImportX on _BookshelfViewState {
  Future<void> _importLocalBook() async {
    if (_isImporting || _isScanningImportFolder) return;

    setState(() => _isImporting = true);

    try {
      final result = await _importService.importLocalBook();

      if (result.success && result.book != null) {
        _loadBooks();
        if (mounted) {
          _showMessage(
              '导入成功：${result.book!.title}\n共 ${result.chapterCount} 章');
        }
      } else if (!result.cancelled && result.errorMessage != null) {
        if (mounted) {
          _showMessage('导入失败：${result.errorMessage}');
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isImporting = false);
      }
    }
  }

  Future<void> _selectImportFolder() async {
    if (_isImporting || _isSelectingImportFolder || _isScanningImportFolder) {
      return;
    }

    final action = await showCupertinoBottomDialog<_ImportFolderAction>(
      context: context,
      barrierDismissible: true,
      builder: (sheetContext) => CupertinoActionSheet(
        title: const Text('选择文件夹'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () =>
                Navigator.pop(sheetContext, _ImportFolderAction.select),
            child: const Text('选择文件夹'),
          ),
          CupertinoActionSheetAction(
            onPressed: () =>
                Navigator.pop(sheetContext, _ImportFolderAction.create),
            child: const Text('创建文件夹'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(sheetContext),
          child: const Text('取消'),
        ),
      ),
    );
    if (!mounted || action == null) return;

    if (action == _ImportFolderAction.select) {
      setState(() => _isSelectingImportFolder = true);
      try {
        final result = await _importService.selectImportDirectory();
        if (!mounted) return;
        if (result.success && result.directoryPath != null) {
          unawaited(showAppToast(context, message: '已选择文件夹：${result.directoryPath}'));
          return;
        }
        if (!result.cancelled && result.errorMessage != null) {
          _showMessage('选择文件夹失败：${result.errorMessage}');
        }
      } finally {
        if (mounted) {
          setState(() => _isSelectingImportFolder = false);
        }
      }
      return;
    }

    setState(() => _isSelectingImportFolder = true);
    String? parentDirectoryPath;
    try {
      parentDirectoryPath = _importService.getSavedImportDirectory();
      if (parentDirectoryPath == null || parentDirectoryPath.trim().isEmpty) {
        final parentResult = await _importService.selectImportDirectory();
        if (!mounted) return;
        if (parentResult.success && parentResult.directoryPath != null) {
          parentDirectoryPath = parentResult.directoryPath!;
        } else {
          if (!parentResult.cancelled && parentResult.errorMessage != null) {
            _showMessage('选择文件夹失败：${parentResult.errorMessage}');
          }
          return;
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isSelectingImportFolder = false);
      }
    }
    if (!mounted) return;

    final folderName = await _showCreateFolderNameDialog();
    if (!mounted || folderName == null) return;

    setState(() => _isSelectingImportFolder = true);
    try {
      final result = await _importService.createImportDirectory(
        parentDirectoryPath: parentDirectoryPath,
        folderName: folderName,
      );
      if (!mounted) return;
      if (result.success && result.directoryPath != null) {
        unawaited(showAppToast(context, message: '已选择文件夹：${result.directoryPath}'));
      } else if (result.errorMessage != null &&
          result.errorMessage!.isNotEmpty) {
        _showMessage('创建文件夹失败：${result.errorMessage}');
      }
    } finally {
      if (mounted) {
        setState(() => _isSelectingImportFolder = false);
      }
    }
  }

  Future<String?> _showCreateFolderNameDialog() async {
    final controller = TextEditingController();
    String? name;
    await showCupertinoBottomDialog<void>(
      context: context,
      builder: (dialogContext) {
        String? errorText;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return CupertinoAlertDialog(
              title: const Text('创建文件夹'),
              content: Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CupertinoTextField(
                      controller: controller,
                      placeholder: '文件夹名',
                    ),
                    if (errorText != null && errorText!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        errorText!,
                        style: TextStyle(
                          color: CupertinoColors.systemRed.resolveFrom(context),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
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
                    final value = controller.text.trim();
                    if (value.isEmpty) {
                      setDialogState(() {
                        errorText = '文件夹名不能为空';
                      });
                      return;
                    }
                    name = value;
                    Navigator.pop(dialogContext);
                  },
                  child: const Text('确定'),
                ),
              ],
            );
          },
        );
      },
    );
    controller.dispose();
    return name;
  }

  Future<void> _scanImportFolder() async {
    if (_isImporting || _isSelectingImportFolder || _isScanningImportFolder) {
      return;
    }
    setState(() => _isScanningImportFolder = true);

    try {
      final scanResult = await _importService.scanImportDirectory();
      if (!mounted) return;
      if (!scanResult.success) {
        if (scanResult.errorMessage != null &&
            scanResult.errorMessage!.isNotEmpty) {
          _showMessage('智能扫描失败：${scanResult.errorMessage}');
        }
        return;
      }

      if (scanResult.candidates.isEmpty) {
        _showMessage('当前文件夹未扫描到可导入的 TXT/EPUB 文件');
        return;
      }

      final selectedFilePaths =
          await _showScanImportSelectionDialog(scanResult: scanResult);
      if (!mounted || selectedFilePaths == null || selectedFilePaths.isEmpty) {
        return;
      }

      setState(() => _isImporting = true);
      final summary =
          await _importService.importLocalBooksByPaths(selectedFilePaths);
      if (!mounted) return;
      setState(() => _isImporting = false);

      _loadBooks();
      _showMessage(_buildScanImportSummaryMessage(summary));
    } finally {
      if (mounted) {
        setState(() {
          _isScanningImportFolder = false;
          _isImporting = false;
        });
      }
    }
  }

  Future<List<String>?> _showScanImportSelectionDialog({
    required ImportScanResult scanResult,
  }) async {
    final candidates = List<ImportScanCandidate>.from(scanResult.candidates);
    final selectedPaths =
        candidates.map((candidate) => candidate.filePath).toSet();
    var deletingSelection = false;

    return showCupertinoBottomDialog<List<String>>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final rootPath = scanResult.rootDirectoryPath;
            final isAllSelected = candidates.isNotEmpty &&
                selectedPaths.length == candidates.length;
            final uiTokens = AppUiTokens.resolve(context);
            return CupertinoAlertDialog(
              title: const Text('智能扫描'),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  children: [
                    const SizedBox(height: 10),
                    Text('已扫描到 ${candidates.length} 个可导入文件'),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: math
                          .min(320, math.max(180, candidates.length * 56))
                          .toDouble(),
                      child: ListView.builder(
                        itemCount: candidates.length,
                        itemBuilder: (context, index) {
                          final candidate = candidates[index];
                          final isSelected =
                              selectedPaths.contains(candidate.filePath);
                          final relativePath =
                              _formatScanCandidatePath(candidate, rootPath);
                          return GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onLongPress: deletingSelection
                                ? null
                                : () async {
                                    final shouldDelete =
                                        await _showScanCandidateLongPressMenu(
                                      context: context,
                                    );
                                    if (!context.mounted || !shouldDelete) {
                                      return;
                                    }
                                    setDialogState(
                                      () => deletingSelection = true,
                                    );
                                    final deleteResult = await _importService
                                        .deleteLocalBooksByPaths(
                                      <String>[candidate.filePath],
                                    );
                                    if (!context.mounted) return;
                                    setDialogState(() {
                                      if (deleteResult.deletedCount > 0) {
                                        candidates.removeWhere(
                                          (entry) =>
                                              entry.filePath ==
                                              candidate.filePath,
                                        );
                                        selectedPaths
                                            .remove(candidate.filePath);
                                      }
                                      deletingSelection = false;
                                    });
                                  },
                            child: CupertinoButton(
                              padding: EdgeInsets.zero,
                              minimumSize: uiTokens.sizes.compactTapSquare,
                              onPressed: () {
                                setDialogState(() {
                                  if (isSelected) {
                                    selectedPaths.remove(candidate.filePath);
                                  } else {
                                    selectedPaths.add(candidate.filePath);
                                  }
                                });
                              },
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 6),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            candidate.fileName,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: isSelected
                                                  ? CupertinoColors.activeBlue.resolveFrom(context)
                                                      .resolveFrom(context)
                                                  : CupertinoColors.label.resolveFrom(context)
                                                      .resolveFrom(context),
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            relativePath,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: CupertinoColors.systemGrey.resolveFrom(context),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Icon(
                                      isSelected
                                          ? CupertinoIcons
                                              .check_mark_circled_solid
                                          : CupertinoIcons.circle,
                                      size: 18,
                                      color: isSelected
                                          ? CupertinoColors.activeBlue.resolveFrom(context)
                                              .resolveFrom(context)
                                          : CupertinoColors.systemGrey.resolveFrom(context),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                CupertinoDialogAction(
                  onPressed: deletingSelection
                      ? null
                      : () => Navigator.pop(dialogContext),
                  child: const Text('取消'),
                ),
                CupertinoDialogAction(
                  onPressed: deletingSelection || candidates.isEmpty
                      ? null
                      : () {
                          setDialogState(() {
                            if (isAllSelected) {
                              selectedPaths.clear();
                              return;
                            }
                            selectedPaths
                              ..clear()
                              ..addAll(
                                candidates
                                    .map((candidate) => candidate.filePath)
                                    .toList(growable: false),
                              );
                          });
                        },
                  child: Text(
                    isAllSelected ? '取消全选' : '全选',
                  ),
                ),
                CupertinoDialogAction(
                  isDestructiveAction: true,
                  onPressed: deletingSelection || selectedPaths.isEmpty
                      ? null
                      : () async {
                          final deletingPaths =
                              selectedPaths.toList(growable: false);
                          setDialogState(() => deletingSelection = true);
                          await _importService
                              .deleteLocalBooksByPaths(deletingPaths);
                          if (!context.mounted) return;
                          setDialogState(() {
                            final deletingSet = deletingPaths.toSet();
                            candidates.removeWhere(
                              (candidate) =>
                                  deletingSet.contains(candidate.filePath),
                            );
                            selectedPaths.removeWhere(deletingSet.contains);
                            deletingSelection = false;
                          });
                        },
                  child: Text(
                    deletingSelection ? '删除中...' : '删除',
                  ),
                ),
                CupertinoDialogAction(
                  isDefaultAction: true,
                  onPressed: selectedPaths.isEmpty || deletingSelection
                      ? null
                      : () {
                          Navigator.pop(
                            dialogContext,
                            selectedPaths.toList(growable: false),
                          );
                        },
                  child: const Text('导入'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<bool> _showScanCandidateLongPressMenu({
    required BuildContext context,
  }) async {
    final result = await showCupertinoBottomDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (sheetContext) => CupertinoActionSheet(
        actions: [
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(sheetContext).pop(true),
            child: const Text('删除'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(sheetContext).pop(false),
          child: const Text('取消'),
        ),
      ),
    );
    return result ?? false;
  }

  String _formatScanCandidatePath(
    ImportScanCandidate candidate,
    String? rootPath,
  ) {
    final normalizedRoot = (rootPath ?? '').trim();
    if (normalizedRoot.isEmpty) {
      return candidate.filePath;
    }
    final normalizedCandidate = p.normalize(candidate.filePath);
    if (normalizedCandidate == normalizedRoot) {
      return candidate.fileName;
    }
    if (!p.isWithin(normalizedRoot, normalizedCandidate)) {
      return normalizedCandidate;
    }
    final relative = p.relative(
      normalizedCandidate,
      from: normalizedRoot,
    );
    return relative.isEmpty ? candidate.fileName : relative;
  }

  String _buildScanImportSummaryMessage(BatchImportResult summary) {
    if (summary.totalCount <= 0) {
      return '未选择可导入文件';
    }

    final lines = <String>[
      '智能扫描导入完成：成功 ${summary.successCount} 项，失败 ${summary.failedCount} 项',
    ];
    if (summary.failures.isNotEmpty) {
      lines.add('');
      lines.add('失败详情（最多 5 条）：');
      for (final failure in summary.failures.take(5)) {
        lines.add('${p.basename(failure.filePath)}：${failure.errorMessage}');
      }
    }
    return lines.join('\n');
  }

  Future<void> _showImportFileNameRuleDialog() async {
    final controller = TextEditingController(
      text: _bookImportFileNameRuleService.getRule(),
    );
    await showCupertinoBottomDialog<void>(
      context: context,
      builder: (dialogContext) {
        return CupertinoAlertDialog(
          title: const Text('导入文件名'),
          content: Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '使用js处理文件名变量src，将书名作者分别赋值到变量name author',
                  textAlign: TextAlign.left,
                ),
                const SizedBox(height: 10),
                CupertinoTextField(
                  controller: controller,
                  placeholder: 'js',
                  maxLines: 5,
                ),
              ],
            ),
          ),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('取消'),
            ),
            CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: () async {
                final rule = controller.text;
                Navigator.pop(dialogContext);
                await _bookImportFileNameRuleService.saveRule(rule);
              },
              child: const Text('确定'),
            ),
          ],
        );
      },
    );
    controller.dispose();
  }

  Future<void> _openGlobalSearch() async {
    await Navigator.of(context, rootNavigator: true).push(
      CupertinoPageRoute<void>(
        builder: (_) => const SearchView(),
      ),
    );
    if (!mounted) return;
    _loadBooks();
  }

  Future<void> _openRemoteBook() async {
    await Navigator.of(context, rootNavigator: true).push(
      CupertinoPageRoute<void>(
        builder: (_) => const RemoteBooksServersView(),
      ),
    );
    if (!mounted) return;
    _loadBooks();
  }

  Future<void> _openBookshelfManage() async {
    final groupId = _selectedGroupId;
    await Navigator.of(context, rootNavigator: true).push(
      CupertinoPageRoute<void>(
        builder: (_) => BookshelfManagePlaceholderView(
          initialGroupId: groupId,
        ),
      ),
    );
    if (!mounted) return;
    await _reloadBookGroupContext(showError: true);
    _loadBooks();
  }

  Future<void> _openCacheExport() async {
    final groupId = _selectedGroupId;
    await Navigator.of(context, rootNavigator: true).push(
      CupertinoPageRoute<void>(
        builder: (_) => CacheExportPlaceholderView(
          initialGroupId: groupId,
        ),
      ),
    );
  }

  Future<void> _openBookshelfGroupManageDialog() async {
    await showCupertinoBottomDialog<void>(
      context: context,
      builder: (_) => const BookshelfGroupManagePlaceholderDialog(),
    );
    if (!mounted) return;
    await _reloadBookGroupContext(showError: true);
    _loadBooks();
  }

  String? _extractBaseUrl(String rawUrl) {
    final uri = Uri.tryParse(rawUrl.trim());
    if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
      return null;
    }
    final scheme = uri.scheme.toLowerCase();
    if (scheme != 'http' && scheme != 'https') {
      return null;
    }
    final portSegment = uri.hasPort ? ':${uri.port}' : '';
    return '$scheme://${uri.host}$portSegment';
  }

  BookSource? _resolveSourceForBookUrl(
    String bookUrl,
    List<BookSource> enabledSources,
  ) {
    final baseUrl = _extractBaseUrl(bookUrl);
    if (baseUrl == null) return null;

    final exactSource = _sourceRepo.getSourceByUrl(baseUrl);
    if (exactSource != null && exactSource.enabled) {
      return exactSource;
    }

    for (final source in enabledSources) {
      final rawPattern = (source.bookUrlPattern ?? '').trim();
      if (rawPattern.isEmpty || rawPattern.toUpperCase() == 'NONE') {
        continue;
      }
      try {
        if (RegExp(rawPattern).hasMatch(bookUrl)) {
          return source;
        }
      } catch (_) {
        // 与 legado 一致：单个异常规则不中断整体匹配流程。
      }
    }
    return null;
  }

  Future<void> _addBooksByUrl(String rawInput) async {
    if (_isImporting || _isUpdatingCatalog || _isAddingByUrl) return;

    final urls = rawInput
        .split('\n')
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList(growable: false);
    if (urls.isEmpty) return;

    if (!mounted) return;
    setState(() => _isAddingByUrl = true);
    _cancelAddByUrlRequested = false;

    final progress = ValueNotifier<int>(0);
    var progressDialogClosed = false;
    Future<void>? progressDialogFuture;
    if (mounted) {
      progressDialogFuture = showCupertinoBottomDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return ValueListenableBuilder<int>(
            valueListenable: progress,
            builder: (_, count, __) {
              return CupertinoAlertDialog(
                title: Text('添加中... ($count)'),
                content: const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: CupertinoActivityIndicator(),
                ),
                actions: [
                  CupertinoDialogAction(
                    onPressed: () {
                      _cancelAddByUrlRequested = true;
                      progressDialogClosed = true;
                      Navigator.pop(dialogContext);
                    },
                    child: const Text('取消'),
                  ),
                ],
              );
            },
          );
        },
      ).then((_) {
        progressDialogClosed = true;
      });
    }

    var successCount = 0;
    final existingBookUrls = _bookRepo
        .getAllBooks()
        .map((book) => (book.bookUrl ?? '').trim())
        .where((url) => url.isNotEmpty)
        .toSet();
    final enabledSources = _sourceRepo
        .getAllSources()
        .where((source) => source.enabled)
        .toList(growable: false);

    try {
      for (final bookUrl in urls) {
        if (_cancelAddByUrlRequested) break;

        if (existingBookUrls.contains(bookUrl)) {
          successCount++;
          progress.value = successCount;
          continue;
        }

        final source = _resolveSourceForBookUrl(bookUrl, enabledSources);
        if (source == null) continue;

        final result = await _bookAddService.addFromSearchResult(
          SearchResult(
            name: '',
            author: '',
            coverUrl: '',
            intro: '',
            lastChapter: '',
            bookUrl: bookUrl,
            sourceUrl: source.bookSourceUrl,
            sourceName: source.bookSourceName,
          ),
        );
        if (result.success || result.alreadyExists) {
          successCount++;
          progress.value = successCount;
          existingBookUrls.add(bookUrl);
        }
      }
    } finally {
      if (mounted && !progressDialogClosed) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      if (progressDialogFuture != null) {
        await progressDialogFuture;
      }
      progress.dispose();
      if (mounted) {
        setState(() => _isAddingByUrl = false);
      }
    }

    if (!mounted) return;
    if (_cancelAddByUrlRequested) {
      _loadBooks();
      return;
    }
    if (successCount > 0) {
      _loadBooks();
      _showMessage('成功');
    } else {
      _showMessage('添加网址失败');
    }
  }

}
