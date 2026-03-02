import 'package:flutter/cupertino.dart';

import '../../../app/widgets/app_cupertino_page_scaffold.dart';
import '../../../app/widgets/app_ui_kit.dart';
import '../../../core/config/migration_exclusions.dart';
import '../../reader/views/speak_engine_manage_view.dart';
import '../../reader/views/txt_toc_rule_manage_view.dart';
import '../../rss/views/rss_source_manage_view.dart';
import '../../source/views/source_list_view.dart';
import 'settings_placeholders.dart';
import 'settings_ui_tokens.dart';
import 'text_rules_settings_view.dart';

class SourceManagementView extends StatelessWidget {
  const SourceManagementView({super.key});

  @override
  Widget build(BuildContext context) {
    final showRssManagement = !MigrationExclusions.excludeRss;
    final showSpeakManagement = !MigrationExclusions.excludeTts;
    return AppCupertinoPageScaffold(
      title: '源管理',
      child: AppListView(
        children: [
          AppListSection(
            header: const Text('管理'),
            hasLeading: false,
            children: [
              AppListTile(
                title: const Text('书源管理'),
                additionalInfo: const Text('导入/导出/启用'),
                onTap: () {
                  Navigator.of(context).push(
                    CupertinoPageRoute<void>(
                      builder: (context) => const SourceListView(),
                    ),
                  );
                },
              ),
              if (showRssManagement)
                AppListTile(
                  title: const Text('订阅管理'),
                  additionalInfo: const Text('搜索/分组/启停'),
                  onTap: () {
                    Navigator.of(context).push(
                      CupertinoPageRoute<void>(
                        builder: (context) => const RssSourceManageView(),
                      ),
                    );
                  },
                ),
              if (showSpeakManagement)
                AppListTile(
                  title: const Text('语音管理'),
                  additionalInfo: const Text('系统/HTTP 引擎'),
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
          AppListSection(
            header: const Text('规则'),
            hasLeading: false,
            children: [
              AppListTile(
                title: const Text('替换净化'),
                additionalInfo: const Text('净化/繁简'),
                onTap: () {
                  Navigator.of(context).push(
                    CupertinoPageRoute<void>(
                      builder: (context) => const TextRulesSettingsView(),
                    ),
                  );
                },
              ),
              AppListTile(
                title: const Text('目录规则'),
                additionalInfo: const Text('书源编辑'),
                onTap: () {
                  Navigator.of(context).push(
                    CupertinoPageRoute<void>(
                      builder: (context) => const TxtTocRuleManageView(),
                    ),
                  );
                },
              ),
              AppListTile(
                title: const Text('广告屏蔽'),
                additionalInfo: Text(
                  SettingsUiTokens.plannedLabel,
                  style: TextStyle(
                    color: CupertinoColors.secondaryLabel.resolveFrom(context),
                  ),
                ),
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
