import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';

import '../../../app/widgets/app_action_list_sheet.dart';
import '../../../app/widgets/app_ui_kit.dart';
import '../../../app/widgets/cupertino_bottom_dialog.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../app/widgets/app_cupertino_page_scaffold.dart';
import '../../../core/services/settings_service.dart';

/// 启动界面样式（对齐 legado `pref_config_welcome.xml` 的基础可操作项）。
class WelcomeStyleSettingsView extends StatefulWidget {
  const WelcomeStyleSettingsView({super.key});

  @override
  State<WelcomeStyleSettingsView> createState() =>
      _WelcomeStyleSettingsViewState();
}

class _WelcomeStyleSettingsViewState extends State<WelcomeStyleSettingsView> {
  final SettingsService _settingsService = SettingsService();

  bool _customWelcome = false;
  String _welcomeImagePath = '';
  bool _welcomeShowText = true;
  bool _welcomeShowIcon = true;

  String _welcomeImageDarkPath = '';
  bool _welcomeShowTextDark = true;
  bool _welcomeShowIconDark = true;

  @override
  void initState() {
    super.initState();
    _loadFromSettings();
  }

  void _loadFromSettings() {
    setState(() {
      _customWelcome = _settingsService.customWelcome;
      _welcomeImagePath = _settingsService.welcomeImagePath;
      _welcomeShowText = _settingsService.welcomeShowText;
      _welcomeShowIcon = _settingsService.welcomeShowIcon;
      _welcomeImageDarkPath = _settingsService.welcomeImageDarkPath;
      _welcomeShowTextDark = _settingsService.welcomeShowTextDark;
      _welcomeShowIconDark = _settingsService.welcomeShowIconDark;
    });
  }

  Future<void> _editWelcomeImage({required bool night}) async {
    final currentPath = night ? _welcomeImageDarkPath : _welcomeImagePath;
    if (currentPath.isEmpty) {
      await _pickAndSaveWelcomeImage(night: night);
      return;
    }

    final selected = await showAppActionListSheet<_WelcomeImageAction>(
      context: context,
      title: night ? '夜间背景图片' : '白天背景图片',
      showCancel: true,
      items: const [
        AppActionListItem<_WelcomeImageAction>(
          value: _WelcomeImageAction.delete,
          icon: CupertinoIcons.delete,
          label: '删除',
          isDestructiveAction: true,
        ),
        AppActionListItem<_WelcomeImageAction>(
          value: _WelcomeImageAction.select,
          icon: CupertinoIcons.photo,
          label: '选择图片',
        ),
      ],
    );

    if (selected == _WelcomeImageAction.delete) {
      await _clearWelcomeImage(night: night);
      return;
    }
    if (selected == _WelcomeImageAction.select) {
      await _pickAndSaveWelcomeImage(night: night);
    }
  }

  Future<void> _pickAndSaveWelcomeImage({required bool night}) async {
    final pickedPath = await _pickAndCopyImage(
      filePrefix: night ? 'welcome_dark' : 'welcome_day',
    );
    if (pickedPath == null) return;

    if (night) {
      await _settingsService.saveWelcomeImageDarkPath(pickedPath);
      if (!mounted) return;
      setState(() => _welcomeImageDarkPath = pickedPath);
      return;
    }

    await _settingsService.saveWelcomeImagePath(pickedPath);
    if (!mounted) return;
    setState(() => _welcomeImagePath = pickedPath);
  }

  Future<void> _clearWelcomeImage({required bool night}) async {
    if (night) {
      await _settingsService.saveWelcomeImageDarkPath(null);
      await _settingsService.saveWelcomeShowTextDark(true);
      await _settingsService.saveWelcomeShowIconDark(true);
      if (!mounted) return;
      setState(() {
        _welcomeImageDarkPath = '';
        _welcomeShowTextDark = true;
        _welcomeShowIconDark = true;
      });
      return;
    }

    await _settingsService.saveWelcomeImagePath(null);
    await _settingsService.saveWelcomeShowText(true);
    await _settingsService.saveWelcomeShowIcon(true);
    if (!mounted) return;
    setState(() {
      _welcomeImagePath = '';
      _welcomeShowText = true;
      _welcomeShowIcon = true;
    });
  }

  Future<String?> _pickAndCopyImage({required String filePrefix}) async {
    if (kIsWeb) {
      _showMessage('当前平台暂不支持选择本地图片');
      return null;
    }
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );
      if (result == null || result.files.isEmpty) {
        return null;
      }
      final selected = result.files.first;
      final sourcePath = selected.path?.trim();
      if (sourcePath == null || sourcePath.isEmpty) {
        _showMessage('无法读取图片路径');
        return null;
      }

