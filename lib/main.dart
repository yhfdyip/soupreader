import 'dart:async';
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import 'app/bootstrap/boot_host_app.dart';
import 'app/widgets/app_error_widget.dart';
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

  // 在 Release 下默认 ErrorWidget 往往只是一块灰屏，无法定位异常根因。
  // 这里强制把异常信息渲染到屏幕上，便于截图/复制回传。
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return AppErrorWidget(
      message: details.exceptionAsString(),
      stackTrace: details.stack?.toString(),
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
