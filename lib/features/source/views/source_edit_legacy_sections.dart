import 'package:flutter/cupertino.dart';

import '../../../app/widgets/app_ui_kit.dart';

class SourceEditLegacyTopSettingsSection extends StatelessWidget {
  const SourceEditLegacyTopSettingsSection({
    super.key,
    required this.bookSourceType,
    required this.typeLabelBuilder,
    required this.onPickBookSourceType,
    required this.enabled,
    required this.onEnabledChanged,
    required this.enabledExplore,
    required this.onEnabledExploreChanged,
    required this.enabledCookieJar,
    required this.onEnabledCookieJarChanged,
  });

  final int bookSourceType;
  final String Function(int type) typeLabelBuilder;
  final Future<void> Function() onPickBookSourceType;
  final bool enabled;
  final ValueChanged<bool> onEnabledChanged;
  final bool enabledExplore;
  final ValueChanged<bool> onEnabledExploreChanged;
  final bool enabledCookieJar;
  final ValueChanged<bool> onEnabledCookieJarChanged;

  @override
  Widget build(BuildContext context) {
    final accentColor = CupertinoTheme.of(context).primaryColor;
    return AppListSection(
      margin: const EdgeInsets.fromLTRB(12, 6, 12, 4),
      children: [
        AppListTile(
          title: const Text('书源类型'),
          additionalInfo: Text(
            typeLabelBuilder(bookSourceType),
            style: TextStyle(
              color: accentColor,
              fontWeight: FontWeight.w600,
            ),
          ),
          onTap: onPickBookSourceType,
        ),
        _TopSwitchTile(
          text: '启用书源',
          helper: '控制该书源是否参与搜索与阅读流程',
          value: enabled,
          onChanged: onEnabledChanged,
        ),
        _TopSwitchTile(
          text: '启用发现',
          helper: '关闭后该书源不会在发现页显示',
          value: enabledExplore,
          onChanged: onEnabledExploreChanged,
        ),
        _TopSwitchTile(
          text: '自动保存 Cookie',
          helper: '请求命中登录态时自动更新 Cookie',
          value: enabledCookieJar,
          onChanged: onEnabledCookieJarChanged,
        ),
      ],
    );
  }
}

class SourceEditLegacyTabSwitcher extends StatelessWidget {
  const SourceEditLegacyTabSwitcher({
    super.key,
    required this.tab,
    required this.onTabChanged,
  });

  final int tab;
  final ValueChanged<int> onTabChanged;

  static const Map<int, Widget> _items = <int, Widget>{
    0: Padding(
      padding: EdgeInsets.symmetric(horizontal: 8),
      child: Text('基础'),
    ),
    1: Padding(
      padding: EdgeInsets.symmetric(horizontal: 8),
      child: Text('搜索'),
    ),
    2: Padding(
      padding: EdgeInsets.symmetric(horizontal: 8),
      child: Text('发现'),
    ),
    3: Padding(
      padding: EdgeInsets.symmetric(horizontal: 8),
      child: Text('详情'),
    ),
    4: Padding(
      padding: EdgeInsets.symmetric(horizontal: 8),
      child: Text('目录'),
    ),
    5: Padding(
      padding: EdgeInsets.symmetric(horizontal: 8),
      child: Text('正文'),
    ),
  };

  @override
  Widget build(BuildContext context) {
    final borderColor = CupertinoColors.separator.resolveFrom(context);
    final sectionColor =
        CupertinoColors.secondarySystemGroupedBackground.resolveFrom(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 2, 12, 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: sectionColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: borderColor.withValues(alpha: 0.7),
            width: 0.6,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: CupertinoSlidingSegmentedControl<int>(
              groupValue: tab,
              children: _items,
              onValueChanged: (value) {
                if (value == null) return;
                onTabChanged(value);
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _TopSwitchTile extends StatelessWidget {
  const _TopSwitchTile({
    required this.text,
    required this.helper,
    required this.value,
    required this.onChanged,
  });

  final String text;
  final String helper;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final helperColor = CupertinoColors.tertiaryLabel.resolveFrom(context);
    return AppListTile(
      title: Text(text),
      subtitle: Text(
        helper,
        style: TextStyle(
          fontSize: 12,
          color: helperColor,
        ),
      ),
      trailing: CupertinoSwitch(
        value: value,
        onChanged: onChanged,
      ),
      showChevron: false,
      onTap: () => onChanged(!value),
    );
  }
}
