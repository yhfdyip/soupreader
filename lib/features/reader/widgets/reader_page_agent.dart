import 'package:flutter/material.dart';

/// 阅读器分页代理
/// 使用 TextPainter 精确计算每页可显示的文本范围
class ReaderPageAgent {
  /// 获取文本分页偏移量
  ///
  /// [content] 文本内容
  /// [height] 可用高度
  /// [width] 可用宽度
  /// [fontSize] 字体大小
  /// [lineHeight] 行高倍数
  static List<Map<String, int>> getPageOffsets(
    String content,
    double height,
    double width,
    double fontSize, {
    double lineHeight = 1.5,
    double letterSpacing = 0,
    String? fontFamily,
  }) {
    String tempStr = content;
    List<Map<String, int>> pageConfig = [];
    int last = 0;

    while (true) {
      Map<String, int> offset = {};
      offset['start'] = last;

      TextPainter textPainter = TextPainter(
        textDirection: TextDirection.ltr,
        text: TextSpan(
          text: tempStr,
          style: TextStyle(
            fontSize: fontSize,
            height: lineHeight,
            letterSpacing: letterSpacing,
            fontFamily: fontFamily,
          ),
        ),
      );
      textPainter.layout(maxWidth: width - 1);

      var end = textPainter.getPositionForOffset(Offset(width, height)).offset;

      if (end == 0) {
        break;
      }

      tempStr = tempStr.substring(end, tempStr.length);
      offset['end'] = last + end;
      last = last + end;
      pageConfig.add(offset);
    }

    return pageConfig;
  }

  /// 将内容转换为页面列表
  static List<String> paginateContent(
    String content,
    double height,
    double width,
    double fontSize, {
    double lineHeight = 1.5,
    double letterSpacing = 0,
    String? fontFamily,
    String? title,
  }) {
    // 预处理内容：添加首行缩进
    String processedContent = content;
    if (!processedContent.startsWith('　　')) {
      processedContent = '　　' + processedContent;
    }
    processedContent = processedContent.replaceAll('\n', '\n　　');

    // 如果有标题，添加到开头
    if (title != null && title.isNotEmpty) {
      processedContent = '$title\n\n$processedContent';
    }

    // 获取分页偏移
    List<Map<String, int>> offsets = getPageOffsets(
      processedContent,
      height,
      width,
      fontSize,
      lineHeight: lineHeight,
      letterSpacing: letterSpacing,
      fontFamily: fontFamily,
    );

    // 转换为页面内容列表
    List<String> pages = [];
    for (var offset in offsets) {
      String pageContent =
          processedContent.substring(offset['start']!, offset['end']);
      // 移除开头的换行
      if (pageContent.startsWith('\n')) {
        pageContent = pageContent.substring(1);
      }
      pages.add(pageContent);
    }

    // 确保至少有一页
    if (pages.isEmpty) {
      pages.add(title ?? '暂无内容');
    }

    return pages;
  }
}
