import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../database/repositories/book_repository.dart';
import '../database/repositories/bookmark_repository.dart';
import '../database/repositories/replace_rule_repository.dart';
import '../database/repositories/rss_article_repository.dart';
import '../database/repositories/rss_source_repository.dart';
import '../database/repositories/rss_star_repository.dart';
import '../database/repositories/source_repository.dart';
import 'core_providers.dart';

part 'repository_providers.g.dart';

/// 书籍仓储（全局单例）。
@Riverpod(keepAlive: true)
BookRepository bookRepository(Ref ref) =>
    BookRepository(ref.watch(databaseServiceProvider));

/// 章节仓储（全局单例）。
@Riverpod(keepAlive: true)
ChapterRepository chapterRepository(Ref ref) =>
    ChapterRepository(ref.watch(databaseServiceProvider));

/// 书源仓储（全局单例）。
@Riverpod(keepAlive: true)
SourceRepository sourceRepository(Ref ref) =>
    SourceRepository(ref.watch(databaseServiceProvider));

/// 替换规则仓储（全局单例）。
@Riverpod(keepAlive: true)
ReplaceRuleRepository replaceRuleRepository(Ref ref) =>
    ReplaceRuleRepository(ref.watch(databaseServiceProvider));

/// 书签仓储（全局单例）。
@Riverpod(keepAlive: true)
BookmarkRepository bookmarkRepository(Ref ref) => BookmarkRepository();

/// RSS 源仓储（全局单例）。
@Riverpod(keepAlive: true)
RssSourceRepository rssSourceRepository(Ref ref) =>
    RssSourceRepository(ref.watch(databaseServiceProvider));

/// RSS 文章仓储（全局单例）。
@Riverpod(keepAlive: true)
RssArticleRepository rssArticleRepository(Ref ref) =>
    RssArticleRepository(ref.watch(databaseServiceProvider));

/// RSS 阅读记录仓储（全局单例）。
@Riverpod(keepAlive: true)
RssReadRecordRepository rssReadRecordRepository(Ref ref) =>
    RssReadRecordRepository(ref.watch(databaseServiceProvider));

/// RSS 收藏仓储（全局单例）。
@Riverpod(keepAlive: true)
RssStarRepository rssStarRepository(Ref ref) =>
    RssStarRepository(ref.watch(databaseServiceProvider));
