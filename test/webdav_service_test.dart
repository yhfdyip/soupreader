import 'package:flutter_test/flutter_test.dart';

import 'package:soupreader/core/models/app_settings.dart';
import 'package:soupreader/core/services/webdav_service.dart';

void main() {
  group('WebDavService', () {
    final service = WebDavService();

    test('buildRootUrl 按 legado 规则拼接目录并补齐斜杠', () {
      const settings = AppSettings(
        webDavUrl: 'https://dav.example.com/dav',
        webDavDir: 'my-sync/books',
      );
      expect(
        service.buildRootUrl(settings),
        'https://dav.example.com/dav/my-sync/books/',
      );
      expect(
        service.buildBooksRootUrl(settings),
        'https://dav.example.com/dav/my-sync/books/books/',
      );
    });

    test('buildRootUrl 在空地址时回退默认 URL', () {
      const settings = AppSettings(
        webDavUrl: '',
        webDavDir: '',
      );
      expect(service.buildRootUrl(settings), AppSettings.defaultWebDavUrl);
    });

    test('buildBookUploadUrl 对文件名做 URL 编码', () {
      const settings = AppSettings(
        webDavUrl: 'https://dav.example.com/dav/',
      );
      final url = service.buildBookUploadUrl(
        settings,
        fileName: '三体 第一部.txt',
      );
      expect(
        url,
        'https://dav.example.com/dav/books/%E4%B8%89%E4%BD%93%20%E7%AC%AC%E4%B8%80%E9%83%A8.txt',
      );
    });

    test('buildBookProgressUrl 对标 legado 生成进度文件路径', () {
      const settings = AppSettings(
        webDavUrl: 'https://dav.example.com/dav/',
      );
      final url = service.buildBookProgressUrl(
        settings,
        bookTitle: '三体/第一部',
        bookAuthor: '刘慈欣',
      );
      expect(
        url,
        'https://dav.example.com/dav/bookProgress/%E4%B8%89%E4%BD%93_%E7%AC%AC%E4%B8%80%E9%83%A8_%E5%88%98%E6%85%88%E6%AC%A3.json',
      );
    });

    test('hasValidConfig 仅在账号密码齐全时为 true', () {
      expect(
        service.hasValidConfig(const AppSettings()),
        isFalse,
      );
      expect(
        service.hasValidConfig(
          const AppSettings(webDavAccount: 'abc', webDavPassword: '123'),
        ),
        isTrue,
      );
    });
  });
}
