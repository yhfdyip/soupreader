import 'package:flutter/cupertino.dart';

import 'theme/cupertino_theme.dart';
import '../core/config/migration_exclusions.dart';
import '../core/models/app_settings.dart';
import '../features/bookshelf/views/bookshelf_view.dart';
import '../features/discovery/views/discovery_view.dart';
import '../features/rss/views/rss_subscription_view.dart';
import '../features/settings/views/settings_view.dart';

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
    final initialIndex = _resolveInitialTabIndex(
      _tabs,
      widget.appSettings.defaultHomePage,
    );
    _tabController = CupertinoTabController(initialIndex: initialIndex);
    debugPrint(
      '[main-tab] init tabs=${_tabIdsSummary(_tabs)} '
      'defaultHome=${widget.appSettings.defaultHomePage.name} '
      'initialIndex=$initialIndex',
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

    final oldTabs = _tabIdsSummary(_tabs);
    final newTabs = _tabIdsSummary(nextTabs);
    final currentIndex = _tabController.index.clamp(0, _tabs.length - 1);
    final currentTabId = _tabs[currentIndex].id;
    final carryIndex = _indexOfTab(nextTabs, currentTabId);
    final nextIndex = carryIndex >= 0
        ? carryIndex
        : _resolveInitialTabIndex(nextTabs, widget.appSettings.defaultHomePage);
    debugPrint(
      '[main-tab] tabs changed old=$oldTabs new=$newTabs '
      'currentIndex=${_tabController.index} carryIndex=$carryIndex '
      'nextIndex=$nextIndex',
    );
    _tabs = nextTabs;
    if (_tabController.index != nextIndex) {
      _tabController.index = nextIndex;
    }
  }

  void _onTabTap(int index) {
    if (index < 0 || index >= _tabs.length) {
      debugPrint(
        '[main-tab] ignore tap: invalid index=$index tabCount=${_tabs.length}',
      );
      return;
    }
    if (index != _tabController.index) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    switch (_tabs[index].id) {
      case _MainTabId.bookshelf:
        if (_shouldTriggerLegacyReselect(_bookshelfReselectedAt, now)) {
          _bookshelfReselectSignal.value++;
          debugPrint(
            '[main-tab] reselection triggered: bookshelf -> gotoTop '
            'signal=${_bookshelfReselectSignal.value}',
          );
        } else {
          _bookshelfReselectedAt = now;
        }
        return;
      case _MainTabId.discovery:
        if (_shouldTriggerLegacyReselect(_discoveryReselectedAt, now)) {
          _discoveryCompressSignal.value++;
          debugPrint(
            '[main-tab] reselection triggered: discovery -> compress '
            'signal=${_discoveryCompressSignal.value}',
          );
        } else {
          _discoveryReselectedAt = now;
        }
        return;
      case _MainTabId.rss:
      case _MainTabId.my:
        // 对齐 legado：仅书架/发现支持重按动作，RSS/我的重按不触发额外行为。
        return;
    }
  }

  bool _shouldTriggerLegacyReselect(int lastReselectedAt, int now) {
    // 与 legado MainActivity 同义：按 tab 独立计时，间隔 <= 300ms 即触发动作。
    return now - lastReselectedAt <= _legacyReselectWindow.inMilliseconds;
  }

  List<_MainTabSpec> _buildTabs(AppSettings settings) {
    // 迁移排除策略：RSS 在默认构建下必须隐藏入口，而不是展示不可用锚点。
    final showRssTab = !MigrationExclusions.excludeRss && settings.showRss;
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
      if (showRssTab)
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
    if (direct >= 0) return direct;
    // 迁移排除与显隐开关可能让默认主页不可见，此时回退到首个可见 Tab（书架）。
    debugPrint(
      '[main-tab] defaultHome=$homePage is hidden, fallback to index=0',
    );
    return 0;
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

  String _tabIdsSummary(List<_MainTabSpec> tabs) {
    return tabs.map((tab) => tab.id.name).join('>');
  }

  @override
  Widget build(BuildContext context) {
    final tabCount = _tabs.length;
    if (tabCount > 0) {
      final currentIndex = _tabController.index;
      if (currentIndex < 0 || currentIndex >= tabCount) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          final latestTabCount = _tabs.length;
          if (latestTabCount <= 0) return;
          final current = _tabController.index;
          final safeIndex = current.clamp(0, latestTabCount - 1);
          if (current == safeIndex) return;
          debugPrint(
            '[main-tab] clamp controller index $current -> $safeIndex '
            '(tabCount=$latestTabCount)',
          );
          _tabController.index = safeIndex;
        });
      }
    }

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
          key: ValueKey(tabId),
          builder: (context) {
            try {
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
            } catch (e, st) {
              debugPrint('[main-tab] tab $tabId build error: $e');
              debugPrintStack(stackTrace: st);
              return CupertinoPageScaffold(
                navigationBar: CupertinoNavigationBar(
                  middle: Text('${tabId.name} 异常'),
                ),
                child: SafeArea(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text(
                        '页面构建异常:\n$e',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
              );
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
