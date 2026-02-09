abstract class JsRuntime {
  String evaluate(String script);
}

class _StubJsRuntime implements JsRuntime {
  @override
  String evaluate(String script) => '';
}

JsRuntime createJsRuntime() => _StubJsRuntime();
