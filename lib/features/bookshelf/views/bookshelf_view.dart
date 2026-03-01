import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

import '../../../app/widgets/app_cupertino_page_scaffold.dart';
import '../../../app/widgets/app_cover_image.dart';
import '../../../app/widgets/app_popover_menu.dart';
import '../../../app/widgets/cupertino_bottom_dialog.dart';
import '../../../core/database/database_service.dart';
import '../../../core/database/repositories/book_repository.dart';
import '../../../core/database/repositories/source_repository.dart';
import '../../../core/models/app_settings.dart';
import '../../../core/services/exception_log_service.dart';
import '../../../core/services/settings_service.dart';
import '../../import/book_import_file_name_rule_service.dart';
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
import '../services/book_add_service.dart';
import '../services/bookshelf_book_group_store.dart';
import '../services/bookshelf_booklist_import_service.dart';
import '../services/bookshelf_catalog_update_service.dart';
import '../services/bookshelf_import_export_service.dart';
import '../models/book.dart';
import '../models/bookshelf_book_group.dart';

enum _ImportFolderAction {
  select,
  create,
}

enum _BookshelfMoreMenuAction {
  updateCatalog,
  importLocal,
  selectFolder,
  scanFolder,
  importFileNameRule,
  addUrl,
  manage,
  cacheExport,
  groupManage,
  layout,
  exportBooklist,
  importBooklist,
  log,
}

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
  static const String _bookGroupMembershipSettingKey =
      'bookshelf.book_group_membership_map';
  static const String _style1SelectedTabIndexSettingKey =
      'bookshelf.style1_selected_tab_index';
  bool _isGridView = true;
  int _gridCrossAxisCount = 3;
  // 与 legado 一致：图墙/列表都可展示“更新中”状态。
  final Set<String> _updatingBookIds = <String>{};
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _moreMenuKey = GlobalKey();
  late final DatabaseService _database;
  late final BookRepository _bookRepo;
  late final SourceRepository _sourceRepo;
  late final BookAddService _bookAddService;
  late final ImportService _importService;
  late final BookImportFileNameRuleService _bookImportFileNameRuleService;
  late final BookshelfBookGroupStore _bookGroupStore;
  late final SettingsService _settingsService;
  late final BookshelfImportExportService _bookshelfIo;
  late final BookshelfBooklistImportService _booklistImporter;
  late final BookshelfCatalogUpdateService _catalogUpdater;
  StreamSubscription<List<Book>>? _booksSubscription;
  List<Book> _books = [];
  bool _isImporting = false;
  bool _isSelectingImportFolder = false;
  bool _isScanningImportFolder = false;
  bool _isAddingByUrl = false;
  bool _cancelAddByUrlRequested = false;
  bool _isUpdatingCatalog = false;
  String? _initError;
  int? _lastExternalReselectVersion;
  List<BookshelfBookGroup> _bookGroups = _defaultBookGroups;
  Map<String, int> _bookGroupMembershipMap = const <String, int>{};
  // 与 legado style2 一致：根态是独立的 IdRoot，而不是“全部”分组本身。
  int _selectedGroupId = BookshelfBookGroup.idRoot;
  // 与 legado AppConfig.saveTabPosition 对齐：style1 记录分组页签索引。
  int _style1SelectedTabIndex = 0;

  // 与 legado 对齐：内置分组的语义和顺序需要稳定保底，避免旧数据缺项导致 UI 行为漂移。
  static const List<BookshelfBookGroup> _defaultBookGroups =
      <BookshelfBookGroup>[
    BookshelfBookGroup(
      groupId: BookshelfBookGroup.idAll,
      groupName: '全部',
      show: true,
      order: -10,
      bookSort: -1,
      enableRefresh: true,
    ),
    BookshelfBookGroup(
      groupId: BookshelfBookGroup.idLocal,
      groupName: '本地',
      show: true,
      order: -9,
      bookSort: -1,
      enableRefresh: false,
    ),
    BookshelfBookGroup(
      groupId: BookshelfBookGroup.idAudio,
      groupName: '音频',
      show: true,
      order: -8,
      bookSort: -1,
      enableRefresh: true,
    ),
    BookshelfBookGroup(
      groupId: BookshelfBookGroup.idNetNone,
      groupName: '网络未分组',
      show: true,
      order: -7,
      bookSort: -1,
      enableRefresh: true,
    ),
    BookshelfBookGroup(
      groupId: BookshelfBookGroup.idLocalNone,
      groupName: '本地未分组',
      show: false,
      order: -6,
      bookSort: -1,
      enableRefresh: true,
    ),
    BookshelfBookGroup(
      groupId: BookshelfBookGroup.idError,
      groupName: '更新失败',
      show: true,
      order: -1,
      bookSort: -1,
      enableRefresh: true,
    ),
  ];

  @override
  void initState() {
    super.initState();
    try {
      debugPrint('[bookshelf] init start');
      _settingsService = SettingsService();
      final db = DatabaseService();
      _database = db;
      _bookRepo = BookRepository(db);
      _sourceRepo = SourceRepository(db);
      _bookAddService = BookAddService(database: db);
      _importService = ImportService();
      _bookImportFileNameRuleService = BookImportFileNameRuleService();
      _bookGroupStore = BookshelfBookGroupStore(database: db);
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
      _style1SelectedTabIndex = _readStyle1SelectedTabIndex();
      _lastExternalReselectVersion = widget.reselectSignal?.value;
      widget.reselectSignal?.addListener(_onExternalReselectSignal);
      _loadBooks();
      unawaited(_reloadBookGroupContext(showError: false));
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
    // 与 legado 一致：E-Ink 模式不做平滑动画，避免刷新残影。
    if (_settingsService.appSettings.appearanceMode == AppAppearanceMode.eInk) {
      _scrollController.jumpTo(0);
      return;
    }
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
    _sortBookList(_books, sortIndex);
  }

  void _sortBookList(List<Book> books, int sortIndex) {
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

    books.sort((a, b) {
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

  bool get _isStyle2Enabled {
    return _settingsService.appSettings.bookshelfGroupStyle == 1;
  }

  Future<void> _reloadBookGroupContext({required bool showError}) async {
    try {
      final groups = await _bookGroupStore.getGroups();
      if (!mounted) return;
      final normalizedGroups = _normalizeGroups(groups);
      final groupMembership = _readBookGroupMembershipMap();
      var nextSelectedGroupId = _selectedGroupId;
      final hasSelectedGroup = nextSelectedGroupId ==
              BookshelfBookGroup.idRoot ||
          normalizedGroups.any((group) => group.groupId == nextSelectedGroupId);
      if (!hasSelectedGroup) {
        nextSelectedGroupId = BookshelfBookGroup.idRoot;
      }
      setState(() {
        _bookGroups = normalizedGroups;
        _bookGroupMembershipMap = groupMembership;
        _selectedGroupId = nextSelectedGroupId;
      });
    } catch (error, stackTrace) {
      debugPrint('[bookshelf] 加载分组失败: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!showError || !mounted) return;
      _showMessage('加载分组失败：$error');
    }
  }

  List<BookshelfBookGroup> _normalizeGroups(List<BookshelfBookGroup> groups) {
    final byId = <int, BookshelfBookGroup>{
      for (final group in groups) group.groupId: group,
    };
    for (final fallback in _defaultBookGroups) {
      byId.putIfAbsent(fallback.groupId, () => fallback);
    }
    final normalized = byId.values.toList(growable: false);
    normalized.sort((a, b) {
      final byOrder = a.order.compareTo(b.order);
      if (byOrder != 0) return byOrder;
      return a.groupId.compareTo(b.groupId);
    });
    return normalized;
  }

  Map<String, int> _readBookGroupMembershipMap() {
    final raw = _database.getSetting(
      _bookGroupMembershipSettingKey,
      defaultValue: const <String, dynamic>{},
    );
    if (raw is! Map) return const <String, int>{};
    final parsed = <String, int>{};
    raw.forEach((key, value) {
      final bookId = '$key'.trim();
      if (bookId.isEmpty) return;
      parsed[bookId] = _parseGroupBits(value);
    });
    return parsed;
  }

  int _parseGroupBits(dynamic raw) {
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    if (raw is String) return int.tryParse(raw.trim()) ?? 0;
    return 0;
  }

  int _readStyle1SelectedTabIndex() {
    final raw = _database.getSetting(
      _style1SelectedTabIndexSettingKey,
      defaultValue: 0,
    );
    if (raw is int) return math.max(raw, 0);
    if (raw is num) return math.max(raw.toInt(), 0);
    if (raw is String) {
      return math.max(int.tryParse(raw.trim()) ?? 0, 0);
    }
    return 0;
  }

  Future<void> _persistStyle1SelectedTabIndex(int index) async {
    final normalized = math.max(index, 0);
    try {
      await _database.putSetting(_style1SelectedTabIndexSettingKey, normalized);
      debugPrint('[bookshelf] style1 save tab index=$normalized');
    } catch (error, stackTrace) {
      ExceptionLogService().record(
        node: 'bookshelf.style1.save_tab_index',
        message: '保存 style1 分组页签索引失败',
        error: error,
        stackTrace: stackTrace,
        context: <String, dynamic>{
          'tabIndex': normalized,
        },
      );
    }
  }

  int _resolveCustomGroupMask() {
    var mask = 0;
    for (final group in _bookGroups) {
      if (group.groupId > 0) {
        mask |= group.groupId;
      }
    }
    return mask;
  }

  List<Book> _filterBooksByGroup(List<Book> books, int groupId) {
    switch (groupId) {
      case BookshelfBookGroup.idAll:
        return books;
      case BookshelfBookGroup.idLocal:
        return books.where((book) => book.isLocal).toList(growable: false);
      case BookshelfBookGroup.idAudio:
      case BookshelfBookGroup.idError:
        // 当前模型未承载 legado 音频/更新失败类型位，保持入口但回落空集。
        return const <Book>[];
      case BookshelfBookGroup.idNetNone:
        final customMask = _resolveCustomGroupMask();
        return books.where((book) {
          if (book.isLocal) return false;
          final membership = _bookGroupMembershipMap[book.id] ?? 0;
          return (membership & customMask) == 0;
        }).toList(growable: false);
      case BookshelfBookGroup.idLocalNone:
        final customMask = _resolveCustomGroupMask();
        return books.where((book) {
          if (!book.isLocal) return false;
          final membership = _bookGroupMembershipMap[book.id] ?? 0;
          return (membership & customMask) == 0;
        }).toList(growable: false);
      default:
        if (groupId == BookshelfBookGroup.longMinValue) {
          return books.where((book) {
            final membership = _bookGroupMembershipMap[book.id] ?? 0;
            return membership == groupId;
          }).toList(growable: false);
        }
        if (groupId > 0) {
          return books.where((book) {
            final membership = _bookGroupMembershipMap[book.id] ?? 0;
            return (membership & groupId) > 0;
          }).toList(growable: false);
        }
        return const <Book>[];
    }
  }

  List<BookshelfBookGroup> _visibleGroupsForRoot() {
    final visible = _bookGroups
        .where((group) => _shouldShowGroupOnRoot(group))
        .toList(growable: false);
    visible.sort((a, b) {
      final byOrder = a.order.compareTo(b.order);
      if (byOrder != 0) return byOrder;
      return a.groupId.compareTo(b.groupId);
    });
    return visible;
  }

  /// 与 legado style1 的 TabLayout 数据源一致：复用 `bookGroupDao.show` 语义。
  List<BookshelfBookGroup> _visibleGroupsForStyle1() {
    final visible = _visibleGroupsForRoot();
    if (visible.isNotEmpty) return visible;
    for (final group in _bookGroups) {
      if (group.groupId == BookshelfBookGroup.idAll) {
        return <BookshelfBookGroup>[group];
      }
    }
    return const <BookshelfBookGroup>[];
  }

  int _resolveStyle1SelectedTabIndex(List<BookshelfBookGroup> groups) {
    if (groups.isEmpty) return 0;
    return _style1SelectedTabIndex.clamp(0, groups.length - 1);
  }

  BookshelfBookGroup? _selectedStyle1GroupOrNull() {
    final groups = _visibleGroupsForStyle1();
    if (groups.isEmpty) return null;
    return groups[_resolveStyle1SelectedTabIndex(groups)];
  }

  /// 与 legado `bookGroupDao.show` 对齐：
  /// 根态只展示“可见且存在匹配书籍”的分组；`全部`分组始终展示。
  bool _shouldShowGroupOnRoot(BookshelfBookGroup group) {
    if (!group.show) return false;
    if (group.groupId == BookshelfBookGroup.idAll) return true;
    return _filterBooksByGroup(_books, group.groupId).isNotEmpty;
  }

  int _resolveSortIndexForCurrentGroup() {
    var sortIndex = _settingsService.appSettings.bookshelfSortIndex;
    if (_isStyle2Enabled) {
      if (_selectedGroupId == BookshelfBookGroup.idRoot) {
        return sortIndex;
      }
      BookshelfBookGroup? selectedGroup;
      for (final group in _bookGroups) {
        if (group.groupId == _selectedGroupId) {
          selectedGroup = group;
          break;
        }
      }
      if (selectedGroup != null && selectedGroup.bookSort >= 0) {
        sortIndex = selectedGroup.bookSort;
      }
      return sortIndex;
    }
    // style1 每个分组也支持独立排序配置（与 legado BooksFragment 对齐）。
    final selectedStyle1Group = _selectedStyle1GroupOrNull();
    if (selectedStyle1Group != null && selectedStyle1Group.bookSort >= 0) {
      sortIndex = selectedStyle1Group.bookSort;
    }
    return sortIndex;
  }

  List<Book> _displayBooks() {
    final source = List<Book>.from(_books);
    late final List<Book> grouped;
    if (_isStyle2Enabled) {
      grouped = _selectedGroupId == BookshelfBookGroup.idRoot
          ? source
          : _filterBooksByGroup(source, _selectedGroupId);
    } else {
      final selectedStyle1Group = _selectedStyle1GroupOrNull();
      grouped = selectedStyle1Group == null
          ? source
          : _filterBooksByGroup(source, selectedStyle1Group.groupId);
    }
    final sorted = List<Book>.from(grouped);
    _sortBookList(sorted, _resolveSortIndexForCurrentGroup());
    return sorted;
  }

  List<Object> _displayItems() {
    final books = _displayBooks();
    // style2 根态（IdRoot）展示“分组卡 + 书籍列表”；子分组只展示书籍。
    if (!_isStyle2Enabled || _selectedGroupId != BookshelfBookGroup.idRoot) {
      return books;
    }
    final groups = _visibleGroupsForRoot();
    return <Object>[...groups, ...books];
  }

  String _resolveGroupTitleById(int groupId) {
    for (final group in _bookGroups) {
      if (group.groupId == groupId) {
        return group.groupName;
      }
    }
    switch (groupId) {
      case BookshelfBookGroup.idAll:
        return '全部';
      case BookshelfBookGroup.idLocal:
        return '本地';
      case BookshelfBookGroup.idAudio:
        return '音频';
      case BookshelfBookGroup.idNetNone:
        return '网络未分组';
      case BookshelfBookGroup.idLocalNone:
        return '本地未分组';
      case BookshelfBookGroup.idError:
        return '更新失败';
      default:
        return '未分组';
    }
  }

  String _currentBookshelfTitle() {
    if (!_isStyle2Enabled || _selectedGroupId == BookshelfBookGroup.idRoot) {
      return '书架';
    }
    return '书架(${_resolveGroupTitleById(_selectedGroupId)})';
  }

  bool _tryHandleStyle2Back() {
    if (!_isStyle2Enabled) return false;
    if (_selectedGroupId == BookshelfBookGroup.idRoot) return false;
    debugPrint('[bookshelf] style2 back to root from group=$_selectedGroupId');
    setState(() => _selectedGroupId = BookshelfBookGroup.idRoot);
    return true;
  }

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
          _showMessage('已选择文件夹：${result.directoryPath}');
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
        _showMessage('已选择文件夹：${result.directoryPath}');
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
    await showCupertinoDialog<void>(
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

    return showCupertinoDialog<List<String>>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final rootPath = scanResult.rootDirectoryPath;
            final isAllSelected = candidates.isNotEmpty &&
                selectedPaths.length == candidates.length;
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
                              minimumSize: Size.zero,
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
                                                  ? CupertinoColors.activeBlue
                                                  : CupertinoColors.label
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
                                              color: CupertinoColors.systemGrey
                                                  .resolveFrom(context),
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
                                          ? CupertinoColors.activeBlue
                                          : CupertinoColors.systemGrey,
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
    await showCupertinoDialog<void>(
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

  Future<void> _openBookshelfManage() async {
    await Navigator.of(context, rootNavigator: true).push(
      CupertinoPageRoute<void>(
        builder: (_) => const BookshelfManagePlaceholderView(),
      ),
    );
    if (!mounted) return;
    await _reloadBookGroupContext(showError: true);
    _loadBooks();
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
    showCupertinoModalPopup<void>(
      context: context,
      barrierColor: CupertinoColors.black.withValues(alpha: 0.08),
      builder: (toastContext) {
        final navigator = Navigator.of(toastContext);
        unawaited(Future<void>.delayed(const Duration(milliseconds: 1100), () {
          if (navigator.mounted && navigator.canPop()) {
            navigator.pop();
          }
        }));
        return SafeArea(
          top: false,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              margin: const EdgeInsets.only(bottom: 28),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: CupertinoColors.systemBackground
                    .resolveFrom(context)
                    .withValues(alpha: 0.96),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: CupertinoColors.separator.resolveFrom(context),
                ),
              ),
              child: Text(
                message,
                style: TextStyle(
                  color: CupertinoColors.label.resolveFrom(context),
                  fontSize: 13,
                ),
              ),
            ),
          ),
        );
      },
    );
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
    if (_initError != null) return _buildInitErrorPage();

    final page = AppCupertinoPageScaffold(
      title: _currentBookshelfTitle(),
      useSliverNavigationBar: true,
      sliverScrollController: _scrollController,
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
            key: _moreMenuKey,
            padding: EdgeInsets.zero,
            minimumSize: const Size(30, 30),
            onPressed: _showMoreMenu,
            child: const Icon(CupertinoIcons.line_horizontal_3),
          ),
        ],
      ),
      child: const SizedBox.shrink(),
      sliverBodyBuilder: (_) => _buildBodySliver(),
    );
    return PopScope<void>(
      canPop:
          !_isStyle2Enabled || _selectedGroupId == BookshelfBookGroup.idRoot,
      // 与 legado style2 保持同义：处于子分组时先返回根分组，而不是直接退出主界面。
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _tryHandleStyle2Back();
      },
      child: _wrapWithFastScroller(page),
    );
  }

  Widget _buildInitErrorPage() {
    return AppCupertinoPageScaffold(
      title: '书架',
      useSliverNavigationBar: true,
      sliverScrollController: _scrollController,
      child: const SizedBox.shrink(),
      sliverBodyBuilder: (_) => SliverSafeArea(
        top: false,
        bottom: true,
        sliver: SliverFillRemaining(
          hasScrollBody: false,
          child: _buildInitError(),
        ),
      ),
    );
  }

  Widget _buildBodySliver() {
    if (_initError != null) {
      return SliverSafeArea(
        top: false,
        bottom: true,
        sliver: SliverFillRemaining(
          hasScrollBody: false,
          child: _buildInitError(),
        ),
      );
    }
    final displayItems = _displayItems();
    final contentSliver = displayItems.isEmpty
        ? SliverFillRemaining(
            hasScrollBody: false,
            child: _buildEmptyState(),
          )
        : _buildBookList(displayItems);
    if (_isStyle2Enabled) {
      return SliverSafeArea(
        top: false,
        bottom: true,
        sliver: contentSliver,
      );
    }
    return SliverSafeArea(
      top: false,
      bottom: true,
      sliver: SliverMainAxisGroup(
        slivers: [
          SliverToBoxAdapter(
            child: _buildStyle1GroupBar(),
          ),
          contentSliver,
        ],
      ),
    );
  }

  Widget _buildStyle1GroupBar() {
    final groups = _visibleGroupsForStyle1();
    if (groups.isEmpty) return const SizedBox.shrink();
    final selectedIndex = _resolveStyle1SelectedTabIndex(groups);
    final separatorColor = CupertinoColors.separator.resolveFrom(context);
    final activeColor = CupertinoTheme.of(context).primaryColor;
    final textColor = CupertinoColors.label.resolveFrom(context);
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: separatorColor, width: 0.5),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: SizedBox(
        height: 34,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: groups.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (context, index) {
            final group = groups[index];
            final selected = index == selectedIndex;
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _onStyle1GroupTap(index, group),
              onLongPress: () => _onStyle1GroupLongPress(group),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                curve: Curves.easeOut,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: selected
                      ? activeColor.withValues(alpha: 0.14)
                      : CupertinoColors.tertiarySystemGroupedBackground
                          .resolveFrom(context),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: selected
                        ? activeColor.withValues(alpha: 0.45)
                        : separatorColor.withValues(alpha: 0.8),
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  group.groupName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    color: selected ? activeColor : textColor,
                  ),
                ),
              ),
            );
          },
        ),
      ),
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
    final theme = CupertinoTheme.of(context);
    final secondaryLabel = CupertinoColors.secondaryLabel.resolveFrom(context);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            CupertinoIcons.book,
            size: 52,
            color: secondaryLabel,
          ),
          const SizedBox(height: 16),
          Text(
            '书架空空如也',
            style: theme.textTheme.navTitleTextStyle.copyWith(
              color: CupertinoColors.label.resolveFrom(context),
            ),
          ),
          const SizedBox(height: 24),
          CupertinoButton(
            color: theme.primaryColor,
            onPressed: _importLocalBook,
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  CupertinoIcons.doc,
                  size: 17,
                  color: CupertinoColors.white,
                ),
                SizedBox(width: 6),
                Text(
                  '导入本地书籍',
                  style: TextStyle(
                    color: CupertinoColors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookList(List<Object> displayItems) {
    if (_isGridView) {
      return _buildGridSliver(displayItems);
    } else {
      return _buildListSliver(displayItems);
    }
  }

  Widget _wrapWithFastScroller(Widget child) {
    if (_initError != null || _displayItems().isEmpty) return child;
    if (!_settingsService.appSettings.bookshelfShowFastScroller) {
      return child;
    }
    return CupertinoScrollbar(
      controller: _scrollController,
      thumbVisibility: true,
      child: child,
    );
  }

  Widget _buildGridSliver(List<Object> displayItems) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 16),
      sliver: SliverGrid(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: _gridCrossAxisCount,
          childAspectRatio: 0.56,
          crossAxisSpacing: 2,
          mainAxisSpacing: 6,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final item = displayItems[index];
            if (item is BookshelfBookGroup) {
              return _buildGroupGridCard(item);
            }
            if (item is Book) {
              return _buildBookCard(item);
            }
            return const SizedBox.shrink();
          },
          childCount: displayItems.length,
        ),
      ),
    );
  }

  Widget _buildGroupGridCard(BookshelfBookGroup group) {
    return GestureDetector(
      onTap: () => _onGroupTap(group),
      onLongPress: () => _onGroupLongPress(group),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: CupertinoColors.systemGrey5.resolveFrom(context),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: AppCoverImage(
                  urlOrPath: group.cover,
                  title: group.groupName,
                  author: '',
                  width: double.infinity,
                  height: double.infinity,
                  borderRadius: 8,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              group.groupName,
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                height: 1.25,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
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

  BoxDecoration _buildListCardDecoration() {
    return BoxDecoration(
      color:
          CupertinoColors.secondarySystemGroupedBackground.resolveFrom(context),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: CupertinoColors.separator
            .resolveFrom(context)
            .withValues(alpha: 0.35),
      ),
    );
  }

  TextStyle _buildListTitleStyle() {
    return CupertinoTheme.of(context).textTheme.textStyle.copyWith(
          color: CupertinoColors.label.resolveFrom(context),
          fontSize: 16,
          fontWeight: FontWeight.w600,
        );
  }

  TextStyle _buildListMetaStyle() {
    return CupertinoTheme.of(context).textTheme.textStyle.copyWith(
          color: CupertinoColors.secondaryLabel.resolveFrom(context),
          fontSize: 12,
        );
  }

  Widget _buildListSliver(List<Object> displayItems) {
    final theme = CupertinoTheme.of(context);
    final metaTextStyle = _buildListMetaStyle();
    final titleTextStyle = _buildListTitleStyle();
    final secondaryLabel = CupertinoColors.secondaryLabel.resolveFrom(context);
    final showLastUpdateTime =
        _settingsService.appSettings.bookshelfShowLastUpdateTime;
    final sliverItemCount =
        displayItems.isEmpty ? 0 : displayItems.length * 2 - 1;

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            if (index.isOdd) return const SizedBox(height: 8);
            final item = displayItems[index ~/ 2];
            if (item is BookshelfBookGroup) {
              return _buildGroupListTile(item);
            }
            if (item is! Book) return const SizedBox.shrink();
            final book = item;
            final readAgo = _formatReadAgo(book.lastReadTime);
            final isUpdating = _isUpdating(book);
            return GestureDetector(
              onTap: () => _openReader(book),
              onLongPress: () => _onBookLongPress(book),
              child: Container(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                decoration: _buildListCardDecoration(),
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
                                  style: titleTextStyle,
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
                                    color: theme.primaryColor
                                        .withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    book.progressText,
                                    style: metaTextStyle.copyWith(
                                      color: theme.primaryColor,
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
                                color: secondaryLabel,
                              ),
                              const SizedBox(width: 5),
                              Expanded(
                                child: Text(
                                  book.author.trim().isEmpty
                                      ? '未知作者'
                                      : book.author,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: metaTextStyle,
                                ),
                              ),
                              if (showLastUpdateTime && readAgo != null)
                                Text(
                                  readAgo,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: metaTextStyle,
                                ),
                            ],
                          ),
                          const SizedBox(height: 5),
                          Row(
                            children: [
                              Icon(
                                CupertinoIcons.clock,
                                size: 13,
                                color: secondaryLabel,
                              ),
                              const SizedBox(width: 5),
                              Expanded(
                                child: Text(
                                  _buildReadLine(book),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: metaTextStyle,
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
                                color: secondaryLabel,
                              ),
                              const SizedBox(width: 5),
                              Expanded(
                                child: Text(
                                  _buildLatestLine(book),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: metaTextStyle,
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
                              CupertinoIcons.chevron_forward,
                              size: 16,
                              color: secondaryLabel,
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
          childCount: sliverItemCount,
        ),
      ),
    );
  }

  Widget _buildGroupListTile(BookshelfBookGroup group) {
    final metaTextStyle = _buildListMetaStyle();
    final titleTextStyle = _buildListTitleStyle();
    final secondaryLabel = CupertinoColors.secondaryLabel.resolveFrom(context);

    return GestureDetector(
      onTap: () => _onGroupTap(group),
      onLongPress: () => _onGroupLongPress(group),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        decoration: _buildListCardDecoration(),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppCoverImage(
              urlOrPath: group.cover,
              title: group.groupName,
              author: '',
              width: 66,
              height: 90,
              borderRadius: 8,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    group.groupName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: titleTextStyle,
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '分组',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: metaTextStyle,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(
                CupertinoIcons.chevron_forward,
                size: 16,
                color: secondaryLabel,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onGroupTap(BookshelfBookGroup group) {
    if (!_isStyle2Enabled) return;
    if (_selectedGroupId == group.groupId) return;
    debugPrint(
      '[bookshelf] style2 enter group id=${group.groupId}, name=${group.groupName}',
    );
    setState(() => _selectedGroupId = group.groupId);
    _scrollToTop();
  }

  void _onGroupLongPress(BookshelfBookGroup _) {
    if (!_isStyle2Enabled) return;
    // 当前迁移阶段以“分组管理”作为分组编辑统一入口。
    _openBookshelfGroupManageDialog();
  }

  void _onStyle1GroupTap(int index, BookshelfBookGroup group) {
    final groups = _visibleGroupsForStyle1();
    final currentIndex = _resolveStyle1SelectedTabIndex(groups);
    if (index == currentIndex) {
      final count = _filterBooksByGroup(_books, group.groupId).length;
      debugPrint(
        '[bookshelf] style1 reselect group=${group.groupName} count=$count',
      );
      _showBottomHint('${group.groupName}($count)');
      return;
    }
    debugPrint(
      '[bookshelf] style1 select tab index=$index group=${group.groupName}',
    );
    setState(() => _style1SelectedTabIndex = index);
    _scrollToTop();
    unawaited(_persistStyle1SelectedTabIndex(index));
  }

  void _onStyle1GroupLongPress(BookshelfBookGroup group) {
    debugPrint(
      '[bookshelf] style1 long press group id=${group.groupId} name=${group.groupName}',
    );
    // 当前迁移阶段以“分组管理”作为分组编辑统一入口。
    _openBookshelfGroupManageDialog();
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
    showCupertinoBottomDialog<void>(
      context: context,
      barrierDismissible: true,
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
