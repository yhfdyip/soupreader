import 'package:flutter/cupertino.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../app/widgets/app_cupertino_page_scaffold.dart';
import '../../../core/database/database_service.dart';
import '../../../core/database/repositories/source_repository.dart';
import '../../bookshelf/services/book_add_service.dart';
import '../../source/models/book_source.dart';
import '../../source/services/rule_parser_engine.dart';
import 'search_book_info_view.dart';

/// 搜索页面 - 全局统一视觉风格
class SearchView extends StatefulWidget {
  final List<String>? sourceUrls;
  final String? initialKeyword;
  final bool autoSearchOnOpen;

  const SearchView({super.key})
      : sourceUrls = null,
        initialKeyword = null,
        autoSearchOnOpen = false;
  const SearchView.scoped({
    super.key,
    required this.sourceUrls,
    this.initialKeyword,
    this.autoSearchOnOpen = false,
  });

  @override
  State<SearchView> createState() => _SearchViewState();
}

class _SearchViewState extends State<SearchView> {
  final TextEditingController _searchController = TextEditingController();
  late final SourceRepository _sourceRepo;
  late final BookAddService _addService;

  List<SearchResult> _results = <SearchResult>[];
  List<_SearchDisplayItem> _displayResults = <_SearchDisplayItem>[];
  final List<_SourceRunIssue> _sourceIssues = <_SourceRunIssue>[];
  bool _isSearching = false;
  String _searchingSource = '';
  int _completedSources = 0;

  @override
  void initState() {
    super.initState();
    final db = DatabaseService();
    _sourceRepo = SourceRepository(db);
    _addService = BookAddService(database: db);
    final initialKeyword = widget.initialKeyword?.trim();
    if (initialKeyword != null && initialKeyword.isNotEmpty) {
      _searchController.text = initialKeyword;
      _searchController.selection = TextSelection.fromPosition(
        TextPosition(offset: initialKeyword.length),
      );
    }
    if (widget.autoSearchOnOpen == true && initialKeyword != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _search();
        }
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<BookSource> _enabledSources() {
    final scopedUrls = widget.sourceUrls
        ?.map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet();

    final enabled = _sourceRepo
        .getAllSources()
        .where((source) => source.enabled == true)
        .where((source) {
      if (scopedUrls == null || scopedUrls.isEmpty) return true;
      return scopedUrls.contains(source.bookSourceUrl);
    }).toList(growable: false);
    enabled.sort((a, b) {
      if (a.weight != b.weight) {
        return b.weight.compareTo(a.weight);
      }
      return a.bookSourceName.compareTo(b.bookSourceName);
    });
    return enabled;
  }

  List<SearchResult> _collectUniqueResults(
    List<SearchResult> incoming,
    Set<String> seenKeys,
  ) {
    final unique = <SearchResult>[];
    for (final item in incoming) {
      final bookUrl = item.bookUrl.trim();
      if (bookUrl.isEmpty) continue;
      final key = '${item.sourceUrl.trim()}|$bookUrl';
      if (!seenKeys.add(key)) continue;
      unique.add(item);
    }
    return unique;
  }

  String _normalizeCompare(String text) {
    return text.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '');
  }

  void _rebuildDisplayResults() {
    final grouped = <String, List<SearchResult>>{};
    for (final item in _results) {
      final key =
          '${_normalizeCompare(item.name)}|${_normalizeCompare(item.author)}';
      grouped.putIfAbsent(key, () => <SearchResult>[]).add(item);
    }
    final built = <_SearchDisplayItem>[];
    for (final entry in grouped.entries) {
      final origins = entry.value;
      if (origins.isEmpty) continue;
      final primary = origins.first;
      final inBookshelf = origins.any(_addService.isInBookshelf);
      built.add(
        _SearchDisplayItem(
          primary: primary,
          origins: origins,
          inBookshelf: inBookshelf,
        ),
      );
    }
    _displayResults = built;
  }

