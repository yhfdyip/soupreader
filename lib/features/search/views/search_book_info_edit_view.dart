import 'package:flutter/cupertino.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../app/widgets/app_cupertino_page_scaffold.dart';
import '../services/search_book_info_edit_helper.dart';

class SearchBookInfoEditView extends StatefulWidget {
  final SearchBookInfoEditDraft initialDraft;

  const SearchBookInfoEditView({
    super.key,
    required this.initialDraft,
  });

  @override
  State<SearchBookInfoEditView> createState() => _SearchBookInfoEditViewState();
}

class _SearchBookInfoEditViewState extends State<SearchBookInfoEditView> {
  late final TextEditingController _nameController;
  late final TextEditingController _authorController;
  late final TextEditingController _coverController;
  late final TextEditingController _introController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialDraft.name);
    _authorController = TextEditingController(text: widget.initialDraft.author);
    _coverController =
        TextEditingController(text: widget.initialDraft.coverUrl);
    _introController = TextEditingController(text: widget.initialDraft.intro);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _authorController.dispose();
    _coverController.dispose();
    _introController.dispose();
    super.dispose();
  }

  void _submit() {
    Navigator.of(context).pop(
      SearchBookInfoEditDraft(
        name: _nameController.text,
        author: _authorController.text,
        coverUrl: _coverController.text,
        intro: _introController.text,
      ),
    );
  }

  Widget _buildField({
    required String label,
    required TextEditingController controller,
    String? placeholder,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
  }) {
    final theme = ShadTheme.of(context);
    final scheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.small.copyWith(
            fontWeight: FontWeight.w600,
            color: scheme.foreground,
          ),
        ),
        const SizedBox(height: 6),
        CupertinoTextField(
          controller: controller,
          maxLines: maxLines,
          placeholder: placeholder,
          keyboardType: keyboardType,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppCupertinoPageScaffold(
      title: '编辑书籍信息',
      leading: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('取消'),
      ),
      trailing: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: _submit,
        child: const Text('保存'),
      ),
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          14,
          12,
          14,
          MediaQuery.paddingOf(context).bottom + 12,
        ),
        children: [
          ShadCard(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildField(
                  label: '书名',
                  controller: _nameController,
                  placeholder: '输入书名',
                ),
                const SizedBox(height: 12),
                _buildField(
                  label: '作者',
                  controller: _authorController,
                  placeholder: '输入作者',
                ),
                const SizedBox(height: 12),
                _buildField(
                  label: '封面链接',
                  controller: _coverController,
                  placeholder: '输入封面 URL 或本地路径',
                  keyboardType: TextInputType.url,
                ),
                const SizedBox(height: 12),
                _buildField(
                  label: '简介',
                  controller: _introController,
                  placeholder: '输入简介',
                  maxLines: 8,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
