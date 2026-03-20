// Scroll-mode content widget extracted from [SimpleReaderView].

import 'package:flutter/cupertino.dart';

import '../models/reader_view_types.dart';
import '../services/reader_image_request_parser.dart';
import '../widgets/legacy_justified_text.dart';
import '../widgets/scroll_segment_paint_view.dart';
import '../widgets/scroll_text_layout_engine.dart';

@immutable
class ScrollContentConfig {
  const ScrollContentConfig({
    required this.fontSize,
    required this.lineHeight,
    required this.letterSpacing,
    required this.paragraphSpacing,
    required this.paragraphIndent,
    required this.textFullJustify,
    required this.textColor,
    required this.fontFamily,
    required this.fontFamilyFallback,
    required this.fontWeight,
    required this.textDecoration,
    required this.titleMode,
    required this.titleSize,
    required this.titleTopSpacing,
    required this.titleBottomSpacing,
    required this.titleTextAlign,
    required this.paddingLeft,
    required this.paddingRight,
    required this.paddingTop,
    required this.paddingBottom,
    required this.paddingDisplayCutouts,
    required this.imageStyle,
    required this.searchHighlightQuery,
    required this.searchHighlightColor,
    required this.searchHighlightTextColor,
  });

  final double fontSize;
  final double lineHeight;
  final double letterSpacing;
  final double paragraphSpacing;
  final String paragraphIndent;
  final bool textFullJustify;
  final Color textColor;
  final String? fontFamily;
  final List<String>? fontFamilyFallback;
  final FontWeight fontWeight;
  final TextDecoration? textDecoration;
  final int titleMode;
  final int titleSize;
  final double titleTopSpacing;
  final double titleBottomSpacing;
  final TextAlign titleTextAlign;
  final double paddingLeft;
  final double paddingRight;
  final double paddingTop;
  final double paddingBottom;
  final bool paddingDisplayCutouts;
  final String imageStyle;
  final String? searchHighlightQuery;
  final Color? searchHighlightColor;
  final Color? searchHighlightTextColor;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! ScrollContentConfig) return false;
    return fontSize == other.fontSize &&
        lineHeight == other.lineHeight &&
        letterSpacing == other.letterSpacing &&
        paragraphSpacing == other.paragraphSpacing &&
        paragraphIndent == other.paragraphIndent &&
        textFullJustify == other.textFullJustify &&
        textColor == other.textColor &&
        fontFamily == other.fontFamily &&
        _listEquals(fontFamilyFallback, other.fontFamilyFallback) &&
        fontWeight == other.fontWeight &&
        textDecoration == other.textDecoration &&
        titleMode == other.titleMode &&
        titleSize == other.titleSize &&
        titleTopSpacing == other.titleTopSpacing &&
        titleBottomSpacing == other.titleBottomSpacing &&
        titleTextAlign == other.titleTextAlign &&
        paddingLeft == other.paddingLeft &&
        paddingRight == other.paddingRight &&
        paddingTop == other.paddingTop &&
        paddingBottom == other.paddingBottom &&
        paddingDisplayCutouts == other.paddingDisplayCutouts &&
        imageStyle == other.imageStyle &&
        searchHighlightQuery == other.searchHighlightQuery &&
        searchHighlightColor == other.searchHighlightColor &&
        searchHighlightTextColor == other.searchHighlightTextColor;
  }

  @override
  int get hashCode => Object.hashAll([
        fontSize,
        lineHeight,
        letterSpacing,
        paragraphSpacing,
        paragraphIndent,
        textFullJustify,
        textColor,
        fontFamily,
        fontWeight,
        textDecoration,
        titleMode,
        titleSize,
        titleTopSpacing,
        titleBottomSpacing,
        titleTextAlign,
        paddingLeft,
        paddingRight,
        paddingTop,
        paddingBottom,
        paddingDisplayCutouts,
        imageStyle,
        searchHighlightQuery,
        searchHighlightColor,
        searchHighlightTextColor,
      ]);

  static bool _listEquals<T>(List<T>? a, List<T>? b) {
    if (a == null) return b == null;
    if (b == null) return false;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  TextStyle get paragraphStyle => TextStyle(
        fontSize: fontSize,
        height: lineHeight,
        letterSpacing: letterSpacing,
        color: textColor,
        fontFamily: fontFamily,
        fontFamilyFallback: fontFamilyFallback,
        fontWeight: fontWeight,
        decoration: textDecoration,
      );

  TextStyle get titleStyle => TextStyle(
        fontSize: fontSize + titleSize,
        fontWeight: FontWeight.w600,
        color: textColor,
        fontFamily: fontFamily,
        fontFamilyFallback: fontFamilyFallback,
      );

  TextStyle fallbackStyle(double size) => TextStyle(
        fontSize: (size - 2).clamp(10.0, 22.0),
        color: textColor.withValues(alpha: 0.7),
        fontFamily: fontFamily,
        fontFamilyFallback: fontFamilyFallback,
      );
}

