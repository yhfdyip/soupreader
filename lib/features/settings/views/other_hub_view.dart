import 'package:flutter/cupertino.dart';

import '../../../app/widgets/app_cupertino_page_scaffold.dart';
import 'about_settings_view.dart';
import 'settings_placeholders.dart';
import 'settings_ui_tokens.dart';

class OtherHubView extends StatelessWidget {
  const OtherHubView({super.key});

  @override
  Widget build(BuildContext context) {
    return AppCupertinoPageScaffold(
      title: '其它',
      child: ListView(
        padding: const EdgeInsets.only(top: 8, bottom: 20),
        children: [
          CupertinoListSection.insetGrouped(
            header: const Text('其它'),
            children: [
              CupertinoListTile.notched(
                title: const Text('分享'),
                additionalInfo: const Text(
                  SettingsUiTokens.plannedLabel,
                  style: TextStyle(color: CupertinoColors.secondaryLabel),
                ),
                trailing: const CupertinoListTileChevron(),
                onTap: () => SettingsPlaceholders.showNotImplemented(
                  context,
                  title: '分享暂未实现（可考虑接入 share_plus）',
                ),
              ),
              CupertinoListTile.notched(
                title: const Text('好评支持'),
                additionalInfo: const Text(
                  SettingsUiTokens.plannedLabel,
                  style: TextStyle(color: CupertinoColors.secondaryLabel),
                ),
                trailing: const CupertinoListTileChevron(),
                onTap: () => SettingsPlaceholders.showNotImplemented(
                  context,
                  title: '好评支持暂未实现',
                ),
              ),
              CupertinoListTile.notched(
                title: const Text('关于我们'),
                trailing: const CupertinoListTileChevron(),
                onTap: () => Navigator.of(context).push(
                  CupertinoPageRoute<void>(
                    builder: (context) => const AboutSettingsView(),
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
