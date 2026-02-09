import 'dart:io';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class CookieStore {
  static CookieJar? _jar;

  static bool get isInitialized => _jar != null;

  static CookieJar get jar {
    final v = _jar;
    if (v == null) {
      throw StateError('CookieStore 未初始化，请在 main() 启动阶段调用 CookieStore.setup()');
    }
    return v;
  }

  static Future<void> setup() async {
    if (_jar != null) return;

    if (kIsWeb) {
      // Web 环境下不走本地文件系统，退化为内存 CookieJar（会随页面刷新丢失）。
      _jar = CookieJar(ignoreExpires: false);
      return;
    }

    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/.cookies');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    final storage = FileStorage(dir.path);
    _jar = PersistCookieJar(
      storage: storage,
      ignoreExpires: false,
    );
  }

  static Future<void> saveFromResponse(Uri uri, List<Cookie> cookies) async {
    await jar.saveFromResponse(uri, cookies);
  }

  static Future<List<Cookie>> loadForRequest(Uri uri) async {
    return jar.loadForRequest(uri);
  }

  static Future<void> deleteAll() async {
    await jar.deleteAll();
  }
}
