abstract class JsRuntime {
  String evaluate(String script);
}

class _WebNoopJsRuntime implements JsRuntime {
  @override
  String evaluate(String script) => '';
}

JsRuntime createJsRuntime() => _WebNoopJsRuntime();
