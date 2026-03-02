import 'package:flutter/cupertino.dart';
import 'package:path/path.dart' as p;

import '../../../app/widgets/app_cupertino_page_scaffold.dart';
import '../../../app/widgets/app_nav_bar_button.dart';
import '../services/remote_books_archive_service.dart';

/// 远程压缩包内容选择页（Cupertino 风格）。
///
/// 设计目标：
/// - 对齐 legado：压缩包下载完成后进入“打开压缩包 -> 选择阅读条目”流程；
/// - 允许文件数量较多时可滚动浏览，并提供轻量搜索；
/// - 点击条目即返回选中的文件名给上层（由上层决定导入与阅读）。
class RemoteBooksArchiveEntriesView extends StatefulWidget {
  const RemoteBooksArchiveEntriesView({
    super.key,
    required this.archiveName,
    required this.candidates,
    this.message,
  });

  final String archiveName;
  final List<RemoteBooksArchiveCandidate> candidates;
  final String? message;

  @override
  State<RemoteBooksArchiveEntriesView> createState() =>
      _RemoteBooksArchiveEntriesViewState();
}

class _RemoteBooksArchiveEntriesViewState
    extends State<RemoteBooksArchiveEntriesView> {
  String _query = '';

  List<RemoteBooksArchiveCandidate> _filterCandidates() {
    final query = _query.trim().toLowerCase();
    final candidates = widget.candidates;
    if (query.isEmpty) return candidates;
    return candidates
        .where((item) => item.fileName.toLowerCase().contains(query))
        .toList(growable: false);
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    const units = <String>['B', 'KB', 'MB', 'GB'];
    var value = bytes.toDouble();
    var idx = 0;
    while (value >= 1024 && idx < units.length - 1) {
      value /= 1024;
      idx++;
    }
    final text = idx == 0 ? value.toStringAsFixed(0) : value.toStringAsFixed(1);
    return '$text ${units[idx]}';
  }

  IconData _resolveIcon(RemoteBooksArchiveCandidate item) {
    switch (item.extension) {
      case 'txt':
        return CupertinoIcons.doc_text;
      case 'epub':
        return CupertinoIcons.book;
      default:
        return CupertinoIcons.doc;
    }
  }

  Widget _buildMessageCard(BuildContext context, String message) {
    final bg = CupertinoColors.secondarySystemGroupedBackground.resolveFrom(
      context,
    );
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        message,
        style: const TextStyle(fontSize: 13),
      ),
    );
  }

  Widget _buildCandidateTile(
    BuildContext context,
    RemoteBooksArchiveCandidate item,
  ) {
    final separator = CupertinoColors.separator.resolveFrom(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.of(context).pop(item.fileName),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
        decoration: BoxDecoration(
          color: CupertinoColors.systemBackground.resolveFrom(context),
          border: Border(bottom: BorderSide(color: separator, width: 0.5)),
        ),
        child: Row(
          children: [
            Icon(
              _resolveIcon(item),
              size: 18,
              color: CupertinoColors.activeBlue.resolveFrom(context),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.fileName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${item.extension.toUpperCase()} · ${_formatBytes(item.sizeInBytes)}',
                    style: TextStyle(
                      fontSize: 12,
                      color:
                          CupertinoColors.secondaryLabel.resolveFrom(context),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              CupertinoIcons.chevron_forward,
              size: 16,
              color: CupertinoColors.tertiaryLabel.resolveFrom(context),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final archiveTitle = p.basename(widget.archiveName.trim());
    final candidates = _filterCandidates();
    final message = widget.message?.trim() ?? '';

    return AppCupertinoPageScaffold(
      title: '压缩包内容',
      middle: Text(archiveTitle.isEmpty ? '压缩包内容' : archiveTitle),
      trailing: AppNavBarButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('取消'),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
            child: CupertinoSearchTextField(
              placeholder: '搜索文件名',
              onChanged: (value) => setState(() => _query = value),
            ),
          ),
          if (message.isNotEmpty) _buildMessageCard(context, message),
          Expanded(
            child: candidates.isEmpty
                ? Center(
                    child: Text(
                      '未找到可阅读文件',
                      style: TextStyle(
                        fontSize: 14,
                        color:
                            CupertinoColors.secondaryLabel.resolveFrom(context),
                      ),
                    ),
                  )
                : ListView.builder(
                    itemCount: candidates.length,
                    itemBuilder: (itemContext, index) {
                      return _buildCandidateTile(
                        itemContext,
                        candidates[index],
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
