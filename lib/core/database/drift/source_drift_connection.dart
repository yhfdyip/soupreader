import 'package:drift/drift.dart';

import 'source_drift_connection_stub.dart'
    if (dart.library.io) 'source_drift_connection_native.dart'
    if (dart.library.html) 'source_drift_connection_web.dart' as impl;

Future<QueryExecutor> openSourceDriftConnection() {
  return impl.openSourceDriftConnection();
}
