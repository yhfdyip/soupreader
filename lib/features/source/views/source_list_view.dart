import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../../core/database/database_service.dart';
import '../../../core/database/entities/book_entity.dart';
import '../../../core/database/repositories/source_repository.dart';
import '../models/book_source.dart';
import '../services/source_filter_helper.dart';
import '../services/source_import_export_service.dart';
import '../../../core/utils/legado_json.dart';
import 'source_edit_view.dart';
import 'source_availability_check_view.dart';

enum _ImportConflictAction {
  overwriteExisting,
  skipExisting,
  cancel,
}

/// 书源管理页面 - 纯 iOS 原生风格
class SourceListView extends StatefulWidget {
  const SourceListView({super.key});

  @override
  State<SourceListView> createState() => _SourceListViewState();
}

class _SourceListViewState extends State<SourceListView> {
  String _selectedGroup = '全部';
  SourceEnabledFilter _enabledFilter = SourceEnabledFilter.all;
  late final SourceRepository _sourceRepo;
  late final DatabaseService _db;
  final SourceImportExportService _importExportService =
      SourceImportExportService();
  final TextEditingController _urlController = TextEditingController();

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
            final filteredByGroup = _filterSources(sources, activeGroup);
            final filteredSources = SourceFilterHelper.filterByEnabled(
              filteredByGroup,
              _enabledFilter,
            );

