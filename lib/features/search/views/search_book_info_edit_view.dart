import 'package:flutter/cupertino.dart';

import '../../../app/theme/design_tokens.dart';
import '../../../app/widgets/app_cupertino_page_scaffold.dart';
import '../../../app/widgets/app_nav_bar_button.dart';
import '../services/search_book_info_edit_helper.dart';
import 'search_book_cover_change_view.dart';

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

  Future<void> _openChangeCover() async {
    final selected = await Navigator.of(context).push<String>(
      CupertinoPageRoute<String>(
        builder: (_) => SearchBookCoverChangeView(
          name: _nameController.text,
          author: _authorController.text,
        ),
      ),
    );
    if (selected == null) return;
    _coverController.text = selected;
  }

  Widget _buildField({
    required String label,
    required TextEditingController controller,
    String? placeholder,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
  }) {
    final textStyle = CupertinoTheme.of(context).textTheme.textStyle;
    final labelColor = CupertinoColors.label.resolveFrom(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: textStyle.copyWith(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: labelColor,
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

  Widget _buildFormContainer({required Widget child}) {
    final cardColor =
        CupertinoColors.secondarySystemGroupedBackground.resolveFrom(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(AppDesignTokens.radiusCard),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppCupertinoPageScaffold(
      title: '编辑书籍信息',
      leading: AppNavBarButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('取消'),
      ),
      trailing: AppNavBarButton(
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
          _buildFormContainer(
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
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: _openChangeCover,
                    child: const Text('封面换源'),
                  ),
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
