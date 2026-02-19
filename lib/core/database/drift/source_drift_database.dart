import 'package:drift/drift.dart';

import 'source_drift_connection.dart';

part 'source_drift_database.g.dart';

class SourceRecords extends Table {
  TextColumn get bookSourceUrl => text()();

  TextColumn get bookSourceName => text().withDefault(const Constant(''))();

  TextColumn get bookSourceGroup => text().nullable()();

  IntColumn get bookSourceType => integer().withDefault(const Constant(0))();

  BoolColumn get enabled => boolean().withDefault(const Constant(true))();

  BoolColumn get enabledExplore =>
      boolean().withDefault(const Constant(true))();

  BoolColumn get enabledCookieJar => boolean().nullable()();

  IntColumn get weight => integer().withDefault(const Constant(0))();

  IntColumn get customOrder => integer().withDefault(const Constant(0))();

  IntColumn get respondTime => integer().withDefault(const Constant(180000))();

  TextColumn get header => text().nullable()();

  TextColumn get loginUrl => text().nullable()();

  TextColumn get bookSourceComment => text().nullable()();

  IntColumn get lastUpdateTime => integer().withDefault(const Constant(0))();

  TextColumn get rawJson => text().nullable()();

  IntColumn get updatedAt => integer().withDefault(const Constant(0))();

  @override
  Set<Column<Object>> get primaryKey => {bookSourceUrl};
}

class RssSourceRecords extends Table {
  TextColumn get sourceUrl => text()();

  TextColumn get sourceName => text().withDefault(const Constant(''))();

  TextColumn get sourceIcon => text().nullable()();

  TextColumn get sourceGroup => text().nullable()();

  TextColumn get sourceComment => text().nullable()();

  BoolColumn get enabled => boolean().withDefault(const Constant(true))();

  TextColumn get loginUrl => text().nullable()();

  TextColumn get sortUrl => text().nullable()();

  BoolColumn get singleUrl => boolean().withDefault(const Constant(false))();

  IntColumn get customOrder => integer().withDefault(const Constant(0))();

  IntColumn get lastUpdateTime => integer().withDefault(const Constant(0))();

  TextColumn get rawJson => text().nullable()();

  IntColumn get updatedAt => integer().withDefault(const Constant(0))();

  @override
  Set<Column<Object>> get primaryKey => {sourceUrl};
}

class RssArticleRecords extends Table {
  TextColumn get origin => text()();

  TextColumn get link => text()();

  TextColumn get sort => text().withDefault(const Constant(''))();

  TextColumn get title => text().withDefault(const Constant(''))();

  IntColumn get orderValue => integer().withDefault(const Constant(0))();

  TextColumn get pubDate => text().nullable()();

  TextColumn get description => text().nullable()();

  TextColumn get content => text().nullable()();

  TextColumn get image => text().nullable()();

  TextColumn get groupName => text().withDefault(const Constant('默认分组'))();

  TextColumn get variable => text().nullable()();

  IntColumn get updatedAt => integer().withDefault(const Constant(0))();

  @override
  Set<Column<Object>> get primaryKey => {origin, link};
}

class RssReadRecordRecords extends Table {
  TextColumn get record => text()();

  TextColumn get title => text().nullable()();

  IntColumn get readTime => integer().nullable()();

  BoolColumn get read => boolean().withDefault(const Constant(true))();

  IntColumn get updatedAt => integer().withDefault(const Constant(0))();

  @override
  Set<Column<Object>> get primaryKey => {record};
}

class BookRecords extends Table {
  TextColumn get id => text()();

  TextColumn get title => text().withDefault(const Constant(''))();

  TextColumn get author => text().withDefault(const Constant(''))();

  TextColumn get coverUrl => text().nullable()();

  TextColumn get intro => text().nullable()();

  TextColumn get sourceId => text().nullable()();

  TextColumn get sourceUrl => text().nullable()();

  TextColumn get bookUrl => text().nullable()();

  TextColumn get latestChapter => text().nullable()();

  IntColumn get totalChapters => integer().withDefault(const Constant(0))();

