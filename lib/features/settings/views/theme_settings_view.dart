import 'package:flutter/cupertino.dart';

import '../../../app/theme/colors.dart';
import '../../../app/widgets/app_cupertino_page_scaffold.dart';
import '../../../core/models/app_settings.dart';
import '../../../core/services/settings_service.dart';
import 'appearance_settings_view.dart';
import 'reading_theme_settings_view.dart';
import 'settings_placeholders.dart';
import 'settings_ui_tokens.dart';

class ThemeSettingsView extends StatelessWidget {
  const ThemeSettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    final settingsService = SettingsService();
    final readingSettings = settingsService.readingSettings;
    final themeIndex = readingSettings.themeIndex;
    final readingThemeName =
        (themeIndex >= 0 && themeIndex < AppColors.readingThemes.length)
            ? AppColors.readingThemes[themeIndex].name
            : AppColors.readingThemes.first.name;

    return AppCupertinoPageScaffold(
      title: '主题',
      child: ListView(
        padding: const EdgeInsets.only(top: 8, bottom: 20),
        children: [
          CupertinoListSection.insetGrouped(
            header: const Text('颜色主题'),
            children: [
              CupertinoListTile.notched(
                title: const Text('应用外观'),
                additionalInfo: Text(_appearanceSummary(settingsService)),
                trailing: const CupertinoListTileChevron(),
                onTap: () {
                  Navigator.of(context).push(
                    CupertinoPageRoute<void>(
                      builder: (context) => const AppearanceSettingsView(),
                    ),
                  );
                },
              ),
              CupertinoListTile.notched(
                title: const Text('阅读主题'),
                additionalInfo: Text(readingThemeName),
                trailing: const CupertinoListTileChevron(),
                onTap: () {
                  Navigator.of(context).push(
                    CupertinoPageRoute<void>(
                      builder: (context) => const ReadingThemeSettingsView(),
                    ),
                  );
                },
              ),
              CupertinoListTile.notched(
                title: const Text('白天/黑夜主题'),
                additionalInfo: _plannedInfo(),
                trailing: const CupertinoListTileChevron(),
                onTap: () => SettingsPlaceholders.showNotImplemented(
                  context,
                  title: '白天/黑夜主题（自动切换两套阅读主题）暂未实现',
                ),
              ),
            ],
          ),
          CupertinoListSection.insetGrouped(
            header: const Text('进阶'),
            children: [
              CupertinoListTile.notched(
                title: const Text('动态颜色/色差'),
                additionalInfo: _plannedInfo(),
                trailing: const CupertinoListTileChevron(),
                onTap: () => SettingsPlaceholders.showNotImplemented(
                  context,
                  title: '动态颜色/色差暂未实现',
                ),
              ),
              CupertinoListTile.notched(
                title: const Text('操作栏模糊'),
                additionalInfo: _plannedInfo(),
                trailing: const CupertinoListTileChevron(),
                onTap: () => SettingsPlaceholders.showNotImplemented(
                  context,
                  title: '操作栏模糊暂未实现',
                ),
              ),
              CupertinoListTile.notched(
                title: const Text('列表点击效果'),
                additionalInfo: _plannedInfo(),
                trailing: const CupertinoListTileChevron(),
                onTap: () => SettingsPlaceholders.showNotImplemented(
                  context,
                  title: '列表点击效果暂未实现',
                ),
              ),
              CupertinoListTile.notched(
                title: const Text('网页主题化'),
                additionalInfo: _plannedInfo(),
                trailing: const CupertinoListTileChevron(),
                onTap: () => SettingsPlaceholders.showNotImplemented(
                  context,
                  title: '网页主题化暂未实现',
                ),
              ),
              CupertinoListTile.notched(
                title: const Text('缩放'),
                additionalInfo: _plannedInfo(),
                trailing: const CupertinoListTileChevron(),
                onTap: () => SettingsPlaceholders.showNotImplemented(
                  context,
                  title: '界面缩放暂未实现',
                ),
              ),
              CupertinoListTile.notched(
                title: const Text('自定义图标'),
                additionalInfo: _plannedInfo(),
                trailing: const CupertinoListTileChevron(),
                onTap: () => SettingsPlaceholders.showNotImplemented(
                  context,
                  title: '自定义图标暂未实现',
                ),
              ),
              CupertinoListTile.notched(
                title: const Text('自定义颜色'),
                additionalInfo: _plannedInfo(),
                trailing: const CupertinoListTileChevron(),
                onTap: () => SettingsPlaceholders.showNotImplemented(
                  context,
                  title: '自定义颜色（主色/强调色/背景/文字等）暂未实现',
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  String _appearanceSummary(SettingsService service) {
    switch (service.appSettings.appearanceMode) {
      case AppAppearanceMode.followSystem:
        return '跟随系统';
      case AppAppearanceMode.light:
        return '浅色';
      case AppAppearanceMode.dark:
        return '深色';
    }
  }

  Widget _plannedInfo() {
    return const Text(
      SettingsUiTokens.plannedLabel,
      style: TextStyle(color: CupertinoColors.secondaryLabel),
    );
  }
}
