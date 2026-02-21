import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:soupreader/app/theme/shadcn_theme.dart';
import 'package:soupreader/core/database/database_service.dart';
import 'package:soupreader/core/database/repositories/book_repository.dart';
import 'package:soupreader/features/bookshelf/models/book.dart';
import 'package:soupreader/features/search/views/search_book_info_edit_view.dart';
import 'package:soupreader/features/search/views/search_book_info_view.dart';

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

Book _buildBook({required String id}) {
  return Book(
    id: id,
    title: '测试书',
    author: '测试作者',
    sourceUrl: '',
    sourceId: '',
    bookUrl: 'local://$id',
    isLocal: true,
    localPath: '/tmp/$id.txt',
  );
}

void main() {
  late Directory tempDir;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();

    tempDir = await Directory.systemTemp.createTemp(
      'soupreader_search_book_info_edit_',
    );
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
      return tempDir.path;
    });

    await DatabaseService().init();
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
  });

  testWidgets('书籍不在书架时不显示编辑入口', (WidgetTester tester) async {
    final book = _buildBook(id: 'book-not-in-shelf');

    await tester.pumpWidget(
      _buildTestApp(
        SearchBookInfoView.fromBookshelf(book: book),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byIcon(CupertinoIcons.pencil), findsNothing);
  });

  testWidgets('书籍在书架时显示编辑入口并可进入编辑页', (WidgetTester tester) async {
    final book = _buildBook(id: 'book-in-shelf');
    final repository = BookRepository(DatabaseService());
    await tester.runAsync(() async {
      await repository.addBook(book);
    });

    await tester.pumpWidget(
      _buildTestApp(
        SearchBookInfoView.fromBookshelf(book: book),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final editAction = find.byIcon(CupertinoIcons.pencil);
    expect(editAction, findsOneWidget);

    await tester.tap(editAction);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 450));

    final editView = find.byType(SearchBookInfoEditView);
    expect(editView, findsOneWidget);
    expect(find.text('书名'), findsOneWidget);
    expect(find.text('作者'), findsOneWidget);
    expect(
      find.descendant(
        of: editView,
        matching: find.widgetWithText(CupertinoButton, '保存'),
      ),
      findsOneWidget,
    );
  });

}
