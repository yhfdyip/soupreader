import 'package:flutter/cupertino.dart';

import '../../../app/theme/ui_tokens.dart';
import '../../../app/widgets/app_cover_image.dart';
import '../../../app/widgets/app_cupertino_page_scaffold.dart';
import '../../../app/widgets/app_empty_state.dart';
import '../../../app/widgets/app_manage_search_field.dart';
import '../../../app/widgets/app_nav_bar_button.dart';
import '../../../app/widgets/app_popover_menu.dart';
import '../../../app/widgets/app_ui_kit.dart';
import '../../../app/widgets/cupertino_bottom_dialog.dart';
import '../../../core/database/database_service.dart';
import '../../../core/database/repositories/book_repository.dart';
import '../../../core/services/settings_service.dart';
import '../../reader/views/simple_reader_view.dart';
import '../../search/models/search_scope_group_helper.dart';
import '../models/book.dart';

enum _ReadRecordTopMenuAction {
  sort,
  toggleRecord,
}

/// 阅读记录
///
/// 对齐 legado `ReadRecordActivity`：
/// - `readRecordSort=0`：名称排序
/// - `readRecordSort=1`：阅读时长排序
/// - `readRecordSort=2`：阅读时间排序
class ReadingHistoryView extends StatefulWidget {
  const ReadingHistoryView({super.key});

  @override
  State<ReadingHistoryView> createState() => _ReadingHistoryViewState();
}

class _ReadingHistoryViewState extends State<ReadingHistoryView> {
  static const int _readRecordSortByName = 0;
  static const int _readRecordSortByReadLong = 1;
  static const int _readRecordSortByReadTime = 2;

  final GlobalKey _moreMenuKey = GlobalKey();
  late final BookRepository _bookRepo;
  late final SettingsService _settingsService;
  final TextEditingController _searchController = TextEditingController();
  bool _enableReadRecord = true;
  int _readRecordSort = _readRecordSortByName;
  String _searchQuery = '';
  bool _clearingAll = false;

