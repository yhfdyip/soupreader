import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../../../core/database/database_service.dart';
import '../../../core/database/repositories/source_repository.dart';
import '../models/book_source.dart';
import '../services/rule_parser_engine.dart';
import '../services/source_availability_diagnosis_service.dart';
import '../services/source_debug_export_service.dart';
import 'source_debug_text_view.dart';
import 'source_edit_view.dart';

enum _CheckStatus {
  pending,
  running,
  ok,
  empty,
  fail,
  skipped,
}

class _CheckItem {
  BookSource source;
  _CheckStatus status = _CheckStatus.pending;
  String? message;
  String? requestUrl;
  int elapsedMs = 0;
  int listCount = 0;
  String? debugKey;
  DiagnosisSummary diagnosis = DiagnosisSummary.noData;

  _CheckItem({required this.source});
}

enum _ResultFilter {
  all,
  available,
  failed,
  empty,
  timeout,
  skipped,
}

class SourceAvailabilityCheckView extends StatefulWidget {
  final bool includeDisabled;

  const SourceAvailabilityCheckView({
    super.key,
    this.includeDisabled = false,
  });

  @override
  State<SourceAvailabilityCheckView> createState() =>
      _SourceAvailabilityCheckViewState();
}

class _SourceAvailabilityCheckViewState
    extends State<SourceAvailabilityCheckView> {
  final RuleParserEngine _engine = RuleParserEngine();
  final SourceAvailabilityDiagnosisService _diagnosisService =
      const SourceAvailabilityDiagnosisService();
  final SourceDebugExportService _exportService = SourceDebugExportService();
  late final DatabaseService _db;
  late final SourceRepository _repo;

  bool _running = false;
  bool _cancelRequested = false;
  final List<_CheckItem> _items = <_CheckItem>[];
  _ResultFilter _resultFilter = _ResultFilter.all;

  @override
  void initState() {
    super.initState();
    _db = DatabaseService();
    _repo = SourceRepository(_db);
    _resetItems();
    _start();
  }

  void _resetItems() {
    final sources = _repo.getAllSources()
      ..sort((a, b) {
        if (a.weight != b.weight) return b.weight.compareTo(a.weight);
        return a.bookSourceName.compareTo(b.bookSourceName);
      });
    _items
      ..clear()
      ..addAll(sources.map((s) => _CheckItem(source: s)));
  }

  Future<void> _start() async {
    if (_running) return;
    setState(() {
      _running = true;
      _cancelRequested = false;
      for (final item in _items) {
        item.status = _CheckStatus.pending;
        item.message = null;
        item.requestUrl = null;
        item.elapsedMs = 0;
        item.listCount = 0;
        item.debugKey = null;
        item.diagnosis = DiagnosisSummary.noData;
      }
    });

    for (final item in _items) {
      if (_cancelRequested) break;

      final source = item.source;
      if (!widget.includeDisabled && !source.enabled) {
        if (!mounted) return;
        setState(() {
          item.status = _CheckStatus.skipped;
          item.message = '已跳过（未启用）';
        });
        continue;
      }

      if (!mounted) return;
      setState(() {
        item.status = _CheckStatus.running;
        item.message = '检测中…';
      });

      try {
        final hasSearch =
            (source.searchUrl != null && source.searchUrl!.trim().isNotEmpty) &&
                source.ruleSearch != null;
        final hasExplore = (source.exploreUrl != null &&
                source.exploreUrl!.trim().isNotEmpty) &&
            source.ruleExplore != null;

        if (hasSearch) {
          final keyword =
              source.ruleSearch?.checkKeyWord?.trim().isNotEmpty == true
                  ? source.ruleSearch!.checkKeyWord!.trim()
                  : '我的';
          item.debugKey = keyword;
          final debug = await _engine.searchDebug(source, keyword);
          final ok = debug.fetch.body != null;
          final cnt = debug.listCount;
          if (!mounted) return;
          setState(() {
            item.elapsedMs = debug.fetch.elapsedMs;
            item.requestUrl = debug.fetch.finalUrl ?? debug.fetch.requestUrl;
            item.listCount = cnt;
            item.diagnosis = _diagnosisService.diagnoseSearch(
              debug: debug,
              keyword: keyword,
            );
            if (!ok) {
              item.status = _CheckStatus.fail;
              item.message = debug.error ?? debug.fetch.error ?? '请求失败';
            } else if (cnt <= 0) {
              item.status = _CheckStatus.empty;
              item.message =
                  '请求成功，但列表为空（${keyword.isEmpty ? '无关键字' : '关键字: $keyword'}）';
            } else {
              item.status = _CheckStatus.ok;
              item.message = '可用（列表 $cnt）';
            }
          });
          continue;
        }

        if (hasExplore) {
          final url = source.exploreUrl!.trim();
          item.debugKey = '发现::$url';
          final debug = await _engine.exploreDebug(source);
          final ok = debug.fetch.body != null;
          final cnt = debug.listCount;
          if (!mounted) return;
          setState(() {
            item.elapsedMs = debug.fetch.elapsedMs;
            item.requestUrl = debug.fetch.finalUrl ?? debug.fetch.requestUrl;
            item.listCount = cnt;
            item.diagnosis = _diagnosisService.diagnoseExplore(debug: debug);
            if (!ok) {
              item.status = _CheckStatus.fail;
              item.message = debug.error ?? debug.fetch.error ?? '请求失败';
            } else if (cnt <= 0) {
              item.status = _CheckStatus.empty;
              item.message = '请求成功，但列表为空';
            } else {
              item.status = _CheckStatus.ok;
              item.message = '可用（列表 $cnt）';
            }
          });
          continue;
        }

        if (!mounted) return;
        setState(() {
          item.status = _CheckStatus.fail;
          item.message =
              '缺少 searchUrl/ruleSearch 或 exploreUrl/ruleExplore，无法检测';
          item.diagnosis = _diagnosisService.diagnoseMissingRule();
        });
      } catch (e) {
        if (!mounted) return;
        setState(() {
          item.status = _CheckStatus.fail;
          item.message = '异常：$e';
          item.diagnosis = _diagnosisService.diagnoseException(e);
        });
      }
    }

    if (!mounted) return;
    setState(() => _running = false);
  }

  void _stop() {
    setState(() {
      _cancelRequested = true;
      _running = false;
    });
  }

  Color _statusColor(_CheckStatus status) {
    switch (status) {
      case _CheckStatus.ok:
        return CupertinoColors.systemGreen.resolveFrom(context);
      case _CheckStatus.empty:
        return CupertinoColors.systemOrange.resolveFrom(context);
      case _CheckStatus.fail:
        return CupertinoColors.systemRed.resolveFrom(context);
      case _CheckStatus.running:
        return CupertinoColors.activeBlue.resolveFrom(context);
      case _CheckStatus.skipped:
        return CupertinoColors.systemGrey.resolveFrom(context);
      case _CheckStatus.pending:
        return CupertinoColors.secondaryLabel.resolveFrom(context);
    }
  }

  String _statusText(_CheckStatus status) {
    switch (status) {
      case _CheckStatus.pending:
        return '待检测';
      case _CheckStatus.running:
        return '检测中';
      case _CheckStatus.ok:
        return '可用';
      case _CheckStatus.empty:
        return '空列表';
      case _CheckStatus.fail:
        return '失败';
      case _CheckStatus.skipped:
        return '跳过';
    }
  }

  bool _isTimeoutMessage(String? message) {
    final text = (message ?? '').trim().toLowerCase();
    if (text.isEmpty) return false;
    return text.contains('timeout') ||
        text.contains('time out') ||
        text.contains('timed out') ||
        text.contains('连接超时') ||
        text.contains('请求超时') ||
        text.contains('超时');
  }

  bool _matchesFilter(_CheckItem item, _ResultFilter filter) {
    switch (filter) {
      case _ResultFilter.all:
        return true;
      case _ResultFilter.available:
        return item.status == _CheckStatus.ok;
      case _ResultFilter.failed:
        return item.status == _CheckStatus.fail;
      case _ResultFilter.empty:
        return item.status == _CheckStatus.empty;
      case _ResultFilter.timeout:
        return item.status == _CheckStatus.fail &&
            _isTimeoutMessage(item.message);
      case _ResultFilter.skipped:
        return item.status == _CheckStatus.skipped;
    }
  }

  String _filterLabel(_ResultFilter filter) {
    switch (filter) {
      case _ResultFilter.all:
        return '全部';
      case _ResultFilter.available:
        return '可用';
      case _ResultFilter.failed:
        return '失败';
      case _ResultFilter.empty:
        return '空列表';
      case _ResultFilter.timeout:
        return '超时';
      case _ResultFilter.skipped:
        return '跳过';
    }
  }

  int _countByFilter(_ResultFilter filter) {
    return _items.where((e) => _matchesFilter(e, filter)).length;
  }

  String _diagnosisLabelText(String code) {
    switch (code) {
      case 'request_failure':
        return '请求失败';
      case 'parse_failure':
        return '解析失败';
      case 'paging_interrupted':
        return '分页中断';
      case 'ok':
        return '基本正常';
      case 'no_data':
        return '无数据';
      default:
        return code;
    }
  }

  Color _diagnosisLabelColor(String code) {
    switch (code) {
      case 'request_failure':
      case 'parse_failure':
      case 'paging_interrupted':
        return CupertinoColors.systemRed.resolveFrom(context);
      case 'ok':
        return CupertinoColors.systemGreen.resolveFrom(context);
      default:
        return CupertinoColors.systemGrey.resolveFrom(context);
    }
  }

  String _buildReportText({required bool onlyVisible}) {
    final now = DateTime.now().toIso8601String();
    final pool = onlyVisible
        ? _items.where((e) => _matchesFilter(e, _resultFilter)).toList()
        : _items;

    final lines = <String>[
      'SoupReader 书源可用性检测报告',
      '生成时间：$now',
      '范围：${widget.includeDisabled ? '全部书源' : '仅启用书源'}',
      '筛选：${_filterLabel(_resultFilter)}',
      '总计：${pool.length}',
      '可用：${pool.where((e) => e.status == _CheckStatus.ok).length}',
      '失败：${pool.where((e) => e.status == _CheckStatus.fail).length}',
      '空列表：${pool.where((e) => e.status == _CheckStatus.empty).length}',
      '跳过：${pool.where((e) => e.status == _CheckStatus.skipped).length}',
      '',
    ];

    for (final item in pool) {
      final s = item.source;
      lines.add([
        _statusText(item.status),
        s.bookSourceName,
        s.bookSourceUrl,
        if (item.elapsedMs > 0) '${item.elapsedMs}ms',
        if (item.listCount > 0) 'list=${item.listCount}',
        if (item.diagnosis.labels.isNotEmpty)
          'diag=${item.diagnosis.labels.map(_diagnosisLabelText).join(',')}',
        if (item.message != null && item.message!.trim().isNotEmpty)
          item.message!.trim(),
      ].join(' | '));
    }

    return lines.join('\n');
  }

  Future<void> _copyReport() async {
    final text = _buildReportText(onlyVisible: true);
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    await showCupertinoDialog<void>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: const Text('提示'),
        content: const Text('\n已复制检测报告'),
        actions: [
          CupertinoDialogAction(
            child: const Text('好'),
            onPressed: () => Navigator.pop(dialogContext),
          ),
        ],
      ),
    );
  }

  Future<void> _exportReportToFile() async {
    final text = _buildReportText(onlyVisible: true);
    final ts = DateTime.now().millisecondsSinceEpoch;
    final fileName = 'source_availability_report_$ts.txt';
    final ok = await _exportService.exportTextToFile(
      text: text,
      fileName: fileName,
      dialogTitle: '导出检测报告',
    );
    if (!mounted) return;
    await showCupertinoDialog<void>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: const Text('提示'),
        content: Text(ok ? '\n已导出：$fileName' : '\n导出取消或失败'),
        actions: [
          CupertinoDialogAction(
            child: const Text('好'),
            onPressed: () => Navigator.pop(dialogContext),
          ),
        ],
      ),
    );
  }

  Future<void> _disableUnavailableSources() async {
    if (_running) {
      await showCupertinoDialog<void>(
        context: context,
        builder: (dialogContext) => CupertinoAlertDialog(
          title: const Text('提示'),
          content: const Text('\n检测进行中，请先停止检测再执行此操作。'),
          actions: [
            CupertinoDialogAction(
              child: const Text('好'),
              onPressed: () => Navigator.pop(dialogContext),
            ),
          ],
        ),
      );
      return;
    }

    final targets = _items
        .where((item) =>
            item.source.enabled &&
            (item.status == _CheckStatus.fail ||
                item.status == _CheckStatus.empty))
        .toList(growable: false);
    if (targets.isEmpty) {
      await showCupertinoDialog<void>(
        context: context,
        builder: (dialogContext) => CupertinoAlertDialog(
          title: const Text('提示'),
          content: const Text('\n没有可禁用的失效书源（仅处理失败/空列表且当前启用）。'),
          actions: [
            CupertinoDialogAction(
              child: const Text('好'),
              onPressed: () => Navigator.pop(dialogContext),
            ),
          ],
        ),
      );
      return;
    }

    final confirmed = await showCupertinoDialog<bool>(
          context: context,
          builder: (dialogContext) => CupertinoAlertDialog(
            title: const Text('一键禁用失效源'),
            content: Text('\n将禁用 ${targets.length} 条书源（失败/空列表）。此操作可在书源列表手动恢复。'),
            actions: [
              CupertinoDialogAction(
                isDestructiveAction: true,
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('确认禁用'),
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

    for (final item in targets) {
      final updated = item.source.copyWith(enabled: false);
      await _repo.updateSource(updated);
      item.source = updated;
      item.message = '${item.message ?? '已检测'}；已自动禁用';
    }

    if (!mounted) return;
    setState(() {});
    await showCupertinoDialog<void>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: const Text('完成'),
        content: Text('\n已禁用 ${targets.length} 条失效书源。'),
        actions: [
          CupertinoDialogAction(
            child: const Text('好'),
            onPressed: () => Navigator.pop(dialogContext),
          ),
        ],
      ),
    );
  }

  Future<void> _openItemDetails(_CheckItem item) async {
    final s = item.source;
    final details = <String>[
      '名称：${s.bookSourceName}',
      '地址：${s.bookSourceUrl}',
      '启用：${s.enabled}',
      if (item.debugKey != null) '调试 key：${item.debugKey}',
      if (item.requestUrl != null) '请求：${item.requestUrl}',
      '耗时：${item.elapsedMs}ms',
      '列表：${item.listCount}',
      if (item.diagnosis.labels.isNotEmpty)
        '诊断：${item.diagnosis.labels.map(_diagnosisLabelText).join(' / ')}',
      if (item.diagnosis.hints.isNotEmpty) '建议：${item.diagnosis.hints.join('；')}',
      if (item.message != null) '信息：${item.message}',
    ].join('\n');
    await Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (_) => SourceDebugTextView(title: '检测详情', text: details),
      ),
    );
  }

  Future<void> _openEditorAtDebug(_CheckItem item) async {
    final entity = _db.sourcesBox.get(item.source.bookSourceUrl);
    if (entity == null) {
      await showCupertinoDialog<void>(
        context: context,
        builder: (dialogContext) => CupertinoAlertDialog(
          title: const Text('提示'),
          content: const Text('\n书源不存在或已被删除'),
          actions: [
            CupertinoDialogAction(
              child: const Text('好'),
              onPressed: () => Navigator.pop(dialogContext),
            ),
          ],
        ),
      );
      return;
    }
    await Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (_) => SourceEditView.fromEntity(
          entity,
          initialTab: 3,
          initialDebugKey: item.debugKey,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final total = _items.length;
    final done = _items
        .where((e) =>
            e.status != _CheckStatus.pending &&
            e.status != _CheckStatus.running)
        .length;
    final ok = _items.where((e) => e.status == _CheckStatus.ok).length;
    final fail = _items.where((e) => e.status == _CheckStatus.fail).length;
    final empty = _items.where((e) => e.status == _CheckStatus.empty).length;
    final timedOut = _items
        .where((e) =>
            e.status == _CheckStatus.fail && _isTimeoutMessage(e.message))
        .length;
    final skipped =
        _items.where((e) => e.status == _CheckStatus.skipped).length;

    final visibleItems = _items
        .where((e) => _matchesFilter(e, _resultFilter))
        .toList(growable: false);

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('书源可用性检测'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: _copyReport,
              child: const Text('复制'),
            ),
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: _exportReportToFile,
              child: const Text('导出'),
            ),
          ],
        ),
      ),
      child: SafeArea(
        child: ListView(
          children: [
            CupertinoListSection.insetGrouped(
              header: const Text('概览'),
              children: [
                CupertinoListTile.notched(
                  title: const Text('进度'),
                  additionalInfo: Text('$done / $total'),
                ),
                CupertinoListTile.notched(
                  title: const Text('结果'),
                  additionalInfo: Text(
                      '可用 $ok / 失败 $fail / 空 $empty / 超时 $timedOut / 跳过 $skipped'),
                ),
                CupertinoListTile.notched(
                  title: const Text('结果筛选'),
                  subtitle: CupertinoSlidingSegmentedControl<_ResultFilter>(
                    groupValue: _resultFilter,
                    children: {
                      for (final f in _ResultFilter.values)
                        f: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child:
                              Text('${_filterLabel(f)}(${_countByFilter(f)})'),
                        ),
                    },
                    onValueChanged: (v) {
                      if (v == null) return;
                      setState(() => _resultFilter = v);
                    },
                  ),
                ),
                CupertinoListTile.notched(
                  title: const Text('一键禁用失效源'),
                  subtitle: const Text('禁用状态为“失败/空列表”的已启用书源'),
                  trailing: const CupertinoListTileChevron(),
                  onTap: _disableUnavailableSources,
                ),
                CupertinoListTile.notched(
                  title: Text(_running ? '停止检测' : '重新检测'),
                  trailing: const CupertinoListTileChevron(),
                  onTap: _running ? _stop : _start,
                ),
              ],
            ),
            CupertinoListSection.insetGrouped(
              header: Text('列表（显示 ${visibleItems.length} / 总计 $total）'),
              children: visibleItems.map((item) {
                final statusText = _statusText(item.status);
                final color = _statusColor(item.status);
                return GestureDetector(
                  onLongPress: () => _openEditorAtDebug(item),
                  child: CupertinoListTile.notched(
                    title: Text(item.source.bookSourceName),
                    subtitle: Text(item.source.bookSourceUrl),
                    additionalInfo: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          statusText,
                          style: TextStyle(color: color),
                        ),
                        const SizedBox(height: 2),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: _diagnosisLabelColor(item.diagnosis.primary)
                                .withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color:
                                  _diagnosisLabelColor(item.diagnosis.primary)
                                      .withValues(alpha: 0.35),
                            ),
                          ),
                          child: Text(
                            _diagnosisLabelText(item.diagnosis.primary),
                            style: TextStyle(
                              fontSize: 11,
                              color: _diagnosisLabelColor(
                                item.diagnosis.primary,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    trailing: const CupertinoListTileChevron(),
                    onTap: () => _openItemDetails(item),
                  ),
                );
              }).toList(),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Text(
                '提示：长按某条书源可直接打开编辑器并跳到调试 Tab。',
                style: TextStyle(fontSize: 12.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