class ScrollContentView extends StatefulWidget {
  const ScrollContentView({
    super.key,
    required this.config,
    required this.scrollInsets,
    required this.segments,
    required this.segmentsVersion,
    required this.scrollController,
    required this.scrollViewportKey,
    required this.onScrollStart,
    required this.onScrollEnd,
    required this.resolveScrollTextLayout,
    required this.resolveSegmentKey,
    required this.resolveImageProvider,
    required this.normalizeImageSrc,
  });

  final ScrollContentConfig config;
  final EdgeInsets scrollInsets;
  final List<ScrollSegment> segments;
  final ValueNotifier<int> segmentsVersion;
  final ScrollController scrollController;
  final GlobalKey scrollViewportKey;
  final VoidCallback onScrollStart;
  final VoidCallback onScrollEnd;
  final ScrollTextLayout Function({
    required ScrollSegmentSeed seed,
    required double maxWidth,
    required TextStyle style,
  }) resolveScrollTextLayout;
  final GlobalKey Function(int chapterIndex) resolveSegmentKey;
  final ImageProvider<Object>? Function(String src)
      resolveImageProvider;
  final String Function(String raw) normalizeImageSrc;

  @override
  State<ScrollContentView> createState() =>
      ScrollContentViewState();
}

class ScrollContentViewState extends State<ScrollContentView> {
  ScrollContentConfig? _lastConfig;
  EdgeInsets? _lastScrollInsets;
  Widget? _cachedContent;

