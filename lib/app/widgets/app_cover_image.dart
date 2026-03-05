import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';

import '../theme/design_tokens.dart';

/// 统一书籍封面组件：
/// - 支持远程 URL（带磁盘缓存）
/// - 支持本地文件路径
/// - 失败回退占位封面
class AppCoverImage extends StatelessWidget {
  static const double _kPlaceholderFontSize = 11;

  final String? urlOrPath;
  final String title;
  final String? author;
  final double width;
  final double height;
  final double borderRadius;
  final BoxFit fit;
  final bool showTextOnPlaceholder;

  const AppCoverImage({
    super.key,
    required this.urlOrPath,
    required this.title,
    this.author,
    required this.width,
    required this.height,
    this.borderRadius = 8,
    this.fit = BoxFit.cover,
    this.showTextOnPlaceholder = true,
  });

  bool _isRemote(String value) {
    final uri = Uri.tryParse(value);
    final scheme = uri?.scheme.toLowerCase();
    return scheme == 'http' || scheme == 'https';
  }

  @override
  Widget build(BuildContext context) {
    final raw = (urlOrPath ?? '').trim();
    return AppCoverFrame(
      width: width,
      height: height,
      borderRadius: borderRadius,
      child: _buildContent(context, raw),
    );
  }

  Widget _buildContent(BuildContext context, String raw) {
    if (raw.isEmpty) return _buildPlaceholder(context);
    if (_isRemote(raw)) {
      return CachedNetworkImage(
        imageUrl: raw,
        fit: fit,
        placeholder: (_, __) => _buildPlaceholder(context, isLoading: true),
        errorWidget: (_, __, ___) => _buildPlaceholder(context),
      );
    }
    if (kIsWeb) return _buildPlaceholder(context);
    return Image.file(
      File(raw),
      fit: fit,
      errorBuilder: (_, __, ___) => _buildPlaceholder(context),
    );
  }

  Widget _buildPlaceholder(BuildContext context, {bool isLoading = false}) {
    final first = title.trim().isNotEmpty ? title.trim().substring(0, 1) : '?';
    final authorText = (author ?? '').trim();
    final displayText = showTextOnPlaceholder
        ? (authorText.isNotEmpty ? '$first\n$authorText' : first)
        : '';
    final topColor = AppDesignTokens.brandSecondary.withValues(alpha: 0.82);
    final bottomColor = const Color(0xFF42507A);

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[topColor, bottomColor],
        ),
      ),
      child: Center(
        child: isLoading
            ? const CupertinoActivityIndicator(radius: 10)
            : Padding(
                padding: const EdgeInsets.all(8),
                child: Text(
                  displayText,
                  maxLines: 3,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFFEFF3FF),
                    fontSize: _kPlaceholderFontSize,
                    fontWeight: FontWeight.w600,
                    height: 1.15,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
      ),
    );
  }
}

/// 封面外框：统一 squircle 裁切、细边框与轻阴影。
class AppCoverFrame extends StatelessWidget {
  static const double _kShadowBlur = 16;
  static const double _kShadowSpread = -9;
  static const double _kTopHighlightInset = 10;

  final double width;
  final double height;
  final double borderRadius;
  final Widget child;

  const AppCoverFrame({
    super.key,
    required this.width,
    required this.height,
    required this.borderRadius,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final isDark =
        (CupertinoTheme.of(context).brightness ?? Brightness.light) ==
            Brightness.dark;
    final borderColor =
        CupertinoColors.separator.resolveFrom(context).withValues(alpha: 0.82);
    final topHighlight = isDark
        ? AppDesignTokens.glassInnerHighlightDark
        : AppDesignTokens.glassInnerHighlightLight;
    final shadowColor =
        (isDark ? CupertinoColors.black : const Color(0xFF0B2F66))
            .withValues(alpha: isDark ? 0.24 : 0.13);
    final shape = ContinuousRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(borderRadius)),
      side: BorderSide(
        color: borderColor,
        width: AppDesignTokens.hairlineBorderWidth,
      ),
    );

    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipPath(
            clipper: ShapeBorderClipper(shape: shape),
            child: child,
          ),
          IgnorePointer(
            child: DecoratedBox(
              decoration: ShapeDecoration(
                shape: shape,
                shadows: <BoxShadow>[
                  BoxShadow(
                    color: shadowColor,
                    blurRadius: _kShadowBlur,
                    spreadRadius: _kShadowSpread,
                    offset: const Offset(0, 7),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: _kTopHighlightInset,
            right: _kTopHighlightInset,
            top: 0,
            child: IgnorePointer(
              child: Container(
                height: AppDesignTokens.hairlineBorderWidth,
                color: topHighlight.withValues(alpha: 0.82),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
