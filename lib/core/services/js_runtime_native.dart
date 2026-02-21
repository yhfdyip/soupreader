import 'package:flutter_js/flutter_js.dart';

abstract class JsRuntime {
  String evaluate(String script);
}

class _FlutterJsRuntime implements JsRuntime {
  JavascriptRuntime? _runtime;
  bool _runtimeUnavailable = false;

  JavascriptRuntime? _ensureRuntime() {
    if (_runtimeUnavailable) {
      return null;
    }
    final cached = _runtime;
    if (cached != null) {
      return cached;
    }
    try {
      final created = getJavascriptRuntime(xhr: false);
      _runtime = created;
      return created;
    } catch (_) {
      _runtimeUnavailable = true;
      return null;
    }
  }

  @override
  String evaluate(String script) {
    final runtime = _ensureRuntime();
    if (runtime == null) {
      return '';
    }
    try {
      return runtime.evaluate(script).stringResult;
    } catch (_) {
      return '';
    }
  }
}

JsRuntime createJsRuntime() => _FlutterJsRuntime();
