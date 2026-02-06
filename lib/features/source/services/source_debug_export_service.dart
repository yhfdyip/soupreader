import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
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

  Future<bool> exportZipToFile({
    required Map<String, String> files,
    required String fileName,
    String dialogTitle = '导出调试包',
  }) async {
    try {
      final outputPath = await FilePicker.platform.saveFile(
        dialogTitle: dialogTitle,
        fileName: fileName,
        allowedExtensions: ['zip'],
        type: FileType.custom,
      );

      if (outputPath == null) return false;

      final archive = Archive();
      for (final entry in files.entries) {
        final path = entry.key.trim();
        if (path.isEmpty) continue;
        final data = utf8.encode(entry.value);
        archive.addFile(ArchiveFile(path, data.length, data));
      }

      final zipData = ZipEncoder().encode(archive);
      if (zipData == null) return false;

      await File(outputPath).writeAsBytes(zipData, flush: true);
      return true;
    } catch (_) {
      return false;
    }
  }
}
