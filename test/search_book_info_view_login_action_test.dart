import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:soupreader/app/theme/shadcn_theme.dart';
import 'package:soupreader/core/database/database_service.dart';
import 'package:soupreader/core/database/repositories/book_repository.dart';
import 'package:soupreader/core/database/repositories/source_repository.dart';
import 'package:soupreader/core/services/settings_service.dart';
import 'package:soupreader/features/bookshelf/models/book.dart';
import 'package:soupreader/features/search/views/search_book_info_view.dart';
import 'package:soupreader/features/source/models/book_source.dart';
import 'package:soupreader/features/source/views/source_login_form_view.dart';

Widget _buildTestApp(Widget home) {
  final shadTheme = AppShadcnTheme.light();
  return ShadApp.custom(
    theme: shadTheme,
    darkTheme: shadTheme,
    appBuilder: (context) {
      final shad = ShadTheme.of(context);
      final cupertinoTheme = CupertinoTheme.of(context).copyWith(
        barBackgroundColor: shad.colorScheme.background.withValues(alpha: 0.92),
      );
      return CupertinoApp(
        theme: cupertinoTheme,
        home: home,
        builder: (context, child) => ShadAppBuilder(child: child!),
      );
    },
  );
}

Book _buildBook({
  required String id,
  required String sourceUrl,
}) {
  return Book(
    id: id,
    title: '登录测试书',
    author: '测试作者',
    sourceUrl: sourceUrl,
    sourceId: sourceUrl,
    bookUrl: 'https://book.example.com/$id',
    isLocal: false,
  );
}

BookSource _buildSource({
  required String sourceUrl,
  required String loginUrl,
  String? loginUi,
}) {
  return BookSource(
    bookSourceUrl: sourceUrl,
    bookSourceName: '登录测试源',
    loginUrl: loginUrl,
    loginUi: loginUi,
  );
}

void main() {
  late Directory tempDir;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues(<String, Object>{});

    tempDir = await Directory.systemTemp.createTemp(
      'soupreader_search_book_info_login_',
    );
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
      return tempDir.path;
    });

    await DatabaseService().init();
    await SettingsService().init();
  });

  tearDownAll(() async {
    try {
      await DatabaseService().close();
    } catch (_) {}
    try {
      await tempDir.delete(recursive: true);
    } catch (_) {}
  });

  setUp(() async {
    await DatabaseService().clearAll();
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await SettingsService().init();
  });

  testWidgets('loginUrl 为空时更多菜单不显示登录入口', (WidgetTester tester) async {
    const sourceUrl = 'https://source-login-empty.example.com';
    final sourceRepo = SourceRepository(DatabaseService());
    final bookRepo = BookRepository(DatabaseService());
    final source = _buildSource(
      sourceUrl: sourceUrl,
      loginUrl: '',
      loginUi: '[{"name":"账号","type":"text"}]',
    );
    final book = _buildBook(
      id: 'book-login-hidden',
      sourceUrl: sourceUrl,
    );

    await tester.runAsync(() async {
      await sourceRepo.addSource(source);
      await bookRepo.addBook(book);
    });

    await tester.pumpWidget(
      _buildTestApp(
        SearchBookInfoView.fromBookshelf(book: book),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 450));

    final moreAction = find.byIcon(CupertinoIcons.ellipsis_circle);
    expect(moreAction, findsOneWidget);
    await tester.tap(moreAction);
    await tester.pumpAndSettle();

    expect(find.text('登录'), findsNothing);
  });

  testWidgets('loginUrl 非空且存在 loginUi 时点击登录进入表单页', (WidgetTester tester) async {
    const sourceUrl = 'https://source-login-ui.example.com';
    final sourceRepo = SourceRepository(DatabaseService());
    final bookRepo = BookRepository(DatabaseService());
    final source = _buildSource(
      sourceUrl: sourceUrl,
      loginUrl: '/login',
      loginUi: '[{"name":"账号","type":"text"}]',
    );
    final book = _buildBook(
      id: 'book-login-ui',
      sourceUrl: sourceUrl,
    );

    await tester.runAsync(() async {
      await sourceRepo.addSource(source);
      await bookRepo.addBook(book);
    });

    await tester.pumpWidget(
      _buildTestApp(
        SearchBookInfoView.fromBookshelf(book: book),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 450));

    final moreAction = find.byIcon(CupertinoIcons.ellipsis_circle);
    expect(moreAction, findsOneWidget);
    await tester.tap(moreAction);
    await tester.pumpAndSettle();

    final loginAction = find.text('登录');
    expect(loginAction, findsOneWidget);
    await tester.tap(loginAction);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 450));

    expect(find.byType(SourceLoginFormView), findsOneWidget);
  });
}
