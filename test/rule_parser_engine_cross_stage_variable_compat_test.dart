import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soupreader/features/source/models/book_source.dart';
import 'package:soupreader/features/source/services/rule_parser_engine.dart';

void main() {
  group('RuleParserEngine cross-stage variable compat', () {
    test('bookInfo @put value can be reused by toc @get', () async {
      final engine = RuleParserEngine();
      final source = BookSource(
        bookSourceUrl: 'https://example.com',
        bookSourceName: 'test',
        enabledCookieJar: false,
        ruleBookInfo: const BookInfoRule(
          tocUrl: '@put:{"tocPath":"a.toc-next@href"}a.toc@href',
        ),
        ruleToc: const TocRule(
          chapterList: '.item',
          chapterName: '.name@text',
          chapterUrl: '.name@href',
          nextTocUrl: '@get:{tocPath}',
        ),
      );

      final responses = <String, String>{
        'https://example.com/book/1':
            '<html><body><a class="toc" href="/toc?page=1">toc</a><a class="toc-next" href="/toc?page=2">next</a></body></html>',
        'https://example.com/toc?page=1':
            '<html><body><div class="item"><a class="name" href="/c1">C1</a></div></body></html>',
        'https://example.com/toc?page=2':
            '<html><body><div class="item"><a class="name" href="/c2">C2</a></div></body></html>',
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
        final detail = await engine.getBookInfo(source, '/book/1');
        expect(detail, isNotNull);
        expect(detail!.tocUrl, 'https://example.com/toc?page=1');

        final toc = await engine.getToc(
          source,
          detail.tocUrl,
          clearRuntimeVariables: false,
        );

        expect(toc.map((e) => e.name).toList(), ['C1', 'C2']);
        expect(
          toc.map((e) => e.url).toList(),
          ['https://example.com/c1', 'https://example.com/c2'],
        );
      } finally {
        dio.interceptors.removeLast();
      }
    });
  });
}
