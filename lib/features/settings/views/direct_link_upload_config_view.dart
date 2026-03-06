import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../../../app/widgets/app_action_list_sheet.dart';
import '../../../app/widgets/app_cupertino_page_scaffold.dart';
import '../../../app/widgets/app_nav_bar_button.dart';
import '../../../app/widgets/cupertino_bottom_dialog.dart';
import '../../../app/widgets/option_picker_sheet.dart';
import '../models/direct_link_upload_rule.dart';
import '../services/direct_link_upload_config_service.dart';
import 'direct_link_upload_config_form.dart';

enum _DirectLinkUploadConfigMenuAction {
  copyRule,
  pasteRule,
  importDefault,
}

/// 直链上传配置页（对齐 legado `DirectLinkUploadConfig`）。
class DirectLinkUploadConfigView extends StatefulWidget {
  const DirectLinkUploadConfigView({super.key});

  @override
  State<DirectLinkUploadConfigView> createState() =>
      _DirectLinkUploadConfigViewState();
}

class _DirectLinkUploadConfigViewState
    extends State<DirectLinkUploadConfigView> {
  final DirectLinkUploadConfigService _service =
      DirectLinkUploadConfigService();
  late final TextEditingController _uploadUrlController;
  late final TextEditingController _downloadUrlRuleController;
  late final TextEditingController _summaryController;

  bool _compress = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _uploadUrlController = TextEditingController();
    _downloadUrlRuleController = TextEditingController();
    _summaryController = TextEditingController();
    _initRule();
  }

  @override
  void dispose() {
    _uploadUrlController.dispose();
    _downloadUrlRuleController.dispose();
    _summaryController.dispose();
    super.dispose();
  }

  Future<void> _initRule() async {
    final rule = await _service.loadRule();
    if (!mounted) return;
    _applyRule(rule);
    setState(() {
      _loading = false;
    });
  }

  void _applyRule(DirectLinkUploadRule rule) {
    _uploadUrlController.text = rule.uploadUrl;
    _downloadUrlRuleController.text = rule.downloadUrlRule;
    _summaryController.text = rule.summary;
    _compress = rule.compress;
  }

  DirectLinkUploadRule? _buildRuleFromForm() {
    final uploadUrl = _uploadUrlController.text;
    final downloadUrlRule = _downloadUrlRuleController.text;
    final summary = _summaryController.text;

    if (uploadUrl.trim().isEmpty) {
      _showMessage('上传Url不能为空');
      return null;
    }
    if (downloadUrlRule.trim().isEmpty) {
      _showMessage('下载Url规则不能为空');
      return null;
    }
    if (summary.trim().isEmpty) {
      _showMessage('注释不能为空');
      return null;
    }
    return DirectLinkUploadRule(
      uploadUrl: uploadUrl,
      downloadUrlRule: downloadUrlRule,
      summary: summary,
      compress: _compress,
    );
  }

  Future<void> _saveAndClose() async {
    final rule = _buildRuleFromForm();
    if (rule == null) return;
    await _service.saveRule(rule);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _showMoreMenu() async {
    final selected =
        await showAppActionListSheet<_DirectLinkUploadConfigMenuAction>(
      context: context,
      title: '直链上传配置',
      showCancel: true,
      items: const [
        AppActionListItem<_DirectLinkUploadConfigMenuAction>(
          value: _DirectLinkUploadConfigMenuAction.copyRule,
          icon: CupertinoIcons.doc_on_doc,
          label: '拷贝规则',
        ),
        AppActionListItem<_DirectLinkUploadConfigMenuAction>(
          value: _DirectLinkUploadConfigMenuAction.pasteRule,
          icon: CupertinoIcons.doc_on_clipboard,
          label: '粘贴规则',
        ),
        AppActionListItem<_DirectLinkUploadConfigMenuAction>(
          value: _DirectLinkUploadConfigMenuAction.importDefault,
          icon: CupertinoIcons.arrow_down_doc,
          label: '导入默认规则',
        ),
      ],
    );
    if (selected == null) return;
    switch (selected) {
      case _DirectLinkUploadConfigMenuAction.copyRule:
        await _copyRuleToClipboard();
        return;
      case _DirectLinkUploadConfigMenuAction.pasteRule:
        await _pasteRuleFromClipboard();
        return;
      case _DirectLinkUploadConfigMenuAction.importDefault:
        await _importDefaultRule();
        return;
    }
  }

  Future<void> _copyRuleToClipboard() async {
    final rule = _buildRuleFromForm();
    if (rule == null) return;
    await Clipboard.setData(ClipboardData(text: jsonEncode(rule.toJson())));
  }

  Future<void> _importDefaultRule() async {
    final defaultRules = await _service.loadDefaultRules();
    if (!mounted || defaultRules.isEmpty) return;
    final selected = await showOptionPickerSheet<DirectLinkUploadRule>(
      context: context,
      title: '导入默认规则',
      currentValue: null,
      showCancel: true,
      items: defaultRules
          .map(
            (rule) => OptionPickerItem<DirectLinkUploadRule>(
              value: rule,
              label: rule.summary,
            ),
          )
          .toList(growable: false),
    );
    if (selected == null || !mounted) return;
    setState(() {
      _applyRule(selected);
    });
  }

  Future<void> _pasteRuleFromClipboard() async {
    final clipData = await Clipboard.getData(Clipboard.kTextPlain);
    final clipText = clipData?.text;
    if (clipText == null || clipText.trim().isEmpty) {
      await _showMessage('剪贴板为空或格式不对');
      return;
    }
    try {
      final decoded = jsonDecode(clipText);
      if (decoded is! Map) {
        throw const FormatException('格式不对');
      }
      final mapped = decoded.map<String, dynamic>(
        (key, value) => MapEntry('$key', value),
      );
      final rule = DirectLinkUploadRule.fromJson(mapped);
      if (!mounted) return;
      setState(() {
        _applyRule(rule);
      });
    } catch (_) {
      await _showMessage('剪贴板为空或格式不对');
    }
  }

  Future<void> _showMessage(String message) async {
    if (!mounted) return;
    await showCupertinoBottomDialog<void>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('好'),
          ),
        ],
      ),
    );
  }

  void _onCompressChanged(bool value) {
    setState(() {
      _compress = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AppCupertinoPageScaffold(
      title: '直链上传配置',
      trailing: AppNavBarButton(
        onPressed: _showMoreMenu,
        child: const Icon(CupertinoIcons.ellipsis, size: 22),
      ),
      child: _loading
          ? const Center(child: CupertinoActivityIndicator())
          : DirectLinkUploadConfigForm(
              uploadUrlController: _uploadUrlController,
              downloadUrlRuleController: _downloadUrlRuleController,
              summaryController: _summaryController,
              compress: _compress,
              onCompressChanged: _onCompressChanged,
              onCancel: () => Navigator.of(context).pop(),
              onConfirm: _saveAndClose,
            ),
    );
  }
}
