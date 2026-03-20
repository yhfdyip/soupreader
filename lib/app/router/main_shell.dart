import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../theme/cupertino_theme.dart';

/// 主界面 Tab 壳，使用 CupertinoTabBar 替代 Material BottomNavigationBar。
///
/// 接管原 [MainScreen] 的 Tab 导航职责：
/// - 通过 [StatefulNavigationShell] 管理 Tab 状态
/// - 保留 CupertinoTabBar 的 iOS 原生风格
/// - 保留双击 Tab 重选逻辑（书架回顶部、发现压缩）
class MainShell extends StatefulWidget {
  /// go_router 的有状态导航壳。
  final StatefulNavigationShell navigationShell;

  const MainShell({super.key, required this.navigationShell});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  static const Duration _reselectWindow = Duration(milliseconds: 300);

  int _lastTappedIndex = -1;
  int _lastTappedAtMs = 0;

  void _onTabTap(int index) {
    final isReselect = index == widget.navigationShell.currentIndex;
    if (isReselect) {
      HapticFeedback.selectionClick();
      final now = DateTime.now().millisecondsSinceEpoch;
      if (now - _lastTappedAtMs <= _reselectWindow.inMilliseconds &&
          _lastTappedIndex == index) {
        // 双击重选逻辑（未来可扩展为 Riverpod Provider 信号）
        debugPrint('[main-shell] reselect tab=$index');
      }
      _lastTappedAtMs = now;
      _lastTappedIndex = index;
    } else {
      HapticFeedback.lightImpact();
      widget.navigationShell.goBranch(
        index,
        initialLocation: index == widget.navigationShell.currentIndex,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final brightness = CupertinoTheme.of(context).brightness ??
        MediaQuery.platformBrightnessOf(context);

    return CupertinoPageScaffold(
      child: Column(
        children: <Widget>[
          Expanded(child: widget.navigationShell),
          CupertinoTabBar(
            backgroundColor:
                AppCupertinoTheme.tabBarBackground(brightness),
            activeColor: AppCupertinoTheme.tabBarActive(brightness),
            inactiveColor:
                AppCupertinoTheme.tabBarInactive(brightness),
            border: AppCupertinoTheme.tabBarBorder(brightness),
            currentIndex: widget.navigationShell.currentIndex,
            onTap: _onTabTap,
            items: const <BottomNavigationBarItem>[
              BottomNavigationBarItem(
                icon: Icon(CupertinoIcons.book),
                activeIcon: Icon(CupertinoIcons.book_fill),
                label: '书架',
              ),
              BottomNavigationBarItem(
                icon: Icon(CupertinoIcons.compass),
                activeIcon: Icon(CupertinoIcons.compass_fill),
                label: '发现',
              ),
              BottomNavigationBarItem(
                icon: Icon(
                  CupertinoIcons.dot_radiowaves_left_right,
                ),
                activeIcon: Icon(
                  CupertinoIcons.dot_radiowaves_right,
                ),
                label: '订阅',
              ),
              BottomNavigationBarItem(
                icon: Icon(CupertinoIcons.person),
                activeIcon: Icon(CupertinoIcons.person_fill),
                label: '我的',
              ),
            ],
          ),
        ],
      ),
    );
  }
}
