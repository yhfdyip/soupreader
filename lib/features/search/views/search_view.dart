import 'package:flutter/cupertino.dart';
import '../../../core/database/database_service.dart';
import '../../../core/database/repositories/source_repository.dart';
import '../../bookshelf/services/book_add_service.dart';
import '../../source/models/book_source.dart';
import '../../source/services/rule_parser_engine.dart';

/// 搜索页面 - Cupertino 风格
class SearchView extends StatefulWidget {
  const SearchView({super.key});

  @override
  State<SearchView> createState() => _SearchViewState();
}

class _SearchViewState extends State<SearchView> {
  final TextEditingController _searchController = TextEditingController();
  final RuleParserEngine _engine = RuleParserEngine();
  late final SourceRepository _sourceRepo;
  late final BookAddService _addService;

  List<SearchResult> _results = [];
  final List<_SourceRunIssue> _sourceIssues = <_SourceRunIssue>[];
  bool _isSearching = false;
  bool _isImporting = false;
  String _searchingSource = '';
  int _completedSources = 0;

  @override
  void initState() {
    super.initState();
    final db = DatabaseService();
    _sourceRepo = SourceRepository(db);
    _addService = BookAddService(database: db, engine: _engine);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<BookSource> _enabledSources() {
    final enabled = _sourceRepo
        .getAllSources()
        .where((source) => source.enabled == true)
        .toList(growable: false);
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
      _results = [];
      _sourceIssues.clear();
      _completedSources = 0;
    });

    for (final source in enabledSources) {
      if (!_isSearching) break;

      setState(() {
        _searchingSource = source.bookSourceName;
      });

      try {
        final debugEngine = RuleParserEngine();
        final debugResult = await debugEngine.searchDebug(source, keyword);
        final issue = _buildSearchIssue(source, debugResult);
        final uniqueResults =
            _collectUniqueResults(debugResult.results, seenResultKeys);
        if (mounted) {
          setState(() {
            _results.addAll(uniqueResults);
            if (issue != null) {
              _sourceIssues.add(issue);
            }
            _completedSources++;
          });
        }
      } catch (e) {
        if (mounted) {
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
    }

    if (mounted) {
      setState(() {
        _isSearching = false;
        _searchingSource = '';
      });
    }
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
      final detail = _compactReason(debugResult.fetch.error ?? 'HTTP $statusCode');
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

  Future<void> _importBook(SearchResult result) async {
    if (_isImporting) return;

    setState(() => _isImporting = true);

    try {
      final addResult = await _addService.addFromSearchResult(result);
      _showMessage(addResult.message);
    } finally {
      if (mounted) {
        setState(() => _isImporting = false);
      }
    }
  }

  void _showMessage(String message) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('提示'),
        content: Text('\n$message'),
        actions: [
          CupertinoDialogAction(
            child: const Text('好'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalSources = _enabledSources().length;

    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('搜索'),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: CupertinoSearchTextField(
                controller: _searchController,
                placeholder: '输入书名或作者',
                onSubmitted: (_) => _search(),
              ),
            ),
            if (_isSearching)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    const CupertinoActivityIndicator(),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '正在搜索: $_searchingSource ($_completedSources/$totalSources)',
                        style: TextStyle(
                          fontSize: 13,
                          color: CupertinoColors.secondaryLabel
                              .resolveFrom(context),
                        ),
                      ),
                    ),
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      child: const Text('停止'),
                      onPressed: () => setState(() => _isSearching = false),
                    ),
                  ],
                ),
              )
            else if (_sourceIssues.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: Row(
                  children: [
                    Icon(
                      CupertinoIcons.exclamationmark_triangle,
                      size: 16,
                      color: CupertinoColors.systemRed.resolveFrom(context),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '本次 ${_sourceIssues.length} 个书源失败，可查看原因',
                        style: TextStyle(
                          fontSize: 12,
                          color: CupertinoColors.systemRed.resolveFrom(context),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: _showIssueDetails,
                      child: const Text('查看'),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: _results.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      itemCount: _results.length,
                      itemBuilder: (context, index) =>
                          _buildResultItem(_results[index]),
                    ),
            ),
            if (_isImporting)
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: CupertinoActivityIndicator(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            CupertinoIcons.search,
            size: 64,
            color: CupertinoColors.systemGrey,
          ),
          const SizedBox(height: 16),
          Text(
            '搜索书籍',
            style: TextStyle(
              fontSize: 16,
              color: CupertinoColors.secondaryLabel.resolveFrom(context),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _sourceIssues.isEmpty
                ? '输入书名或作者后回车'
                : '本次有失败书源，点上方“查看”了解原因',
            style: TextStyle(
              fontSize: 14,
              color: CupertinoColors.tertiaryLabel.resolveFrom(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultItem(SearchResult result) {
    return CupertinoListTile.notched(
      leading: Container(
        width: 40,
        height: 56,
        decoration: BoxDecoration(
          color: CupertinoColors.systemGrey5.resolveFrom(context),
          borderRadius: BorderRadius.circular(6),
          image: result.coverUrl.isNotEmpty
              ? DecorationImage(
                  image: NetworkImage(result.coverUrl),
                  fit: BoxFit.cover,
                )
              : null,
        ),
        child: result.coverUrl.isEmpty
            ? Center(
                child: Text(
                  result.name.isNotEmpty ? result.name.substring(0, 1) : '?',
                  style: TextStyle(
                    color: CupertinoColors.secondaryLabel.resolveFrom(context),
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              )
            : null,
      ),
      title: Text(
        result.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            result.author.isNotEmpty ? result.author : '未知作者',
            style: TextStyle(
              fontSize: 13,
              color: CupertinoColors.secondaryLabel.resolveFrom(context),
            ),
          ),
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
              style: TextStyle(
                fontSize: 12,
                color: CupertinoColors.tertiaryLabel.resolveFrom(context),
              ),
            ),
          ],
          if (result.lastChapter.trim().isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              '最新: ${result.lastChapter.trim()}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                color: CupertinoColors.tertiaryLabel.resolveFrom(context),
              ),
            ),
          ],
          const SizedBox(height: 2),
          Text(
            '来源: ${result.sourceName}',
            style: TextStyle(
              fontSize: 12,
              color: CupertinoColors.tertiaryLabel.resolveFrom(context),
            ),
          ),
        ],
      ),
      trailing: const CupertinoListTileChevron(),
      onTap: () => _importBook(result),
    );
  }
}

class _SourceRunIssue {
  final String sourceName;
  final String reason;

  const _SourceRunIssue({
    required this.sourceName,
    required this.reason,
  });
}
