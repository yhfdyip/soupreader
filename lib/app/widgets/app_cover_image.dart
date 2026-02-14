import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';

/// 统一书籍封面组件：
/// - 支持远程 URL（带磁盘缓存）
/// - 支持本地文件路径
/// - 失败回退占位封面
class AppCoverImage extends StatelessWidget {
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
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: SizedBox(
        width: width,
        height: height,
        child: _buildContent(context, raw),
      ),
    );
  }

  Widget _buildContent(BuildContext context, String raw) {
    if (raw.isEmpty) {
      return _buildPlaceholder(context);
    }

    if (_isRemote(raw)) {
      return CachedNetworkImage(
        imageUrl: raw,
        fit: fit,
        placeholder: (_, __) => _buildPlaceholder(context, isLoading: true),
        errorWidget: (_, __, ___) => _buildPlaceholder(context),
      );
    }

    if (kIsWeb) {
      return _buildPlaceholder(context);
    }

    return Image.file(
      File(raw),
      fit: fit,
      errorBuilder: (_, __, ___) => _buildPlaceholder(context),
    );
  }

  Widget _buildPlaceholder(
    BuildContext context, {
    bool isLoading = false,
  }) {
    final first = title.trim().isNotEmpty ? title.trim().substring(0, 1) : '?';
    final authorText = (author ?? '').trim();
    final displayText = showTextOnPlaceholder
        ? (authorText.isNotEmpty ? '$first\n$authorText' : first)
        : '';

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFD1A15A),
            Color(0xFF7B5E3A),
          ],
        ),
      ),
      alignment: Alignment.center,
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
                  color: Color(0xFFEFE7DB),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  height: 1.15,
                ),
              ),
            ),
    );
  }
}
