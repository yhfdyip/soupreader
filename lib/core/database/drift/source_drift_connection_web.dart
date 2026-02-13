// ignore_for_file: deprecated_member_use

import 'package:drift/drift.dart';
import 'package:drift/web.dart';

Future<QueryExecutor> openSourceDriftConnection() async {
  final storage = await DriftWebStorage.indexedDbIfSupported(
    'soupreader_sources',
  );
  return WebDatabase.withStorage(
    storage,
    logStatements: false,
  );
}
