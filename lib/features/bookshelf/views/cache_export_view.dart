import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';

import '../../../app/theme/design_tokens.dart';
import '../../../app/widgets/app_cupertino_page_scaffold.dart';
import '../../../app/widgets/app_empty_state.dart';
import '../../../app/widgets/cupertino_bottom_dialog.dart';
import '../../../core/database/database_service.dart';
import '../../../core/database/repositories/book_repository.dart';
import '../../../core/services/exception_log_service.dart';
import '../services/cache_export_task_service.dart';
import '../models/book.dart';
import '../services/cache_download_task_service.dart';

/// 缓存/导出页（当前已收敛 `menu_download`、`menu_download_after`、`menu_download_all`、`menu_book_group`、`menu_export_all`、`menu_enable_replace`、`menu_enable_custom_export`、`menu_export_web_dav`、`menu_export_no_chapter_name`、`menu_export_pics_file`、`menu_parallel_export`、`menu_export_folder`、`menu_export_file_name`、`menu_export_type`、`menu_export_charset`）。
class CacheExportView extends StatefulWidget {
  const CacheExportView({
    super.key,
    this.initialGroupId,
  });

  final int? initialGroupId;

  @override
  State<CacheExportView> createState() => _CacheExportViewState();
}

class _CacheBookGroupOption {
  final int id;
  final String title;
  final int order;

  const _CacheBookGroupOption({
    required this.id,
    required this.title,
    required this.order,
  });
}

class _CacheExportViewState extends State<CacheExportView> {
  static const int _groupIdAll = -1;
  static const int _groupIdLocal = -2;
  static const int _groupIdAudio = -3;
  static const int _groupIdNetNone = -4;
  static const int _groupIdLocalNone = -5;
  static const int _groupIdError = -11;
  static const List<_CacheBookGroupOption> _legacyBookGroups =
      <_CacheBookGroupOption>[
    _CacheBookGroupOption(id: _groupIdAll, title: '全部', order: -10),
    _CacheBookGroupOption(id: _groupIdLocal, title: '本地', order: -9),
    _CacheBookGroupOption(id: _groupIdAudio, title: '音频', order: -8),
    _CacheBookGroupOption(id: _groupIdNetNone, title: '网络未分组', order: -7),
    _CacheBookGroupOption(id: _groupIdLocalNone, title: '本地未分组', order: -6),
    _CacheBookGroupOption(id: _groupIdError, title: '更新失败', order: -1),
  ];

  late final BookRepository _bookRepo;
  late final ChapterRepository _chapterRepo;
  late final CacheDownloadTaskService _downloadService;
  late final CacheExportTaskService _exportService;

  StreamSubscription<List<Book>>? _booksSubscription;

  List<Book> _allBooks = const <Book>[];
  List<Book> _books = const <Book>[];
  Map<String, int> _cachedChapterCountByBookId = const <String, int>{};
  int _selectedGroupId = _groupIdAll;
  String _selectedGroupTitle = '全部';
  CacheDownloadProgress? _progress;
  bool _downloadRunning = false;
  bool _exportRunning = false;
  bool _exportUseReplace = true;
  bool _enableCustomExport = false;
  bool _exportToWebDav = false;
  bool _exportNoChapterName = false;
  bool _exportPictureFile = false;
  bool _parallelExportBook = false;
  int _exportTypeIndex = 0;
  String _exportCharset = CacheExportTaskService.defaultExportCharset;
  String? _initError;

