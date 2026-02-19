class SourceHostGroupHelper {
  const SourceHostGroupHelper._();

  static final RegExp _strictIpv4Pattern = RegExp(
    r'^(?:\d{1,3}\.){3}\d{1,3}$',
  );
  static final RegExp _domainLabelPattern = RegExp(r'^[a-z0-9-]+$');

  static const Set<String> _multiPartPublicSuffixes = <String>{
    'ac.cn',
    'ah.cn',
    'bj.cn',
    'cq.cn',
    'com.cn',
    'fj.cn',
    'gd.cn',
    'gs.cn',
    'gz.cn',
    'gx.cn',
    'ha.cn',
    'hb.cn',
    'he.cn',
    'hi.cn',
    'hl.cn',
    'hn.cn',
    'jl.cn',
    'js.cn',
    'jx.cn',
    'ln.cn',
    'nm.cn',
    'nx.cn',
    'qh.cn',
    'sc.cn',
    'sd.cn',
    'sh.cn',
    'sn.cn',
    'sx.cn',
    'tj.cn',
    'xj.cn',
    'xz.cn',
    'yn.cn',
    'zj.cn',
    'edu.cn',
    'gov.cn',
    'net.cn',
    'org.cn',
    'com.br',
    'com.mx',
    'com.tr',
    'com.sa',
    'com.sg',
    'com.hk',
    'com.tw',
    'com.au',
    'net.au',
    'org.au',
    'co.nz',
    'co.in',
    'co.id',
    'co.th',
    'co.il',
    'com.my',
    'com.ph',
    'co.jp',
    'co.kr',
    'co.uk',
    'org.uk',
    'gov.uk',
    'ac.uk',
  };

  static String groupHost(String url) {
    final baseUrl = _extractHttpBaseUrl(url);
    if (baseUrl == null) return '#';
    final uri = Uri.tryParse(baseUrl);
    if (uri == null) return '#';

    final scheme = uri.scheme.toLowerCase();
    if (scheme != 'http' && scheme != 'https') return '#';

    final host = uri.host.trim().toLowerCase();
    if (host.isEmpty) return '#';
    if (_isIpAddress(host)) return host;
    if (!_isDomainHost(host)) return '#';

    final labels = host.split('.');
    if (labels.length <= 2) {
      return host;
    }

    final suffix2 = '${labels[labels.length - 2]}.${labels.last}';
    if (_multiPartPublicSuffixes.contains(suffix2) && labels.length >= 3) {
      return '${labels[labels.length - 3]}.$suffix2';
    }
    return suffix2;
  }

  static String? _extractHttpBaseUrl(String url) {
    final raw = url.trim();
    if (raw.isEmpty) return null;
    final lower = raw.toLowerCase();
    if (!lower.startsWith('http://') && !lower.startsWith('https://')) {
      return null;
    }
    final slashIndex = raw.indexOf('/', 9);
    if (slashIndex < 0) return raw;
    return raw.substring(0, slashIndex);
  }

  static bool _isIpAddress(String host) {
    return _isIpv4(host) || _isIpv6(host);
  }

  static bool _isIpv4(String host) {
    if (!_strictIpv4Pattern.hasMatch(host)) return false;
    final firstChar = host.codeUnitAt(0);
    if (firstChar < 49 || firstChar > 57) return false;
    final parts = host.split('.');
    if (parts.length != 4) return false;
    for (final part in parts) {
      final value = int.tryParse(part);
      if (value == null || value < 0 || value > 255) {
        return false;
      }
    }
    return true;
  }

  static bool _isIpv6(String host) {
    return host.contains(':');
  }

  static bool _isDomainHost(String host) {
    if (host.startsWith('.') || host.endsWith('.')) return false;
    if (host.contains(',') ||
        host.contains('%') ||
        host.contains(' ') ||
        host.contains('/')) {
      return false;
    }
    final labels = host.split('.');
    if (labels.any((label) => label.isEmpty)) return false;
    for (final label in labels) {
      if (!_domainLabelPattern.hasMatch(label)) return false;
    }
    return true;
  }
}
