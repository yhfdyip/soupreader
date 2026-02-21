import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../app/widgets/app_cupertino_page_scaffold.dart';
import '../../../app/widgets/app_cover_image.dart';
import '../../../core/database/database_service.dart';
import '../../../core/database/repositories/book_repository.dart';
import '../../../core/database/repositories/source_repository.dart';
import '../../../core/models/app_settings.dart';
import '../../../core/services/settings_service.dart';
import '../../import/import_service.dart';
import '../../reader/views/simple_reader_view.dart';
import '../../search/views/search_book_info_view.dart';
import '../../search/views/search_view.dart';
import '../../settings/views/app_log_dialog.dart';
import '../../source/models/book_source.dart';
import '../../source/services/rule_parser_engine.dart';
import 'cache_export_placeholder_view.dart';
import 'bookshelf_manage_placeholder_view.dart';
import 'bookshelf_group_manage_placeholder_dialog.dart';
import 'remote_books_placeholder_view.dart';
import '../services/book_add_service.dart';
import '../services/bookshelf_booklist_import_service.dart';
import '../services/bookshelf_catalog_update_service.dart';
import '../services/bookshelf_import_export_service.dart';
import '../models/book.dart';

/// 书架页面 - 纯 iOS 原生风格
class BookshelfView extends StatefulWidget {
  final ValueListenable<int>? reselectSignal;

  const BookshelfView({
    super.key,
    this.reselectSignal,
  });

  @override
  State<BookshelfView> createState() => _BookshelfViewState();
}

class _BookshelfViewState extends State<BookshelfView> {
  bool _isGridView = true;
  int _gridCrossAxisCount = 3;
  // 与 legado 一致：图墙/列表都可展示“更新中”状态。
  final Set<String> _updatingBookIds = <String>{};
  final ScrollController _scrollController = ScrollController();
  late final BookRepository _bookRepo;
  late final SourceRepository _sourceRepo;
  late final BookAddService _bookAddService;
  late final ImportService _importService;
  late final SettingsService _settingsService;
  late final BookshelfImportExportService _bookshelfIo;
  late final BookshelfBooklistImportService _booklistImporter;
  late final BookshelfCatalogUpdateService _catalogUpdater;
  StreamSubscription<List<Book>>? _booksSubscription;
  List<Book> _books = [];
  bool _isImporting = false;
  bool _isAddingByUrl = false;
  bool _cancelAddByUrlRequested = false;
  bool _isUpdatingCatalog = false;
  String? _initError;
  int? _lastExternalReselectVersion;

  @override
  void initState() {
    super.initState();
    try {
      debugPrint('[bookshelf] init start');
      final db = DatabaseService();
      _bookRepo = BookRepository(db);
      _sourceRepo = SourceRepository(db);
      _bookAddService = BookAddService(database: db);
      _importService = ImportService();
      _settingsService = SettingsService();
      _bookshelfIo = BookshelfImportExportService();
      _booklistImporter = BookshelfBooklistImportService();
      _catalogUpdater = BookshelfCatalogUpdateService(
        database: db,
        bookRepo: _bookRepo,
      );
      final initialLayoutIndex = _normalizeLayoutIndex(
          _settingsService.appSettings.bookshelfLayoutIndex);
      _isGridView = initialLayoutIndex > 0;
      _gridCrossAxisCount = _gridColumnsForLayoutIndex(initialLayoutIndex);
      _lastExternalReselectVersion = widget.reselectSignal?.value;
      widget.reselectSignal?.addListener(_onExternalReselectSignal);
      _loadBooks();
      _booksSubscription = _bookRepo.watchAllBooks().listen((books) {
        if (!mounted) return;
        setState(() {
          _books = List<Book>.from(books);
          _sortBooks(_settingsService.appSettings.bookshelfSortIndex);
        });
      });
      debugPrint('[bookshelf] init done, books=\${_books.length}');
    } catch (e, st) {
      _initError = '书架初始化异常: $e';
      debugPrint('[bookshelf] init failed: $e');
      debugPrintStack(stackTrace: st);
    }
  }

