import 'dart:async';
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'app/theme/cupertino_theme.dart';
import 'app/theme/shadcn_theme.dart';
import 'core/database/database_service.dart';
import 'core/database/repositories/book_repository.dart';
import 'core/database/repositories/rss_article_repository.dart';
import 'core/database/repositories/rss_source_repository.dart';
import 'core/database/repositories/replace_rule_repository.dart';
import 'core/database/repositories/source_repository.dart';
import 'core/models/app_settings.dart';
import 'core/services/cookie_store.dart';
import 'core/services/exception_log_service.dart';
import 'core/services/settings_service.dart';
import 'features/bookshelf/views/bookshelf_view.dart';
import 'features/discovery/views/discovery_view.dart';
import 'features/rss/views/rss_subscription_view.dart';
import 'features/settings/views/settings_view.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

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
    final bootFailure = await _bootstrapApp();

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

Future<BootFailure?> _bootstrapApp() async {
  try {
    await _runBootStep('DatabaseService.init', () async {
      await DatabaseService().init();
    });
    await _runBootStep('ExceptionLogService.bootstrap', () async {
      await ExceptionLogService().bootstrap();
    });
    await _runBootStep('SourceRepository.bootstrap', () async {
      await SourceRepository.bootstrap(DatabaseService());
    });
    await _runBootStep('RssSourceRepository.bootstrap', () async {
      await RssSourceRepository.bootstrap(DatabaseService());
    });
    await _runBootStep('RssArticleRepository.bootstrap', () async {
      await RssArticleRepository.bootstrap(DatabaseService());
    });
    await _runBootStep('RssReadRecordRepository.bootstrap', () async {
      await RssReadRecordRepository.bootstrap(DatabaseService());
    });
    await _runBootStep('BookRepository.bootstrap', () async {
      await BookRepository.bootstrap(DatabaseService());
    });
    await _runBootStep('ChapterRepository.bootstrap', () async {
      await ChapterRepository.bootstrap(DatabaseService());
    });
    await _runBootStep('ReplaceRuleRepository.bootstrap', () async {
      await ReplaceRuleRepository.bootstrap(DatabaseService());
    });
    await _runBootStep('SettingsService.init', () async {
      await SettingsService().init();
    });
    await _runBootStep('CookieStore.setup', () async {
      await CookieStore.setup();
    });
    return null;
  } on _BootStepException catch (e) {
    return BootFailure(
      stepName: e.stepName,
      error: e.error,
      stack: e.stack,
    );
  } catch (e, st) {
    return BootFailure(
      stepName: 'unknown',
      error: e,
      stack: st,
    );
  }
}

Future<void> _runBootStep(
  String name,
  Future<void> Function() action,
) async {
  debugPrint('[boot] $name start');
  try {
    await action();
    debugPrint('[boot] $name ok');
  } catch (e, st) {
    debugPrint('[boot] $name failed: $e');
    debugPrintStack(stackTrace: st);
    ExceptionLogService().record(
      node: 'bootstrap.$name',
      message: '启动步骤失败',
      error: e,
      stackTrace: st,
    );
    throw _BootStepException(
      stepName: name,
      error: e,
      stack: st,
    );
  }
}

class _BootStepException implements Exception {
  final String stepName;
  final Object error;
  final StackTrace stack;

  const _BootStepException({
    required this.stepName,
    required this.error,
    required this.stack,
  });

  @override
  String toString() => 'BootStepException($stepName): $error';
}

class BootFailure {
  final String stepName;
  final Object error;
  final StackTrace stack;

  const BootFailure({
    required this.stepName,
    required this.error,
    required this.stack,
  });
}

/// SoupReader 阅读应用
class SoupReaderApp extends StatefulWidget {
  final BootFailure? initialBootFailure;

  const SoupReaderApp({
    super.key,
    this.initialBootFailure,
  });

  @override
  State<SoupReaderApp> createState() => _SoupReaderAppState();
}

