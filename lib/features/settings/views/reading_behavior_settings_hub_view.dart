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
                  info: '阈值 / 音量键 / 鼠标滚轮 / 长按按键',
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
                  title: '状态栏与操作',
                  info: '状态栏/导航栏 / 亮度条 / 点击动作',
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
                  info: '方向 / 返回键 / 常亮 / 繁简 / 净化标题',
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
    final infoText = info.trim();

    return SizedBox(
      width: double.infinity,
      child: CupertinoButton(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        alignment: Alignment.centerLeft,
        onPressed: onTap,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.p.copyWith(color: scheme.foreground),
                  ),
                  if (infoText.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      infoText,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.small.copyWith(
                        color: scheme.mutedForeground,
                      ),
                    ),
                  ],
                ],
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
      ),
    );
  }
}
