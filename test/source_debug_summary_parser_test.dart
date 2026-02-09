import 'package:flutter_test/flutter_test.dart';

import 'package:soupreader/features/source/services/source_debug_summary_parser.dart';

void main() {
  test('extracts request stages and parse summary from debug logs', () {
    final summary = SourceDebugSummaryParser.build(
      logLines: const [
        '[10:00:00] ︾开始解析搜索页',
        '[10:00:01] └请求头（CookieJar=开）',
        'User-Agent: SoupReader/1.0',
        'Cookie: session=abcdef123456',
        '[10:00:02] └请求决策：urlOption.method=POST',
        '[10:00:02] └重试决策：retry=1；实际重试=0',
        '[10:00:02] └请求编码：UTF-8',
        '[10:00:02] └请求体决策：form 编码',
        '[10:00:03] ≡获取成功:https://a.com/search?q=abc (200) 321ms',
        '[10:00:04] └列表大小:5',
        '[10:00:04] ◇书籍总数:3',
        '[10:00:05] ︾开始解析目录页',
        '[10:00:06] ≡目录页请求:1',
        '[10:00:06] ≡获取成功:https://a.com/toc/1 (200) 120ms',
        '[10:00:06] ◇章节总数:20',
        '[10:00:07] ︾开始解析正文页',
        '[10:00:08] ≡正文页请求:1',
        '[10:00:08] ≡获取成功:https://a.com/c1 (200) 88ms',
        '[10:00:09] ◇分页:2 提取总长:3000 清理后总长:2800',
        '[10:00:09] ≡正文翻页结束：无可用下一页',
      ],
      errorLines: const [],
    );

    final request = summary['request'] as Map<String, dynamic>;
    expect(request['total'], 3);
    expect(request['failed'], 0);

    final stages = request['stages'] as List<dynamic>;
    expect(stages, isNotEmpty);

    final first = stages.first as Map<String, dynamic>;
    expect(first['stage'], 'search');
    expect(first['statusCode'], 200);
    expect(first['cookieJarEnabled'], true);
    final headers = first['requestHeaders'] as Map<String, dynamic>;
    expect(headers['User-Agent'], 'SoupReader/1.0');
    expect((headers['Cookie'] as String).contains('***'), isTrue);

    final parse = summary['parse'] as Map<String, dynamic>;
    expect(parse['booksTotal'], 3);
    expect(parse['chaptersTotal'], 20);
    expect(parse['contentPages'], 2);
    expect(parse['contentExtractedLength'], 3000);
    expect(parse['contentCleanedLength'], 2800);
    expect(parse['contentStopReason'], '无可用下一页');

    final diagnosis = summary['diagnosis'] as Map<String, dynamic>;
    expect(diagnosis['primary'], 'ok');
    final labels = diagnosis['labels'] as List<dynamic>;
    expect(labels, contains('ok'));
  });

  test('collects failed request and stage errors', () {
    final summary = SourceDebugSummaryParser.build(
      logLines: const [
        '︾开始解析正文页',
        '≡正文页请求:2',
        '└请求头（CookieJar=关）',
        'Referer: https://a.com/book/1',
        '≡请求失败:https://a.com/c2 (403) 666ms',
      ],
      debugError: '调试失败：HTTP 403',
      errorLines: const [
        'HTTP 状态码异常：403',
        '提示：403 多为反爬',
      ],
    );

    final request = summary['request'] as Map<String, dynamic>;
    expect(request['total'], 1);
    expect(request['failed'], 1);

    final stages = request['stages'] as List<dynamic>;
    final stage = stages.single as Map<String, dynamic>;
    expect(stage['stage'], 'content');
    expect(stage['requestIndex'], 2);
    expect(stage['statusCode'], 403);
    expect(stage['ok'], false);

    final errors = summary['errors'] as Map<String, dynamic>;
    expect(errors['debugError'], '调试失败：HTTP 403');
    final stageErrors = errors['stageErrors'] as List<dynamic>;
    expect(stageErrors, contains('HTTP 状态码异常：403'));

    final diagnosis = summary['diagnosis'] as Map<String, dynamic>;
    expect(diagnosis['primary'], 'request_failure');
    final labels = diagnosis['labels'] as List<dynamic>;
    expect(labels, contains('request_failure'));
  });

  test('marks paging interrupted when next chapter block is triggered', () {
    final summary = SourceDebugSummaryParser.build(
      logLines: const [
        '︾开始解析正文页',
        '≡正文页请求:1',
        '≡获取成功:https://a.com/c1 (200) 99ms',
        '≡命中下一章链接，停止正文翻页',
        '◇分页:1 提取总长:1000 清理后总长:980',
      ],
    );

    final parse = summary['parse'] as Map<String, dynamic>;
    expect(parse['stoppedByNextChapter'], true);

    final diagnosis = summary['diagnosis'] as Map<String, dynamic>;
    final labels = diagnosis['labels'] as List<dynamic>;
    expect(labels, contains('paging_interrupted'));
  });
}
