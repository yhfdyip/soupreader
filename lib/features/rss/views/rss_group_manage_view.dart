import 'package:flutter/cupertino.dart';

import '../../../app/theme/ui_tokens.dart';
import '../../../app/widgets/cupertino_bottom_dialog.dart';

import '../../../app/widgets/app_cupertino_page_scaffold.dart';
import '../../../app/widgets/app_empty_state.dart';
import '../../../app/widgets/app_nav_bar_button.dart';
import '../../../app/widgets/app_ui_kit.dart';
import '../../../core/database/database_service.dart';
import '../../../core/database/repositories/rss_source_repository.dart';
import '../services/rss_source_manage_helper.dart';

class RssGroupManageView extends StatefulWidget {
  const RssGroupManageView({
    super.key,
    this.repository,
    this.embedded = false,
  });

  final RssSourceRepository? repository;
  final bool embedded;

  @override
  State<RssGroupManageView> createState() => _RssGroupManageViewState();
}

class _RssGroupManageViewState extends State<RssGroupManageView> {
  late final RssSourceRepository _repo;

  @override
  void initState() {
    super.initState();
    _repo = widget.repository ?? RssSourceRepository(DatabaseService());
  }

  @override
  Widget build(BuildContext context) {
    if (widget.embedded) {
      return _buildEmbeddedView(context);
    }
    return AppCupertinoPageScaffold(
      title: '分组管理',
      trailing: AppNavBarButton(
        onPressed: _addGroup,
        child: const Icon(CupertinoIcons.add, size: 22),
      ),
      child: _buildGroupList(),
    );
  }

  Widget _buildEmbeddedView(BuildContext context) {
    final separatorColor =
        AppUiTokens.resolve(context).colors.separator.withValues(alpha: 0.78);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  '分组管理',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              CupertinoButton(
                padding: EdgeInsets.zero,
                minimumSize: const Size(32, 32),
                onPressed: _addGroup,
                child: const Icon(CupertinoIcons.add_circled),
              ),
              CupertinoButton(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                minimumSize: const Size(40, 32),
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('完成'),
              ),
            ],
          ),
        ),
        Container(
          height: AppUiTokens.resolve(context).sizes.dividerThickness,
          color: separatorColor,
        ),
        Expanded(child: _buildGroupList()),
      ],
    );
  }

  Widget _buildGroupList() {
    return StreamBuilder<List<String>>(
      stream: _repo.flowGroups(),
      builder: (context, snapshot) {
        final groups = snapshot.data ?? _repo.allGroups();
        if (groups.isEmpty) {
          return const AppEmptyState(
            illustration: AppEmptyPlanetIllustration(size: 84),
            title: '暂无分组',
            message: '点击右上角加号添加分组',
          );
        }
        return AppListView(
          padding: const EdgeInsets.only(top: 12, bottom: 20),
          children: [
            AppListSection(
              hasLeading: false,
              children: groups.map(_buildGroupTile).toList(growable: false),
            ),
          ],
        );
      },
    );
  }

  Widget _buildGroupTile(String group) {
    return AppListTile(
      title: Text(group),
      showChevron: false,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CupertinoButton(
            padding: EdgeInsets.zero,
            minimumSize: const Size(28, 28),
            onPressed: () => _editGroup(group),
            child: const Icon(
              CupertinoIcons.pencil,
              size: 18,
            ),
          ),
          CupertinoButton(
            padding: EdgeInsets.zero,
            minimumSize: const Size(28, 28),
            onPressed: () => _removeGroup(group),
            child: Icon(
              CupertinoIcons.delete,
              color: CupertinoColors.systemRed.resolveFrom(context),
              size: 18,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _addGroup() async {
    final group = await _showGroupInputDialog(title: '添加分组');
    if (!mounted || group == null || group.isEmpty) return;
    final updates = RssSourceManageHelper.addGroupToNoGroupSources(
      allSources: _repo.getAllSources(),
      group: group,
    );
    if (updates.isEmpty) return;
    await _repo.updateSources(updates);
  }

  Future<void> _editGroup(String oldGroup) async {
    final next = await _showGroupInputDialog(
      title: '重命名分组',
      initialValue: oldGroup,
    );
    if (!mounted || next == null) return;
    final updates = RssSourceManageHelper.renameGroup(
      allSources: _repo.getAllSources(),
      oldGroup: oldGroup,
      newGroup: next,
    );
    if (updates.isEmpty) return;
    await _repo.updateSources(updates);
  }

  Future<void> _removeGroup(String group) async {
    final updates = RssSourceManageHelper.removeGroup(
      allSources: _repo.getAllSources(),
      group: group,
    );
    if (updates.isEmpty) return;
    await _repo.updateSources(updates);
  }

  Future<String?> _showGroupInputDialog({
    required String title,
    String initialValue = '',
  }) async {
    final controller = TextEditingController(text: initialValue);
    final result = await showCupertinoBottomDialog<String>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(title),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: CupertinoTextField(
            controller: controller,
            placeholder: '分组名',
            autofocus: true,
          ),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            onPressed: () => Navigator.of(ctx).pop(controller.text),
            child: const Text('确定'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result?.trim();
  }
}
