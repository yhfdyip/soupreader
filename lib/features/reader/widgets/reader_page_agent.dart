import 'dart:ui' as ui;
import 'package:flutter/material.dart';

/// 阅读器分页代理
/// 重构：完全对标 Legado TextChapterLayout 逻辑
/// 采用“逐行合成”(Line Composition) 算法，而非简单的整体截断
class ReaderPageAgent {
  // === 配置参数 (对标 Legado) ===
  static const String indentChar = '　'; // 全角空格
  static const int indentSize = 2; // 缩进字符数
  
  // 注意：由于 UI 层 (PagedReaderWidget) 使用单个 TextPainter 渲染整页，
  // 无法在段落之间插入非整数倍行高（如 0.4 行高）。
  // 因此这里暂时将段间距设为 0，以保证计算高度 == 渲染高度。
  // 如果需要真实的段间距，需重构 PagedReaderWidget 改为逐段绘制。
  static const double paragraphSpacingFactor = 0.0; 

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
    // 1. 准备画笔和通用样式
    final textStyle = TextStyle(
      fontSize: fontSize,
      height: lineHeight,
      letterSpacing: letterSpacing,
      fontFamily: fontFamily,
      color: Colors.black, // 颜色不影响排版，但必须指定以避免 assert 错误
    );

    // 2. 预处理文本：按换行符分割段落
    final paragraphs = content.split('\n');
    
    // 如果有标题，插入到最前面，并添加一个空行作为分隔
    bool hasTitle = title != null && title.isNotEmpty;
    if (hasTitle) {
      paragraphs.insert(0, ''); // 标题后的空行
      paragraphs.insert(0, title);
    }

    // 3. 分页状态变量
    List<String> pages = [];
    StringBuffer currentPageContent = StringBuffer();
    double currentY = 0;
    // 留一点 buffer 防止浮点误差导致溢出
    double maxPageHeight = height - 1.0; 

    // 辅助函数：提交当前页
    void commitPage() {
      if (currentPageContent.isNotEmpty) {
        pages.add(currentPageContent.toString());
        currentPageContent.clear();
      }
      currentY = 0; // 重置高度
    }

    // === 段落循环 (Paragraph Loop) ===
    for (int i = 0; i < paragraphs.length; i++) {
      String paraText = paragraphs[i];
      
      // 判断是否是标题段落（不缩进）
      bool isTitle = hasTitle && i == 0;
      
      // 处理空段落（空行）
      if (paraText.isEmpty) {
        double emptyLineHeight = fontSize * lineHeight;
        if (currentY + emptyLineHeight > maxPageHeight) {
          commitPage();
        }
        currentPageContent.write('\n'); // 写入换行符，产生视觉空行
        currentY += emptyLineHeight;
        continue;
      }

      // 添加首行缩进
      // Legado 也是通过添加字符或 indentWidth 实现
      // 标题不缩进
      String indentedPara = isTitle ? paraText : (indentChar * indentSize) + paraText;

      // 使用 TextPainter 测量整个段落
      final textPainter = TextPainter(
        text: TextSpan(text: indentedPara, style: textStyle), // Title 暂时使用相同样式，仅不缩进
        textDirection: ui.TextDirection.ltr,
        textAlign: TextAlign.justify,
      );
      textPainter.layout(maxWidth: width);

      // 获取行信息 (Line Loop)
      List<ui.LineMetrics> lines = textPainter.computeLineMetrics();
      
      // 遍历每一行，决定是否换页
      for (int lineIndex = 0; lineIndex < lines.length; lineIndex++) {
        final line = lines[lineIndex];
        final lineH = line.height;

        // 检查是否溢出
        if (currentY + lineH > maxPageHeight) {
          // 当前行放不下了 -> 换页
          commitPage(); 
        }

        // 计算当前行文本范围 (TextRange)
        // 累加之前行的高度，尽量取每行的垂直中点来命中该行
        double lineTop = 0;
        for (int k = 0; k < lineIndex; k++) {
          lineTop += lines[k].height;
        }
        double lineCenterY = lineTop + lineH / 2;
        
        // 技巧：利用 getPositionForOffset 获取行首位置
        // 注意：TextPainter 布局后，每行行首的 offset 是确定的
        int startOffset = textPainter.getPositionForOffset(Offset(0, lineCenterY)).offset;
        
        // 获取该行文本范围
        var range = textPainter.getLineBoundary(TextPosition(offset: startOffset));
        
        // 提取文本
        String lineText = indentedPara.substring(range.start, range.end);
        
        // 将行内容加入当前页
        currentPageContent.write(lineText);
        
        // 增加高度
        currentY += lineH;
        
        // 如果是段落的最后一行，处理段落结束
        if (lineIndex == lines.length - 1) {
           currentPageContent.write('\n'); 
           // 增加段间距（如果有）
           if (paragraphSpacingFactor > 0) {
              currentY += fontSize * lineHeight * paragraphSpacingFactor;
           }
        }
      }
    }

    // 提交最后一页
    if (currentPageContent.isNotEmpty) {
      pages.add(currentPageContent.toString());
    }
    
    // 兜底
    if (pages.isEmpty) {
        pages.add(''); 
    }

    return pages;
  }
}
