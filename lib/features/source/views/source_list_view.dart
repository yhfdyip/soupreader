import 'package:flutter/cupertino.dart';
import '../models/book_source.dart';

/// 书源管理页面 - 纯 iOS 原生风格
class SourceListView extends StatefulWidget {
  const SourceListView({super.key});

  @override
  State<SourceListView> createState() => _SourceListViewState();
}

class _SourceListViewState extends State<SourceListView> {
  String _selectedGroup = '全部';
  final List<String> _groups = ['全部', '小说', '漫画', '有声', '失效'];

  final List<BookSource> _sources = [
    BookSource(
      bookSourceUrl: 'https://www.example1.com',
      bookSourceName: '笔趣阁',
      bookSourceGroup: '小说',
      enabled: true,
    ),
    BookSource(
      bookSourceUrl: 'https://www.example2.com',
      bookSourceName: '起点中文网',
      bookSourceGroup: '小说',
      enabled: true,
    ),
    BookSource(
      bookSourceUrl: 'https://www.example3.com',
      bookSourceName: '番茄小说',
      bookSourceGroup: '小说',
      enabled: false,
    ),
    BookSource(
      bookSourceUrl: 'https://www.example4.com',
      bookSourceName: '喜马拉雅',
      bookSourceGroup: '有声',
      enabled: true,
    ),
  ];

  List<BookSource> get _filteredSources {
    if (_selectedGroup == '全部') return _sources;
    if (_selectedGroup == '失效') {
      return _sources.where((s) => !s.enabled).toList();
    }
    return _sources.where((s) => s.bookSourceGroup == _selectedGroup).toList();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('书源'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: _showImportOptions,
              child: const Icon(CupertinoIcons.add),
            ),
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: _showMoreOptions,
              child: const Icon(CupertinoIcons.ellipsis_vertical),
            ),
          ],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // 分组筛选
            _buildGroupFilter(),
            // 书源列表
            Expanded(
              child: _filteredSources.isEmpty
                  ? _buildEmptyState()
                  : _buildSourceList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupFilter() {
    return Container(
      height: 44,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _groups.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final group = _groups[index];
          final isSelected = group == _selectedGroup;
          return GestureDetector(
            onTap: () => setState(() => _selectedGroup = group),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: isSelected
                    ? CupertinoTheme.of(context).primaryColor
                    : CupertinoColors.systemGrey5.resolveFrom(context),
                borderRadius: BorderRadius.circular(22),
              ),
              alignment: Alignment.center,
              child: Text(
                group,
                style: TextStyle(
                  color: isSelected
                      ? CupertinoColors.white
                      : CupertinoColors.label.resolveFrom(context),
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            CupertinoIcons.cloud,
            size: 64,
            color: CupertinoColors.secondaryLabel.resolveFrom(context),
          ),
          const SizedBox(height: 16),
          Text(
            '暂无书源',
            style: TextStyle(
              fontSize: 17,
              color: CupertinoColors.secondaryLabel.resolveFrom(context),
            ),
          ),
          const SizedBox(height: 16),
          CupertinoButton.filled(
            onPressed: _showImportOptions,
            child: const Text('导入书源'),
          ),
        ],
      ),
    );
  }

  Widget _buildSourceList() {
    return ListView.builder(
      itemCount: _filteredSources.length,
      itemBuilder: (context, index) {
        final source = _filteredSources[index];
        return CupertinoListTile(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: source.enabled
                  ? CupertinoTheme.of(context).primaryColor.withValues(alpha: 0.1)
                  : CupertinoColors.systemGrey5.resolveFrom(context),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              CupertinoIcons.globe,
              color: source.enabled
                  ? CupertinoTheme.of(context).primaryColor
                  : CupertinoColors.secondaryLabel.resolveFrom(context),
            ),
          ),
          title: Text(
            source.bookSourceName,
            style: TextStyle(
              color: source.enabled
                  ? CupertinoColors.label.resolveFrom(context)
                  : CupertinoColors.secondaryLabel.resolveFrom(context),
            ),
          ),
          subtitle: Text(source.bookSourceGroup ?? '未分组'),
          trailing: CupertinoSwitch(
            value: source.enabled,
            onChanged: (value) {
              setState(() {
                final i = _sources.indexOf(source);
                _sources[i] = source.copyWith(enabled: value);
              });
            },
          ),
          onTap: () => _onSourceTap(source),
        );
      },
    );
  }

  void _showImportOptions() {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('导入书源'),
        actions: [
          CupertinoActionSheetAction(
            child: const Text('从剪贴板导入'),
            onPressed: () => Navigator.pop(context),
          ),
          CupertinoActionSheetAction(
            child: const Text('从文件导入'),
            onPressed: () => Navigator.pop(context),
          ),
          CupertinoActionSheetAction(
            child: const Text('从网络导入'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          child: const Text('取消'),
          onPressed: () => Navigator.pop(context),
        ),
      ),
    );
  }

  void _showMoreOptions() {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        actions: [
          CupertinoActionSheetAction(
            child: const Text('全选'),
            onPressed: () => Navigator.pop(context),
          ),
          CupertinoActionSheetAction(
            child: const Text('导出书源'),
            onPressed: () => Navigator.pop(context),
          ),
          CupertinoActionSheetAction(
            child: const Text('检查可用性'),
            onPressed: () => Navigator.pop(context),
          ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            child: const Text('删除失效书源'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          child: const Text('取消'),
          onPressed: () => Navigator.pop(context),
        ),
      ),
    );
  }

  void _onSourceTap(BookSource source) {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: Text(source.bookSourceName),
        actions: [
          CupertinoActionSheetAction(
            child: const Text('编辑'),
            onPressed: () => Navigator.pop(context),
          ),
          CupertinoActionSheetAction(
            child: const Text('置顶'),
            onPressed: () => Navigator.pop(context),
          ),
          CupertinoActionSheetAction(
            child: const Text('分享'),
            onPressed: () => Navigator.pop(context),
          ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            child: const Text('删除'),
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _sources.removeWhere(
                    (s) => s.bookSourceUrl == source.bookSourceUrl);
              });
            },
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          child: const Text('取消'),
          onPressed: () => Navigator.pop(context),
        ),
      ),
    );
  }
}
