import 'package:flutter_test/flutter_test.dart';

import 'package:soupreader/features/source/services/rule_parser_engine.dart';
import 'package:soupreader/features/source/services/source_availability_diagnosis_service.dart';

void main() {
  const service = SourceAvailabilityDiagnosisService();

  FetchDebugResult buildFetch({
    String? body,
    int? statusCode,
    String? error,
    int elapsedMs = 120,
  }) {
    return FetchDebugResult(
      requestUrl: 'https://example.com/search?q=book',
      finalUrl: 'https://example.com/search?q=book',
      statusCode: statusCode,
      elapsedMs: elapsedMs,
      responseLength: body?.length ?? 0,
      responseSnippet: body,
      requestHeaders: const <String, String>{},
      headersWarning: null,
      responseHeaders: const <String, String>{},
      error: error,
      body: body,
    );
  }

  SearchDebugResult buildSearchDebug({
    required FetchDebugResult fetch,
    required int listCount,
    String? error,
  }) {
    return SearchDebugResult(
      fetch: fetch,
      requestType: DebugRequestType.search,
      requestUrlRule: 'https://example.com/search?q={{key}}',
      listRule: '.book-list > li',
      listCount: listCount,
      results: const <SearchResult>[],
      fieldSample: const <String, String>{},
      error: error,
    );
  }

  test('diagnoseSearch marks request failure on fetch error', () {
    final debug = buildSearchDebug(
      fetch: buildFetch(statusCode: 403, body: null, error: 'HTTP 403'),
      listCount: 0,
      error: 'HTTP 403',
    );

    final diagnosis = service.diagnoseSearch(debug: debug, keyword: '我的');

    expect(diagnosis.primary, 'request_failure');
    expect(diagnosis.labels, contains('request_failure'));
  });

  test('diagnoseSearch marks parse failure when list is empty', () {
    final debug = buildSearchDebug(
      fetch: buildFetch(statusCode: 200, body: '<html>ok</html>'),
      listCount: 0,
      error: null,
    );

    final diagnosis = service.diagnoseSearch(debug: debug, keyword: '测试');

    expect(diagnosis.primary, 'parse_failure');
    expect(diagnosis.labels, contains('parse_failure'));
  });

  test('diagnoseSearch marks ok when request and list are normal', () {
    final debug = buildSearchDebug(
      fetch: buildFetch(statusCode: 200, body: '<html>ok</html>'),
      listCount: 3,
      error: null,
    );

    final diagnosis = service.diagnoseSearch(debug: debug, keyword: '测试');

    expect(diagnosis.primary, 'ok');
    expect(diagnosis.labels, contains('ok'));
  });

  test('diagnoseMissingRule returns parse failure label', () {
    final diagnosis = service.diagnoseMissingRule();
    expect(diagnosis.primary, 'parse_failure');
  });

  test('diagnoseException returns request failure label', () {
    final diagnosis = service.diagnoseException(Exception('network down'));
    expect(diagnosis.primary, 'request_failure');
  });
}
