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
}) {
  return Book(
    id: id,
    title: '允许更新测试书',
    author: '测试作者',
    sourceUrl: sourceUrl,
    sourceId: sourceUrl,
    bookUrl: 'https://book.example.com/$id',
    isLocal: false,
  );
}

BookSource _buildSource(String sourceUrl) {
  return BookSource(
    bookSourceUrl: sourceUrl,
    bookSourceName: '允许更新测试源',
  );
}

void main() {
  late Directory tempDir;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues(<String, Object>{});

    tempDir = await Directory.systemTemp.createTemp(
      'soupreader_search_book_info_allow_update_',
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

  testWidgets('详情页菜单显示允许更新并默认勾选', (WidgetTester tester) async {
    const sourceUrl = 'https://source-allow-update-menu.example.com';
    final sourceRepo = SourceRepository(DatabaseService());
    final bookRepo = BookRepository(DatabaseService());
    final book = _buildBook(
      id: 'book-allow-update-menu',
      sourceUrl: sourceUrl,
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

    final allowUpdateAction =
        find.widgetWithText(CupertinoActionSheetAction, '允许更新');
    expect(allowUpdateAction, findsOneWidget);
    expect(find.text('允许更新：开'), findsNothing);
    expect(find.text('允许更新：关'), findsNothing);
    expect(
      find.descendant(
        of: allowUpdateAction,
        matching: find.byIcon(CupertinoIcons.check_mark),
      ),
      findsOneWidget,
    );
  });

  testWidgets('点击允许更新后仅切换状态并持久化，不弹扩展提示', (WidgetTester tester) async {
    const sourceUrl = 'https://source-allow-update-toggle.example.com';
    const bookId = 'book-allow-update-toggle';
    final sourceRepo = SourceRepository(DatabaseService());
    final bookRepo = BookRepository(DatabaseService());
    final settings = SettingsService();
    final book = _buildBook(
      id: bookId,
      sourceUrl: sourceUrl,
    );

    await tester.runAsync(() async {
      await sourceRepo.addSource(_buildSource(sourceUrl));
      await bookRepo.addBook(book);
      await settings.saveBookCanUpdate(bookId, true);
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

    final allowUpdateAction =
        find.widgetWithText(CupertinoActionSheetAction, '允许更新');
    expect(allowUpdateAction, findsOneWidget);
    await tester.tap(allowUpdateAction);
    await tester.pumpAndSettle();

    expect(find.text('已开启“允许更新”'), findsNothing);
    expect(find.text('已关闭“允许更新”'), findsNothing);

    bool? storedCanUpdate;
    await tester.runAsync(() async {
      storedCanUpdate = settings.getBookCanUpdate(bookId);
    });
    expect(storedCanUpdate, isFalse);

    await tester.tap(moreAction);
    await tester.pumpAndSettle();

    final uncheckedAction =
        find.widgetWithText(CupertinoActionSheetAction, '允许更新');
    expect(uncheckedAction, findsOneWidget);
    expect(
      find.descendant(
        of: uncheckedAction,
        matching: find.byIcon(CupertinoIcons.check_mark),
      ),
      findsNothing,
    );
  });
}
