import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../bootstrap/boot_log.dart';

Future<QueryExecutor> openSourceDriftConnection() async {
  BootLog.add('drift.open: getApplicationDocumentsDirectory start');
  final documentsDirectory = await getApplicationDocumentsDirectory();
  BootLog.add(
    'drift.open: getApplicationDocumentsDirectory ok '
    'path=${documentsDirectory.path}',
  );
  final file = File(
    p.join(documentsDirectory.path, 'soupreader_sources.sqlite'),
  );
  // iOS Release 下后台 isolate 启动偶发卡死会导致应用停留在启动白屏。
  // 这里优先使用前台打开，若数据库异常会显式抛出并进入启动异常页。
  if (Platform.isIOS) {
    BootLog.add('drift.open: NativeDatabase (foreground) start');
    return NativeDatabase(
      file,
      logStatements: kDebugMode,
    );
  }
  BootLog.add('drift.open: NativeDatabase.createInBackground start');
  return NativeDatabase.createInBackground(file);
}
