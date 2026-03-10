// ignore_for_file: invalid_use_of_protected_member
part of 'source_list_view.dart';

class _SourceSortSheet extends StatefulWidget {
  static const double _radius = 18;
  static const double _handleWidth = 36;
  static const double _handleHeight = 4;
  static const List<_SourceSortMode> _modeOrder = [
    _SourceSortMode.name,
    _SourceSortMode.url,
    _SourceSortMode.update,
    _SourceSortMode.weight,
    _SourceSortMode.respond,
    _SourceSortMode.enabled,
    _SourceSortMode.manual,
  ];

  final _SourceSortMode mode;
  final bool ascending;
  final _SourceSortModeLabelBuilder modeLabelBuilder;
  final _SourceSortChanged onChanged;

  const _SourceSortSheet({
    required this.mode,
    required this.ascending,
    required this.modeLabelBuilder,
    required this.onChanged,
  });

  @override
  State<_SourceSortSheet> createState() => _SourceSortSheetState();
}

class _SourceSortSheetState extends State<_SourceSortSheet> {
  late _SourceSortMode _mode;
  late bool _ascending;

  @override
  void initState() {
    super.initState();
    _mode = widget.mode;
    _ascending = widget.ascending;
  }

  void _update({
    _SourceSortMode? mode,
    bool? ascending,
  }) {
    setState(() {
      if (mode != null) _mode = mode;
      if (ascending != null) _ascending = ascending;
    });
    widget.onChanged(_mode, _ascending);
  }

