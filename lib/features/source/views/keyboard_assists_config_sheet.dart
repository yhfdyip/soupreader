import 'package:flutter/cupertino.dart';

import '../../../core/services/keyboard_assist_store.dart';

Future<void> showKeyboardAssistsConfigSheet(
  BuildContext context, {
  KeyboardAssistStore? store,
}) async {
  await showCupertinoDialog<void>(
    context: context,
    builder: (dialogContext) => _KeyboardAssistsConfigDialog(
      store: store ?? KeyboardAssistStore(),
    ),
  );
}

class _KeyboardAssistsConfigDialog extends StatefulWidget {
  const _KeyboardAssistsConfigDialog({
    required this.store,
  });

  final KeyboardAssistStore store;

  @override
  State<_KeyboardAssistsConfigDialog> createState() =>
      _KeyboardAssistsConfigDialogState();
}

class _KeyboardAssistsConfigDialogState
    extends State<_KeyboardAssistsConfigDialog> {
  List<KeyboardAssistEntry> _items = const <KeyboardAssistEntry>[];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final items = await widget.store.loadAll(type: 0);
    if (!mounted) return;
    setState(() {
      _items = items;
      _loading = false;
    });
  }

  Future<void> _editAssist([KeyboardAssistEntry? editing]) async {
    final keyController = TextEditingController(text: editing?.key ?? '');
    final valueController = TextEditingController(text: editing?.value ?? '');
    final shouldSave = await showCupertinoDialog<bool>(
      context: context,
      builder: (popupContext) => CupertinoAlertDialog(
        title: const Text('辅助按键'),
        content: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CupertinoTextField(
                controller: keyController,
                placeholder: 'key',
              ),
              const SizedBox(height: 8),
              CupertinoTextField(
                controller: valueController,
                placeholder: 'value',
              ),
            ],
          ),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(popupContext, false),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(popupContext, true),
            child: const Text('确定'),
          ),
        ],
      ),
    );

    final key = keyController.text.trim();
    final value = valueController.text;
    keyController.dispose();
    valueController.dispose();

    if (shouldSave != true) return;
    if (key.isEmpty) {
      await _showMessage('key 不能为空');
      return;
    }
    await widget.store.upsert(
      key: key,
      value: value,
      editing: editing,
    );
    await _reload();
  }

  Future<void> _deleteAssist(KeyboardAssistEntry item) async {
    await widget.store.delete(item);
    await _reload();
  }

  Future<void> _showMessage(String message) async {
    if (!mounted) return;
    await showCupertinoDialog<void>(
      context: context,
      builder: (popupContext) => CupertinoAlertDialog(
        title: const Text('提示'),
        content: Text('\n$message'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(popupContext),
            child: const Text('好'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Center(
      child: CupertinoPopupSurface(
        child: SizedBox(
          width: size.width * 0.9,
          height: size.height * 0.9,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
                child: Row(
                  children: [
                    CupertinoButton(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('关闭'),
                    ),
                    const Expanded(
                      child: Center(
                        child: Text(
                          '辅助按键配置',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    CupertinoButton(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      onPressed: () => _editAssist(null),
                      child: const Icon(CupertinoIcons.add),
                    ),
                  ],
                ),
              ),
              _buildSeparator(context),
              Expanded(
                child: _loading
                    ? const Center(child: CupertinoActivityIndicator())
                    : _items.isEmpty
                        ? const Center(
                            child: Text(
                              '暂无辅助按键',
                              style: TextStyle(
                                color: CupertinoColors.secondaryLabel,
                              ),
                            ),
                          )
                        : ListView.separated(
                            itemCount: _items.length,
                            separatorBuilder: (_, __) =>
                                _buildSeparator(context),
                            itemBuilder: (context, index) {
                              final item = _items[index];
                              return GestureDetector(
                                onTap: () => _editAssist(item),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 12,
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              item.key,
                                              style: const TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              item.value.isEmpty
                                                  ? '（空值）'
                                                  : item.value,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: CupertinoColors
                                                    .secondaryLabel,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      CupertinoButton(
                                        padding: const EdgeInsets.all(4),
                                        minimumSize: const Size(28, 28),
                                        onPressed: () => _deleteAssist(item),
                                        child: const Icon(
                                          CupertinoIcons.delete,
                                          size: 18,
                                          color: CupertinoColors.destructiveRed,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSeparator(BuildContext context) {
    return Container(
      height: 0.5,
      color: CupertinoColors.separator.resolveFrom(context),
    );
  }
}
