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
  required String bookUrl,
}) {
  return Book(
    id: id,
    title: '拷贝目录链接测试书',
    author: '测试作者',
    sourceUrl: sourceUrl,
    sourceId: sourceUrl,
    bookUrl: bookUrl,
    isLocal: false,
  );
}

BookSource _buildSource(String sourceUrl) {
  return BookSource(
    bookSourceUrl: sourceUrl,
    bookSourceName: '拷贝目录链接测试源',
  );
}

void main() {
  late Directory tempDir;
  String? clipboardText;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues(<String, Object>{});

    tempDir = await Directory.systemTemp.createTemp(
      'soupreader_search_book_info_copy_toc_url_',
    );
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
      return tempDir.path;
    });

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform,
            (MethodCall call) async {
      switch (call.method) {
        case 'Clipboard.setData':
          final arguments = (call.arguments as Map<dynamic, dynamic>? ??
              const <dynamic, dynamic>{});
          clipboardText = arguments['text'] as String?;
          return null;
        case 'Clipboard.getData':
          if (clipboardText == null) return null;
          return <String, dynamic>{'text': clipboardText};
        default:
          return null;
      }
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
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  setUp(() async {
    await DatabaseService().clearAll();
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await SettingsService().init();
    clipboardText = null;
  });

  testWidgets('详情页菜单显示拷贝目录 URL 入口', (WidgetTester tester) async {
    const sourceUrl = 'https://source-copy-toc-url-menu.example.com';
    const bookUrl = 'https://book.example.com/copy-toc-url';
    final sourceRepo = SourceRepository(DatabaseService());
    final bookRepo = BookRepository(DatabaseService());
    final book = _buildBook(
      id: 'book-copy-toc-url-menu',
      sourceUrl: sourceUrl,
      bookUrl: bookUrl,
    );

    await tester.runAsync(() async {
      await sourceRepo.addSource(_buildSource(sourceUrl));
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

    expect(find.text('拷贝目录 URL'), findsOneWidget);
    expect(find.text('复制目录链接'), findsNothing);
  });

  testWidgets('目录 URL 为空时仍复制空字符串且不提示链接为空', (WidgetTester tester) async {
    const sourceUrl = 'https://source-copy-toc-url-empty.example.com';
    final sourceRepo = SourceRepository(DatabaseService());
    final bookRepo = BookRepository(DatabaseService());
    final book = _buildBook(
      id: 'book-copy-toc-url-empty',
      sourceUrl: sourceUrl,
      bookUrl: '',
    );

    await tester.runAsync(() async {
      await sourceRepo.addSource(_buildSource(sourceUrl));
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

    await tester.tap(find.text('拷贝目录 URL'));
    await tester.pumpAndSettle();

    expect(find.text('当前目录链接为空'), findsNothing);
    expect(clipboardText, '');
  });
}
