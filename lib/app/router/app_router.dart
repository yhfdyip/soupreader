import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../features/bookshelf/views/bookshelf_view.dart';
import '../../features/discovery/views/discovery_view.dart';
import '../../features/rss/views/rss_subscription_view.dart';
import '../../features/settings/views/settings_view.dart';
import 'main_shell.dart';

part 'app_router.g.dart';

/// 应用全局路由配置。
///
/// 使用 [StatefulShellRoute.indexedStack] 实现 Tab 导航，
/// 每个 Tab 独立维护 Navigator 栈。
@Riverpod(keepAlive: true)
GoRouter appRouter(Ref ref) {
  return GoRouter(
    initialLocation: '/bookshelf',
    routes: <RouteBase>[
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return MainShell(navigationShell: navigationShell);
        },
        branches: <StatefulShellBranch>[
          // ── 书架 ──
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: '/bookshelf',
                pageBuilder: (context, state) => const NoTransitionPage(
                  child: BookshelfView(),
                ),
              ),
            ],
          ),
          // ── 发现 ──
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: '/discovery',
                pageBuilder: (context, state) => NoTransitionPage(
                  child: DiscoveryView(),
                ),
              ),
            ],
          ),
          // ── 订阅 ──
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: '/rss',
                pageBuilder: (context, state) => const NoTransitionPage(
                  child: RssSubscriptionView(),
                ),
              ),
            ],
          ),
          // ── 我的 ──
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: '/settings',
                pageBuilder: (context, state) => const NoTransitionPage(
                  child: SettingsView(),
                ),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}
