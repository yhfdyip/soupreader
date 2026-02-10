import 'package:flutter/cupertino.dart';

import '../../../app/theme/design_tokens.dart';
import '../../../core/database/database_service.dart';
import '../../../core/database/repositories/source_repository.dart';
import '../../bookshelf/services/book_add_service.dart';
import '../../source/models/book_source.dart';
import '../../source/services/rule_parser_engine.dart';

/// 搜索页面 - 全局统一视觉风格
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

  List<SearchResult> _results = <SearchResult>[];
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
      _results = <SearchResult>[];
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
    final theme = CupertinoTheme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final borderColor =
        isDark ? AppDesignTokens.borderDark : AppDesignTokens.borderLight;
    final panelColor = isDark
        ? AppDesignTokens.surfaceDark.withValues(alpha: 0.82)
        : AppDesignTokens.surfaceLight.withValues(alpha: 0.94);

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('搜索'),
        backgroundColor: theme.barBackgroundColor,
        border: Border(bottom: BorderSide(color: borderColor, width: 0.5)),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              panelColor,
              theme.scaffoldBackgroundColor,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: panelColor,
                    borderRadius:
                        BorderRadius.circular(AppDesignTokens.radiusPopup),
                    border: Border.all(color: borderColor),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: CupertinoSearchTextField(
                          controller: _searchController,
                          placeholder: '输入书名或作者',
                          backgroundColor: CupertinoColors.transparent,
                          onSubmitted: (_) => _search(),
                        ),
                      ),
                      CupertinoButton(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        minimumSize: const Size(32, 32),
                        onPressed: _isSearching ? null : _search,
                        child: const Icon(CupertinoIcons.search),
                      ),
                    ],
                  ),
                ),
              ),
              if (_isSearching)
                _buildStatusPanel(
                  panelColor: panelColor,
                  borderColor: borderColor,
                  child: Row(
                    children: [
                      const CupertinoActivityIndicator(),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '正在搜索: $_searchingSource ($_completedSources/$totalSources)',
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark
                                ? AppDesignTokens.textMuted
                                : AppDesignTokens.textNormal,
                          ),
                        ),
                      ),
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: () => setState(() => _isSearching = false),
                        child: const Text('停止'),
                      ),
                    ],
                  ),
                )
              else if (_sourceIssues.isNotEmpty)
                _buildStatusPanel(
                  panelColor: panelColor,
                  borderColor: CupertinoColors.systemRed.resolveFrom(context),
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
                            color:
                                CupertinoColors.systemRed.resolveFrom(context),
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
                    ? _buildEmptyState(isDark)
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(12, 2, 12, 12),
                        itemCount: _results.length,
                        itemBuilder: (context, index) =>
                            _buildResultItem(_results[index], isDark),
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
      ),
    );
  }

  Widget _buildStatusPanel({
    required Color panelColor,
    required Color borderColor,
    required Widget child,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: panelColor,
          borderRadius: BorderRadius.circular(AppDesignTokens.radiusCard),
          border: Border.all(color: borderColor),
        ),
        child: child,
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    final secondary =
        isDark ? AppDesignTokens.textMuted : AppDesignTokens.textNormal;
    final tertiary =
        isDark ? AppDesignTokens.textMuted : AppDesignTokens.textMuted;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            CupertinoIcons.search,
            size: 64,
            color: secondary,
          ),
          const SizedBox(height: 16),
          Text(
            '搜索书籍',
            style: TextStyle(
              fontSize: 16,
              color: secondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _sourceIssues.isEmpty ? '输入书名或作者后回车' : '本次有失败书源，点上方“查看”了解原因',
            style: TextStyle(
              fontSize: 14,
              color: tertiary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultItem(SearchResult result, bool isDark) {
    final tileColor = isDark
        ? AppDesignTokens.surfaceDark.withValues(alpha: 0.78)
        : AppDesignTokens.surfaceLight;
    final borderColor =
        isDark ? AppDesignTokens.borderDark : AppDesignTokens.borderLight;
    final coverBg = isDark
        ? AppDesignTokens.pageBgDark
        : CupertinoColors.systemGrey6.resolveFrom(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: tileColor,
          borderRadius: BorderRadius.circular(AppDesignTokens.radiusCard),
          border: Border.all(color: borderColor),
        ),
        child: CupertinoListTile.notched(
          leading: Container(
            width: 40,
            height: 56,
            decoration: BoxDecoration(
              color: coverBg,
              borderRadius: BorderRadius.circular(8),
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
                      result.name.isNotEmpty
                          ? result.name.substring(0, 1)
                          : '?',
                      style: TextStyle(
                        color:
                            CupertinoColors.secondaryLabel.resolveFrom(context),
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
        ),
      ),
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
