import 'package:flutter/cupertino.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../app/widgets/app_cupertino_page_scaffold.dart';
import '../models/search_scope.dart';
import '../models/search_scope_group_helper.dart';
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
  final TextEditingController _queryController = TextEditingController();
  late _SearchScopeMode _mode;
  late final List<BookSource> _sources;
  late final List<String> _groups;
  final Set<String> _selectedGroups = <String>{};
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
    final query = _queryController.text.trim().toLowerCase();
    if (query.isEmpty) return _sources;
    return _sources.where((source) {
      final name = source.bookSourceName.toLowerCase();
      final url = source.bookSourceUrl.toLowerCase();
      final group = (source.bookSourceGroup ?? '').toLowerCase();
      return name.contains(query) ||
          url.contains(query) ||
          group.contains(query);
    }).toList(growable: false);
  }

  List<String> get _orderedSelectedGroups {
    return _groups.where((group) => _selectedGroups.contains(group)).toList();
  }

  void _toggleGroup(String group) {
    setState(() {
      if (_selectedGroups.contains(group)) {
        _selectedGroups.remove(group);
      } else {
        _selectedGroups.add(group);
      }
    });
  }

  void _toggleSource(BookSource source) {
    setState(() {
      if (_selectedSource?.bookSourceUrl == source.bookSourceUrl) {
        _selectedSource = null;
      } else {
        _selectedSource = source;
      }
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
    final theme = ShadTheme.of(context);
    final scheme = theme.colorScheme;

    return AppCupertinoPageScaffold(
      title: '搜索范围',
      trailing: CupertinoButton(
        padding: EdgeInsets.zero,
        minimumSize: const Size(30, 30),
        onPressed: _submit,
        child: const Text('确定'),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
            child: CupertinoSlidingSegmentedControl<_SearchScopeMode>(
              groupValue: _mode,
              children: const {
                _SearchScopeMode.group: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  child: Text('分组'),
                ),
                _SearchScopeMode.source: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  child: Text('书源'),
                ),
              },
              onValueChanged: (value) {
                if (value == null) return;
                setState(() => _mode = value);
              },
            ),
          ),
          if (_mode == _SearchScopeMode.source)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: ShadInput(
                controller: _queryController,
                placeholder: const Text('筛选书源'),
                leading: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(LucideIcons.search, size: 16),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                Text(
                  _mode == _SearchScopeMode.group
                      ? '已选 ${_selectedGroups.length}/${_groups.length} 分组'
                      : (_selectedSource == null
                          ? '未选书源'
                          : '已选：${_selectedSource!.bookSourceName}'),
                  style: theme.textTheme.small.copyWith(
                    color: scheme.mutedForeground,
                  ),
                ),
                const Spacer(),
                if (_mode == _SearchScopeMode.group)
                  ShadButton.link(
                    onPressed: _selectedGroups.isEmpty
                        ? null
                        : () => setState(_selectedGroups.clear),
                    child: const Text('清空分组'),
                  )
                else
                  ShadButton.link(
                    onPressed: _selectedSource == null
                        ? null
                        : () => setState(() => _selectedSource = null),
                    child: const Text('清空书源'),
                  ),
              ],
            ),
          ),
          Expanded(
            child: _mode == _SearchScopeMode.group
                ? _buildGroupList(theme, scheme)
                : _buildSourceList(theme, scheme),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: scheme.border, width: 1),
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
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupList(ShadThemeData theme, ShadColorScheme scheme) {
    if (_groups.isEmpty) {
      return Center(
        child: Text(
          '没有可选分组',
          style: theme.textTheme.muted.copyWith(
            color: scheme.mutedForeground,
          ),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      itemCount: _groups.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final group = _groups[index];
        final selected = _selectedGroups.contains(group);
        return GestureDetector(
          key: ValueKey('group-$group'),
          onTap: () => _toggleGroup(group),
          child: ShadCard(
            padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    group,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.p.copyWith(
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
                  color: selected ? scheme.primary : scheme.mutedForeground,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSourceList(ShadThemeData theme, ShadColorScheme scheme) {
    final filtered = _filteredSources;
    if (filtered.isEmpty) {
      return Center(
        child: Text(
          '未找到匹配书源',
          style: theme.textTheme.muted.copyWith(
            color: scheme.mutedForeground,
          ),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      itemCount: filtered.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final source = filtered[index];
        final selected = _selectedSource?.bookSourceUrl == source.bookSourceUrl;
        return GestureDetector(
          key: ValueKey(source.bookSourceUrl),
          onTap: () => _toggleSource(source),
          child: ShadCard(
            padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        source.bookSourceName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.p.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        source.bookSourceUrl,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.small.copyWith(
                          color: scheme.mutedForeground,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Icon(
                  selected
                      ? CupertinoIcons.check_mark_circled_solid
                      : CupertinoIcons.circle,
                  size: 20,
                  color: selected ? scheme.primary : scheme.mutedForeground,
                ),
              ],
            ),
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
