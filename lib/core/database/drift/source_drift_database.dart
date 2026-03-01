import 'package:drift/drift.dart';

import '../../bootstrap/boot_log.dart';
import 'source_drift_connection.dart';
import 'source_drift_tables.dart';

part 'source_drift_database.g.dart';

@DriftDatabase(
  tables: [
    SourceRecords,
    RssSourceRecords,
    RssArticleRecords,
    RssStarRecords,
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
  int get schemaVersion => 6;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (Migrator m) async {
          BootLog.add('drift.migration: onCreate start');
          await m.createAll();
          BootLog.add('drift.migration: onCreate ok');
        },
        onUpgrade: (Migrator m, int from, int to) async {
          BootLog.add('drift.migration: onUpgrade start (from=$from to=$to)');
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
          if (from < 6) {
            await m.createTable(rssStarRecords);
          }
          BootLog.add('drift.migration: onUpgrade ok (from=$from to=$to)');
        },
        beforeOpen: (OpeningDetails details) async {
          BootLog.add(
            'drift.migration: beforeOpen '
            '(version=${details.versionNow} '
            'was=${details.versionBefore})',
          );
        },
      );
}

LazyDatabase _openConnection() {
  return LazyDatabase(openSourceDriftConnection);
}
