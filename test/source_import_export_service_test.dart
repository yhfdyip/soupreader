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

    test('importFromJson supports nested json string payload', () {
      final payload =
          '"[{\\"bookSourceUrl\\":\\"https://c.com\\",\\"bookSourceName\\":\\"C\\"}]"';

      final result = service.importFromJson(payload);

      expect(result.success, isTrue);
      expect(result.importCount, 1);
      expect(result.sources.first.bookSourceUrl, 'https://c.com');
    });

    test('importFromJson fails on unsupported json shape', () {
      final result = service.importFromJson('12345');

      expect(result.success, isFalse);
      expect(result.errorMessage, contains('JSON格式不支持'));
    });
  });
}
