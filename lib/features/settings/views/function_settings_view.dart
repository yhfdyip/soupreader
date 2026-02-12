import 'package:flutter/cupertino.dart';

import '../../../app/widgets/app_cupertino_page_scaffold.dart';
import '../../bookshelf/views/reading_history_view.dart';
import 'backup_settings_view.dart';
import 'global_reading_settings_view.dart';
import 'other_settings_view.dart';
import 'settings_placeholders.dart';

class FunctionSettingsView extends StatelessWidget {
  const FunctionSettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    return AppCupertinoPageScaffold(
      title: '功能 & 设置',
      child: ListView(
        children: [
          CupertinoListSection.insetGrouped(
            header: const Text('核心'),
            children: [
              CupertinoListTile.notched(
                title: const Text('备份/同步'),
                additionalInfo: const Text('导入/导出'),
                trailing: const CupertinoListTileChevron(),
                onTap: () => Navigator.of(context).push(
                  CupertinoPageRoute<void>(
                    builder: (context) => const BackupSettingsView(),
                  ),
                ),
              ),
              CupertinoListTile.notched(
                title: const Text('阅读设置'),
                additionalInfo: const Text('全局默认'),
                trailing: const CupertinoListTileChevron(),
                onTap: () => Navigator.of(context).push(
                  CupertinoPageRoute<void>(
                    builder: (context) => const GlobalReadingSettingsView(),
                  ),
                ),
              ),
              CupertinoListTile.notched(
                title: const Text('阅读记录'),
                additionalInfo: const Text('历史列表'),
                trailing: const CupertinoListTileChevron(),
                onTap: () => Navigator.of(context).push(
                  CupertinoPageRoute<void>(
                    builder: (context) => const ReadingHistoryView(),
                  ),
                ),
              ),
              CupertinoListTile.notched(
                title: const Text('隔空阅读'),
                additionalInfo: const Text('暂未实现'),
                trailing: const CupertinoListTileChevron(),
                onTap: () => SettingsPlaceholders.showNotImplemented(
                  context,
                  title: '隔空阅读（接力/Handoff）暂未实现',
                ),
              ),
            ],
          ),
          CupertinoListSection.insetGrouped(
            header: const Text('更多'),
            children: [
              CupertinoListTile.notched(
                title: const Text('其它设置'),
                additionalInfo: const Text('详细配置'),
                trailing: const CupertinoListTileChevron(),
                onTap: () => Navigator.of(context).push(
                  CupertinoPageRoute<void>(
                    builder: (context) => const OtherSettingsView(),
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
}
