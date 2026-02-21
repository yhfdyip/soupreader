import 'dart:convert';

class ReaderImageRequest {
  final String raw;
  final String url;
  final Map<String, String> headers;

  const ReaderImageRequest({
    required this.raw,
    required this.url,
    this.headers = const <String, String>{},
  });
}

class ReaderImageRequestParser {
  const ReaderImageRequestParser._();

  static ReaderImageRequest parse(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return const ReaderImageRequest(raw: '', url: '');
    }
    if (_isDataImageUrl(trimmed)) {
      return ReaderImageRequest(raw: trimmed, url: trimmed);
    }

    final split = _splitLegacyUrlOption(trimmed);
    final option = split.optionRaw == null
        ? null
        : _tryParseOptionMap(split.optionRaw!);
    final headers = <String, String>{}
      ..addAll(_coerceHeaderMap(option?['header']))
      ..addAll(_coerceHeaderMap(option?['headers']));
    final normalizedUrl = split.url.trim();
    return ReaderImageRequest(
      raw: trimmed,
      url: normalizedUrl.isEmpty ? trimmed : normalizedUrl,
      headers: headers,
    );
  }

  static Map<String, String> parseHeaderText(String? rawHeader) {
    if (rawHeader == null || rawHeader.trim().isEmpty) {
      return const <String, String>{};
    }
    return _coerceHeaderMap(rawHeader);
  }

  static bool _isDataImageUrl(String value) {
    return value.toLowerCase().startsWith('data:image');
  }

  static ({String url, String? optionRaw}) _splitLegacyUrlOption(String value) {
    if (!value.endsWith('}')) {
      return (url: value, optionRaw: null);
    }

    final optionStart = value.lastIndexOf(',{');
    if (optionStart > 0) {
      final optionRaw = value.substring(optionStart + 1).trim();
      if (_looksLikeJsonObject(optionRaw)) {
        return (
          url: value.substring(0, optionStart).trim(),
          optionRaw: optionRaw,
        );
      }
    }

    final braceStart = value.lastIndexOf('{');
    if (braceStart > 0) {
      final optionRaw = value.substring(braceStart).trim();
      if (_looksLikeJsonObject(optionRaw)) {
        return (
          url: value.substring(0, braceStart).trim(),
          optionRaw: optionRaw,
        );
      }
    }
    return (url: value, optionRaw: null);
  }

  static bool _looksLikeJsonObject(String value) {
    final trimmed = value.trim();
    return trimmed.length >= 2 &&
        trimmed.startsWith('{') &&
        trimmed.endsWith('}');
  }

  static Map<String, dynamic>? _tryParseOptionMap(String raw) {
    final trimmed = raw.trim();
    if (!_looksLikeJsonObject(trimmed)) return null;
    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is Map) {
        return decoded.map(
          (key, value) => MapEntry(key.toString(), value),
        );
      }
    } catch (_) {
      // ignore malformed option payload
    }
    return null;
  }

  static Map<String, String> _coerceHeaderMap(dynamic raw) {
    if (raw == null) return const <String, String>{};

    final out = <String, String>{};
    if (raw is Map) {
      raw.forEach((key, value) {
        if (key == null || value == null) return;
        final normalizedKey = key.toString().trim();
        if (normalizedKey.isEmpty) return;
        out[normalizedKey] = value.toString();
      });
      return out;
    }

    final text = raw.toString().trim();
    if (text.isEmpty) return out;

    if (_looksLikeJsonObject(text)) {
      try {
        final decoded = jsonDecode(text);
        if (decoded is Map) {
          decoded.forEach((key, value) {
            if (key == null || value == null) return;
            final normalizedKey = key.toString().trim();
            if (normalizedKey.isEmpty) return;
            out[normalizedKey] = value.toString();
          });
          return out;
        }
      } catch (_) {
        // fallback to line parser
      }
    }

    for (final line in text.split('\n')) {
      final trimmedLine = line.trim();
      if (trimmedLine.isEmpty) continue;
      final index = trimmedLine.indexOf(':');
      if (index <= 0) continue;
      final key = trimmedLine.substring(0, index).trim();
      if (key.isEmpty) continue;
      final value = trimmedLine.substring(index + 1).trim();
      out[key] = value;
    }
    return out;
  }
}
