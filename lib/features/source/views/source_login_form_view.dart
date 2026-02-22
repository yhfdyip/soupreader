import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/widgets/app_cupertino_page_scaffold.dart';
import '../../../core/services/cookie_store.dart';
import '../../../core/services/source_login_store.dart';
import '../models/book_source.dart';
import '../services/source_cookie_scope_resolver.dart';
import '../services/source_login_ui_helper.dart';
import '../services/source_login_script_service.dart';

enum _SourceLoginMenuAction {
  showLoginHeader,
  deleteLoginHeader,
}

class SourceLoginFormView extends StatefulWidget {
  final BookSource source;

  const SourceLoginFormView({
    super.key,
    required this.source,
  });

  @override
  State<SourceLoginFormView> createState() => _SourceLoginFormViewState();
}

class _SourceLoginFormViewState extends State<SourceLoginFormView> {
  late final List<SourceLoginUiRow> _rows;
  final SourceLoginScriptService _scriptService =
      const SourceLoginScriptService();
  final Map<String, TextEditingController> _controllers =
      <String, TextEditingController>{};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _rows = SourceLoginUiHelper.parseRows(widget.source.loginUi);
    _initFormData();
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    _controllers.clear();
    super.dispose();
  }

  Future<void> _showMessage(String message) async {
    if (!mounted) return;
    await showCupertinoDialog<void>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('提示'),
        content: Text('\n$message'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('好'),
          ),
        ],
      ),
    );
  }

  Future<void> _showMoreMenu() async {
    if (_loading || !mounted) return;
    final selected = await showCupertinoModalPopup<_SourceLoginMenuAction>(
      context: context,
      builder: (sheetContext) => CupertinoActionSheet(
        actions: [
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(
              sheetContext,
              _SourceLoginMenuAction.showLoginHeader,
            ),
            child: const Text('查看登录头'),
          ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(
              sheetContext,
              _SourceLoginMenuAction.deleteLoginHeader,
            ),
            child: const Text('删除登录头'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(sheetContext),
          child: const Text('取消'),
        ),
      ),
    );
    if (selected == _SourceLoginMenuAction.showLoginHeader) {
      await _showLoginHeaderDialog();
      return;
    }
    if (selected == _SourceLoginMenuAction.deleteLoginHeader) {
      await _deleteLoginHeader();
    }
  }

  Future<void> _showLoginHeaderDialog() async {
    final key = widget.source.bookSourceUrl.trim();
    final loginHeaderText =
        key.isEmpty ? null : await SourceLoginStore.getLoginHeaderText(key);
    if (!mounted) return;
    await showCupertinoDialog<void>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: const Text('登录头'),
        content: loginHeaderText == null ? null : Text('\n$loginHeaderText'),
        actions: [
          if (loginHeaderText != null)
            CupertinoDialogAction(
              onPressed: () async {
                await Clipboard.setData(
                  ClipboardData(text: loginHeaderText),
                );
                if (!dialogContext.mounted) return;
                Navigator.pop(dialogContext);
              },
              child: const Text('复制文本'),
            ),
          if (loginHeaderText == null)
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('好'),
            ),
        ],
      ),
    );
  }

  Future<void> _deleteLoginHeader() async {
    final key = widget.source.bookSourceUrl.trim();
    if (key.isEmpty) return;
    await SourceLoginStore.removeLoginHeader(key);
    final cookieCandidates = SourceCookieScopeResolver.resolveClearCandidates(
      key,
    );
    for (final uri in cookieCandidates) {
      try {
        await CookieStore.jar.delete(uri, true);
      } catch (_) {
        // 对齐 legado 语义：删除登录头动作为静默分支，不提示 Cookie 清理错误。
      }
    }
  }

  Future<void> _initFormData() async {
    final key = widget.source.bookSourceUrl.trim();
    Map<String, String> loginInfoMap = <String, String>{};
    if (key.isNotEmpty) {
      final raw = await SourceLoginStore.getLoginInfo(key);
      if (raw != null && raw.trim().isNotEmpty) {
        try {
          final decoded = jsonDecode(raw);
          if (decoded is Map) {
            decoded.forEach((k, v) {
              if (k == null || v == null) return;
              final name = k.toString().trim();
              if (name.isEmpty) return;
              loginInfoMap[name] = v.toString();
            });
          }
        } catch (_) {
          // ignore invalid cached payload
        }
      }
    }

    for (final row in _rows) {
      if (!row.isTextLike) continue;
      _controllers[row.name] = TextEditingController(
        text: loginInfoMap[row.name] ?? '',
      );
    }

    if (!mounted) return;
    setState(() => _loading = false);
  }

  Future<void> _submit() async {
    final key = widget.source.bookSourceUrl.trim();
    if (key.isEmpty) {
      await _showMessage('请先填写书源地址');
      return;
    }

    final loginData = <String, String>{};
    for (final row in _rows) {
      if (!row.isTextLike) continue;
      final text = (_controllers[row.name]?.text ?? '').trim();
      if (text.isEmpty) continue;
      loginData[row.name] = text;
    }

    if (loginData.isEmpty) {
      await SourceLoginStore.removeLoginInfo(key);
      if (!mounted) return;
      Navigator.pop(context);
      return;
    }

    await SourceLoginStore.putLoginInfo(key, jsonEncode(loginData));
    final result = await _scriptService.runLoginScript(
      source: widget.source,
      loginData: loginData,
    );
    if (!mounted) return;
    if (!result.success) {
      await _showMessage(result.message);
      return;
    }
    if (result.message.trim().isNotEmpty) {
      await _showMessage(result.message);
      if (!mounted) return;
    }
    Navigator.pop(context);
  }

  Future<void> _handleActionRow(SourceLoginUiRow row) async {
    final action = row.action?.trim() ?? '';
    if (action.isEmpty) return;

    if (SourceLoginUiHelper.isAbsUrl(action)) {
      final uri = Uri.tryParse(action);
      if (uri == null) {
        await _showMessage('按钮地址无效');
        return;
      }
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return;
    }

    final loginData = <String, String>{};
    for (final item in _rows) {
      if (!item.isTextLike) continue;
      final text = (_controllers[item.name]?.text ?? '').trim();
      if (text.isEmpty) continue;
      loginData[item.name] = text;
    }
    final result = await _scriptService.runButtonScript(
      source: widget.source,
      loginData: loginData,
      actionScript: action,
    );
    if (!mounted) return;
    if (result.message.trim().isNotEmpty) {
      await _showMessage(result.message);
    }
  }

  Widget _buildRow(SourceLoginUiRow row) {
    if (row.isButton) {
      return CupertinoButton.filled(
        onPressed: () => _handleActionRow(row),
        child: Text(row.name),
      );
    }

    final controller = _controllers[row.name] ?? TextEditingController();
    _controllers.putIfAbsent(row.name, () => controller);

    return CupertinoTextField(
      controller: controller,
      obscureText: row.isPassword,
      placeholder: row.name,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      clearButtonMode: OverlayVisibilityMode.editing,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppCupertinoPageScaffold(
      title: '登录',
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CupertinoButton(
            padding: EdgeInsets.zero,
            minSize: 30,
            onPressed: _loading ? null : _submit,
            child: const Text('完成'),
          ),
          CupertinoButton(
            padding: EdgeInsets.zero,
            minSize: 30,
            onPressed: _loading ? null : _showMoreMenu,
            child: const Icon(CupertinoIcons.ellipsis),
          ),
        ],
      ),
      child: SafeArea(
        child: _loading
            ? const Center(child: CupertinoActivityIndicator())
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
                itemCount: _rows.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, index) => _buildRow(_rows[index]),
              ),
      ),
    );
  }
}
