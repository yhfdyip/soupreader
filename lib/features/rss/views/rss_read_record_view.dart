import 'package:flutter/cupertino.dart';
import '../../../app/widgets/cupertino_bottom_dialog.dart';

import '../../../app/theme/ui_tokens.dart';
import '../../../app/widgets/app_cupertino_page_scaffold.dart';
import '../../../app/widgets/app_empty_state.dart';
import '../../../app/widgets/app_nav_bar_button.dart';
import '../../../app/widgets/app_ui_kit.dart';
import '../../../core/database/database_service.dart';
import '../../../core/database/repositories/rss_article_repository.dart';
import '../../../core/services/exception_log_service.dart';
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
    int count = 0;
    try {
      count = await _repo.countRecords();
    } catch (error, stackTrace) {
      ExceptionLogService().record(
        node: 'rss_read_record.menu_clear',
        message: '统计 RSS 阅读记录数量失败',
        error: error,
        stackTrace: stackTrace,
      );
      return;
    }
    if (!mounted) return;
    final shouldClear = await showCupertinoBottomSheetDialog<bool>(
          context: context,
          builder: (ctx) => CupertinoAlertDialog(
            title: const Text('提醒'),
            content: Text('确定删除\n$count 阅读记录'),
            actions: [
              CupertinoDialogAction(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('取消'),
              ),
              CupertinoDialogAction(
                isDestructiveAction: true,
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('确定'),
              ),
            ],
          ),
        ) ??
        false;
    if (!shouldClear) return;
    try {
      await _repo.deleteAllRecord();
      await _reload();
    } catch (error, stackTrace) {
      ExceptionLogService().record(
        node: 'rss_read_record.menu_clear',
        message: '清除 RSS 阅读记录失败',
        error: error,
        stackTrace: stackTrace,
        context: <String, dynamic>{
          'count': count,
        },
      );
    }
  }

  Widget _buildEmptyState() {
    return const AppEmptyState(
      illustration: AppEmptyPlanetIllustration(size: 84),
      title: '暂无阅读记录',
      message: '清空后或尚未阅读时会显示在这里',
    );
  }

  Widget _buildRecordList() {
    final tokens = AppUiTokens.resolve(context);
    return ListView.separated(
      padding: const EdgeInsets.only(top: 12, bottom: 24),
      itemCount: _records.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final record = _records[index];
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: AppCard(
            padding: const EdgeInsets.all(12),
            borderColor: tokens.colors.separator.withValues(alpha: 0.72),
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
                  style: TextStyle(
                    fontSize: 12,
                    color: tokens.colors.secondaryLabel,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppCupertinoPageScaffold(
      title: '阅读记录',
      trailing: AppNavBarButton(
        onPressed: _clearAllRecords,
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
