import 'dart:typed_data';

import 'package:flutter/cupertino.dart';

import '../../features/source/models/book_source.dart';
import '../../features/source/services/source_cover_loader.dart';
import 'app_cover_image.dart';

enum SourceAwareCoverLoadState {
  emptyUrl,
  loading,
  success,
  failed,
}

/// 带书源上下文的封面组件：
/// - source 为空：沿用普通封面加载
/// - source 不为空且 url 为远程：按书源 header/Cookie/coverDecodeJs 加载
class SourceAwareCoverImage extends StatefulWidget {
  final String? urlOrPath;
  final String title;
  final String? author;
  final BookSource? source;
  final double width;
  final double height;
  final double borderRadius;
  final BoxFit fit;
  final bool showTextOnPlaceholder;
  final ValueChanged<SourceAwareCoverLoadState>? onLoadStateChanged;

  const SourceAwareCoverImage({
    super.key,
    required this.urlOrPath,
    required this.title,
    this.author,
    this.source,
    required this.width,
    required this.height,
    this.borderRadius = 8,
    this.fit = BoxFit.cover,
    this.showTextOnPlaceholder = true,
    this.onLoadStateChanged,
  });

  @override
  State<SourceAwareCoverImage> createState() => _SourceAwareCoverImageState();
}

class _SourceAwareCoverImageState extends State<SourceAwareCoverImage> {
  Future<Uint8List?>? _bytesFuture;
  SourceAwareCoverLoadState? _lastState;

  bool _isRemote(String value) {
    final uri = Uri.tryParse(value);
    final scheme = uri?.scheme.toLowerCase();
    return scheme == 'http' || scheme == 'https';
  }

  String _rawUrl() => (widget.urlOrPath ?? '').trim();

  bool _canUseSourceAwareLoader() {
    final raw = _rawUrl();
    final source = widget.source;
    return source != null && raw.isNotEmpty && _isRemote(raw);
  }

  void _emitLoadState(SourceAwareCoverLoadState state) {
    if (_lastState == state) return;
    _lastState = state;
    widget.onLoadStateChanged?.call(state);
  }

  void _refreshFuture() {
    final raw = _rawUrl();
    if (raw.isEmpty) {
      _emitLoadState(SourceAwareCoverLoadState.emptyUrl);
      _bytesFuture = null;
      return;
    }

    if (!_canUseSourceAwareLoader()) {
      _emitLoadState(SourceAwareCoverLoadState.failed);
      _bytesFuture = null;
      return;
    }
    final source = widget.source!;
    _emitLoadState(SourceAwareCoverLoadState.loading);
    _bytesFuture = SourceCoverLoader.instance.load(
      imageUrl: raw,
      source: source,
    );
  }

  @override
  void initState() {
    super.initState();
    _refreshFuture();
  }

  @override
  void didUpdateWidget(covariant SourceAwareCoverImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.urlOrPath != widget.urlOrPath ||
        oldWidget.source?.bookSourceUrl != widget.source?.bookSourceUrl) {
      _refreshFuture();
    }
  }

  Widget _buildFallback({String? urlOrPath}) {
    return AppCoverImage(
      urlOrPath: urlOrPath ?? widget.urlOrPath,
      title: widget.title,
      author: widget.author,
      width: widget.width,
      height: widget.height,
      borderRadius: widget.borderRadius,
      fit: widget.fit,
      showTextOnPlaceholder: widget.showTextOnPlaceholder,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bytesFuture = _bytesFuture;
    if (bytesFuture == null) {
      return _buildFallback();
    }

    return FutureBuilder<Uint8List?>(
      future: bytesFuture,
      builder: (context, snapshot) {
        final bytes = snapshot.data;
        if (bytes != null && bytes.isNotEmpty) {
          _emitLoadState(SourceAwareCoverLoadState.success);
          return ClipRRect(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            child: SizedBox(
              width: widget.width,
              height: widget.height,
              child: Image.memory(
                bytes,
                fit: widget.fit,
                gaplessPlayback: true,
                errorBuilder: (_, __, ___) => _buildFallback(),
              ),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          _emitLoadState(SourceAwareCoverLoadState.loading);
          return _buildFallback(urlOrPath: '');
        }

        _emitLoadState(SourceAwareCoverLoadState.failed);
        return _buildFallback();
      },
    );
  }
}