  @override
  void didUpdateWidget(covariant BookshelfView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reselectSignal == widget.reselectSignal) return;
    oldWidget.reselectSignal?.removeListener(_onExternalReselectSignal);
    _lastExternalReselectVersion = widget.reselectSignal?.value;
    widget.reselectSignal?.addListener(_onExternalReselectSignal);
  }

  @override
  void dispose() {
    _booksSubscription?.cancel();
    widget.reselectSignal?.removeListener(_onExternalReselectSignal);
    _scrollController.dispose();
    super.dispose();
  }

  void _onExternalReselectSignal() {
    final version = widget.reselectSignal?.value;
    if (version == null) return;
    if (_lastExternalReselectVersion == version) return;
    _lastExternalReselectVersion = version;
    _scrollToTop();
  }

  void _scrollToTop() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOut,
    );
  }

  void _loadBooks() {
    setState(() {
      _books = List<Book>.from(_bookRepo.getAllBooks());
      _sortBooks(_settingsService.appSettings.bookshelfSortIndex);
    });
  }

  int _normalizeLayoutIndex(int index) {
    return index.clamp(0, 4);
  }

  int _normalizeSortIndex(int index) {
    return index.clamp(0, 5);
  }

  int _gridColumnsForLayoutIndex(int index) {
    final normalized = _normalizeLayoutIndex(index);
    if (normalized == 0) return 3;
    return normalized + 2;
  }

  void _sortBooks(int sortIndex) {
    int compareDateTimeDesc(DateTime? a, DateTime? b) {
      final aTime = a ?? DateTime(2000);
      final bTime = b ?? DateTime(2000);
      return bTime.compareTo(aTime);
    }

    final normalized = _normalizeSortIndex(sortIndex);
    if (normalized == 3) {
      // legado“手动排序”在当前阶段无独立 order 字段，保持数据库原顺序。
      return;
    }

    _books.sort((a, b) {
      switch (normalized) {
        case 0:
          return compareDateTimeDesc(
            a.lastReadTime ?? a.addedTime,
            b.lastReadTime ?? b.addedTime,
          );
        case 1:
          return compareDateTimeDesc(a.addedTime, b.addedTime);
        case 2:
          return a.title.compareTo(b.title);
        case 4:
          return compareDateTimeDesc(
            _maxDateTime(a.lastReadTime, a.addedTime),
            _maxDateTime(b.lastReadTime, b.addedTime),
          );
        case 5:
          return a.author.compareTo(b.author);
        default:
          return 0;
      }
    });
  }

  DateTime? _maxDateTime(DateTime? a, DateTime? b) {
    if (a == null) return b;
    if (b == null) return a;
    return a.isAfter(b) ? a : b;
  }

  Future<void> _importLocalBook() async {
    if (_isImporting) return;

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

  Future<void> _openGlobalSearch() async {
    await Navigator.of(context, rootNavigator: true).push(
      CupertinoPageRoute<void>(
        builder: (_) => const SearchView(),
      ),
    );
    if (!mounted) return;
    _loadBooks();
  }

  Future<void> _openRemoteBooks() async {
    await Navigator.of(context, rootNavigator: true).push(
      CupertinoPageRoute<void>(
        builder: (_) => const RemoteBooksPlaceholderView(),
      ),
    );
  }

  Future<void> _openBookshelfManage() async {
    await Navigator.of(context, rootNavigator: true).push(
      CupertinoPageRoute<void>(
        builder: (_) => const BookshelfManagePlaceholderView(),
      ),
    );
  }

  Future<void> _openCacheExport() async {
    await Navigator.of(context, rootNavigator: true).push(
      CupertinoPageRoute<void>(
        builder: (_) => const CacheExportPlaceholderView(),
      ),
    );
  }

  Future<void> _openBookshelfGroupManageDialog() async {
    await showCupertinoDialog<void>(
      context: context,
      builder: (_) => const BookshelfGroupManagePlaceholderDialog(),
    );
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
      progressDialogFuture = showCupertinoDialog<void>(
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

  Future<void> _showAddBookByUrlDialog() async {
    final controller = TextEditingController();
    await showCupertinoDialog<void>(
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
      _showMessage('导出成功');
      return;
    }
    _showExportSuccessDialog(hint);
  }

  void _showExportSuccessDialog(String pathOrHint) {
    showCupertinoDialog<void>(
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
              _showMessage('已复制到剪贴板');
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
    await showCupertinoDialog<void>(
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
    showCupertinoDialog(
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

  Widget _buildLayoutSwitchRow({
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontSize: 14),
            ),
          ),
          CupertinoSwitch(
            value: value,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildLayoutChoiceRow({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onTap,
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: selected
                    ? CupertinoColors.activeBlue
                    : CupertinoColors.label.resolveFrom(context),
              ),
            ),
          ),
          if (selected)
            const Icon(
              CupertinoIcons.check_mark,
              size: 16,
              color: CupertinoColors.activeBlue,
            ),
        ],
      ),
    );
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
    final normalizedLayout = _normalizeLayoutIndex(layoutIndex);
    final normalizedSort = _normalizeSortIndex(sortIndex);
    final nextSettings = _settingsService.appSettings.copyWith(
      bookshelfGroupStyle: groupStyle.clamp(0, 1),
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
    });
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

    await showCupertinoDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return CupertinoAlertDialog(
              title: const Text('书架布局'),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 12),
                      const Text(
                        '分组样式',
                        style: TextStyle(fontSize: 13),
                      ),
                      const SizedBox(height: 6),
                      CupertinoSlidingSegmentedControl<int>(
                        groupValue: groupStyle,
                        children: const {
                          0: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 10),
                            child: Text('样式一'),
                          ),
                          1: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 10),
                            child: Text('样式二'),
                          ),
                        },
                        onValueChanged: (value) {
                          if (value == null) return;
                          setDialogState(() => groupStyle = value);
                        },
                      ),
                      _buildLayoutSwitchRow(
                        title: '显示未读数量',
                        value: showUnread,
                        onChanged: (value) {
                          setDialogState(() => showUnread = value);
                        },
                      ),
                      _buildLayoutSwitchRow(
                        title: '显示最新更新时间',
                        value: showLastUpdateTime,
                        onChanged: (value) {
                          setDialogState(() => showLastUpdateTime = value);
                        },
                      ),
                      _buildLayoutSwitchRow(
                        title: '显示待更新计数',
                        value: showWaitUpCount,
                        onChanged: (value) {
                          setDialogState(() => showWaitUpCount = value);
                        },
                      ),
                      _buildLayoutSwitchRow(
                        title: '显示快速滚动条',
                        value: showFastScroller,
                        onChanged: (value) {
                          setDialogState(() => showFastScroller = value);
                        },
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        '视图',
                        style: TextStyle(fontSize: 13),
                      ),
                      for (var i = 0; i <= 4; i++)
                        _buildLayoutChoiceRow(
                          label: _layoutLabel(i),
                          selected: layoutIndex == i,
                          onTap: () {
                            setDialogState(() => layoutIndex = i);
                          },
                        ),
                      const SizedBox(height: 10),
                      const Text(
                        '排序',
                        style: TextStyle(fontSize: 13),
                      ),
                      for (var i = 0; i <= 5; i++)
                        _buildLayoutChoiceRow(
                          label: _legacySortLabel(i),
                          selected: sortIndex == i,
                          onTap: () {
                            setDialogState(() => sortIndex = i);
                          },
                        ),
                    ],
                  ),
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
                    Navigator.pop(dialogContext);
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
                  child: const Text('确定'),
                ),
              ],
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

  void _showMoreMenu() {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('书架'),
        actions: [
          CupertinoActionSheetAction(
            child: Text(_updateCatalogMenuText()),
            onPressed: () {
              Navigator.pop(context);
              _updateBookshelfCatalog();
            },
          ),
          CupertinoActionSheetAction(
            child: const Text('添加本地'),
            onPressed: () {
              Navigator.pop(context);
              _importLocalBook();
            },
          ),
          CupertinoActionSheetAction(
            child: const Text('远程书籍'),
            onPressed: () {
              Navigator.pop(context);
              _openRemoteBooks();
            },
          ),
          CupertinoActionSheetAction(
            child: const Text('添加网址'),
            onPressed: () {
              Navigator.pop(context);
              _showAddBookByUrlDialog();
            },
          ),
          CupertinoActionSheetAction(
            child: const Text('书架管理'),
            onPressed: () {
              Navigator.pop(context);
              _openBookshelfManage();
            },
          ),
          CupertinoActionSheetAction(
            child: const Text('缓存/导出'),
            onPressed: () {
              Navigator.pop(context);
              _openCacheExport();
            },
          ),
          CupertinoActionSheetAction(
            child: const Text('分组管理'),
            onPressed: () {
              Navigator.pop(context);
              _openBookshelfGroupManageDialog();
            },
          ),
          CupertinoActionSheetAction(
            child: const Text('书架布局'),
            onPressed: () {
              Navigator.pop(context);
              _showLayoutConfigDialog();
            },
          ),
          CupertinoActionSheetAction(
            child: const Text('导出书单'),
            onPressed: () {
              Navigator.pop(context);
              _exportBookshelf();
            },
          ),
          CupertinoActionSheetAction(
            child: const Text('导入书单'),
            onPressed: () {
              Navigator.pop(context);
              _showImportBookshelfDialog();
            },
          ),
          CupertinoActionSheetAction(
            child: const Text('日志'),
            onPressed: () {
              Navigator.pop(context);
              _openAppLogDialog();
            },
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          child: const Text('取消'),
          onPressed: () => Navigator.pop(context),
        ),
      ),
    );
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

    final snapshot = _books.toList(growable: false);
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
    showCupertinoDialog(
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

  int _waitUpCount() {
    return _books.where((book) {
      if (book.isLocal) return false;
      return _settingsService.getBookCanUpdate(book.id);
    }).length;
  }

  Widget? _buildBookshelfMiddleTitle() {
    final settings = _settingsService.appSettings;
    if (!settings.bookshelfShowWaitUpCount) return null;
    final count = _waitUpCount();
    if (count <= 0) {
      return const Text('书架');
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('书架'),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: CupertinoColors.systemRed.resolveFrom(context),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            count > 99 ? '99+' : '$count',
            style: const TextStyle(
              fontSize: 11,
              color: CupertinoColors.white,
              fontWeight: FontWeight.w600,
              height: 1.1,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppCupertinoPageScaffold(
      title: '书架',
      middle: _buildBookshelfMiddleTitle(),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CupertinoButton(
            padding: EdgeInsets.zero,
            minimumSize: const Size(30, 30),
            onPressed: _openGlobalSearch,
            child: const Icon(CupertinoIcons.search),
          ),
          CupertinoButton(
            padding: EdgeInsets.zero,
            minimumSize: const Size(30, 30),
            onPressed: _showMoreMenu,
            child: const Icon(CupertinoIcons.ellipsis),
          ),
        ],
      ),
      child: _initError != null
          ? _buildInitError()
          : (_books.isEmpty ? _buildEmptyState() : _buildBookList()),
    );
  }

  Widget _buildInitError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(CupertinoIcons.exclamationmark_triangle, size: 40),
            const SizedBox(height: 12),
            Text(
              _initError ?? '初始化失败',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final theme = ShadTheme.of(context);
    final scheme = theme.colorScheme;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            LucideIcons.bookOpen,
            size: 52,
            color: scheme.mutedForeground,
          ),
          const SizedBox(height: 16),
          Text(
            '书架空空如也',
            style: theme.textTheme.h4,
          ),
          const SizedBox(height: 24),
          ShadButton(
            onPressed: _importLocalBook,
            leading: const Icon(LucideIcons.fileUp),
            child: const Text('导入本地书籍'),
          ),
        ],
      ),
    );
  }

  Widget _buildBookList() {
    if (_isGridView) {
      return _buildGridView();
    } else {
      return _buildListView();
    }
  }

  Widget _wrapWithFastScroller(Widget child) {
    if (!_settingsService.appSettings.bookshelfShowFastScroller) {
      return child;
    }
    return CupertinoScrollbar(
      controller: _scrollController,
      thumbVisibility: true,
      child: child,
    );
  }

  Widget _buildGridView() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 16),
      child: _wrapWithFastScroller(
        GridView.builder(
          controller: _scrollController,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: _gridCrossAxisCount,
            childAspectRatio: 0.56,
            crossAxisSpacing: 2,
            mainAxisSpacing: 6,
          ),
          itemCount: _books.length,
          itemBuilder: (context, index) {
            final book = _books[index];
            return _buildBookCard(book);
          },
        ),
      ),
    );
  }

  Widget _buildBookCard(Book book) {
    final unreadCount = _settingsService.appSettings.bookshelfShowUnread
        ? _unreadCountLikeLegado(book)
        : 0;
    final isUpdating = _isUpdating(book);

    return GestureDetector(
      onTap: () => _openReader(book),
      onLongPress: () => _onBookLongPress(book),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: CupertinoColors.systemGrey5.resolveFrom(context),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: AppCoverImage(
                        urlOrPath: book.coverUrl,
                        title: book.title,
                        author: book.author,
                        width: double.infinity,
                        height: double.infinity,
                        borderRadius: 8,
                      ),
                    ),
                  ),
                  Positioned(
                    top: -2,
                    right: -2,
                    child: isUpdating
                        ? _buildGridLoadingBadge()
                        : _buildGridUnreadBadge(unreadCount),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Text(
              book.title,
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                height: 1.25,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGridLoadingBadge() {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: CupertinoColors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(11),
      ),
      alignment: Alignment.center,
      child: const CupertinoActivityIndicator(radius: 6),
    );
  }

  Widget _buildGridUnreadBadge(int unreadCount) {
    if (unreadCount <= 0) return const SizedBox.shrink();

    return Container(
      constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: CupertinoColors.systemRed.resolveFrom(context),
        borderRadius: BorderRadius.circular(9),
      ),
      alignment: Alignment.center,
      child: Text(
        _formatUnreadCount(unreadCount),
        style: const TextStyle(
          color: CupertinoColors.white,
          fontSize: 10,
          fontWeight: FontWeight.w600,
          height: 1.1,
        ),
      ),
    );
  }

  String _formatUnreadCount(int unreadCount) {
    if (unreadCount > 99) return '99+';
    return '$unreadCount';
  }

  int _unreadCountLikeLegado(Book book) {
    final total = book.totalChapters;
    if (total <= 0) return 0;
    final current = book.currentChapter.clamp(0, total - 1);
    return math.max(total - current - 1, 0);
  }

  bool _isUpdating(Book book) {
    if (book.isLocal) return false;
    return _updatingBookIds.contains(book.id);
  }

  Widget _buildListView() {
    final theme = ShadTheme.of(context);
    final scheme = theme.colorScheme;
    final showLastUpdateTime =
        _settingsService.appSettings.bookshelfShowLastUpdateTime;

    return _wrapWithFastScroller(
      ListView.separated(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        itemCount: _books.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final book = _books[index];
          final readAgo = _formatReadAgo(book.lastReadTime);
          final isUpdating = _isUpdating(book);
          return GestureDetector(
            onTap: () => _openReader(book),
            onLongPress: () => _onBookLongPress(book),
            child: ShadCard(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppCoverImage(
                    urlOrPath: book.coverUrl,
                    title: book.title,
                    author: book.author,
                    width: 66,
                    height: 90,
                    borderRadius: 8,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                book.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.p.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: scheme.foreground,
                                ),
                              ),
                            ),
                            if (book.isReading)
                              Container(
                                margin: const EdgeInsets.only(left: 6),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 1,
                                ),
                                decoration: BoxDecoration(
                                  color: scheme.primary.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  book.progressText,
                                  style: theme.textTheme.small.copyWith(
                                    color: scheme.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        Row(
                          children: [
                            Icon(
                              CupertinoIcons.person,
                              size: 13,
                              color: scheme.mutedForeground,
                            ),
                            const SizedBox(width: 5),
                            Expanded(
                              child: Text(
                                book.author.trim().isEmpty
                                    ? '未知作者'
                                    : book.author,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.small.copyWith(
                                  color: scheme.mutedForeground,
                                ),
                              ),
                            ),
                            if (showLastUpdateTime && readAgo != null)
                              Text(
                                readAgo,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.small.copyWith(
                                  color: scheme.mutedForeground,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        Row(
                          children: [
                            Icon(
                              CupertinoIcons.clock,
                              size: 13,
                              color: scheme.mutedForeground,
                            ),
                            const SizedBox(width: 5),
                            Expanded(
                              child: Text(
                                _buildReadLine(book),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.small.copyWith(
                                  color: scheme.mutedForeground,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        Row(
                          children: [
                            Icon(
                              CupertinoIcons.book,
                              size: 13,
                              color: scheme.mutedForeground,
                            ),
                            const SizedBox(width: 5),
                            Expanded(
                              child: Text(
                                _buildLatestLine(book),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.small.copyWith(
                                  color: scheme.mutedForeground,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: isUpdating
                        ? const CupertinoActivityIndicator(radius: 8)
                        : Icon(
                            LucideIcons.chevronRight,
                            size: 16,
                            color: scheme.mutedForeground,
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  String _buildReadLine(Book book) {
    final total = book.totalChapters;
    if (total <= 0) {
      return book.isReading ? '阅读进度 ${book.progressText}' : '未开始阅读';
    }
    final current = (book.currentChapter + 1).clamp(1, total);
    if (!book.isReading) {
      return '未开始阅读 · 共 $total 章';
    }
    final unreadCount = _settingsService.appSettings.bookshelfShowUnread
        ? _unreadCountLikeLegado(book)
        : 0;
    if (unreadCount <= 0) {
      return '阅读：$current/$total 章';
    }
    return '阅读：$current/$total 章 · 未读 $unreadCount';
  }

  String _buildLatestLine(Book book) {
    final latest = (book.latestChapter ?? '').trim();
    if (latest.isNotEmpty) {
      return '最新：$latest';
    }
    if (book.isLocal) {
      return '本地书籍';
    }
    return '暂无最新章节';
  }

  String? _formatReadAgo(DateTime? value) {
    if (value == null) return null;
    final now = DateTime.now();
    final diff = now.difference(value);
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inHours < 1) return '${diff.inMinutes}分钟前';
    if (diff.inDays < 1) return '${diff.inHours}小时前';
    if (diff.inDays < 30) return '${diff.inDays}天前';

    String two(int n) => n.toString().padLeft(2, '0');
    return '${value.year}-${two(value.month)}-${two(value.day)}';
  }

  void _openReader(Book book) {
    Navigator.of(context, rootNavigator: true)
        .push(
          CupertinoPageRoute(
            builder: (context) => SimpleReaderView(
              bookId: book.id,
              bookTitle: book.title,
              initialChapter: book.currentChapter,
            ),
          ),
        )
        .then((_) => _loadBooks()); // 返回时刷新列表
  }

  void _onBookLongPress(Book book) {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: Text(book.title),
        actions: [
          CupertinoActionSheetAction(
            child: const Text('书籍详情'),
            onPressed: () {
              Navigator.pop(context);
              _showBookInfo(book);
            },
          ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            child: const Text('移除书籍'),
            onPressed: () async {
              Navigator.pop(context);
              await _bookRepo.deleteBook(book.id);
              _loadBooks();
            },
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          child: const Text('取消'),
          onPressed: () => Navigator.pop(context),
        ),
      ),
    );
  }

  Future<void> _showBookInfo(Book book) async {
    await Navigator.of(context, rootNavigator: true).push(
      CupertinoPageRoute<void>(
        builder: (_) => SearchBookInfoView.fromBookshelf(book: book),
      ),
    );
    if (!mounted) return;
    _loadBooks();
  }
}
