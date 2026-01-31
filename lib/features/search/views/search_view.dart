import 'package:flutter/cupertino.dart';
import '../models/book_source.dart';
import '../services/rule_parser_engine.dart';

/// 搜索页面 - Cupertino 风格
class SearchView extends StatefulWidget {
  final List<BookSource> sources;

  const SearchView({super.key, required this.sources});

  @override
  State<SearchView> createState() => _SearchViewState();
}

class _SearchViewState extends State<SearchView> {
  final TextEditingController _searchController = TextEditingController();
  final RuleParserEngine _engine = RuleParserEngine();

  List<SearchResult> _results = [];
  bool _isSearching = false;
  String _searchingSource = '';
  int _completedSources = 0;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final keyword = _searchController.text.trim();
    if (keyword.isEmpty) return;

    final enabledSources = widget.sources.where((s) => s.enabled).toList();
    if (enabledSources.isEmpty) {
      _showMessage('没有启用的书源');
      return;
    }

    setState(() {
      _isSearching = true;
      _results = [];
      _completedSources = 0;
    });

    // 并发搜索所有书源
    for (final source in enabledSources) {
      if (!_isSearching) break; // 支持取消

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
      } catch (e) {
        print('搜索 ${source.bookSourceName} 失败: $e');
      }
    }

    if (mounted) {
      setState(() {
        _isSearching = false;
        _searchingSource = '';
      });
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

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('搜索'),
        previousPageTitle: '返回',
      ),
      child: SafeArea(
        child: Column(
          children: [
            // 搜索框
            Padding(
              padding: const EdgeInsets.all(16),
              child: CupertinoSearchTextField(
                controller: _searchController,
                placeholder: '输入书名或作者',
                onSubmitted: (_) => _search(),
              ),
            ),

            // 搜索进度
            if (_isSearching)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    const CupertinoActivityIndicator(),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '正在搜索: $_searchingSource ($_completedSources/${widget.sources.where((s) => s.enabled).length})',
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

            // 搜索结果
            Expanded(
              child: _results.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      itemCount: _results.length,
                      itemBuilder: (context, index) =>
                          _buildResultItem(_results[index]),
                    ),
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
            color: CupertinoColors.secondaryLabel.resolveFrom(context),
          ),
          const SizedBox(height: 16),
          Text(
            _isSearching ? '正在搜索...' : '输入关键词搜索书籍',
            style: TextStyle(
              fontSize: 17,
              color: CupertinoColors.secondaryLabel.resolveFrom(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultItem(SearchResult result) {
    return CupertinoListTile(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      leadingSize: 50,
      leading: Container(
        width: 50,
        height: 70,
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
      onTap: () => _onResultTap(result),
    );
  }

  void _onResultTap(SearchResult result) {
    // TODO: 跳转到书籍详情页面
    _showMessage(
        '${result.name}\n作者: ${result.author}\n来源: ${result.sourceName}');
  }
}
