import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/database/database_service.dart';
import '../../../core/database/repositories/source_repository.dart';
import '../models/book_source.dart';
import 'rule_parser_engine.dart';
import 'source_availability_diagnosis_service.dart';
import 'source_availability_summary_store.dart';

enum SourceCheckStatus {
  pending,
  running,
  ok,
  empty,
  fail,
  skipped,
}

class SourceCheckItem {
  BookSource source;
  SourceCheckStatus status;
  String? message;
  String? requestUrl;
  int elapsedMs;
  int listCount;
  String? debugKey;
  DiagnosisSummary diagnosis;

  SourceCheckItem({
    required this.source,
    this.status = SourceCheckStatus.pending,
    this.message,
    this.requestUrl,
    this.elapsedMs = 0,
    this.listCount = 0,
    this.debugKey,
    this.diagnosis = DiagnosisSummary.noData,
  });
}

class SourceCheckTaskConfig {
  final bool includeDisabled;
  final List<String>? sourceUrls;
  final String? keywordOverride;

  const SourceCheckTaskConfig({
    required this.includeDisabled,
    this.sourceUrls,
    this.keywordOverride,
  });

  Set<String> normalizedSourceUrls() {
    return (sourceUrls ?? const <String>[])
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet();
  }

  String normalizedKeyword() {
    return (keywordOverride ?? '').trim();
  }

  bool semanticallyEquals(SourceCheckTaskConfig other) {
    if (includeDisabled != other.includeDisabled) return false;
    if (normalizedKeyword() != other.normalizedKeyword()) return false;
    final a = normalizedSourceUrls();
    final b = other.normalizedSourceUrls();
    if (a.length != b.length) return false;
    for (final item in a) {
      if (!b.contains(item)) return false;
    }
    return true;
  }
}

class SourceCheckTaskSnapshot {
  final SourceCheckTaskConfig config;
  final bool running;
  final bool stopRequested;
  final DateTime startedAt;
  final DateTime? finishedAt;
  final List<SourceCheckItem> items;

  const SourceCheckTaskSnapshot({
    required this.config,
    required this.running,
    required this.stopRequested,
    required this.startedAt,
    required this.finishedAt,
    required this.items,
  });

  SourceCheckTaskSnapshot copyWith({
    SourceCheckTaskConfig? config,
    bool? running,
    bool? stopRequested,
    DateTime? startedAt,
    DateTime? finishedAt,
    List<SourceCheckItem>? items,
  }) {
    return SourceCheckTaskSnapshot(
      config: config ?? this.config,
      running: running ?? this.running,
      stopRequested: stopRequested ?? this.stopRequested,
      startedAt: startedAt ?? this.startedAt,
      finishedAt: finishedAt ?? this.finishedAt,
      items: items ?? this.items,
    );
  }
}

enum SourceCheckStartType {
  started,
  attachedExisting,
  runningOtherTask,
  emptySource,
}

class SourceCheckStartResult {
  final SourceCheckStartType type;
  final String message;

  const SourceCheckStartResult({
    required this.type,
    required this.message,
  });
}

/// 对标 legado CheckSourceService 的“任务化”语义：
/// - 检测任务脱离页面生命周期，页面退出后可继续运行；
/// - 再次进入检测页可恢复当前任务状态；
/// - 提供 start/stop 任务控制，并输出统一快照供 UI 订阅。
class SourceAvailabilityCheckTaskService {
  SourceAvailabilityCheckTaskService._();

  static final SourceAvailabilityCheckTaskService instance =
      SourceAvailabilityCheckTaskService._();

  final RuleParserEngine _engine = RuleParserEngine();
  final SourceAvailabilityDiagnosisService _diagnosisService =
      const SourceAvailabilityDiagnosisService();
  final SourceRepository _repo = SourceRepository(DatabaseService());

  final ValueNotifier<SourceCheckTaskSnapshot?> _notifier =
      ValueNotifier<SourceCheckTaskSnapshot?>(null);

