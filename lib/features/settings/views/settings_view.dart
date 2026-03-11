import 'package:flutter/foundation.dart';
import 'package:flutter/cupertino.dart';

import '../../../app/widgets/app_nav_bar_button.dart';
import '../../../app/widgets/cupertino_bottom_dialog.dart';
import 'package:flutter/services.dart';

import '../../../app/theme/design_tokens.dart';
import '../../../app/theme/ui_tokens.dart';
import '../../../app/widgets/app_cupertino_page_scaffold.dart';
import '../../../app/widgets/app_ui_kit.dart';
import '../../../app/widgets/option_picker_sheet.dart';
import '../../../core/config/migration_exclusions.dart';
import '../../../core/models/app_settings.dart';
import '../../../core/services/settings_service.dart';
import '../../bookshelf/views/reading_history_view.dart';
import '../../reader/views/all_bookmark_view.dart';
import '../../reader/views/dict_rule_manage_view.dart';
import '../../reader/views/txt_toc_rule_manage_view.dart';
import '../../replace/views/replace_rule_list_view.dart';
import '../../source/views/source_list_view.dart';
import 'about_settings_view.dart';
import 'app_help_dialog.dart';
import 'backup_settings_view.dart';
import 'file_manage_view.dart';
import 'other_settings_view.dart';
import 'settings_placeholders.dart';
import 'settings_profile_card.dart';
import 'theme_settings_view.dart';

/// 我的页菜单（按 legado `pref_main.xml` 入口顺序迁移）
class SettingsView extends StatefulWidget {
  const SettingsView({
    super.key,
    this.reselectSignal,
  });

  final ValueListenable<int>? reselectSignal;

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  final SettingsService _settingsService = SettingsService();
  final ScrollController _sliverScrollController = ScrollController();
  bool _loadingMyHelp = false;
  int? _lastReselectVersion;

  @override
  void initState() {
    super.initState();
    _settingsService.appSettingsListenable.addListener(_onAppSettingsChanged);
    _bindReselectSignal(widget.reselectSignal);
  }

