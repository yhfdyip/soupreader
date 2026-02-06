import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../../../core/database/database_service.dart';
import '../../../core/database/repositories/source_repository.dart';
import '../models/book_source.dart';
import '../services/rule_parser_engine.dart';
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
  final BookSource source;
  _CheckStatus status = _CheckStatus.pending;
  String? message;
  String? requestUrl;
  int elapsedMs = 0;
  int listCount = 0;
  String? debugKey;

  _CheckItem({required this.source});
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

class _SourceAvailabilityCheckViewState extends State<SourceAvailabilityCheckView> {
  final RuleParserEngine _engine = RuleParserEngine();
  late final DatabaseService _db;
  late final SourceRepository _repo;

  bool _running = false;
  bool _cancelRequested = false;
  final List<_CheckItem> _items = <_CheckItem>[];

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
        final hasExplore =
            (source.exploreUrl != null && source.exploreUrl!.trim().isNotEmpty) &&
                source.ruleExplore != null;

        if (hasSearch) {
          final keyword = source.ruleSearch?.checkKeyWord?.trim().isNotEmpty == true
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
            if (!ok) {
              item.status = _CheckStatus.fail;
              item.message = debug.error ?? debug.fetch.error ?? '请求失败';
            } else if (cnt <= 0) {
              item.status = _CheckStatus.empty;
              item.message = '请求成功，但列表为空（${keyword.isEmpty ? '无关键字' : '关键字: $keyword'}）';
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
          item.message = '缺少 searchUrl/ruleSearch 或 exploreUrl/ruleExplore，无法检测';
        });
      } catch (e) {
        if (!mounted) return;
        setState(() {
          item.status = _CheckStatus.fail;
          item.message = '异常：$e';
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

  Future<void> _copyReport() async {
    final lines = <String>[];
    for (final item in _items) {
      final s = item.source;
      lines.add([
        _statusText(item.status),
        s.bookSourceName,
        s.bookSourceUrl,
        if (item.elapsedMs > 0) '${item.elapsedMs}ms',
        if (item.listCount > 0) 'list=${item.listCount}',
        if (item.message != null && item.message!.trim().isNotEmpty)
          item.message!.trim(),
      ].join(' | '));
    }
    await Clipboard.setData(ClipboardData(text: lines.join('\n')));
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
            e.status != _CheckStatus.pending && e.status != _CheckStatus.running)
        .length;
    final ok = _items.where((e) => e.status == _CheckStatus.ok).length;
    final fail = _items.where((e) => e.status == _CheckStatus.fail).length;
    final empty = _items.where((e) => e.status == _CheckStatus.empty).length;

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('书源可用性检测'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _copyReport,
          child: const Text('复制'),
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
                  additionalInfo: Text('可用 $ok / 失败 $fail / 空 $empty'),
                ),
                CupertinoListTile.notched(
                  title: Text(_running ? '停止检测' : '重新检测'),
                  trailing: const CupertinoListTileChevron(),
                  onTap: _running ? _stop : _start,
                ),
              ],
            ),
            CupertinoListSection.insetGrouped(
              header: const Text('列表'),
              children: _items.map((item) {
                final statusText = _statusText(item.status);
                final color = _statusColor(item.status);
                return GestureDetector(
                  onLongPress: () => _openEditorAtDebug(item),
                  child: CupertinoListTile.notched(
                    title: Text(item.source.bookSourceName),
                    subtitle: Text(item.source.bookSourceUrl),
                    additionalInfo: Text(
                      statusText,
                      style: TextStyle(color: color),
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
