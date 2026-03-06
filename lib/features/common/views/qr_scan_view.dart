import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:path_provider/path_provider.dart';

import '../../../app/theme/ui_tokens.dart';
import '../../../app/widgets/app_cupertino_page_scaffold.dart';
import '../../../app/widgets/app_nav_bar_button.dart';
import '../../../app/widgets/app_ui_kit.dart';
import '../../../core/services/exception_log_service.dart';

class QrScanView extends StatefulWidget {
  final String title;

  const QrScanView({
    super.key,
    this.title = '扫码',
  });

  @override
  State<QrScanView> createState() => _QrScanViewState();
}

class _QrScanViewState extends State<QrScanView> {
  static const String _galleryNode = 'qr_code_scan.action_choose_from_gallery';

  late final MobileScannerController _controller;
  bool _handled = false;
  bool _pickingFromGallery = false;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      facing: CameraFacing.back,
      torchEnabled: false,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled || _pickingFromGallery) return;
    final raw = _firstRawValue(capture);
    if (raw == null || raw.isEmpty) return;
    _handled = true;
    Navigator.of(context).pop(raw);
  }

  String? _firstRawValue(BarcodeCapture? capture) {
    if (capture == null) return null;
    for (final code in capture.barcodes) {
      final raw = code.rawValue?.trim();
      if (raw == null || raw.isEmpty) continue;
      return raw;
    }
    return null;
  }

  Future<String?> _resolvePickedImagePath(PlatformFile file) async {
    final path = file.path?.trim();
    if (path != null && path.isNotEmpty) {
      return path;
    }
    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) {
      return null;
    }
    final dir = await getTemporaryDirectory();
    final ext = _resolveImageExtension(file.extension);
    final tempPath =
        '${dir.path}/qr_scan_${DateTime.now().microsecondsSinceEpoch}.$ext';
    final tempFile = File(tempPath);
    await tempFile.writeAsBytes(bytes, flush: true);
    return tempFile.path;
  }

  String _resolveImageExtension(String? extension) {
    final ext = (extension ?? '').trim().toLowerCase();
    switch (ext) {
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'bmp':
      case 'webp':
      case 'gif':
      case 'heic':
      case 'heif':
        return ext;
      default:
        return 'png';
    }
  }

  Future<void> _chooseFromGallery() async {
    if (_handled || _pickingFromGallery) return;
    setState(() => _pickingFromGallery = true);
    try {
      final pickResult = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        withData: true,
      );
      if (pickResult == null || pickResult.files.isEmpty) {
        return;
      }
      final imagePath = await _resolvePickedImagePath(pickResult.files.first);
      if (imagePath == null || imagePath.isEmpty) {
        ExceptionLogService().record(
          node: _galleryNode,
          message: '图库图片读取失败',
          context: <String, dynamic>{
            'fileName': pickResult.files.first.name,
          },
        );
        return;
      }
      String? raw;
      try {
        final capture = await _controller.analyzeImage(imagePath);
        raw = _firstRawValue(capture);
      } catch (error, stackTrace) {
        ExceptionLogService().record(
          node: _galleryNode,
          message: '图库二维码解析失败',
          error: error,
          stackTrace: stackTrace,
          context: <String, dynamic>{
            'imagePath': imagePath,
          },
        );
      }
      _handled = true;
      if (!mounted) return;
      Navigator.of(context).pop(raw);
    } catch (error, stackTrace) {
      ExceptionLogService().record(
        node: _galleryNode,
        message: '打开图库失败',
        error: error,
        stackTrace: stackTrace,
      );
    } finally {
      if (mounted) {
        setState(() => _pickingFromGallery = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AppUiTokens.resolve(context);
    return AppCupertinoPageScaffold(
      title: widget.title,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppNavBarButton(
            onPressed:
                (_handled || _pickingFromGallery) ? null : _chooseFromGallery,
            child: Text(_pickingFromGallery ? '处理中' : '图库'),
          ),
          AppNavBarButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
        ],
      ),
      includeTopSafeArea: true,
      includeBottomSafeArea: false,
      child: Column(
        children: [
          Expanded(
            child: MobileScanner(
              controller: _controller,
              onDetect: _onDetect,
            ),
          ),
          SafeArea(
            top: false,
            child: _buildBottomActions(tokens),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActions(AppUiTokens tokens) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      child: AppCard(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
        borderColor: tokens.colors.separator.withValues(alpha: 0.72),
        child: Row(
          children: [
            Expanded(
              child: CupertinoButton.filled(
                padding: const EdgeInsets.symmetric(vertical: 10),
                onPressed: () => _controller.toggleTorch(),
                child: const Text('切换闪光灯'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: CupertinoButton(
                padding: const EdgeInsets.symmetric(vertical: 10),
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('取消'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
