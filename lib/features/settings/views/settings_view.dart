import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../../shared/widgets/adaptive_widgets.dart';

/// 设置页面
class SettingsView extends StatefulWidget {
  const SettingsView({super.key});

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  // 设置状态
  bool _darkMode = true;
  bool _autoUpdate = true;
  bool _wifiOnly = true;
  String _cacheSize = '256 MB';
  String _version = '';

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() {
        _version = '${info.version} (${info.buildNumber})';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // iOS 设置页面通常使用分组背景色
    final isIOS = Theme.of(context).platform == TargetPlatform.iOS;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isIOS
        ? (isDark ? Colors.black : const Color(0xFFF2F2F7))
        : null; // Android 使用默认主题色

    return Scaffold(
      backgroundColor: backgroundColor,
      body: CustomScrollView(
        slivers: [
          // 大标题导航栏
          SliverAppBar.large(
            title: const Text('设置'),
            centerTitle: !isIOS, // iOS 大标题居左，Android居中(如果设置了)
            // iOS 风格背景配置
            backgroundColor: backgroundColor,
            elevation: 0,
            scrolledUnderElevation: 0,
            pinned: true,
          ),

          SliverToBoxAdapter(
            child: Column(
              children: [
                // 阅读设置
                AdaptiveSettingsGroup(
                  header: '阅读体验',
                  children: [
                    AdaptiveSettingsTile(
                      icon: Icons.text_fields,
                      iconBgColor: Colors.blue,
                      title: '阅读偏好',
                      subtitle: isIOS ? null : '字体、行距、背景等', // iOS 风格不需要副标题
                      onTap: _openReadingSettings,
                    ),
                    AdaptiveSettingsTile(
                      icon: Icons.brightness_6,
                      iconBgColor: Colors.purple,
                      title: '深色模式',
                      trailing: AdaptiveSwitch(
                        value: _darkMode,
                        onChanged: (value) {
                          setState(() {
                            _darkMode = value;
                          });
                          // 震动反馈
                          if (isIOS) HapticFeedback.selectionClick();
                        },
                      ),
                    ),
                  ],
                ),

                // 书源设置
                AdaptiveSettingsGroup(
                  header: '内容来源',
                  children: [
                    AdaptiveSettingsTile(
                      icon: Icons.source,
                      iconBgColor: Colors.orange,
                      title: '书源管理',
                      onTap: () {
                        // TODO: 跳转到书源管理
                      },
                    ),
                    AdaptiveSettingsTile(
                      icon: Icons.update,
                      iconBgColor: Colors.green,
                      title: '自动更新书源',
                      trailing: AdaptiveSwitch(
                        value: _autoUpdate,
                        onChanged: (value) {
                          setState(() {
                            _autoUpdate = value;
                          });
                          if (isIOS) HapticFeedback.selectionClick();
                        },
                      ),
                    ),
                  ],
                ),

                // 缓存设置
                AdaptiveSettingsGroup(
                  header: '数据与存储',
                  children: [
                    AdaptiveSettingsTile(
                      icon: Icons.wifi,
                      iconBgColor: Colors.blueAccent,
                      title: '仅WiFi下载',
                      trailing: AdaptiveSwitch(
                        value: _wifiOnly,
                        onChanged: (value) {
                          setState(() {
                            _wifiOnly = value;
                          });
                          if (isIOS) HapticFeedback.selectionClick();
                        },
                      ),
                    ),
                    AdaptiveSettingsTile(
                      icon: Icons.storage,
                      iconBgColor: Colors.teal,
                      title: '清理缓存',
                      trailing: isIOS
                          ? Text(_cacheSize,
                              style: const TextStyle(
                                  color: Colors.grey, fontSize: 15))
                          : null,
                      subtitle: isIOS ? null : '当前缓存：$_cacheSize',
                      onTap: _showCacheOptions,
                    ),
                    AdaptiveSettingsTile(
                      icon: Icons.download,
                      iconBgColor: Colors.indigo,
                      title: '下载目录',
                      subtitle: '/Documents/SoupReader',
                      onTap: () {},
                    ),
                  ],
                ),

                // 其他设置
                AdaptiveSettingsGroup(
                  header: '关于',
                  children: [
                    AdaptiveSettingsTile(
                      icon: Icons.system_update,
                      iconBgColor: Colors.redAccent,
                      title: '检查更新',
                      onTap: _checkUpdate,
                    ),
                    AdaptiveSettingsTile(
                      icon: Icons.backup,
                      iconBgColor: Colors.brown,
                      title: '备份与恢复',
                      onTap: _showBackupOptions,
                    ),
                    AdaptiveSettingsTile(
                      icon: Icons.info_outline,
                      iconBgColor: Colors.grey,
                      title: '关于应用',
                      trailing: Text('v$_version',
                          style: const TextStyle(
                              color: Colors.grey, fontSize: 15)),
                      onTap: _showAbout,
                    ),
                  ],
                  footer: 'SoupReader for iOS © 2026',
                ),

                // 底部留白，适应 TabBar
                const SizedBox(height: 100),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _openReadingSettings() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent, // 让内容决定背景
      builder: (context) => _buildReadingSettingsSheet(),
    );
  }

  Widget _buildReadingSettingsSheet() {
    // 简单实现，UI待优化
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.all(24),
            children: const [
              Text('阅读偏好设置 - 此处待用 Adaptive 组件重构'),
            ],
          ),
        );
      },
    );
  }

  void _showCacheOptions() {
    showPlatformDialog(
      context: context,
      title: '清除缓存',
      content: '确定要清除 $_cacheSize 缓存数据吗？此操作不会删除书架记录。',
      actions: [
        if (Platform.isIOS) ...[
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => _clearCache(),
            child: const Text('清除'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
        ] else ...[
          TextButton(
              onPressed: () => Navigator.pop(context), child: const Text('取消')),
          TextButton(
              onPressed: () => _clearCache(),
              child: const Text('清除', style: TextStyle(color: Colors.red))),
        ]
      ],
    );
  }

  void _clearCache() {
    Navigator.pop(context);
    setState(() {
      _cacheSize = '0 MB';
    });
    // 触发震动
    HapticFeedback.mediumImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('缓存已更除')),
    );
  }

