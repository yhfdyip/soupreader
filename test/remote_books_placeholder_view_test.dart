import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'package:soupreader/app/theme/shadcn_theme.dart';
import 'package:soupreader/core/models/app_settings.dart';
import 'package:soupreader/core/services/exception_log_service.dart';
import 'package:soupreader/core/services/settings_service.dart';
import 'package:soupreader/features/bookshelf/services/remote_books_service.dart';
import 'package:soupreader/features/bookshelf/views/remote_books_placeholder_view.dart';

void main() {
  testWidgets('RemoteBooksPlaceholderView 刷新动作重载当前目录',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final settingsService = SettingsService();
    await settingsService.init();
    await settingsService.saveAppSettings(
      const AppSettings(
        webDavUrl: 'https://dav.example.com/dav/',
        webDavAccount: 'demo',
        webDavPassword: 'pass',
      ),
    );

    var requestCount = 0;
    final service = RemoteBooksService(
      propfindHandler: ({
        required Uri uri,
        required AppSettings settings,
        required String payload,
      }) async {
        requestCount++;
        final data = requestCount == 1
            ? '''<?xml version="1.0" encoding="utf-8"?>
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
    <d:href>/dav/books/alpha/</d:href>
    <d:propstat><d:prop>
      <d:displayname>alpha</d:displayname>
      <d:resourcetype><d:collection/></d:resourcetype>
      <d:getcontentlength>0</d:getcontentlength>
      <d:getlastmodified>Wed, 22 Oct 2015 07:28:00 GMT</d:getlastmodified>
    </d:prop></d:propstat>
  </d:response>
</d:multistatus>'''
            : '''<?xml version="1.0" encoding="utf-8"?>
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
    <d:href>/dav/books/beta.txt</d:href>
    <d:propstat><d:prop>
      <d:displayname>beta.txt</d:displayname>
      <d:getcontenttype>text/plain</d:getcontenttype>
      <d:resourcetype></d:resourcetype>
      <d:getcontentlength>128</d:getcontentlength>
      <d:getlastmodified>Wed, 23 Oct 2015 07:28:00 GMT</d:getlastmodified>
    </d:prop></d:propstat>
  </d:response>
</d:multistatus>''';
        return Response<dynamic>(
          requestOptions: RequestOptions(path: uri.toString()),
          statusCode: 207,
          data: data,
        );
      },
    );

    await tester.pumpWidget(
      ShadApp.custom(
        theme: AppShadcnTheme.light(),
        darkTheme: AppShadcnTheme.light(),
        appBuilder: (context) {
          return CupertinoApp(
            home: RemoteBooksPlaceholderView(
              remoteBooksService: service,
              settingsService: settingsService,
            ),
            builder: (context, child) => ShadAppBuilder(child: child!),
          );
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(requestCount, 1);
    expect(find.text('alpha'), findsOneWidget);

    await tester.tap(find.byIcon(CupertinoIcons.refresh));
    await tester.pumpAndSettle();

    expect(requestCount, 2);
    expect(find.text('beta.txt'), findsOneWidget);
  });

  testWidgets('RemoteBooksPlaceholderView 展示排序入口与排序菜单',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final settingsService = SettingsService();
    await settingsService.init();
    await settingsService.saveAppSettings(
      const AppSettings(
        webDavUrl: 'https://dav.example.com/dav/',
        webDavAccount: 'demo',
        webDavPassword: 'pass',
      ),
    );

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
</d:multistatus>''',
        );
      },
    );

    await tester.pumpWidget(
      ShadApp.custom(
        theme: AppShadcnTheme.light(),
        darkTheme: AppShadcnTheme.light(),
        appBuilder: (context) {
          return CupertinoApp(
            home: RemoteBooksPlaceholderView(
              remoteBooksService: service,
              settingsService: settingsService,
            ),
            builder: (context, child) => ShadAppBuilder(child: child!),
          );
        },
      ),
    );
    await tester.pumpAndSettle();

    final sortAction = find.byIcon(CupertinoIcons.sort_down);
    expect(sortAction, findsOneWidget);

    await tester.tap(sortAction);
    await tester.pumpAndSettle();

    expect(find.text('排序'), findsOneWidget);
    expect(find.text('名称排序'), findsOneWidget);
    expect(find.text('更新时间排序'), findsOneWidget);

    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();

    expect(find.text('排序'), findsNothing);
  });

  testWidgets('RemoteBooksPlaceholderView 服务器配置关闭后重载当前目录',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final settingsService = SettingsService();
    await settingsService.init();
    await settingsService.saveAppSettings(
      const AppSettings(
        webDavUrl: 'https://dav.example.com/dav/',
        webDavAccount: 'demo',
        webDavPassword: 'pass',
      ),
    );

    var requestCount = 0;
    final requestedUrls = <String>[];
    final service = RemoteBooksService(
      propfindHandler: ({
        required Uri uri,
        required AppSettings settings,
        required String payload,
      }) async {
        requestCount++;
        requestedUrls.add(uri.toString());
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
</d:multistatus>''',
        );
      },
    );

    await tester.pumpWidget(
      ShadApp.custom(
        theme: AppShadcnTheme.light(),
        darkTheme: AppShadcnTheme.light(),
        appBuilder: (context) {
          return CupertinoApp(
            home: RemoteBooksPlaceholderView(
              remoteBooksService: service,
              settingsService: settingsService,
            ),
            builder: (context, child) => ShadAppBuilder(child: child!),
          );
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(requestCount, 1);
    expect(
      requestedUrls.last,
      'https://dav.example.com/dav/books/',
    );

    await tester.tap(find.byIcon(CupertinoIcons.ellipsis));
    await tester.pumpAndSettle();
    expect(find.text('服务器配置'), findsOneWidget);

    await tester.tap(find.text('服务器配置'));
    await tester.pumpAndSettle();

    expect(find.text('服务器配置'), findsOneWidget);
    await tester.tap(find.text('服务器地址'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(CupertinoTextField),
      'https://dav.next.example.com/root/',
    );
    await tester.tap(find.widgetWithText(CupertinoDialogAction, '保存'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('好'));
    await tester.pumpAndSettle();

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(requestCount, 2);
    expect(
      requestedUrls.last,
      'https://dav.next.example.com/root/books/',
    );
  });

  testWidgets('RemoteBooksPlaceholderView 更多菜单帮助动作打开 WebDav 帮助文档',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final settingsService = SettingsService();
    await settingsService.init();
    await settingsService.saveAppSettings(
      const AppSettings(
        webDavUrl: 'https://dav.example.com/dav/',
        webDavAccount: 'demo',
        webDavPassword: 'pass',
      ),
    );

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
</d:multistatus>''',
        );
      },
    );

    await tester.pumpWidget(
      ShadApp.custom(
        theme: AppShadcnTheme.light(),
        darkTheme: AppShadcnTheme.light(),
        appBuilder: (context) {
          return CupertinoApp(
            home: RemoteBooksPlaceholderView(
              remoteBooksService: service,
              settingsService: settingsService,
            ),
            builder: (context, child) => ShadAppBuilder(child: child!),
          );
        },
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(CupertinoIcons.ellipsis));
    await tester.pumpAndSettle();
    expect(find.text('帮助'), findsOneWidget);

    await tester.tap(find.text('帮助'));
    await tester.pumpAndSettle();

    expect(find.text('帮助'), findsOneWidget);
    expect(find.textContaining('WebDav 书籍简明使用教程'), findsOneWidget);
  });

  testWidgets('RemoteBooksPlaceholderView 更多菜单日志动作打开日志弹层',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await ExceptionLogService().clear();
    final settingsService = SettingsService();
    await settingsService.init();
    await settingsService.saveAppSettings(
      const AppSettings(
        webDavUrl: 'https://dav.example.com/dav/',
        webDavAccount: 'demo',
        webDavPassword: 'pass',
      ),
    );

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
</d:multistatus>''',
        );
      },
    );

    await tester.pumpWidget(
      ShadApp.custom(
        theme: AppShadcnTheme.light(),
        darkTheme: AppShadcnTheme.light(),
        appBuilder: (context) {
          return CupertinoApp(
            home: RemoteBooksPlaceholderView(
              remoteBooksService: service,
              settingsService: settingsService,
            ),
            builder: (context, child) => ShadAppBuilder(child: child!),
          );
        },
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(CupertinoIcons.ellipsis));
    await tester.pumpAndSettle();
    expect(find.text('日志'), findsOneWidget);

    await tester.tap(find.text('日志'));
    await tester.pumpAndSettle();

    expect(find.text('清空'), findsOneWidget);
    expect(find.text('暂无日志'), findsOneWidget);
    expect(find.text('异常日志'), findsNothing);
  });

  testWidgets('RemoteBooksPlaceholderView 名称排序按 legado 语义切换升降序',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final settingsService = SettingsService();
    await settingsService.init();
    await settingsService.saveAppSettings(
      const AppSettings(
        webDavUrl: 'https://dav.example.com/dav/',
        webDavAccount: 'demo',
        webDavPassword: 'pass',
      ),
    );

    var requestCount = 0;
    final service = RemoteBooksService(
      propfindHandler: ({
        required Uri uri,
        required AppSettings settings,
        required String payload,
      }) async {
        requestCount++;
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
      <d:getlastmodified>Wed, 24 Oct 2015 07:28:00 GMT</d:getlastmodified>
    </d:prop></d:propstat>
  </d:response>
  <d:response>
    <d:href>/dav/books/alpha/</d:href>
    <d:propstat><d:prop>
      <d:displayname>alpha</d:displayname>
      <d:resourcetype><d:collection/></d:resourcetype>
      <d:getcontentlength>0</d:getcontentlength>
      <d:getlastmodified>Wed, 25 Oct 2015 07:28:00 GMT</d:getlastmodified>
    </d:prop></d:propstat>
  </d:response>
  <d:response>
    <d:href>/dav/books/b10.txt</d:href>
    <d:propstat><d:prop>
      <d:displayname>b10.txt</d:displayname>
      <d:getcontenttype>text/plain</d:getcontenttype>
      <d:resourcetype></d:resourcetype>
      <d:getcontentlength>128</d:getcontentlength>
      <d:getlastmodified>Wed, 26 Oct 2015 07:28:00 GMT</d:getlastmodified>
    </d:prop></d:propstat>
  </d:response>
  <d:response>
    <d:href>/dav/books/b2.txt</d:href>
    <d:propstat><d:prop>
      <d:displayname>b2.txt</d:displayname>
      <d:getcontenttype>text/plain</d:getcontenttype>
      <d:resourcetype></d:resourcetype>
      <d:getcontentlength>96</d:getcontentlength>
      <d:getlastmodified>Wed, 23 Oct 2015 07:28:00 GMT</d:getlastmodified>
    </d:prop></d:propstat>
  </d:response>
  <d:response>
    <d:href>/dav/books/a.txt</d:href>
    <d:propstat><d:prop>
      <d:displayname>a.txt</d:displayname>
      <d:getcontenttype>text/plain</d:getcontenttype>
      <d:resourcetype></d:resourcetype>
      <d:getcontentlength>64</d:getcontentlength>
      <d:getlastmodified>Wed, 22 Oct 2015 07:28:00 GMT</d:getlastmodified>
    </d:prop></d:propstat>
  </d:response>
</d:multistatus>''',
        );
      },
    );

    await tester.pumpWidget(
      ShadApp.custom(
        theme: AppShadcnTheme.light(),
        darkTheme: AppShadcnTheme.light(),
        appBuilder: (context) {
          return CupertinoApp(
            home: RemoteBooksPlaceholderView(
              remoteBooksService: service,
              settingsService: settingsService,
            ),
            builder: (context, child) => ShadAppBuilder(child: child!),
          );
        },
      ),
    );
    await tester.pumpAndSettle();
    expect(requestCount, 1);

    double topOf(String label) {
      return tester.getTopLeft(find.text(label).first).dy;
    }

    await tester.tap(find.byIcon(CupertinoIcons.sort_down));
    await tester.pumpAndSettle();
    await tester.tap(find.text('名称排序'));
    await tester.pumpAndSettle();

    expect(requestCount, 2);
    expect(topOf('alpha') < topOf('zeta'), isTrue);
    expect(topOf('a.txt') < topOf('b2.txt'), isTrue);
    expect(topOf('b2.txt') < topOf('b10.txt'), isTrue);

    await tester.tap(find.byIcon(CupertinoIcons.sort_down));
    await tester.pumpAndSettle();
    await tester.tap(find.text('名称排序'));
    await tester.pumpAndSettle();

    expect(requestCount, 3);
    expect(topOf('zeta') < topOf('alpha'), isTrue);
    expect(topOf('b10.txt') < topOf('b2.txt'), isTrue);
    expect(topOf('b2.txt') < topOf('a.txt'), isTrue);
  });

  testWidgets('RemoteBooksPlaceholderView 更新时间排序按 legado 语义切换升降序',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final settingsService = SettingsService();
    await settingsService.init();
    await settingsService.saveAppSettings(
      const AppSettings(
        webDavUrl: 'https://dav.example.com/dav/',
        webDavAccount: 'demo',
        webDavPassword: 'pass',
      ),
    );

    var requestCount = 0;
    final service = RemoteBooksService(
      propfindHandler: ({
        required Uri uri,
        required AppSettings settings,
        required String payload,
      }) async {
        requestCount++;
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
      <d:getlastmodified>Wed, 24 Oct 2015 07:28:00 GMT</d:getlastmodified>
    </d:prop></d:propstat>
  </d:response>
  <d:response>
    <d:href>/dav/books/alpha/</d:href>
    <d:propstat><d:prop>
      <d:displayname>alpha</d:displayname>
      <d:resourcetype><d:collection/></d:resourcetype>
      <d:getcontentlength>0</d:getcontentlength>
      <d:getlastmodified>Wed, 25 Oct 2015 07:28:00 GMT</d:getlastmodified>
    </d:prop></d:propstat>
  </d:response>
  <d:response>
    <d:href>/dav/books/b10.txt</d:href>
    <d:propstat><d:prop>
      <d:displayname>b10.txt</d:displayname>
      <d:getcontenttype>text/plain</d:getcontenttype>
      <d:resourcetype></d:resourcetype>
      <d:getcontentlength>128</d:getcontentlength>
      <d:getlastmodified>Wed, 26 Oct 2015 07:28:00 GMT</d:getlastmodified>
    </d:prop></d:propstat>
  </d:response>
  <d:response>
    <d:href>/dav/books/b2.txt</d:href>
    <d:propstat><d:prop>
      <d:displayname>b2.txt</d:displayname>
      <d:getcontenttype>text/plain</d:getcontenttype>
      <d:resourcetype></d:resourcetype>
      <d:getcontentlength>96</d:getcontentlength>
      <d:getlastmodified>Wed, 23 Oct 2015 07:28:00 GMT</d:getlastmodified>
    </d:prop></d:propstat>
  </d:response>
  <d:response>
    <d:href>/dav/books/a.txt</d:href>
    <d:propstat><d:prop>
      <d:displayname>a.txt</d:displayname>
      <d:getcontenttype>text/plain</d:getcontenttype>
      <d:resourcetype></d:resourcetype>
      <d:getcontentlength>64</d:getcontentlength>
      <d:getlastmodified>Wed, 22 Oct 2015 07:28:00 GMT</d:getlastmodified>
    </d:prop></d:propstat>
  </d:response>
</d:multistatus>''',
        );
      },
    );

    await tester.pumpWidget(
      ShadApp.custom(
        theme: AppShadcnTheme.light(),
        darkTheme: AppShadcnTheme.light(),
        appBuilder: (context) {
          return CupertinoApp(
            home: RemoteBooksPlaceholderView(
              remoteBooksService: service,
              settingsService: settingsService,
            ),
            builder: (context, child) => ShadAppBuilder(child: child!),
          );
        },
      ),
    );
    await tester.pumpAndSettle();
    expect(requestCount, 1);

    double topOf(String label) {
      return tester.getTopLeft(find.text(label).first).dy;
    }

    await tester.tap(find.byIcon(CupertinoIcons.sort_down));
    await tester.pumpAndSettle();
    await tester.tap(find.text('名称排序'));
    await tester.pumpAndSettle();
    expect(requestCount, 2);

    await tester.tap(find.byIcon(CupertinoIcons.sort_down));
    await tester.pumpAndSettle();
    await tester.tap(find.text('更新时间排序'));
    await tester.pumpAndSettle();

    expect(requestCount, 3);
    expect(topOf('zeta') < topOf('alpha'), isTrue);
    expect(topOf('a.txt') < topOf('b2.txt'), isTrue);
    expect(topOf('b2.txt') < topOf('b10.txt'), isTrue);

    await tester.tap(find.byIcon(CupertinoIcons.sort_down));
    await tester.pumpAndSettle();
    await tester.tap(find.text('更新时间排序'));
    await tester.pumpAndSettle();

    expect(requestCount, 4);
    expect(topOf('alpha') < topOf('zeta'), isTrue);
    expect(topOf('b10.txt') < topOf('b2.txt'), isTrue);
    expect(topOf('b2.txt') < topOf('a.txt'), isTrue);
  });
}
