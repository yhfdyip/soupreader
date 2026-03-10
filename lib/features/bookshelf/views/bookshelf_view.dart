import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

import '../../../app/theme/design_tokens.dart';
import '../../../app/theme/ui_tokens.dart';
import '../../../app/widgets/app_cupertino_page_scaffold.dart';
import '../../../app/widgets/app_cover_image.dart';
import '../../../app/widgets/app_empty_state.dart';
import '../../../app/widgets/app_nav_bar_button.dart';
import '../../../app/widgets/app_popover_menu.dart';
import '../../../app/widgets/app_sheet_header.dart';
import '../../../app/widgets/app_ui_kit.dart';
import '../../../app/widgets/app_toast.dart';
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
import 'remote_books_servers_view.dart';
import '../services/book_add_service.dart';
import '../services/bookshelf_book_group_store.dart';
import '../services/bookshelf_booklist_import_service.dart';
import '../services/bookshelf_catalog_update_service.dart';
import '../services/bookshelf_import_export_service.dart';
import '../models/book.dart';
import '../models/bookshelf_book_group.dart';

part 'bookshelf_view_import.dart';
part 'bookshelf_view_manage.dart';
part 'bookshelf_view_build.dart';


enum _ImportFolderAction {
  select,
  create,
}

enum _BookshelfMoreMenuAction {
  updateCatalog,
  importLocal,
  remoteBook,
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
      if (_selectedGroupId == BookshelfBookGroup.idRoot) {
        // 与 legado flowRoot() 对齐：根态只展示未归入任何自定义分组的网络书。
        // 若「网络未分组」分组本身已显示（show=true），根态不再重复展示这些书。
        final netNoneGroup = _bookGroups.where(
          (g) => g.groupId == BookshelfBookGroup.idNetNone,
        ).firstOrNull;
        final netNoneShown = netNoneGroup?.show ?? false;
        if (netNoneShown) {
          grouped = const <Book>[];
        } else {
          grouped = _filterBooksByGroup(source, BookshelfBookGroup.idNetNone);
        }
      } else {
        grouped = _filterBooksByGroup(source, _selectedGroupId);
      }
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
          AppNavBarButton(
            onPressed: _openGlobalSearch,
            child: const Icon(CupertinoIcons.search, size: 22),
          ),
          AppNavBarButton(
            key: _moreMenuKey,
            onPressed: _showMoreMenu,
            child: const Icon(CupertinoIcons.line_horizontal_3, size: 22),
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


}