            return Column(
              children: [
                _buildGroupFilter(groups, activeGroup),
                _buildEnabledFilter(),
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
    return SourceFilterHelper.buildGroups(sources);
  }

  List<BookSource> _filterSources(
    List<BookSource> sources,
    String activeGroup,
  ) {
    return SourceFilterHelper.filterByGroup(sources, activeGroup);
  }

  Widget _buildEnabledFilter() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: CupertinoSlidingSegmentedControl<SourceEnabledFilter>(
        groupValue: _enabledFilter,
        children: const {
          SourceEnabledFilter.all: Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: Text('全部状态'),
          ),
          SourceEnabledFilter.enabled: Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: Text('仅启用'),
          ),
          SourceEnabledFilter.disabled: Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: Text('仅失效'),
          ),
        },
        onValueChanged: (value) {
          if (value == null) return;
          setState(() => _enabledFilter = value);
        },
      ),
    );
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
        message: const Text('推荐优先：剪贴板导入（最快）\n若来源是链接，可用网络导入；Web 端可能受跨域限制。'),
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
            child: const Text('批量启用当前筛选'),
            onPressed: () {
              Navigator.pop(context);
              _bulkUpdateEnabledForFiltered(true);
            },
          ),
          CupertinoActionSheetAction(
            child: const Text('批量禁用当前筛选'),
            onPressed: () {
              Navigator.pop(context);
              _bulkUpdateEnabledForFiltered(false);
            },
          ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            child: const Text('删除失效书源'),
            onPressed: () {
              Navigator.pop(context);
              _confirmDeleteDisabledSources();
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

  Future<void> _bulkUpdateEnabledForFiltered(bool enabled) async {
    final all = _sourceRepo.getAllSources();
    final groups = _buildGroups(all);
    final activeGroup = groups.contains(_selectedGroup) ? _selectedGroup : '全部';
    final groupFiltered = _filterSources(all, activeGroup);
    final filtered =
        SourceFilterHelper.filterByEnabled(groupFiltered, _enabledFilter);

    if (filtered.isEmpty) {
      _showMessage('当前筛选结果为空，无可批量处理项');
      return;
    }

    final targets =
        filtered.where((s) => s.enabled != enabled).toList(growable: false);
    if (targets.isEmpty) {
      _showMessage(enabled ? '当前筛选内已全部启用' : '当前筛选内已全部禁用');
      return;
    }

    for (final source in targets) {
      await _sourceRepo.updateSource(source.copyWith(enabled: enabled));
    }

    _showMessage('${enabled ? '已启用' : '已禁用'} ${targets.length} 条书源');
  }

  Future<void> _confirmDeleteDisabledSources() async {
    final count = _sourceRepo.getAllSources().where((s) => !s.enabled).length;
    if (count <= 0) {
      _showMessage('当前没有失效书源可删除');
      return;
    }

    final confirmed = await showCupertinoDialog<bool>(
          context: context,
          builder: (dialogContext) => CupertinoAlertDialog(
            title: const Text('删除失效书源'),
            content: Text('\n将删除 $count 条已禁用书源，此操作不可撤销。'),
            actions: [
              CupertinoDialogAction(
                isDestructiveAction: true,
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('确认删除'),
              ),
              CupertinoDialogAction(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('取消'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;

    await _sourceRepo.deleteDisabledSources();
    _showMessage('已删除 $count 条失效书源');
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
    await _commitImportResult(result);
  }

  Future<void> _importFromClipboard() async {
    final data = await Clipboard.getData('text/plain');
    final text = data?.text?.trim();
    if (text == null || text.isEmpty) {
      _showMessage('剪贴板为空');
      return;
    }
    final result = _importExportService.importFromJson(text);
    await _commitImportResult(result);
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
            placeholder: '输入书源链接（http/https）',
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
      if (!url.startsWith('http://') && !url.startsWith('https://')) {
        _showMessage('链接格式无效，请输入 http:// 或 https:// 开头的地址');
        return;
      }
      final result = await _importExportService.importFromUrl(url);
      await _commitImportResult(result);
    });
  }

  Future<void> _commitImportResult(SourceImportResult result) async {
    if (!result.success) {
      if (result.cancelled) return;
      _showImportError(result);
      return;
    }

    final prepared = await _prepareImportSources(result.sources);
    if (prepared == null) return;

    final finalSources = prepared.finalSources;
    if (finalSources.isEmpty) {
      _showMessage('没有可导入的书源（可能都已存在）');
      return;
    }

    await _persistImportedSources(result, finalSources);
    _showImportSummary(
      result,
      actualImportedCount: finalSources.length,
      conflictCount: prepared.conflictCount,
      skippedConflictCount: prepared.skippedConflictCount,
    );
  }

  Future<void> _persistImportedSources(
    SourceImportResult result,
    List<BookSource> finalSources,
  ) async {
    for (final source in finalSources) {
      final url = source.bookSourceUrl.trim();
      if (url.isEmpty) continue;

      final rawJson = result.rawJsonForSourceUrl(url);
      if (rawJson != null && rawJson.trim().isNotEmpty) {
        await _sourceRepo.upsertSourceRawJson(rawJson: rawJson);
      } else {
        await _sourceRepo.addSource(source);
      }
    }
  }

  Future<
      ({
        List<BookSource> finalSources,
        int conflictCount,
        int skippedConflictCount,
      })?> _prepareImportSources(List<BookSource> incoming) async {
    if (incoming.isEmpty) {
      return (
        finalSources: const <BookSource>[],
        conflictCount: 0,
        skippedConflictCount: 0,
      );
    }

    final conflictUrls = <String>{};
    final conflictPreview = <BookSource>[];

    for (final source in incoming) {
      final url = source.bookSourceUrl.trim();
      if (url.isEmpty) continue;
      if (_sourceRepo.getSourceByUrl(url) == null) continue;
      if (conflictUrls.add(url) && conflictPreview.length < 5) {
        conflictPreview.add(source);
      }
    }

    final conflictCount = conflictUrls.length;
    if (conflictCount == 0) {
      return (
        finalSources: incoming,
        conflictCount: 0,
        skippedConflictCount: 0,
      );
    }

    final action = await _showImportConflictDialog(
      conflictCount: conflictCount,
      preview: conflictPreview,
    );
    if (action == null || action == _ImportConflictAction.cancel) {
      _showMessage('已取消导入');
      return null;
    }

    if (action == _ImportConflictAction.skipExisting) {
      final filtered = incoming
          .where((s) => !conflictUrls.contains(s.bookSourceUrl.trim()))
          .toList(growable: false);
      return (
        finalSources: filtered,
        conflictCount: conflictCount,
        skippedConflictCount: conflictCount,
      );
    }

    return (
      finalSources: incoming,
      conflictCount: conflictCount,
      skippedConflictCount: 0,
    );
  }

  Future<_ImportConflictAction?> _showImportConflictDialog({
    required int conflictCount,
    required List<BookSource> preview,
  }) {
    final lines = <String>['检测到 $conflictCount 条书源 URL 与现有书源重复。'];
    if (preview.isNotEmpty) {
      lines.add('示例：');
      lines.addAll(preview.map((s) {
        final name = s.bookSourceName.trim();
        final url = s.bookSourceUrl.trim();
        return '• ${name.isEmpty ? '(未命名)' : name}（$url）';
      }));
      final more = conflictCount - preview.length;
      if (more > 0) lines.add('…其余 $more 条省略');
    }
    lines.add('请选择处理方式：');

    return showCupertinoDialog<_ImportConflictAction>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('导入冲突处理'),
        content: Text('\n${lines.join('\n')}'),
        actions: [
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () =>
                Navigator.pop(context, _ImportConflictAction.overwriteExisting),
            child: const Text('覆盖重复（推荐）'),
          ),
          CupertinoDialogAction(
            onPressed: () =>
                Navigator.pop(context, _ImportConflictAction.skipExisting),
            child: const Text('跳过重复（保留现有）'),
          ),
          CupertinoDialogAction(
            onPressed: () =>
                Navigator.pop(context, _ImportConflictAction.cancel),
            child: const Text('取消导入'),
          ),
        ],
      ),
    );
  }

  void _showImportError(SourceImportResult result) {
    final lines = <String>[];
    lines.add(result.errorMessage ?? '导入失败');
    if (result.totalInputCount > 0) {
      lines.add('输入条数：${result.totalInputCount}');
      if (result.invalidCount > 0) lines.add('无效条数：${result.invalidCount}');
      if (result.duplicateCount > 0) {
        lines.add('重复URL：${result.duplicateCount}（已按后出现项覆盖）');
      }
    }
    if (kIsWeb && (result.errorMessage ?? '').contains('跨域限制')) {
      lines.add('建议：改用“从剪贴板导入”或“从文件导入”');
    }
    if (result.warnings.isNotEmpty) {
      lines.add('详情：');
      lines.addAll(result.warnings.take(5));
      final more = result.warnings.length - 5;
      if (more > 0) lines.add('…其余 $more 条省略');
    }
    _showMessage(lines.join('\n'));
  }

  void _showImportSummary(
    SourceImportResult result, {
    required int actualImportedCount,
    int conflictCount = 0,
    int skippedConflictCount = 0,
  }) {
    final lines = <String>['成功导入 $actualImportedCount 条书源'];
    if (result.totalInputCount > 0) {
      lines.add('输入条数：${result.totalInputCount}');
      if (result.invalidCount > 0) lines.add('跳过无效：${result.invalidCount}');
      if (result.duplicateCount > 0) {
        lines.add('覆盖重复URL：${result.duplicateCount}');
      }
    }
    if (conflictCount > 0) {
      lines.add('与现有书源重复：$conflictCount');
      if (skippedConflictCount > 0) {
        lines.add('按你的选择跳过：$skippedConflictCount');
      }
    }
    if (result.warnings.isNotEmpty) {
      lines.add('说明：');
      lines.addAll(result.warnings.take(5));
      final more = result.warnings.length - 5;
      if (more > 0) lines.add('…其余 $more 条省略');
    }
    _showMessage(lines.join('\n'));
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
