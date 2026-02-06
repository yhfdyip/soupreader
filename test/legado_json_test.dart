import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:soupreader/core/utils/legado_json.dart';

void main() {
  group('LegadoJson.encode', () {
    test('strips null keys recursively in maps', () {
      final input = <String, dynamic>{
        'a': 1,
        'b': null,
        'c': {
          'c1': null,
          'c2': 'ok',
          'c3': {
            'x': null,
            'y': 2,
          },
        },
      };

      final text = LegadoJson.encode(input);
      final decoded = json.decode(text) as Map<String, dynamic>;

      expect(decoded.containsKey('b'), isFalse);
      expect((decoded['c'] as Map<String, dynamic>).containsKey('c1'), isFalse);
      expect(
        ((decoded['c'] as Map<String, dynamic>)['c3'] as Map<String, dynamic>)
            .containsKey('x'),
        isFalse,
      );
      expect(decoded['a'], 1);
      expect((decoded['c'] as Map<String, dynamic>)['c2'], 'ok');
      expect(
        ((decoded['c'] as Map<String, dynamic>)['c3'] as Map<String, dynamic>)['y'],
        2,
      );
    });

    test('keeps null elements inside lists', () {
      final input = <String, dynamic>{
        'arr': [1, null, {'k': null, 'v': 2}],
      };

      final decoded = LegadoJson.decode(LegadoJson.encode(input))
          as Map<String, dynamic>;
      final arr = decoded['arr'] as List<dynamic>;

      expect(arr.length, 3);
      expect(arr[1], isNull);
      expect(arr[2], {'v': 2});
    });
  });
}

