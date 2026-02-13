import 'package:flutter/cupertino.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../app/widgets/app_cupertino_page_scaffold.dart';
import '../../../core/services/settings_service.dart';
import '../../reader/models/reading_settings.dart';
import 'reading_behavior_settings_hub_view.dart';
import 'reading_interface_settings_hub_view.dart';

class GlobalReadingSettingsView extends StatefulWidget {
  const GlobalReadingSettingsView({super.key});

  @override
  State<GlobalReadingSettingsView> createState() =>
      _GlobalReadingSettingsViewState();
}

class _GlobalReadingSettingsViewState extends State<GlobalReadingSettingsView> {
  final SettingsService _settingsService = SettingsService();

  Future<void> _openInterfaceHub() async {
    await Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (context) => const ReadingInterfaceSettingsHubView(),
      ),
    );
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _openBehaviorHub() async {
    await Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (context) => const ReadingBehaviorSettingsHubView(),
      ),
    );
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _resetDefaults() async {
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('恢复默认？'),
        content: const Text('\n将把“全局默认阅读设置”恢复为初始值。'),
        actions: [
          CupertinoDialogAction(
            child: const Text('取消'),
            onPressed: () => Navigator.pop(context, false),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: const Text('恢复'),
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await _settingsService.saveReadingSettings(const ReadingSettings());
    if (!mounted) return;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final scheme = theme.colorScheme;

    return AppCupertinoPageScaffold(
      title: '阅读（全局默认）',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
        children: [
          Text(
            '入口与阅读页保持一致',
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
                  title: '界面（样式）',
                  info: '主题 / 字体 / 排版 / 翻页动画',
                  onTap: _openInterfaceHub,
                ),
                const ShadSeparator.horizontal(
                  margin: EdgeInsets.symmetric(horizontal: 12),
                ),
                _buildItem(
                  title: '设置（行为）',
                  info: '翻页 / 点击 / 状态栏 / 其他',
                  onTap: _openBehaviorHub,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(
            '高级',
            style: theme.textTheme.small.copyWith(
              color: scheme.mutedForeground,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          ShadCard(
            padding: EdgeInsets.zero,
            child: _buildItem(
              title: '恢复默认阅读设置',
              info: '重置全部全局默认项',
              onTap: _resetDefaults,
              destructive: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItem({
    required String title,
    required String info,
    required VoidCallback onTap,
    bool destructive = false,
  }) {
    final theme = ShadTheme.of(context);
    final scheme = theme.colorScheme;
    final titleColor = destructive ? scheme.destructive : scheme.foreground;
    final infoText = info.trim();

    return ShadButton.ghost(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      mainAxisAlignment: MainAxisAlignment.start,
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
                  style: theme.textTheme.p.copyWith(color: titleColor),
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
    );
  }
}
