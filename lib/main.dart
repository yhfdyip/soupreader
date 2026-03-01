import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';

import 'app/bootstrap/app_bootstrap.dart';
import 'app/soup_reader_app.dart';
import 'app/widgets/app_error_widget.dart';

/// 调试版：加入 ErrorWidget.builder 以让 tab 页面异常可见。
void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // 让 Release 模式下的渲染异常可见（不再显示为灰色/空白区域）。
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return AppErrorWidget(
      message: details.exceptionAsString(),
      stackTrace: details.stack?.toString(),
    );
  };

  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('[flutter-error] ${details.exceptionAsString()}');
    if (details.stack != null) {
      debugPrintStack(stackTrace: details.stack);
    }
  };

  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    debugPrint('[platform-error] $error');
    debugPrintStack(stackTrace: stack);
    return true;
  };

  // 先显示探测 UI
  runApp(const _TestApp(status: '正在启动...'));

  // 异步 bootstrap 后加载完整 UI
  () async {
    debugPrint('[boot] bootstrap start');
    BootFailure? failure;
    try {
      failure = await bootstrapApp();
    } catch (e, st) {
      debugPrint('[boot] bootstrap threw: $e');
      failure = BootFailure(stepName: 'bootstrapApp', error: e, stack: st);
    }
    debugPrint('[boot] bootstrap done, failure=$failure');

    debugPrint('[boot] runApp SoupReaderApp start');
    runApp(SoupReaderApp(initialBootFailure: failure));
    debugPrint('[boot] runApp SoupReaderApp done');
  }();
}

class _TestApp extends StatelessWidget {
  final String status;
  const _TestApp({required this.status});

  @override
  Widget build(BuildContext context) {
    return CupertinoApp(
      debugShowCheckedModeBanner: false,
      home: CupertinoPageScaffold(
        backgroundColor: const Color(0xFFFFF8E1),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              status,
              style:
                  const TextStyle(fontSize: 18, color: CupertinoColors.label),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}
