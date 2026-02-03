import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'core/database/database_service.dart';
import 'core/services/settings_service.dart';
import 'features/bookshelf/views/bookshelf_view.dart';
import 'features/source/views/source_list_view.dart';
import 'features/settings/views/settings_view.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 设置状态栏样式
  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);

  // 初始化数据库
  await DatabaseService().init();

  // 初始化全局设置
  await SettingsService().init();

  runApp(const SoupReaderApp());
}

/// SoupReader 阅读应用
class SoupReaderApp extends StatelessWidget {
  const SoupReaderApp({super.key});

  @override
  Widget build(BuildContext context) {
    // 使用纯 CupertinoApp，不指定自定义字体让系统自动使用 SF Pro
    return const CupertinoApp(
      title: 'SoupReader',
      debugShowCheckedModeBanner: false,
      // 使用系统默认深色主题，不过度自定义
      theme: CupertinoThemeData(
        brightness: Brightness.dark,
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
            label: '发现',
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
                return const ExploreView();
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

/// 发现页面
class ExploreView extends StatefulWidget {
  const ExploreView({super.key});

  @override
  State<ExploreView> createState() => _ExploreViewState();
}

class _ExploreViewState extends State<ExploreView> {
  final TextEditingController _searchController = TextEditingController();
  final List<String> _hotKeywords = [
    '斗破苍穹',
    '完美世界',
    '遮天',
    '凡人修仙传',
    '诛仙',
    '盗墓笔记',
    '鬼吹灯',
    '三体',
  ];

  bool _isSearching = false;
  List<Map<String, String>> _searchResults = [];

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      // 使用大标题导航栏 - iOS 原生风格
      navigationBar: const CupertinoNavigationBar(
        middle: Text('发现'),
      ),
      child: SafeArea(
        child: CustomScrollView(
          slivers: [
            // 搜索框
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: CupertinoSearchTextField(
                  controller: _searchController,
                  placeholder: '搜索书籍、作者',
                  onSubmitted: _onSearch,
                  onSuffixTap: () {
                    _searchController.clear();
                    setState(() => _isSearching = false);
                  },
                ),
              ),
            ),

            if (_isSearching)
              ..._buildSearchResultsSliver()
            else
              ..._buildExploreContentSliver(),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildExploreContentSliver() {
    return [
      // 热门搜索标题
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Text(
            '热门搜索',
            style: CupertinoTheme.of(context).textTheme.navTitleTextStyle,
          ),
        ),
      ),
      // 热门搜索标签
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _hotKeywords.map((keyword) {
              return CupertinoButton(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                color: CupertinoColors.systemGrey5.darkColor,
                borderRadius: BorderRadius.circular(18),

                onPressed: () {
                  _searchController.text = keyword;
                  _onSearch(keyword);
                },
                child: Text(
                  keyword,
                  style: const TextStyle(
                    color: CupertinoColors.white,
                    fontSize: 14,
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),

      // 分类标题
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 32, 16, 12),
          child: Text(
            '分类',
            style: CupertinoTheme.of(context).textTheme.navTitleTextStyle,
          ),
        ),
      ),
      // 分类网格
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        sliver: SliverGrid.count(
          crossAxisCount: 4,
          mainAxisSpacing: 20,
          crossAxisSpacing: 16,
          children: [
            _buildCategoryItem(
                CupertinoIcons.flame_fill, '玄幻', CupertinoColors.systemOrange),
            _buildCategoryItem(
                CupertinoIcons.heart_fill, '言情', CupertinoColors.systemPink),
            _buildCategoryItem(
                CupertinoIcons.book_fill, '历史', CupertinoColors.systemBrown),
            _buildCategoryItem(
                CupertinoIcons.rocket_fill, '科幻', CupertinoColors.systemIndigo),
            _buildCategoryItem(CupertinoIcons.sportscourt_fill, '武侠',
                CupertinoColors.systemRed),
            _buildCategoryItem(CupertinoIcons.building_2_fill, '都市',
                CupertinoColors.systemTeal),
            _buildCategoryItem(
                CupertinoIcons.moon_fill, '灵异', CupertinoColors.systemPurple),
            _buildCategoryItem(
                CupertinoIcons.ellipsis, '更多', CupertinoColors.systemGrey),
          ],
        ),
      ),
    ];
  }

  Widget _buildCategoryItem(IconData icon, String label, Color color) {
    return GestureDetector(
      onTap: () {
        _searchController.text = label;
        _onSearch(label);
      },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color: CupertinoColors.secondaryLabel.resolveFrom(context),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildSearchResultsSliver() {
    if (_searchResults.isEmpty) {
      return [
        const SliverFillRemaining(
          child: Center(
            child: CupertinoActivityIndicator(),
          ),
        ),
      ];
    }

    return [
      SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final book = _searchResults[index];
            return CupertinoListTile(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              leadingSize: 50,
              leading: Container(
                width: 50,
                height: 70,
                decoration: BoxDecoration(
                  color: CupertinoColors.systemGrey5.darkColor,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(
                  CupertinoIcons.book_fill,
                  color: CupertinoColors.systemGrey,
                ),
              ),
              title: Text(book['title'] ?? ''),
              subtitle: Text(book['author'] ?? ''),
              trailing: CupertinoButton(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),

                child: const Text('加入'),
                onPressed: () {},
              ),
            );
          },
          childCount: _searchResults.length,
        ),
      ),
    ];
  }

  void _onSearch(String query) {
    if (query.isEmpty) return;

    setState(() {
      _isSearching = true;
      _searchResults = [];
    });

    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        setState(() {
          _searchResults = [
            {'title': '$query - 第一部', 'author': '作者A'},
            {'title': '$query - 第二部', 'author': '作者B'},
            {'title': '$query 外传', 'author': '作者C'},
          ];
        });
      }
    });
  }
}
