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
import 'package:soupreader/core/services/book_variable_store.dart';
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
    title: '书籍变量测试书',
    author: '测试作者',
    sourceUrl: sourceUrl,
    sourceId: sourceUrl,
    bookUrl: bookUrl,
    isLocal: false,
  );
}

BookSource _buildSource({
  required String sourceUrl,
}) {
  return BookSource(
    bookSourceUrl: sourceUrl,
    bookSourceName: '书籍变量测试源',
    variableComment: '这是变量说明',
  );
}

void main() {
  late Directory tempDir;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues(<String, Object>{});

    tempDir = await Directory.systemTemp.createTemp(
      'soupreader_search_book_info_book_variable_',
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

  testWidgets('详情页设置书籍变量保存空字符串并保持 legado 同义语义', (tester) async {
    const sourceUrl = 'https://book-variable.example.com';
    const bookUrl = 'https://book-variable.example.com/book/100';
    final sourceRepo = SourceRepository(DatabaseService());
    final bookRepo = BookRepository(DatabaseService());
    final source = _buildSource(sourceUrl: sourceUrl);
    final book = _buildBook(
      id: 'book-variable',
      sourceUrl: sourceUrl,
      bookUrl: bookUrl,
    );

    await tester.runAsync(() async {
      await sourceRepo.addSource(source);
      await bookRepo.addBook(book);
      await BookVariableStore.putVariable(bookUrl, 'old=1');
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

    final bookVariableAction = find.text('设置书籍变量');
    expect(bookVariableAction, findsOneWidget);
    await tester.tap(bookVariableAction);
    await tester.pumpAndSettle();

    expect(
      find.text('这是变量说明\n书籍变量可在js中通过book.getVariable("custom")获取'),
      findsOneWidget,
    );

    final input = find.byType(CupertinoTextField);
    expect(input, findsOneWidget);
    final field = tester.widget<CupertinoTextField>(input);
    expect(field.controller?.text, 'old=1');

    await tester.enterText(input, '');
    await tester.tap(find.widgetWithText(CupertinoDialogAction, '保存'));
    await tester.pumpAndSettle();

    expect(find.text('书籍变量已保存'), findsNothing);

    String? storedValue;
    String? rawValue;
    await tester.runAsync(() async {
      storedValue = await BookVariableStore.getVariable(bookUrl);
      final prefs = await SharedPreferences.getInstance();
      rawValue = prefs.getString('bookVariable_$bookUrl');
    });
    expect(storedValue, '');
    expect(rawValue, '');
  });
}