  @override
  Widget build(BuildContext context) {
    final sheetBg =
        CupertinoColors.systemGroupedBackground.resolveFrom(context);
    final titleColor = CupertinoColors.label.resolveFrom(context);
    final handleColor = CupertinoColors.separator.resolveFrom(context);
    final mediaQuery = MediaQuery.of(context);
    final bottomInset = math.max(mediaQuery.padding.bottom, 8.0);

    return SafeArea(
      top: false,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: sheetBg,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(_SourceSortSheet._radius),
          ),
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(0, 10, 0, bottomInset),
          child: ListView(
            shrinkWrap: true,
            physics: const BouncingScrollPhysics(),
            children: [
              _buildHeader(handleColor: handleColor, titleColor: titleColor),
              AppListSection(
                header: const Text('类型'),
                hasLeading: false,
                children: [
                  for (final mode in _SourceSortSheet._modeOrder)
                    _buildOptionRow(
                      title: widget.modeLabelBuilder(mode),
                      selected: _mode == mode,
                      onTap: () => _update(mode: mode),
                    ),
                ],
              ),
              AppListSection(
                header: const Text('顺序'),
                hasLeading: false,
                children: [
                  _buildOptionRow(
                    title: '升序',
                    selected: _ascending,
                    onTap: () => _update(ascending: true),
                  ),
                  _buildOptionRow(
                    title: '降序',
                    selected: !_ascending,
                    onTap: () => _update(ascending: false),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader({
    required Color handleColor,
    required Color titleColor,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: _SourceSortSheet._handleWidth,
          height: _SourceSortSheet._handleHeight,
          decoration: BoxDecoration(
            color: handleColor,
            borderRadius: BorderRadius.circular(999),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
          child: Text(
            '排序',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: titleColor,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOptionRow({
    required String title,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final accent = CupertinoTheme.of(context).primaryColor;
    return AppListTile(
      title: Text(
        title,
        style: TextStyle(
          color: selected ? accent : CupertinoColors.label.resolveFrom(context),
          fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
        ),
      ),
      trailing: selected
          ? Icon(CupertinoIcons.check_mark, size: 18, color: accent)
          : null,
      onTap: onTap,
      showChevron: false,
    );
  }
}

typedef _SourceGroupManageCallback = void Function(BuildContext sheetContext);
typedef _SourceGroupToggleCallback = void Function(BuildContext sheetContext);
typedef _SourceGroupApplyQueryCallback = void Function(
  String query,
  BuildContext sheetContext,
);

class _SourceGroupFilterSheet extends StatelessWidget {
  static const double _radius = 18;
  static const double _handleWidth = 36;
  static const double _handleHeight = 4;

  final List<String> groups;
  final bool groupSourcesByDomain;
  final _SourceGroupManageCallback onOpenGroupManage;
  final _SourceGroupToggleCallback onToggleGroupByDomain;
  final _SourceGroupApplyQueryCallback onApplyQuery;

  const _SourceGroupFilterSheet({
    required this.groups,
    required this.groupSourcesByDomain,
    required this.onOpenGroupManage,
    required this.onToggleGroupByDomain,
    required this.onApplyQuery,
  });

  @override
  Widget build(BuildContext context) {
    final sheetBg =
        CupertinoColors.systemGroupedBackground.resolveFrom(context);
    final titleColor = CupertinoColors.label.resolveFrom(context);
    final handleColor = CupertinoColors.separator.resolveFrom(context);
    final mediaQuery = MediaQuery.of(context);
    final bottomInset = math.max(mediaQuery.padding.bottom, 8.0);

    final children = <Widget>[
      _buildHeader(handleColor: handleColor, titleColor: titleColor),
      _buildManageSection(context),
      _buildPresetFiltersSection(context),
      if (groups.isNotEmpty) _buildGroupsSection(context),
      _buildCancelSection(context),
    ];
    return _buildFrame(
      context,
      sheetBg: sheetBg,
      bottomInset: bottomInset,
      children: children,
    );
  }

  Widget _buildFrame(
    BuildContext context, {
    required Color sheetBg,
    required double bottomInset,
    required List<Widget> children,
  }) {
    return SafeArea(
      top: false,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: sheetBg,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(_radius)),
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(0, 10, 0, bottomInset),
          child: ListView(
            shrinkWrap: true,
            physics: const BouncingScrollPhysics(),
            children: children,
          ),
        ),
      ),
    );
  }

  Widget _buildManageSection(BuildContext context) {
    return AppListSection(
      hasLeading: false,
      children: [
        AppListTile(
          title: const Text('分组管理'),
          onTap: () => onOpenGroupManage(context),
        ),
        _buildCheckRow(
          context: context,
          title: '按域名分组显示',
          selected: groupSourcesByDomain,
          onTap: () => onToggleGroupByDomain(context),
        ),
      ],
    );
  }

  Widget _buildPresetFiltersSection(BuildContext context) {
    return AppListSection(
      hasLeading: false,
      children: [
        _buildActionRow(
            title: '已启用', onTap: () => onApplyQuery('已启用', context)),
        _buildActionRow(
            title: '已禁用', onTap: () => onApplyQuery('已禁用', context)),
        _buildActionRow(
            title: '需要登录', onTap: () => onApplyQuery('需要登录', context)),
        _buildActionRow(
            title: '未分组', onTap: () => onApplyQuery('未分组', context)),
        _buildActionRow(
            title: '已启用发现', onTap: () => onApplyQuery('已启用发现', context)),
        _buildActionRow(
            title: '已禁用发现', onTap: () => onApplyQuery('已禁用发现', context)),
      ],
    );
  }

  Widget _buildGroupsSection(BuildContext context) {
    return AppListSection(
      header: const Text('分组'),
      hasLeading: false,
      children: [
        for (final group in groups)
          _buildActionRow(
            title: group,
            onTap: () => onApplyQuery('group:$group', context),
          ),
      ],
    );
  }

  Widget _buildCancelSection(BuildContext context) {
    return AppListSection(
      hasLeading: false,
      children: [
        AppListTile(
          title: const Text('取消'),
          onTap: () => Navigator.of(context).pop(),
          showChevron: false,
        ),
      ],
    );
  }

  Widget _buildHeader({
    required Color handleColor,
    required Color titleColor,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: _handleWidth,
          height: _handleHeight,
          decoration: BoxDecoration(
            color: handleColor,
            borderRadius: BorderRadius.circular(999),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
          child: Text(
            '分组',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: titleColor,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionRow({
    required String title,
    required VoidCallback onTap,
  }) {
    return AppListTile(
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      onTap: onTap,
      showChevron: false,
    );
  }

  Widget _buildCheckRow({
    required BuildContext context,
    required String title,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final accent = CupertinoTheme.of(context).primaryColor;
    return AppListTile(
      title: Text(
        title,
        style: TextStyle(
          color: selected ? accent : CupertinoColors.label.resolveFrom(context),
          fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
        ),
      ),
      trailing: selected
          ? Icon(CupertinoIcons.check_mark, size: 18, color: accent)
          : null,
      onTap: onTap,
      showChevron: false,
    );
  }
}