  Future<void> _search() async {
    final keyword = _searchController.text.trim();
    if (keyword.isEmpty) return;

    final enabledSources = _enabledSources();
    if (enabledSources.isEmpty) {
      _showMessage('没有启用的书源');
      return;
    }

    final seenResultKeys = <String>{};

    setState(() {
      _isSearching = true;
      _results = <SearchResult>[];
      _displayResults = <_SearchDisplayItem>[];
      _sourceIssues.clear();
      _completedSources = 0;
    });

    for (final source in enabledSources) {
      if (!_isSearching) break;

      setState(() => _searchingSource = source.bookSourceName);

      try {
        final debugEngine = RuleParserEngine();
        final debugResult = await debugEngine.searchDebug(source, keyword);
        final issue = _buildSearchIssue(source, debugResult);
        final uniqueResults =
            _collectUniqueResults(debugResult.results, seenResultKeys);
        if (!mounted) return;
        setState(() {
          _results.addAll(uniqueResults);
          _rebuildDisplayResults();
          if (issue != null) {
            _sourceIssues.add(issue);
          }
          _completedSources++;
        });
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _completedSources++;
          _sourceIssues.add(
            _SourceRunIssue(
              sourceName: source.bookSourceName,
              reason: '搜索异常：${_compactReason(e.toString())}',
            ),
          );
        });
      }
    }

    if (!mounted) return;
    setState(() {
      _isSearching = false;
      _searchingSource = '';
    });
  }

  _SourceRunIssue? _buildSearchIssue(
    BookSource source,
    SearchDebugResult debugResult,
  ) {
    final explicitError = (debugResult.error ?? '').trim();
    if (explicitError.isNotEmpty) {
      return _SourceRunIssue(
        sourceName: source.bookSourceName,
        reason: _compactReason(explicitError),
      );
    }

    final statusCode = debugResult.fetch.statusCode;
    if (statusCode != null && statusCode >= 400) {
      final detail =
          _compactReason(debugResult.fetch.error ?? 'HTTP $statusCode');
      return _SourceRunIssue(
        sourceName: source.bookSourceName,
        reason: '请求失败（HTTP $statusCode）：$detail',
      );
    }

    if (debugResult.fetch.body != null &&
        debugResult.listCount > 0 &&
        debugResult.results.isEmpty) {
      return _SourceRunIssue(
        sourceName: source.bookSourceName,
        reason: '解析到列表 ${debugResult.listCount} 项，但缺少 name/bookUrl',
      );
    }

    return null;
  }

  String _compactReason(String text, {int maxLength = 96}) {
    final normalized = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.length <= maxLength) {
      return normalized;
    }
    return '${normalized.substring(0, maxLength)}…';
  }

  void _showIssueDetails() {
    if (_sourceIssues.isEmpty) return;
    final lines = <String>['失败书源：${_sourceIssues.length} 条'];
    final preview = _sourceIssues.take(12).toList(growable: false);
    for (final issue in preview) {
      lines.add('• ${issue.sourceName}：${issue.reason}');
    }
    final remain = _sourceIssues.length - preview.length;
    if (remain > 0) {
      lines.add('…其余 $remain 条省略');
    }
    lines.add('可在“书源可用性检测”或“调试”继续定位。');
    _showMessage(lines.join('\n'));
  }

  Future<void> _openBookInfo(SearchResult result) async {
    await Navigator.of(context, rootNavigator: true).push(
      CupertinoPageRoute(
        builder: (_) => SearchBookInfoView(result: result),
      ),
    );
    if (!mounted) return;
    setState(_rebuildDisplayResults);
  }

  void _showMessage(String message) {
    showShadDialog<void>(
      context: context,
      builder: (dialogContext) => ShadDialog.alert(
        title: const Text('提示'),
        description: Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(message),
        ),
        actions: [
          ShadButton(
            child: const Text('好'),
            onPressed: () => Navigator.of(dialogContext).pop(),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalSources = _enabledSources().length;
    final theme = ShadTheme.of(context);
    final scheme = theme.colorScheme;

    return AppCupertinoPageScaffold(
      title: '搜索',
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: ShadInput(
                        controller: _searchController,
                        placeholder: const Text('输入书名或作者'),
                        textInputAction: TextInputAction.search,
                        leading: const Padding(
                          padding: EdgeInsets.all(4),
                          child: Icon(LucideIcons.search, size: 16),
                        ),
                        onSubmitted: (_) => _search(),
                      ),
                    ),
                    const SizedBox(width: 10),
                    ShadButton(
                      onPressed: _isSearching ? null : _search,
                      leading: _isSearching
                          ? const SizedBox.square(
                              dimension: 16,
                              child: CupertinoActivityIndicator(radius: 8),
                            )
                          : const Icon(LucideIcons.search),
                      child: const Text('搜索'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      '书源 $totalSources',
                      style: theme.textTheme.small.copyWith(
                        color: scheme.mutedForeground,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '结果 ${_displayResults.length}',
                      style: theme.textTheme.small.copyWith(
                        color: scheme.mutedForeground,
                      ),
                    ),
                    if (_sourceIssues.isNotEmpty) ...[
                      const SizedBox(width: 10),
                      Text(
                        '失败 ${_sourceIssues.length}',
                        style: theme.textTheme.small.copyWith(
                          color: scheme.destructive,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (_isSearching)
            _buildStatusPanel(
              borderColor: scheme.border,
              child: Row(
                children: [
                  const CupertinoActivityIndicator(),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '正在搜索: $_searchingSource ($_completedSources/$totalSources)',
                      style: TextStyle(
                        fontSize: 13,
                        color: scheme.mutedForeground,
                      ),
                    ),
                  ),
                  ShadButton.link(
                    onPressed: () => setState(() => _isSearching = false),
                    child: const Text('停止'),
                  ),
                ],
              ),
            )
          else if (_sourceIssues.isNotEmpty)
            _buildStatusPanel(
              borderColor: scheme.destructive,
              child: Row(
                children: [
                  Icon(LucideIcons.triangleAlert,
                      size: 16, color: scheme.destructive),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '本次 ${_sourceIssues.length} 个书源失败，可查看原因',
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.destructive,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  ShadButton.link(
                    onPressed: _showIssueDetails,
                    child: const Text('查看'),
                  ),
                ],
              ),
            ),
          Expanded(
            child: _displayResults.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 2, 12, 12),
                    itemCount: _displayResults.length,
                    itemBuilder: (context, index) =>
                        _buildResultItem(_displayResults[index]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusPanel({
    required Color borderColor,
    required Widget child,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: ShadCard(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: ShadBorder.all(color: borderColor, width: 1),
        child: child,
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
            LucideIcons.search,
            size: 52,
            color: scheme.mutedForeground,
          ),
          const SizedBox(height: 16),
          Text(
            '搜索书籍',
            style: theme.textTheme.h4,
          ),
          const SizedBox(height: 8),
          Text(
            _sourceIssues.isEmpty ? '输入书名或作者后回车' : '本次有失败书源，点上方“查看”了解原因',
            style: theme.textTheme.muted.copyWith(
              color: scheme.mutedForeground,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultItem(_SearchDisplayItem item) {
    final theme = ShadTheme.of(context);
    final scheme = theme.colorScheme;
    final result = item.primary;
    final sourceCount = item.origins.length;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: () => _openBookInfo(result),
        child: ShadCard(
          padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
          trailing: Icon(
            item.inBookshelf ? LucideIcons.bookCheck : LucideIcons.chevronRight,
            size: item.inBookshelf ? 17 : 16,
            color: item.inBookshelf ? scheme.primary : scheme.mutedForeground,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      result.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.p.copyWith(
                        fontWeight: FontWeight.w600,
                        color: scheme.foreground,
                      ),
                    ),
                  ),
                  if (sourceCount > 1)
                    Container(
                      margin: const EdgeInsets.only(left: 6),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: scheme.primary.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '$sourceCount源',
                        style: theme.textTheme.small.copyWith(
                          color: scheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                result.author.isNotEmpty ? result.author : '未知作者',
                style: theme.textTheme.small.copyWith(
                  color: scheme.mutedForeground,
                ),
              ),
              if (result.intro.trim().isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  result.intro.trim(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.small.copyWith(
                    color: scheme.mutedForeground,
                  ),
                ),
              ],
              if ([
                if (result.kind.trim().isNotEmpty) result.kind.trim(),
                if (result.wordCount.trim().isNotEmpty)
                  '字数:${result.wordCount.trim()}',
                if (result.updateTime.trim().isNotEmpty)
                  '更新:${result.updateTime.trim()}',
              ].isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  [
                    if (result.kind.trim().isNotEmpty) result.kind.trim(),
                    if (result.wordCount.trim().isNotEmpty)
                      '字数:${result.wordCount.trim()}',
                    if (result.updateTime.trim().isNotEmpty)
                      '更新:${result.updateTime.trim()}',
                  ].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.small.copyWith(
                    color: scheme.mutedForeground,
                  ),
                ),
              ],
              if (result.lastChapter.trim().isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  '最新: ${result.lastChapter.trim()}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.small.copyWith(
                    color: scheme.mutedForeground,
                  ),
                ),
              ],
              const SizedBox(height: 2),
              Text(
                sourceCount > 1
                    ? '来源: ${result.sourceName} 等 $sourceCount 个'
                    : '来源: ${result.sourceName}',
                style: theme.textTheme.small.copyWith(
                  color: scheme.mutedForeground,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchDisplayItem {
  final SearchResult primary;
  final List<SearchResult> origins;
  final bool inBookshelf;

  const _SearchDisplayItem({
    required this.primary,
    required this.origins,
    required this.inBookshelf,
  });
}

class _SourceRunIssue {
  final String sourceName;
  final String reason;

  const _SourceRunIssue({
    required this.sourceName,
    required this.reason,
  });
}
