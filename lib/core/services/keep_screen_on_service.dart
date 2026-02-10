import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// 控制阅读时的“屏幕常亮”（防止系统熄屏）。
///
/// - Android: Window FLAG_KEEP_SCREEN_ON
/// - iOS: UIApplication.shared.isIdleTimerDisabled
/// - Web/desktop: 不支持（降级为 no-op）
class KeepScreenOnService {
  KeepScreenOnService._();

  static final KeepScreenOnService instance = KeepScreenOnService._();

  static const MethodChannel _channel =
      MethodChannel('soupreader/keep_screen_on');

  bool get supportsNative {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  Future<void> setEnabled(bool enabled) async {
    if (!supportsNative) return;
    try {
      await _channel.invokeMethod<void>(
        'setEnabled',
        <String, Object?>{'enabled': enabled},
      );
    } catch (_) {
      // Best-effort：保持 UI 响应，不把平台层异常暴露给用户。
    }
  }
}

