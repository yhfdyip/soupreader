import 'package:flutter/cupertino.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../app/widgets/app_cupertino_page_scaffold.dart';
import '../../../core/database/database_service.dart';
import '../../../core/database/repositories/source_repository.dart';
import '../../bookshelf/services/book_add_service.dart';
import '../../source/models/book_source.dart';
import '../../source/services/rule_parser_engine.dart';
import '../../search/views/search_book_info_view.dart';

/// 发现页（对标 Legado 的 exploreUrl / ruleExplore）
///
/// 目标：
/// - 基于已导入的书源“发现规则”拉取列表
/// - 展示聚合结果，支持“一键加入书架”
/// - iOS（Cupertino）优先
class DiscoveryView extends StatefulWidget {
  const DiscoveryView({super.key});

  @override
  State<DiscoveryView> createState() => _DiscoveryViewState();
}

class _DiscoveryViewState extends State<DiscoveryView> {
  late final SourceRepository _sourceRepo;
  late final BookAddService _addService;

  bool _loading = false;
  bool _cancelRequested = false;

  String _currentSourceName = '';
  int _completedSources = 0;
  int _totalSources = 0;

  final List<SearchResult> _results = <SearchResult>[];
  List<_DiscoveryDisplayItem> _displayResults = <_DiscoveryDisplayItem>[];
  final List<_SourceRunIssue> _sourceIssues = <_SourceRunIssue>[];
  String? _lastError;

  @override
  void initState() {
    super.initState();
    final db = DatabaseService();
    _sourceRepo = SourceRepository(db);
    _addService = BookAddService(database: db);

    // 首次进入自动拉取一次
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  List<BookSource> _eligibleSources() {
    final all = _sourceRepo.getAllSources();
    final eligible = all.where((s) {
      final hasExplore =
          (s.exploreUrl ?? '').trim().isNotEmpty && s.ruleExplore != null;
      return s.enabled && s.enabledExplore && hasExplore;
    }).toList(growable: false);
    eligible.sort((a, b) {
      if (a.weight != b.weight) return b.weight.compareTo(a.weight);
      return a.bookSourceName.compareTo(b.bookSourceName);
    });
    return eligible;
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
    final built = <_DiscoveryDisplayItem>[];
    for (final entry in grouped.entries) {
      final origins = entry.value;
      if (origins.isEmpty) continue;
      final primary = origins.first;
      final inBookshelf = origins.any(_addService.isInBookshelf);
      built.add(
        _DiscoveryDisplayItem(
          primary: primary,
          origins: origins,
          inBookshelf: inBookshelf,
        ),
      );
    }
    _displayResults = built;
  }

  Future<void> _refresh() async {
    if (_loading) return;

    final sources = _eligibleSources();
    final seenResultKeys = <String>{};
    setState(() {
      _loading = true;
      _cancelRequested = false;
      _results.clear();
      _displayResults.clear();
      _sourceIssues.clear();
      _lastError = null;
      _currentSourceName = '';
      _completedSources = 0;
      _totalSources = sources.length;
    });

    if (sources.isEmpty) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _lastError = '没有可用的发现书源（需要 exploreUrl + ruleExplore 且启用发现）';
      });
      return;
    }

    for (final source in sources) {
      if (_cancelRequested) break;

      if (!mounted) return;
      setState(() => _currentSourceName = source.bookSourceName);

      try {
        final debugEngine = RuleParserEngine();
        final debugResult = await debugEngine.exploreDebug(source);
        final issue = _buildExploreIssue(source, debugResult);
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
              reason: '发现异常：${_compactReason(e.toString())}',
            ),
          );
          _lastError = '部分书源拉取失败';
        });
      }
    }

    if (!mounted) return;
    setState(() {
      _loading = false;
      _currentSourceName = '';
    });
  }

  _SourceRunIssue? _buildExploreIssue(
    BookSource source,
    ExploreDebugResult debugResult,
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

  void _stop() {
    setState(() {
      _cancelRequested = true;
      _loading = false;
      _currentSourceName = '';
    });
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
    final eligibleCount = _eligibleSources().length;
    final theme = ShadTheme.of(context);
    final scheme = theme.colorScheme;

    return AppCupertinoPageScaffold(
      title: '发现',
      trailing: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: _loading ? null : _refresh,
        child: const Icon(CupertinoIcons.refresh),
      ),
      child: Column(
        children: [
          if (_loading)
            _buildStatusPanel(
              borderColor: scheme.border,
              child: Row(
                children: [
                  const CupertinoActivityIndicator(),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _currentSourceName.isEmpty
                          ? '正在加载…'
                          : '正在发现: $_currentSourceName ($_completedSources/$_totalSources)',
                      style: TextStyle(
                        fontSize: 13,
                        color: scheme.mutedForeground,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  ShadButton.link(
                    onPressed: _stop,
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
            )
          else if (_lastError != null && _results.isEmpty)
            _buildStatusPanel(
              borderColor: scheme.destructive,
              child: Text(
                _lastError!,
                style: TextStyle(
                  fontSize: 13,
                  color: scheme.destructive,
                ),
              ),
            )
          else
            const SizedBox(height: 6),
          Expanded(
            child: _displayResults.isEmpty
                ? _buildEmptyState(context, eligibleCount)
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
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      child: ShadCard(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: ShadBorder.all(color: borderColor, width: 1),
        child: child,
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, int eligibleCount) {
    final theme = ShadTheme.of(context);
    final scheme = theme.colorScheme;

    final subtitle = eligibleCount == 0
        ? '没有可用的发现书源\n请先导入带 exploreUrl/ruleExplore 的 Legado 书源'
        : _sourceIssues.isEmpty
            ? '点击右上角刷新'
            : '本次有失败书源，点上方“查看”了解原因';
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            LucideIcons.compass,
            size: 52,
            color: scheme.mutedForeground,
          ),
          const SizedBox(height: 16),
          Text(
            '暂无发现内容',
            style: theme.textTheme.h4,
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: theme.textTheme.muted.copyWith(
              color: scheme.mutedForeground,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultItem(_DiscoveryDisplayItem item) {
    final theme = ShadTheme.of(context);
    final scheme = theme.colorScheme;
    final radius = theme.radius;
    final coverBg = scheme.muted;
    final result = item.primary;
    final sourceCount = item.origins.length;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: () => _openBookInfo(result),
        child: ShadCard(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          leading: Container(
            width: 40,
            height: 56,
            decoration: BoxDecoration(
              color: coverBg,
              borderRadius: radius,
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
                      style: theme.textTheme.h4.copyWith(
                        color: scheme.mutedForeground,
                      ),
                    ),
                  )
                : null,
          ),
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
              const SizedBox(height: 2),
              Text(
                sourceCount > 1
                    ? '来源: ${result.sourceName} 等 $sourceCount 个'
                    : '来源: ${result.sourceName}',
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
}

class _DiscoveryDisplayItem {
  final SearchResult primary;
  final List<SearchResult> origins;
  final bool inBookshelf;

  const _DiscoveryDisplayItem({
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
