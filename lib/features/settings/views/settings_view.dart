import 'package:flutter/cupertino.dart';
import 'package:dio/dio.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 设置页面 - 纯 iOS 原生风格
class SettingsView extends StatefulWidget {
  const SettingsView({super.key});

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  bool _darkMode = true;
  bool _autoUpdate = true;
  bool _wifiOnly = true;
  String _version = '';

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      setState(() {
        _version = '${info.version} (${info.buildNumber})';
      });
    } catch (e) {
      setState(() {
        _version = '1.0.0';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('设置'),
      ),
      child: SafeArea(
        child: ListView(
          children: [
            // 阅读设置
            CupertinoListSection.insetGrouped(
              header: const Text('阅读'),
              children: [
                CupertinoListTile.notched(
                  leading: _buildIconBox(
                      CupertinoIcons.textformat, CupertinoColors.systemBlue),
                  title: const Text('阅读偏好'),
                  additionalInfo: const Text('默认'),
                  trailing: const CupertinoListTileChevron(),
                  onTap: _openReadingSettings,
                ),
                CupertinoListTile.notched(
                  leading: _buildIconBox(
                      CupertinoIcons.moon_fill, CupertinoColors.systemIndigo),
                  title: const Text('深色模式'),
                  trailing: CupertinoSwitch(
                    value: _darkMode,
                    onChanged: (value) => setState(() => _darkMode = value),
                  ),
                ),
              ],
            ),

            // 书源设置
            CupertinoListSection.insetGrouped(
              header: const Text('书源'),
              children: [
                CupertinoListTile.notched(
                  leading: _buildIconBox(
                      CupertinoIcons.cloud_fill, CupertinoColors.systemCyan),
                  title: const Text('书源管理'),
                  additionalInfo: const Text('4 个'),
                  trailing: const CupertinoListTileChevron(),
                  onTap: () {},
                ),
                CupertinoListTile.notched(
                  leading: _buildIconBox(CupertinoIcons.arrow_2_circlepath,
                      CupertinoColors.systemGreen),
                  title: const Text('自动更新'),
                  trailing: CupertinoSwitch(
                    value: _autoUpdate,
                    onChanged: (value) => setState(() => _autoUpdate = value),
                  ),
                ),
              ],
            ),

            // 存储
            CupertinoListSection.insetGrouped(
              header: const Text('存储'),
              children: [
                CupertinoListTile.notched(
                  leading: _buildIconBox(
                      CupertinoIcons.wifi, CupertinoColors.systemBlue),
                  title: const Text('仅 Wi-Fi 下载'),
                  trailing: CupertinoSwitch(
                    value: _wifiOnly,
                    onChanged: (value) => setState(() => _wifiOnly = value),
                  ),
                ),
                CupertinoListTile.notched(
                  leading: _buildIconBox(
                      CupertinoIcons.trash_fill, CupertinoColors.systemRed),
                  title: const Text('清除缓存'),
                  additionalInfo: const Text('256 MB'),
                  trailing: const CupertinoListTileChevron(),
                  onTap: _showCacheOptions,
                ),
              ],
            ),

            // 其他
            CupertinoListSection.insetGrouped(
              header: const Text('其他'),
              children: [
                CupertinoListTile.notched(
                  leading: _buildIconBox(CupertinoIcons.arrow_down_circle_fill,
                      CupertinoColors.systemGreen),
                  title: const Text('检查更新'),
                  trailing: const CupertinoListTileChevron(),
                  onTap: _checkUpdate,
                ),
                CupertinoListTile.notched(
                  leading: _buildIconBox(CupertinoIcons.arrow_up_arrow_down,
                      CupertinoColors.systemOrange),
                  title: const Text('备份与恢复'),
                  trailing: const CupertinoListTileChevron(),
                  onTap: _showBackupOptions,
                ),
                CupertinoListTile.notched(
                  leading: _buildIconBox(CupertinoIcons.info_circle_fill,
                      CupertinoColors.systemGrey),
                  title: const Text('关于'),
                  additionalInfo: Text(_version),
                  trailing: const CupertinoListTileChevron(),
                  onTap: _showAbout,
                ),
              ],
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  /// 构建设置项图标盒子 - iOS 风格
  Widget _buildIconBox(IconData icon, Color color) {
    return Container(
      width: 29,
      height: 29,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Icon(icon, color: CupertinoColors.white, size: 17),
    );
  }

  void _openReadingSettings() {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.5,
        decoration: BoxDecoration(
          color: CupertinoColors.systemBackground.resolveFrom(context),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
        ),
        child: Column(
          children: [
            // 拖动指示器
            Container(
              margin: const EdgeInsets.only(top: 8),
              width: 36,
              height: 5,
              decoration: BoxDecoration(
                color: CupertinoColors.systemGrey3.resolveFrom(context),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                '阅读偏好',
                style: CupertinoTheme.of(context).textTheme.navTitleTextStyle,
              ),
            ),
            Expanded(
              child: CupertinoListSection.insetGrouped(
                children: [
                  CupertinoListTile.notched(
                    title: const Text('字体大小'),
                    additionalInfo: const Text('18'),
                    trailing: const CupertinoListTileChevron(),
                  ),
                  CupertinoListTile.notched(
                    title: const Text('行距'),
                    additionalInfo: const Text('1.8'),
                    trailing: const CupertinoListTileChevron(),
                  ),
                  CupertinoListTile.notched(
                    title: const Text('主题'),
                    additionalInfo: const Text('夜间'),
                    trailing: const CupertinoListTileChevron(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCacheOptions() {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('清除缓存'),
        content: const Text('\n当前缓存 256 MB\n\n这将删除所有已下载的章节，书架和阅读进度不受影响。'),
        actions: [
          CupertinoDialogAction(
            child: const Text('取消'),
            onPressed: () => Navigator.pop(context),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: const Text('清除'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  void _showBackupOptions() {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        actions: [
          CupertinoActionSheetAction(
            child: const Text('导出到文件'),
            onPressed: () => Navigator.pop(context),
          ),
          CupertinoActionSheetAction(
            child: const Text('从文件导入'),
            onPressed: () => Navigator.pop(context),
          ),
          CupertinoActionSheetAction(
            child: const Text('iCloud 同步'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          child: const Text('取消'),
          onPressed: () => Navigator.pop(context),
        ),
      ),
    );
  }

  void _showAbout() {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('SoupReader'),
        content: Text('\n版本 $_version\n\n一款简洁优雅的阅读应用\n支持自定义书源'),
        actions: [
          CupertinoDialogAction(
            child: const Text('好'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Future<void> _checkUpdate() async {
    showCupertinoDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CupertinoActivityIndicator()),
    );

    try {
      final dio = Dio();
      final prefs = await SharedPreferences.getInstance();

      final response = await dio.get(
        'https://github-action-cf.mcshr.workers.dev/latest',
      );

      if (!mounted) return;
      Navigator.pop(context);

      if (response.statusCode == 200) {
        final data = response.data;
        final tag = data['tag'] as String?;
        final name = data['name'] as String?;
        final downloadUrl = data['downloadUrl'] as String?;
        final publishedAt = data['publishedAt'] as String?;

        if (downloadUrl == null || downloadUrl.isEmpty) {
          _showMessage('未找到安装包');
          return;
        }

        // 版本比较
        final lastIgnoredTime = prefs.getString('last_ignored_update_time');
        final lastUpdatedTime = prefs.getString('last_updated_time');

        if (publishedAt != null) {
          final remoteTime = DateTime.tryParse(publishedAt);
          if (remoteTime != null) {
            if (lastIgnoredTime != null) {
              final ignored = DateTime.tryParse(lastIgnoredTime);
              if (ignored != null && !remoteTime.isAfter(ignored)) {
                _showMessage('已是最新版本');
                return;
              }
            }
            if (lastUpdatedTime != null) {
              final updated = DateTime.tryParse(lastUpdatedTime);
              if (updated != null && !remoteTime.isAfter(updated)) {
                _showMessage('已是最新版本');
                return;
              }
            }
          }
        }

        String info = name ?? 'Nightly Build';
        if (publishedAt != null) {
          try {
            final date = DateTime.parse(publishedAt);
            info +=
                '\n${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
          } catch (_) {}
        }

        _showUpdateDialog(tag ?? 'nightly', info, downloadUrl, publishedAt);
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        if (e is DioException && e.response?.statusCode == 404) {
          _showMessage('暂无更新');
        } else {
          _showMessage('检查失败');
        }
      }
    }
  }

  void _showMessage(String message) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            child: const Text('好'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  void _showUpdateDialog(
      String tag, String body, String url, String? publishedAt) {
    showCupertinoDialog(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: Text('有新版本 $tag'),
        content: Text('\n$body'),
        actions: [
          CupertinoDialogAction(
            child: const Text('忽略'),
            onPressed: () {
              Navigator.pop(dialogContext);
              _saveIgnoreTime(publishedAt);
            },
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            child: const Text('更新'),
            onPressed: () {
              Navigator.pop(dialogContext);
              _saveUpdateTimeAndLaunch(url, publishedAt);
            },
          ),
        ],
      ),
    );
  }

  /// 保存忽略时间
  Future<void> _saveIgnoreTime(String? publishedAt) async {
    if (publishedAt == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_ignored_update_time', publishedAt);
      debugPrint('已保存忽略时间: $publishedAt');
    } catch (e) {
      debugPrint('保存忽略时间失败: $e');
    }
  }

  /// 保存更新时间并打开链接
  Future<void> _saveUpdateTimeAndLaunch(String url, String? publishedAt) async {
    if (publishedAt != null) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('last_updated_time', publishedAt);
        debugPrint('已保存更新时间: $publishedAt');
      } catch (e) {
        debugPrint('保存更新时间失败: $e');
      }
    }
    launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }
}
