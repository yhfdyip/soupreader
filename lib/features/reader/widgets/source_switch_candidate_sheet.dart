import 'package:flutter/cupertino.dart';

import '../services/reader_source_switch_helper.dart';

Future<ReaderSourceSwitchCandidate?> showSourceSwitchCandidateSheet({
  required BuildContext context,
  required String keyword,
  required List<ReaderSourceSwitchCandidate> candidates,
  required bool loadTocEnabled,
  Future<void> Function(bool enabled)? onLoadTocChanged,
  Future<void> Function()? onOpenSourceManage,
  Future<List<ReaderSourceSwitchCandidate>> Function(
    List<ReaderSourceSwitchCandidate> currentCandidates,
  )? onRefreshCandidates,
}) {
  return showCupertinoModalPopup<ReaderSourceSwitchCandidate>(
    context: context,
    builder: (_) => SourceSwitchCandidateSheet(
      keyword: keyword,
      candidates: candidates,
      loadTocEnabled: loadTocEnabled,
      onLoadTocChanged: onLoadTocChanged,
      onOpenSourceManage: onOpenSourceManage,
      onRefreshCandidates: onRefreshCandidates,
    ),
  );
}

class SourceSwitchCandidateSheet extends StatefulWidget {
  final String keyword;
  final List<ReaderSourceSwitchCandidate> candidates;
  final bool loadTocEnabled;
  final Future<void> Function(bool enabled)? onLoadTocChanged;
  final Future<void> Function()? onOpenSourceManage;
  final Future<List<ReaderSourceSwitchCandidate>> Function(
    List<ReaderSourceSwitchCandidate> currentCandidates,
  )? onRefreshCandidates;

  const SourceSwitchCandidateSheet({
    super.key,
    required this.keyword,
    required this.candidates,
    required this.loadTocEnabled,
    this.onLoadTocChanged,
    this.onOpenSourceManage,
    this.onRefreshCandidates,
  });

  @override
  State<SourceSwitchCandidateSheet> createState() =>
      _SourceSwitchCandidateSheetState();
}