  @override
  void didUpdateWidget(ScrollContentView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.config != oldWidget.config ||
        widget.scrollInsets != oldWidget.scrollInsets) {
      _cachedContent = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_cachedContent != null &&
        widget.config == _lastConfig &&
        widget.scrollInsets == _lastScrollInsets) {
      return _cachedContent!;
    }
    _lastConfig = widget.config;
    _lastScrollInsets = widget.scrollInsets;
    _cachedContent = _buildContent();
    return _cachedContent!;
  }

  Widget _buildContent() {
    return Padding(
      padding: widget.scrollInsets,
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification.metrics.axis != Axis.vertical) {
            return false;
          }
          if (notification is ScrollStartNotification) {
            widget.onScrollStart();
          }
          if (notification is ScrollEndNotification) {
            widget.onScrollEnd();
          }
          return false;
        },
        child: ValueListenableBuilder<int>(
          valueListenable: widget.segmentsVersion,
          builder: (context, _, __) {
            if (widget.segments.isEmpty) {
              return const Center(
                  child: CupertinoActivityIndicator());
            }
            return SingleChildScrollView(
              key: widget.scrollViewportKey,
              controller: widget.scrollController,
              physics: const BouncingScrollPhysics(
                decelerationRate:
                    ScrollDecelerationRate.fast,
              ),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0;
                      i < widget.segments.length;
                      i++)
                    _buildSegmentBody(
                      widget.segments[i],
                      isTailSegment:
                          i == widget.segments.length - 1,
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildSegmentBody(ScrollSegment segment,
      {required bool isTailSegment}) {
    final cfg = widget.config;
    final bodyWidth = _resolveBodyWidth();
    final imageBlocks =
        _buildImageRenderBlocks(segment.content);
    final contentBody = imageBlocks == null
        ? ScrollSegmentPaintView(
            layout: widget.resolveScrollTextLayout(
              seed: ScrollSegmentSeed(
                chapterId: segment.chapterId,
                title: segment.title,
                content: segment.content,
              ),
              maxWidth: bodyWidth,
              style: cfg.paragraphStyle,
            ),
            style: cfg.paragraphStyle,
            highlightQuery: cfg.searchHighlightQuery,
            highlightColor: cfg.searchHighlightColor,
            highlightTextColor:
                cfg.searchHighlightTextColor,
          )
        : _buildImageAwareBody(
            blocks: imageBlocks,
            bodyWidth: bodyWidth,
          );

    return KeyedSubtree(
      key: widget
          .resolveSegmentKey(segment.chapterIndex),
      child: Padding(
        padding: EdgeInsets.only(
          left: cfg.paddingLeft,
          right: cfg.paddingRight,
          top: cfg.paddingTop,
          bottom: cfg.paddingBottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (cfg.titleMode != 2) ...[
              SizedBox(height: cfg.titleTopSpacing),
              SizedBox(
                width: double.infinity,
                child: Text(
                  segment.title,
                  textAlign: cfg.titleTextAlign,
                  style: cfg.titleStyle,
                ),
              ),
              SizedBox(height: cfg.titleBottomSpacing),
            ],
            contentBody,
            SizedBox(
                height: isTailSegment ? 80 : 24),
          ],
        ),
      ),
    );
  }

  List<ReaderRenderBlock>? _buildImageRenderBlocks(
      String content) {
    final imageStyle = widget.config.imageStyle;
    if (imageStyle == legacyImageStyleText ||
        !legacyImageTagRegex.hasMatch(content)) {
      return null;
    }
    final blocks = <ReaderRenderBlock>[];
    var cursor = 0;
    for (final match
        in legacyImageTagRegex.allMatches(content)) {
      final before =
          content.substring(cursor, match.start);
      if (before.trim().isNotEmpty) {
        blocks.add(ReaderRenderBlock.text(before));
      }
      final rawSrc = (match.group(1) ?? '').trim();
      final src = widget.normalizeImageSrc(rawSrc);
      if (src.isNotEmpty) {
        blocks.add(ReaderRenderBlock.image(src));
      }
      cursor = match.end;
    }
    if (cursor < content.length) {
      final trailing = content.substring(cursor);
      if (trailing.trim().isNotEmpty) {
        blocks
            .add(ReaderRenderBlock.text(trailing));
      }
    }
    if (!blocks.any((b) => b.isImage)) return null;
    return blocks;
  }

  Widget _buildImageAwareBody({
    required List<ReaderRenderBlock> blocks,
    required double bodyWidth,
  }) {
    final cfg = widget.config;
    final children = <Widget>[];
    for (var i = 0; i < blocks.length; i++) {
      final block = blocks[i];
      if (block.isImage) {
        children.add(_buildImageBlock(
            src: block.imageSrc ?? '',
            bodyWidth: bodyWidth));
      } else if ((block.text ?? '').trim().isNotEmpty) {
        children.add(
          LegacyJustifiedTextBlock(
            content: block.text ?? '',
            style: cfg.paragraphStyle,
            justify: cfg.textFullJustify,
            paragraphIndent: cfg.paragraphIndent,
            applyParagraphIndent: true,
            preserveEmptyLines: true,
          ),
        );
      }
      if (i != blocks.length - 1) {
        children.add(SizedBox(
            height: cfg.paragraphSpacing
                .clamp(4.0, 24.0)
                .toDouble()));
      }
    }
    if (children.isEmpty) return const SizedBox.shrink();
    return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children);
  }

  Widget _buildImageBlock(
      {required String src, required double bodyWidth}) {
    final cfg = widget.config;
    final request = ReaderImageRequestParser.parse(src);
    final displaySrc = request.url.trim().isEmpty
        ? src.trim()
        : request.url;
    final imageProvider =
        widget.resolveImageProvider(src);
    if (imageProvider == null) {
      return _buildImageFallback(displaySrc);
    }

    final forceFullWidth =
        cfg.imageStyle == legacyImageStyleFull ||
            cfg.imageStyle == legacyImageStyleSingle;
    final image = Image(
      image: imageProvider,
      width: forceFullWidth ? bodyWidth : null,
      fit: forceFullWidth
          ? BoxFit.fitWidth
          : BoxFit.contain,
      filterQuality: FilterQuality.medium,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return const SizedBox(
          width: double.infinity,
          child: Padding(
            padding:
                EdgeInsets.symmetric(vertical: 12),
            child: Center(
                child: CupertinoActivityIndicator()),
          ),
        );
      },
      errorBuilder: (_, __, ___) =>
          _buildImageFallback(displaySrc),
    );
    final imageBox = ConstrainedBox(
        constraints:
            BoxConstraints(maxWidth: bodyWidth),
        child: image);

    if (cfg.imageStyle == legacyImageStyleSingle) {
      final viewportHeight =
          MediaQuery.sizeOf(context).height;
      final singleHeight = (viewportHeight -
              cfg.paddingTop -
              cfg.paddingBottom)
          .clamp(220.0, 1200.0)
          .toDouble();
      return SizedBox(
          height: singleHeight,
          child: Center(child: imageBox));
    }
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(
            vertical: (cfg.paragraphSpacing / 2)
                .clamp(6.0, 20.0)
                .toDouble()),
        child: imageBox,
      ),
    );
  }

  Widget _buildImageFallback(String src) {
    final display = src.trim();
    final message = display.isEmpty
        ? '图片加载失败'
        : '图片加载失败：$display';
    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.symmetric(vertical: 8),
      alignment: Alignment.centerLeft,
      child: Text(message,
          style: widget.config
              .fallbackStyle(widget.config.fontSize)),
    );
  }

  double _resolveBodyWidth() {
    final mediaQuery = MediaQuery.maybeOf(context);
    if (mediaQuery == null) return 320.0;
    final cfg = widget.config;
    final screenSize = mediaQuery.size;
    final safePadding = mediaQuery.padding;
    final horizontalSafeInset =
        cfg.paddingDisplayCutouts
            ? safePadding.left + safePadding.right
            : 0.0;
    return (screenSize.width -
            horizontalSafeInset -
            cfg.paddingLeft -
            cfg.paddingRight)
        .clamp(1.0, double.infinity)
        .toDouble();
  }
}

/// 全屏图片预览页，支持双指缩放和平移。
class ImagePreviewPage extends StatelessWidget {
  final ImageProvider imageProvider;

  const ImagePreviewPage(
      {super.key, required this.imageProvider});

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.black,
      navigationBar: CupertinoNavigationBar(
        backgroundColor:
            CupertinoColors.black.withValues(alpha: 0.7),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => Navigator.of(context).pop(),
          child: const Icon(
            CupertinoIcons.xmark,
            color: CupertinoColors.white,
          ),
        ),
      ),
      child: SafeArea(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 8.0,
          child: Center(
            child: Image(
              image: imageProvider,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => Icon(
                CupertinoIcons.photo,
                color: CupertinoColors.systemGrey
                    .resolveFrom(context),
                size: 64,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
