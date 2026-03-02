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
import '../../../core/models/app_settings.dart';
import '../../../core/services/settings_service.dart';

class AppearanceSettingsView extends StatefulWidget {
  const AppearanceSettingsView({super.key});

  @override
  State<AppearanceSettingsView> createState() => _AppearanceSettingsViewState();
}

class _AppearanceSettingsViewState extends State<AppearanceSettingsView> {
  static const String _defaultInputActionToken = '__default__';
  static const List<({String value, String label})> _launcherIconOptions = [
    (value: AppSettings.defaultLauncherIcon, label: 'iconMain'),
    (value: 'launcher1', label: 'icon1'),
    (value: 'launcher2', label: 'icon2'),
    (value: 'launcher3', label: 'icon3'),
    (value: 'launcher4', label: 'icon4'),
    (value: 'launcher5', label: 'icon5'),
    (value: 'launcher6', label: 'icon6'),
  ];

  final SettingsService _settingsService = SettingsService();
  late AppSettings _settings;

  @override
  void initState() {
    super.initState();
    _settings = _settingsService.appSettings;
    _settingsService.appSettingsListenable.addListener(_onChanged);
  }

  @override
  void dispose() {
    _settingsService.appSettingsListenable.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (!mounted) return;
    setState(() => _settings = _settingsService.appSettings);
  }

  Future<void> _showThemeModeManagedHint() async {
    await showCupertinoBottomDialog<void>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: const Text('外观开关'),
        content: const Text('请在“我的-主题模式”中切换主题模式。'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }

  String _launcherIconLabel(String value) {
    for (final option in _launcherIconOptions) {
      if (option.value == value) return option.label;
    }
    return value;
  }

  String get _barElevationSummary {
    final value = _settings.barElevation;
    if (value == AppSettings.defaultBarElevation) {
      return '默认（$value）';
    }
    return value.toString();
  }

  String get _fontScaleSummary {
    final value = _settings.fontScale;
    if (value == AppSettings.defaultFontScale) {
      return '默认';
    }
    return '${(value / 10).toStringAsFixed(1)}x';
  }

  String _backgroundImageSummary(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty) return '选择图片';
    if (normalized.length <= 26) return normalized;
    return '${normalized.substring(0, 26)}…';
  }

  void _toggleTransparentStatusBar(bool value) {
    setState(() {
      _settings = _settings.copyWith(transparentStatusBar: value);
    });
    _settingsService.saveTransparentStatusBar(value);
  }

  void _toggleImmNavigationBar(bool value) {
    setState(() {
      _settings = _settings.copyWith(immNavigationBar: value);
    });
    _settingsService.saveImmNavigationBar(value);
  }