  @override
  void didUpdateWidget(covariant SettingsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reselectSignal == widget.reselectSignal) return;
    _unbindReselectSignal(oldWidget.reselectSignal);
    _bindReselectSignal(widget.reselectSignal);
  }

  @override
  void dispose() {
    _unbindReselectSignal(widget.reselectSignal);
    _settingsService.appSettingsListenable
        .removeListener(_onAppSettingsChanged);
    _sliverScrollController.dispose();
    super.dispose();
  }

  void _onAppSettingsChanged() {
    if (!mounted) return;
    setState(() {});
  }

  void _bindReselectSignal(ValueListenable<int>? signal) {
    _lastReselectVersion = signal?.value;
    signal?.addListener(_onReselectSignalChanged);
  }

  void _unbindReselectSignal(ValueListenable<int>? signal) {
    signal?.removeListener(_onReselectSignalChanged);
  }

  void _onReselectSignalChanged() {
    final signal = widget.reselectSignal;
    if (signal == null) return;
    final version = signal.value;
    if (_lastReselectVersion == version) return;
    _lastReselectVersion = version;
    _scrollToTop();
  }

  void _scrollToTop() {
    if (!_sliverScrollController.hasClients) return;
    _sliverScrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  String get _themeModeSummary {
    final app = _settingsService.appSettingsListenable.value;
    switch (app.appearanceMode) {
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

  Future<void> _pickThemeMode() async {
    final current = _settingsService.appSettingsListenable.value.appearanceMode;
    final selected = await showOptionPickerSheet<AppAppearanceMode>(
      context: context,
      title: '主题模式',
      currentValue: current,
      accentColor: AppDesignTokens.brandPrimary,
      items: const [
        OptionPickerItem<AppAppearanceMode>(
          value: AppAppearanceMode.followSystem,
          label: '跟随系统',
        ),
        OptionPickerItem<AppAppearanceMode>(
          value: AppAppearanceMode.light,
          label: '浅色',
        ),
        OptionPickerItem<AppAppearanceMode>(
          value: AppAppearanceMode.dark,
          label: '深色',
        ),
        OptionPickerItem<AppAppearanceMode>(
          value: AppAppearanceMode.eInk,
          label: 'E-Ink',
        ),
      ],
    );
    if (selected == null || selected == current) return;
    final currentSettings = _settingsService.appSettingsListenable.value;
    await _settingsService.saveAppSettings(
      currentSettings.copyWith(appearanceMode: selected),
    );
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _openMyHelp() async {
    if (_loadingMyHelp) return;
    setState(() => _loadingMyHelp = true);
    try {
      final markdownText =
          await rootBundle.loadString('assets/web/help/md/appHelp.md');
      if (!mounted) return;
      await showAppHelpDialog(
        context,
        markdownText: markdownText,
      );
    } catch (error) {
      if (!mounted) return;
      await showCupertinoBottomDialog<void>(
        context: context,
        builder: (dialogContext) => CupertinoAlertDialog(
          title: const Text('帮助'),
          content: Text('帮助文档加载失败：$error'),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('关闭'),
            ),
          ],
        ),
      );
    } finally {
      if (!mounted) return;
      setState(() => _loadingMyHelp = false);
    }
  }

  Widget _buildHelpAction() {
    if (_loadingMyHelp) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 8),
        child: CupertinoActivityIndicator(radius: 9),
      );
    }
    return AppNavBarButton(
      onPressed: _openMyHelp,
      child: const Icon(CupertinoIcons.question_circle, size: 22),
    );
  }

  void _showWebServiceNotImplemented() {
    SettingsPlaceholders.showNotImplemented(
      context,
      title: 'Web服务不在本轮迁移范围',
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppCupertinoPageScaffold(
      title: '我的',
      useSliverNavigationBar: true,
      sliverScrollController: _sliverScrollController,
      trailing: _buildHelpAction(),
      child: const SizedBox.shrink(),
      sliverBodyBuilder: (_) => _buildBodySliver(context),
    );
  }

  Widget _buildBodySliver(BuildContext context) {
    final tokens = AppUiTokens.resolve(context);
    return SliverSafeArea(
      top: true,
      bottom: true,
      sliver: SliverToBoxAdapter(
        child: Padding(
          padding: tokens.spacings.pageListPadding.copyWith(bottom: 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: _buildProfileCard(context),
              ),
              const SizedBox(height: 8),
              AppListSection(
                children: [
                  AppListTile(
                    key: const Key('my_menu_bookSourceManage'),
                    leadingIcon: CupertinoIcons.book,
                    title: const Text('书源管理'),
                    subtitle: const Text('新建、导入、编辑或管理书源'),
                    onTap: () => _open(
                      context,
                      const SourceListView(),
                    ),
                  ),
                  AppListTile(
                    key: const Key('my_menu_txtTocRuleManage'),
                    leadingIcon: CupertinoIcons.doc_text,
                    title: const Text('TXT目录规则'),
                    subtitle: const Text('配置 TXT 目录规则'),
                    onTap: () => _open(
                      context,
                      const TxtTocRuleManageView(),
                    ),
                  ),
                  AppListTile(
                    key: const Key('my_menu_replaceManage'),
                    leadingIcon: CupertinoIcons.wand_stars,
                    title: const Text('替换净化'),
                    subtitle: const Text('配置替换净化规则'),
                    onTap: () => _open(
                      context,
                      const ReplaceRuleListView(),
                    ),
                  ),
                  AppListTile(
                    key: const Key('my_menu_dictRuleManage'),
                    leadingIcon: CupertinoIcons.dot_radiowaves_right,
                    title: const Text('字典规则'),
                    subtitle: const Text('配置字典规则'),
                    onTap: () => _open(
                      context,
                      const DictRuleManageView(),
                    ),
                  ),
                  AppListTile(
                    key: const Key('my_menu_themeMode'),
                    leadingIcon: CupertinoIcons.circle_lefthalf_fill,
                    title: const Text('主题模式'),
                    subtitle: const Text('选择主题模式'),
                    additionalInfo: Text(_themeModeSummary),
                    onTap: _pickThemeMode,
                  ),
                  if (!MigrationExclusions.excludeWebService)
                    AppListTile(
                      key: const Key('my_menu_webService'),
                      leadingIcon: CupertinoIcons.globe,
                      title: const Text('Web服务'),
                      trailing: CupertinoSwitch(
                        value: false,
                        onChanged: (_) => _showWebServiceNotImplemented(),
                      ),
                      onTap: _showWebServiceNotImplemented,
                    ),
                ],
              ),
              AppListSection(
                header: const Text('设置'),
                children: [
                  AppListTile(
                    key: const Key('my_menu_web_dav_setting'),
                    leadingIcon: CupertinoIcons.cloud_upload,
                    title: const Text('备份与恢复'),
                    subtitle: const Text('WebDav 设置/导入旧版本数据'),
                    onTap: () => _open(
                      context,
                      const BackupSettingsView(),
                    ),
                  ),
                  AppListTile(
                    key: const Key('my_menu_theme_setting'),
                    leadingIcon: CupertinoIcons.paintbrush,
                    title: const Text('主题设置'),
                    subtitle: const Text('与界面/颜色相关的一些设置'),
                    onTap: () => _open(
                      context,
                      const ThemeSettingsView(),
                    ),
                  ),
                  AppListTile(
                    key: const Key('my_menu_setting'),
                    leadingIcon: CupertinoIcons.gear,
                    title: const Text('其它设置'),
                    subtitle: const Text('与功能相关的一些设置'),
                    onTap: () => _open(
                      context,
                      const OtherSettingsView(),
                    ),
                  ),
                ],
              ),
              AppListSection(
                header: const Text('其他'),
                children: [
                  AppListTile(
                    key: const Key('my_menu_bookmark'),
                    leadingIcon: CupertinoIcons.bookmark,
                    title: const Text('书签'),
                    subtitle: const Text('所有书签'),
                    onTap: () => _open(
                      context,
                      const AllBookmarkView(),
                    ),
                  ),
                  AppListTile(
                    key: const Key('my_menu_readRecord'),
                    leadingIcon: CupertinoIcons.clock,
                    title: const Text('阅读记录'),
                    subtitle: const Text('阅读时间记录'),
                    onTap: () => _open(
                      context,
                      const ReadingHistoryView(),
                    ),
                  ),
                  AppListTile(
                    key: const Key('my_menu_fileManage'),
                    leadingIcon: CupertinoIcons.folder,
                    title: const Text('文件管理'),
                    subtitle: const Text('管理私有文件夹的文件'),
                    onTap: () => _open(
                      context,
                      const FileManageView(),
                    ),
                  ),
                  AppListTile(
                    key: const Key('my_menu_about'),
                    leadingIcon: CupertinoIcons.info_circle,
                    title: const Text('关于'),
                    onTap: () => _open(
                      context,
                      const AboutSettingsView(),
                    ),
                  ),
                  AppListTile(
                    key: const Key('my_menu_exit'),
                    leadingIcon: CupertinoIcons.arrow_right_circle,
                    title: const Text('退出'),
                    onTap: () => SystemNavigator.pop(),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileCard(BuildContext context) {
    final appSettings = _settingsService.appSettingsListenable.value;
    return SettingsProfileCard(
      appearanceMode: appSettings.appearanceMode,
      modeLabel: _themeModeSummary,
    );
  }

  Future<void> _open(BuildContext context, Widget page) async {
    await Navigator.of(context).push(
      CupertinoPageRoute<void>(builder: (_) => page),
    );
  }
}
