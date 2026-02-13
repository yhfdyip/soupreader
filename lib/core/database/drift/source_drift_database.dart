import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

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

@DriftDatabase(tables: [SourceRecords])
class SourceDriftDatabase extends _$SourceDriftDatabase {
  SourceDriftDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final file = File(
      p.join(documentsDirectory.path, 'soupreader_sources.sqlite'),
    );
    return NativeDatabase.createInBackground(file);
  });
}