      final sourceFile = File(sourcePath);
      if (!await sourceFile.exists()) {
        _showMessage('图片文件不存在');
        return null;
      }

      final docsDir = await getApplicationDocumentsDirectory();
      final targetDir = Directory(p.join(docsDir.path, 'settings', 'welcome'));
      if (!await targetDir.exists()) {
        await targetDir.create(recursive: true);
      }

      final originalName = selected.name.trim().isNotEmpty
          ? selected.name.trim()
          : 'welcome.jpg';
      final sanitizedName =
          originalName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
      final extension = p.extension(sanitizedName).toLowerCase();
      final safeExtension = extension.isEmpty ? '.jpg' : extension;
      final targetName =
          '${filePrefix}_${DateTime.now().millisecondsSinceEpoch}$safeExtension';
      final targetPath = p.join(targetDir.path, targetName);
      final savedFile = await sourceFile.copy(targetPath);
      return savedFile.path;
    } catch (error) {
      _showMessage('选择图片失败：$error');
      return null;
    }
  }

  String _pathSummary(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty) return '选择图片';
    if (normalized.length <= 26) return normalized;
    return '${normalized.substring(0, 26)}…';
  }

  void _showMessage(String message) {
    showCupertinoBottomDialog<void>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: const Text('提示'),
        content: Text('\n$message'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('好'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasDayImage = _welcomeImagePath.trim().isNotEmpty;
    final hasNightImage = _welcomeImageDarkPath.trim().isNotEmpty;

    return AppCupertinoPageScaffold(
      title: '启动界面样式',
      child: AppListView(
        children: [
          AppListSection(
            hasLeading: false,
            children: [
              AppListTile(
                title: const Text('自定义欢迎页'),
                additionalInfo: const Text('是否使用自定义欢迎页'),
                trailing: CupertinoSwitch(
                  value: _customWelcome,
                  onChanged: (value) async {
                    await _settingsService.saveCustomWelcome(value);
                    if (!mounted) return;
                    setState(() => _customWelcome = value);
                  },
                ),
              ),
            ],
          ),
          AppListSection(
            header: const Text('白天'),
            hasLeading: false,
            children: [
              AppListTile(
                title: const Text('背景图片'),
                additionalInfo: Text(_pathSummary(_welcomeImagePath)),
                onTap: () => _editWelcomeImage(night: false),
              ),
              AppListTile(
                title: const Text('显示文字'),
                additionalInfo: const Text('阅读|享受美好时光'),
                trailing: CupertinoSwitch(
                  value: _welcomeShowText,
                  onChanged: hasDayImage
                      ? (value) async {
                          await _settingsService.saveWelcomeShowText(value);
                          if (!mounted) return;
                          setState(() => _welcomeShowText = value);
                        }
                      : null,
                ),
              ),
              AppListTile(
                title: const Text('显示图标'),
                additionalInfo: const Text('显示默认书籍图标'),
                trailing: CupertinoSwitch(
                  value: _welcomeShowIcon,
                  onChanged: hasDayImage
                      ? (value) async {
                          await _settingsService.saveWelcomeShowIcon(value);
                          if (!mounted) return;
                          setState(() => _welcomeShowIcon = value);
                        }
                      : null,
                ),
              ),
            ],
          ),
          AppListSection(
            header: const Text('夜间'),
            hasLeading: false,
            children: [
              AppListTile(
                title: const Text('背景图片'),
                additionalInfo: Text(_pathSummary(_welcomeImageDarkPath)),
                onTap: () => _editWelcomeImage(night: true),
              ),
              AppListTile(
                title: const Text('显示文字'),
                additionalInfo: const Text('阅读|享受美好时光'),
                trailing: CupertinoSwitch(
                  value: _welcomeShowTextDark,
                  onChanged: hasNightImage
                      ? (value) async {
                          await _settingsService.saveWelcomeShowTextDark(value);
                          if (!mounted) return;
                          setState(() => _welcomeShowTextDark = value);
                        }
                      : null,
                ),
              ),
              AppListTile(
                title: const Text('显示图标'),
                additionalInfo: const Text('显示默认书籍图标'),
                trailing: CupertinoSwitch(
                  value: _welcomeShowIconDark,
                  onChanged: hasNightImage
                      ? (value) async {
                          await _settingsService.saveWelcomeShowIconDark(value);
                          if (!mounted) return;
                          setState(() => _welcomeShowIconDark = value);
                        }
                      : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

enum _WelcomeImageAction {
  delete,
  select,
}
