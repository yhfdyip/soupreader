enum SourceDebugIntentType {
  search,
  bookInfo,
  explore,
  toc,
  content,
}

class SourceDebugIntent {
  final SourceDebugIntentType type;
  final String rawKey;
  final String runKey;
  final String? keyword;
  final String? url;
  final String? exploreTitle;

  const SourceDebugIntent({
    required this.type,
    required this.rawKey,
    required this.runKey,
    this.keyword,
    this.url,
    this.exploreTitle,
  });

  String get label {
    switch (type) {
      case SourceDebugIntentType.search:
        return '搜索';
      case SourceDebugIntentType.bookInfo:
        return '详情';
      case SourceDebugIntentType.explore:
        return '发现';
      case SourceDebugIntentType.toc:
        return '目录';
      case SourceDebugIntentType.content:
        return '正文';
    }
  }
}

class SourceDebugParseResult {
  final SourceDebugIntent? intent;
  final String? error;

  const SourceDebugParseResult._({
    required this.intent,
    required this.error,
  });

  const SourceDebugParseResult.success(SourceDebugIntent intent)
      : this._(intent: intent, error: null);

  const SourceDebugParseResult.failure(String message)
      : this._(intent: null, error: message);

  bool get ok => intent != null;
}

/// 调试 key 语义解析：
/// - 绝对 URL: 详情调试
/// - 包含 :: : 发现调试（substringAfter("::")）
/// - ++ 开头: 目录调试
/// - -- 开头: 正文调试
/// - 其它: 搜索调试
class SourceDebugKeyParser {
  const SourceDebugKeyParser();

  SourceDebugParseResult parse(String input) {
    final raw = input.trim();
    if (raw.isEmpty) {
      return const SourceDebugParseResult.failure('请输入 key');
    }

    if (_isAbsUrl(raw)) {
      return SourceDebugParseResult.success(
        SourceDebugIntent(
          type: SourceDebugIntentType.bookInfo,
          rawKey: raw,
          runKey: raw,
          url: raw,
        ),
      );
    }

    if (raw.startsWith('++')) {
      final url = raw.substring(2).trim();
      if (url.isEmpty) {
        return const SourceDebugParseResult.failure(
            '目录调试 key 缺少 URL（格式：++url）');
      }
      return SourceDebugParseResult.success(
        SourceDebugIntent(
          type: SourceDebugIntentType.toc,
          rawKey: raw,
          runKey: '++$url',
          url: url,
        ),
      );
    }

    if (raw.startsWith('--')) {
      final url = raw.substring(2).trim();
      if (url.isEmpty) {
        return const SourceDebugParseResult.failure(
            '正文调试 key 缺少 URL（格式：--url）');
      }
      return SourceDebugParseResult.success(
        SourceDebugIntent(
          type: SourceDebugIntentType.content,
          rawKey: raw,
          runKey: '--$url',
          url: url,
        ),
      );
    }

    if (raw.contains('::')) {
      final separator = raw.indexOf('::');
      final title = separator > 0 ? raw.substring(0, separator).trim() : '';
      final url = raw.substring(separator + 2).trim();
      if (url.isEmpty) {
        return const SourceDebugParseResult.failure(
            '发现调试 key 缺少 URL（格式：标题::url）');
      }
      final normalizedTitle = title.isEmpty ? '发现' : title;
      return SourceDebugParseResult.success(
        SourceDebugIntent(
          type: SourceDebugIntentType.explore,
          rawKey: raw,
          runKey: '$normalizedTitle::$url',
          url: url,
          exploreTitle: normalizedTitle,
        ),
      );
    }

    return SourceDebugParseResult.success(
      SourceDebugIntent(
        type: SourceDebugIntentType.search,
        rawKey: raw,
        runKey: raw,
        keyword: raw,
      ),
    );
  }

  bool _isAbsUrl(String key) {
    final lower = key.toLowerCase();
    return lower.startsWith('http://') || lower.startsWith('https://');
  }
}
