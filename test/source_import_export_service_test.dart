import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soupreader/features/source/services/source_import_export_service.dart';

void main() {
  group('SourceImportExportService', () {
    final service = SourceImportExportService();

    test('importFromJson dedups by bookSourceUrl and tracks warnings', () {
      final json = '''
[
  {"bookSourceUrl":"https://a.com","bookSourceName":"A"},
  {"bookSourceUrl":"https://a.com","bookSourceName":"A2"},
  {"bookSourceUrl":"https://b.com","bookSourceName":"B"},
  {"bookSourceName":"MissingUrl"},
  "bad-item"
]
''';

      final result = service.importFromJson(json);

      expect(result.success, isTrue);
      expect(result.importCount, 2);
      expect(result.totalInputCount, 5);
      expect(result.invalidCount, 2);
      expect(result.duplicateCount, 1);
      expect(result.sources.map((e) => e.bookSourceUrl).toList(),
          ['https://a.com', 'https://b.com']);
      expect(result.sources.first.bookSourceName, 'A2');
      expect(result.warnings, isNotEmpty);
    });

    test('importFromJson keeps raw json mapping by source url', () {
      final json = '''
[
  {"bookSourceUrl":"https://raw.com","bookSourceName":"Raw1","x-extra":"1"},
  {"bookSourceUrl":"https://raw.com","bookSourceName":"Raw2","x-extra":"2"}
]
''';

      final result = service.importFromJson(json);

      expect(result.success, isTrue);
      final rawJson = result.rawJsonForSourceUrl('https://raw.com');
      expect(rawJson, isNotNull);

      final rawMap = jsonDecode(rawJson!) as Map<String, dynamic>;
      expect(rawMap['bookSourceName'], 'Raw2');
      expect(rawMap['x-extra'], '2');
    });

    test('importFromJson supports nested json string payload', () {
      final payload =
          '"[{\\"bookSourceUrl\\":\\"https://c.com\\",\\"bookSourceName\\":\\"C\\"}]"';

      final result = service.importFromJson(payload);

      expect(result.success, isTrue);
      expect(result.importCount, 1);
      expect(result.sources.first.bookSourceUrl, 'https://c.com');
    });

    test('importFromJson supports multi-level nested json string payload', () {
      final inner = '[{"bookSourceUrl":"https://d.com","bookSourceName":"D"}]';
      final payload = jsonEncode(jsonEncode(inner));

      final result = service.importFromJson(payload);

      expect(result.success, isTrue);
      expect(result.importCount, 1);
      expect(result.sources.first.bookSourceUrl, 'https://d.com');
      expect(result.sources.first.bookSourceName, 'D');
    });

    test('importFromJson supports utf8 bom prefix payload', () {
      final payload =
          '\uFEFF{"bookSourceUrl":"https://e.com","bookSourceName":"E"}';

      final result = service.importFromJson(payload);

      expect(result.success, isTrue);
      expect(result.importCount, 1);
      expect(result.sources.first.bookSourceUrl, 'https://e.com');
      expect(result.sources.first.bookSourceName, 'E');
    });

    test('importFromJson fails on unsupported json shape', () {
      final result = service.importFromJson('12345');

      expect(result.success, isFalse);
      expect(result.errorMessage, contains('JSON格式不支持'));
    });

    test('importFromUrl adds redirect warning when realUri changed', () async {
      final service = SourceImportExportService(
        isWeb: false,
        httpFetcher: (uri) async {
          return Response<String>(
            requestOptions: RequestOptions(path: uri.toString()),
            statusCode: 200,
            data:
                '[{"bookSourceUrl":"https://redirected.example","bookSourceName":"R"}]',
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

      final result =
          await service.importFromUrl('https://origin.example/s.json');

      expect(result.success, isTrue);
      expect(result.importCount, 1);
      expect(result.warnings, isNotEmpty);
      expect(result.warnings.join('\n'), contains('已跟随重定向'));
      expect(result.warnings.join('\n'),
          contains('https://origin.example/s.json'));
      expect(
        result.warnings.join('\n'),
        contains('https://redirected.example/source.json'),
      );
    });

    test('importFromUrl returns actionable CORS hint on web', () async {
      final service = SourceImportExportService(
        isWeb: true,
        httpFetcher: (_) async {
          throw DioException(
            requestOptions: RequestOptions(path: 'https://blocked.example'),
            type: DioExceptionType.connectionError,
            message:
                'XMLHttpRequest error: No Access-Control-Allow-Origin header',
          );
        },
      );

      final result =
          await service.importFromUrl('https://blocked.example/s.json');

      expect(result.success, isFalse);
      expect(result.errorMessage, contains('跨域限制（CORS）'));
      expect(result.errorMessage, contains('从剪贴板导入'));
      expect(result.errorMessage, contains('从文件导入'));
    });
  });
}
