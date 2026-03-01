import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

Future<QueryExecutor> openSourceDriftConnection() async {
  final documentsDirectory = await getApplicationDocumentsDirectory();
  final file = File(
    p.join(documentsDirectory.path, 'soupreader_sources.sqlite'),
  );
  // iOS Release 下后台 isolate 启动偶发卡死会导致应用停留在启动白屏。
  // 这里优先使用前台打开，若数据库异常会显式抛出并进入启动异常页。
  if (Platform.isIOS) {
    return NativeDatabase(
      file,
      logStatements: kDebugMode,
    );
  }
  return NativeDatabase.createInBackground(file);
}