  @override
  void initState() {
    super.initState();
    try {
      final db = DatabaseService();
      _bookRepo = BookRepository(db);
      _chapterRepo = ChapterRepository(db);
      _downloadService = CacheDownloadTaskService(
        database: db,
        bookRepo: _bookRepo,
        chapterRepo: _chapterRepo,
      );
      _exportService = CacheExportTaskService(
        database: db,
        chapterRepo: _chapterRepo,
      );
      _exportUseReplace = _exportService.getExportUseReplace();
      _enableCustomExport = _exportService.getEnableCustomExport();
      _exportToWebDav = _exportService.getExportToWebDav();
      _exportNoChapterName = _exportService.getExportNoChapterName();
      _exportPictureFile = _exportService.getExportPictureFile();
      _parallelExportBook = _exportService.getParallelExportBook();
      _exportTypeIndex = _exportService.getExportTypeIndex();
      _exportCharset = _exportService.getExportCharset();
      final initialGroupId = widget.initialGroupId;
      if (initialGroupId != null) {
        final matchesLegacy = _legacyBookGroups.any((g) => g.id == initialGroupId);
        if (matchesLegacy) {
          _selectedGroupId = initialGroupId;
          _selectedGroupTitle = _resolveGroupTitle(initialGroupId);
        }
      }
      _refreshBooksSnapshot();
      _booksSubscription = _bookRepo.watchAllBooks().listen((books) {
        if (!mounted) return;
        _applyBooks(books);
      });
    } catch (error) {
      _initError = '缓存/导出页初始化失败：$error';
    }
  }

  @override
  void dispose() {
    _booksSubscription?.cancel();
    if (_downloadRunning) {
      _downloadService.stop();
    }
    super.dispose();
  }

  void _sortBooks(List<Book> books) {
    books.sort((a, b) {
      final aTime = _maxDateTime(a.lastReadTime, a.addedTime);
      final bTime = _maxDateTime(b.lastReadTime, b.addedTime);
      final aMs = aTime?.millisecondsSinceEpoch ?? 0;
      final bMs = bTime?.millisecondsSinceEpoch ?? 0;
      return bMs.compareTo(aMs);
    });
  }

  DateTime? _maxDateTime(DateTime? a, DateTime? b) {
    if (a == null) return b;
    if (b == null) return a;
    return a.isAfter(b) ? a : b;
  }

  String _resolveGroupTitle(int groupId) {
    for (final option in _legacyBookGroups) {
      if (option.id == groupId) {
        return option.title;
      }
    }
    return '未分组';
  }

  List<Book> _filterBooksByGroup(List<Book> books, int groupId) {
    switch (groupId) {
      case _groupIdAll:
        return List<Book>.from(books);
      case _groupIdLocal:
        return books.where((book) => book.isLocal).toList(growable: false);
      case _groupIdAudio:
      case _groupIdError:
        // 当前模型未承载 legado 音频/更新失败类型位，先保持可选分组入口，列表回落空集。
        return const <Book>[];
      case _groupIdNetNone:
        return books.where((book) => !book.isLocal).toList(growable: false);
      case _groupIdLocalNone:
        return books.where((book) => book.isLocal).toList(growable: false);
      default:
        return const <Book>[];
    }
  }

  void _applyBooks(List<Book> books) {
    final nextBooks = List<Book>.from(books);
    _sortBooks(nextBooks);
    final nextCount = _buildCachedCountMap(nextBooks);
    final filtered = _filterBooksByGroup(nextBooks, _selectedGroupId);
    setState(() {
      _allBooks = nextBooks;
      _books = filtered;
      _cachedChapterCountByBookId = nextCount;
      _selectedGroupTitle = _resolveGroupTitle(_selectedGroupId);
    });
  }

  Map<String, int> _buildCachedCountMap(List<Book> books) {
    final next = <String, int>{};
    for (final book in books) {
      next[book.id] =
          _chapterRepo.getDownloadedCacheInfoForBook(book.id).chapters;
    }
    return next;
  }

  void _refreshBooksSnapshot() {
    final books = List<Book>.from(_bookRepo.getAllBooks());
    _sortBooks(books);
    if (!mounted) return;
    setState(() {
      _allBooks = books;
      _books = _filterBooksByGroup(books, _selectedGroupId);
      _cachedChapterCountByBookId = _buildCachedCountMap(books);
      _selectedGroupTitle = _resolveGroupTitle(_selectedGroupId);
    });
  }

