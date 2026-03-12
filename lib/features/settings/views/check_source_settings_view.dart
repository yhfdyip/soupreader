import 'package:flutter/cupertino.dart';

import '../../../app/widgets/app_ui_kit.dart';
import '../../../app/widgets/cupertino_bottom_dialog.dart';

import '../../../app/widgets/app_cupertino_page_scaffold.dart';
import '../../../app/widgets/app_nav_bar_button.dart';
import '../models/check_source_settings.dart';
import '../services/check_source_settings_service.dart';

class CheckSourceSettingsView extends StatefulWidget {
  const CheckSourceSettingsView({super.key});

  @override
  State<CheckSourceSettingsView> createState() =>
      _CheckSourceSettingsViewState();
}

class _CheckSourceSettingsViewState extends State<CheckSourceSettingsView> {
  final CheckSourceSettingsService _service = CheckSourceSettingsService();
  late CheckSourceSettings _draft;

  @override
  void initState() {
    super.initState();
    _draft = _service.loadSettings();
  }

  Future<void> _saveAndClose() async {
    if (_draft.timeoutMs <= 0) {
      _showMessage('超时时间需大于0秒');
      return;
    }
    await _service.saveSettings(_draft);
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  Future<void> _editTimeoutSeconds() async {
    final controller = TextEditingController(
      text: (_draft.timeoutMs ~/ 1000).toString(),
    );
    final result = await showCupertinoBottomSheetDialog<String>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: const Text('单个书源校验超时（秒）'),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: CupertinoTextField(
            controller: controller,
            keyboardType: TextInputType.number,
            placeholder: '请输入大于 0 的整数',
          ),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: const Text('确定'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result == null) return;
    final seconds = int.tryParse(result.trim()) ?? 0;
    if (seconds <= 0) {
      _showMessage('超时时间需大于0秒');
      return;
    }
    setState(() {
      _draft = _draft.copyWith(timeoutMs: seconds * 1000).normalized();
    });
  }

  void _toggleCheckSearch(bool enabled) {
    var next = _draft.copyWith(checkSearch: enabled);
    if (!next.checkSearch && !next.checkDiscovery) {
      next = next.copyWith(checkDiscovery: true);
    }
    setState(() {
      _draft = next.normalized();
    });
  }

  void _toggleCheckDiscovery(bool enabled) {
    var next = _draft.copyWith(checkDiscovery: enabled);
    if (!next.checkSearch && !next.checkDiscovery) {
      next = next.copyWith(checkSearch: true);
    }
    setState(() {
      _draft = next.normalized();
    });
  }

  void _toggleCheckInfo(bool enabled) {
    var next = _draft.copyWith(checkInfo: enabled);
    if (!enabled) {
      next = next.copyWith(
        checkCategory: false,
        checkContent: false,
      );
    }
    setState(() {
      _draft = next.normalized();
    });
  }

  void _toggleCheckCategory(bool enabled) {
    if (!_draft.checkInfo) return;
    var next = _draft.copyWith(checkCategory: enabled);
    if (!enabled) {
      next = next.copyWith(checkContent: false);
    }
    setState(() {
      _draft = next.normalized();
    });
  }

  void _toggleCheckContent(bool enabled) {
    if (!_draft.checkCategory) return;
    setState(() {
      _draft = _draft.copyWith(checkContent: enabled).normalized();
    });
  }

  void _showMessage(String message) {
    showCupertinoBottomSheetDialog<void>(
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

  Widget _buildSwitchTile({
    required String title,
    required bool value,
    required ValueChanged<bool>? onChanged,
  }) {
    return AppListTile(
      title: Text(title),
      trailing: CupertinoSwitch(
        value: value,
        onChanged: onChanged,
      ),
      onTap: onChanged == null ? null : () => onChanged(!value),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppCupertinoPageScaffold(
      title: '校验设置',
      leading: AppNavBarButton(
        onPressed: () => Navigator.of(context).pop(false),
        child: const Text('取消'),
      ),
      trailing: AppNavBarButton(
        onPressed: _saveAndClose,
        child: const Text('确定'),
      ),
      child: AppListView(
        children: [
          AppListSection(
            hasLeading: false,
            children: [
              AppListTile(
                title: const Text('单个书源校验超时（秒）'),
                additionalInfo: Text('${_draft.timeoutMs ~/ 1000}'),
                onTap: _editTimeoutSeconds,
              ),
            ],
          ),
          AppListSection(
            header: const Text('校验项目'),
            hasLeading: false,
            children: [
              _buildSwitchTile(
                title: '搜索',
                value: _draft.checkSearch,
                onChanged: _toggleCheckSearch,
              ),
              _buildSwitchTile(
                title: '发现',
                value: _draft.checkDiscovery,
                onChanged: _toggleCheckDiscovery,
              ),
              _buildSwitchTile(
                title: '详情',
                value: _draft.checkInfo,
                onChanged: _toggleCheckInfo,
              ),
              _buildSwitchTile(
                title: '目录',
                value: _draft.checkCategory,
                onChanged: _draft.checkInfo ? _toggleCheckCategory : null,
              ),
              _buildSwitchTile(
                title: '正文',
                value: _draft.checkContent,
                onChanged: _draft.checkCategory ? _toggleCheckContent : null,
              ),
            ],
          ),
          AppListSection(
            header: const Text('摘要'),
            hasLeading: false,
            children: [
              AppListTile(
                title: Text(_draft.summary()),
                showChevron: false,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
