import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../../app/theme/ui_tokens.dart';
import '../../../app/widgets/app_cupertino_page_scaffold.dart';
import '../../../app/widgets/app_nav_bar_button.dart';
import '../../../app/widgets/app_ui_kit.dart';

class SourceQrShareView extends StatelessWidget {
  const SourceQrShareView({
    super.key,
    required this.text,
    required this.subject,
    this.hintText = '使用其他设备扫码导入',
  });

  final String text;
  final String subject;
  final String hintText;

  @override
  Widget build(BuildContext context) {
    final uiTokens = AppUiTokens.resolve(context);
    final title = subject.trim().isEmpty ? '书源二维码' : subject.trim();
    return AppCupertinoPageScaffold(
      title: title,
      trailing: AppNavBarButton(
        onPressed: () async {
          final qrFile = await _buildQrPngFile(text);
          if (qrFile != null) {
            await SharePlus.instance.share(
              ShareParams(
                files: [
                  XFile(
                    qrFile.path,
                    mimeType: 'image/png',
                  ),
                ],
                subject: title,
                text: title,
              ),
            );
            return;
          }
          await SharePlus.instance.share(
            ShareParams(
              text: text,
              subject: title,
            ),
          );
        },
        child: const Text('分享'),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AppCard(
              padding: const EdgeInsets.all(14),
              backgroundColor: CupertinoColors.white,
              borderColor: uiTokens.colors.separator.withValues(alpha: 0.72),
              child: SizedBox(
                width: 260,
                height: 260,
                child: QrImageView(
                  data: text,
                  version: QrVersions.auto,
                  size: 260,
                  eyeStyle: const QrEyeStyle(
                    eyeShape: QrEyeShape.square,
                    color: CupertinoColors.black,
                  ),
                  dataModuleStyle: const QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.square,
                    color: CupertinoColors.black,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),
            AppCard(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              borderColor: uiTokens.colors.separator.withValues(alpha: 0.72),
              child: Text(
                hintText,
                style: TextStyle(
                  color: uiTokens.colors.secondaryLabel,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<File?> _buildQrPngFile(String data) async {
    if (kIsWeb) return null;
    try {
      final painter = QrPainter(
        data: data,
        version: QrVersions.auto,
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
          'source_qr_${DateTime.now().millisecondsSinceEpoch}.png',
        ),
      );
      await file.writeAsBytes(bytes, flush: true);
      return file;
    } catch (_) {
      return null;
    }
  }
}
