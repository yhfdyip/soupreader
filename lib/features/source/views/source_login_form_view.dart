import 'dart:async';
import 'dart:convert';

import 'package:flutter/cupertino.dart';

import '../../../app/widgets/app_toast.dart';
import '../../../app/widgets/app_action_list_sheet.dart';
import '../../../app/widgets/cupertino_bottom_dialog.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/widgets/app_cupertino_page_scaffold.dart';
import '../../../app/widgets/app_nav_bar_button.dart';
import '../../../core/services/cookie_store.dart';
import '../../../core/services/exception_log_service.dart';
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
    await showCupertinoBottomSheetDialog<void>(
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
    final selected = await showAppActionListSheet<_SourceLoginMenuAction>(
      context: context,
      title: '操作',
      showCancel: true,
      items: const [
        AppActionListItem<_SourceLoginMenuAction>(
          value: _SourceLoginMenuAction.showLoginHeader,
          icon: CupertinoIcons.doc_text_search,
          label: '查看登录头',
        ),
        AppActionListItem<_SourceLoginMenuAction>(
          value: _SourceLoginMenuAction.deleteLoginHeader,
          icon: CupertinoIcons.delete,
          label: '删除登录头',
          isDestructiveAction: true,
        ),
      ],
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
    await showCupertinoBottomSheetDialog<void>(
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
    final loginData = _collectLoginData();

    if (loginData.isEmpty) {
      await SourceLoginStore.removeLoginInfo(key);
      if (!mounted) return;
      Navigator.pop(context);
      return;
    }

    try {
      await SourceLoginStore.putLoginInfo(key, jsonEncode(loginData));
      final result = await _scriptService.runLoginScript(
        source: widget.source,
        loginData: loginData,
      );
      if (!mounted) return;

      if (!result.success) {
        final detail = result.message.trim();
        final errorMessage = detail.isEmpty ? '登录出错' : '登录出错\n$detail';
        ExceptionLogService().record(
          node: 'source.login.menu_ok',
          message: '登录脚本执行失败',
          error: detail.isEmpty ? null : detail,
          context: <String, dynamic>{
            'sourceKey': key,
            'sourceName': widget.source.bookSourceName,
          },
        );
        await _showMessage(errorMessage);
        return;
      }

      // 对齐 legado SourceLoginDialog.menu_ok：成功后仅提示“成功”并关闭页面。
      unawaited(showAppToast(context, message: '登录成功'));
      if (!mounted) return;
      Navigator.pop(context);
    } catch (error, stackTrace) {
      ExceptionLogService().record(
        node: 'source.login.menu_ok',
        message: '登录出错',
        error: error,
        stackTrace: stackTrace,
        context: <String, dynamic>{
          'sourceKey': key,
          'sourceName': widget.source.bookSourceName,
        },
      );
      if (!mounted) return;
      await _showMessage('登录出错\n$error');
    }
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

    final loginData = _collectLoginData();
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

  Map<String, String> _collectLoginData() {
    final loginData = <String, String>{};
    for (final row in _rows) {
      if (!row.isTextLike) continue;
      loginData[row.name] = _controllers[row.name]?.text ?? '';
    }
    return loginData;
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
          AppNavBarButton(
            onPressed: _loading ? null : _submit,
            child: const Text('完成'),
            minimumSize: const Size(30, 30),
          ),
          AppNavBarButton(
            onPressed: _loading ? null : _showMoreMenu,
            child: const Icon(CupertinoIcons.ellipsis),
            minimumSize: const Size(30, 30),
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