class _SourceSwitchCandidateSheetState
    extends State<SourceSwitchCandidateSheet> {
  final TextEditingController _queryController = TextEditingController();
  String _query = '';
  bool _openingSourceManage = false;
  bool _refreshingCandidates = false;
  bool _updatingLoadToc = false;
  late bool _loadTocEnabled;
  late List<ReaderSourceSwitchCandidate> _candidates;

  List<ReaderSourceSwitchCandidate> get _filteredCandidates {
    return ReaderSourceSwitchHelper.filterCandidates(
      candidates: _candidates,
      query: _query,
    );
  }

  @override
  void initState() {
    super.initState();
    _loadTocEnabled = widget.loadTocEnabled;
    _candidates = List<ReaderSourceSwitchCandidate>.from(
      widget.candidates,
      growable: false,
    );
    _queryController.addListener(_handleQueryChanged);
  }

  @override
  void didUpdateWidget(covariant SourceSwitchCandidateSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.loadTocEnabled != widget.loadTocEnabled) {
      _loadTocEnabled = widget.loadTocEnabled;
    }
  }

  @override
  void dispose() {
    _queryController
      ..removeListener(_handleQueryChanged)
      ..dispose();
    super.dispose();
  }

  void _handleQueryChanged() {
    final value = _queryController.text;
    if (value == _query) return;
    setState(() => _query = value);
  }

  Future<void> _handleOpenSourceManage() async {
    final onOpenSourceManage = widget.onOpenSourceManage;
    if (onOpenSourceManage == null ||
        _openingSourceManage ||
        _refreshingCandidates) {
      return;
    }
    setState(() => _openingSourceManage = true);
    try {
      await onOpenSourceManage();
    } finally {
      if (mounted) {
        setState(() => _openingSourceManage = false);
      }
    }
  }

  Future<void> _handleRefreshCandidates() async {
    final onRefreshCandidates = widget.onRefreshCandidates;
    if (onRefreshCandidates == null ||
        _refreshingCandidates ||
        _openingSourceManage) {
      return;
    }
    setState(() => _refreshingCandidates = true);
    final currentCandidates = List<ReaderSourceSwitchCandidate>.from(
      _filteredCandidates,
      growable: false,
    );
    try {
      final refreshed = await onRefreshCandidates(currentCandidates);
      if (!mounted) return;
      setState(() {
        _candidates = List<ReaderSourceSwitchCandidate>.from(
          refreshed,
          growable: false,
        );
      });
    } catch (_) {
      // 与 legado 一致：刷新失败保持当前列表且不弹额外提示。
    } finally {
      if (mounted) {
        setState(() => _refreshingCandidates = false);
      }
    }
  }

  Future<void> _handleToggleLoadToc() async {
    final onLoadTocChanged = widget.onLoadTocChanged;
    if (onLoadTocChanged == null || _updatingLoadToc) {
      return;
    }
    final next = !_loadTocEnabled;
    setState(() {
      _loadTocEnabled = next;
      _updatingLoadToc = true;
    });
    try {
      await onLoadTocChanged(next);
    } finally {
      if (mounted) {
        setState(() => _updatingLoadToc = false);
      }
    }
  }

  Future<void> _showMoreActions() async {
    if (_openingSourceManage || _refreshingCandidates || _updatingLoadToc) {
      return;
    }
    final action = await showCupertinoModalPopup<_SourceSwitchMenuAction>(
      context: context,
      builder: (sheetContext) => CupertinoActionSheet(
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(sheetContext).pop(_SourceSwitchMenuAction.loadToc);
            },
            child: Text(_loadTocEnabled ? '✓ 加载目录' : '加载目录'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(sheetContext).pop(),
          child: const Text('取消'),
        ),
      ),
    );
    if (action == _SourceSwitchMenuAction.loadToc) {
      await _handleToggleLoadToc();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = CupertinoTheme.of(context);
    final size = MediaQuery.of(context).size;
    final filtered = _filteredCandidates;

    return SafeArea(
      top: false,
      child: Container(
        height: size.height * 0.8,
        decoration: BoxDecoration(
          color: colors.scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: CupertinoColors.systemGrey3.resolveFrom(context),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '换源（${widget.keyword}）',
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '候选 ${_candidates.length} 条',
                          style: TextStyle(
                            fontSize: 13,
                            color: CupertinoColors.systemGrey.resolveFrom(
                              context,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      if (widget.onRefreshCandidates != null)
                        CupertinoButton(
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(32, 32),
                          onPressed:
                              (_refreshingCandidates || _openingSourceManage)
                                  ? null
                                  : _handleRefreshCandidates,
                          child: Text(
                            _refreshingCandidates ? '刷新中' : '刷新列表',
                          ),
                        ),
                      if (widget.onRefreshCandidates != null)
                        const SizedBox(width: 12),
                      if (widget.onOpenSourceManage != null)
                        CupertinoButton(
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(32, 32),
                          onPressed:
                              (_openingSourceManage || _refreshingCandidates)
                                  ? null
                                  : _handleOpenSourceManage,
                          child: const Text('书源管理'),
                        ),
                      const SizedBox(width: 12),
                      if (widget.onLoadTocChanged != null)
                        CupertinoButton(
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(32, 32),
                          onPressed: (_openingSourceManage ||
                                  _refreshingCandidates ||
                                  _updatingLoadToc)
                              ? null
                              : _showMoreActions,
                          child: const Text('更多'),
                        ),
                      if (widget.onLoadTocChanged != null)
                        const SizedBox(width: 12),
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(32, 32),
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('取消'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
              child: CupertinoSearchTextField(
                controller: _queryController,
                placeholder: '筛选书源 / 最新章节',
              ),
            ),
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Text(
                        _query.trim().isEmpty ? '暂无候选书源' : '无匹配候选',
                        style: TextStyle(
                          fontSize: 14,
                          color:
                              CupertinoColors.systemGrey.resolveFrom(context),
                        ),
                      ),
                    )
                  : ListView.separated(
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                        height: 0.5,
                        color: CupertinoColors.systemGrey4.resolveFrom(context),
                      ),
                      itemBuilder: (itemContext, index) {
                        final candidate = filtered[index];
                        final sourceName = candidate.source.bookSourceName;
                        final author = candidate.book.author.trim().isEmpty
                            ? '未知作者'
                            : candidate.book.author.trim();
                        final latestChapter = candidate.book.lastChapter.trim();
                        return CupertinoButton(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          minimumSize: Size.zero,
                          onPressed: () =>
                              Navigator.of(itemContext).pop(candidate),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  sourceName,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: CupertinoColors.label,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  author,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color:
                                        CupertinoColors.systemGrey.resolveFrom(
                                      itemContext,
                                    ),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (latestChapter.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    latestChapter,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: CupertinoColors.systemGrey2
                                          .resolveFrom(itemContext),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _SourceSwitchMenuAction {
  loadToc,
}
