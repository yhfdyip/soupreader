import 'package:flutter/cupertino.dart';

import '../../../app/widgets/app_cupertino_page_scaffold.dart';
import '../../../core/database/database_service.dart';
import '../../../core/database/repositories/rss_article_repository.dart';
import '../models/rss_read_record.dart';

class RssReadRecordView extends StatefulWidget {
  const RssReadRecordView({
    super.key,
    this.repository,
  });

  final RssReadRecordRepository? repository;

  @override
  State<RssReadRecordView> createState() => _RssReadRecordViewState();
}

class _RssReadRecordViewState extends State<RssReadRecordView> {
  late final RssReadRecordRepository _repo;
  List<RssReadRecord> _records = const <RssReadRecord>[];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _repo = widget.repository ?? RssReadRecordRepository(DatabaseService());
    _reload();
  }

  Future<void> _reload() async {
    final records = await _repo.getRecords();
    if (!mounted) return;
    setState(() {
      _records = records;
      _loading = false;
    });
  }

  Future<void> _clearAllRecords() async {
    final count = await _repo.countRecords();
    if (!mounted) return;
    final shouldClear = await showCupertinoDialog<bool>(
          context: context,
          builder: (ctx) => CupertinoAlertDialog(
            title: const Text('清空阅读记录'),
            content: Text('\n确定删除 $count 条阅读记录吗？'),
            actions: [
              CupertinoDialogAction(
                isDestructiveAction: true,
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('清空'),
              ),
              CupertinoDialogAction(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('取消'),
              ),
            ],
          ),
        ) ??
        false;
    if (!shouldClear) return;
    await _repo.deleteAllRecord();
    await _reload();
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Text(
        '暂无阅读记录',
        style: TextStyle(color: CupertinoColors.secondaryLabel),
      ),
    );
  }

  Widget _buildRecordList() {
    return ListView.separated(
      padding: const EdgeInsets.only(top: 12, bottom: 24),
      itemCount: _records.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final record = _records[index];
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: CupertinoColors.secondarySystemGroupedBackground
                .resolveFrom(context),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                (record.title ?? '').trim().isEmpty
                    ? '未命名文章'
                    : record.title!.trim(),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              Text(
                record.record,
                style: const TextStyle(
                  fontSize: 12,
                  color: CupertinoColors.secondaryLabel,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppCupertinoPageScaffold(
      title: '阅读记录',
      trailing: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed:
            _loading || _records.isEmpty ? null : () => _clearAllRecords(),
        child: const Text('清空'),
      ),
      child: _loading
          ? const Center(child: CupertinoActivityIndicator())
          : _records.isEmpty
              ? _buildEmptyState()
              : _buildRecordList(),
    );
  }
}
