import 'package:flutter/cupertino.dart';

import 'app/bootstrap/app_bootstrap.dart';
import 'app/bootstrap/boot_host_app.dart';
import 'app/bootstrap/global_error_handlers.dart';
import 'core/services/exception_log_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final exceptionLogService = ExceptionLogService();

  // ── 全局错误处理 ──
  // 不设置 ErrorWidget.builder。
  // 1. CupertinoPageScaffold 等依赖 CupertinoTheme 的组件在缺少 theme 时自身 crash → 递归白屏。
  // 2. 任何 box widget 类型的 ErrorWidget 在 Sliver 上下文中会导致
  //    'RenderBox is not a subtype of RenderSliver' 二次崩溃。
  // 默认 ErrorWidget 在 Release 模式下为灰色方块，虽不美观但不会引发级联崩溃。

  installGlobalErrorHandlers(exceptionLogService: exceptionLogService);
  runGuardedApp(
    () => runApp(
      BootHostApp(
        bootDependencies: BootDependencies.defaults(
          exceptionLogService: exceptionLogService,
        ),
      ),
    ),
    exceptionLogService: exceptionLogService,
  );
}