  void _handleDownloadProgress(CacheDownloadProgress progress) {
    if (!mounted) return;
    final nextCount = Map<String, int>.from(_cachedChapterCountByBookId);
    nextCount[progress.bookId] =
        _chapterRepo.getDownloadedCacheInfoForBook(progress.bookId).chapters;
    setState(() {
      _progress = progress;
      _cachedChapterCountByBookId = nextCount;
    });
  }

  Future<void> _handleDownloadTap() async {
    await _handleDownloadAfterTap();
  }

  Future<void> _handleDownloadAfterTap() async {
    await _startDownload(downloadAllChapters: false);
  }

  Future<void> _handleDownloadAllTap() async {
    await _startDownload(downloadAllChapters: true);
  }

  Future<void> _downloadSingleBook(Book book) async {
    if (_downloadRunning || book.isLocal) return;
    setState(() {
      _downloadRunning = true;
      _progress = null;
    });
    try {
      final summary =
          await _downloadService.startDownloadFromCurrentChapter(
        [book],
        onProgress: _handleDownloadProgress,
      );
      _refreshBooksSnapshot();
      if (!mounted) return;
      await _showMessage(_buildSummaryMessage(summary));
    } catch (error) {
      if (!mounted) return;
      await _showMessage('缓存失败：$error');
    } finally {
      if (!mounted) return;
      setState(() => _downloadRunning = false);
    }
  }

  Future<void> _exportSingleBook(Book book) async {
    if (_exportRunning) return;
    setState(() => _exportRunning = true);
    try {
      final exportDirectory = await _resolveExportDirectory();
      if (exportDirectory == null) return;
      final summary = await _exportService.exportAllToDirectory(
        [book],
        exportDirectory,
        exportPictureFile: _exportPictureFile,
      );
      if (!mounted) return;
      await _showMessage(_buildExportSummaryMessage(summary));
    } catch (error) {
      if (!mounted) return;
      await _showMessage('导出失败：$error');
    } finally {
      if (!mounted) return;
      setState(() => _exportRunning = false);
    }
  }

  Future<void> _startDownload({required bool downloadAllChapters}) async {
    if (_downloadRunning) {
      _downloadService.stop();
      return;
    }

    final candidates =
        _books.where((book) => !book.isLocal).toList(growable: false);
    if (candidates.isEmpty) {
      await _showMessage('当前无可缓存的在线书籍');
      return;
    }

    final confirmed = await _confirmStartDownload();
    if (!confirmed) return;

    if (!mounted) return;
    setState(() {
      _downloadRunning = true;
      _progress = null;
    });

    try {
      final summary = downloadAllChapters
          ? await _downloadService.startDownloadAllChapters(
              _books,
              onProgress: _handleDownloadProgress,
            )
          : await _downloadService.startDownloadFromCurrentChapter(
              _books,
              onProgress: _handleDownloadProgress,
            );
      _refreshBooksSnapshot();
      if (!mounted) return;
      await _showMessage(_buildSummaryMessage(summary));
    } catch (error) {
      if (!mounted) return;
      await _showMessage('缓存失败：$error');
    } finally {
      if (!mounted) return;
      setState(() {
        _downloadRunning = false;
        _progress = null;
      });
    }
  }

