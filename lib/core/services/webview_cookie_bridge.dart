import 'dart:io';

import 'package:flutter/services.dart';

class WebViewCookieBridge {
  static const MethodChannel _channel =
      MethodChannel('soupreader/webview_cookies');

  static bool get isSupported => Platform.isIOS;

  static Future<List<Cookie>> getCookiesForDomain(
    String domain, {
    bool includeSubdomains = true,
  }) async {
    if (!isSupported) return const <Cookie>[];
    final raw = await _channel.invokeMethod<List<dynamic>>(
      'getCookies',
      <String, dynamic>{
        'domain': domain,
        'includeSubdomains': includeSubdomains,
      },
    );
    if (raw == null) return const <Cookie>[];

    final out = <Cookie>[];
    for (final item in raw) {
      if (item is! Map) continue;
      final map = item.map((k, v) => MapEntry(k.toString(), v));
      final name = (map['name'] ?? '').toString();
      final value = (map['value'] ?? '').toString();
      final cookieDomain = (map['domain'] ?? '').toString();
      final path = (map['path'] ?? '/').toString();
      final secure = map['secure'] == true;
      final httpOnly = map['httpOnly'] == true;
      final expiresMs = map['expiresMs'];

      if (name.trim().isEmpty) continue;
      final cookie = Cookie(name, value);
      if (cookieDomain.trim().isNotEmpty) cookie.domain = cookieDomain;
      cookie.path = path.isEmpty ? '/' : path;
      cookie.secure = secure;
      cookie.httpOnly = httpOnly;

      if (expiresMs is int) {
        cookie.expires = DateTime.fromMillisecondsSinceEpoch(expiresMs);
      } else if (expiresMs is num) {
        cookie.expires =
            DateTime.fromMillisecondsSinceEpoch(expiresMs.toInt());
      } else if (expiresMs is String) {
        final parsed = int.tryParse(expiresMs);
        if (parsed != null) {
          cookie.expires = DateTime.fromMillisecondsSinceEpoch(parsed);
        }
      }

      out.add(cookie);
    }
    return out;
  }

  static Future<bool> clearAllCookies() async {
    if (!isSupported) return false;
    final ok = await _channel.invokeMethod<bool>('clearAllCookies');
    return ok ?? false;
  }

  static String toCookieHeaderValue(List<Cookie> cookies) {
    if (cookies.isEmpty) return '';
    return cookies.map((c) => '${c.name}=${c.value}').join('; ');
  }
}

