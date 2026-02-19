import 'package:flutter_test/flutter_test.dart';

import 'package:soupreader/features/source/services/source_host_group_helper.dart';

void main() {
  test('groups subdomains into effective host for common domains', () {
    expect(
      SourceHostGroupHelper.groupHost('https://www.example.com/a'),
      'example.com',
    );
    expect(
      SourceHostGroupHelper.groupHost('https://m.api.example.com/list'),
      'example.com',
    );
  });

  test('supports common multi-part suffix domains', () {
    expect(
      SourceHostGroupHelper.groupHost('https://a.b.foo.com.cn/path'),
      'foo.com.cn',
    );
    expect(
      SourceHostGroupHelper.groupHost('https://reader.news.co.uk/chapter'),
      'news.co.uk',
    );
  });

  test('keeps ip hosts and marks invalid urls', () {
    expect(
      SourceHostGroupHelper.groupHost('https://127.0.0.1:8080/path'),
      '127.0.0.1',
    );
    expect(SourceHostGroupHelper.groupHost('not-a-url'), '#');
    expect(SourceHostGroupHelper.groupHost('https://[240e:390:abcd::1]/a'),
        '240e:390:abcd::1');
  });

  test('only accepts http and https like legacy', () {
    expect(
      SourceHostGroupHelper.groupHost('ftp://sub.a.example.com/path'),
      '#',
    );
    expect(
      SourceHostGroupHelper.groupHost('ws://sub.a.example.com/path'),
      '#',
    );
  });

  test('comma suffix url falls back to #', () {
    expect(
      SourceHostGroupHelper.groupHost('https://example.com,{{key}}'),
      '#',
    );
  });
}
