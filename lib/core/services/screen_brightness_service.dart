import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Controls device/app brightness for reading.
///
/// - Android: uses per-window brightness (`WindowManager.LayoutParams.screenBrightness`).
/// - iOS: uses global screen brightness (`UIScreen.main.brightness`).
/// - Web/desktop: not supported; the reader should fall back to an overlay.
class ScreenBrightnessService {
  ScreenBrightnessService._();

  static final ScreenBrightnessService instance = ScreenBrightnessService._();

  static const MethodChannel _channel =
      MethodChannel('soupreader/screen_brightness');

  bool get supportsNative {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  Future<void> setBrightness(double brightness) async {
    if (!supportsNative) return;
    final value = brightness.clamp(0.0, 1.0);
    try {
      await _channel.invokeMethod<void>(
        'setBrightness',
        <String, Object?>{'brightness': value},
      );
    } catch (_) {
      // Best-effort: if the platform channel isn't available, keep UI responsive.
    }
  }

  Future<void> resetToSystem() async {
    if (!supportsNative) return;
    try {
      await _channel.invokeMethod<void>('resetBrightness');
    } catch (_) {
      // Best-effort
    }
  }
}
