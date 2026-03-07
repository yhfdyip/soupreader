/// 启动阶段的轻量日志缓冲，负责裁剪和导出展示内容。
class BootLogBuffer {
  final int _maxLines;
  final int _visibleLines;
  final List<String> _lines = <String>[];

  /// 创建固定容量的启动日志缓冲。
  BootLogBuffer({
    required int maxLines,
    required int visibleLines,
  })  : _maxLines = maxLines,
        _visibleLines = visibleLines;

  /// 是否已经记录过日志。
  bool get hasLogs => _lines.isNotEmpty;

  /// 追加一条日志并按容量裁剪。
  void append(String message) {
    _lines.add(message);
    final overflow = _lines.length - _maxLines;
    if (overflow > 0) {
      _lines.removeRange(0, overflow);
    }
  }

  /// 清空当前缓冲中的所有日志。
  void clear() => _lines.clear();

  /// 返回完整日志文本。
  String payload() => _lines.join('\n').trim();

  /// 返回最后一条日志，若为空则返回空字符串。
  String latestLine() {
    if (_lines.isEmpty) return '';
    return _lines.last.trim();
  }

  /// 返回最近若干条日志，按最新优先排列。
  String tailPayload() {
    if (_lines.isEmpty) return '';
    final start = (_lines.length - _visibleLines).clamp(0, _lines.length);
    return _lines.sublist(start).reversed.join('\n').trim();
  }
}
