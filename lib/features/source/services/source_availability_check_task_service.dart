import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../core/database/database_service.dart';
import '../../../core/database/repositories/source_repository.dart';
import '../../../core/services/settings_service.dart';
import '../models/book_source.dart';
import 'rule_parser_engine.dart';
import 'source_availability_diagnosis_service.dart';
import 'source_check_source_state_helper.dart';
import 'source_explore_kinds_service.dart';
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

class SourceCheckCachedResult {
  const SourceCheckCachedResult({
    required this.status,
    required this.message,
    required this.elapsedMs,
  });

  final SourceCheckStatus status;
  final String? message;
  final int elapsedMs;
}

class SourceCheckTaskConfig {
  final bool includeDisabled;
  final List<String>? sourceUrls;
  final String? keywordOverride;
  final int timeoutMs;
  final bool checkSearch;
  final bool checkDiscovery;
  final bool checkInfo;
  final bool checkCategory;
  final bool checkContent;

  const SourceCheckTaskConfig({
    required this.includeDisabled,
    this.sourceUrls,
    this.keywordOverride,
    this.timeoutMs = 180000,
    this.checkSearch = true,
    this.checkDiscovery = true,
    this.checkInfo = true,
    this.checkCategory = true,
    this.checkContent = true,
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

  int normalizedTimeoutMs() {
    return timeoutMs > 0 ? timeoutMs : 180000;
  }

  bool semanticallyEquals(SourceCheckTaskConfig other) {
    if (includeDisabled != other.includeDisabled) return false;
    if (checkSearch != other.checkSearch) return false;
    if (checkDiscovery != other.checkDiscovery) return false;
    if (checkInfo != other.checkInfo) return false;
    if (checkCategory != other.checkCategory) return false;
    if (checkContent != other.checkContent) return false;
    if (normalizedTimeoutMs() != other.normalizedTimeoutMs()) return false;
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

class _SourceCheckStageOutcome {
  const _SourceCheckStageOutcome({
    required this.success,
    required this.failed,
    this.message = '',
    this.requestUrl,
    this.elapsedMs = 0,
    this.listCount = 0,
    this.diagnosis = DiagnosisSummary.noData,
    this.addGroups = const <String>{},
    this.removeGroups = const <String>{},
  });

  final bool success;
  final bool failed;
  final String message;
  final String? requestUrl;
  final int elapsedMs;
  final int listCount;
  final DiagnosisSummary diagnosis;
  final Set<String> addGroups;
  final Set<String> removeGroups;

  bool get hasMessage => message.trim().isNotEmpty;
}

class _SourceCheckRunOutcome {
  const _SourceCheckRunOutcome({
    this.addGroups = const <String>{},
    this.removeGroups = const <String>{},
  });

  final Set<String> addGroups;
  final Set<String> removeGroups;
}

/// 书源可用性检测任务服务：
/// - 检测任务脱离页面生命周期，页面退出后可继续运行；
/// - 再次进入检测页可恢复当前任务状态；
/// - 提供 start/stop 任务控制，并输出统一快照供 UI 订阅。
class SourceAvailabilityCheckTaskService {
  SourceAvailabilityCheckTaskService._();

  static final SourceAvailabilityCheckTaskService instance =
      SourceAvailabilityCheckTaskService._();
  static const int _fallbackThreadCount = 8;

  final RuleParserEngine _engine = RuleParserEngine();
  final SourceAvailabilityDiagnosisService _diagnosisService =
      const SourceAvailabilityDiagnosisService();
  final SourceRepository _repo = SourceRepository(DatabaseService());
  final SourceExploreKindsService _exploreKindsService =
      SourceExploreKindsService();
  CancelToken? _runningCancelToken;
  final Set<CancelToken> _runningCancelTokens = <CancelToken>{};
  final Map<String, SourceCheckCachedResult> _lastResultByUrl =
      <String, SourceCheckCachedResult>{};

  final ValueNotifier<SourceCheckTaskSnapshot?> _notifier =
      ValueNotifier<SourceCheckTaskSnapshot?>(null);

  ValueListenable<SourceCheckTaskSnapshot?> get listenable => _notifier;

  SourceCheckTaskSnapshot? get snapshot => _notifier.value;

  bool get isRunning => snapshot?.running == true;

  SourceCheckCachedResult? lastResultFor(String bookSourceUrl) {
    final key = bookSourceUrl.trim();
    if (key.isEmpty) return null;
    return _lastResultByUrl[key];
  }

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

    for (final item in items) {
      final url = item.source.bookSourceUrl.trim();
      if (url.isEmpty) continue;
      _lastResultByUrl.remove(url);
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
    final runningTokens = _runningCancelTokens.toList(growable: false);
    for (final token in runningTokens) {
      if (!token.isCancelled) {
        token.cancel('source check stopped by user');
      }
    }
    final token = _runningCancelToken;
    if (token != null && !token.isCancelled) {
      token.cancel('source check stopped by user');
    }
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
    final workerCount = _resolveThreadCount(items.length);
    var cursor = 0;
    Future<void> runWorker() async {
      while (true) {
        if (_shouldStopCurrentTask()) return;
        if (cursor >= items.length) return;
        final item = items[cursor++];
        await _runItem(config: config, item: item);
      }
    }

    final workers = List<Future<void>>.generate(
      workerCount,
      (_) => runWorker(),
      growable: false,
    );
    await Future.wait(workers);

    _runningCancelToken = null;
    _runningCancelTokens.clear();

    final done = snapshot;
    if (done == null) return;
    _notifier.value = done.copyWith(
      running: false,
      stopRequested: false,
      finishedAt: DateTime.now(),
    );
    _publishSummary(done.items, done.config);
  }

  Future<void> _runItem({
    required SourceCheckTaskConfig config,
    required SourceCheckItem item,
  }) async {
    if (_shouldStopCurrentTask()) return;

    var source = item.source;
    if (!config.includeDisabled && !source.enabled) {
      item.status = SourceCheckStatus.skipped;
      item.message = '已跳过（未启用）';
      _cacheItemResult(item);
      touch();
      return;
    }
    if (!config.checkSearch && !config.checkDiscovery) {
      item.status = SourceCheckStatus.skipped;
      item.message = '已跳过（未启用搜索/发现校验）';
      _cacheItemResult(item);
      touch();
      return;
    }

    item.status = SourceCheckStatus.running;
    item.message = '检测中…';
    _cacheItemResult(item);
    touch();
    source = SourceCheckSourceStateHelper.prepareForCheck(source);
    item.source = source;

    final requestToken = CancelToken();
    _runningCancelToken = requestToken;
    _runningCancelTokens.add(requestToken);
    final itemStopwatch = Stopwatch()..start();
    try {
      final timeout = Duration(milliseconds: config.normalizedTimeoutMs());
      final runOutcome = await _runItemCheckStages(
        config: config,
        item: item,
        cancelToken: requestToken,
      ).timeout(
        timeout,
        onTimeout: () {
          if (!requestToken.isCancelled) {
            requestToken.cancel('source check timeout');
          }
          throw TimeoutException('source check timeout');
        },
      );
      source = SourceCheckSourceStateHelper.applyGroupMutations(
        source,
        add: runOutcome.addGroups,
        remove: runOutcome.removeGroups,
      );
      if (item.status == SourceCheckStatus.fail ||
          item.status == SourceCheckStatus.empty) {
        final invalidGroups = SourceCheckSourceStateHelper.invalidGroupNames(
          source.bookSourceGroup,
        );
        final errorMessage = invalidGroups.isNotEmpty
            ? invalidGroups
            : ((item.message ?? '').trim().isNotEmpty
                ? (item.message ?? '').trim()
                : '校验失败');
        source = SourceCheckSourceStateHelper.addErrorComment(
          source,
          errorMessage,
        );
      }
      _cacheItemResult(item);
      touch();
    } on TimeoutException catch (_) {
      item.status = SourceCheckStatus.fail;
      item.message = '校验超时';
      item.diagnosis = _diagnosisService.diagnoseException('timeout');
      source = SourceCheckSourceStateHelper.applyGroupMutations(
        source,
        add: const <String>{'校验超时'},
      );
      source = SourceCheckSourceStateHelper.addErrorComment(source, '校验超时');
      _cacheItemResult(item);
      touch();
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) {
        item.status = SourceCheckStatus.skipped;
        item.message = '已停止';
        item.diagnosis = DiagnosisSummary.noData;
        _cacheItemResult(item);
        touch();
      } else {
        item.status = SourceCheckStatus.fail;
        item.message = '异常：$e';
        item.diagnosis = _diagnosisService.diagnoseException(e);
        source = SourceCheckSourceStateHelper.applyGroupMutations(
          source,
          add: const <String>{'网站失效'},
        );
        source = SourceCheckSourceStateHelper.addErrorComment(
          source,
          e.toString(),
        );
        _cacheItemResult(item);
        touch();
      }
    } catch (e) {
      item.status = SourceCheckStatus.fail;
      item.message = '异常：$e';
      item.diagnosis = _diagnosisService.diagnoseException(e);
      final errorText = e.toString();
      source = SourceCheckSourceStateHelper.applyGroupMutations(
        source,
        add: _isLikelyJsError(errorText)
            ? const <String>{'js失效'}
            : const <String>{'网站失效'},
      );
      source = SourceCheckSourceStateHelper.addErrorComment(source, errorText);
      _cacheItemResult(item);
      touch();
    } finally {
      itemStopwatch.stop();
      final elapsed = item.elapsedMs > 0
          ? item.elapsedMs
          : itemStopwatch.elapsedMilliseconds;
      if (elapsed > 0) {
        source = source.copyWith(respondTime: elapsed);
        item.elapsedMs = elapsed;
      }
      item.source = source;
      _cacheItemResult(item);
      try {
        await _repo.updateSource(source);
      } catch (_) {
        // 按任务继续策略忽略单条写库失败，避免整批检测中断。
      }
      _runningCancelTokens.remove(requestToken);
      if (identical(_runningCancelToken, requestToken)) {
        _runningCancelToken = null;
      }
    }
  }

  bool _shouldStopCurrentTask() {
    final latest = snapshot;
    return latest == null || !latest.running || latest.stopRequested;
  }

  int _resolveThreadCount(int itemCount) {
    if (itemCount <= 0) return 1;
    var threadCount = _fallbackThreadCount;
    try {
      threadCount = SettingsService().appSettings.searchConcurrency;
    } catch (_) {
      threadCount = _fallbackThreadCount;
    }
    if (threadCount < 1) {
      threadCount = 1;
    }
    if (threadCount > itemCount) {
      threadCount = itemCount;
    }
    return threadCount;
  }

  Future<_SourceCheckRunOutcome> _runItemCheckStages({
    required SourceCheckTaskConfig config,
    required SourceCheckItem item,
    required CancelToken cancelToken,
  }) async {
    _throwIfCancelled(cancelToken);
    final source = item.source;
    final outcomes = <_SourceCheckStageOutcome>[];
    if (config.checkSearch) {
      outcomes.add(
        await _runSearchStage(
          source: source,
          config: config,
          item: item,
          cancelToken: cancelToken,
        ),
      );
    }
    if (config.checkDiscovery) {
      outcomes.add(
        await _runExploreStage(
          source: source,
          config: config,
          item: item,
          cancelToken: cancelToken,
        ),
      );
    }

    if (outcomes.isEmpty) {
      item.status = SourceCheckStatus.skipped;
      item.message = '已跳过';
      item.diagnosis = DiagnosisSummary.noData;
      return const _SourceCheckRunOutcome();
    }

    final failedMessages = <String>[];
    final successMessages = <String>[];
    final addGroups = <String>{};
    final removeGroups = <String>{};
    var hasSuccessOutcome = false;
    var elapsedMs = 0;
    var listCount = 0;
    String? requestUrl;
    DiagnosisSummary diagnosis = DiagnosisSummary.noData;

    for (final outcome in outcomes) {
      elapsedMs += outcome.elapsedMs;
      listCount = listCount > outcome.listCount ? listCount : outcome.listCount;
      if ((outcome.requestUrl ?? '').trim().isNotEmpty) {
        requestUrl = outcome.requestUrl;
      }
      if (diagnosis == DiagnosisSummary.noData &&
          outcome.diagnosis != DiagnosisSummary.noData) {
        diagnosis = outcome.diagnosis;
      }
      addGroups.addAll(outcome.addGroups);
      removeGroups.addAll(outcome.removeGroups);
      if (outcome.failed) {
        if (outcome.hasMessage) {
          failedMessages.add(outcome.message);
        }
      } else if (outcome.success) {
        hasSuccessOutcome = true;
        if (outcome.hasMessage) {
          successMessages.add(outcome.message);
        }
      }
    }

    item.elapsedMs = elapsedMs;
    item.listCount = listCount;
    item.requestUrl = requestUrl;
    item.diagnosis = diagnosis;

    if (failedMessages.isNotEmpty) {
      item.status = SourceCheckStatus.fail;
      item.message = failedMessages.join('；');
      return _SourceCheckRunOutcome(
        addGroups: addGroups,
        removeGroups: removeGroups,
      );
    }
    if (successMessages.isNotEmpty) {
      item.status = SourceCheckStatus.ok;
      item.message = successMessages.join('；');
      return _SourceCheckRunOutcome(
        addGroups: addGroups,
        removeGroups: removeGroups,
      );
    }
    if (hasSuccessOutcome) {
      item.status = SourceCheckStatus.ok;
      item.message = '校验成功';
      return _SourceCheckRunOutcome(
        addGroups: addGroups,
        removeGroups: removeGroups,
      );
    }

    item.status = SourceCheckStatus.skipped;
    item.message = '已跳过';
    if (item.diagnosis == DiagnosisSummary.noData) {
      item.diagnosis = _diagnosisService.diagnoseMissingRule();
    }
    return _SourceCheckRunOutcome(
      addGroups: addGroups,
      removeGroups: removeGroups,
    );
  }

  Future<_SourceCheckStageOutcome> _runSearchStage({
    required BookSource source,
    required SourceCheckTaskConfig config,
    required SourceCheckItem item,
    required CancelToken cancelToken,
  }) async {
    final hasSearch =
        source.searchUrl != null && source.searchUrl!.trim().isNotEmpty;
    if (!hasSearch) {
      return _SourceCheckStageOutcome(
        success: true,
        failed: false,
        message: '',
        diagnosis: _diagnosisService.diagnoseMissingRule(),
        addGroups: const <String>{'搜索链接规则为空'},
      );
    }

    final overrideKeyword = config.normalizedKeyword();
    final keyword = overrideKeyword.isNotEmpty
        ? overrideKeyword
        : (source.ruleSearch?.checkKeyWord?.trim().isNotEmpty == true
            ? source.ruleSearch!.checkKeyWord!.trim()
            : '我的');
    item.debugKey = keyword;
    final debug = await _engine.searchDebug(
      source,
      keyword,
      cancelToken: cancelToken,
    );
    final cnt = debug.listCount;
    final requestUrl = debug.fetch.finalUrl ?? debug.fetch.requestUrl;
    final diagnosis = _diagnosisService.diagnoseSearch(
      debug: debug,
      keyword: keyword,
    );
    final fetchOk = debug.fetch.body != null;
    if (!fetchOk) {
      final errorText = (debug.error ?? debug.fetch.error ?? '搜索请求失败');
      final failureGroup = _isLikelyJsError(errorText) ? 'js失效' : '网站失效';
      return _SourceCheckStageOutcome(
        success: false,
        failed: true,
        message: errorText,
        requestUrl: requestUrl,
        elapsedMs: debug.fetch.elapsedMs,
        listCount: cnt,
        diagnosis: diagnosis,
        addGroups: <String>{failureGroup},
        removeGroups: const <String>{'搜索链接规则为空'},
      );
    }
    if (cnt <= 0) {
      return _SourceCheckStageOutcome(
        success: false,
        failed: true,
        message: '搜索失效',
        requestUrl: requestUrl,
        elapsedMs: debug.fetch.elapsedMs,
        listCount: cnt,
        diagnosis: diagnosis,
        addGroups: const <String>{'搜索失效'},
        removeGroups: const <String>{'搜索链接规则为空'},
      );
    }
    final firstBookUrl = debug.results.first.bookUrl.trim();
    final chain = await _runBookStageChain(
      source: source,
      config: config,
      stagePrefix: '搜索',
      bookUrl: firstBookUrl,
      cancelToken: cancelToken,
    );
    return _SourceCheckStageOutcome(
      success: chain.success,
      failed: chain.failed,
      message: chain.hasMessage ? chain.message : '搜索可用（列表 $cnt）',
      requestUrl: chain.requestUrl ?? requestUrl,
      elapsedMs: debug.fetch.elapsedMs + chain.elapsedMs,
      listCount: cnt,
      diagnosis: chain.diagnosis == DiagnosisSummary.noData
          ? diagnosis
          : chain.diagnosis,
      addGroups: chain.addGroups,
      removeGroups: {
        ...chain.removeGroups,
        '搜索失效',
        '搜索链接规则为空',
      },
    );
  }

  Future<_SourceCheckStageOutcome> _runExploreStage({
    required BookSource source,
    required SourceCheckTaskConfig config,
    required SourceCheckItem item,
    required CancelToken cancelToken,
  }) async {
    final hasExplore =
        source.exploreUrl != null && source.exploreUrl!.trim().isNotEmpty;
    if (!hasExplore) {
      return _SourceCheckStageOutcome(
        success: true,
        failed: false,
        message: '',
      );
    }

    final exploreUrl = await _resolveFirstExploreUrl(source);
    if (exploreUrl == null) {
      return _SourceCheckStageOutcome(
        success: true,
        failed: false,
        message: '',
        addGroups: const <String>{'发现规则为空'},
      );
    }
    item.debugKey = '发现::$exploreUrl';
    final debug = await _engine.exploreDebug(
      source,
      exploreUrlOverride: exploreUrl,
      cancelToken: cancelToken,
    );
    final cnt = debug.listCount;
    final requestUrl = debug.fetch.finalUrl ?? debug.fetch.requestUrl;
    final diagnosis = _diagnosisService.diagnoseExplore(debug: debug);
    final fetchOk = debug.fetch.body != null;
    if (!fetchOk) {
      final errorText = (debug.error ?? debug.fetch.error ?? '发现请求失败');
      final failureGroup = _isLikelyJsError(errorText) ? 'js失效' : '网站失效';
      return _SourceCheckStageOutcome(
        success: false,
        failed: true,
        message: errorText,
        requestUrl: requestUrl,
        elapsedMs: debug.fetch.elapsedMs,
        listCount: cnt,
        diagnosis: diagnosis,
        addGroups: <String>{failureGroup},
        removeGroups: const <String>{'发现规则为空'},
      );
    }
    if (cnt <= 0) {
      return _SourceCheckStageOutcome(
        success: false,
        failed: true,
        message: '发现失效',
        requestUrl: requestUrl,
        elapsedMs: debug.fetch.elapsedMs,
        listCount: cnt,
        diagnosis: diagnosis,
        addGroups: const <String>{'发现失效'},
        removeGroups: const <String>{'发现规则为空'},
      );
    }
    final firstBookUrl = debug.results.first.bookUrl.trim();
    final chain = await _runBookStageChain(
      source: source,
      config: config,
      stagePrefix: '发现',
      bookUrl: firstBookUrl,
      cancelToken: cancelToken,
    );
    return _SourceCheckStageOutcome(
      success: chain.success,
      failed: chain.failed,
      message: chain.hasMessage ? chain.message : '发现可用（列表 $cnt）',
      requestUrl: chain.requestUrl ?? requestUrl,
      elapsedMs: debug.fetch.elapsedMs + chain.elapsedMs,
      listCount: cnt,
      diagnosis: chain.diagnosis == DiagnosisSummary.noData
          ? diagnosis
          : chain.diagnosis,
      addGroups: chain.addGroups,
      removeGroups: {
        ...chain.removeGroups,
        '发现失效',
        '发现规则为空',
      },
    );
  }

  Future<_SourceCheckStageOutcome> _runBookStageChain({
    required BookSource source,
    required SourceCheckTaskConfig config,
    required String stagePrefix,
    required String bookUrl,
    required CancelToken cancelToken,
  }) async {
    _throwIfCancelled(cancelToken);
    final tocFailureGroup = '$stagePrefix目录失效';
    final contentFailureGroup = '$stagePrefix正文失效';
    if (!config.checkInfo) {
      return _SourceCheckStageOutcome(
        success: true,
        failed: false,
        message: '$stagePrefix可用',
        removeGroups: {tocFailureGroup, contentFailureGroup},
      );
    }
    final normalizedBookUrl = bookUrl.trim();
    if (normalizedBookUrl.isEmpty) {
      return _SourceCheckStageOutcome(
        success: false,
        failed: true,
        message: '$stagePrefix详情失效',
        diagnosis: _diagnosisService.diagnoseMissingRule(),
      );
    }
    _throwIfCancelled(cancelToken);
    final info = await _engine.getBookInfoDebug(source, normalizedBookUrl);
    _throwIfCancelled(cancelToken);
    final infoRequestUrl = info.fetch.finalUrl ?? info.fetch.requestUrl;
    final infoFetchOk = info.fetch.body != null;
    if (!infoFetchOk || info.detail == null) {
      final detailError = (info.error ?? '').trim();
      return _SourceCheckStageOutcome(
        success: false,
        failed: true,
        message: detailError.isNotEmpty ? detailError : '$stagePrefix详情失效',
        requestUrl: infoRequestUrl,
        elapsedMs: info.fetch.elapsedMs,
        diagnosis: _diagnosisService.diagnoseMissingRule(),
      );
    }

    if (!config.checkCategory || _isFileSourceType(source)) {
      return _SourceCheckStageOutcome(
        success: true,
        failed: false,
        message: '$stagePrefix详情可用',
        requestUrl: infoRequestUrl,
        elapsedMs: info.fetch.elapsedMs,
        removeGroups: {tocFailureGroup, contentFailureGroup},
      );
    }

    final tocUrl = info.detail!.tocUrl.trim();
    if (tocUrl.isEmpty) {
      return _SourceCheckStageOutcome(
        success: false,
        failed: true,
        message: '$stagePrefix目录失效',
        requestUrl: infoRequestUrl,
        elapsedMs: info.fetch.elapsedMs,
        addGroups: {tocFailureGroup},
      );
    }

    _throwIfCancelled(cancelToken);
    final toc = await _engine.getTocDebug(source, tocUrl);
    _throwIfCancelled(cancelToken);
    final tocRequestUrl = toc.fetch.finalUrl ?? toc.fetch.requestUrl;
    final tocFetchOk = toc.fetch.body != null;
    final chapters = toc.toc
        .where((chapter) => !chapter.isVolume && chapter.url.trim().isNotEmpty)
        .toList(growable: false);
    if (!tocFetchOk || chapters.isEmpty) {
      final tocError = (toc.error ?? '').trim();
      return _SourceCheckStageOutcome(
        success: false,
        failed: true,
        message: tocError.isNotEmpty ? tocError : '$stagePrefix目录失效',
        requestUrl: tocRequestUrl,
        elapsedMs: info.fetch.elapsedMs + toc.fetch.elapsedMs,
        addGroups: {tocFailureGroup},
      );
    }

    if (!config.checkContent) {
      return _SourceCheckStageOutcome(
        success: true,
        failed: false,
        message: '$stagePrefix目录可用',
        requestUrl: tocRequestUrl,
        elapsedMs: info.fetch.elapsedMs + toc.fetch.elapsedMs,
        removeGroups: {tocFailureGroup, contentFailureGroup},
      );
    }

    final firstChapter = chapters.first;
    final nextChapterUrl = chapters.length > 1 ? chapters[1].url : null;
    _throwIfCancelled(cancelToken);
    final content = await _engine.getContentDebug(
      source,
      firstChapter.url,
      nextChapterUrl: nextChapterUrl,
    );
    _throwIfCancelled(cancelToken);
    final contentRequestUrl =
        content.fetch.finalUrl ?? content.fetch.requestUrl;
    final contentFetchOk = content.fetch.body != null;
    final contentText = content.content.trim();
    if (!contentFetchOk ||
        ((content.error ?? '').trim().isNotEmpty) ||
        contentText.isEmpty) {
      final contentError = (content.error ?? '').trim();
      return _SourceCheckStageOutcome(
        success: false,
        failed: true,
        message: contentError.isNotEmpty ? contentError : '$stagePrefix正文失效',
        requestUrl: contentRequestUrl,
        elapsedMs: info.fetch.elapsedMs +
            toc.fetch.elapsedMs +
            content.fetch.elapsedMs,
        addGroups: {contentFailureGroup},
      );
    }

    return _SourceCheckStageOutcome(
      success: true,
      failed: false,
      message: '$stagePrefix正文可用',
      requestUrl: contentRequestUrl,
      elapsedMs:
          info.fetch.elapsedMs + toc.fetch.elapsedMs + content.fetch.elapsedMs,
      removeGroups: {tocFailureGroup, contentFailureGroup},
    );
  }

  bool _isFileSourceType(BookSource source) {
    return source.bookSourceType == 3;
  }

  Future<String?> _resolveFirstExploreUrl(BookSource source) async {
    try {
      final kinds = await _exploreKindsService.exploreKinds(source);
      for (final kind in kinds) {
        final url = (kind.url ?? '').trim();
        if (url.isNotEmpty) return url;
      }
    } catch (_) {
      // 保持与校验流程一致：无法解析发现分类时按“无可用分类链接”处理。
    }
    return null;
  }

  List<SourceCheckItem> _buildItems(SourceCheckTaskConfig config) {
    final selectedUrls = config.normalizedSourceUrls();
    final all = _repo.getAllSources();
    if (selectedUrls.isNotEmpty) {
      final byUrl = <String, BookSource>{
        for (final source in all) source.bookSourceUrl: source,
      };
      final ordered = <SourceCheckItem>[];
      final seen = <String>{};
      for (final raw in (config.sourceUrls ?? const <String>[])) {
        final url = raw.trim();
        if (url.isEmpty || !seen.add(url)) continue;
        final source = byUrl[url];
        if (source == null) continue;
        ordered.add(SourceCheckItem(source: source));
      }
      return ordered;
    }

    all.sort((a, b) {
      if (a.weight != b.weight) return b.weight.compareTo(a.weight);
      return a.bookSourceName.compareTo(b.bookSourceName);
    });

    return all.map((source) => SourceCheckItem(source: source)).toList();
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

  bool _isLikelyJsError(String message) {
    final text = message.trim().toLowerCase();
    if (text.isEmpty) return false;
    return text.contains('script') ||
        text.contains('javascript') ||
        text.contains('js ') ||
        text.contains('js:') ||
        text.contains('js执行') ||
        text.contains('js失效');
  }

  Never _cancelledError(CancelToken cancelToken) {
    throw DioException(
      requestOptions: RequestOptions(path: ''),
      type: DioExceptionType.cancel,
      error: cancelToken.cancelError,
      message: cancelToken.cancelError?.toString(),
    );
  }

  void _throwIfCancelled(CancelToken cancelToken) {
    if (!cancelToken.isCancelled) return;
    _cancelledError(cancelToken);
  }

  void _cacheItemResult(SourceCheckItem item) {
    if (item.status == SourceCheckStatus.pending) return;
    final url = item.source.bookSourceUrl.trim();
    if (url.isEmpty) return;
    _lastResultByUrl[url] = SourceCheckCachedResult(
      status: item.status,
      message: item.message,
      elapsedMs: item.elapsedMs,
    );
  }
}
