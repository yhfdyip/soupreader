import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soupreader/core/services/source_variable_store.dart';

void main() {
  group('SourceVariableStore', () {
    const sourceKey = 'https://example.com/source.json';

    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('put/get variable', () async {
      await SourceVariableStore.putVariable(sourceKey, '{"token":"abc"}');
      final value = await SourceVariableStore.getVariable(sourceKey);
      expect(value, '{"token":"abc"}');
    });

    test('put empty variable keeps empty string', () async {
      await SourceVariableStore.putVariable(sourceKey, '{"a":1}');
      expect(await SourceVariableStore.getVariable(sourceKey), isNotNull);

      await SourceVariableStore.putVariable(sourceKey, '   ');
      expect(await SourceVariableStore.getVariable(sourceKey), '   ');
    });

    test('remove variable', () async {
      await SourceVariableStore.putVariable(sourceKey, 'x=1');
      await SourceVariableStore.removeVariable(sourceKey);
      final value = await SourceVariableStore.getVariable(sourceKey);
      expect(value, isNull);
    });
  });
}
