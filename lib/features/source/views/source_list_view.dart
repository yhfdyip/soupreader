import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../../core/database/database_service.dart';
import '../../../core/database/entities/book_entity.dart';
import '../../../core/database/repositories/source_repository.dart';
import '../models/book_source.dart';
import '../services/source_import_export_service.dart';
import '../../../core/utils/legado_json.dart';
import 'source_edit_view.dart';
import 'source_availability_check_view.dart';

/// 书源管理页面 - 纯 iOS 原生风格
class SourceListView extends StatefulWidget {
  const SourceListView({super.key});

  @override
  State<SourceListView> createState() => _SourceListViewState();
}

class _SourceListViewState extends State<SourceListView> {
  String _selectedGroup = '全部';
  late final SourceRepository _sourceRepo;
  late final DatabaseService _db;
  final SourceImportExportService _importExportService =
      SourceImportExportService();
  final TextEditingController _urlController = TextEditingController();

  static final RegExp _splitGroupRegex = RegExp(r'[,;，；]');

  @override
  void initState() {
    super.initState();
    _db = DatabaseService();
    _sourceRepo = SourceRepository(_db);
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('书源管理'),
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
              child: const Icon(CupertinoIcons.ellipsis),
            ),
          ],
        ),
      ),
      child: SafeArea(
        child: ValueListenableBuilder<Box<BookSourceEntity>>(
          valueListenable: _db.sourcesBox.listenable(),
          builder: (context, box, _) {
            final sources = _sourceRepo.fromEntities(box.values).toList()
              ..sort((a, b) {
                if (a.weight != b.weight) {
                  return b.weight.compareTo(a.weight);
                }
                return a.bookSourceName.compareTo(b.bookSourceName);
              });

            final groups = _buildGroups(sources);
            final activeGroup =
                groups.contains(_selectedGroup) ? _selectedGroup : '全部';
            final filteredSources = _filterSources(sources, activeGroup);

            return Column(
              children: [
                _buildGroupFilter(groups, activeGroup),
                Expanded(
                  child: filteredSources.isEmpty
                      ? _buildEmptyState()
                      : _buildSourceList(filteredSources),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  List<String> _buildGroups(List<BookSource> sources) {
    final groups = <String>{};
    for (final source in sources) {
      final raw = source.bookSourceGroup?.trim();
      if (raw == null || raw.isEmpty) continue;
      for (final g in raw.split(_splitGroupRegex)) {
        final group = g.trim();
        if (group.isNotEmpty) groups.add(group);
      }
    }
    return ['全部', ...groups.toList()..sort(), '失效'];
  }

  List<BookSource> _filterSources(
    List<BookSource> sources,
    String activeGroup,
  ) {
    if (activeGroup == '全部') return sources;
    if (activeGroup == '失效') {
      return sources.where((s) => !s.enabled).toList();
    }
    return sources.where((s) {
      final raw = s.bookSourceGroup;
      if (raw == null || raw.trim().isEmpty) return false;
      return raw
          .split(_splitGroupRegex)
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .contains(activeGroup);
    }).toList();
  }

  Widget _buildGroupFilter(List<String> groups, String activeGroup) {
    return Container(
      height: 44,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: groups.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final group = groups[index];
          final isSelected = group == activeGroup;
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

  Widget _buildSourceList(List<BookSource> sources) {
    return ListView.builder(
      itemCount: sources.length,
      itemBuilder: (context, index) {
        final source = sources[index];
        return CupertinoListTile.notched(
          title: Text(source.bookSourceName),
          subtitle: Text(source.bookSourceUrl),
          trailing: CupertinoSwitch(
            value: source.enabled,
            onChanged: (value) {
              _sourceRepo.updateSource(source.copyWith(enabled: value));
            },
          ),
          onTap: () => _onSourceTap(source),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            CupertinoIcons.cloud_download,
            size: 64,
            color: CupertinoColors.systemGrey,
          ),
          const SizedBox(height: 16),
          Text(
            '暂无书源',
            style: TextStyle(
              fontSize: 16,
              color: CupertinoColors.secondaryLabel.resolveFrom(context),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '点击右上角 + 导入书源',
            style: TextStyle(
              fontSize: 14,
              color: CupertinoColors.tertiaryLabel.resolveFrom(context),
            ),
          ),
        ],
      ),
    );
  }

  void _showImportOptions() {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('导入书源'),
        actions: [
          CupertinoActionSheetAction(
            child: const Text('新建书源'),
            onPressed: () {
              Navigator.pop(context);
              _createNewSource();
            },
          ),
          CupertinoActionSheetAction(
            child: const Text('从剪贴板导入'),
            onPressed: () {
              Navigator.pop(context);
              _importFromClipboard();
            },
          ),
          CupertinoActionSheetAction(
            child: const Text('从文件导入'),
            onPressed: () {
              Navigator.pop(context);
              _importFromFile();
            },
          ),
          CupertinoActionSheetAction(
            child: const Text('从网络导入'),
            onPressed: () {
              Navigator.pop(context);
              _importFromUrl();
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

  void _showMoreOptions() {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        actions: [
          CupertinoActionSheetAction(
            child: const Text('导出书源'),
            onPressed: () {
              Navigator.pop(context);
              _exportSources();
            },
          ),
          CupertinoActionSheetAction(
            child: const Text('检查可用性'),
            onPressed: () {
              Navigator.pop(context);
              _openAvailabilityCheck();
            },
          ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            child: const Text('删除失效书源'),
            onPressed: () {
              Navigator.pop(context);
              _sourceRepo.deleteDisabledSources();
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

  Future<void> _openAvailabilityCheck() async {
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('书源可用性检测'),
        message: const Text('建议先检测“启用的书源”，避免浪费时间。'),
        actions: [
          CupertinoActionSheetAction(
            child: const Text('检测启用的（推荐）'),
            onPressed: () async {
              Navigator.pop(context);
              await Navigator.of(context).push(
                CupertinoPageRoute<void>(
                  builder: (_) => const SourceAvailabilityCheckView(
                    includeDisabled: false,
                  ),
                ),
              );
            },
          ),
          CupertinoActionSheetAction(
            child: const Text('检测全部（含失效）'),
            onPressed: () async {
              Navigator.pop(context);
              await Navigator.of(context).push(
                CupertinoPageRoute<void>(
                  builder: (_) => const SourceAvailabilityCheckView(
                    includeDisabled: true,
                  ),
                ),
              );
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

  void _onSourceTap(BookSource source) {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: Text(source.bookSourceName),
        actions: [
          CupertinoActionSheetAction(
            child: const Text('编辑'),
            onPressed: () {
              Navigator.pop(context);
              _openEditor(source.bookSourceUrl);
            },
          ),
          CupertinoActionSheetAction(
            child: const Text('置顶'),
            onPressed: () {
              Navigator.pop(context);
              _sourceRepo.updateSource(source.copyWith(weight: 9999));
            },
          ),
          CupertinoActionSheetAction(
            child: const Text('分享'),
            onPressed: () {
              Navigator.pop(context);
              Clipboard.setData(
                ClipboardData(text: LegadoJson.encode(source.toJson())),
              );
              _showMessage('已复制书源 JSON');
            },
          ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            child: const Text('删除'),
            onPressed: () {
              Navigator.pop(context);
              _sourceRepo.deleteSource(source.bookSourceUrl);
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

  Future<void> _createNewSource() async {
    final template = {
      'bookSourceUrl': '',
      'bookSourceName': '',
      'bookSourceGroup': null,
      'bookSourceType': 0,
      'customOrder': 0,
      'enabled': true,
      'enabledExplore': true,
      'enabledCookieJar': true,
      'respondTime': 180000,
      'weight': 0,
      'searchUrl': null,
      'exploreUrl': null,
      'ruleSearch': null,
      'ruleBookInfo': null,
      'ruleToc': null,
      'ruleContent': null,
    };
    await Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (_) => SourceEditView(
          initialRawJson: LegadoJson.encode(template),
          originalUrl: null,
        ),
      ),
    );
  }

  Future<void> _openEditor(String bookSourceUrl) async {
    final entity = _db.sourcesBox.get(bookSourceUrl);
    if (entity == null) {
      _showMessage('书源不存在或已被删除');
      return;
    }
    await Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (_) => SourceEditView.fromEntity(entity),
      ),
    );
  }

  Future<void> _importFromFile() async {
    final result = await _importExportService.importFromFile();
    if (!result.success) {
      if (result.cancelled) return;
      _showMessage(result.errorMessage ?? '导入失败');
      return;
    }
    await _sourceRepo.addSources(result.sources);
    _showMessage('成功导入 ${result.importCount} 条书源');
  }

  Future<void> _importFromClipboard() async {
    final data = await Clipboard.getData('text/plain');
    final text = data?.text?.trim();
    if (text == null || text.isEmpty) {
      _showMessage('剪贴板为空');
      return;
    }
    final result = _importExportService.importFromJson(text);
    if (!result.success) {
      _showMessage(result.errorMessage ?? '导入失败');
      return;
    }
    await _sourceRepo.addSources(result.sources);
    _showMessage('成功导入 ${result.importCount} 条书源');
  }

  Future<void> _importFromUrl() async {
    _urlController.clear();
    await showCupertinoDialog<String>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('从网络导入'),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: CupertinoTextField(
            controller: _urlController,
            placeholder: '输入书源链接',
          ),
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('取消'),
            onPressed: () => Navigator.pop(context),
          ),
          CupertinoDialogAction(
            child: const Text('导入'),
            onPressed: () => Navigator.pop(context, _urlController.text),
          ),
        ],
      ),
    ).then((value) async {
      final url = value?.trim();
      if (url == null || url.isEmpty) return;
      final result = await _importExportService.importFromUrl(url);
      if (!result.success) {
        _showMessage(result.errorMessage ?? '导入失败');
        return;
      }
      await _sourceRepo.addSources(result.sources);
      _showMessage('成功导入 ${result.importCount} 条书源');
    });
  }

  Future<void> _exportSources() async {
    final sources = _sourceRepo.getAllSources();
    if (sources.isEmpty) {
      _showMessage('暂无可导出的书源');
      return;
    }
    final success = await _importExportService.exportToFile(sources);
    _showMessage(success ? '导出成功' : '导出取消');
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
}
