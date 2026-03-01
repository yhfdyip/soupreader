import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';

import 'app/bootstrap/app_bootstrap.dart';
import 'app/soup_reader_app.dart';

/// 二分法测试 2：引入 bootstrap + SoupReaderApp（完整 UI 链）。
/// 如果白屏 → SoupReaderApp/MainScreen 有渲染问题。
void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // 先显示探测 UI
  runApp(const _TestApp(status: '正在启动...'));

  // 异步 bootstrap 后加载完整 UI
  () async {
    debugPrint('[test] bootstrap start');
    BootFailure? failure;
    try {
      failure = await bootstrapApp();
    } catch (e, st) {
      debugPrint('[test] bootstrap threw: $e');
      failure = BootFailure(stepName: 'bootstrapApp', error: e, stack: st);
    }
    debugPrint('[test] bootstrap done, failure=$failure');

    try {
      debugPrint('[test] runApp SoupReaderApp start');
      runApp(SoupReaderApp(initialBootFailure: failure));
      debugPrint('[test] runApp SoupReaderApp done');
    } catch (e) {
      debugPrint('[test] SoupReaderApp threw: $e');
      runApp(_TestApp(status: 'SoupReaderApp 崩溃：$e'));
    }
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
