import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';

import 'app/bootstrap/app_bootstrap.dart';
import 'app/soup_reader_app.dart';
import 'app/widgets/app_error_widget.dart';
import 'core/services/exception_log_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Release 模式下默认 ErrorWidget 常退化为灰色方块，
  // 在无 Xcode 日志时难以诊断构建期故障。
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

  runZonedGuarded(() async {
    // 在 runApp 之前完成全部初始化（platform channel 在干净的 event loop 中执行，
    // 避免与 Widget 渲染循环竞争导致 iOS Release 模式下白屏/hang）。
    debugPrint('[boot] bootstrap start');
    final bootFailure = await bootstrapApp();
    debugPrint('[boot] bootstrap done, failure=$bootFailure');

    debugPrint('[boot] runApp start');
    runApp(SoupReaderApp(initialBootFailure: bootFailure));
    debugPrint('[boot] runApp done');
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
