import 'package:flutter/cupertino.dart';

import '../../../app/theme/ui_tokens.dart';
import '../../../app/widgets/app_ui_kit.dart';
import '../../../app/widgets/cupertino_bottom_dialog.dart';

import '../../../app/theme/cupertino_theme.dart';
import '../../../app/widgets/app_cupertino_page_scaffold.dart';
import '../../../app/widgets/app_nav_bar_button.dart';
import '../../../core/models/app_settings.dart';
import '../../../core/services/settings_service.dart';
import '../services/theme_config_service.dart';
import 'appearance_settings_view.dart';
import 'cover_config_view.dart';
import 'reading_interface_settings_hub_view.dart';
import 'reading_theme_settings_view.dart';
import 'theme_config_list_view.dart';
import 'welcome_style_settings_view.dart';

class ThemeSettingsView extends StatefulWidget {
  const ThemeSettingsView({super.key});

  @override
  State<ThemeSettingsView> createState() => _ThemeSettingsViewState();
}

class _ThemeSettingsViewState extends State<ThemeSettingsView> {
  final SettingsService _settingsService = SettingsService();
  final ThemeConfigService _themeConfigService = ThemeConfigService();
  static final RegExp _illegalThemeNamePattern =
      RegExp(r'[\u0000-\u001F\u007F]');

  @override
  void initState() {
    super.initState();
    _settingsService.appSettingsListenable.addListener(_onAppSettingsChanged);
  }

  @override
  void dispose() {
    _settingsService.appSettingsListenable
        .removeListener(_onAppSettingsChanged);
    super.dispose();
  }

