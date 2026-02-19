import '../../../core/utils/chinese_script_converter.dart';
import '../../replace/services/replace_rule_service.dart';
import '../models/reading_settings.dart';

typedef ChapterTitleApplyOverride = Future<String> Function(String title);

/// 目录标题展示处理（对齐 legado 标题链路）：
/// - 去除换行；
/// - 按阅读设置执行简繁转换；
/// - 最后应用标题替换规则。
class ChapterTitleDisplayHelper {
  ChapterTitleDisplayHelper({
    ReplaceRuleService? replaceRuleService,
    ChineseScriptConverter? chineseScriptConverter,
  })  : _replaceRuleService = replaceRuleService,
        _converter = chineseScriptConverter ?? ChineseScriptConverter.instance;

  final ReplaceRuleService? _replaceRuleService;
  final ChineseScriptConverter _converter;

  String normalizeAndConvertTitle(
    String rawTitle, {
    required int chineseConverterType,
  }) {
    final normalized = rawTitle.replaceAll(RegExp(r'[\r\n]+'), '');
    switch (chineseConverterType) {
      case ChineseConverterType.traditionalToSimplified:
        return _converter.traditionalToSimplified(normalized);
      case ChineseConverterType.simplifiedToTraditional:
        return _converter.simplifiedToTraditional(normalized);
      case ChineseConverterType.off:
      default:
        return normalized;
    }
  }

  Future<String> buildDisplayTitle({
    required String rawTitle,
    required String bookName,
    required String? sourceUrl,
    required int chineseConverterType,
    ChapterTitleApplyOverride? applyTitleOverride,
  }) async {
    final converted = normalizeAndConvertTitle(
      rawTitle,
      chineseConverterType: chineseConverterType,
    );

    if (applyTitleOverride != null) {
      return applyTitleOverride(converted);
    }

    final replaceService = _replaceRuleService;
    if (replaceService == null) {
      return converted;
    }
    return replaceService.applyTitle(
      converted,
      bookName: bookName,
      sourceUrl: sourceUrl,
    );
  }

  Future<List<String>> buildDisplayTitles({
    required List<String> rawTitles,
    required String bookName,
    required String? sourceUrl,
    required int chineseConverterType,
    ChapterTitleApplyOverride? applyTitleOverride,
  }) async {
    final result = <String>[];
    for (final rawTitle in rawTitles) {
      result.add(
        await buildDisplayTitle(
          rawTitle: rawTitle,
          bookName: bookName,
          sourceUrl: sourceUrl,
          chineseConverterType: chineseConverterType,
          applyTitleOverride: applyTitleOverride,
        ),
      );
    }
    return result;
  }
}
