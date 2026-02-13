import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

Future<QueryExecutor> openSourceDriftConnection() async {
  final documentsDirectory = await getApplicationDocumentsDirectory();
  final file = File(
    p.join(documentsDirectory.path, 'soupreader_sources.sqlite'),
  );
  return NativeDatabase.createInBackground(file);
}
