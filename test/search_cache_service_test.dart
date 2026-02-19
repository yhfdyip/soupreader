import 'package:flutter_test/flutter_test.dart';

import 'package:soupreader/core/models/app_settings.dart';
import 'package:soupreader/features/search/services/search_cache_service.dart';

void main() {
  test('SearchCacheService 过滤模式缓存键按精准开关归一', () {
    final service = SearchCacheService();

    final keyFromNone = service.buildCacheKey(
      keyword: '  诡秘之主  ',
      filterMode: SearchFilterMode.none,
      scopeSourceUrls: const <String>[
        ' https://b.example.com/source ',
        'https://a.example.com/source',
      ],
    );
    final keyFromNormal = service.buildCacheKey(
      keyword: '诡秘之主',
      filterMode: SearchFilterMode.normal,
      scopeSourceUrls: const <String>[
        'https://a.example.com/source',
        'https://b.example.com/source',
      ],
    );
    final keyFromPrecise = service.buildCacheKey(
      keyword: '诡秘之主',
      filterMode: SearchFilterMode.precise,
      scopeSourceUrls: const <String>[
        'https://a.example.com/source',
        'https://b.example.com/source',
      ],
    );

    expect(keyFromNone, keyFromNormal);
    expect(keyFromPrecise, isNot(keyFromNormal));
    expect(keyFromNormal.startsWith('normal|'), isTrue);
    expect(keyFromPrecise.startsWith('precise|'), isTrue);
  });
}
