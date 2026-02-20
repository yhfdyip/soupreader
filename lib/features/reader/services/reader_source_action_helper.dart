enum ReaderSourcePayActionResultType {
  url,
  success,
  noop,
  unsupported,
}

class ReaderSourcePayActionResult {
  final ReaderSourcePayActionResultType type;
  final String? url;
  final String rawOutput;

  const ReaderSourcePayActionResult._({
    required this.type,
    required this.url,
    required this.rawOutput,
  });

  const ReaderSourcePayActionResult.url(String url)
      : this._(
          type: ReaderSourcePayActionResultType.url,
          url: url,
          rawOutput: '',
        );

  const ReaderSourcePayActionResult.success(String rawOutput)
      : this._(
          type: ReaderSourcePayActionResultType.success,
          url: null,
          rawOutput: rawOutput,
        );

  const ReaderSourcePayActionResult.noop(String rawOutput)
      : this._(
          type: ReaderSourcePayActionResultType.noop,
          url: null,
          rawOutput: rawOutput,
        );

  const ReaderSourcePayActionResult.unsupported(String rawOutput)
      : this._(
          type: ReaderSourcePayActionResultType.unsupported,
          url: null,
          rawOutput: rawOutput,
        );
}

class ReaderSourceActionHelper {
  const ReaderSourceActionHelper._();

  static const List<String> legacyActionOrder = <String>[
    '登录',
    '章节购买',
    '编辑书源',
    '禁用书源',
  ];

  static bool hasLoginUrl(String? loginUrl) {
    return (loginUrl ?? '').trim().isNotEmpty;
  }

  static bool hasPayAction(String? payAction) {
    return (payAction ?? '').trim().isNotEmpty;
  }

  static bool shouldShowChapterPay({
    required bool hasLoginUrl,
    required bool hasPayAction,
    bool? currentChapterIsVip,
    bool? currentChapterIsPay,
  }) {
    if (!hasLoginUrl || !hasPayAction) return false;

    // Legacy uses isVip && !isPay. Flutter side currently may not always
    // have persisted chapter flags, so keep chapter pay visible as fallback.
    if (currentChapterIsVip == null || currentChapterIsPay == null) {
      return true;
    }
    return currentChapterIsVip && !currentChapterIsPay;
  }

  static bool isAbsoluteHttpUrl(String raw) {
    final text = raw.trim().toLowerCase();
    return text.startsWith('http://') || text.startsWith('https://');
  }

  static ReaderSourcePayActionResult resolvePayActionOutput(String output) {
    final text = output.trim();
    final lower = text.toLowerCase();
    if (text.isEmpty ||
        lower == 'null' ||
        lower == 'undefined' ||
        lower == 'false' ||
        lower == '0') {
      return ReaderSourcePayActionResult.noop(text);
    }
    if (isAbsoluteHttpUrl(text)) {
      return ReaderSourcePayActionResult.url(text);
    }
    if (lower == 'true' ||
        lower == '1' ||
        lower == 'ok' ||
        lower == 'success') {
      return ReaderSourcePayActionResult.success(text);
    }
    return ReaderSourcePayActionResult.unsupported(text);
  }
}
