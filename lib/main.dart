import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';

import 'app/bootstrap/app_bootstrap.dart';
import 'app/soup_reader_app.dart';
import 'app/widgets/app_error_widget.dart';
import 'core/services/exception_log_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // ── 第一步：立即 runApp，渲染极简 UI 证明 Flutter engine 正常 ──
  // 如果这个都白屏，说明是 iOS native 层/打包/签名问题。
  runApp(const _BootProbeApp());

  // ── 第二步：异步执行 bootstrap，完成后替换 UI ──
  _asyncBoot();
}

Future<void> _asyncBoot() async {
  debugPrint('[boot] _asyncBoot start');

  // Release 模式下默认 ErrorWidget 常退化为灰色方块。
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
  };

  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    debugPrint('[platform-error] $error');
    ExceptionLogService().record(
      node: 'global.platform_error',
      message: 'PlatformDispatcher.onError',
      error: error,
      stackTrace: stack,
    );
    return true;
  };

  BootFailure? bootFailure;
  try {
    debugPrint('[boot] bootstrapApp start');
    bootFailure = await bootstrapApp().timeout(const Duration(seconds: 30),
        onTimeout: () {
      debugPrint('[boot] bootstrapApp TIMEOUT after 30s');
      return BootFailure(
        stepName: 'timeout',
        error: 'Bootstrap 超时（30 秒），可能某步初始化 hang 住了。',
        stack: StackTrace.current,
      );
    });
    debugPrint('[boot] bootstrapApp done, failure=$bootFailure');
  } catch (e, st) {
    debugPrint('[boot] bootstrapApp threw: $e');
    bootFailure = BootFailure(stepName: 'bootstrapApp', error: e, stack: st);
  }

  debugPrint('[boot] switching to SoupReaderApp');
  runApp(SoupReaderApp(initialBootFailure: bootFailure));
  debugPrint('[boot] SoupReaderApp mounted');
}

/// 极简探测 App：如果这个能渲染，说明 Flutter engine 正常。
class _BootProbeApp extends StatelessWidget {
  const _BootProbeApp();

  @override
  Widget build(BuildContext context) {
    return CupertinoApp(
      debugShowCheckedModeBanner: false,
      home: CupertinoPageScaffold(
        backgroundColor: const Color(0xFFFFF8E1),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              CupertinoActivityIndicator(radius: 14),
              SizedBox(height: 16),
              Text(
                'SoupReader 正在启动…',
                style: TextStyle(fontSize: 16, color: CupertinoColors.label),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