  @override
  void initState() {
    super.initState();
    _bookRepo = BookRepository(DatabaseService());
    _settingsService = SettingsService();
    _enableReadRecord = _settingsService.enableReadRecord;
    _readRecordSort = _settingsService.getReadRecordSort(
      fallback: _readRecordSortByName,
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppCupertinoPageScaffold(
      title: '阅读记录',
      trailing: AppNavBarButton(
        key: _moreMenuKey,
        onPressed: _showTopActions,
        child: const Icon(CupertinoIcons.ellipsis_circle, size: 22),
      ),
      child: StreamBuilder<List<Book>>(
        stream: _bookRepo.watchAllBooks(),
        builder: (context, snapshot) {
          final books = snapshot.data ?? _bookRepo.getAllBooks();
          final readRecordDurationByBookId =
              _settingsService.getBookReadRecordDurationSnapshot();
          final history = List<Book>.from(
            books.where((b) => b.lastReadTime != null && b.isReading).toList(
                  growable: false,
                ),
          );
          _sortHistory(history, readRecordDurationByBookId);
          final filteredHistory = _applySearchFilter(history);
          final totalReadDurationMs =
              _settingsService.getTotalBookReadRecordDurationMs();
          final isSearching = _searchQuery.trim().isNotEmpty;

          return Column(
            children: [
              _buildSearchBox(
                visibleCount: filteredHistory.length,
                totalCount: history.length,
              ),
              _buildAllTimeHeader(
                allTimeMs: totalReadDurationMs,
                hasHistory: history.isNotEmpty,
                history: history,
              ),
              Expanded(
                child: filteredHistory.isEmpty
                    ? _buildEmptyState(isSearching: isSearching)
                    : _buildHistoryList(
                        filteredHistory,
                        readRecordDurationByBookId,
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSearchBox({
    required int visibleCount,
    required int totalCount,
  }) {
    final tokens = AppUiTokens.resolve(context);
    final theme = CupertinoTheme.of(context);
    final isSearching = _searchQuery.trim().isNotEmpty;
    final summary = isSearching ? '搜索结果（$visibleCount）' : '阅读记录（$totalCount）';

    return Padding(
      padding: AppManageSearchField.outerPadding,
      child: Column(
        children: [
          AppManageSearchField(
            controller: _searchController,
            placeholder: '搜索书名',
            onChanged: (value) {
              if (!mounted) return;
              setState(() => _searchQuery = value);
            },
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              summary,
              style: theme.textTheme.textStyle.copyWith(
                fontSize: 12,
                color: tokens.colors.secondaryLabel,
                letterSpacing: -0.2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAllTimeHeader({
    required int allTimeMs,
    required bool hasHistory,
    required List<Book> history,
  }) {
    final tokens = AppUiTokens.resolve(context);
    final theme = CupertinoTheme.of(context);
    final canClear = hasHistory && !_clearingAll;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: AppCard(
        padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
        borderColor: tokens.colors.separator.withValues(alpha: 0.74),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '总阅读时间',
                    style: theme.textTheme.textStyle.copyWith(
                      fontSize: 13,
                      color: tokens.colors.secondaryLabel,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _formatDuration(allTimeMs),
                    style: theme.textTheme.textStyle.copyWith(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: tokens.colors.label,
                      letterSpacing: -0.24,
                    ),
                  ),
                ],
              ),
            ),
            CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              onPressed: canClear ? () => _clearAllReadRecord(history) : null,
              minimumSize: const Size(44, 44),
              child: _clearingAll
                  ? const CupertinoActivityIndicator(radius: 9)
                  : const Text('清空'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryList(
    List<Book> books,
    Map<String, int> readRecordDurationByBookId,
  ) {
    final tokens = AppUiTokens.resolve(context);
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      itemCount: books.length,
      itemBuilder: (context, index) {
        final book = books[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onLongPress: () => _showActions(book),
            child: AppCard(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: GestureDetector(
                onTap: () => _openReader(book),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppCoverImage(
                      urlOrPath: book.coverUrl,
                      title: book.title,
                      author: book.author,
                      width: 48,
                      height: 67,
                      borderRadius: 6,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            book.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _subtitleForBook(book, readRecordDurationByBookId),
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.24,
                              color: tokens.colors.secondaryLabel,
                              letterSpacing: -0.16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState({required bool isSearching}) {
    return AppEmptyState(
      illustration: const AppEmptyPlanetIllustration(size: 88),
      title: isSearching ? '无匹配记录' : '暂无阅读记录',
      message: isSearching ? '请尝试更换搜索关键字' : '继续阅读一本书后，这里会自动记录历史',
    );
  }

  List<Book> _applySearchFilter(List<Book> books) {
    final key = _searchQuery.trim();
    if (key.isEmpty) return books;
    final lowerKey = key.toLowerCase();
    return books
        .where((book) => book.title.toLowerCase().contains(lowerKey))
        .toList(growable: false);
  }

  String _subtitleForBook(
    Book book,
    Map<String, int> readRecordDurationByBookId,
  ) {
    final lastRead = book.lastReadTime;
    final readDuration = readRecordDurationByBookId[book.id] ?? 0;
    final lastReadText = lastRead == null
        ? '—'
        : '${lastRead.year}-${_two(lastRead.month)}-${_two(lastRead.day)}';
    return '阅读时长 ${_formatDuration(readDuration)}\n最近阅读 $lastReadText';
  }

  String _two(int v) => v.toString().padLeft(2, '0');

  String _formatDuration(int milliseconds) {
    final safeMs = milliseconds < 0 ? 0 : milliseconds;
    final days = safeMs ~/ (1000 * 60 * 60 * 24);
    final hours = (safeMs % (1000 * 60 * 60 * 24)) ~/ (1000 * 60 * 60);
    final minutes = (safeMs % (1000 * 60 * 60)) ~/ (1000 * 60);
    final seconds = (safeMs % (1000 * 60)) ~/ 1000;
    final dayText = days > 0 ? '${days}天' : '';
    final hourText = hours > 0 ? '${hours}小时' : '';
    final minuteText = minutes > 0 ? '${minutes}分钟' : '';
    final secondText = seconds > 0 ? '${seconds}秒' : '';
    final text = '$dayText$hourText$minuteText$secondText';
    if (text.trim().isEmpty) {
      return '0秒';
    }
    return text;
  }

  void _sortHistory(
    List<Book> books,
    Map<String, int> readRecordDurationByBookId,
  ) {
    if (_readRecordSort == _readRecordSortByReadLong) {
      books.sort((left, right) {
        final leftDuration = readRecordDurationByBookId[left.id] ?? 0;
        final rightDuration = readRecordDurationByBookId[right.id] ?? 0;
        final byDuration = rightDuration.compareTo(leftDuration);
        if (byDuration != 0) return byDuration;
        return _compareByReadTimeDescThenTitle(left, right);
      });
      return;
    }
    if (_readRecordSort == _readRecordSortByReadTime) {
      books.sort(_compareByReadTimeDescThenTitle);
      return;
    }
    books.sort(_compareByNameLikeLegado);
  }

  int _compareByReadTimeDescThenTitle(Book left, Book right) {
    final leftTime =
        left.lastReadTime ?? DateTime.fromMillisecondsSinceEpoch(0);
    final rightTime =
        right.lastReadTime ?? DateTime.fromMillisecondsSinceEpoch(0);
    final byReadTime = rightTime.compareTo(leftTime);
    if (byReadTime != 0) return byReadTime;
    return _compareByNameLikeLegado(left, right);
  }

  int _compareByNameLikeLegado(Book left, Book right) {
    return SearchScopeGroupHelper.cnCompareLikeLegado(left.title, right.title);
  }

  Future<void> _showTopActions() async {
    if (!mounted) return;
    final selected = await showAppPopoverMenu<_ReadRecordTopMenuAction>(
      context: context,
      anchorKey: _moreMenuKey,
      items: [
        const AppPopoverMenuItem(
          value: _ReadRecordTopMenuAction.sort,
          icon: CupertinoIcons.arrow_up_arrow_down,
          label: '排序',
        ),
        AppPopoverMenuItem(
          value: _ReadRecordTopMenuAction.toggleRecord,
          icon: CupertinoIcons.check_mark,
          label: '${_enableReadRecord ? '✓ ' : ''}开启记录',
        ),
      ],
    );
    if (!mounted || selected == null) return;
    switch (selected) {
      case _ReadRecordTopMenuAction.sort:
        await _showSortActions();
        break;
      case _ReadRecordTopMenuAction.toggleRecord:
        final nextValue = !_enableReadRecord;
        await _settingsService.saveEnableReadRecord(nextValue);
        if (!mounted) return;
        setState(() => _enableReadRecord = nextValue);
        break;
    }
  }

  Future<void> _showSortActions() async {
    if (!mounted) return;
    final selected = await showAppPopoverMenu<int>(
      context: context,
      anchorKey: _moreMenuKey,
      items: [
        AppPopoverMenuItem(
          value: _readRecordSortByName,
          icon: CupertinoIcons.textformat,
          label: '${_readRecordSort == _readRecordSortByName ? '✓ ' : ''}名称排序',
        ),
        AppPopoverMenuItem(
          value: _readRecordSortByReadLong,
          icon: CupertinoIcons.time,
          label:
              '${_readRecordSort == _readRecordSortByReadLong ? '✓ ' : ''}阅读时长排序',
        ),
        AppPopoverMenuItem(
          value: _readRecordSortByReadTime,
          icon: CupertinoIcons.clock,
          label:
              '${_readRecordSort == _readRecordSortByReadTime ? '✓ ' : ''}阅读时间排序',
        ),
      ],
    );
    if (!mounted || selected == null) return;

    await _settingsService.saveReadRecordSort(selected);
    if (!mounted) return;
    setState(() => _readRecordSort = selected);
  }

  void _openReader(Book book) {
    Navigator.of(context, rootNavigator: true).push(
      CupertinoPageRoute(
        builder: (context) => SimpleReaderView(
          bookId: book.id,
          bookTitle: book.title,
          initialChapter: book.currentChapter,
        ),
      ),
    );
  }

  Future<bool> _showDeleteConfirm({
    required String message,
  }) async {
    final confirmed = await showCupertinoBottomSheetDialog<bool>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: const Text('删除'),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('删除'),
          ),
          CupertinoDialogAction(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  Future<void> _clearSingleReadRecord(Book book) async {
    final confirmed = await _showDeleteConfirm(
      message: '是否确认删除 ${book.title}？',
    );
    if (!confirmed) return;
    await _bookRepo.clearReadingRecord(book.id);
    await _settingsService.clearBookReadRecordDuration(book.id);
  }

  Future<void> _clearAllReadRecord(List<Book> history) async {
    if (_clearingAll) return;
    final confirmed = await _showDeleteConfirm(message: '是否确认删除？');
    if (!confirmed) return;
    if (!mounted) return;
    setState(() => _clearingAll = true);
    try {
      for (final book in history) {
        await _bookRepo.clearReadingRecord(book.id);
      }
      await _settingsService.clearAllBookReadRecordDuration();
    } finally {
      if (mounted) {
        setState(() => _clearingAll = false);
      }
    }
  }

  void _showActions(Book book) {
    showCupertinoBottomSheetDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (context) => CupertinoActionSheet(
        title: Text(book.title),
        actions: [
          CupertinoActionSheetAction(
            child: const Text('继续阅读'),
            onPressed: () {
              Navigator.pop(context);
              _openReader(book);
            },
          ),
          CupertinoActionSheetAction(
            child: const Text('清除阅读记录'),
            onPressed: () async {
              Navigator.pop(context);
              await _clearSingleReadRecord(book);
            },
          ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            child: const Text('从书架移除'),
            onPressed: () async {
              Navigator.pop(context);
              await _settingsService.clearBookReadRecordDuration(book.id);
              await _bookRepo.deleteBook(book.id);
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
}
