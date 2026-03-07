import 'package:flutter/cupertino.dart';

import '../../../app/widgets/cupertino_bottom_dialog.dart';

/// 展示源变量编辑弹窗，并在保存时返回输入内容。
Future<String?> showSourceEditLegacyVariableSheet(
  BuildContext context, {
  required String note,
  required String initialValue,
}) async {
  final controller = TextEditingController(text: initialValue);
  try {
    return await showCupertinoBottomSheetDialog<String>(
      context: context,
      builder: (popupContext) => _SourceEditLegacyVariableSheet(
        note: note,
        controller: controller,
      ),
    );
  } finally {
    controller.dispose();
  }
}

class _SourceEditLegacyVariableSheet extends StatelessWidget {
  const _SourceEditLegacyVariableSheet({
    required this.note,
    required this.controller,
  });

  final String note;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return CupertinoPopupSurface(
      isSurfacePainted: true,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.78,
          child: Column(
            children: [
              _SourceEditLegacyVariableSheetHeader(controller: controller),
              Container(
                height: 0.5,
                color: CupertinoColors.separator.resolveFrom(context),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        note,
                        style: TextStyle(
                          fontSize: 12,
                          color: CupertinoColors.secondaryLabel.resolveFrom(
                            context,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Expanded(
                        child: CupertinoTextField(
                          controller: controller,
                          minLines: null,
                          maxLines: null,
                          expands: true,
                          textAlignVertical: TextAlignVertical.top,
                          placeholder: '输入变量 JSON 或文本',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SourceEditLegacyVariableSheetHeader extends StatelessWidget {
  const _SourceEditLegacyVariableSheetHeader({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 8),
      child: Row(
        children: [
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          const Expanded(
            child: Text(
              '设置源变量',
              maxLines: 1,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }
}
