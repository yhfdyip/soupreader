import 'package:flutter/cupertino.dart';

import '../../../app/theme/ui_tokens.dart';
import '../../../app/widgets/app_cupertino_page_scaffold.dart';
import '../../../app/widgets/app_empty_state.dart';
import '../../../app/widgets/app_manage_search_field.dart';
import '../models/search_scope.dart';
import '../models/search_scope_group_helper.dart';
import '../services/search_scope_picker_helper.dart';
import '../../source/models/book_source.dart';

class SearchScopePickerView extends StatefulWidget {
  final List<BookSource> sources;
  final List<BookSource> enabledSources;

  const SearchScopePickerView({
    super.key,
    required this.sources,
    required this.enabledSources,
  });

  @override
  State<SearchScopePickerView> createState() => _SearchScopePickerViewState();
}

class _SearchScopePickerViewState extends State<SearchScopePickerView> {
  static const Key _menuScreenFieldKey = Key('search_scope_menu_screen_field');

  final TextEditingController _queryController = TextEditingController();
  late _SearchScopeMode _mode;
  late final List<BookSource> _sources;
  late final List<String> _groups;
  final List<String> _selectedGroups = <String>[];
  BookSource? _selectedSource;

  @override
  void initState() {
    super.initState();
    final indexed = widget.sources.asMap().entries.toList(growable: false)
      ..sort((a, b) {
        final orderCompare = a.value.customOrder.compareTo(b.value.customOrder);
        if (orderCompare != 0) {
          return orderCompare;
        }
        return a.key.compareTo(b.key);
      });
    _sources = indexed.map((entry) => entry.value).toList(growable: false);
    _groups = SearchScopeGroupHelper.enabledGroupsFromSources(
      widget.enabledSources,
    );
    _mode = _SearchScopeMode.group;
  }

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  List<BookSource> get _filteredSources {
    return SearchScopePickerHelper.filterSourcesByQuery(
      _sources,
      _queryController.text,
    );
  }

  List<String> get _orderedSelectedGroups {
    return SearchScopePickerHelper.orderedSelectedGroups(
        _selectedGroups, _groups);
  }

  void _toggleGroup(String group) {
    setState(() {
      SearchScopePickerHelper.toggleGroupSelection(_selectedGroups, group);
    });
  }

  void _toggleSource(BookSource source) {
    setState(() {
      _selectedSource = source;
    });
  }

  void _submit() {
    final scope = switch (_mode) {
      _SearchScopeMode.group => SearchScope.fromGroups(_orderedSelectedGroups),
      _SearchScopeMode.source =>
        _selectedSource == null ? '' : SearchScope.fromSource(_selectedSource!),
    };
    Navigator.of(context).pop(scope);
  }

  @override
  Widget build(BuildContext context) {
    final theme = CupertinoTheme.of(context);
    final uiTokens = AppUiTokens.resolve(context);

    return AppCupertinoPageScaffold(
      title: '搜索范围',
      trailing: _mode == _SearchScopeMode.source
          ? SizedBox(
              width: 168,
              child: AppManageSearchField(
                key: _menuScreenFieldKey,
                controller: _queryController,
                placeholder: '筛选',
                onChanged: (_) => setState(() {}),
              ),
            )
          : null,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
            child: SizedBox(
              width: double.infinity,
              child: CupertinoSlidingSegmentedControl<_SearchScopeMode>(
                groupValue: _mode,
                padding: const EdgeInsets.all(3),
                children: const {
                  _SearchScopeMode.group: Padding(
                    padding: EdgeInsets.symmetric(vertical: 7),
                    child: Text('分组', textAlign: TextAlign.center),
                  ),
                  _SearchScopeMode.source: Padding(
                    padding: EdgeInsets.symmetric(vertical: 7),
                    child: Text('书源', textAlign: TextAlign.center),
                  ),
                },
                onValueChanged: (value) {
                  if (value == null) return;
                  setState(() => _mode = value);
                },
              ),
            ),
          ),
          Expanded(
            child: _mode == _SearchScopeMode.group
                ? _buildGroupList(theme, uiTokens)
                : _buildSourceList(theme, uiTokens),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: uiTokens.colors.separator, width: 0.5),
              ),
            ),
            child: Row(
              children: [
                CupertinoButton(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  minimumSize: const Size(0, 34),
                  onPressed: () => Navigator.of(context).pop(''),
                  child: const Text('全部书源'),
                ),
                const Spacer(),
                CupertinoButton(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  minimumSize: const Size(0, 34),
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('取消'),
                ),
                CupertinoButton(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  minimumSize: const Size(0, 34),
                  onPressed: _submit,
                  child: const Text('确定'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScopeOptionTile({
    Key? key,
    required AppUiTokens uiTokens,
    required bool selected,
    required VoidCallback onPressed,
    required Widget child,
  }) {
    return CupertinoButton(
      key: key,
      padding: EdgeInsets.zero,
      minimumSize: uiTokens.sizes.compactTapSquare,
      pressedOpacity: 0.72,
      onPressed: onPressed,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
        decoration: BoxDecoration(
          color: selected
              ? uiTokens.colors.accent.withValues(alpha: 0.08)
              : uiTokens.colors.card,
          borderRadius: BorderRadius.circular(uiTokens.radii.control),
          border: Border.all(
            color: selected
                ? uiTokens.colors.accent.withValues(alpha: 0.42)
                : uiTokens.colors.separator.withValues(alpha: 0.72),
            width: 0.8,
          ),
        ),
        child: child,
      ),
    );
  }

  Widget _buildGroupList(CupertinoThemeData theme, AppUiTokens uiTokens) {
    if (_groups.isEmpty) {
      return const AppEmptyState(
        illustration: AppEmptyPlanetIllustration(size: 82),
        title: '没有可选分组',
        message: '当前启用书源中未配置可用分组',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      itemCount: _groups.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final group = _groups[index];
        final selected = _selectedGroups.contains(group);
        return _buildScopeOptionTile(
          key: ValueKey('group-$group'),
          uiTokens: uiTokens,
          selected: selected,
          onPressed: () => _toggleGroup(group),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  group,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.textStyle.copyWith(
                    color: uiTokens.colors.cardForeground,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Icon(
                selected
                    ? CupertinoIcons.check_mark_circled_solid
                    : CupertinoIcons.circle,
                size: 20,
                color: selected
                    ? uiTokens.colors.accent
                    : uiTokens.colors.mutedForeground,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSourceList(CupertinoThemeData theme, AppUiTokens uiTokens) {
    final filtered = _filteredSources;
    if (filtered.isEmpty) {
      return const AppEmptyState(
        illustration: AppEmptyPlanetIllustration(size: 82),
        title: '未找到匹配书源',
        message: '请尝试更换筛选关键字',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      itemCount: filtered.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final source = filtered[index];
        final selected = _selectedSource?.bookSourceUrl == source.bookSourceUrl;
        return _buildScopeOptionTile(
          key: ValueKey(source.bookSourceUrl),
          uiTokens: uiTokens,
          selected: selected,
          onPressed: () => _toggleSource(source),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  source.bookSourceName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.textStyle.copyWith(
                    color: uiTokens.colors.cardForeground,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Icon(
                selected
                    ? CupertinoIcons.check_mark_circled_solid
                    : CupertinoIcons.circle,
                size: 20,
                color: selected
                    ? uiTokens.colors.accent
                    : uiTokens.colors.mutedForeground,
              ),
            ],
          ),
        );
      },
    );
  }
}

enum _SearchScopeMode {
  group,
  source,
}
