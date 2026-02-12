import 'package:flutter/cupertino.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../app/widgets/app_cupertino_page_scaffold.dart';
import 'reading_other_settings_view.dart';
import 'reading_page_settings_view.dart';
import 'reading_status_action_settings_view.dart';

class ReadingBehaviorSettingsHubView extends StatelessWidget {
  const ReadingBehaviorSettingsHubView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final scheme = theme.colorScheme;

    return AppCupertinoPageScaffold(
      title: '设置（行为）',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        children: [
          Text(
            '阅读行为与操作',
            style: theme.textTheme.small.copyWith(
              color: scheme.mutedForeground,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          ShadCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _buildItem(
                  context,
                  title: '翻页与按键',
                  info: '灵敏度 / 音量键 / 净化标题',
                  onTap: () => Navigator.of(context).push(
                    CupertinoPageRoute<void>(
                      builder: (context) => const ReadingPageSettingsView(),
                    ),
                  ),
                ),
                const ShadSeparator.horizontal(
                  margin: EdgeInsets.symmetric(horizontal: 12),
                ),
                _buildItem(
                  context,
                  title: '状态栏与点击区域',
                  info: '状态栏显示 / 点击动作',
                  onTap: () => Navigator.of(context).push(
                    CupertinoPageRoute<void>(
                      builder: (context) =>
                          const ReadingStatusActionSettingsView(),
                    ),
                  ),
                ),
                const ShadSeparator.horizontal(
                  margin: EdgeInsets.symmetric(horizontal: 12),
                ),
                _buildItem(
                  context,
                  title: '其他阅读行为',
                  info: '自动阅读 / 常亮 / 繁简',
                  onTap: () => Navigator.of(context).push(
                    CupertinoPageRoute<void>(
                      builder: (context) => const ReadingOtherSettingsView(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItem(
    BuildContext context, {
    required String title,
    required String info,
    required VoidCallback onTap,
  }) {
    final theme = ShadTheme.of(context);
    final scheme = theme.colorScheme;

    return ShadButton.ghost(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      mainAxisAlignment: MainAxisAlignment.start,
      onPressed: onTap,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            info,
            style: theme.textTheme.small.copyWith(
              color: scheme.mutedForeground,
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            LucideIcons.chevronRight,
            size: 16,
            color: scheme.mutedForeground,
          ),
        ],
      ),
      child: Text(
        title,
        style: theme.textTheme.p.copyWith(color: scheme.foreground),
      ),
    );
  }
}
