import 'package:flutter/cupertino.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../app/widgets/app_cover_image.dart';
import '../../../app/widgets/app_cupertino_page_scaffold.dart';
import '../../../core/database/database_service.dart';
import '../../bookshelf/services/book_add_service.dart';
import '../../source/models/book_source.dart';
import '../../source/services/rule_parser_engine.dart';
import '../../search/views/search_book_info_view.dart';

/// 发现二级页：单书源 + 单发现入口结果（对标 legado ExploreShowActivity）
class DiscoveryExploreResultsView extends StatefulWidget {
  final BookSource source;
  final String exploreName;
  final String exploreUrl;

  const DiscoveryExploreResultsView({
    super.key,
    required this.source,
    required this.exploreName,
    required this.exploreUrl,
  });

  @override
  State<DiscoveryExploreResultsView> createState() =>
      _DiscoveryExploreResultsViewState();
}

class _DiscoveryExploreResultsViewState
    extends State<DiscoveryExploreResultsView> {
  late final RuleParserEngine _engine;
  late final BookAddService _addService;
  final ScrollController _scrollController = ScrollController();

  final List<SearchResult> _results = <SearchResult>[];
  final Set<String> _seenKeys = <String>{};

  bool _loading = false;
  bool _hasMore = true;
  int _page = 1;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final db = DatabaseService();
    _engine = RuleParserEngine();
    _addService = BookAddService(database: db);
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadMore());
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.maxScrollExtent <= 0) return;
    if (position.pixels >= position.maxScrollExtent - 220) {
      _loadMore();
    }
  }

  Future<void> _loadMore({bool forceRefresh = false}) async {
    if (_loading) return;
    if (!forceRefresh && !_hasMore) return;

    if (forceRefresh) {
      setState(() {
        _loading = true;
        _errorMessage = null;
        _results.clear();
        _seenKeys.clear();
        _hasMore = true;
        _page = 1;
      });
    } else {
      setState(() {
        _loading = true;
        _errorMessage = null;
      });
    }

    try {
      final fetched = await _engine.explore(
        widget.source,
        exploreUrlOverride: widget.exploreUrl,
        page: _page,
      );

      if (!mounted) return;

      var added = 0;
      for (final item in fetched) {
        final bookUrl = item.bookUrl.trim();
        if (bookUrl.isEmpty) continue;
        final key = '${item.sourceUrl.trim()}|$bookUrl';
        if (!_seenKeys.add(key)) continue;
        _results.add(item);
        added++;
      }

      setState(() {
        _loading = false;
        if (fetched.isEmpty || added == 0) {
          _hasMore = false;
        } else {
          _page++;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorMessage = _compactReason(e.toString());
      });
    }
  }

  String _compactReason(String text, {int maxLength = 96}) {
    final normalized = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.length <= maxLength) return normalized;
    return '${normalized.substring(0, maxLength)}…';
  }

  Future<void> _openBookInfo(SearchResult result) async {
    await Navigator.of(context, rootNavigator: true).push(
      CupertinoPageRoute<void>(
        builder: (_) => SearchBookInfoView(result: result),
      ),
    );
    if (!mounted) return;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final scheme = theme.colorScheme;

    return AppCupertinoPageScaffold(
      title: widget.exploreName,
      trailing: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: _loading ? null : () => _loadMore(forceRefresh: true),
        child: const Icon(CupertinoIcons.refresh),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.source.bookSourceName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.small.copyWith(
                      color: scheme.mutedForeground,
                    ),
                  ),
                ),
                Text(
                  '已加载 ${_results.length}',
                  style: theme.textTheme.small.copyWith(
                    color: scheme.mutedForeground,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _buildBody(context),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final theme = ShadTheme.of(context);
    final scheme = theme.colorScheme;

    if (_results.isEmpty) {
      if (_loading) {
        return const Center(child: CupertinoActivityIndicator());
      }
      if (_errorMessage != null) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  LucideIcons.triangleAlert,
                  size: 42,
                  color: scheme.destructive,
                ),
                const SizedBox(height: 10),
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.small.copyWith(
                    color: scheme.destructive,
                  ),
                ),
                const SizedBox(height: 12),
                ShadButton(
                  onPressed: () => _loadMore(forceRefresh: true),
                  child: const Text('重试'),
                ),
              ],
            ),
          ),
        );
      }
      return Center(
        child: Text(
          '暂无发现内容',
          style: theme.textTheme.muted.copyWith(
            color: scheme.mutedForeground,
          ),
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      itemCount: _results.length + 1,
      itemBuilder: (context, index) {
        if (index == _results.length) {
          return _buildFooter(context);
        }
        return _buildResultItem(_results[index]);
      },
    );
  }

  Widget _buildResultItem(SearchResult result) {
    final theme = ShadTheme.of(context);
    final scheme = theme.colorScheme;
    final inBookshelf = _addService.isInBookshelf(result);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: () => _openBookInfo(result),
        child: ShadCard(
          padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
          leading: AppCoverImage(
            urlOrPath: result.coverUrl,
            title: result.name,
            author: result.author,
            width: 40,
            height: 56,
            borderRadius: 6,
            fit: BoxFit.cover,
            showTextOnPlaceholder: false,
          ),
          trailing: Icon(
            inBookshelf ? LucideIcons.bookCheck : LucideIcons.chevronRight,
            size: inBookshelf ? 17 : 16,
            color: inBookshelf ? scheme.primary : scheme.mutedForeground,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                result.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.p.copyWith(
                  fontWeight: FontWeight.w600,
                  color: scheme.foreground,
                ),
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    final theme = ShadTheme.of(context);
    final scheme = theme.colorScheme;

    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 14),
        child: Center(child: CupertinoActivityIndicator()),
      );
    }

    if (_errorMessage != null) {
      return Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 12),
        child: Column(
          children: [
            Text(
              '加载失败：$_errorMessage',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: theme.textTheme.small.copyWith(
                color: scheme.destructive,
              ),
            ),
            const SizedBox(height: 8),
            ShadButton.outline(
              onPressed: _loadMore,
              child: const Text('重试加载'),
            ),
          ],
        ),
      );
    }

    if (!_hasMore) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Center(
          child: Text(
            '没有更多了',
            style: theme.textTheme.small.copyWith(
              color: scheme.mutedForeground,
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: Text(
          '上拉继续加载',
          style: theme.textTheme.small.copyWith(
            color: scheme.mutedForeground,
          ),
        ),
      ),
    );
  }
}
