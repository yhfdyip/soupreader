import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soupreader/features/source/models/book_source.dart';
import 'package:soupreader/features/source/services/rule_parser_engine.dart';

void main() {
  group('RuleParserEngine stage js compat', () {
    test('ruleToc.preUpdateJs rewrites response before list extraction',
        () async {
      final engine = RuleParserEngine();
      final source = BookSource(
        bookSourceUrl: 'https://example.com',
        bookSourceName: 'test',
        enabledCookieJar: false,
        ruleToc: const TocRule(
          preUpdateJs:
              'result = JSON.stringify({list:[{name:"C1",url:"/c1"}]}); result',
          chapterList: r'@Json:$.list[*]',
          chapterName: r'@Json:$.name',
          chapterUrl: r'@Json:$.url',
        ),
      );

      final responses = <String, String>{
        'https://example.com/toc': '<html><body>old toc html</body></html>',
      };

      final dio = RuleParserEngine.debugDioForTest();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            final body = responses[options.uri.toString()];
            if (body != null) {
              handler.resolve(
                Response<List<int>>(
                  requestOptions: options,
                  data: utf8.encode(body),
                  statusCode: 200,
                ),
              );
              return;
            }
            handler.reject(
              DioException(
                requestOptions: options,
                error: 'missing mock for ${options.uri}',
              ),
            );
          },
        ),
      );

      try {
        final toc = await engine.getToc(source, '/toc');
        expect(toc.map((e) => e.name).toList(), ['C1']);
        expect(toc.map((e) => e.url).toList(), ['https://example.com/c1']);
      } finally {
        dio.interceptors.removeLast();
      }
    });

    test('ruleContent.webJs rewrites response before content extraction',
        () async {
      final engine = RuleParserEngine();
      final source = BookSource(
        bookSourceUrl: 'https://example.com',
        bookSourceName: 'test',
        enabledCookieJar: false,
        ruleContent: const ContentRule(
          webJs: 'result = JSON.stringify({content:"正文A"}); result',
          content: r'@Json:$.content',
        ),
      );

      final responses = <String, String>{
        'https://example.com/chapter/1':
            '<html><body><div id="content">old</div></body></html>',
      };

      final dio = RuleParserEngine.debugDioForTest();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            final body = responses[options.uri.toString()];
            if (body != null) {
              handler.resolve(
                Response<List<int>>(
                  requestOptions: options,
                  data: utf8.encode(body),
                  statusCode: 200,
                ),
              );
              return;
            }
            handler.reject(
              DioException(
                requestOptions: options,
                error: 'missing mock for ${options.uri}',
              ),
            );
          },
        ),
      );

      try {
        final content = await engine.getContent(source, '/chapter/1');
        expect(content, '正文A');
      } finally {
        dio.interceptors.removeLast();
      }
    });

    test('ruleContent.replaceRegex keeps later rules when one is invalid',
        () async {
      final engine = RuleParserEngine();
      final source = BookSource(
        bookSourceUrl: 'https://example.com',
        bookSourceName: 'test',
        enabledCookieJar: false,
        ruleContent: const ContentRule(
          content: 'div#content@text',
          // 第二条正则非法；第三条应继续生效。
          replaceRegex: r'第##D##(坏正则##X##章##Z',
        ),
      );

      final responses = <String, String>{
        'https://example.com/chapter/1':
            '<html><body><div id="content">第1章</div></body></html>',
      };

      final dio = RuleParserEngine.debugDioForTest();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            final body = responses[options.uri.toString()];
            if (body != null) {
              handler.resolve(
                Response<List<int>>(
                  requestOptions: options,
                  data: utf8.encode(body),
                  statusCode: 200,
                ),
              );
              return;
            }
            handler.reject(
              DioException(
                requestOptions: options,
                error: 'missing mock for ${options.uri}',
              ),
            );
          },
        ),
      );

      try {
        final content = await engine.getContent(source, '/chapter/1');
        expect(content, 'D1Z');
      } finally {
        dio.interceptors.removeLast();
      }
    });
  });
}
