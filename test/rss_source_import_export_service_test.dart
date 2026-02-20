import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:soupreader/features/rss/services/rss_source_import_export_service.dart';

void main() {
  group('RssSourceImportExportService', () {
    final service = RssSourceImportExportService();

    test('importFromJson dedups by sourceUrl and tracks warnings', () {
      final json = '''
[
  {"sourceUrl":"https://a.com","sourceName":"A"},
  {"sourceUrl":"https://a.com","sourceName":"A2"},
  {"sourceUrl":"https://b.com","sourceName":"B"},
  {"sourceName":"MissingUrl"},
  "bad-item"
]
''';

      final result = service.importFromJson(json);

      expect(result.success, isTrue);
      expect(result.importCount, 2);
      expect(result.totalInputCount, 5);
      expect(result.invalidCount, 2);
      expect(result.duplicateCount, 1);
      expect(
        result.sources.map((e) => e.sourceUrl).toList(),
        ['https://a.com', 'https://b.com'],
      );
      expect(result.sources.first.sourceName, 'A2');
      expect(result.warnings, isNotEmpty);
    });

    test('importFromJson keeps raw json mapping by source url', () {
      final json = '''
[
  {"sourceUrl":"https://raw.com","sourceName":"Raw1","x-extra":"1"},
  {"sourceUrl":"https://raw.com","sourceName":"Raw2","x-extra":"2"}
]
''';

      final result = service.importFromJson(json);

      expect(result.success, isTrue);
      final rawJson = result.rawJsonForSourceUrl('https://raw.com');
      expect(rawJson, isNotNull);

      final rawMap = jsonDecode(rawJson!) as Map<String, dynamic>;
      expect(rawMap['sourceName'], 'Raw2');
      expect(rawMap['x-extra'], '2');
    });

    test('importFromJson supports nested json string payload', () {
      final payload =
          '"[{\\"sourceUrl\\":\\"https://c.com\\",\\"sourceName\\":\\"C\\"}]"';

      final result = service.importFromJson(payload);

      expect(result.success, isTrue);
      expect(result.importCount, 1);
      expect(result.sources.first.sourceUrl, 'https://c.com');
    });

    test('importFromJson supports multi-level nested json string payload', () {
      final inner = '[{"sourceUrl":"https://d.com","sourceName":"D"}]';
      final payload = jsonEncode(jsonEncode(inner));

      final result = service.importFromJson(payload);

      expect(result.success, isTrue);
      expect(result.importCount, 1);
      expect(result.sources.first.sourceUrl, 'https://d.com');
      expect(result.sources.first.sourceName, 'D');
    });

    test('importFromJson supports utf8 bom prefix payload', () {
      final payload = '\uFEFF{"sourceUrl":"https://e.com","sourceName":"E"}';

      final result = service.importFromJson(payload);

      expect(result.success, isTrue);
      expect(result.importCount, 1);
      expect(result.sources.first.sourceUrl, 'https://e.com');
      expect(result.sources.first.sourceName, 'E');
    });

    test('importFromJson fails on unsupported json shape', () {
      final result = service.importFromJson('12345');

      expect(result.success, isFalse);
      expect(result.errorMessage, contains('JSON格式不支持或无有效订阅源'));
    });

    test('importFromUrl adds redirect warning when realUri changed', () async {
      final service = RssSourceImportExportService(
        isWeb: false,
        httpFetcher: (uri, {required requestWithoutUa}) async {
          return Response<String>(
            requestOptions: RequestOptions(path: uri.toString()),
            statusCode: 200,
            data: '[{"sourceUrl":"https://redirected.example","sourceName":"R"}]',
            isRedirect: true,
            redirects: <RedirectRecord>[
              RedirectRecord(
                302,
                'GET',
                Uri.parse('https://redirected.example/source.json'),
              ),
            ],
          );
        },
      );

      final result = await service.importFromUrl('https://origin.example/s.json');

      expect(result.success, isTrue);
      expect(result.importCount, 1);
      expect(result.warnings, isNotEmpty);
      expect(result.warnings.join('\n'), contains('已跟随重定向'));
      expect(result.warnings.join('\n'), contains('https://origin.example/s.json'));
      expect(
        result.warnings.join('\n'),
        contains('https://redirected.example/source.json'),
      );
    });

    test('importFromUrl returns actionable CORS hint on web', () async {
      final service = RssSourceImportExportService(
        isWeb: true,
        httpFetcher: (_, {required requestWithoutUa}) async {
          throw DioException(
            requestOptions: RequestOptions(path: 'https://blocked.example'),
            type: DioExceptionType.connectionError,
            message: 'XMLHttpRequest error: No Access-Control-Allow-Origin header',
          );
        },
      );

      final result = await service.importFromUrl('https://blocked.example/s.json');

      expect(result.success, isFalse);
      expect(result.errorMessage, contains('跨域限制（CORS）'));
      expect(result.errorMessage, contains('扫码导入'));
      expect(result.errorMessage, contains('文件导入'));
    });
  });
}
