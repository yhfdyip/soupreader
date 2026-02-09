import 'package:flutter_js/flutter_js.dart';

abstract class JsRuntime {
  String evaluate(String script);
}

class _FlutterJsRuntime implements JsRuntime {
  _FlutterJsRuntime() : _runtime = getJavascriptRuntime(xhr: false);

  final JavascriptRuntime _runtime;

  @override
  String evaluate(String script) {
    try {
      return _runtime.evaluate(script).stringResult;
    } catch (_) {
      return '';
    }
  }
}

JsRuntime createJsRuntime() => _FlutterJsRuntime();
