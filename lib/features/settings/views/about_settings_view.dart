import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class AboutSettingsView extends StatefulWidget {
  const AboutSettingsView({super.key});

  @override
  State<AboutSettingsView> createState() => _AboutSettingsViewState();
}

class _AboutSettingsViewState extends State<AboutSettingsView> {
  String _version = '—';

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (!mounted) return;
      setState(() {
        _version = '${info.version} (${info.buildNumber})';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _version = '—');
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('关于与诊断'),
      ),
      child: SafeArea(
        child: ListView(
          children: [
            CupertinoListSection.insetGrouped(
              header: const Text('应用'),
              children: [
                CupertinoListTile.notched(
                  title: const Text('应用名称'),
                  additionalInfo: const Text('SoupReader'),
                ),
                CupertinoListTile.notched(
                  title: const Text('版本'),
                  additionalInfo: Text(_version),
                ),
              ],
            ),
            CupertinoListSection.insetGrouped(
              header: const Text('更新'),
              children: [
                CupertinoListTile.notched(
                  title: const Text('检查更新'),
                  trailing: const CupertinoListTileChevron(),
                  onTap: _checkUpdate,
                ),
              ],
            ),
            CupertinoListSection.insetGrouped(
              header: const Text('说明'),
              children: const [
                CupertinoListTile(
                  title: Text('如遇到书源解析问题，建议在“书源”中导出相关书源 JSON 便于排查。'),
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
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

        var info = name ?? 'Nightly Build';
        if (publishedAt != null) {
          try {
            final date = DateTime.parse(publishedAt).toLocal();
            final dateStr =
                '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} '
                '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
            info += '\n$dateStr';
          } catch (_) {}
        }

        _showUpdateInfo(tag ?? 'nightly', info, downloadUrl);
        return;
      }

      _showMessage('检查失败');
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
        title: const Text('提示'),
        content: Text('\n$message'),
        actions: [
          CupertinoDialogAction(
            child: const Text('好'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  void _showUpdateInfo(String tag, String info, String downloadUrl) {
    showCupertinoDialog(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: const Text('最新版本'),
        content: Text('\n$tag\n$info'),
        actions: [
          CupertinoDialogAction(
            child: const Text('关闭'),
            onPressed: () => Navigator.pop(dialogContext),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            child: const Text('下载'),
            onPressed: () {
              Navigator.pop(dialogContext);
              launchUrl(
                Uri.parse(downloadUrl),
                mode: LaunchMode.externalApplication,
              );
            },
          ),
        ],
      ),
    );
  }
}

