import 'dart:ui' as ui;
import 'package:flutter/widgets.dart';
import '../services/reader_image_marker_codec.dart';

/// 阅读器分页代理
/// 重构：完全对标 Legado TextChapterLayout 逻辑
/// 采用“逐行合成”(Line Composition) 算法，而非简单的整体截断
class ReaderPageAgent {
  // === 配置参数 (对标 Legado) ===
  static const String defaultIndent = '　　'; // 默认两个全角空格
  static const String _defaultImageStyle = 'DEFAULT';
  static const String _imageStyleFull = 'FULL';
  static const String _imageStyleSingle = 'SINGLE';

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
    List<String>? fontFamilyFallback,
    String? title,
    String paragraphIndent = defaultIndent,
    TextAlign textAlign = TextAlign.left,
    double? titleFontSize,
    TextAlign titleAlign = TextAlign.left,
    double titleTopSpacing = 0,
    double titleBottomSpacing = 0,
    FontWeight? fontWeight,
    bool underline = false,
    String imageStyle = _defaultImageStyle,
  }) {
    // 1. 准备画笔和通用样式
    final textStyle = TextStyle(
      fontSize: fontSize,
      height: lineHeight,
      letterSpacing: letterSpacing,
      fontFamily: fontFamily,
      fontFamilyFallback: fontFamilyFallback,
      fontWeight: fontWeight,
      decoration: underline ? TextDecoration.underline : TextDecoration.none,
      color: const Color(0xFF000000), // 颜色不影响排版，但必须指定以避免 assert 错误
    );
    final titleStyle = textStyle.copyWith(
      fontSize: titleFontSize ?? (fontSize + 4),
      fontWeight: FontWeight.w600,
      decoration: TextDecoration.none,
    );

    // 2. 预处理文本：按换行符分割段落，并进行清洗
    //
    // 说明：
    // - 不使用 `trim()`，避免用户关闭缩进时丢失原文前导空白
    // - 当开启段首缩进时，会统一“去掉原文前导空白 + 重新添加缩进”，保证一致性
    String cleanContent = content.replaceAll('\r\n', '\n');
    final rawParagraphs = cleanContent.split('\n');
    final List<String> paragraphs = [];

    // 如果有标题，插入到最前面
    bool hasTitle = title != null && title.isNotEmpty;
    if (hasTitle) {
      paragraphs.add(title);
      paragraphs.add(''); // 标题后的视觉空行
    }

    // 清洗段落（去除行尾空白，过滤空段落）
    for (var p in rawParagraphs) {
      final paragraphText = p.trimRight();
      final trimmedLeft = paragraphText.trimLeft();
      if (trimmedLeft.isNotEmpty) {
        // 保留原文的前导空白（用于“关闭缩进时保留原格式”）
        paragraphs.add(paragraphText);
      }
    }

    // 3. 分页状态变量
    List<String> pages = [];
    StringBuffer currentPageContent = StringBuffer();
    double currentY = 0;
    double maxPageHeight = height - 1.0;
    final normalizedImageStyle = _normalizeImageStyle(imageStyle);

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

      final imageMeta = ReaderImageMarkerCodec.decodeMetaLine(paraText);
      if (imageMeta != null) {
        final marker = paraText.trim();
        final intrinsicSize = _resolveImageIntrinsicSize(imageMeta);
        final imageHeight = _estimateImageBlockHeight(
          imageStyle: normalizedImageStyle,
          maxPageHeight: maxPageHeight,
          contentWidth: width,
          fontSize: fontSize,
          lineHeight: lineHeight,
          imageSize: intrinsicSize,
        );
        final spacingHeight = paragraphSpacing > fontSize * 0.5
            ? fontSize * lineHeight
            : defaultParagraphSpacing;

        if (normalizedImageStyle == _imageStyleSingle) {
          if (currentPageContent.isNotEmpty) {
            commitPage();
          }
          currentPageContent.write(marker);
          currentY = imageHeight;
          if (spacingHeight > 0 && currentY + spacingHeight <= maxPageHeight) {
            currentPageContent.write('\n');
            currentY += spacingHeight;
          }
          commitPage();
          continue;
        }

        if (currentY + imageHeight > maxPageHeight) {
          commitPage();
        }
        currentPageContent.write(marker);
        currentPageContent.write('\n');
        currentY += imageHeight;
        if (spacingHeight > 0 && currentY + spacingHeight <= maxPageHeight) {
          currentPageContent.write('\n');
          currentY += spacingHeight;
        }
        continue;
      }

      // 添加缩进：标题不缩进；正文在开启缩进时统一标准化（去前导空白 + 添加缩进）
      final indent = paragraphIndent;
      final trimmedLeft = paraText.trimLeft();
      final normalizedPara =
          (isTitle || indent.isEmpty) ? paraText : '$indent$trimmedLeft';

      // 标题可设置顶部/底部间距
      if (isTitle && titleTopSpacing > 0) {
        if (currentY + titleTopSpacing > maxPageHeight) {
          commitPage();
        }
        currentY += titleTopSpacing;
      }

      final textPainter = TextPainter(
        text: TextSpan(
          text: normalizedPara,
          style: isTitle ? titleStyle : textStyle,
        ),
        textDirection: ui.TextDirection.ltr,
        textAlign: isTitle ? titleAlign : textAlign,
      );
      textPainter.layout(maxWidth: width);

      List<ui.LineMetrics> lines = textPainter.computeLineMetrics();
      int boundaryOffset = 0;

      for (int lineIndex = 0; lineIndex < lines.length; lineIndex++) {
        final line = lines[lineIndex];
        final lineH = line.height;

        if (currentY + lineH > maxPageHeight) {
          commitPage();
        }

        // 获取当前行文本（用 offset 递增的方式避免丢失行首空白）
        var range = textPainter.getLineBoundary(
          TextPosition(offset: boundaryOffset.clamp(0, normalizedPara.length)),
        );
        // 处理极端情况下 range 不前进导致死循环
        if (range.end <= boundaryOffset &&
            boundaryOffset < normalizedPara.length) {
          boundaryOffset++;
          range = textPainter.getLineBoundary(
            TextPosition(
                offset: boundaryOffset.clamp(0, normalizedPara.length)),
          );
        }
        final lineText = normalizedPara.substring(range.start, range.end);
        boundaryOffset = range.end;

        currentPageContent.write(lineText);
        currentY += lineH;

        // 段落结束处理
        if (lineIndex == lines.length - 1) {
          currentPageContent.write('\n');

          if (isTitle && titleBottomSpacing > 0) {
            if (currentY + titleBottomSpacing > maxPageHeight) {
              commitPage();
            } else {
              currentY += titleBottomSpacing;
            }
          }

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

  static String _normalizeImageStyle(String imageStyle) {
    final normalized = imageStyle.trim().toUpperCase();
    if (normalized.isEmpty) {
      return _defaultImageStyle;
    }
    return normalized;
  }

  static double _estimateImageBlockHeight({
    required String imageStyle,
    required double maxPageHeight,
    required double contentWidth,
    required double fontSize,
    required double lineHeight,
    ui.Size? imageSize,
  }) {
    final width = contentWidth <= 0 ? 320.0 : contentWidth;
    final minLineHeight = (fontSize * lineHeight).clamp(14.0, maxPageHeight);

    if (imageSize != null &&
        imageSize.width > 0 &&
        imageSize.height > 0 &&
        imageSize.width.isFinite &&
        imageSize.height.isFinite) {
      double renderWidth = imageSize.width;
      double renderHeight = imageSize.height;
      switch (imageStyle) {
        case _imageStyleSingle:
          renderWidth = width;
          renderHeight = imageSize.height * renderWidth / imageSize.width;
          if (renderHeight > maxPageHeight) {
            renderWidth = renderWidth * maxPageHeight / renderHeight;
            renderHeight = maxPageHeight;
          }
          break;
        case _imageStyleFull:
          renderWidth = width;
          renderHeight = imageSize.height * renderWidth / imageSize.width;
          if (renderHeight > maxPageHeight) {
            renderWidth = renderWidth * maxPageHeight / renderHeight;
            renderHeight = maxPageHeight;
          }
          break;
        default:
          if (renderWidth > width) {
            renderHeight = renderHeight * width / renderWidth;
            renderWidth = width;
          }
          if (renderHeight > maxPageHeight) {
            renderWidth = renderWidth * maxPageHeight / renderHeight;
            renderHeight = maxPageHeight;
          }
          break;
      }
      return renderHeight.clamp(minLineHeight, maxPageHeight).toDouble();
    }

    switch (imageStyle) {
      case _imageStyleSingle:
        return maxPageHeight.clamp(minLineHeight, maxPageHeight);
      case _imageStyleFull:
        final candidate = width * 0.75;
        return candidate.clamp(minLineHeight * 3, maxPageHeight);
      default:
        final candidate = width * 0.62;
        return candidate.clamp(minLineHeight * 2, maxPageHeight * 0.72);
    }
  }

  static ui.Size? _resolveImageIntrinsicSize(ReaderImageMarkerMeta meta) {
    final resolved = ReaderImageMarkerCodec.lookupResolvedSize(meta.src);
    if (resolved != null &&
        resolved.width > 0 &&
        resolved.height > 0 &&
        resolved.width.isFinite &&
        resolved.height.isFinite) {
      return resolved;
    }
    if (meta.hasDimensionHints) {
      return ui.Size(meta.width!, meta.height!);
    }
    return null;
  }
}
