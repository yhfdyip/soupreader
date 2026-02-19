import 'source_host_group_helper.dart';

class SourceCookieScopeResolver {
  const SourceCookieScopeResolver._();

  static List<Uri> resolveClearCandidates(String sourceUrl) {
    final uris = <Uri>[];
    final seen = <String>{};

    void pushAll(Iterable<Uri> values) {
      for (final uri in values) {
        final key = uri.toString();
        if (seen.add(key)) {
          uris.add(uri);
        }
      }
    }

    // 对齐 legado 的清理口径：既清理书源 URL 作用域，也补充主域作用域。
    pushAll(resolveCandidates(sourceUrl));
    pushAll(resolveDomainCandidates(sourceUrl));
    return uris;
  }

  static List<Uri> resolveCandidates(String sourceUrl) {
    final baseUris = _resolveBaseUris(sourceUrl);
    final uris = <Uri>[];
    final seen = <String>{};
    void push(Uri uri) {
      final key = uri.toString();
      if (seen.add(key)) {
        uris.add(uri);
      }
    }

    for (final uri in baseUris) {
      push(uri);
      final root = Uri(
        scheme: uri.scheme,
        userInfo: uri.userInfo,
        host: uri.host,
        port: uri.hasPort ? uri.port : null,
      );
      push(root);
    }

    return uris;
  }

  static List<Uri> resolveDomainCandidates(String sourceUrl) {
    final baseUris = _resolveBaseUris(sourceUrl);
    final uris = <Uri>[];
    final seen = <String>{};
    void push(Uri uri) {
      final key = uri.toString();
      if (seen.add(key)) {
        uris.add(uri);
      }
    }

    for (final uri in baseUris) {
      final host = _normalizeHost(uri.host);
      if (host.isEmpty) continue;

      final hostRoot = Uri(
        scheme: uri.scheme,
        userInfo: uri.userInfo,
        host: host,
        port: uri.hasPort ? uri.port : null,
      );
      push(hostRoot);

      final groupedHost = _effectiveDomainHost(host);
      if (groupedHost.isEmpty || groupedHost == host) continue;

      final groupedRoot = Uri(
        scheme: uri.scheme,
        userInfo: uri.userInfo,
        host: groupedHost,
      );
      push(groupedRoot);
    }

    return uris;
  }

  static List<Uri> _resolveBaseUris(String sourceUrl) {
    final raw = sourceUrl.trim();
    if (raw.isEmpty) return const <Uri>[];

    final candidates = <String>{raw};
    final beforeComma = raw.split(',').first.trim();
    if (beforeComma.isNotEmpty) {
      candidates.add(beforeComma);
    }

    final uris = <Uri>[];
    final seen = <String>{};
    for (final text in candidates) {
      final uri = Uri.tryParse(text);
      if (uri == null) continue;
      final scheme = uri.scheme.toLowerCase();
      if (scheme != 'http' && scheme != 'https') continue;
      final host = _normalizeHost(uri.host);
      if (host.isEmpty) continue;

      final normalized = Uri(
        scheme: uri.scheme,
        userInfo: uri.userInfo,
        host: host,
        port: uri.hasPort ? uri.port : null,
        path: uri.path,
        query: uri.query.isEmpty ? null : uri.query,
        fragment: uri.fragment.isEmpty ? null : uri.fragment,
      );
      final key = normalized.toString();
      if (seen.add(key)) {
        uris.add(normalized);
      }
    }
    return uris;
  }

  static String _normalizeHost(String host) {
    final trimmed = host.trim().toLowerCase();
    if (trimmed.isEmpty) return '';
    final commaIndex = trimmed.indexOf(',');
    if (commaIndex <= 0) return trimmed;
    return trimmed.substring(0, commaIndex).trim();
  }

  static String _effectiveDomainHost(String host) {
    final grouped = SourceHostGroupHelper.groupHost('https://$host').trim();
    if (grouped.isEmpty || grouped == '#') return host;
    return grouped;
  }
}