  Future<void> _handleDownloadActionLongPress() async {
    if (!mounted) return;
    await showCupertinoBottomSheetDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (sheetContext) {
        return CupertinoActionSheet(
          actions: [
            CupertinoActionSheetAction(
              onPressed: () async {
                Navigator.pop(sheetContext);
                await _handleDownloadAfterTap();
              },
              child: const Text('下载之后章节'),
            ),
            CupertinoActionSheetAction(
              onPressed: () async {
                Navigator.pop(sheetContext);
                await _handleDownloadAllTap();
              },
              child: const Text('下载全部章节'),
            ),
          ],
          cancelButton: CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(sheetContext),
            child: const Text('取消'),
          ),
        );
      },
    );
  }

  Future<bool> _confirmStartDownload() async {
    final result = await showCupertinoBottomSheetDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return CupertinoAlertDialog(
          title: const Text('提醒'),
          content: const Text('是否确认缓存当前列表书籍？'),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('取消'),
            ),
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('确定'),
            ),
          ],
        );
      },
    );
    return result == true;
  }

  Future<void> _showMessage(String message) async {
    if (!mounted) return;
    await showCupertinoBottomSheetDialog<void>(
      context: context,
      builder: (dialogContext) {
        return CupertinoAlertDialog(
          content: Text(message),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('好'),
            ),
          ],
        );
      },
    );
  }

  String _buildSummaryMessage(CacheDownloadSummary summary) {
    final parts = <String>[
      '新增${summary.downloadedChapters}章',
      if (summary.skippedChapters > 0) '已缓存${summary.skippedChapters}章',
      if (summary.failedChapters > 0) '失败${summary.failedChapters}章',
    ];
    final prefix = summary.stoppedByUser ? '缓存已停止' : '缓存完成';
    return '$prefix（共${summary.requestedChapters}章）：${parts.join('，')}';
  }

  Future<void> _handleMoreTap() async {
    if (_exportRunning) return;
    if (!mounted) return;
    setState(() {
      _exportUseReplace = _exportService.getExportUseReplace();
      _enableCustomExport = _exportService.getEnableCustomExport();
      _exportToWebDav = _exportService.getExportToWebDav();
      _exportNoChapterName = _exportService.getExportNoChapterName();
      _exportPictureFile = _exportService.getExportPictureFile();
      _parallelExportBook = _exportService.getParallelExportBook();
      _exportTypeIndex = _exportService.getExportTypeIndex();
      _exportCharset = _exportService.getExportCharset();
    });
    await showCupertinoBottomSheetDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (sheetContext) {
        return CupertinoActionSheet(
          title: const Text('更多'),
          actions: [
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(sheetContext);
                _handleExportAllTap();
              },
              child: const Text('导出所有'),
            ),
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(sheetContext);
                _toggleExportUseReplace();
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_exportUseReplace)
                    const Icon(CupertinoIcons.check_mark, size: 16)
                  else
                    const SizedBox(width: 16),
                  const SizedBox(width: 6),
                  const Text('替换净化'),
                ],
              ),
            ),
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(sheetContext);
                _toggleCustomExport();
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_enableCustomExport)
                    const Icon(CupertinoIcons.check_mark, size: 16)
                  else
                    const SizedBox(width: 16),
                  const SizedBox(width: 6),
                  const Text('自定义Epub导出章节'),
                ],
              ),
            ),
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(sheetContext);
                _toggleExportToWebDav();
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_exportToWebDav)
                    const Icon(CupertinoIcons.check_mark, size: 16)
                  else
                    const SizedBox(width: 16),
                  const SizedBox(width: 6),
                  const Text('导出到 WebDav'),
                ],
              ),
            ),
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(sheetContext);
                _toggleExportNoChapterName();
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_exportNoChapterName)
                    const Icon(CupertinoIcons.check_mark, size: 16)
                  else
                    const SizedBox(width: 16),
                  const SizedBox(width: 6),
                  const Text('TXT 不导出章节名'),
                ],
              ),
            ),
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(sheetContext);
                _toggleExportPictureFile();
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_exportPictureFile)
                    const Icon(CupertinoIcons.check_mark, size: 16)
                  else
                    const SizedBox(width: 16),
                  const SizedBox(width: 6),
                  const Text('TXT 导出图片'),
                ],
              ),
            ),
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(sheetContext);
                _toggleParallelExportBook();
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_parallelExportBook)
                    const Icon(CupertinoIcons.check_mark, size: 16)
                  else
                    const SizedBox(width: 16),
                  const SizedBox(width: 6),
                  const Text('多线程导出'),
                ],
              ),
            ),
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(sheetContext);
                _handleExportFolderTap();
              },
              child: const Text('导出文件夹'),
            ),
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(sheetContext);
                _handleExportFileNameTap();
              },
              child: const Text('导出文件名'),
            ),
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(sheetContext);
                _handleExportTypeTap();
              },
              child: Text('导出格式(${_currentExportTypeName()})'),
            ),
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(sheetContext);
                _handleExportCharsetTap();
              },
              child: Text('导出编码($_exportCharset)'),
            ),
          ],
          cancelButton: CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(sheetContext),
            child: const Text('取消'),
          ),
        );
      },
    );
  }

  Future<void> _handleBookGroupTap() async {
    if (!mounted) return;
    final options = _legacyBookGroups.toList(growable: false)
      ..sort((a, b) => a.order.compareTo(b.order));
    final selectedGroupId = await showCupertinoBottomSheetDialog<int>(
      context: context,
      barrierDismissible: true,
      builder: (sheetContext) {
        return CupertinoActionSheet(
          title: const Text('分组'),
          actions: options
              .map(
                (option) => CupertinoActionSheetAction(
                  onPressed: () => Navigator.pop(sheetContext, option.id),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_selectedGroupId == option.id)
                        const Icon(CupertinoIcons.check_mark, size: 16)
                      else
                        const SizedBox(width: 16),
                      const SizedBox(width: 6),
                      Text(option.title),
                    ],
                  ),
                ),
              )
              .toList(growable: false),
          cancelButton: CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(sheetContext),
            child: const Text('取消'),
          ),
        );
      },
    );
    if (selectedGroupId == null || selectedGroupId == _selectedGroupId) {
      return;
    }
    if (!mounted) return;
    setState(() {
      _selectedGroupId = selectedGroupId;
      _selectedGroupTitle = _resolveGroupTitle(selectedGroupId);
      _books = _filterBooksByGroup(_allBooks, selectedGroupId);
    });
  }

  Future<void> _toggleExportUseReplace() async {
    final nextValue = !_exportUseReplace;
    if (!mounted) return;
    setState(() {
      _exportUseReplace = nextValue;
    });
    try {
      await _exportService.saveExportUseReplace(nextValue);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _exportUseReplace = !nextValue;
      });
      await _showMessage('切换失败：$error');
    }
  }

  Future<void> _toggleCustomExport() async {
    final nextValue = !_enableCustomExport;
    if (!mounted) return;
    setState(() {
      _enableCustomExport = nextValue;
    });
    try {
      await _exportService.saveEnableCustomExport(nextValue);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _enableCustomExport = !nextValue;
      });
      await _showMessage('切换失败：$error');
    }
  }

  Future<void> _toggleExportToWebDav() async {
    final nextValue = !_exportToWebDav;
    if (!mounted) return;
    setState(() {
      _exportToWebDav = nextValue;
    });
    try {
      await _exportService.saveExportToWebDav(nextValue);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _exportToWebDav = !nextValue;
      });
      await _showMessage('切换失败：$error');
    }
  }

  Future<void> _toggleExportNoChapterName() async {
    final nextValue = !_exportNoChapterName;
    if (!mounted) return;
    setState(() {
      _exportNoChapterName = nextValue;
    });
    try {
      await _exportService.saveExportNoChapterName(nextValue);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _exportNoChapterName = !nextValue;
      });
      await _showMessage('切换失败：$error');
    }
  }

  Future<void> _toggleExportPictureFile() async {
    final nextValue = !_exportPictureFile;
    if (!mounted) return;
    setState(() {
      _exportPictureFile = nextValue;
    });
    try {
      await _exportService.saveExportPictureFile(nextValue);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _exportPictureFile = !nextValue;
      });
      await _showMessage('切换失败：$error');
    }
  }

  Future<void> _toggleParallelExportBook() async {
    final nextValue = !_parallelExportBook;
    if (!mounted) return;
    setState(() {
      _parallelExportBook = nextValue;
    });
    try {
      await _exportService.saveParallelExportBook(nextValue);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _parallelExportBook = !nextValue;
      });
      await _showMessage('切换失败：$error');
    }
  }

  Future<void> _handleExportFolderTap() async {
    final saved = _exportService.getSavedExportDirectory();
    final selected = await FilePicker.platform.getDirectoryPath(
      dialogTitle: '选择导出文件夹',
      initialDirectory: saved,
    );
    final normalized = selected?.trim() ?? '';
    if (normalized.isEmpty) {
      return;
    }
    try {
      await _exportService.saveExportDirectory(normalized);
    } catch (error, stackTrace) {
      ExceptionLogService().record(
        node: 'bookshelf.cache.export_folder.save_failed',
        message: '保存导出目录失败',
        error: error,
        stackTrace: stackTrace,
        context: <String, dynamic>{
          'directoryPath': normalized,
        },
      );
    }
  }

  Future<void> _handleExportFileNameTap() async {
    final controller = TextEditingController(
      text: _exportService.getBookExportFileName() ?? '',
    );
    try {
      final shouldSave = await showCupertinoBottomSheetDialog<bool>(
        context: context,
        builder: (dialogContext) {
          return CupertinoAlertDialog(
            title: const Text('导出文件名'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Variable: name, author.'),
                const SizedBox(height: 8),
                CupertinoTextField(
                  controller: controller,
                  placeholder: 'file name js',
                  textInputAction: TextInputAction.done,
                ),
              ],
            ),
            actions: [
              CupertinoDialogAction(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('取消'),
              ),
              CupertinoDialogAction(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('确定'),
              ),
            ],
          );
        },
      );
      if (shouldSave != true) {
        return;
      }
      await _exportService.saveBookExportFileName(controller.text);
    } catch (error, stackTrace) {
      ExceptionLogService().record(
        node: 'bookshelf.cache.export_file_name.save_failed',
        message: '保存导出文件名规则失败',
        error: error,
        stackTrace: stackTrace,
      );
    } finally {
      controller.dispose();
    }
  }

  String _currentExportTypeName() {
    final options = _exportService.getExportTypeOptions();
    if (_exportTypeIndex < 0 || _exportTypeIndex >= options.length) {
      return options.first;
    }
    return options[_exportTypeIndex];
  }

  Future<void> _handleExportTypeTap() async {
    if (!mounted) return;
    final options = _exportService.getExportTypeOptions();
    final selected = await showCupertinoBottomSheetDialog<int>(
      context: context,
      barrierDismissible: true,
      builder: (sheetContext) {
        return CupertinoActionSheet(
          title: const Text('导出格式'),
          actions: List<Widget>.generate(options.length, (index) {
            final option = options[index];
            return CupertinoActionSheetAction(
              onPressed: () => Navigator.pop(sheetContext, index),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_exportTypeIndex == index)
                    const Icon(CupertinoIcons.check_mark, size: 16)
                  else
                    const SizedBox(width: 16),
                  const SizedBox(width: 6),
                  Text(option),
                ],
              ),
            );
          }),
          cancelButton: CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(sheetContext),
            child: const Text('取消'),
          ),
        );
      },
    );
    if (selected == null || selected == _exportTypeIndex) {
      return;
    }

    final previous = _exportTypeIndex;
    if (!mounted) return;
    setState(() {
      _exportTypeIndex = selected;
    });
    try {
      await _exportService.saveExportTypeIndex(selected);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _exportTypeIndex = previous;
      });
      await _showMessage('切换失败：$error');
    }
  }

  Future<void> _handleExportCharsetTap() async {
    final controller = TextEditingController(
      text: _exportService.getExportCharset(),
    );
    try {
      final result = await showCupertinoBottomSheetDialog<String>(
        context: context,
        builder: (dialogContext) {
          return CupertinoAlertDialog(
            title: const Text('设置编码'),
            content: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CupertinoTextField(
                    controller: controller,
                    placeholder: 'charset name',
                  ),
                  const SizedBox(height: 10),
                  Text(
                    CacheExportTaskService.legacyExportCharsetOptions
                        .join(' / '),
                    textAlign: TextAlign.left,
                    style: TextStyle(
                      fontSize: 11,
                      color: CupertinoColors.secondaryLabel.resolveFrom(context)
                          .resolveFrom(dialogContext),
                    ),
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
                onPressed: () => Navigator.pop(dialogContext, controller.text),
                child: const Text('确定'),
              ),
            ],
          );
        },
      );
      if (result == null) {
        return;
      }
      await _exportService.saveExportCharset(result);
      if (!mounted) return;
      setState(() {
        _exportCharset = _exportService.getExportCharset();
      });
    } catch (error, stackTrace) {
      ExceptionLogService().record(
        node: 'bookshelf.cache.export_charset.save_failed',
        message: '保存导出编码失败',
        error: error,
        stackTrace: stackTrace,
      );
    } finally {
      controller.dispose();
    }
  }

  Future<void> _handleExportAllTap() async {
    if (_exportRunning) return;
    if (_books.isEmpty) {
      await _showMessage('暂无书籍');
      return;
    }

    if (!mounted) return;
    setState(() {
      _exportRunning = true;
    });

    try {
      final exportDirectory = await _resolveExportDirectory();
      if (exportDirectory == null) return;

      final summary = await _exportService.exportAllToDirectory(
        _books,
        exportDirectory,
        exportPictureFile: _exportPictureFile,
      );
      if (!mounted) return;
      await _showMessage(_buildExportSummaryMessage(summary));
    } catch (error) {
      if (!mounted) return;
      await _showMessage('导出失败：$error');
    } finally {
      if (!mounted) return;
      setState(() {
        _exportRunning = false;
      });
    }
  }

  Future<String?> _resolveExportDirectory() async {
    final saved = _exportService.getSavedExportDirectory();
    if (saved != null && await _exportService.isWritableDirectory(saved)) {
      return saved;
    }

    final selected = await FilePicker.platform.getDirectoryPath(
      dialogTitle: '选择导出文件夹',
      initialDirectory: saved,
    );
    final normalized = selected?.trim() ?? '';
    if (normalized.isEmpty) {
      return null;
    }
    if (!await _exportService.isWritableDirectory(normalized)) {
      return null;
    }
    await _exportService.saveExportDirectory(normalized);
    return normalized;
  }

  String _buildExportSummaryMessage(CacheExportSummary summary) {
    final failed = summary.failedBooks;
    final skipped = summary.skippedBooks;
    final success = summary.exportedBooks;
    return '导出完成：成功$success本，跳过$skipped本，失败$failed本，'
        '共导出${summary.exportedChapters}章\n目录：${summary.outputDirectory}';
  }

  Widget _buildDownloadAction() {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onLongPress: _handleDownloadActionLongPress,
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: _handleDownloadTap,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _downloadRunning
                  ? CupertinoIcons.stop_circle
                  : CupertinoIcons.cloud_download,
              size: 20,
            ),
            const SizedBox(width: 4),
            Text(_downloadRunning ? '停止' : '下载'),
          ],
        ),
      ),
    );
  }

  Widget _buildMoreAction() {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: _handleMoreTap,
      child: const Icon(CupertinoIcons.ellipsis_circle, size: 20),
    );
  }

  Widget _buildBookGroupAction() {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: _handleBookGroupTap,
      child: const Icon(CupertinoIcons.square_grid_2x2, size: 20),
    );
  }

  Widget _buildTopActions() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildDownloadAction(),
        const SizedBox(width: 8),
        _buildBookGroupAction(),
        const SizedBox(width: 8),
        _buildMoreAction(),
      ],
    );
  }

  Widget _buildNavMiddle() {
    final secondaryColor = CupertinoColors.secondaryLabel.resolveFrom(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('缓存/导出'),
        Text(
          _selectedGroupTitle,
          style: TextStyle(
            fontSize: 11,
            color: secondaryColor,
          ),
        ),
      ],
    );
  }

  Widget _buildProgressCard() {
    final progress = _progress;
    if (progress == null) {
      return const SizedBox.shrink();
    }
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: CupertinoColors.secondarySystemGroupedBackground.resolveFrom(context)
            .resolveFrom(context),
        borderRadius: BorderRadius.circular(AppDesignTokens.radiusCard),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '正在缓存：${progress.bookTitle}',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text(
            '当前书籍 ${progress.completedChapters}/${progress.requestedChapters} '
            '(新增${progress.downloadedChapters}，已缓存${progress.skippedChapters}，失败${progress.failedChapters})',
            style: const TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 4),
          Text(
            '整体进度 新增${progress.overallDownloadedChapters}，'
            '已缓存${progress.overallSkippedChapters}，失败${progress.overallFailedChapters}',
            style: TextStyle(
              fontSize: 12,
              color: CupertinoColors.secondaryLabel.resolveFrom(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMigrationHintCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: CupertinoColors.tertiarySystemGroupedBackground.resolveFrom(context)
            .resolveFrom(context),
        borderRadius: BorderRadius.circular(AppDesignTokens.radiusCard),
      ),
      child: Text(
        '缓存/导出（迁移中）',
        style: TextStyle(
          fontSize: 13,
          color: CupertinoColors.secondaryLabel.resolveFrom(context),
        ),
      ),
    );
  }

  Widget _buildBookTile(Book book) {
    final cachedCount = _cachedChapterCountByBookId[book.id] ?? 0;
    final totalCount =
        book.totalChapters > 0 ? book.totalChapters : cachedCount;
    final statusText = book.isLocal ? '本地书籍' : '已缓存 $cachedCount/$totalCount';
    final secondaryLabel =
        CupertinoColors.secondaryLabel.resolveFrom(context);
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      decoration: BoxDecoration(
        color: CupertinoColors.secondarySystemGroupedBackground.resolveFrom(context)
            .resolveFrom(context),
        borderRadius: BorderRadius.circular(AppDesignTokens.radiusCard),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  book.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  '作者：${book.author.isEmpty ? '未知' : book.author}',
                  style: TextStyle(fontSize: 13, color: secondaryLabel),
                ),
                const SizedBox(height: 4),
                Text(
                  '$statusText · 当前章节 ${book.currentChapter + 1}',
                  style: const TextStyle(fontSize: 13),
                ),
              ],
            ),
          ),
          // 缓存按钮（对齐 legado iv_download）
          if (!book.isLocal)
            CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              minimumSize: const Size(44, 44),
              onPressed: _downloadRunning ? null : () => _downloadSingleBook(book),
              child: Icon(
                CupertinoIcons.cloud_download,
                size: 20,
                color: _downloadRunning ? secondaryLabel : CupertinoColors.activeBlue.resolveFrom(context),
              ),
            ),
          // 导出按钮（对齐 legado tv_export）
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            minimumSize: const Size(44, 44),
            onPressed: _exportRunning ? null : () => _exportSingleBook(book),
            child: Icon(
              CupertinoIcons.square_arrow_up,
              size: 20,
              color: _exportRunning ? secondaryLabel : secondaryLabel,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final initError = _initError;
    return AppCupertinoPageScaffold(
      title: '缓存/导出',
      middle: _buildNavMiddle(),
      trailing: _buildTopActions(),
      child: initError == null
          ? Column(
              children: [
                _buildMigrationHintCard(),
                _buildProgressCard(),
                Expanded(
                  child: _books.isEmpty
                      ? const AppEmptyState(
                          illustration: AppEmptyPlanetIllustration(size: 86),
                          title: '暂无书籍',
                          message: '请先在书架添加书籍，或切换分组后重试。',
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.only(top: 12, bottom: 16),
                          itemCount: _books.length,
                          itemBuilder: (context, index) {
                            final book = _books[index];
                            return _buildBookTile(book);
                          },
                        ),
                ),
              ],
            )
          : Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  initError,
                  style: TextStyle(
                    color: CupertinoColors.systemRed.resolveFrom(context),
                  ),
                ),
              ),
            ),
    );
  }
}
