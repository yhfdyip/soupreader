import 'package:flutter/cupertino.dart';

import '../../features/common/views/qr_scan_view.dart';

class QrScanService {
  const QrScanService._();

  static Future<String?> scanText(
    BuildContext context, {
    String title = '扫码',
  }) {
    return Navigator.of(context).push<String>(
      CupertinoPageRoute<String>(
        builder: (_) => QrScanView(title: title),
      ),
    );
  }
}
