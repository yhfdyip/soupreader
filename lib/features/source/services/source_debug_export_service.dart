import 'dart:io';

import 'package:file_picker/file_picker.dart';

class SourceDebugExportService {
  Future<bool> exportJsonToFile({
    required String json,
    required String fileName,
    String dialogTitle = '导出调试包',
  }) async {
    try {
      final outputPath = await FilePicker.platform.saveFile(
        dialogTitle: dialogTitle,
        fileName: fileName,
        allowedExtensions: ['json'],
        type: FileType.custom,
      );

      if (outputPath == null) return false;
      await File(outputPath).writeAsString(json);
      return true;
    } catch (_) {
      return false;
    }
  }
}

