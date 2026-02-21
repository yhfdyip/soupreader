import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:soupreader/core/models/app_settings.dart';
import 'package:soupreader/features/bookshelf/services/remote_books_service.dart';

void main() {
  group('RemoteBooksService', () {
    test('listCurrentDirectory 过滤当前目录与非书籍文件并保持目录优先', () async {
      final service = RemoteBooksService(
        propfindHandler: ({
          required Uri uri,
          required AppSettings settings,
          required String payload,
        }) async {
          return Response<dynamic>(
            requestOptions: RequestOptions(path: uri.toString()),
            statusCode: 207,
            data: '''<?xml version="1.0" encoding="utf-8"?>
<d:multistatus xmlns:d="DAV:">
  <d:response>
    <d:href>/dav/books/</d:href>
    <d:propstat><d:prop>
      <d:displayname>books</d:displayname>
      <d:resourcetype><d:collection/></d:resourcetype>
      <d:getcontentlength>0</d:getcontentlength>
      <d:getlastmodified>Wed, 21 Oct 2015 07:28:00 GMT</d:getlastmodified>
    </d:prop></d:propstat>
  </d:response>
  <d:response>
    <d:href>/dav/books/zeta/</d:href>
    <d:propstat><d:prop>
      <d:displayname>zeta</d:displayname>
      <d:resourcetype><d:collection/></d:resourcetype>
      <d:getcontentlength>0</d:getcontentlength>
      <d:getlastmodified>Wed, 22 Oct 2015 07:28:00 GMT</d:getlastmodified>
    </d:prop></d:propstat>
  </d:response>
  <d:response>
    <d:href>/dav/books/a.jpg</d:href>
    <d:propstat><d:prop>
      <d:displayname>a.jpg</d:displayname>
      <d:getcontenttype>image/jpeg</d:getcontenttype>
      <d:resourcetype></d:resourcetype>
      <d:getcontentlength>12</d:getcontentlength>
      <d:getlastmodified>Wed, 23 Oct 2015 07:28:00 GMT</d:getlastmodified>
    </d:prop></d:propstat>
  </d:response>
  <d:response>
    <d:href>/dav/books/c.zip</d:href>
    <d:propstat><d:prop>
      <d:displayname>c.zip</d:displayname>
      <d:getcontenttype>application/zip</d:getcontenttype>
      <d:resourcetype></d:resourcetype>
      <d:getcontentlength>120</d:getcontentlength>
      <d:getlastmodified>Wed, 24 Oct 2015 07:28:00 GMT</d:getlastmodified>
    </d:prop></d:propstat>
  </d:response>
  <d:response>
    <d:href>/dav/books/b.txt</d:href>
    <d:propstat><d:prop>
      <d:displayname>b.txt</d:displayname>
      <d:getcontenttype>text/plain</d:getcontenttype>
      <d:resourcetype></d:resourcetype>
      <d:getcontentlength>64</d:getcontentlength>
      <d:getlastmodified>Wed, 25 Oct 2015 07:28:00 GMT</d:getlastmodified>
    </d:prop></d:propstat>
  </d:response>
</d:multistatus>''',
          );
        },
      );

      const settings = AppSettings(
        webDavUrl: 'https://dav.example.com/dav/',
        webDavAccount: 'u',
        webDavPassword: 'p',
      );

      final entries = await service.listCurrentDirectory(settings: settings);
      expect(entries.length, 3);
      expect(entries[0].displayName, 'zeta');
      expect(entries[0].isDirectory, isTrue);
      expect(entries[1].displayName, 'b.txt');
      expect(entries[2].displayName, 'c.zip');
    });
  });
}
