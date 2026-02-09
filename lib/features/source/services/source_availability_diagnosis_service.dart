import 'rule_parser_engine.dart';
import 'source_debug_summary_parser.dart';

class DiagnosisSummary {
  final List<String> labels;
  final List<String> hints;

  const DiagnosisSummary({
    required this.labels,
    required this.hints,
  });

  String get primary => labels.isEmpty ? 'no_data' : labels.first;

  static const noData = DiagnosisSummary(
    labels: <String>['no_data'],
    hints: <String>['暂无检测数据，请先运行一次检测。'],
  );

  factory DiagnosisSummary.fromMap(dynamic raw) {
    if (raw is! Map) return noData;

    List<String> pickList(String key) {
      final value = raw[key];
      if (value is! List) return const <String>[];
      return value
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList(growable: false);
    }

    final labels = pickList('labels');
    final hints = pickList('hints');
    if (labels.isEmpty && hints.isEmpty) return noData;

    return DiagnosisSummary(
      labels: labels.isEmpty ? const <String>['no_data'] : labels,
      hints: hints,
    );
  }
}

class SourceAvailabilityDiagnosisService {
  const SourceAvailabilityDiagnosisService();

  DiagnosisSummary diagnoseSearch({
    required SearchDebugResult debug,
    required String keyword,
  }) {
    final context = keyword.trim().isEmpty ? '无关键字' : '关键字=$keyword';
    return _diagnoseListDebug(
      stageStart: '︾开始解析搜索页',
      fetch: debug.fetch,
      listCount: debug.listCount,
      debugError: debug.error,
      extraErrors: <String>[if (debug.listCount <= 0) '列表为空（$context）'],
    );
  }

  DiagnosisSummary diagnoseExplore({
    required ExploreDebugResult debug,
  }) {
    return _diagnoseListDebug(
      stageStart: '︾开始解析发现页',
      fetch: debug.fetch,
      listCount: debug.listCount,
      debugError: debug.error,
      extraErrors: <String>[if (debug.listCount <= 0) '列表为空（发现）'],
    );
  }

  DiagnosisSummary diagnoseMissingRule() {
    return const DiagnosisSummary(
      labels: <String>['parse_failure'],
      hints: <String>['缺少 search/explore 规则配置，请先补齐 searchUrl/ruleSearch 或 exploreUrl/ruleExplore。'],
    );
  }

  DiagnosisSummary diagnoseException(Object error) {
    return DiagnosisSummary(
      labels: const <String>['request_failure'],
      hints: <String>['检测阶段抛出异常：$error'],
    );
  }

  DiagnosisSummary _diagnoseListDebug({
    required String stageStart,
    required FetchDebugResult fetch,
    required int listCount,
    required String? debugError,
    List<String> extraErrors = const <String>[],
  }) {
    final requestUrl = (fetch.finalUrl ?? fetch.requestUrl).trim();
    final statusText = fetch.statusCode == null ? '' : ' (${fetch.statusCode})';
    final elapsedText = '${fetch.elapsedMs}ms';
    final requestLine = fetch.body != null
        ? '≡获取成功:$requestUrl$statusText $elapsedText'
        : '≡请求失败:$requestUrl$statusText $elapsedText';

    final logLines = <String>[
      stageStart,
      requestLine,
      '└列表大小:$listCount',
      '◇书籍总数:${listCount.clamp(0, 999999)}',
    ];

    final errors = <String>{
      if (debugError != null && debugError.trim().isNotEmpty) debugError.trim(),
      if (fetch.error != null && fetch.error!.trim().isNotEmpty)
        fetch.error!.trim(),
      ...extraErrors.where((e) => e.trim().isNotEmpty),
    }.toList(growable: false);

    final summary = SourceDebugSummaryParser.build(
      logLines: logLines,
      debugError: debugError,
      errorLines: errors,
    );

    return DiagnosisSummary.fromMap(summary['diagnosis']);
  }
}
