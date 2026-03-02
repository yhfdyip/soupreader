import 'package:flutter/cupertino.dart';

import '../../../app/widgets/app_cupertino_page_scaffold.dart';
import '../../../app/widgets/app_nav_bar_button.dart';
import '../../../app/widgets/cupertino_bottom_dialog.dart';
import '../../../core/services/exception_log_service.dart';
import '../models/rule_subscription.dart';
import '../services/rule_subscription_store.dart';

class RuleSubscriptionView extends StatefulWidget {
  const RuleSubscriptionView({super.key});

  @override
  State<RuleSubscriptionView> createState() => _RuleSubscriptionViewState();
}

class _RuleSubscriptionViewState extends State<RuleSubscriptionView> {
  late final RuleSubscriptionStore _store;

  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _store = RuleSubscriptionStore();
    _bootstrap();
  }

  @override
  void dispose() {
    _store.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    try {
      await _store.init();
    } catch (error, stackTrace) {
      ExceptionLogService().record(
        node: 'RuleSubscriptionView.bootstrap',
        message: '规则订阅页初始化失败',
        error: error,
        stackTrace: stackTrace,
      );
    }
    if (!mounted) return;
    setState(() {
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AppCupertinoPageScaffold(
      title: '规则订阅',
      trailing: AppNavBarButton(
        onPressed: _addSubscription,
        child: const Icon(CupertinoIcons.add, size: 22),
      ),
      child: _loading
          ? const Center(child: CupertinoActivityIndicator())
          : ValueListenableBuilder<List<RuleSubscription>>(
              valueListenable: _store.listenable,
              builder: (context, subscriptions, _) {
                if (subscriptions.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        '新增大佬们提供的规则导入地址\n新增后点击可导入规则',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: CupertinoColors.secondaryLabel.resolveFrom(
                            context,
                          ),
                        ),
                      ),
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 20),
                  itemCount: subscriptions.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final subscription = subscriptions[index];
                    return _buildSubscriptionItem(subscription);
                  },
                );
              },
            ),
    );
  }

  Widget _buildSubscriptionItem(RuleSubscription subscription) {
    final typeText = _typeLabel(subscription.type);

    return Container(
      decoration: BoxDecoration(
        color: CupertinoColors.secondarySystemGroupedBackground
            .resolveFrom(context),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    subscription.name.trim().isEmpty
                        ? subscription.url.trim()
                        : subscription.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: CupertinoColors.systemGrey5.resolveFrom(
                            context,
                          ),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        child: Text(
                          typeText,
                          style: TextStyle(
                            fontSize: 11,
                            color: CupertinoColors.secondaryLabel.resolveFrom(
                              context,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          subscription.url,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: CupertinoColors.secondaryLabel.resolveFrom(
                              context,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            CupertinoButton(
              padding: EdgeInsets.zero,
              minimumSize: const Size(30, 30),
              onPressed: () => _showSubscriptionActions(subscription),
              child: const Icon(CupertinoIcons.ellipsis_circle, size: 20),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showSubscriptionActions(RuleSubscription subscription) async {
    if (!mounted) return;
    await showCupertinoBottomDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (sheetContext) => CupertinoActionSheet(
        title: Text(
          subscription.name.trim().isEmpty
              ? subscription.url.trim()
              : subscription.name,
        ),
        actions: [
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.of(sheetContext).pop();
              _deleteSubscription(subscription);
            },
            child: const Text('删除'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(sheetContext).pop(),
          child: const Text('取消'),
        ),
      ),
    );
  }

  Future<void> _deleteSubscription(RuleSubscription subscription) async {
    try {
      await _store.delete(subscription);
    } catch (error, stackTrace) {
      ExceptionLogService().record(
        node: 'RuleSubscriptionView.menu_del',
        message: '规则订阅删除失败',
        error: error,
        stackTrace: stackTrace,
        context: <String, dynamic>{
          'id': subscription.id,
          'name': subscription.name,
          'url': subscription.url,
        },
      );
    }
  }

  Future<void> _addSubscription() async {
    final draft = RuleSubscription(
      id: _store.nextId,
      name: '',
      url: '',
      type: 0,
      customOrder: _store.nextCustomOrder,
      update: DateTime.now().millisecondsSinceEpoch,
    );
    await _editSubscription(draft);
  }

  Future<void> _editSubscription(RuleSubscription subscription) async {
    final result = await _showEditDialog(subscription);
    if (result == null) return;

    final duplicated = _store.findByUrl(result.url);
    if (duplicated != null && duplicated.id != subscription.id) {
      final name = duplicated.name;
      if (!mounted) return;
      await _showMessage('此 URL 已订阅($name)');
      return;
    }

    final next = subscription.copyWith(
      name: result.name,
      url: result.url,
      type: result.type,
      update: DateTime.now().millisecondsSinceEpoch,
    );
    try {
      await _store.upsert(next);
    } catch (error, stackTrace) {
      ExceptionLogService().record(
        node: 'RuleSubscriptionView.menu_add',
        message: '规则订阅保存失败',
        error: error,
        stackTrace: stackTrace,
        context: <String, dynamic>{
          'id': next.id,
          'name': next.name,
          'url': next.url,
          'type': next.type,
          'customOrder': next.customOrder,
        },
      );
    }
  }

  Future<_RuleSubscriptionDraft?> _showEditDialog(
    RuleSubscription subscription,
  ) async {
    final nameController = TextEditingController(text: subscription.name);
    final urlController = TextEditingController(text: subscription.url);
    var selectedType = _normalizeType(subscription.type);

    try {
      return await showCupertinoDialog<_RuleSubscriptionDraft>(
        context: context,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (context, setState) {
              return CupertinoAlertDialog(
                title: const Text('规则订阅'),
                content: Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CupertinoSlidingSegmentedControl<int>(
                        groupValue: selectedType,
                        children: const <int, Widget>{
                          0: Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            child: Text('书源', style: TextStyle(fontSize: 12)),
                          ),
                          1: Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            child: Text('订阅源', style: TextStyle(fontSize: 12)),
                          ),
                          2: Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            child: Text('替换规则', style: TextStyle(fontSize: 12)),
                          ),
                        },
                        onValueChanged: (value) {
                          if (value == null) return;
                          setState(() {
                            selectedType = value;
                          });
                        },
                      ),
                      const SizedBox(height: 10),
                      CupertinoTextField(
                        controller: nameController,
                        placeholder: '名称',
                      ),
                      const SizedBox(height: 8),
                      CupertinoTextField(
                        controller: urlController,
                        placeholder: 'URL',
                      ),
                    ],
                  ),
                ),
                actions: [
                  CupertinoDialogAction(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    child: const Text('取消'),
                  ),
                  CupertinoDialogAction(
                    onPressed: () {
                      Navigator.of(dialogContext).pop(
                        _RuleSubscriptionDraft(
                          type: selectedType,
                          name: nameController.text,
                          url: urlController.text,
                        ),
                      );
                    },
                    child: const Text('确定'),
                  ),
                ],
              );
            },
          );
        },
      );
    } finally {
      nameController.dispose();
      urlController.dispose();
    }
  }

  int _normalizeType(int type) {
    return switch (type) {
      1 => 1,
      2 => 2,
      _ => 0,
    };
  }

  Future<void> _showMessage(String message) async {
    if (!mounted) return;
    await showCupertinoDialog<void>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: const Text('提示'),
        content: Text('\n$message'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('好'),
          ),
        ],
      ),
    );
  }

  String _typeLabel(int type) {
    return switch (type) {
      1 => '订阅源',
      2 => '替换规则',
      _ => '书源',
    };
  }
}

class _RuleSubscriptionDraft {
  const _RuleSubscriptionDraft({
    required this.type,
    required this.name,
    required this.url,
  });

  final int type;
  final String name;
  final String url;
}
