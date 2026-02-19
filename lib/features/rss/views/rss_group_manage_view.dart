import 'package:flutter/cupertino.dart';

import '../../../app/widgets/app_cupertino_page_scaffold.dart';
import '../../../core/database/database_service.dart';
import '../../../core/database/repositories/rss_source_repository.dart';
import '../services/rss_source_manage_helper.dart';

class RssGroupManageView extends StatefulWidget {
  const RssGroupManageView({
    super.key,
    this.repository,
  });

  final RssSourceRepository? repository;

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
    return AppCupertinoPageScaffold(
      title: '分组管理',
      trailing: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: _addGroup,
        child: const Icon(CupertinoIcons.add),
      ),
      child: StreamBuilder<List<String>>(
        stream: _repo.flowGroups(),
        builder: (context, snapshot) {
          final groups = snapshot.data ?? _repo.allGroups();
          if (groups.isEmpty) {
            return const Center(
              child: Text(
                '暂无分组',
                style: TextStyle(color: CupertinoColors.secondaryLabel),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.only(top: 12, bottom: 20),
            itemCount: groups.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final group = groups[index];
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: CupertinoColors.secondarySystemGroupedBackground
                      .resolveFrom(context),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: CupertinoListTile.notched(
                  title: Text(group),
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
                        child: const Icon(
                          CupertinoIcons.delete,
                          color: CupertinoColors.systemRed,
                          size: 18,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _addGroup() async {
    final group = await _showGroupInputDialog(title: '新增分组');
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
    final result = await showCupertinoDialog<String>(
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
