import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';

import 'app/bootstrap/app_bootstrap.dart';
import 'app/soup_reader_app.dart';

/// 调试版：内联 ErrorWidget，不 import app_error_widget.dart。
void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // 使用内联的简单 ErrorWidget（不引入任何项目文件）。
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return Container(
      color: const Color(0xFFFFEBEE),
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        child: Text(
          'BUILD ERROR:\n${details.exceptionAsString()}\n\n${details.stack}',
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFFB71C1C),
            decoration: TextDecoration.none,
          ),
        ),
      ),
    );
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
