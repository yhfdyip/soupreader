import 'dart:async';
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/cupertino.dart';

import '../../core/services/exception_log_service.dart';

/// 安装应用级全局异常处理入口。
void installGlobalErrorHandlers({
  required ExceptionLogService exceptionLogService,
}) {
  FlutterError.onError = (FlutterErrorDetails details) {
    _handleFlutterError(details, exceptionLogService);
  };
  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    return _handlePlatformError(
      error: error,
      stackTrace: stack,
      exceptionLogService: exceptionLogService,
    );
  };
}

/// 在受保护的 Zone 中启动应用，并统一记录未处理异常。
void runGuardedApp(
  VoidCallback appRunner, {
  required ExceptionLogService exceptionLogService,
}) {
  runZonedGuarded(appRunner, (Object error, StackTrace stack) {
    debugPrint('[zone-error] $error');
    _recordGlobalError(
      exceptionLogService: exceptionLogService,
      node: 'global.zone_error',
      message: 'runZonedGuarded 捕获未处理异常',
      error: error,
      stackTrace: stack,
    );
    debugPrintStack(stackTrace: stack);
  });
}

void _handleFlutterError(
  FlutterErrorDetails details,
  ExceptionLogService exceptionLogService,
) {
  FlutterError.presentError(details);
  debugPrint('[flutter-error] ${details.exceptionAsString()}');
  _recordGlobalError(
    exceptionLogService: exceptionLogService,
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
}

bool _handlePlatformError({
  required Object error,
  required StackTrace stackTrace,
  required ExceptionLogService exceptionLogService,
}) {
  debugPrint('[platform-error] $error');
  _recordGlobalError(
    exceptionLogService: exceptionLogService,
    node: 'global.platform_error',
    message: 'PlatformDispatcher.onError',
    error: error,
    stackTrace: stackTrace,
  );
  debugPrintStack(stackTrace: stackTrace);
  return true;
}

void _recordGlobalError({
  required ExceptionLogService exceptionLogService,
  required String node,
  required String message,
  required Object error,
  required StackTrace? stackTrace,
  Map<String, dynamic>? context,
}) {
  exceptionLogService.record(
    node: node,
    message: message,
    error: error,
    stackTrace: stackTrace,
    context: context,
  );
}
