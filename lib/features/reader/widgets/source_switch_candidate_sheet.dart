import 'package:flutter/cupertino.dart';

import '../services/reader_source_switch_helper.dart';

Future<ReaderSourceSwitchCandidate?> showSourceSwitchCandidateSheet({
  required BuildContext context,
  required String keyword,
  required List<ReaderSourceSwitchCandidate> candidates,
}) {
  return showCupertinoModalPopup<ReaderSourceSwitchCandidate>(
    context: context,
    builder: (_) => SourceSwitchCandidateSheet(
      keyword: keyword,
      candidates: candidates,
    ),
  );
}

class SourceSwitchCandidateSheet extends StatefulWidget {
  final String keyword;
  final List<ReaderSourceSwitchCandidate> candidates;

  const SourceSwitchCandidateSheet({
    super.key,
    required this.keyword,
    required this.candidates,
  });

  @override
  State<SourceSwitchCandidateSheet> createState() =>
      _SourceSwitchCandidateSheetState();
}

class _SourceSwitchCandidateSheetState
    extends State<SourceSwitchCandidateSheet> {
  final TextEditingController _queryController = TextEditingController();
  String _query = '';

  List<ReaderSourceSwitchCandidate> get _filteredCandidates {
    return ReaderSourceSwitchHelper.filterCandidates(
      candidates: widget.candidates,
      query: _query,
    );
  }

  @override
  void initState() {
    super.initState();
    _queryController.addListener(_handleQueryChanged);
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
                          '候选 ${widget.candidates.length} 条',
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
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(32, 32),
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('取消'),
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