  void _showBackupOptions() {
    // TODO: 实现备份选项
  }

  void _showAbout() {
    showPlatformDialog(
      context: context,
      title: 'SoupReader',
      content: '版本: $_version\n\n一款专注阅读体验的开源应用。',
    );
  }

  // 检查更新
  Future<void> _checkUpdate() async {
    // 省略加载提示，让体验更流畅，或者使用顶部 Toast

    try {
      final dio = Dio();
      final response = await dio.get(
        'https://api.github.com/repos/Inighty/soupreader/releases/latest',
      );

      if (response.statusCode == 200) {
        final data = response.data;
        final tagName = data['tag_name'];
        final body = data['body'];
        final assets = data['assets'] as List;

        String? downloadUrl;
        for (var asset in assets) {
          if (asset['name'].toString().endsWith('.ipa')) {
            downloadUrl = asset['browser_download_url'];
            break;
          }
        }

        if (!mounted) return;

        if (downloadUrl != null) {
          _showUpdateDialog(tagName, body ?? '修复了一些问题', downloadUrl);
        } else {
          // 只有手动检查才提示无更新
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('暂无 iOS 安装包')));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('检查失败，请检查网络')),
        );
      }
    }
  }

  void _showUpdateDialog(String tagName, String body, String downloadUrl) {
    showPlatformDialog(
      context: context,
      title: '发现新版本 $tagName',
      content: body,
      actions: [
        if (Platform.isIOS) ...[
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () {
              Navigator.pop(context);
              launchUrl(Uri.parse(downloadUrl),
                  mode: LaunchMode.externalApplication);
            },
            child: const Text('立即更新'),
          ),
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('稍后'),
          ),
        ] else ...[
          TextButton(
              onPressed: () => Navigator.pop(context), child: const Text('稍后')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              launchUrl(Uri.parse(downloadUrl),
                  mode: LaunchMode.externalApplication);
            },
            child: const Text('更新'),
          ),
        ]
      ],
    );
  }
}
