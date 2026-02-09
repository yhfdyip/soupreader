class SourceDebugSummaryParser {
  const SourceDebugSummaryParser._();

  static const Set<String> _importantHeaderKeys = {
    'content-type',
    'user-agent',
    'referer',
    'origin',
    'cookie',
    'authorization',
    'x-forwarded-for',
  };

  static Map<String, dynamic> build({
    required List<String> logLines,
    String? debugError,
    List<String> errorLines = const <String>[],
  }) {
    final normalized = _normalizeLines(logLines);
    final requestStages = <Map<String, dynamic>>[];

    final listSizes = <int>[];
    int? booksTotal;
    int? chaptersTotal;
    int? contentPages;
    int? contentExtractedLength;
    int? contentCleanedLength;
    String? contentStopReason;
    var stoppedByNextChapter = false;

    String? currentStage;
    int? currentStageRequestIndex;

    String? methodDecision;
    String? retryDecision;
    String? requestCharsetDecision;
    String? bodyDecision;
    String? responseCharset;
    String? responseDecodeDecision;
    bool? cookieJarEnabled;
    final currentRequestHeaders = <String, String>{};
    var collectingRequestHeaders = false;

    void resetRequestMeta() {
      methodDecision = null;
      retryDecision = null;
      requestCharsetDecision = null;
      bodyDecision = null;
      responseCharset = null;
      responseDecodeDecision = null;
      cookieJarEnabled = null;
      currentRequestHeaders.clear();
      collectingRequestHeaders = false;
    }

    for (final line in normalized) {
      final stage = _stageFromLine(line);
      if (stage != null) {
        currentStage = stage;
      }

      final requestIndex = _requestIndexFromLine(line);
      if (requestIndex != null) {
        currentStageRequestIndex = requestIndex;
      }

      if (line.startsWith('└请求头（CookieJar=')) {
        cookieJarEnabled = line.contains('CookieJar=开');
        collectingRequestHeaders = true;
        continue;
      }

      if (collectingRequestHeaders && !_isHeaderLine(line)) {
        collectingRequestHeaders = false;
      }

      if (collectingRequestHeaders && _isHeaderLine(line)) {
        final parsedHeader = _parseHeaderLine(line);
        if (parsedHeader != null) {
          final key = parsedHeader.key;
          final value = parsedHeader.value;
          final lower = key.toLowerCase();
          if (_importantHeaderKeys.contains(lower)) {
            currentRequestHeaders[key] = _sanitizeHeaderValue(key, value);
          }
        }
        continue;
      }

      if (line.startsWith('└请求决策：')) {
        methodDecision = _suffix(line, '└请求决策：');
        continue;
      }
      if (line.startsWith('└重试决策：')) {
        retryDecision = _suffix(line, '└重试决策：');
        continue;
      }
      if (line.startsWith('└请求编码：')) {
        requestCharsetDecision = _suffix(line, '└请求编码：');
        continue;
      }
      if (line.startsWith('└请求体决策：')) {
        bodyDecision = _suffix(line, '└请求体决策：');
        continue;
      }
      if (line.startsWith('└响应编码：')) {
        responseCharset = _suffix(line, '└响应编码：');
        continue;
      }
      if (line.startsWith('└响应解码决策：')) {
        responseDecodeDecision = _suffix(line, '└响应解码决策：');
        continue;
      }
      if (line.startsWith('└Content-Type：')) {
        final value = _suffix(line, '└Content-Type：');
        if (value != null && value.isNotEmpty) {
          currentRequestHeaders['Content-Type'] =
              _sanitizeHeaderValue('Content-Type', value);
        }
        continue;
      }

      final successMatch = RegExp(
        r'^≡获取(?:成功|完成):(.+?)(?: \((\d+)\))? (\d+)ms$',
      ).firstMatch(line);
      if (successMatch != null) {
        final statusCode = int.tryParse(successMatch.group(2) ?? '');
        final elapsedMs = int.tryParse(successMatch.group(3) ?? '') ?? 0;
        requestStages.add(
          _withoutNulls(<String, dynamic>{
            'stage': currentStage ?? 'unknown',
            'requestIndex': currentStageRequestIndex,
            'url': successMatch.group(1)?.trim(),
            'statusCode': statusCode,
            'elapsedMs': elapsedMs,
            'ok': statusCode == null || statusCode < 400,
            'cookieJarEnabled': cookieJarEnabled,
            'requestHeaders': currentRequestHeaders.isEmpty
                ? null
                : Map<String, String>.from(currentRequestHeaders),
            'methodDecision': methodDecision,
            'retryDecision': retryDecision,
            'requestCharsetDecision': requestCharsetDecision,
            'bodyDecision': bodyDecision,
            'responseCharset': responseCharset,
            'responseDecodeDecision': responseDecodeDecision,
          }),
        );
        resetRequestMeta();
        continue;
      }

      final failMatch = RegExp(
        r'^≡请求失败:(.+?)(?: \((\d+)\))? (\d+)ms$',
      ).firstMatch(line);
      if (failMatch != null) {
        final statusCode = int.tryParse(failMatch.group(2) ?? '');
        final elapsedMs = int.tryParse(failMatch.group(3) ?? '') ?? 0;
        requestStages.add(
          _withoutNulls(<String, dynamic>{
            'stage': currentStage ?? 'unknown',
            'requestIndex': currentStageRequestIndex,
            'url': failMatch.group(1)?.trim(),
            'statusCode': statusCode,
            'elapsedMs': elapsedMs,
            'ok': false,
            'cookieJarEnabled': cookieJarEnabled,
            'requestHeaders': currentRequestHeaders.isEmpty
                ? null
                : Map<String, String>.from(currentRequestHeaders),
            'methodDecision': methodDecision,
            'retryDecision': retryDecision,
            'requestCharsetDecision': requestCharsetDecision,
            'bodyDecision': bodyDecision,
          }),
        );
        resetRequestMeta();
        continue;
      }

      final listSize = _intFromSuffix(line, '└列表大小:');
      if (listSize != null) {
        listSizes.add(listSize);
        continue;
      }

      final booksCount = _intFromSuffix(line, '◇书籍总数:');
      if (booksCount != null) {
        booksTotal = booksCount;
        continue;
      }

      final chapterCount = _intFromSuffix(line, '◇章节总数:');
      if (chapterCount != null) {
        chaptersTotal = chapterCount;
        continue;
      }

      final pageSummaryMatch = RegExp(
        r'^◇分页:(\d+) 提取总长:(\d+) 清理后总长:(\d+)$',
      ).firstMatch(line);
      if (pageSummaryMatch != null) {
        contentPages = int.tryParse(pageSummaryMatch.group(1) ?? '');
        contentExtractedLength =
            int.tryParse(pageSummaryMatch.group(2) ?? '');
        contentCleanedLength = int.tryParse(pageSummaryMatch.group(3) ?? '');
        continue;
      }

      if (line.startsWith('≡正文翻页结束：')) {
        contentStopReason = _suffix(line, '≡正文翻页结束：');
        continue;
      }

      if (line.contains('命中下一章链接') && line.contains('停止正文翻页')) {
        stoppedByNextChapter = true;
        continue;
      }
    }

    final stageErrors = <String>{
      for (final line in _normalizeLines(errorLines)) line,
    }.toList(growable: false);

    final failed = requestStages.where((stage) {
      final ok = stage['ok'];
      return ok is bool ? !ok : true;
    }).length;

    final requestSection = <String, dynamic>{
      'total': requestStages.length,
      'failed': failed,
      'stages': requestStages,
      'last': requestStages.isEmpty ? null : requestStages.last,
    };

    final parseSection = _withoutNulls(<String, dynamic>{
      'listSizes': listSizes,
      'booksTotal': booksTotal,
      'chaptersTotal': chaptersTotal,
      'contentPages': contentPages,
      'contentExtractedLength': contentExtractedLength,
      'contentCleanedLength': contentCleanedLength,
      'contentStopReason': contentStopReason,
      'stoppedByNextChapter': stoppedByNextChapter,
    });

    final errorSection = _withoutNulls(<String, dynamic>{
      'debugError': _cleanText(debugError),
      'stageErrors': stageErrors,
    });

    final diagnosisSection = _buildDiagnosis(
      failedRequests: failed,
      requestTotal: requestStages.length,
      booksTotal: booksTotal,
      chaptersTotal: chaptersTotal,
      contentCleanedLength: contentCleanedLength,
      contentStopReason: contentStopReason,
      stoppedByNextChapter: stoppedByNextChapter,
      stageErrors: stageErrors,
      debugError: debugError,
    );

    return <String, dynamic>{
      'request': requestSection,
      'parse': parseSection,
      'errors': errorSection,
      'diagnosis': diagnosisSection,
    };
  }

  static Map<String, dynamic> _buildDiagnosis({
    required int failedRequests,
    required int requestTotal,
    required int? booksTotal,
    required int? chaptersTotal,
    required int? contentCleanedLength,
    required String? contentStopReason,
    required bool stoppedByNextChapter,
    required List<String> stageErrors,
    required String? debugError,
  }) {
    final labels = <String>[];
    final hints = <String>[];

    final lowerErrors = stageErrors.map((e) => e.toLowerCase()).join('\n');
    final lowerDebug = (debugError ?? '').toLowerCase();

    final hasRequestFailure =
        failedRequests > 0 || _containsAny(lowerErrors, _requestKeywords) ||
            _containsAny(lowerDebug, _requestKeywords);
    if (hasRequestFailure) {
      labels.add('request_failure');
      hints.add('请求阶段存在失败，优先检查网络可达性、Header/Cookie 与反爬限制。');
    }

    final hasParseFailure = !hasRequestFailure &&
        (_containsAny(lowerErrors, _parseKeywords) ||
            _containsAny(lowerDebug, _parseKeywords) ||
            (booksTotal != null && booksTotal <= 0) ||
            (chaptersTotal != null && chaptersTotal <= 0) ||
            (contentCleanedLength != null && contentCleanedLength <= 0));
    if (hasParseFailure) {
      labels.add('parse_failure');
      hints.add('请求成功但解析结果异常，建议先核对 ruleSearch/ruleBookInfo/ruleToc/ruleContent。');
    }

    final hasPagingInterrupted = stoppedByNextChapter ||
        (contentStopReason != null &&
            contentStopReason.trim().isNotEmpty &&
            contentStopReason != '无可用下一页');
    if (hasPagingInterrupted) {
      labels.add('paging_interrupted');
      hints.add('正文分页提前停止，建议检查 nextContentUrl 规则与下一章链接阻断逻辑。');
    }

    if (labels.isEmpty) {
      if (requestTotal > 0) {
        labels.add('ok');
        hints.add('未发现明显异常，请结合结构化摘要与控制台细节继续定位。');
      } else {
        labels.add('no_data');
        hints.add('暂无调试数据，请先运行一次调试。');
      }
    }

    return <String, dynamic>{
      'labels': labels,
      'hints': hints,
      'primary': labels.first,
    };
  }

  static List<String> _normalizeLines(List<String> rawLines) {
    final lines = <String>[];
    for (final raw in rawLines) {
      for (final split in raw.split('\n')) {
        final cleaned = _cleanLine(split);
        if (cleaned != null) {
          lines.add(cleaned);
        }
      }
    }
    return lines;
  }

  static String? _cleanLine(String? line) {
    final stripped = _stripDebugTimePrefix(line ?? '').trim();
    if (stripped.isEmpty) return null;
    return stripped;
  }

  static String? _cleanText(String? text) {
    final cleaned = text?.trim();
    if (cleaned == null || cleaned.isEmpty) return null;
    return cleaned;
  }

  static String _stripDebugTimePrefix(String text) {
    final trimmed = text.trimLeft();
    if (!trimmed.startsWith('[')) return trimmed;
    final index = trimmed.indexOf('] ');
    if (index < 0) return trimmed;
    return trimmed.substring(index + 2);
  }

  static String? _stageFromLine(String line) {
    if (line.startsWith('︾开始解析搜索页')) return 'search';
    if (line.startsWith('︾开始解析发现页')) return 'explore';
    if (line.startsWith('︾开始解析详情页')) return 'bookInfo';
    if (line.startsWith('︾开始解析目录页')) return 'toc';
    if (line.startsWith('︾开始解析正文页')) return 'content';
    return null;
  }

  static int? _requestIndexFromLine(String line) {
    final toc = _intFromSuffix(line, '≡目录页请求:');
    if (toc != null) return toc;
    final content = _intFromSuffix(line, '≡正文页请求:');
    if (content != null) return content;
    return null;
  }

  static int? _intFromSuffix(String line, String prefix) {
    if (!line.startsWith(prefix)) return null;
    return int.tryParse(line.substring(prefix.length).trim());
  }

  static String? _suffix(String line, String prefix) {
    if (!line.startsWith(prefix)) return null;
    final value = line.substring(prefix.length).trim();
    if (value.isEmpty) return null;
    return value;
  }

  static bool _isHeaderLine(String line) {
    if (!line.contains(':')) return false;
    final trimmed = line.trimLeft();
    const controlPrefixes = ['└', '┌', '≡', '◇', '⇒', '︾', '︽'];
    for (final prefix in controlPrefixes) {
      if (trimmed.startsWith(prefix)) {
        return false;
      }
    }
    return true;
  }

  static MapEntry<String, String>? _parseHeaderLine(String line) {
    final index = line.indexOf(':');
    if (index <= 0) return null;
    final key = line.substring(0, index).trim();
    final value = line.substring(index + 1).trim();
    if (key.isEmpty) return null;
    return MapEntry(key, value);
  }

  static String _sanitizeHeaderValue(String key, String value) {
    final lower = key.toLowerCase();
    if (lower.contains('cookie') ||
        lower.contains('authorization') ||
        lower.contains('token')) {
      return _maskSensitive(value);
    }
    if (value.length > 200) {
      return '${value.substring(0, 200)}…';
    }
    return value;
  }

  static String _maskSensitive(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return trimmed;
    if (trimmed.length <= 6) return '***';
    final head = trimmed.substring(0, 3);
    final tail = trimmed.substring(trimmed.length - 2);
    return '$head***$tail';
  }

  static Map<String, dynamic> _withoutNulls(Map<String, dynamic> input) {
    final output = <String, dynamic>{};
    input.forEach((key, value) {
      if (value == null) return;
      if (value is String && value.trim().isEmpty) return;
      output[key] = value;
    });
    return output;
  }

  static const List<String> _requestKeywords = [
    'http 状态码',
    '请求失败',
    '超时',
    'timeout',
    'network',
    'dioexception',
    '连接失败',
    '连接超时',
  ];

  static const List<String> _parseKeywords = [
    '列表为空',
    '字段全为空',
    '不匹配',
    '内容为空',
    '没有正文章节',
    '规则为空',
    '解析失败',
  ];

  static bool _containsAny(String text, List<String> patterns) {
    for (final pattern in patterns) {
      if (text.contains(pattern)) return true;
    }
    return false;
  }
}
