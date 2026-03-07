import 'package:flutter/cupertino.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../../app/theme/cupertino_theme.dart';

/// 提供统一的启动阶段应用壳，避免重复配置 `CupertinoApp`。
class BootAppShell extends StatelessWidget {
  /// 当前壳层的唯一键，用于区分启动页与主界面。
  final String shellKey;

  /// 壳层使用的主题亮度。
  final Brightness brightness;

  /// 壳层内实际展示的页面内容。
  final Widget home;

  /// 使用统一主题和本地化配置包裹当前启动页面。
  const BootAppShell({
    super.key,
    required this.shellKey,
    required this.brightness,
    required this.home,
  });

  @override
  Widget build(BuildContext context) {
    return CupertinoApp(
      key: ValueKey<String>(shellKey),
      title: 'SoupReader',
      debugShowCheckedModeBanner: false,
      theme: AppCupertinoTheme.build(brightness),
      builder: (context, child) => child ?? const SizedBox.shrink(),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('zh', 'CN'),
        Locale('en', 'US'),
      ],
      home: home,
    );
  }
}