  Future<void> _pickLauncherIcon() async {
    final currentIndex = _launcherIconOptions.indexWhere(
      (option) => option.value == _settings.launcherIcon,
    );
    var pendingIndex = currentIndex >= 0 ? currentIndex : 0;
    final controller = FixedExtentScrollController(initialItem: pendingIndex);
    final selected = await showCupertinoModalPopup<int>(
      context: context,
      builder: (dialogContext) => Container(
        height: 300,
        color: CupertinoDynamicColor.resolve(
          CupertinoColors.systemBackground,
          dialogContext,
        ),
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              SizedBox(
                height: 44,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    CupertinoButton(
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      child: const Text('取消'),
                    ),
                    CupertinoButton(
                      onPressed: () =>
                          Navigator.of(dialogContext).pop(pendingIndex),
                      child: const Text('确定'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: CupertinoPicker(
                  scrollController: controller,
                  itemExtent: 36,
                  onSelectedItemChanged: (index) {
                    pendingIndex = index;
                  },
                  children: _launcherIconOptions
                      .map(
                        (option) => Center(
                          child: Text(option.label),
                        ),
                      )
                      .toList(growable: false),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    controller.dispose();
    if (selected == null || selected == currentIndex) return;
    await _settingsService
        .saveLauncherIcon(_launcherIconOptions[selected].value);
  }

  Future<void> _pickBarElevation() async {
    final value = await _showIntegerInputDialog(
      title: '导航栏阴影',
      placeholder: '请输入 0 - 32',
      initialValue: _settings.barElevation.toString(),
    );
    if (value == null) return;
    if (value == _defaultInputActionToken) {
      await _settingsService.saveBarElevation(AppSettings.defaultBarElevation);
      return;
    }
    final parsed = int.tryParse(value);
    if (parsed == null || parsed < 0 || parsed > 32) {
      await _showValidationMessage('请输入 0-32 的整数');
      return;
    }
    await _settingsService.saveBarElevation(parsed);
  }

  Future<void> _pickFontScale() async {
    final value = await _showIntegerInputDialog(
      title: '字体缩放',
      placeholder: '0=默认；或输入 8 - 16',
      initialValue: _settings.fontScale.toString(),
    );
    if (value == null) return;
    if (value == _defaultInputActionToken) {
      await _settingsService.saveFontScale(AppSettings.defaultFontScale);
      return;
    }
    final parsed = int.tryParse(value);
    final valid =
        parsed != null && (parsed == 0 || (parsed >= 8 && parsed <= 16));
    if (!valid) {
      await _showValidationMessage('请输入 0 或 8-16 的整数');
      return;
    }
    await _settingsService.saveFontScale(parsed);
  }

  Future<void> _editBackgroundImage({required bool night}) async {
    final currentPath =
        night ? _settings.backgroundImageNight : _settings.backgroundImage;
    final hasImage = currentPath.trim().isNotEmpty;
    final selected = await showAppActionListSheet<_BackgroundImageAction>(
      context: context,
      title: night ? '夜间背景图' : '白天背景图',
      showCancel: true,
      items: [
        const AppActionListItem<_BackgroundImageAction>(
          value: _BackgroundImageAction.select,
          icon: CupertinoIcons.photo,
          label: '选择图片',
        ),
        if (hasImage)
          const AppActionListItem<_BackgroundImageAction>(
            value: _BackgroundImageAction.clear,
            icon: CupertinoIcons.delete,
            label: '清空',
            isDestructiveAction: true,
          ),
      ],
    );
    if (selected == _BackgroundImageAction.select) {
      await _pickAndSaveBackgroundImage(night: night);
      return;
    }
    if (selected == _BackgroundImageAction.clear) {
      await _saveBackgroundImagePath(night: night, path: null);
    }
  }

  Future<void> _pickAndSaveBackgroundImage({required bool night}) async {
    final pickedPath = await _pickAndCopyBackgroundImage(
      filePrefix: night ? 'theme_background_night' : 'theme_background_day',
    );
    if (pickedPath == null) return;
    await _saveBackgroundImagePath(night: night, path: pickedPath);
  }

  Future<void> _saveBackgroundImagePath({
    required bool night,
    required String? path,
  }) async {
    final normalized = (path ?? '').trim();
    if (night) {
      await _settingsService.saveBackgroundImageNight(
        normalized.isEmpty ? null : normalized,
      );
    } else {
      await _settingsService.saveBackgroundImage(
        normalized.isEmpty ? null : normalized,
      );
    }
    if (!mounted) return;
    setState(() {
      _settings = night
          ? _settings.copyWith(backgroundImageNight: normalized)
          : _settings.copyWith(backgroundImage: normalized);
    });
  }

  Future<String?> _pickAndCopyBackgroundImage({
    required String filePrefix,
  }) async {
    if (kIsWeb) {
      await _showMessage('当前平台暂不支持选择本地图片');
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
        await _showMessage('无法读取图片路径');
        return null;
      }

      final sourceFile = File(sourcePath);
      if (!await sourceFile.exists()) {
        await _showMessage('图片文件不存在');
        return null;
      }

      final docsDir = await getApplicationDocumentsDirectory();
      final targetDir =
          Directory(p.join(docsDir.path, 'settings', 'theme_background'));
      if (!await targetDir.exists()) {
        await targetDir.create(recursive: true);
      }

      final originalName = selected.name.trim().isNotEmpty
          ? selected.name.trim()
          : 'background.jpg';
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
      await _showMessage('选择图片失败：$error');
      return null;
    }
  }

  Future<void> _pickBackgroundImageBlurring({required bool night}) async {
    final currentValue = night
        ? _settings.backgroundImageNightBlurring
        : _settings.backgroundImageBlurring;
    final maxValue = AppSettings.maxBackgroundImageBlurring;
    final value = await _showIntegerInputDialog(
      title: night ? '夜间模糊度' : '白天模糊度',
      placeholder: '请输入 0 - $maxValue',
      initialValue: currentValue.toString(),
    );
    if (value == null) return;
    if (value == _defaultInputActionToken) {
      await _saveBackgroundImageBlurring(
        night: night,
        value: AppSettings.defaultBackgroundImageBlurring,
      );
      return;
    }
    final parsed = int.tryParse(value);
    if (parsed == null || parsed < 0 || parsed > maxValue) {
      await _showValidationMessage('请输入 0-$maxValue 的整数');
      return;
    }
    await _saveBackgroundImageBlurring(night: night, value: parsed);
  }

  Future<void> _saveBackgroundImageBlurring({
    required bool night,
    required int value,
  }) async {
    if (night) {
      await _settingsService.saveBackgroundImageNightBlurring(value);
    } else {
      await _settingsService.saveBackgroundImageBlurring(value);
    }
    if (!mounted) return;
    setState(() {
      _settings = night
          ? _settings.copyWith(backgroundImageNightBlurring: value)
          : _settings.copyWith(backgroundImageBlurring: value);
    });
  }

  Future<String?> _showIntegerInputDialog({
    required String title,
    required String placeholder,
    required String initialValue,
  }) async {
    final controller = TextEditingController(text: initialValue);
    return showCupertinoBottomDialog<String>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: Text(title),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: CupertinoTextField(
            controller: controller,
            keyboardType: TextInputType.number,
            placeholder: placeholder,
          ),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () =>
                Navigator.of(dialogContext).pop(_defaultInputActionToken),
            child: const Text('默认'),
          ),
          CupertinoDialogAction(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(dialogContext).pop(
              controller.text.trim(),
            ),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  Future<void> _showValidationMessage(String message) async {
    await showCupertinoBottomDialog<void>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: const Text('输入无效'),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }

  Future<void> _showMessage(String message) async {
    await showCupertinoBottomDialog<void>(
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
    final systemBrightness = MediaQuery.platformBrightnessOf(context);
    final followSystem =
        _settings.appearanceMode == AppAppearanceMode.followSystem;
    final effectiveIsDark = followSystem
        ? systemBrightness == Brightness.dark
        : _settings.appearanceMode == AppAppearanceMode.dark;

    return AppCupertinoPageScaffold(
      title: '外观与通用',
      child: AppListView(
        children: [
          AppListSection(
            header: const Text('外观'),
            children: [
              AppListTile(
                title: const Text('跟随系统外观'),
                trailing: CupertinoSwitch(
                  value: followSystem,
                  onChanged: (_) => _showThemeModeManagedHint(),
                ),
              ),
              AppListTile(
                title: const Text('深色模式'),
                trailing: CupertinoSwitch(
                  value: effectiveIsDark,
                  onChanged: (_) => _showThemeModeManagedHint(),
                ),
              ),
            ],
          ),
          AppListSection(
            header: const Text('主题底层配置'),
            children: [
              AppListTile(
                title: const Text('启动图标'),
                additionalInfo:
                    Text(_launcherIconLabel(_settings.launcherIcon)),
                onTap: _pickLauncherIcon,
              ),
              AppListTile(
                title: const Text('沉浸状态栏'),
                trailing: CupertinoSwitch(
                  value: _settings.transparentStatusBar,
                  onChanged: _toggleTransparentStatusBar,
                ),
              ),
              AppListTile(
                title: const Text('沉浸导航栏'),
                trailing: CupertinoSwitch(
                  value: _settings.immNavigationBar,
                  onChanged: _toggleImmNavigationBar,
                ),
              ),
              AppListTile(
                title: const Text('导航栏阴影'),
                additionalInfo: Text(_barElevationSummary),
                onTap: _pickBarElevation,
              ),
              AppListTile(
                title: const Text('字体缩放'),
                additionalInfo: Text(_fontScaleSummary),
                onTap: _pickFontScale,
              ),
              AppListTile(
                title: const Text('白天背景图'),
                additionalInfo: Text(
                  _backgroundImageSummary(_settings.backgroundImage),
                ),
                onTap: () => _editBackgroundImage(night: false),
              ),
              AppListTile(
                title: const Text('白天模糊度'),
                additionalInfo: Text(
                  _settings.backgroundImageBlurring.toString(),
                ),
                onTap: () => _pickBackgroundImageBlurring(night: false),
              ),
              AppListTile(
                title: const Text('夜间背景图'),
                additionalInfo: Text(
                  _backgroundImageSummary(_settings.backgroundImageNight),
                ),
                onTap: () => _editBackgroundImage(night: true),
              ),
              AppListTile(
                title: const Text('夜间模糊度'),
                additionalInfo: Text(
                  _settings.backgroundImageNightBlurring.toString(),
                ),
                onTap: () => _pickBackgroundImageBlurring(night: true),
              ),
            ],
          ),
          AppListSection(
            header: const Text('说明'),
            children: [
              const AppListTile(
                title: Text('本页用于应用外观与主题底层配置，不影响阅读主题。'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

enum _BackgroundImageAction {
  select,
  clear,
}
