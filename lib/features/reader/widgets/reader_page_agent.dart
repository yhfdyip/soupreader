import 'dart:ui' as ui;
import 'package:flutter/material.dart';

/// 阅读器分页代理
/// 重构：完全对标 Legado TextChapterLayout 逻辑
/// 采用“逐行合成”(Line Composition) 算法，而非简单的整体截断
class ReaderPageAgent {
  // === 配置参数 (对标 Legado) ===
  static const String indentChar = '　'; // 全角空格
  static const int indentSize = 2; // 缩进字符数
  
  // 段间距因子：由 ReadingSettings 传入 paragraphSpacing 控制
  // 如果 paragraphSpacing > 0，则在每段结束增加高度
  static const double defaultParagraphSpacing = 0.0; 

  /// 将内容转换为页面列表
  static List<String> paginateContent(
    String content,
    double height,
    double width,
    double fontSize, {
    double lineHeight = 1.5,
    double letterSpacing = 0,
    double paragraphSpacing = 0,
    String? fontFamily,
    String? title,
  }) {
    // 1. 准备画笔和通用样式
    final textStyle = TextStyle(
      fontSize: fontSize,
      height: lineHeight,
      letterSpacing: letterSpacing,
      fontFamily: fontFamily,
      color: Colors.black, // 颜色不影响排版，但必须指定以避免 assert 错误
    );

    // 2. 预处理文本：按换行符分割段落，并进行清洗
    String cleanContent = content.replaceAll('\r\n', '\n');
    final rawParagraphs = cleanContent.split('\n');
    List<String> paragraphs = [];
    
    // 如果有标题，插入到最前面
    bool hasTitle = title != null && title.isNotEmpty;
    if (hasTitle) {
      paragraphs.add(title);
      paragraphs.add(''); // 标题后的视觉空行
    }
    
    // 清洗段落（去除首尾空白，去除空段落）
    for (var p in rawParagraphs) {
      String trimmed = p.trim();
      // 去除全角空格干扰
      while (trimmed.startsWith('　')) {
        trimmed = trimmed.substring(1).trim();
      }
      if (trimmed.isNotEmpty) {
        paragraphs.add(trimmed);
      }
    }

    // 3. 分页状态变量
    List<String> pages = [];
    StringBuffer currentPageContent = StringBuffer();
    double currentY = 0;
    double maxPageHeight = height - 1.0; 

    // 辅助函数：提交当前页
    void commitPage() {
      if (currentPageContent.isNotEmpty) {
        // 去除页末可能多余的换行符
        String pageData = currentPageContent.toString();
        while (pageData.endsWith('\n')) {
          pageData = pageData.substring(0, pageData.length - 1);
        }
        pages.add(pageData);
        currentPageContent.clear();
      }
      currentY = 0;
    }

    // === 段落循环 ===
    for (int i = 0; i < paragraphs.length; i++) {
      String paraText = paragraphs[i];
      
      // 判断是否是标题
      bool isTitle = hasTitle && i == 0;
      
      // 这里的 paragraphs[i] 已经是清洗过的非空文本（除了标题后插入的空字符串）
      if (paraText.isEmpty) {
        // 仅用于标题后的空行
        double emptyLineHeight = fontSize * lineHeight;
        if (currentY + emptyLineHeight > maxPageHeight) {
          commitPage();
        }
        currentPageContent.write('\n');
        currentY += emptyLineHeight;
        continue;
      }

      // 添加缩进：标题不缩进，正文统一缩进
      String indentedPara = isTitle ? paraText : (indentChar * indentSize) + paraText;

      final textPainter = TextPainter(
        text: TextSpan(text: indentedPara, style: textStyle),
        textDirection: ui.TextDirection.ltr,
        textAlign: TextAlign.justify,
      );
      textPainter.layout(maxWidth: width);

      List<ui.LineMetrics> lines = textPainter.computeLineMetrics();
      
      for (int lineIndex = 0; lineIndex < lines.length; lineIndex++) {
        final line = lines[lineIndex];
        final lineH = line.height;

        if (currentY + lineH > maxPageHeight) {
          commitPage(); 
        }

        // 获取当前行文本
        double lineTop = 0;
        for (int k = 0; k < lineIndex; k++) {
          lineTop += lines[k].height;
        }
        double lineCenterY = lineTop + lineH / 2;
        int startOffset = textPainter.getPositionForOffset(Offset(0, lineCenterY)).offset;
        var range = textPainter.getLineBoundary(TextPosition(offset: startOffset));
        String lineText = indentedPara.substring(range.start, range.end);
        
        currentPageContent.write(lineText);
        currentY += lineH;
        
        // 段落结束处理
        if (lineIndex == lines.length - 1) {
           currentPageContent.write('\n'); 
           
           // 段落间距逻辑：如果设置了段距且足够大，插入空行模拟
           if (paragraphSpacing > fontSize * 0.5) {
              double spacingHeight = fontSize * lineHeight; // 模拟一个空行的高度
              // 只有当剩余空间足够放一个空行时才插入，避免页面底部只有空行
              if (currentY + spacingHeight <= maxPageHeight) {
                 currentPageContent.write('\n');
                 currentY += spacingHeight;
              }
           }
        }
      }
    }

    if (currentPageContent.isNotEmpty) {
      pages.add(currentPageContent.toString().trimRight());
    }
    
    if (pages.isEmpty) {
        pages.add(''); 
    }

    return pages;
  }
}

