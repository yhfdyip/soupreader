typedef BootLogSink = void Function(String message);

/// Lightweight boot logger used to surface startup progress on-screen.
///
/// Notes:
/// - Intentionally pure Dart: no Flutter imports, safe to call from core layer.
/// - When unbound, calling [add] is a no-op.
class BootLog {
  BootLog._();

  static BootLogSink? _sink;

  static void bind(BootLogSink sink) {
    _sink = sink;
  }

  static void unbind() {
    _sink = null;
  }

  static void add(String message) {
    _sink?.call(message);
  }
}

