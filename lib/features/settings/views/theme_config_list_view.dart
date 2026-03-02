import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../../app/widgets/app_cupertino_page_scaffold.dart';
import '../../../app/widgets/app_nav_bar_button.dart';
import '../../../app/widgets/app_ui_kit.dart';
import '../../../app/widgets/cupertino_bottom_dialog.dart';
import '../../../core/models/app_settings.dart';
import '../../../core/services/settings_service.dart';
import '../models/theme_config_entry.dart';
import '../services/theme_config_service.dart';

/// 主题列表（对齐 legado ThemeListDialog 的承载与菜单入口）。
class ThemeConfigListView extends StatefulWidget {
  const ThemeConfigListView({super.key});

  @override
  State<ThemeConfigListView> createState() => _ThemeConfigListViewState();
}

class _ThemeConfigListViewState extends State<ThemeConfigListView> {
  final ThemeConfigService _themeConfigService = ThemeConfigService();
  final SettingsService _settingsService = SettingsService();

  List<ThemeConfigEntry> _configs = const <ThemeConfigEntry>[];
  bool _loading = true;
  late AppAppearanceMode _appearanceMode;

  @override
  void initState() {
    super.initState();
    _appearanceMode = _settingsService.appSettings.appearanceMode;
    _settingsService.appSettingsListenable.addListener(_onAppSettingsChanged);
    unawaited(_reloadConfigs());
  }

  @override
  void dispose() {
    _settingsService.appSettingsListenable
        .removeListener(_onAppSettingsChanged);
    super.dispose();
  }

  void _onAppSettingsChanged() {
    if (!mounted) return;
    setState(() {
      _appearanceMode = _settingsService.appSettings.appearanceMode;
    });
  }

  Future<void> _reloadConfigs() async {
    final configs = _themeConfigService.loadConfigs();
    if (!mounted) return;
    setState(() {
      _configs = configs;
      _loading = false;
    });
  }

  Future<void> _importFromClipboard() async {
    final clipData = await Clipboard.getData(Clipboard.kTextPlain);
    if (clipData == null) {
      return;
    }
    final clipText = clipData.text ?? '';
    final success = await _themeConfigService.importFromClipboardText(clipText);
    if (!mounted) return;
    if (!success) {
      await _showMessage('格式不对,添加失败');
      return;
    }
    await _reloadConfigs();
  }

  Future<void> _applyConfig(ThemeConfigEntry config) async {
    final modeText = config.isNightTheme ? '深色' : '浅色';
    await _showMessage(
      '主题应用不再修改主题模式（目标：$modeText），请在“我的-主题模式”中切换。',
    );
  }

  Future<void> _shareConfig(int index) async {
    final payload = _themeConfigService.sharePayloadAt(index);
    if (payload == null) return;
    try {
      await SharePlus.instance.share(
        ShareParams(
          text: payload,
          subject: '主题分享',
        ),
      );
    } catch (_) {
      // 对齐 legado Context.share(text, title)：分享失败静默吞掉。
    }
  }

  Future<void> _deleteConfig(int index) async {
    final confirmed = await showCupertinoBottomDialog<bool>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: const Text('删除'),
        content: const Text('\n是否确认删除？'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _themeConfigService.deleteAt(index);
    if (!mounted) return;
    await _reloadConfigs();
  }

  bool _isSelectedConfig(ThemeConfigEntry config) {
    if (_appearanceMode == AppAppearanceMode.followSystem) {
      return false;
    }
    final targetMode =
        config.isNightTheme ? AppAppearanceMode.dark : AppAppearanceMode.light;
    return _appearanceMode == targetMode;
  }

  String _modeText(ThemeConfigEntry config) {
    final modeText = config.isNightTheme ? '夜间' : '白天';
    if (_isSelectedConfig(config)) {
      return '$modeText（当前）';
    }
    return modeText;
  }

  String _titleText(ThemeConfigEntry config) {
    final normalized = config.themeName.trim();
    if (normalized.isEmpty) {
      return '未命名主题';
    }
    return normalized;
  }

  Future<void> _showMessage(String message) async {
    await showCupertinoBottomDialog<void>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: Text(message),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppCupertinoPageScaffold(
      title: '主题列表',
      trailing: AppNavBarButton(
        onPressed: _importFromClipboard,
        child: const Text('剪贴板导入'),
      ),
      child: _loading
          ? const Center(child: CupertinoActivityIndicator())
          : AppListView(
              children: [
                AppListSection(
                  header: const Text('已保存主题'),
                  hasLeading: false,
                  children: _configs.isEmpty
                      ? const [
                          AppListTile(
                            title: Text('暂无主题配置'),
                            showChevron: false,
                          ),
                        ]
                      : _configs.asMap().entries.map((entry) {
                          final index = entry.key;
                          final config = entry.value;
                          return AppListTile(
                            title: Text(_titleText(config)),
                            additionalInfo: Text(_modeText(config)),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CupertinoButton(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 0,
                                  ),
                                  onPressed: () => _shareConfig(index),
                                  minimumSize: const Size(28, 28),
                                  child: const Icon(
                                    CupertinoIcons.share,
                                    size: 18,
                                  ),
                                ),
                                CupertinoButton(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 0,
                                  ),
                                  onPressed: () => _deleteConfig(index),
                                  minimumSize: const Size(28, 28),
                                  child: const Icon(
                                    CupertinoIcons.delete,
                                    size: 18,
                                  ),
                                ),
                              ],
                            ),
                            onTap: () => _applyConfig(config),
                          );
                        }).toList(),
                ),
                const SizedBox(height: 24),
              ],
            ),
    );
  }
}