  IntColumn get currentChapter => integer().withDefault(const Constant(0))();

  RealColumn get readProgress => real().withDefault(const Constant(0.0))();

  IntColumn get lastReadTime => integer().nullable()();

  IntColumn get addedTime => integer().nullable()();

  BoolColumn get isLocal => boolean().withDefault(const Constant(false))();

  TextColumn get localPath => text().nullable()();

  IntColumn get updatedAt => integer().withDefault(const Constant(0))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class ChapterRecords extends Table {
  TextColumn get id => text()();

  TextColumn get bookId => text()();

  TextColumn get title => text().withDefault(const Constant(''))();

  TextColumn get url => text().nullable()();

  IntColumn get chapterIndex => integer().withDefault(const Constant(0))();

  BoolColumn get isDownloaded => boolean().withDefault(const Constant(false))();

  TextColumn get content => text().nullable()();

  IntColumn get updatedAt => integer().withDefault(const Constant(0))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class ReplaceRuleRecords extends Table {
  IntColumn get id => integer()();

  TextColumn get name => text().withDefault(const Constant(''))();

  TextColumn get groupName => text().nullable()();

  TextColumn get pattern => text().withDefault(const Constant(''))();

  TextColumn get replacement => text().withDefault(const Constant(''))();

  TextColumn get scope => text().nullable()();

  BoolColumn get scopeTitle => boolean().withDefault(const Constant(false))();

  BoolColumn get scopeContent => boolean().withDefault(const Constant(true))();

  TextColumn get excludeScope => text().nullable()();

  BoolColumn get isEnabled => boolean().withDefault(const Constant(true))();

  BoolColumn get isRegex => boolean().withDefault(const Constant(true))();

  IntColumn get timeoutMillisecond =>
      integer().withDefault(const Constant(3000))();

  IntColumn get orderValue =>
      integer().withDefault(const Constant(-2147483648))();

  IntColumn get updatedAt => integer().withDefault(const Constant(0))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class AppKeyValueRecords extends Table {
  TextColumn get key => text()();

  TextColumn get value => text().nullable()();

  IntColumn get updatedAt => integer().withDefault(const Constant(0))();

  @override
  Set<Column<Object>> get primaryKey => {key};
}

class BookmarkRecords extends Table {
  TextColumn get id => text()();

  TextColumn get bookId => text()();

  TextColumn get bookName => text().withDefault(const Constant(''))();

  TextColumn get bookAuthor => text().withDefault(const Constant(''))();

  IntColumn get chapterIndex => integer().withDefault(const Constant(0))();

  TextColumn get chapterTitle => text().withDefault(const Constant(''))();

  IntColumn get chapterPos => integer().withDefault(const Constant(0))();

  TextColumn get content => text().withDefault(const Constant(''))();

  IntColumn get createdTime => integer().withDefault(const Constant(0))();

  IntColumn get updatedAt => integer().withDefault(const Constant(0))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DriftDatabase(
  tables: [
    SourceRecords,
    RssSourceRecords,
    RssArticleRecords,
    RssReadRecordRecords,
    BookRecords,
    ChapterRecords,
    ReplaceRuleRecords,
    AppKeyValueRecords,
    BookmarkRecords,
  ],
)
class SourceDriftDatabase extends _$SourceDriftDatabase {
  SourceDriftDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 5;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (Migrator m) async {
          await m.createAll();
        },
        onUpgrade: (Migrator m, int from, int to) async {
          if (from < 2) {
            await m.createTable(bookRecords);
            await m.createTable(chapterRecords);
            await m.createTable(replaceRuleRecords);
            await m.createTable(appKeyValueRecords);
            await m.createTable(bookmarkRecords);
          }
          if (from >= 2 && from < 3) {
            await m.addColumn(bookRecords, bookRecords.bookUrl);
          }
          if (from < 4) {
            await m.createTable(rssSourceRecords);
          }
          if (from < 5) {
            await m.createTable(rssArticleRecords);
            await m.createTable(rssReadRecordRecords);
          }
        },
      );
}

LazyDatabase _openConnection() {
  return LazyDatabase(openSourceDriftConnection);
}