  void _onAppSettingsChanged() {
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _showThemeModeManagedHint() async {
    await showCupertinoBottomDialog<void>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: const Text('主题模式'),
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

  Future<void> _saveThemeSnapshot({required bool isNightTheme}) async {
    final modeLabel = isNightTheme ? '夜间' : '白天';
    final inputName =
        await _showThemeNameInputDialog(isNightTheme: isNightTheme);
    if (!mounted) return;
    if (inputName == null) {
      await _showFallbackHint('已取消保存$modeLabel主题');
      return;
    }

    final themeName = inputName.trim();
    if (themeName.isEmpty) {
      await _showFallbackHint('主题名称不能为空');
      return;
    }
    if (_isIllegalThemeName(themeName)) {
      await _showFallbackHint('主题名称不合法，请使用 1-40 位常规字符');
      return;
    }

    final snapshot = _buildThemeSnapshot(isNightTheme: isNightTheme);
    final saved = await _themeConfigService.saveCurrentTheme(
      themeName: themeName,
      isNightTheme: isNightTheme,
      primaryColor: snapshot.primaryColor,
      accentColor: snapshot.accentColor,
      backgroundColor: snapshot.backgroundColor,
      bottomBackground: snapshot.bottomBackground,
    );
    if (!mounted) return;
    if (saved == null) {
      await _showFallbackHint('保存失败，请稍后重试');
      return;
    }
    await _showSuccessHint('已保存$modeLabel主题：${saved.themeName}');
  }

  Future<String?> _showThemeNameInputDialog(
      {required bool isNightTheme}) async {
    final controller = TextEditingController();
    final modeLabel = isNightTheme ? '夜间' : '白天';
    final result = await showCupertinoBottomDialog<String>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: Text('保存$modeLabel主题'),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: CupertinoTextField(
            controller: controller,
            placeholder: '请输入主题名称',
            autofocus: true,
            textInputAction: TextInputAction.done,
          ),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(dialogContext).pop(controller.text),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  Future<void> _showSuccessHint(String message) async {
    await showCupertinoBottomDialog<void>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: const Text('保存成功'),
        content: Text('\n$message'),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('好'),
          ),
        ],
      ),
    );
  }

  Future<void> _showFallbackHint(String message) async {
    await showCupertinoBottomDialog<void>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: const Text('提示'),
        content: Text('\n$message'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }

  bool _isIllegalThemeName(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty) return true;
    if (normalized.length > 40) return true;
    return _illegalThemeNamePattern.hasMatch(normalized);
  }

  ({
    String primaryColor,
    String accentColor,
    String backgroundColor,
    String bottomBackground,
  }) _buildThemeSnapshot({required bool isNightTheme}) {
    final brightness = isNightTheme ? Brightness.dark : Brightness.light;
    final theme = AppCupertinoTheme.build(brightness);
    final accent = theme.textTheme.actionTextStyle.color ?? theme.primaryColor;
    final bottomBackground = theme.barBackgroundColor;
    return (
      primaryColor: _toHexColor(theme.primaryColor),
      accentColor: _toHexColor(accent),
      backgroundColor: _toHexColor(theme.scaffoldBackgroundColor),
      bottomBackground: _toHexColor(bottomBackground),
    );
  }

  String _toHexColor(Color color) {
    final hex =
        color.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase();
    return '#$hex';
  }

  String _themeModeSummary(BuildContext context) {
    final mode = _settingsService.appSettings.appearanceMode;
    switch (mode) {
      case AppAppearanceMode.followSystem:
        final systemBrightness = MediaQuery.platformBrightnessOf(context);
        return systemBrightness == Brightness.dark
            ? '跟随系统（当前夜间）'
            : '跟随系统（当前白天）';
      case AppAppearanceMode.light:
        return '白天';
      case AppAppearanceMode.dark:
        return '夜间';
      case AppAppearanceMode.eInk:
        return 'E-Ink';
    }
  }

  Future<void> _openThemeList() async {
    await Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (context) => const ThemeConfigListView(),
      ),
    );
  }

  Future<void> _openCoverConfig() async {
    await Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (context) => const CoverConfigView(),
      ),
    );
  }

  Future<void> _openWelcomeStyle() async {
    await Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (context) => const WelcomeStyleSettingsView(),
      ),
    );
  }

  String _appearanceModeSummary() {
    switch (_settingsService.appSettings.appearanceMode) {
      case AppAppearanceMode.followSystem:
        return '跟随系统';
      case AppAppearanceMode.light:
        return '浅色';
      case AppAppearanceMode.dark:
        return '深色';
      case AppAppearanceMode.eInk:
        return 'E-Ink';
    }
  }

  String _launcherIconLabel(String value) {
    switch (value) {
      case AppSettings.defaultLauncherIcon:
        return 'iconMain';
      case 'launcher1':
        return 'icon1';
      case 'launcher2':
        return 'icon2';
      case 'launcher3':
        return 'icon3';
      case 'launcher4':
        return 'icon4';
      case 'launcher5':
        return 'icon5';
      case 'launcher6':
        return 'icon6';
      default:
        return value;
    }
  }

  String _fontScaleSummary(int value) {
    if (value == AppSettings.defaultFontScale) {
      return '默认';
    }
    return '${(value / 10).toStringAsFixed(1)}x';
  }

  String _backgroundImageStateSummary(String value) {
    return value.trim().isEmpty ? '未设置' : '已设置';
  }

  String _appearanceSummary() {
    final settings = _settingsService.appSettings;
    final barState = settings.transparentStatusBar ? '状态栏沉浸开' : '状态栏沉浸关';
    final navState = settings.immNavigationBar ? '导航栏沉浸开' : '导航栏沉浸关';
    final dayBackgroundState =
        _backgroundImageStateSummary(settings.backgroundImage);
    final nightBackgroundState =
        _backgroundImageStateSummary(settings.backgroundImageNight);
    return '${_appearanceModeSummary()} · ${_launcherIconLabel(settings.launcherIcon)} · '
        '$barState · $navState · 阴影${settings.barElevation} · '
        '字体${_fontScaleSummary(settings.fontScale)} · '
        '白天背景图$dayBackgroundState · 白天模糊${settings.backgroundImageBlurring} · '
        '夜间背景图$nightBackgroundState · 夜间模糊${settings.backgroundImageNightBlurring}';
  }

  Future<void> _openAppearanceSettings() async {
    await Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (context) => const AppearanceSettingsView(),
      ),
    );
    if (!mounted) return;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return AppCupertinoPageScaffold(
      title: '主题设置',
      trailing: AppNavBarButton(
        onPressed: _showThemeModeManagedHint,
        child: const Text('主题模式'),
      ),
      child: AppListView(
        children: [
          _buildThemeHeroCard(context),
          AppListSection(
            header: Text('主题模式：${_themeModeSummary(context)}'),
            children: [
              AppListTile(
                title: const Text('启动界面样式'),                onTap: _openWelcomeStyle,
              ),
              AppListTile(
                title: const Text('封面设置'),                onTap: _openCoverConfig,
              ),
              AppListTile(
                title: const Text('主题列表'),                onTap: _openThemeList,
              ),
              AppListTile(
                title: const Text('保存白天主题'),                onTap: () => _saveThemeSnapshot(isNightTheme: false),
              ),
              AppListTile(
                title: const Text('保存夜间主题'),                onTap: () => _saveThemeSnapshot(isNightTheme: true),
              ),
            ],
          ),
          AppListSection(
            header: const Text('界面与阅读'),
            children: [
              AppListTile(
                title: const Text('外观与主题底层'),
                additionalInfo: Text(_appearanceSummary()),
                onTap: _openAppearanceSettings,
              ),
              AppListTile(
                title: const Text('阅读主题'),                onTap: () => Navigator.of(context).push(
                  CupertinoPageRoute<void>(
                    builder: (context) => const ReadingThemeSettingsView(),
                  ),
                ),
              ),
              AppListTile(
                title: const Text('阅读界面样式'),                onTap: () => Navigator.of(context).push(
                  CupertinoPageRoute<void>(
                    builder: (context) =>
                        const ReadingInterfaceSettingsHubView(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildThemeHeroCard(BuildContext context) {
    final tokens = AppUiTokens.resolve(context);
    final theme = CupertinoTheme.of(context);
    final mode = _settingsService.appSettings.appearanceMode;
    final modeLabel = _themeModeSummary(context);
    final iconData = switch (mode) {
      AppAppearanceMode.followSystem => CupertinoIcons.circle_lefthalf_fill,
      AppAppearanceMode.light => CupertinoIcons.sun_max_fill,
      AppAppearanceMode.dark => CupertinoIcons.moon_stars_fill,
      AppAppearanceMode.eInk => CupertinoIcons.rectangle_compress_vertical,
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      child: AppCard(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        borderColor: tokens.colors.separator.withValues(alpha: 0.72),
        child: Row(
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: tokens.colors.accent,
              ),
              child: SizedBox(
                width: 42,
                height: 42,
                child: Icon(
                  iconData,
                  color: CupertinoColors.white,
                  size: 20,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '当前主题模式',
                    style: theme.textTheme.textStyle.copyWith(
                      fontSize: 12,
                      color: tokens.colors.secondaryLabel,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    modeLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.textStyle.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.24,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              '主题',
              style: theme.textTheme.textStyle.copyWith(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: tokens.colors.accent,
                letterSpacing: -0.16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
