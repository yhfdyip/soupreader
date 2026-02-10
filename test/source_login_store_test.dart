import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soupreader/core/services/source_login_store.dart';

void main() {
  group('SourceLoginStore', () {
    const sourceKey = 'https://example.com/source.json';

    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('put/get/remove login header map', () async {
      await SourceLoginStore.putLoginHeaderMap(sourceKey, {
        'Cookie': 'sid=abc',
        'Authorization': 'Bearer token',
      });

      final map = await SourceLoginStore.getLoginHeaderMap(sourceKey);
      expect(map, isNotNull);
      expect(map!['Cookie'], 'sid=abc');
      expect(map['Authorization'], 'Bearer token');

      await SourceLoginStore.removeLoginHeader(sourceKey);
      final removed = await SourceLoginStore.getLoginHeaderMap(sourceKey);
      expect(removed, isNull);
    });

    test('putLoginHeaderJson validates json object', () async {
      expect(
        () => SourceLoginStore.putLoginHeaderJson(sourceKey, '[1,2,3]'),
        throwsA(isA<FormatException>()),
      );

      await SourceLoginStore.putLoginHeaderJson(
        sourceKey,
        '{"Cookie":"sid=xyz","X-Test":"1"}',
      );
      final map = await SourceLoginStore.getLoginHeaderMap(sourceKey);
      expect(map?['Cookie'], 'sid=xyz');
      expect(map?['X-Test'], '1');
    });

    test('put/get/remove login info', () async {
      await SourceLoginStore.putLoginInfo(sourceKey, '{"user":"demo"}');
      final info = await SourceLoginStore.getLoginInfo(sourceKey);
      expect(info, '{"user":"demo"}');

      await SourceLoginStore.removeLoginInfo(sourceKey);
      final removed = await SourceLoginStore.getLoginInfo(sourceKey);
      expect(removed, isNull);
    });
  });
}
