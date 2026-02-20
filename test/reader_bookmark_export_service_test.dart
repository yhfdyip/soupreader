import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:soupreader/core/database/entities/bookmark_entity.dart';
import 'package:soupreader/features/reader/services/reader_bookmark_export_service.dart';

void main() {
  BookmarkEntity buildBookmark({
    required String id,
    required int chapterIndex,
    required int chapterPos,
    required String chapterTitle,
    required String content,
  }) {
    return BookmarkEntity(
      id: id,
      bookId: 'book-1',
      bookName: '测试书',
      bookAuthor: '测试作者',
      chapterIndex: chapterIndex,
      chapterTitle: chapterTitle,
      chapterPos: chapterPos,
      content: content,
      createdTime:
          DateTime.fromMillisecondsSinceEpoch(1700000000000 + chapterPos),
    );
  }

  test('ReaderBookmarkExportService 导出 JSON 按章节顺序落盘', () async {
    String? capturedPath;
    String? capturedContent;
    final service = ReaderBookmarkExportService(
      saveFile: ({
        required String dialogTitle,
        required String fileName,
        required List<String> allowedExtensions,
      }) async {
        expect(dialogTitle, '导出书签');
        expect(fileName.endsWith('.json'), isTrue);
        expect(allowedExtensions, <String>['json']);
        return '/tmp/bookmark.json';
      },
      writeFile: ({
        required String path,
        required String content,
      }) async {
        capturedPath = path;
        capturedContent = content;
      },
    );

    final result = await service.exportJson(
      bookTitle: '测试书',
      bookAuthor: '测试作者',
      bookmarks: <BookmarkEntity>[
        buildBookmark(
          id: 'b2',
          chapterIndex: 5,
          chapterPos: 10,
          chapterTitle: '第六章',
          content: '后段内容',
        ),
        buildBookmark(
          id: 'b1',
          chapterIndex: 1,
          chapterPos: 0,
          chapterTitle: '第二章',
          content: '前段内容',
        ),
      ],
    );

    expect(result.success, isTrue);
    expect(result.cancelled, isFalse);
    expect(result.outputPath, '/tmp/bookmark.json');
    expect(capturedPath, '/tmp/bookmark.json');
    expect(capturedContent, isNotNull);
    final decoded = json.decode(capturedContent!) as List<dynamic>;
    expect(decoded, hasLength(2));
    expect((decoded[0] as Map<String, dynamic>)['chapterIndex'], 1);
    expect((decoded[1] as Map<String, dynamic>)['chapterIndex'], 5);
  });

  test('ReaderBookmarkExportService 导出 Markdown 生成 legado 风格段落', () async {
    String? capturedContent;
    final service = ReaderBookmarkExportService(
      saveFile: ({
        required String dialogTitle,
        required String fileName,
        required List<String> allowedExtensions,
      }) async {
        expect(dialogTitle, '导出 Markdown');
        expect(fileName.endsWith('.md'), isTrue);
        expect(allowedExtensions, <String>['md']);
        return '/tmp/bookmark.md';
      },
      writeFile: ({
        required String path,
        required String content,
      }) async {
        capturedContent = content;
      },
    );

    final result = await service.exportMarkdown(
      bookTitle: '测试书',
      bookAuthor: '测试作者',
      bookmarks: <BookmarkEntity>[
        buildBookmark(
          id: 'b1',
          chapterIndex: 0,
          chapterPos: 0,
          chapterTitle: '第一章',
          content: '这里是书签内容',
        ),
      ],
    );

    expect(result.success, isTrue);
    expect(capturedContent, isNotNull);
    expect(capturedContent, contains('## 测试书 测试作者'));
    expect(capturedContent, contains('#### 第一章'));
    expect(capturedContent, contains('###### 原文'));
    expect(capturedContent, contains('###### 摘要'));
    expect(capturedContent, contains('这里是书签内容'));
  });

  test('ReaderBookmarkExportService 取消保存返回 cancelled', () async {
    final service = ReaderBookmarkExportService(
      saveFile: ({
        required String dialogTitle,
        required String fileName,
        required List<String> allowedExtensions,
      }) async {
        return null;
      },
    );

    final result = await service.exportJson(
      bookTitle: '测试书',
      bookAuthor: '测试作者',
      bookmarks: <BookmarkEntity>[
        buildBookmark(
          id: 'b1',
          chapterIndex: 1,
          chapterPos: 0,
          chapterTitle: '第二章',
          content: '内容',
        ),
      ],
    );

    expect(result.success, isFalse);
    expect(result.cancelled, isTrue);
  });

  test('ReaderBookmarkExportService 空书签返回提示', () async {
    final service = ReaderBookmarkExportService();
    final result = await service.exportJson(
      bookTitle: '测试书',
      bookAuthor: '测试作者',
      bookmarks: const <BookmarkEntity>[],
    );

    expect(result.success, isFalse);
    expect(result.cancelled, isFalse);
    expect(result.message, '暂无书签可导出');
  });
}
