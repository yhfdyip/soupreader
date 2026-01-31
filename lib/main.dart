import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'features/bookshelf/views/bookshelf_view.dart';
import 'features/source/views/source_list_view.dart';
import 'features/settings/views/settings_view.dart';
import 'app/theme/colors.dart';

void main() {
  runApp(const SoupReaderApp());
}

/// SoupReader 阅读应用
class SoupReaderApp extends StatelessWidget {
  const SoupReaderApp({super.key});

  @override
  Widget build(BuildContext context) {
    // 使用 CupertinoApp 获得完整的 iOS 体验
    return CupertinoApp(
      title: 'SoupReader',
      debugShowCheckedModeBanner: false,
      theme: const CupertinoThemeData(
        brightness: Brightness.dark,
        primaryColor: AppColors.accent,
        scaffoldBackgroundColor: CupertinoColors.black,
        barBackgroundColor: Color(0xE6121212), // 半透明深色
        textTheme: CupertinoTextThemeData(
          primaryColor: AppColors.accent,
          textStyle: TextStyle(
            fontFamily: '.SF Pro Text',
            color: CupertinoColors.white,
          ),
          navTitleTextStyle: TextStyle(
            fontFamily: '.SF Pro Text',
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: CupertinoColors.white,
          ),
          navLargeTitleTextStyle: TextStyle(
            fontFamily: '.SF Pro Display',
            fontSize: 34,
            fontWeight: FontWeight.w700,
            color: CupertinoColors.white,
          ),
        ),
      ),
      home: const MainScreen(),
    );
  }
}

/// 主屏幕（带底部导航）
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  @override
  Widget build(BuildContext context) {
    return CupertinoTabScaffold(
      tabBar: CupertinoTabBar(
        backgroundColor: const Color(0xE6121212), // 半透明深色
        activeColor: AppColors.accent,
        inactiveColor: CupertinoColors.systemGrey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.book),
            activeIcon: Icon(CupertinoIcons.book_fill),
            label: '书架',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.search),
            activeIcon: Icon(CupertinoIcons.search),
            label: '发现',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.cloud),
            activeIcon: Icon(CupertinoIcons.cloud_fill),
            label: '书源',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.settings),
            activeIcon: Icon(CupertinoIcons.settings_solid),
            label: '设置',
          ),
        ],
      ),
      tabBuilder: (context, index) {
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
  }
}

/// 发现/探索页面（搜索书籍）
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
      navigationBar: CupertinoNavigationBar(
        middle: CupertinoSearchTextField(
          controller: _searchController,
          placeholder: '搜索书籍、作者',
          onSubmitted: _onSearch,
          onChanged: (value) {
            if (value.isEmpty && _isSearching) {
              setState(() {
                _isSearching = false;
              });
            }
          },
          onSuffixTap: () {
            _searchController.clear();
            setState(() {
              _isSearching = false;
            });
          },
        ),
        backgroundColor: const Color(0xE6121212),
        border: null,
      ),
      backgroundColor: CupertinoColors.black,
      child: SafeArea(
        child: _isSearching ? _buildSearchResults() : _buildExploreContent(),
      ),
    );
  }

  Widget _buildExploreContent() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 热门搜索
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            '热门搜索',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: CupertinoColors.white,
            ),
          ),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _hotKeywords.map((keyword) {
            return CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: AppColors.accent.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
              minSize: 0,
              onPressed: () {
                _searchController.text = keyword;
                _onSearch(keyword);
              },
              child: Text(
                keyword,
                style: const TextStyle(
                  color: AppColors.accent,
                  fontSize: 14,
                ),
              ),
            );
          }).toList(),
        ),

        const SizedBox(height: 32),

        // 分类推荐
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            '分类',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: CupertinoColors.white,
            ),
          ),
        ),
        GridView.count(
          crossAxisCount: 4,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          children: [
            _buildCategoryItem(CupertinoIcons.flame, '玄幻'),
            _buildCategoryItem(CupertinoIcons.heart, '言情'),
            _buildCategoryItem(CupertinoIcons.book, '历史'),
            _buildCategoryItem(CupertinoIcons.rocket, '科幻'),
            _buildCategoryItem(CupertinoIcons.sportscourt, '武侠'),
            _buildCategoryItem(CupertinoIcons.building_2_fill, '都市'),
            _buildCategoryItem(CupertinoIcons.moon_stars, '灵异'),
            _buildCategoryItem(CupertinoIcons.ellipsis, '更多'),
          ],
        ),
      ],
    );
  }

  Widget _buildCategoryItem(IconData icon, String label) {
    return GestureDetector(
      onTap: () {
        _searchController.text = label;
        _onSearch(label);
      },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: AppColors.accent.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.accent, size: 24),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color: CupertinoColors.systemGrey,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults() {
    if (_searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CupertinoActivityIndicator(radius: 14),
            const SizedBox(height: 16),
            Text(
              '正在搜索...',
              style: TextStyle(color: CupertinoColors.systemGrey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final book = _searchResults[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF1C1C1E),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 70,
                decoration: BoxDecoration(
                  color: AppColors.accent.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(CupertinoIcons.book_fill,
                    color: AppColors.accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      book['title'] ?? '',
                      style: const TextStyle(
                        color: CupertinoColors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      book['author'] ?? '',
                      style: TextStyle(
                        color: CupertinoColors.systemGrey,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              CupertinoButton(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: AppColors.accent,
                borderRadius: BorderRadius.circular(20),
                minSize: 0,
                onPressed: () {
                  // TODO: 添加到书架
                },
                child: const Text(
                  '加入',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _onSearch(String query) {
    if (query.isEmpty) return;

    setState(() {
      _isSearching = true;
      _searchResults = [];
    });

    // 模拟搜索延迟
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
