import 'dart:async';
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/cupertino.dart';

import 'app/bootstrap/boot_host_app.dart';
import 'app/widgets/app_error_widget.dart';
import 'core/services/exception_log_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // In Release, the default ErrorWidget often degrades into a grey box,
  // making build-time failures hard to diagnose without Xcode logs.
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

