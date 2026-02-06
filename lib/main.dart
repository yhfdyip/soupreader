import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'core/database/database_service.dart';
import 'core/models/app_settings.dart';
import 'core/services/settings_service.dart';
import 'features/bookshelf/views/bookshelf_view.dart';
import 'features/search/views/search_view.dart';
import 'features/source/views/source_list_view.dart';
import 'features/settings/views/settings_view.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化数据库
  await DatabaseService().init();

  // 初始化全局设置
  await SettingsService().init();

  runApp(const SoupReaderApp());
}

/// SoupReader 阅读应用
class SoupReaderApp extends StatefulWidget {
  const SoupReaderApp({super.key});

  @override
  State<SoupReaderApp> createState() => _SoupReaderAppState();
}

class _SoupReaderAppState extends State<SoupReaderApp>
    with WidgetsBindingObserver {
  final SettingsService _settingsService = SettingsService();
  late Brightness _platformBrightness;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _platformBrightness =
        WidgetsBinding.instance.platformDispatcher.platformBrightness;
    _settingsService.appSettingsListenable.addListener(_onAppSettingsChanged);
    _applySystemUiOverlayStyle();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _settingsService.appSettingsListenable.removeListener(_onAppSettingsChanged);
    super.dispose();
  }

  @override
  void didChangePlatformBrightness() {
    setState(() {
      _platformBrightness =
          WidgetsBinding.instance.platformDispatcher.platformBrightness;
    });
    _applySystemUiOverlayStyle();
  }

  void _onAppSettingsChanged() {
    setState(() {});
    _applySystemUiOverlayStyle();
  }

  Brightness get _effectiveBrightness {
    final settings = _settingsService.appSettings;
    switch (settings.appearanceMode) {
      case AppAppearanceMode.followSystem:
        return _platformBrightness;
      case AppAppearanceMode.light:
        return Brightness.light;
      case AppAppearanceMode.dark:
        return Brightness.dark;
    }
  }

  void _applySystemUiOverlayStyle() {
    final brightness = _effectiveBrightness;
    SystemChrome.setSystemUIOverlayStyle(
      brightness == Brightness.dark
          ? SystemUiOverlayStyle.light
          : SystemUiOverlayStyle.dark,
    );
  }

  @override
  Widget build(BuildContext context) {
    // 使用纯 CupertinoApp，不指定自定义字体让系统自动使用 SF Pro
    return CupertinoApp(
      title: 'SoupReader',
      debugShowCheckedModeBanner: false,
      // 使用系统默认深色主题，不过度自定义
      theme: CupertinoThemeData(
        brightness: _effectiveBrightness,
        // 使用系统蓝色作为主色调（iOS 标准）
        primaryColor: CupertinoColors.systemBlue,
      ),
      home: MainScreen(),
    );
  }
}

/// 主屏幕（带底部导航）
class MainScreen extends StatelessWidget {
  const MainScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoTabScaffold(
      tabBar: CupertinoTabBar(
        // 使用系统默认样式，不自定义背景色
        items: const [
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.book),
            activeIcon: Icon(CupertinoIcons.book_fill),
            label: '书架',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.search),
            label: '搜索',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.cloud),
            activeIcon: Icon(CupertinoIcons.cloud_fill),
            label: '书源',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.gear),
            activeIcon: Icon(CupertinoIcons.gear_solid),
            label: '设置',
          ),
        ],
      ),
      tabBuilder: (context, index) {
        return CupertinoTabView(
          builder: (context) {
            switch (index) {
              case 0:
                return const BookshelfView();
              case 1:
                return const SearchView();
              case 2:
                return const SourceListView();
              case 3:
                return const SettingsView();
              default:
                return const BookshelfView();
            }
          },
        );
      },
    );
  }
}
