import 'package:flutter/cupertino.dart';
import '../../../core/database/database_service.dart';
import '../../../core/database/repositories/source_repository.dart';
import '../../bookshelf/services/book_add_service.dart';
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

  Future<void> _search() async {
    final keyword = _searchController.text.trim();
    if (keyword.isEmpty) return;

    final sources = _sourceRepo.getAllSources();
    final enabledSources =
        sources.where((source) => source.enabled == true).toList();

    if (enabledSources.isEmpty) {
      _showMessage('没有启用的书源');
      return;
    }

    setState(() {
      _isSearching = true;
      _results = [];
      _completedSources = 0;
    });

    for (final source in enabledSources) {
      if (!_isSearching) break;

      setState(() {
        _searchingSource = source.bookSourceName;
      });

      try {
        final results = await _engine.search(source, keyword);
        if (mounted) {
          setState(() {
            _results.addAll(results);
            _completedSources++;
          });
        }
      } catch (_) {
        if (mounted) {
          setState(() => _completedSources++);
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
    final totalSources = _sourceRepo
        .getAllSources()
        .where((source) => source.enabled == true)
        .length;

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
            '输入书名或作者后回车',
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
