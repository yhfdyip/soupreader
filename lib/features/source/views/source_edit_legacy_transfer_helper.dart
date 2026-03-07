import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/utils/legado_json.dart';
import '../models/book_source.dart';
import '../services/source_import_export_service.dart';

/// 导入结果，统一承载首个书源与用户可见错误消息。
class SourceEditLegacyTransferImportResult {
  const SourceEditLegacyTransferImportResult({
    this.source,
    this.userMessage,
    this.rawErrorMessage,
    this.inputLength,
  });

  final BookSource? source;
  final String? userMessage;
  final String? rawErrorMessage;
  final int? inputLength;

  bool get isSuccess => source != null;
}

/// 提供书源编辑页的复制、分享与导入辅助能力。
class SourceEditLegacyTransferHelper {
  static Future<void> copySourceJson(BookSource source) async {
    final text = encodeSourceJson(source);
    await Clipboard.setData(ClipboardData(text: text));
  }

  static String encodeSourceJson(BookSource source) {
    return LegadoJson.encode(source.toJson());
  }

  static Future<String?> readClipboardText() async {
    final data = await Clipboard.getData('text/plain');
    return data?.text?.trim();
  }

  static Future<void> shareSourceJsonText(BookSource source) async {
    final text = encodeSourceJson(source);
    try {
      await SharePlus.instance.share(
        ShareParams(
          text: text,
          subject: '分享',
        ),
      );
    } catch (_) {
      // 对齐 legado Context.share(text)：分享异常静默，不追加成功/失败提示。
    }
  }

  static Future<SourceEditLegacyTransferImportResult>
      importFirstSourceFromText({
    required String text,
    required SourceImportExportService importExportService,
    required String Function(String? rawMessage) errorMessageResolver,
  }) async {
    final normalized = text.trim();
    if (normalized.isEmpty) {
      return const SourceEditLegacyTransferImportResult(userMessage: '剪贴板为空');
    }

    final result = await importExportService.importFromText(normalized);
    if (!result.success || result.sources.isEmpty) {
      return SourceEditLegacyTransferImportResult(
        userMessage: errorMessageResolver(result.errorMessage),
        rawErrorMessage: result.errorMessage,
        inputLength: normalized.length,
      );
    }

    return SourceEditLegacyTransferImportResult(source: result.sources.first);
  }

  static String resolvePasteSourceError(String? rawMessage) {
    final message = (rawMessage ?? '').trim();
    if (message.isEmpty) {
      return '格式不对';
    }
    if (message == '无效链接' ||
        message.contains('格式错误') ||
        message.contains('JSON') ||
        message.contains('sourceUrls') ||
        message.contains('未识别到有效书源')) {
      return '格式不对';
    }
    return message;
  }

  static String resolveQrImportError(String? rawMessage) {
    final message = (rawMessage ?? '').trim();
    if (message.isEmpty) {
      return 'Error';
    }
    return message;
  }
}
