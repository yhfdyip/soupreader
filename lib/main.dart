import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';

import 'app/bootstrap/app_bootstrap.dart';
import 'app/soup_reader_app.dart';
import 'core/services/exception_log_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // ── 全局错误处理 ──
  // 注意：不设置 ErrorWidget.builder。
  // 在 Release 模式下，默认 ErrorWidget 显示为灰色方块，虽然不好看但不会引发
  // 递归 Stack Overflow。自定义 ErrorWidget（如 CupertinoPageScaffold 等）在缺少
  // CupertinoTheme 上下文时自身也会 crash，导致无限递归白屏。

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

  // ── 启动流程 ──
  // 与 main 分支保持同一模式：在 runApp 之前完成全部初始化，
  // 避免与 Widget 渲染循环竞争导致 iOS Release 模式白屏/hang。
  // 不使用"先渲染后初始化"的双 runApp 模式（可能与 CupertinoTabScaffold 冲突）。
  runZonedGuarded(() async {
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
