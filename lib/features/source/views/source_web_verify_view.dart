import 'dart:async';

import 'package:flutter/cupertino.dart';

import '../../../app/widgets/app_toast.dart';
import '../../../app/widgets/app_action_list_sheet.dart';
import '../../../app/widgets/cupertino_bottom_dialog.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../app/theme/design_tokens.dart';
import '../../../app/widgets/app_cupertino_page_scaffold.dart';
import '../../../app/widgets/app_nav_bar_button.dart';
import '../../../app/widgets/app_webview_toolbar.dart';
import '../../../core/database/database_service.dart';
import '../../../core/database/repositories/source_repository.dart';
import '../../../core/services/exception_log_service.dart';
import '../../../core/services/source_variable_store.dart';
import '../../../core/services/webview_cookie_bridge.dart';
import '../services/rule_parser_engine.dart';

class SourceWebVerifyView extends StatefulWidget {
  final String initialUrl;
  final String sourceOrigin;
  final String sourceName;

  const SourceWebVerifyView({
    super.key,
    required this.initialUrl,
    this.sourceOrigin = '',
    this.sourceName = '',
  });

  @override
  State<SourceWebVerifyView> createState() => _SourceWebVerifyViewState();
}

enum _SourceWebVerifyAction {
  openInBrowser,
  copyUrl,
  fullScreen,
  disableSource,
  deleteSource,
  reload,
  importCookies,
  copyCookieHeader,
  clearCookie,
}

class _SourceWebVerifyViewState extends State<SourceWebVerifyView> {
  static const double _progressBarHeight = 2;
  static const double _progressMinFactor = 0.08;
  static const double _fullScreenOverlayBgAlpha = 0.72;
  static const double _fullScreenOverlayRadius = 12;
  static const double _fullScreenOverlayButtonSize = 34;
  static const double _fullScreenOverlayIconSize = 18;

  late final SourceRepository _sourceRepo;
  late final ExceptionLogService _exceptionLogService;

  late final WebViewController _controller;
  int _progress = 0;
  String _currentUrl = '';
  bool _isFullScreen = false;
  bool _isLoading = true;
  bool _canGoBack = false;
  bool _canGoForward = false;
  bool _navStateRefreshErrorLogged = false;

  String? _lastImportHint;
  String? _lastImportCookieHeaderValue;

