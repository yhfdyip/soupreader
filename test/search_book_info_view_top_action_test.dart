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
  required DateTime baseline,
}) {
  return Book(
    id: id,
    title: '置顶测试书',
    author: '测试作者',
    sourceUrl: sourceUrl,
    sourceId: sourceUrl,
    bookUrl: 'https://book.example.com/$id',
    addedTime: baseline,
    lastReadTime: baseline,
    isLocal: false,
  );
}

BookSource _buildSource(String sourceUrl) {
  return BookSource(
    bookSourceUrl: sourceUrl,
    bookSourceName: '置顶测试源',
  );
}

void main() {
  late Directory tempDir;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues(<String, Object>{});

    tempDir = await Directory.systemTemp.createTemp(
      'soupreader_search_book_info_top_',
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

  testWidgets('详情页点击置顶会更新书架时间戳', (WidgetTester tester) async {
    const sourceUrl = 'https://source-top-action.example.com';
    const bookId = 'book-top-action';
    final baseline = DateTime(2021, 1, 1, 8, 0, 0);
    final sourceRepo = SourceRepository(DatabaseService());
    final bookRepo = BookRepository(DatabaseService());
    final book = _buildBook(
      id: bookId,
      sourceUrl: sourceUrl,
      baseline: baseline,
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

    final topAction = find.text('置顶');
    expect(topAction, findsOneWidget);
    await tester.tap(topAction);
    await tester.pumpAndSettle();

    int? updatedLastReadMs;
    int? updatedAddedMs;
    final baselineMs = baseline.millisecondsSinceEpoch;
    await tester.runAsync(() async {
      final db = DatabaseService().driftDb;
      for (var attempt = 0; attempt < 50; attempt++) {
        final row = await (db.select(db.bookRecords)
              ..where((tbl) => tbl.id.equals(bookId)))
            .getSingle();
        updatedLastReadMs = row.lastReadTime;
        updatedAddedMs = row.addedTime;
        if ((updatedLastReadMs ?? 0) > baselineMs &&
            (updatedAddedMs ?? 0) > baselineMs) {
          break;
        }
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
    });

    expect(updatedLastReadMs, isNotNull);
    expect(updatedAddedMs, isNotNull);
    expect(updatedLastReadMs!, greaterThan(baselineMs));
    expect(updatedAddedMs!, greaterThan(baselineMs));
  });
}
