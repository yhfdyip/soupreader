import 'dart:math' as math;

import 'package:flutter/cupertino.dart';

import '../../../app/theme/ui_tokens.dart';
import '../../../app/widgets/app_card.dart';
import '../../../app/widgets/app_empty_state.dart';
import '../../../app/widgets/app_glass_sheet_panel.dart';
import '../../../app/widgets/cupertino_bottom_dialog.dart';

import '../../../core/services/keyboard_assist_store.dart';

Future<void> showKeyboardAssistsConfigSheet(
  BuildContext context, {
  KeyboardAssistStore? store,
}) async {
  await showCupertinoBottomDialog<void>(
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
  static const double _kWidthFactor = 0.9;
  static const double _kHeightFactor = 0.9;
  static const double _kMaxWidth = 720;
  static const double _kMaxHeight = 760;

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
    final shouldSave = await showCupertinoBottomDialog<bool>(
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
    await showCupertinoBottomDialog<void>(
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
    final ui = AppUiTokens.resolve(context);
    final size = MediaQuery.sizeOf(context);
    final width = math.min(size.width * _kWidthFactor, _kMaxWidth);
    final height = math.min(size.height * _kHeightFactor, _kMaxHeight);

    return Center(
      child: SizedBox(
        width: width,
        height: height,
        child: AppGlassSheetPanel(
          contentPadding: EdgeInsets.zero,
          radius: ui.radii.sheet,
          child: SafeArea(
            bottom: false,
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
                _buildSeparator(ui),
                Expanded(
                  child: _loading
                      ? const Center(child: CupertinoActivityIndicator())
                      : _items.isEmpty
                          ? const AppEmptyState(
                              illustration:
                                  AppEmptyPlanetIllustration(size: 80),
                              title: '暂无辅助按键',
                              message: '点击右上角加号添加辅助按键',
                            )
                          : ListView.separated(
                              physics: const BouncingScrollPhysics(),
                              padding: const EdgeInsets.fromLTRB(10, 8, 10, 12),
                              itemCount: _items.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 8),
                              itemBuilder: (context, index) {
                                final item = _items[index];
                                return _KeyboardAssistListTile(
                                  item: item,
                                  onTap: () => _editAssist(item),
                                  onDelete: () => _deleteAssist(item),
                                );
                              },
                            ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _KeyboardAssistListTile extends StatelessWidget {
  final KeyboardAssistEntry item;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _KeyboardAssistListTile({
    required this.item,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final secondaryLabel = CupertinoColors.secondaryLabel.resolveFrom(context);
    final destructiveColor =
        CupertinoColors.destructiveRed.resolveFrom(context);
    return GestureDetector(
      onTap: onTap,
      child: AppCard(
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
        child: SizedBox(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
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
                      item.value.isEmpty ? '（空值）' : item.value,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: secondaryLabel,
                      ),
                    ),
                  ],
                ),
              ),
              CupertinoButton(
                padding: const EdgeInsets.all(4),
                minimumSize: const Size(28, 28),
                onPressed: onDelete,
                child: Icon(
                  CupertinoIcons.delete,
                  size: 18,
                  color: destructiveColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Widget _buildSeparator(AppUiTokens ui) {
  return Container(
    height: ui.sizes.dividerThickness,
    color: ui.colors.separator.withValues(alpha: 0.78),
  );
}
