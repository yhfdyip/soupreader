import 'dart:async';
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import 'app/bootstrap/boot_host_app.dart';
import 'core/services/exception_log_service.dart';

const MethodChannel _bootOverlayChannel = MethodChannel('soupreader/boot_overlay');

void _hideNativeBootOverlayAfterFirstFrame() {
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    try {
      await _bootOverlayChannel.invokeMethod<void>('hide');
    } catch (e) {
      debugPrint('[boot-overlay] hide failed: $e');
    }
  });
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // ── 全局错误处理 ──
  // 使用只依赖基础 Widget 的安全 ErrorWidget.builder，避免 Release 模式灰屏。
  // 注意：不能使用 CupertinoPageScaffold / CupertinoNavigationBar 等依赖
  // CupertinoTheme 的组件，否则在缺少 theme 祖先时自身也会 crash 导致无限递归白屏。
  ErrorWidget.builder = (FlutterErrorDetails details) {
    debugPrint('[ErrorWidget] ${details.exceptionAsString()}');
    return ColoredBox(
      color: const Color(0xFFFFF4D6),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          'ERROR:\n${details.exceptionAsString()}',
          textDirection: TextDirection.ltr,
          style: const TextStyle(
            color: Color(0xFF333333),
            fontSize: 12,
            decoration: TextDecoration.none,
          ),
        ),
      ),
    );
  };

  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('[flutter-error] ${details.exceptionAsString()}');
    ExceptionLogService().record(
      node: 'global.flutter_error',
      message: details.exceptionAsString(),
      error: details.exception,
      stackTrace: details.stack,
      context: <String, dynamic>{
        if (details.library != null) 'library': details.library!,
      },
    );
    if (details.stack != null) {
      debugPrintStack(stackTrace: details.stack);
    }
  };

  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    debugPrint('[platform-error] $error');
    ExceptionLogService().record(
      node: 'global.platform_error',
      message: 'PlatformDispatcher.onError',
      error: error,
      stackTrace: stack,
    );
    debugPrintStack(stackTrace: stack);
    return true;
  };

  runZonedGuarded(() {
    runApp(const BootHostApp());
    _hideNativeBootOverlayAfterFirstFrame();
  }, (Object error, StackTrace stack) {
    debugPrint('[zone-error] $error');
    ExceptionLogService().record(
      node: 'global.zone_error',
      message: 'runZonedGuarded 捕获未处理异常',
      error: error,
      stackTrace: stack,
    );
    debugPrintStack(stackTrace: stack);
  });
}