class _SoupReaderAppState extends State<SoupReaderApp>
    with WidgetsBindingObserver {
  final SettingsService _settingsService = SettingsService();
  late Brightness _platformBrightness;
  BootFailure? _bootFailure;
  bool _bootRetrying = false;
  bool _settingsReady = false;

  @override
  void initState() {
    super.initState();
    _bootFailure = widget.initialBootFailure;
    WidgetsBinding.instance.addObserver(this);
    _platformBrightness =
        WidgetsBinding.instance.platformDispatcher.platformBrightness;
    _settingsReady = _bootFailure == null;
    if (_settingsReady) {
      _settingsService.appSettingsListenable.addListener(_onAppSettingsChanged);
    }
    _applySystemUiOverlayStyle();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (_settingsReady) {
      _settingsService.appSettingsListenable
          .removeListener(_onAppSettingsChanged);
    }
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

  Future<void> _retryBoot() async {
    if (_bootRetrying) return;
    setState(() => _bootRetrying = true);
    final failure = await _bootstrapApp();
    if (!mounted) return;
    final retrySuccess = failure == null;
    if (retrySuccess && !_settingsReady) {
      _settingsReady = true;
      _settingsService.appSettingsListenable.addListener(_onAppSettingsChanged);
    }
    setState(() {
      _bootFailure = failure;
      _bootRetrying = false;
    });
    _applySystemUiOverlayStyle();
  }

  Brightness get _effectiveBrightness {
    if (!_settingsReady) {
      return _platformBrightness;
    }
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
    final brightness = _effectiveBrightness;
    final shadTheme = brightness == Brightness.dark
        ? AppShadcnTheme.dark()
        : AppShadcnTheme.light();

    return ShadApp.custom(
      // 直接根据设置计算后的亮度提供主题，避免依赖 Material ThemeMode。
      theme: shadTheme,
      darkTheme: shadTheme,
      appBuilder: (context) {
        final shad = ShadTheme.of(context);
        final cupertinoTheme = CupertinoTheme.of(context).copyWith(
          barBackgroundColor:
              shad.colorScheme.background.withValues(alpha: 0.92),
        );

        return CupertinoApp(
          title: 'SoupReader',
          debugShowCheckedModeBanner: false,
          theme: cupertinoTheme,
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          supportedLocales: const [
            Locale('zh', 'CN'),
            Locale('en', 'US'),
          ],
          home: _bootFailure == null
              ? MainScreen(
                  brightness: brightness,
                  appSettings: _settingsReady
                      ? _settingsService.appSettings
                      : const AppSettings(),
                )
              : _BootFailureView(
                  failure: _bootFailure!,
                  retrying: _bootRetrying,
                  onRetry: _retryBoot,
                ),
          builder: (context, child) => ShadAppBuilder(child: child!),
        );
      },
    );
  }
}

/// 主屏幕（带底部导航）
class MainScreen extends StatefulWidget {
  final Brightness brightness;
  final AppSettings appSettings;

  const MainScreen({
    super.key,
    required this.brightness,
    required this.appSettings,
  });

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  static const Duration _legacyReselectWindow = Duration(milliseconds: 300);
  late final CupertinoTabController _tabController;
  final ValueNotifier<int> _bookshelfReselectSignal = ValueNotifier<int>(0);
  final ValueNotifier<int> _discoveryCompressSignal = ValueNotifier<int>(0);
  int _bookshelfReselectedAt = 0;
  int _discoveryReselectedAt = 0;
  late List<_MainTabSpec> _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = _buildTabs(widget.appSettings);
    _tabController = CupertinoTabController(
      initialIndex: _resolveInitialTabIndex(
        _tabs,
        widget.appSettings.defaultHomePage,
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _bookshelfReselectSignal.dispose();
    _discoveryCompressSignal.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant MainScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextTabs = _buildTabs(widget.appSettings);
    if (_sameTabIds(_tabs, nextTabs)) return;

    final currentIndex = _tabController.index.clamp(0, _tabs.length - 1);
    final currentTabId = _tabs[currentIndex].id;
    final carryIndex = _indexOfTab(nextTabs, currentTabId);
    final nextIndex = carryIndex >= 0
        ? carryIndex
        : _resolveInitialTabIndex(nextTabs, widget.appSettings.defaultHomePage);
    _tabs = nextTabs;
    if (_tabController.index != nextIndex) {
      _tabController.index = nextIndex;
    }
  }

  void _onTabTap(int index) {
    if (index < 0 || index >= _tabs.length) return;
    final tab = _tabs[index];
    if (index != _tabController.index) return;
    switch (tab.id) {
      case _MainTabId.bookshelf:
        final now = DateTime.now().millisecondsSinceEpoch;
        if (now - _bookshelfReselectedAt >
            _legacyReselectWindow.inMilliseconds) {
          _bookshelfReselectedAt = now;
        } else {
          _bookshelfReselectSignal.value++;
        }
        return;
      case _MainTabId.discovery:
        final now = DateTime.now().millisecondsSinceEpoch;
        if (now - _discoveryReselectedAt >
            _legacyReselectWindow.inMilliseconds) {
          _discoveryReselectedAt = now;
        } else {
          _discoveryCompressSignal.value++;
        }
        return;
      case _MainTabId.rss:
      case _MainTabId.my:
        return;
    }
  }

  List<_MainTabSpec> _buildTabs(AppSettings settings) {
    return [
      const _MainTabSpec(
        id: _MainTabId.bookshelf,
        item: BottomNavigationBarItem(
          icon: Icon(CupertinoIcons.book),
          activeIcon: Icon(CupertinoIcons.book_fill),
          label: '书架',
        ),
      ),
      if (settings.showDiscovery)
        const _MainTabSpec(
          id: _MainTabId.discovery,
          item: BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.compass),
            activeIcon: Icon(CupertinoIcons.compass_fill),
            label: '发现',
          ),
        ),
      if (settings.showRss)
        const _MainTabSpec(
          id: _MainTabId.rss,
          item: BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.dot_radiowaves_left_right),
            activeIcon: Icon(CupertinoIcons.dot_radiowaves_right),
            label: '订阅',
          ),
        ),
      const _MainTabSpec(
        id: _MainTabId.my,
        item: BottomNavigationBarItem(
          icon: Icon(CupertinoIcons.person),
          activeIcon: Icon(CupertinoIcons.person_fill),
          label: '我的',
        ),
      ),
    ];
  }

  int _resolveInitialTabIndex(
    List<_MainTabSpec> tabs,
    MainDefaultHomePage homePage,
  ) {
    final target = switch (homePage) {
      MainDefaultHomePage.bookshelf => _MainTabId.bookshelf,
      MainDefaultHomePage.explore => _MainTabId.discovery,
      MainDefaultHomePage.rss => _MainTabId.rss,
      MainDefaultHomePage.my => _MainTabId.my,
    };
    final direct = _indexOfTab(tabs, target);
    return direct >= 0 ? direct : 0;
  }

  int _indexOfTab(List<_MainTabSpec> tabs, _MainTabId id) {
    for (var i = 0; i < tabs.length; i++) {
      if (tabs[i].id == id) return i;
    }
    return -1;
  }

  bool _sameTabIds(List<_MainTabSpec> a, List<_MainTabSpec> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id) return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoTabScaffold(
      controller: _tabController,
      tabBar: CupertinoTabBar(
        backgroundColor: AppCupertinoTheme.tabBarBackground(widget.brightness),
        activeColor: AppCupertinoTheme.tabBarActive(widget.brightness),
        inactiveColor: AppCupertinoTheme.tabBarInactive(widget.brightness),
        border: AppCupertinoTheme.tabBarBorder(widget.brightness),
        onTap: _onTabTap,
        items: _tabs.map((tab) => tab.item).toList(growable: false),
      ),
      tabBuilder: (context, index) {
        final tabId = _tabs[index].id;
        return CupertinoTabView(
          defaultTitle: 'SoupReader',
          builder: (context) {
            switch (tabId) {
              case _MainTabId.bookshelf:
                return BookshelfView(
                  reselectSignal: _bookshelfReselectSignal,
                );
              case _MainTabId.discovery:
                return DiscoveryView(
                  compressSignal: _discoveryCompressSignal,
                );
              case _MainTabId.rss:
                return const RssSubscriptionView();
              case _MainTabId.my:
                return const SettingsView();
            }
          },
        );
      },
    );
  }
}

enum _MainTabId {
  bookshelf,
  discovery,
  rss,
  my,
}

class _MainTabSpec {
  const _MainTabSpec({
    required this.id,
    required this.item,
  });

  final _MainTabId id;
  final BottomNavigationBarItem item;
}

class _BootFailureView extends StatelessWidget {
  final BootFailure failure;
  final bool retrying;
  final VoidCallback onRetry;

  const _BootFailureView({
    required this.failure,
    required this.retrying,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('启动异常'),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
          children: [
            const Text(
              '应用初始化失败，已阻止进入主界面以避免后续导入/书源管理出现连锁异常。',
              style: TextStyle(fontSize: 15),
            ),
            const SizedBox(height: 14),
            Text(
              '失败步骤：${failure.stepName}\n错误：${failure.error}',
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 20),
            CupertinoButton.filled(
              onPressed: retrying ? null : onRetry,
              child: Text(retrying ? '重试中…' : '重试初始化'),
            ),
          ],
        ),
      ),
    );
  }
}
