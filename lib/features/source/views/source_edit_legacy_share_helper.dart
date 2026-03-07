import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

class SourceEditLegacyShareHelper {
  static Future<File?> buildShareQrPngFile(String payload) async {
    if (kIsWeb) return null;
    try {
      final painter = QrPainter(
        data: payload,
        version: QrVersions.auto,
        errorCorrectionLevel: QrErrorCorrectLevel.L,
        eyeStyle: const QrEyeStyle(
          eyeShape: QrEyeShape.square,
          color: CupertinoColors.black,
        ),
        dataModuleStyle: const QrDataModuleStyle(
          dataModuleShape: QrDataModuleShape.square,
          color: CupertinoColors.black,
        ),
      );
      final imageData = await painter.toImageData(
        1024,
        format: ui.ImageByteFormat.png,
      );
      final bytes = imageData?.buffer.asUint8List();
      if (bytes == null || bytes.isEmpty) {
        return null;
      }
      final dir = await getTemporaryDirectory();
      final file = File(
        p.join(
          dir.path,
          'source_qr_share_${DateTime.now().millisecondsSinceEpoch}.png',
        ),
      );
      await file.writeAsBytes(bytes, flush: true);
      return file;
    } catch (_) {
      return null;
    }
  }

  static String resolveShareErrorMessage(Object error) {
    final raw = error.toString().trim();
    if (raw.isEmpty) return 'ERROR';

    const exceptionPrefix = 'Exception:';
    if (raw.startsWith(exceptionPrefix)) {
      final message = raw.substring(exceptionPrefix.length).trim();
      return message.isEmpty ? 'ERROR' : message;
    }

    const platformPrefix = 'PlatformException(';
    if (raw.startsWith(platformPrefix) && raw.endsWith(')')) {
      final body = raw.substring(platformPrefix.length, raw.length - 1);
      final segments = body.split(',');
      if (segments.length >= 2) {
        final message = segments[1].trim();
        if (message.isNotEmpty) return message;
      }
    }

    return raw;
  }
}
