import 'package:flutter_test/flutter_test.dart';
import 'package:soupreader/features/source/models/book_source.dart';

void main() {
  group('Source import conflict logic', () {
    test('skip duplicates keeps only non-conflict items', () {
      final incoming = <BookSource>[
        const BookSource(
          bookSourceUrl: 'https://a.com',
          bookSourceName: 'A',
        ),
        const BookSource(
          bookSourceUrl: 'https://b.com',
          bookSourceName: 'B',
        ),
        const BookSource(
          bookSourceUrl: 'https://c.com',
          bookSourceName: 'C',
        ),
      ];

      final conflictUrls = {'https://a.com', 'https://c.com'};

      final filtered = incoming
          .where((s) => !conflictUrls.contains(s.bookSourceUrl.trim()))
          .toList(growable: false);

      expect(filtered.length, 1);
      expect(filtered.first.bookSourceUrl, 'https://b.com');
      expect(filtered.first.bookSourceName, 'B');
    });
  });
}