  ValueListenable<SourceCheckTaskSnapshot?> get listenable => _notifier;

  SourceCheckTaskSnapshot? get snapshot => _notifier.value;

  bool get isRunning => snapshot?.running == true;

  Future<SourceCheckStartResult> start(
    SourceCheckTaskConfig config, {
    bool forceRestart = false,
  }) async {
    final current = snapshot;
    if (current != null && current.running) {
      if (current.config.semanticallyEquals(config)) {
        return const SourceCheckStartResult(
          type: SourceCheckStartType.attachedExisting,
          message: '已恢复正在进行的检测任务',
        );
      }
      return const SourceCheckStartResult(
        type: SourceCheckStartType.runningOtherTask,
        message: '已有检测任务在运行，请先停止后再发起新任务',
      );
    }

    if (!forceRestart &&
        current != null &&
        current.config.semanticallyEquals(config) &&
        current.items.isNotEmpty) {
      return const SourceCheckStartResult(
        type: SourceCheckStartType.attachedExisting,
        message: '已恢复最近一次检测结果',
      );
    }

    final items = _buildItems(config);
    if (items.isEmpty) {
      _notifier.value = SourceCheckTaskSnapshot(
        config: config,
        running: false,
        stopRequested: false,
        startedAt: DateTime.now(),
        finishedAt: DateTime.now(),
        items: const <SourceCheckItem>[],
      );
      return const SourceCheckStartResult(
        type: SourceCheckStartType.emptySource,
        message: '没有可检测书源',
      );
    }

    final now = DateTime.now();
    _notifier.value = SourceCheckTaskSnapshot(
      config: config,
      running: true,
      stopRequested: false,
      startedAt: now,
      finishedAt: null,
      items: items,
    );

    unawaited(_runCurrentTask());

    return const SourceCheckStartResult(
      type: SourceCheckStartType.started,
      message: '已开始检测任务',
    );
  }

  void requestStop() {
    final current = snapshot;
    if (current == null || !current.running || current.stopRequested) return;
    _notifier.value = current.copyWith(stopRequested: true);
  }

  void touch() {
    final current = snapshot;
    if (current == null) return;
    _notifier.value = current.copyWith();
  }

