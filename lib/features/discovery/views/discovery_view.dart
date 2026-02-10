import 'package:flutter/cupertino.dart';

import '../../../app/theme/design_tokens.dart';
import '../../../core/database/database_service.dart';
import '../../../core/database/repositories/source_repository.dart';
import '../../bookshelf/services/book_add_service.dart';
import '../../source/models/book_source.dart';
import '../../source/services/rule_parser_engine.dart';

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
  final RuleParserEngine _engine = RuleParserEngine();
  late final SourceRepository _sourceRepo;
  late final BookAddService _addService;

  bool _loading = false;
  bool _cancelRequested = false;
  bool _isImporting = false;

  String _currentSourceName = '';
  int _completedSources = 0;
  int _totalSources = 0;

  final List<SearchResult> _results = <SearchResult>[];
  final List<_SourceRunIssue> _sourceIssues = <_SourceRunIssue>[];
  String? _lastError;

  @override
  void initState() {
    super.initState();
    final db = DatabaseService();
    _sourceRepo = SourceRepository(db);
    _addService = BookAddService(database: db, engine: _engine);

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

  Future<void> _refresh() async {
    if (_loading) return;

    final sources = _eligibleSources();
    final seenResultKeys = <String>{};
    setState(() {
      _loading = true;
      _cancelRequested = false;
      _results.clear();
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

  Future<void> _importBook(SearchResult result) async {
    if (_isImporting) return;
    setState(() => _isImporting = true);
    try {
      final addResult = await _addService.addFromSearchResult(result);
      if (!mounted) return;
      _showMessage(addResult.message);
    } finally {
      if (mounted) setState(() => _isImporting = false);
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
    final eligibleCount = _eligibleSources().length;
    final theme = CupertinoTheme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final borderColor =
        isDark ? AppDesignTokens.borderDark : AppDesignTokens.borderLight;
    final panelColor = isDark
        ? AppDesignTokens.surfaceDark.withValues(alpha: 0.82)
        : AppDesignTokens.surfaceLight.withValues(alpha: 0.94);

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('发现'),
        backgroundColor: theme.barBackgroundColor,
        border: Border(bottom: BorderSide(color: borderColor, width: 0.5)),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _loading ? null : _refresh,
          child: const Icon(CupertinoIcons.refresh),
        ),
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
              if (_loading)
                _buildStatusPanel(
                  borderColor: borderColor,
                  panelColor: panelColor,
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
                            color: isDark
                                ? AppDesignTokens.textMuted
                                : AppDesignTokens.textNormal,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: _stop,
                        child: const Text('停止'),
                      ),
                    ],
                  ),
                )
              else if (_sourceIssues.isNotEmpty)
                _buildStatusPanel(
                  borderColor: CupertinoColors.systemRed.resolveFrom(context),
                  panelColor: panelColor,
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
                )
              else if (_lastError != null && _results.isEmpty)
                _buildStatusPanel(
                  borderColor: CupertinoColors.systemRed.resolveFrom(context),
                  panelColor: panelColor,
                  child: Text(
                    _lastError!,
                    style: TextStyle(
                      fontSize: 13,
                      color: CupertinoColors.systemRed.resolveFrom(context),
                    ),
                  ),
                )
              else
                const SizedBox(height: 6),
              Expanded(
                child: _results.isEmpty
                    ? _buildEmptyState(context, eligibleCount)
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(12, 2, 12, 12),
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
      ),
    );
  }

  Widget _buildStatusPanel({
    required Color borderColor,
    required Color panelColor,
    required Widget child,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
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

  Widget _buildEmptyState(BuildContext context, int eligibleCount) {
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
            CupertinoIcons.compass,
            size: 64,
            color: CupertinoColors.systemGrey.resolveFrom(context),
          ),
          const SizedBox(height: 16),
          Text(
            '暂无发现内容',
            style: TextStyle(
              fontSize: 16,
              color: CupertinoColors.secondaryLabel.resolveFrom(context),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
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
    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;
    final tileColor = isDark
        ? AppDesignTokens.surfaceDark.withValues(alpha: 0.78)
        : AppDesignTokens.surfaceLight;
    final borderColor =
        isDark ? AppDesignTokens.borderDark : AppDesignTokens.borderLight;

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
              const SizedBox(height: 2),
              Text(
                '来源: ${result.sourceName}',
                style: TextStyle(
                  fontSize: 12,
                  color: CupertinoColors.tertiaryLabel.resolveFrom(context),
                ),
              ),
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
