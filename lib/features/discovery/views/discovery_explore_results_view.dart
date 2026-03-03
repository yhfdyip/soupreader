import 'dart:async';

import 'package:flutter/cupertino.dart';

import '../../../app/theme/source_ui_tokens.dart';
import '../../../app/widgets/app_cover_image.dart';
import '../../../app/widgets/app_cupertino_page_scaffold.dart';
import '../../../app/widgets/source_consistent_card.dart';
import '../../../core/database/database_service.dart';
import '../../../core/services/exception_log_service.dart';
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
  static const double _scrollLoadThreshold = 220;
  static const double _minTapSize = SourceUiTokens.minTapSize;
  static const double _footerTapMinHeight = SourceUiTokens.minTapSize;

  late final RuleParserEngine _engine;
  late final BookAddService _addService;
  final ScrollController _scrollController = ScrollController();

  final List<SearchResult> _results = <SearchResult>[];
  final Set<String> _seenKeys = <String>{};
  Set<String> _bookshelfKeys = <String>{};

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
    _bookshelfKeys = _addService.buildSearchBookshelfKeys();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_loadMore(trigger: 'init'));
    });
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
    if (position.pixels >= position.maxScrollExtent - _scrollLoadThreshold) {
      unawaited(_loadMore(trigger: 'scroll'));
    }
  }

  Future<void> _loadMore({
    bool forceLoad = false,
    bool resetList = false,
    String trigger = 'manual',
  }) async {
    if (_loading) return;
    if (!forceLoad && !_hasMore) return;

    final requestPage = resetList ? 1 : _page;

    setState(() {
      _loading = true;
      _errorMessage = null;
      if (forceLoad) {
        // 对齐 legado LoadMoreView.hasMore()：用户点“继续加载/重试”时强制恢复可加载状态。
        _hasMore = true;
      }
      if (resetList) {
        _results.clear();
        _seenKeys.clear();
        _hasMore = true;
        _page = 1;
      }
    });

    try {
      debugPrint(
        '[discovery-results] loadMore trigger=$trigger page=$requestPage '
        'forceLoad=$forceLoad resetList=$resetList source=${widget.source.bookSourceUrl}',
      );
      final fetched = await _engine.explore(
        widget.source,
        exploreUrlOverride: widget.exploreUrl,
        page: requestPage,
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
          debugPrint(
            '[discovery-results] no more data page=$requestPage '
            'fetched=${fetched.length} added=$added',
          );
        } else {
          _page = requestPage + 1;
          debugPrint(
            '[discovery-results] loaded page=$requestPage '
            'fetched=${fetched.length} added=$added nextPage=$_page',
          );
        }
      });
    } catch (e, st) {
      ExceptionLogService().record(
        node: 'discovery.explore_results.load_more',
        message: '发现二级页加载失败',
        error: e,
        stackTrace: st,
        context: <String, dynamic>{
          'sourceUrl': widget.source.bookSourceUrl,
          'sourceName': widget.source.bookSourceName,
          'exploreName': widget.exploreName,
          'exploreUrl': widget.exploreUrl,
          'page': requestPage,
          'trigger': trigger,
        },
      );
      if (!mounted) return;
      setState(() {
        _loading = false;
        _hasMore = false;
        _errorMessage = _compactReason(e.toString());
      });
      debugPrint(
        '[discovery-results] load failed page=$requestPage trigger=$trigger error=$e',
      );
    }
  }

  String _compactReason(String text, {int maxLength = 96}) {
    final normalized = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.length <= maxLength) return normalized;
    return '${normalized.substring(0, maxLength)}…';
  }

  Future<void> _openBookInfo(SearchResult result) async {
    try {
      await Navigator.of(context, rootNavigator: true).push(
        CupertinoPageRoute<void>(
          builder: (_) => SearchBookInfoView(result: result),
        ),
      );
    } catch (e, st) {
      ExceptionLogService().record(
        node: 'discovery.explore_results.open_book_info',
        message: '打开书籍详情失败',
        error: e,
        stackTrace: st,
        context: <String, dynamic>{
          'bookName': result.name,
          'bookUrl': result.bookUrl,
          'sourceUrl': result.sourceUrl,
        },
      );
      if (mounted) {
        _showMessage('打开详情失败，请稍后重试');
      }
    }
    if (!mounted) return;
    setState(() {
      _bookshelfKeys = _addService.buildSearchBookshelfKeys();
    });
  }

  Future<void> _onFooterTap() async {
    if (_loading) return;
    if ((_errorMessage ?? '').trim().isNotEmpty) {
      final retry = await _showLoadErrorDialog(_errorMessage!);
      if (!retry || !mounted) return;
      await _loadMore(
        forceLoad: true,
        trigger: 'footer_error_retry',
      );
      return;
    }
    await _loadMore(
      forceLoad: true,
      trigger: 'footer_click',
    );
  }

  Future<bool> _showLoadErrorDialog(String detail) async {
    final result = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('加载失败'),
        content: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(detail),
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('取消'),
            onPressed: () => Navigator.of(ctx).pop(false),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            child: const Text('重试'),
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  void _showMessage(String message, {String title = '提示'}) {
    showCupertinoDialog<void>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(title),
        content: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(message),
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('确定'),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = CupertinoTheme.of(context);
    final textStyle = theme.textTheme.textStyle;
    final secondaryTextColor =
        SourceUiTokens.resolveSecondaryTextColor(context);

    return AppCupertinoPageScaffold(
      title: widget.exploreName,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              SourceUiTokens.pagePaddingHorizontal,
              12,
              SourceUiTokens.pagePaddingHorizontal,
              10,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.source.bookSourceName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textStyle.copyWith(
                      fontSize: SourceUiTokens.itemMetaSize,
                      color: secondaryTextColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  '已加载 ${_results.length} 本',
                  style: textStyle.copyWith(
                    fontSize: SourceUiTokens.itemSubMetaSize,
                    color: secondaryTextColor,
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
    if (_results.isEmpty && _loading) {
      return const Center(child: CupertinoActivityIndicator());
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(
        SourceUiTokens.pagePaddingHorizontal,
        0,
        SourceUiTokens.pagePaddingHorizontal,
        12,
      ),
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
    final textStyle = CupertinoTheme.of(context).textTheme.textStyle;
    final primaryTextColor = CupertinoColors.label.resolveFrom(context);
    final secondaryTextColor =
        SourceUiTokens.resolveSecondaryTextColor(context);
    final inShelfColor = CupertinoColors.activeBlue.resolveFrom(context);
    final inBookshelf = _addService.isInBookshelf(
      result,
      bookshelfKeys: _bookshelfKeys,
    );
    final author = result.author.trim().isEmpty ? '未知作者' : result.author.trim();
    final lastChapter = result.lastChapter.trim();
    final intro = result.intro.trim();

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _openBookInfo(result),
        child: SourceConsistentCard(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: _minTapSize),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppCoverImage(
                  urlOrPath: result.coverUrl,
                  title: result.name,
                  author: result.author,
                  width: SourceUiTokens.discoveryResultCoverWidth,
                  height: SourceUiTokens.discoveryResultCoverHeight,
                  borderRadius: 7,
                  fit: BoxFit.cover,
                  showTextOnPlaceholder: false,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        result.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textStyle.copyWith(
                          fontSize: SourceUiTokens.itemTitleSize,
                          fontWeight: FontWeight.w600,
                          color: primaryTextColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        author,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textStyle.copyWith(
                          fontSize: SourceUiTokens.itemMetaSize,
                          color: secondaryTextColor,
                        ),
                      ),
                      if (lastChapter.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          '最新：$lastChapter',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textStyle.copyWith(
                            fontSize: SourceUiTokens.itemSubMetaSize,
                            color: CupertinoColors.tertiaryLabel
                                .resolveFrom(context),
                          ),
                        ),
                      ],
                      if (intro.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          intro,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textStyle.copyWith(
                            fontSize: SourceUiTokens.itemSubMetaSize,
                            color: CupertinoColors.tertiaryLabel
                                .resolveFrom(context),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: _minTapSize,
                  height: _minTapSize,
                  child: Center(
                    child: Icon(
                      inBookshelf
                          ? CupertinoIcons.book_fill
                          : CupertinoIcons.chevron_right,
                      size: inBookshelf ? 17 : 16,
                      color: inBookshelf ? inShelfColor : secondaryTextColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    final textStyle = CupertinoTheme.of(context).textTheme.textStyle;
    final secondaryTextColor =
        SourceUiTokens.resolveSecondaryTextColor(context);
    final destructiveColor = SourceUiTokens.resolveDangerColor(context);
    final primaryActionColor =
        SourceUiTokens.resolvePrimaryActionColor(context);
    final hasError = (_errorMessage ?? '').trim().isNotEmpty;

    if (_results.isEmpty && !_loading && !hasError && !_hasMore) {
      return _buildFooterBox(
        child: Text(
          '暂无发现内容',
          style: textStyle.copyWith(
            fontSize: SourceUiTokens.itemMetaSize,
            color: secondaryTextColor,
          ),
        ),
      );
    }

    if (_loading) {
      return const _FooterLoadingBox();
    }

    if (hasError) {
      return _buildFooterBox(
        onTap: () => unawaited(_onFooterTap()),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '加载失败，点按查看详情并重试',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: textStyle.copyWith(
                fontSize: SourceUiTokens.itemMetaSize,
                color: destructiveColor,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _errorMessage!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: textStyle.copyWith(
                fontSize: SourceUiTokens.itemSubMetaSize,
                color: secondaryTextColor,
              ),
            ),
          ],
        ),
      );
    }

    if (!_hasMore) {
      return _buildFooterBox(
        child: Text(
          '没有更多了',
          style: textStyle.copyWith(
            fontSize: SourceUiTokens.itemMetaSize,
            color: secondaryTextColor,
          ),
        ),
      );
    }

    return _buildFooterBox(
      onTap: () => unawaited(_onFooterTap()),
      child: Text(
        '点击继续加载',
        style: textStyle.copyWith(
          fontSize: SourceUiTokens.itemMetaSize,
          color: primaryActionColor,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildFooterBox({
    required Widget child,
    VoidCallback? onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 12),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: _footerTapMinHeight),
          child: Center(
            child: child,
          ),
        ),
      ),
    );
  }
}

class _FooterLoadingBox extends StatelessWidget {
  const _FooterLoadingBox();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 12),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: SourceUiTokens.minTapSize),
        child: const Center(child: CupertinoActivityIndicator()),
      ),
    );
  }
}