  Future<void> _runCurrentTask() async {
    final current = snapshot;
    if (current == null || !current.running) return;

    final config = current.config;
    final items = current.items;

    for (final item in items) {
      final latest = snapshot;
      if (latest == null || !latest.running || latest.stopRequested) break;

      final source = item.source;
      if (!config.includeDisabled && !source.enabled) {
        item.status = SourceCheckStatus.skipped;
        item.message = '已跳过（未启用）';
        touch();
        continue;
      }

      item.status = SourceCheckStatus.running;
      item.message = '检测中…';
      touch();

      try {
        final hasSearch =
            (source.searchUrl != null && source.searchUrl!.trim().isNotEmpty) &&
                source.ruleSearch != null;
        final hasExplore = (source.exploreUrl != null &&
                source.exploreUrl!.trim().isNotEmpty) &&
            source.ruleExplore != null;

        if (hasSearch) {
          final overrideKeyword = config.normalizedKeyword();
          final keyword = overrideKeyword.isNotEmpty
              ? overrideKeyword
              : (source.ruleSearch?.checkKeyWord?.trim().isNotEmpty == true
                  ? source.ruleSearch!.checkKeyWord!.trim()
                  : '我的');
          item.debugKey = keyword;
          final debug = await _engine.searchDebug(source, keyword);
          final ok = debug.fetch.body != null;
          final cnt = debug.listCount;

          item.elapsedMs = debug.fetch.elapsedMs;
          item.requestUrl = debug.fetch.finalUrl ?? debug.fetch.requestUrl;
          item.listCount = cnt;
          item.diagnosis = _diagnosisService.diagnoseSearch(
            debug: debug,
            keyword: keyword,
          );
          if (!ok) {
            item.status = SourceCheckStatus.fail;
            item.message = debug.error ?? debug.fetch.error ?? '请求失败';
          } else if (cnt <= 0) {
            item.status = SourceCheckStatus.empty;
            item.message =
                '请求成功，但列表为空（${keyword.isEmpty ? '无关键字' : '关键字: $keyword'}）';
          } else {
            item.status = SourceCheckStatus.ok;
            item.message = '可用（列表 $cnt）';
          }
          touch();
          continue;
        }

        if (hasExplore) {
          final url = source.exploreUrl!.trim();
          item.debugKey = '发现::$url';
          final debug = await _engine.exploreDebug(source);
          final ok = debug.fetch.body != null;
          final cnt = debug.listCount;

          item.elapsedMs = debug.fetch.elapsedMs;
          item.requestUrl = debug.fetch.finalUrl ?? debug.fetch.requestUrl;
          item.listCount = cnt;
          item.diagnosis = _diagnosisService.diagnoseExplore(debug: debug);
          if (!ok) {
            item.status = SourceCheckStatus.fail;
            item.message = debug.error ?? debug.fetch.error ?? '请求失败';
          } else if (cnt <= 0) {
            item.status = SourceCheckStatus.empty;
            item.message = '请求成功，但列表为空';
          } else {
            item.status = SourceCheckStatus.ok;
            item.message = '可用（列表 $cnt）';
          }
          touch();
          continue;
        }

        item.status = SourceCheckStatus.fail;
        item.message = '缺少 searchUrl/ruleSearch 或 exploreUrl/ruleExplore，无法检测';
        item.diagnosis = _diagnosisService.diagnoseMissingRule();
        touch();
      } catch (e) {
        item.status = SourceCheckStatus.fail;
        item.message = '异常：$e';
        item.diagnosis = _diagnosisService.diagnoseException(e);
        touch();
      }
    }

    final done = snapshot;
    if (done == null) return;
    _notifier.value = done.copyWith(
      running: false,
      stopRequested: false,
      finishedAt: DateTime.now(),
    );
    _publishSummary(done.items, done.config);
  }

  List<SourceCheckItem> _buildItems(SourceCheckTaskConfig config) {
    final selectedUrls = config.normalizedSourceUrls();
    final all = _repo.getAllSources()
      ..retainWhere((source) {
        if (selectedUrls.isEmpty) return true;
        return selectedUrls.contains(source.bookSourceUrl);
      })
      ..sort((a, b) {
        if (a.weight != b.weight) return b.weight.compareTo(a.weight);
        return a.bookSourceName.compareTo(b.bookSourceName);
      });

    return all
        .map((source) => SourceCheckItem(source: source))
        .toList(growable: false);
  }

  void _publishSummary(
      List<SourceCheckItem> items, SourceCheckTaskConfig config) {
    final failedSourceUrls = items
        .where((item) =>
            item.status == SourceCheckStatus.fail ||
            item.status == SourceCheckStatus.empty)
        .map((item) => item.source.bookSourceUrl)
        .toSet()
        .toList(growable: false);

    SourceAvailabilitySummaryStore.instance.update(
      SourceAvailabilitySummary(
        finishedAt: DateTime.now(),
        includeDisabled: config.includeDisabled,
        keyword: config.normalizedKeyword().isEmpty
            ? null
            : config.normalizedKeyword(),
        total: items.length,
        available: items.where((e) => e.status == SourceCheckStatus.ok).length,
        failed: items.where((e) => e.status == SourceCheckStatus.fail).length,
        empty: items.where((e) => e.status == SourceCheckStatus.empty).length,
        timeout: items
            .where((e) =>
                e.status == SourceCheckStatus.fail &&
                _isTimeoutMessage(e.message))
            .length,
        skipped:
            items.where((e) => e.status == SourceCheckStatus.skipped).length,
        failedSourceUrls: failedSourceUrls,
      ),
    );
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
}
