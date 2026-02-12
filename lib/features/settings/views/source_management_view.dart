import 'package:flutter/cupertino.dart';

import '../../../app/widgets/app_cupertino_page_scaffold.dart';
import '../../source/views/source_list_view.dart';
import 'settings_placeholders.dart';
import 'text_rules_settings_view.dart';

class SourceManagementView extends StatelessWidget {
  const SourceManagementView({super.key});

  @override
  Widget build(BuildContext context) {
    return AppCupertinoPageScaffold(
      title: '源管理',
      child: ListView(
        children: [
          CupertinoListSection.insetGrouped(
            header: const Text('管理'),
            children: [
              CupertinoListTile.notched(
                title: const Text('书源管理'),
                additionalInfo: const Text('导入/导出/启用'),
                trailing: const CupertinoListTileChevron(),
                onTap: () {
                  Navigator.of(context).push(
                    CupertinoPageRoute<void>(
                      builder: (context) => const SourceListView(),
                    ),
                  );
                },
              ),
              CupertinoListTile.notched(
                title: const Text('订阅管理'),
                additionalInfo: const Text('暂未实现'),
                trailing: const CupertinoListTileChevron(),
                onTap: () => SettingsPlaceholders.showNotImplemented(
                  context,
                  title: '订阅管理暂未实现',
                ),
              ),
              CupertinoListTile.notched(
                title: const Text('语音管理'),
                additionalInfo: const Text('暂未实现'),
                trailing: const CupertinoListTileChevron(),
                onTap: () => SettingsPlaceholders.showNotImplemented(
                  context,
                  title: '语音管理（TTS）暂未实现',
                ),
              ),
            ],
          ),
          CupertinoListSection.insetGrouped(
            header: const Text('规则'),
            children: [
              CupertinoListTile.notched(
                title: const Text('替换净化'),
                additionalInfo: const Text('净化/繁简'),
                trailing: const CupertinoListTileChevron(),
                onTap: () {
                  Navigator.of(context).push(
                    CupertinoPageRoute<void>(
                      builder: (context) => const TextRulesSettingsView(),
                    ),
                  );
                },
              ),
              CupertinoListTile.notched(
                title: const Text('目录规则'),
                additionalInfo: const Text('书源编辑'),
                trailing: const CupertinoListTileChevron(),
                onTap: () {
                  Navigator.of(context).push(
                    CupertinoPageRoute<void>(
                      builder: (context) => const SourceListView(),
                    ),
                  );
                },
              ),
              CupertinoListTile.notched(
                title: const Text('广告屏蔽'),
                additionalInfo: const Text('暂未实现'),
                trailing: const CupertinoListTileChevron(),
                onTap: () => SettingsPlaceholders.showNotImplemented(
                  context,
                  title: '广告屏蔽规则暂未实现',
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
