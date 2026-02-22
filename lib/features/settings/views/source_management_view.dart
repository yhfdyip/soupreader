import 'package:flutter/cupertino.dart';

import '../../../app/widgets/app_cupertino_page_scaffold.dart';
import '../../reader/views/speak_engine_manage_view.dart';
import '../../rss/views/rss_source_manage_view.dart';
import '../../source/views/source_list_view.dart';
import 'settings_placeholders.dart';
import 'settings_ui_tokens.dart';
import 'text_rules_settings_view.dart';

class SourceManagementView extends StatelessWidget {
  const SourceManagementView({super.key});

  @override
  Widget build(BuildContext context) {
    return AppCupertinoPageScaffold(
      title: '源管理',
      child: ListView(
        padding: const EdgeInsets.only(top: 8, bottom: 20),
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
                additionalInfo: const Text('搜索/分组/启停'),
                trailing: const CupertinoListTileChevron(),
                onTap: () {
                  Navigator.of(context).push(
                    CupertinoPageRoute<void>(
                      builder: (context) => const RssSourceManageView(),
                    ),
                  );
                },
              ),
              CupertinoListTile.notched(
                title: const Text('语音管理'),
                additionalInfo: const Text('系统/HTTP 引擎'),
                trailing: const CupertinoListTileChevron(),
                onTap: () {
                  Navigator.of(context).push(
                    CupertinoPageRoute<void>(
                      builder: (context) => const SpeakEngineManageView(),
                    ),
                  );
                },
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
                additionalInfo: const Text(
                  SettingsUiTokens.plannedLabel,
                  style: TextStyle(color: CupertinoColors.secondaryLabel),
                ),
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