  @override
  void initState() {
    super.initState();
    _sourceRepo = SourceRepository(DatabaseService());
    _exceptionLogService = ExceptionLogService();

    _currentUrl = widget.initialUrl;

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (p) {
            if (!mounted) return;
            setState(() => _progress = p);
          },
          onPageStarted: (url) {
            if (!mounted) return;
            setState(() {
              _isLoading = true;
              _currentUrl = url;
            });
            unawaited(_refreshNavState());
          },
          onPageFinished: (_) {
            if (!mounted) return;
            setState(() => _isLoading = false);
            unawaited(_refreshNavState());
          },
          onUrlChange: (change) {
            final url = change.url;
            if (url == null) return;
            if (!mounted) return;
            setState(() => _currentUrl = url);
            unawaited(_refreshNavState());
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.initialUrl));
  }

  @override
  void dispose() {
    if (_isFullScreen) {
      unawaited(_restoreSystemUiForPage());
    }
    super.dispose();
  }

  Future<void> _setFullScreen(bool enabled) async {
    if (!mounted || _isFullScreen == enabled) return;
    setState(() => _isFullScreen = enabled);
    await SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: enabled
          ? const <SystemUiOverlay>[]
          : const <SystemUiOverlay>[
              SystemUiOverlay.top,
              SystemUiOverlay.bottom,
            ],
    );
  }

  Future<void> _toggleFullScreen() async {
    await _setFullScreen(!_isFullScreen);
  }

  Future<void> _restoreSystemUiForPage() async {
    await SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: const <SystemUiOverlay>[
        SystemUiOverlay.top,
        SystemUiOverlay.bottom,
      ],
    );
  }

  Future<void> _refreshNavState() async {
    try {
      final back = await _controller.canGoBack();
      final forward = await _controller.canGoForward();
      if (!mounted) return;
      setState(() {
        _canGoBack = back;
        _canGoForward = forward;
      });
    } catch (error, stackTrace) {
      // WebView 生命周期中可能暂不可用：允许忽略导航态刷新，但不能静默吞错。
      if (_navStateRefreshErrorLogged) return;
      _navStateRefreshErrorLogged = true;
      _exceptionLogService.record(
        node: 'source.web_view.refresh_nav_state',
        message: '刷新 WebView 导航状态失败',
        error: error,
        stackTrace: stackTrace,
        context: <String, dynamic>{
          'initialUrl': widget.initialUrl,
          'currentUrl': _currentUrl,
          'isFullScreen': _isFullScreen,
          'isLoading': _isLoading,
        },
      );
    }
  }

  Future<void> _goBack() async {
    if (!await _controller.canGoBack()) return;
    await _controller.goBack();
    unawaited(_refreshNavState());
  }

  Future<void> _goForward() async {
    if (!await _controller.canGoForward()) return;
    await _controller.goForward();
    unawaited(_refreshNavState());
  }

  Future<void> _reloadOrStop() async {
    if (_isLoading) {
      // webview_flutter 没有 stopLoading API，尽量用 window.stop() 对齐浏览器行为。
      try {
        await _controller.runJavaScript('window.stop();');
      } catch (error, stackTrace) {
        _exceptionLogService.record(
          node: 'source.web_view.stop_loading',
          message: '停止加载失败（window.stop）',
          error: error,
          stackTrace: stackTrace,
          context: <String, dynamic>{
            'initialUrl': widget.initialUrl,
            'currentUrl': _currentUrl,
          },
        );
      }
      if (!mounted) return;
      setState(() => _isLoading = false);
      return;
    }
    setState(() => _isLoading = true);
    await _controller.reload();
  }

  Future<void> _showMessage(String message) async {
    if (!mounted) return;
    showCupertinoBottomDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('提示'),
        content: Text('\n$message'),
        actions: [
          CupertinoDialogAction(
            child: const Text('好'),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Future<void> _importCookies() async {
    if (!WebViewCookieBridge.isSupported) {
      await _showMessage('当前平台不支持从 WebView 导入 Cookie');
      return;
    }

    Uri? uri;
    try {
      uri = Uri.parse(_currentUrl.isNotEmpty ? _currentUrl : widget.initialUrl);
    } catch (_) {
      uri = null;
    }
    if (uri == null || uri.host.trim().isEmpty) {
      await _showMessage('URL 无效，无法解析域名');
      return;
    }

    final domain = uri.host;
    final cookies = await WebViewCookieBridge.getCookiesForDomain(
      domain,
      includeSubdomains: true,
    );
    if (cookies.isEmpty) {
      await _showMessage('未读取到 Cookie（可能尚未通过验证）');
      return;
    }

    await RuleParserEngine.saveCookiesForUrl(uri.toString(), cookies);
    final cookieHeader = WebViewCookieBridge.toCookieHeaderValue(cookies);

    final names = cookies.map((c) => c.name).toSet().toList()..sort();
    final keyOnes = names
        .where((n) => n.toLowerCase().contains('cf') || n.contains('clearance'))
        .toList(growable: false);

    if (!mounted) return;
    setState(() {
      _lastImportCookieHeaderValue = cookieHeader;
      _lastImportHint = [
        '已导入 Cookie：${cookies.length} 个（${names.length} 种）',
        if (keyOnes.isNotEmpty) '关键：${keyOnes.join(', ')}',
        '域名：$domain',
      ].join('\n');
    });

    await _showMessage(_lastImportHint!);
  }

  Future<void> _copyCookieHeader() async {
    final value = _lastImportCookieHeaderValue;
    if (value == null || value.trim().isEmpty) {
      await _showMessage('尚未导入 Cookie');
      return;
    }
    await Clipboard.setData(ClipboardData(text: value));
    unawaited(showAppToast(context, message: '已复制 Cookie 值（可用于书源 header 的 Cookie 字段）'));
  }

  Future<void> _openInBrowser() async {
    final initial = widget.initialUrl.trim();
    final current = _currentUrl.trim();
    final target = initial.isNotEmpty ? initial : current;
    final uri = Uri.tryParse(target);
    final scheme = uri?.scheme.toLowerCase();
    if (uri == null || (scheme != 'http' && scheme != 'https')) {
      ExceptionLogService().record(
        node: 'source.web_view.menu_open_in_browser',
        message: '网页验证页浏览器打开失败（URL 解析失败）',
        context: <String, dynamic>{
          'target': target,
          'initialUrl': widget.initialUrl,
          'currentUrl': _currentUrl,
        },
      );
      await _showMessage('open url error');
      return;
    }
    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (launched) {
        return;
      }
      ExceptionLogService().record(
        node: 'source.web_view.menu_open_in_browser',
        message: '网页验证页浏览器打开失败（launchUrl=false）',
        context: <String, dynamic>{
          'target': target,
          'initialUrl': widget.initialUrl,
          'currentUrl': _currentUrl,
        },
      );
      await _showMessage('open url error');
    } catch (error, stackTrace) {
      ExceptionLogService().record(
        node: 'source.web_view.menu_open_in_browser',
        message: '网页验证页浏览器打开失败',
        error: error,
        stackTrace: stackTrace,
        context: <String, dynamic>{
          'target': target,
          'initialUrl': widget.initialUrl,
          'currentUrl': _currentUrl,
        },
      );
      await _showMessage('open url error');
    }
  }

  Future<void> _copyBaseUrl() async {
    final current = _currentUrl.trim();
    final initial = widget.initialUrl.trim();
    final target = current.isNotEmpty ? current : initial;
    if (target.isEmpty) {
      await _showMessage('URL 为空');
      return;
    }
    await Clipboard.setData(ClipboardData(text: target));
    await _showMessage('复制完成');
  }

  Future<void> _disableCurrentSource() async {
    final sourceUrl = widget.sourceOrigin.trim();
    if (sourceUrl.isEmpty) return;

    try {
      final current = _sourceRepo.getSourceByUrl(sourceUrl);
      if (current != null) {
        await _sourceRepo.updateSource(current.copyWith(enabled: false));
      }
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (error, stackTrace) {
      _exceptionLogService.record(
        node: 'source.web_view.menu_disable_source',
        message: '禁用书源失败',
        error: error,
        stackTrace: stackTrace,
        context: <String, dynamic>{
          'sourceKey': sourceUrl,
          'sourceName': widget.sourceName,
          'initialUrl': widget.initialUrl,
          'currentUrl': _currentUrl,
        },
      );
    }
  }

  Future<void> _confirmDeleteCurrentSource() async {
    final sourceUrl = widget.sourceOrigin.trim();
    if (sourceUrl.isEmpty || !mounted) return;
    final sourceName = widget.sourceName.trim();

    final confirmed = await showCupertinoBottomDialog<bool>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: const Text('提醒'),
        content: Text('是否确认删除？\n$sourceName'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('确定'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _deleteCurrentSource();
  }

  Future<void> _deleteCurrentSource() async {
    final sourceUrl = widget.sourceOrigin.trim();
    if (sourceUrl.isEmpty) return;

    try {
      await _sourceRepo.deleteSource(sourceUrl);
      await SourceVariableStore.removeVariable(sourceUrl);
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (error, stackTrace) {
      _exceptionLogService.record(
        node: 'source.web_view.menu_delete_source',
        message: '删除书源失败',
        error: error,
        stackTrace: stackTrace,
        context: <String, dynamic>{
          'sourceKey': sourceUrl,
          'sourceName': widget.sourceName,
          'initialUrl': widget.initialUrl,
          'currentUrl': _currentUrl,
        },
      );
    }
  }

  void _confirmAndClose() {
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _showMoreMenu() async {
    final hasSource = widget.sourceOrigin.trim().isNotEmpty;
    final menuUrl = (_currentUrl.isEmpty ? widget.initialUrl : _currentUrl);
    final action = await showAppActionListSheet<_SourceWebVerifyAction>(
      context: context,
      title: '操作',
      message: menuUrl,
      showCancel: true,
      items: <AppActionListItem<_SourceWebVerifyAction>>[
        const AppActionListItem<_SourceWebVerifyAction>(
          value: _SourceWebVerifyAction.openInBrowser,
          icon: CupertinoIcons.globe,
          label: '浏览器打开',
        ),
        const AppActionListItem<_SourceWebVerifyAction>(
          value: _SourceWebVerifyAction.copyUrl,
          icon: CupertinoIcons.doc_on_doc,
          label: '拷贝 URL',
        ),
        const AppActionListItem<_SourceWebVerifyAction>(
          value: _SourceWebVerifyAction.fullScreen,
          icon: CupertinoIcons.fullscreen,
          label: '全屏',
        ),
        if (hasSource)
          const AppActionListItem<_SourceWebVerifyAction>(
            value: _SourceWebVerifyAction.disableSource,
            icon: CupertinoIcons.pause_circle,
            label: '禁用源',
            isDestructiveAction: true,
          ),
        if (hasSource)
          const AppActionListItem<_SourceWebVerifyAction>(
            value: _SourceWebVerifyAction.deleteSource,
            icon: CupertinoIcons.delete,
            label: '删除源',
            isDestructiveAction: true,
          ),
        const AppActionListItem<_SourceWebVerifyAction>(
          value: _SourceWebVerifyAction.reload,
          icon: CupertinoIcons.refresh,
          label: '刷新',
        ),
        const AppActionListItem<_SourceWebVerifyAction>(
          value: _SourceWebVerifyAction.importCookies,
          icon: CupertinoIcons.square_arrow_down,
          label: '导入 Cookie 到解析引擎',
        ),
        const AppActionListItem<_SourceWebVerifyAction>(
          value: _SourceWebVerifyAction.copyCookieHeader,
          icon: CupertinoIcons.doc_text,
          label: '复制 Cookie 值',
        ),
        const AppActionListItem<_SourceWebVerifyAction>(
          value: _SourceWebVerifyAction.clearCookie,
          icon: CupertinoIcons.delete_solid,
          label: '清空 WebView Cookie',
          isDestructiveAction: true,
        ),
      ],
    );
    if (action == null) return;
    switch (action) {
      case _SourceWebVerifyAction.openInBrowser:
        await _openInBrowser();
        return;
      case _SourceWebVerifyAction.copyUrl:
        await _copyBaseUrl();
        return;
      case _SourceWebVerifyAction.fullScreen:
        await _toggleFullScreen();
        return;
      case _SourceWebVerifyAction.disableSource:
        await _disableCurrentSource();
        return;
      case _SourceWebVerifyAction.deleteSource:
        await _confirmDeleteCurrentSource();
        return;
      case _SourceWebVerifyAction.reload:
        _controller.reload();
        return;
      case _SourceWebVerifyAction.importCookies:
        await _importCookies();
        return;
      case _SourceWebVerifyAction.copyCookieHeader:
        await _copyCookieHeader();
        return;
      case _SourceWebVerifyAction.clearCookie:
        final ok = await WebViewCookieBridge.clearAllCookies();
        await _showMessage(ok ? '已清空 Cookie' : '清空失败或不支持');
        return;
    }
  }

  Color _accentColor(BuildContext context) {
    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;
    return isDark
        ? AppDesignTokens.brandSecondary
        : AppDesignTokens.brandPrimary;
  }

  Widget _buildProgressBar(BuildContext context, {required bool showProgress}) {
    if (!showProgress) return const SizedBox.shrink();
    final factor =
        _progress <= 0 && _isLoading ? _progressMinFactor : (_progress / 100.0);
    return SizedBox(
      height: _progressBarHeight,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: CupertinoColors.systemGrey5.resolveFrom(context),
        ),
        child: Align(
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: factor.clamp(0.0, 1.0),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: _accentColor(context),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPageBody(BuildContext context, {required bool showProgress}) {
    return Column(
      children: [
        _buildProgressBar(context, showProgress: showProgress),
        if (_lastImportHint != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
            child: Text(
              _lastImportHint!,
              style: TextStyle(
                fontSize: 12,
                color: CupertinoColors.secondaryLabel.resolveFrom(context),
              ),
            ),
          ),
        Expanded(
          child: WebViewWidget(controller: _controller),
        ),
        if (!_isFullScreen)
          AppWebViewToolbar(
            canGoBack: _canGoBack,
            canGoForward: _canGoForward,
            isLoading: _isLoading,
            onBack: () => unawaited(_goBack()),
            onForward: () => unawaited(_goForward()),
            onReload: () => unawaited(_reloadOrStop()),
            onToggleFullScreen: () => unawaited(_toggleFullScreen()),
            onMore: _showMoreMenu,
          ),
      ],
    );
  }

  Widget _buildFullScreenOverlayControls(BuildContext context) {
    final bg = CupertinoColors.systemBackground.resolveFrom(context)
        .resolveFrom(context)
        .withValues(alpha: _fullScreenOverlayBgAlpha);
    final iconColor = CupertinoColors.label.resolveFrom(context);

    Widget buildIconButton({
      required IconData icon,
      required VoidCallback onTap,
    }) {
      return CupertinoButton(
        padding: EdgeInsets.zero,
        minimumSize: const Size(
            _fullScreenOverlayButtonSize, _fullScreenOverlayButtonSize),
        onPressed: onTap,
        child: Container(
          width: _fullScreenOverlayButtonSize,
          height: _fullScreenOverlayButtonSize,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(_fullScreenOverlayRadius),
          ),
          child: Icon(icon, size: _fullScreenOverlayIconSize, color: iconColor),
        ),
      );
    }

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
        child: Row(
          children: [
            buildIconButton(
              icon: CupertinoIcons.chevron_down,
              onTap: () => unawaited(_toggleFullScreen()),
            ),
            const Spacer(),
            buildIconButton(
              icon: CupertinoIcons.ellipsis,
              onTap: _showMoreMenu,
            ),
            const SizedBox(width: 8),
            buildIconButton(
              icon: CupertinoIcons.xmark,
              onTap: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final showProgress = _isLoading || (_progress > 0 && _progress < 100);
    return PopScope(
      // - 全屏时：返回用于退出全屏（避免“全屏无法返回”）
      // - WebView 可后退时：返回用于页面后退（对齐浏览器语义）
      // - WebView 不可后退时：允许路由正常 pop，保留 iOS 侧滑返回
      canPop: !_isFullScreen && !_canGoBack,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (_isFullScreen) {
          await _toggleFullScreen();
          return;
        }
        try {
          final canGoBack = await _controller.canGoBack();
          if (canGoBack) {
            await _controller.goBack();
            unawaited(_refreshNavState());
            return;
          }
        } catch (error, stackTrace) {
          _exceptionLogService.record(
            node: 'source.web_view.pop_go_back',
            message: '返回触发 WebView 后退失败',
            error: error,
            stackTrace: stackTrace,
            context: <String, dynamic>{
              'initialUrl': widget.initialUrl,
              'currentUrl': _currentUrl,
              'isFullScreen': _isFullScreen,
              'isLoading': _isLoading,
            },
          );
        }
        if (!context.mounted) return;
        Navigator.of(context).pop();
      },
      child: _isFullScreen
          ? CupertinoPageScaffold(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: SafeArea(
                      top: false,
                      bottom: false,
                      child:
                          _buildPageBody(context, showProgress: showProgress),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    top: 0,
                    child: _buildFullScreenOverlayControls(context),
                  ),
                ],
              ),
            )
          : AppCupertinoPageScaffold(
              title: '网页验证',
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppNavBarButton(
                    minimumSize: const Size(30, 30),
                    onPressed: _confirmAndClose,
                    child: const Icon(CupertinoIcons.check_mark),
                  ),
                  AppNavBarButton(
                    minimumSize: const Size(30, 30),
                    onPressed: _showMoreMenu,
                    child: const Icon(CupertinoIcons.ellipsis),
                  ),
                ],
              ),
              child: _buildPageBody(context, showProgress: showProgress),
            ),
    );
  }
}
