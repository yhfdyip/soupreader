import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../../../app/widgets/app_toast.dart';
import '../../../app/widgets/app_action_list_sheet.dart';
import '../../../app/widgets/cupertino_bottom_dialog.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../app/theme/design_tokens.dart';
import '../../../app/widgets/app_cupertino_page_scaffold.dart';
import '../../../app/widgets/app_nav_bar_button.dart';
import '../../../app/widgets/app_webview_toolbar.dart';
import '../../../core/services/exception_log_service.dart';
import '../../../core/services/webview_cookie_bridge.dart';
import '../models/book_source.dart';
import '../services/rule_parser_engine.dart';

/// 对标 legado `source_webview_login/menu_ok`：
/// - 顶栏一级动作“确认”
/// - 点击后提示“正在打开首页，成功自动返回主界面”
/// - 重载首页并在页面加载完成后自动返回
/// - 页面加载期间持续同步 Cookie 到解析引擎 CookieJar
class SourceLoginWebViewView extends StatefulWidget {
  final BookSource source;
  final String initialUrl;

  const SourceLoginWebViewView({
    super.key,
    required this.source,
    required this.initialUrl,
  });

  @override
  State<SourceLoginWebViewView> createState() => _SourceLoginWebViewViewState();
}

enum _SourceLoginWebviewAction {
  openInBrowser,
  copyUrl,
  reload,
  clearCookie,
}

class _SourceLoginWebViewViewState extends State<SourceLoginWebViewView> {
  static const String _checkHint = '正在打开首页，成功自动返回主界面';
  static const String _defaultUserAgent =
      'Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) '
      'AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.0 Mobile/15E148 '
      'Safari/604.1';
  static const double _progressBarHeight = 2;
  static const double _progressMinFactor = 0.08;

  late final WebViewController _controller;
  late final Map<String, String> _headerMap;
  late final String _initialUrl;
  late final ExceptionLogService _exceptionLogService;

  bool _checking = false;
  bool _closing = false;
  int _progress = 0;
  bool _isLoading = true;
  bool _canGoBack = false;
  bool _canGoForward = false;
  String _currentUrl = '';
  bool _navStateRefreshErrorLogged = false;
  bool _cookieFromJsErrorLogged = false;

  @override
  void initState() {
    super.initState();
    _initialUrl = widget.initialUrl.trim();
    _headerMap = _buildHeaderMap(widget.source.header);
    _exceptionLogService = ExceptionLogService();

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (progress) {
            if (!mounted) return;
            setState(() => _progress = progress);
          },
          onPageStarted: (url) {
            if (!mounted) return;
            setState(() {
              _isLoading = true;
              _currentUrl = url;
            });
            unawaited(_syncCookies(url));
            unawaited(_refreshNavState());
          },
          onPageFinished: (url) {
            if (!mounted) return;
            setState(() {
              _isLoading = false;
              _currentUrl = url;
            });
            unawaited(_handlePageFinished(url));
            unawaited(_refreshNavState());
          },
          onUrlChange: (change) {
            final url = change.url;
            if (url == null) return;
            if (!mounted) return;
            setState(() => _currentUrl = url);
            unawaited(_refreshNavState());
          },
          onNavigationRequest: (request) async {
            final uri = Uri.tryParse(request.url);
            final scheme = uri?.scheme.toLowerCase();
            if (scheme == 'http' || scheme == 'https') {
              return NavigationDecision.navigate;
            }
            if (uri == null) return NavigationDecision.prevent;
            final allowed = await _confirmOpenExternalApp(uri);
            if (allowed) {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            }
            return NavigationDecision.prevent;
          },
        ),
      );

    if (_initialUrl.isNotEmpty) {
      _currentUrl = _initialUrl;
      unawaited(_loadUrl(_initialUrl));
    }
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
      if (_navStateRefreshErrorLogged) return;
      _navStateRefreshErrorLogged = true;
      _exceptionLogService.record(
        node: 'source.webview_login.refresh_nav_state',
        message: '刷新 WebView 导航状态失败',
        error: error,
        stackTrace: stackTrace,
        context: <String, dynamic>{
          'sourceKey': widget.source.bookSourceUrl,
          'initialUrl': _initialUrl,
          'currentUrl': _currentUrl,
          'isLoading': _isLoading,
        },
      );
    }
  }

  Future<void> _goBack() async {
    if (!await _controller.canGoBack()) return;
    await _controller.goBack();
  }

  Future<void> _goForward() async {
    if (!await _controller.canGoForward()) return;
    await _controller.goForward();
  }

  Future<void> _reloadOrStop() async {
    if (_isLoading) {
      try {
        await _controller.runJavaScript('window.stop();');
      } catch (error, stackTrace) {
        _exceptionLogService.record(
          node: 'source.webview_login.stop_loading',
          message: '停止加载失败（window.stop）',
          error: error,
          stackTrace: stackTrace,
          context: <String, dynamic>{
            'sourceKey': widget.source.bookSourceUrl,
            'initialUrl': _initialUrl,
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
    await showCupertinoBottomDialog<void>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: const Text('提示'),
        content: Text('\n$message'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('好'),
          ),
        ],
      ),
    );
  }

  Future<void> _openInBrowser() async {
    final raw =
        _currentUrl.trim().isNotEmpty ? _currentUrl.trim() : _initialUrl;
    final uri = Uri.tryParse(raw);
    final scheme = uri?.scheme.toLowerCase();
    if (uri == null || (scheme != 'http' && scheme != 'https')) {
      _exceptionLogService.record(
        node: 'source.webview_login.menu_open_in_browser',
        message: '浏览器打开失败（URL 解析失败）',
        context: <String, dynamic>{
          'sourceKey': widget.source.bookSourceUrl,
          'target': raw,
          'initialUrl': _initialUrl,
          'currentUrl': _currentUrl,
        },
      );
      await _showMessage('打开失败');
      return;
    }
    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (launched) return;
      _exceptionLogService.record(
        node: 'source.webview_login.menu_open_in_browser',
        message: '浏览器打开失败（launchUrl=false）',
        context: <String, dynamic>{
          'sourceKey': widget.source.bookSourceUrl,
          'target': raw,
          'initialUrl': _initialUrl,
          'currentUrl': _currentUrl,
        },
      );
      await _showMessage('打开失败');
    } catch (error, stackTrace) {
      _exceptionLogService.record(
        node: 'source.webview_login.menu_open_in_browser',
        message: '浏览器打开失败',
        error: error,
        stackTrace: stackTrace,
        context: <String, dynamic>{
          'sourceKey': widget.source.bookSourceUrl,
          'target': raw,
          'initialUrl': _initialUrl,
          'currentUrl': _currentUrl,
        },
      );
      await _showMessage('打开失败');
    }
  }

  Future<void> _copyUrl() async {
    final url =
        _currentUrl.trim().isNotEmpty ? _currentUrl.trim() : _initialUrl;
    if (url.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: url));
    unawaited(showAppToast(context, message: '已复制 URL'));
  }

  Future<void> _showMoreMenu() async {
    if (!mounted) return;
    final menuUrl = (_currentUrl.isEmpty ? _initialUrl : _currentUrl);
    final action = await showAppActionListSheet<_SourceLoginWebviewAction>(
      context: context,
      title: '操作',
      message: menuUrl,
      showCancel: true,
      items: const [
        AppActionListItem<_SourceLoginWebviewAction>(
          value: _SourceLoginWebviewAction.openInBrowser,
          icon: CupertinoIcons.globe,
          label: '浏览器打开',
        ),
        AppActionListItem<_SourceLoginWebviewAction>(
          value: _SourceLoginWebviewAction.copyUrl,
          icon: CupertinoIcons.doc_on_doc,
          label: '拷贝 URL',
        ),
        AppActionListItem<_SourceLoginWebviewAction>(
          value: _SourceLoginWebviewAction.reload,
          icon: CupertinoIcons.refresh,
          label: '刷新',
        ),
        AppActionListItem<_SourceLoginWebviewAction>(
          value: _SourceLoginWebviewAction.clearCookie,
          icon: CupertinoIcons.delete,
          label: '清空 WebView Cookie',
          isDestructiveAction: true,
        ),
      ],
    );
    if (action == null) return;
    switch (action) {
      case _SourceLoginWebviewAction.openInBrowser:
        await _openInBrowser();
        return;
      case _SourceLoginWebviewAction.copyUrl:
        await _copyUrl();
        return;
      case _SourceLoginWebviewAction.reload:
        unawaited(_reloadOrStop());
        return;
      case _SourceLoginWebviewAction.clearCookie:
        final ok = await WebViewCookieBridge.clearAllCookies();
        await _showMessage(ok ? '已清空 Cookie' : '清空失败或不支持');
        return;
    }
  }

  Future<void> _loadUrl(String url) async {
    final uri = Uri.tryParse(url);
    final scheme = uri?.scheme.toLowerCase();
    if (uri == null || (scheme != 'http' && scheme != 'https')) {
      _exceptionLogService.record(
        node: 'source.webview_login.load_url',
        message: '加载 URL 失败（URL 无效）',
        context: <String, dynamic>{
          'sourceKey': widget.source.bookSourceUrl,
          'target': url,
          'initialUrl': _initialUrl,
          'currentUrl': _currentUrl,
        },
      );
      return;
    }
    await _controller.loadRequest(uri, headers: _headerMap);
  }

  Future<void> _handlePageFinished(String url) async {
    await _syncCookies(url);
    if (!mounted || !_checking || _closing) return;
    _closing = true;
    Navigator.of(context).pop();
  }

  Future<void> _confirmAndCheck() async {
    if (_checking) return;
    if (_initialUrl.isEmpty) return;
    if (!mounted) return;
    setState(() {
      _checking = true;
    });
    await _loadUrl(_initialUrl);
  }

  Future<bool> _confirmOpenExternalApp(Uri uri) async {
    if (!mounted) return false;
    // 对齐 legado WebViewLoginFragment：
    // 非 http(s) 仅二次确认是否跳转其它应用，不提供额外管理动作。
    final result = await showCupertinoBottomDialog<bool>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: const Text('跳转其它应用'),
        content: Text('\n${uri.toString()}'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('确认'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Map<String, String> _buildHeaderMap(String? rawHeader) {
    final headers = _parseHeaderMap(rawHeader);
    headers.putIfAbsent('User-Agent', () => _defaultUserAgent);
    return headers;
  }

  Map<String, String> _parseHeaderMap(String? rawHeader) {
    final text = (rawHeader ?? '').trim();
    if (text.isEmpty) return <String, String>{};

    dynamic payload = text;
    for (var i = 0; i < 2; i++) {
      if (payload is! String) break;
      final current = payload.trim();
      if (current.isEmpty) return <String, String>{};
      if (!(current.startsWith('{') && current.endsWith('}')) &&
          !(current.startsWith('"') && current.endsWith('"'))) {
        break;
      }
      try {
        payload = jsonDecode(current);
      } catch (_) {
        break;
      }
    }

    if (payload is Map) {
      final out = <String, String>{};
      payload.forEach((key, value) {
        if (key == null || value == null) return;
        final k = key.toString().trim();
        if (k.isEmpty) return;
        out[k] = value.toString();
      });
      return out;
    }

    if (payload is String) {
      final out = <String, String>{};
      final lines = payload.split(RegExp(r'[\r\n]+'));
      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.isEmpty) continue;
        final index = trimmed.indexOf(':');
        if (index <= 0) continue;
        final key = trimmed.substring(0, index).trim();
        final value = trimmed.substring(index + 1).trim();
        if (key.isEmpty) continue;
        out[key] = value;
      }
      return out;
    }

    return <String, String>{};
  }

  Future<void> _syncCookies(String rawUrl) async {
    final uri = Uri.tryParse(rawUrl);
    if (uri == null || uri.host.trim().isEmpty) return;

    try {
      final cookies = await _readCookies(uri);
      if (cookies.isEmpty) return;

      await RuleParserEngine.saveCookiesForUrl(uri.toString(), cookies);

      final sourceBaseUrl = _resolveSourceBaseUrl();
      if (sourceBaseUrl != null && sourceBaseUrl != uri.toString()) {
        await RuleParserEngine.saveCookiesForUrl(sourceBaseUrl, cookies);
      }
    } catch (error, stackTrace) {
      ExceptionLogService().record(
        node: 'source.webview_login.cookie_sync',
        message: '同步 WebView Cookie 失败',
        error: error,
        stackTrace: stackTrace,
        context: <String, dynamic>{
          'sourceKey': widget.source.bookSourceUrl,
          'currentUrl': rawUrl,
        },
      );
    }
  }

  Future<List<Cookie>> _readCookies(Uri uri) async {
    final cookies = await WebViewCookieBridge.getCookiesForUrl(uri.toString());
    if (cookies.isNotEmpty) return cookies;
    return _readCookiesFromJs(uri);
  }

  Future<List<Cookie>> _readCookiesFromJs(Uri uri) async {
    try {
      final raw =
          await _controller.runJavaScriptReturningResult('document.cookie');
      final cookieHeader = _normalizeJsResult(raw).trim();
      if (cookieHeader.isEmpty) return const <Cookie>[];
      return _parseCookieHeader(cookieHeader, uri.host);
    } catch (error, stackTrace) {
      if (!_cookieFromJsErrorLogged) {
        _cookieFromJsErrorLogged = true;
        _exceptionLogService.record(
          node: 'source.webview_login.cookie_read_js',
          message: '读取 document.cookie 失败',
          error: error,
          stackTrace: stackTrace,
          context: <String, dynamic>{
            'sourceKey': widget.source.bookSourceUrl,
            'host': uri.host,
            'currentUrl': _currentUrl,
          },
        );
      }
      return const <Cookie>[];
    }
  }

  String _normalizeJsResult(Object raw) {
    final text = raw.toString().trim();
    if (text.isEmpty) return '';
    if ((text.startsWith('"') && text.endsWith('"')) ||
        (text.startsWith("'") && text.endsWith("'"))) {
      try {
        final decoded = jsonDecode(text);
        if (decoded is String) return decoded;
      } catch (_) {
        return text.substring(1, text.length - 1);
      }
    }
    return text;
  }

  List<Cookie> _parseCookieHeader(String header, String host) {
    final out = <Cookie>[];
    final parts = header.split(';');
    for (final part in parts) {
      final pair = part.trim();
      if (pair.isEmpty) continue;
      final index = pair.indexOf('=');
      if (index <= 0) continue;
      final name = pair.substring(0, index).trim();
      if (name.isEmpty) continue;
      final value = pair.substring(index + 1).trim();
      final cookie = Cookie(name, value);
      cookie.domain = host;
      cookie.path = '/';
      out.add(cookie);
    }
    return out;
  }

  String? _resolveSourceBaseUrl() {
    final sourceKey = widget.source.bookSourceUrl.trim();
    if (sourceKey.isEmpty) return null;
    final first = sourceKey.split(',').first.trim();
    final uri = Uri.tryParse(first);
    if (uri == null || !uri.hasScheme || uri.host.trim().isEmpty) {
      return null;
    }
    return uri.toString();
  }

  Color _accentColor(BuildContext context) {
    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;
    return isDark
        ? AppDesignTokens.brandSecondary
        : AppDesignTokens.brandPrimary;
  }

  @override
  Widget build(BuildContext context) {
    final progress = _progress;
    final showProgress = _isLoading || (progress > 0 && progress < 100);
    final sourceName = widget.source.bookSourceName.trim();
    final title = sourceName.isEmpty ? '登录' : '登录 $sourceName';

    return AppCupertinoPageScaffold(
      title: title,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppNavBarButton(
            minimumSize: const Size(30, 30),
            onPressed: _showMoreMenu,
            child: const Icon(CupertinoIcons.ellipsis),
          ),
          AppNavBarButton(
            onPressed: _confirmAndCheck,
            child: const Text('确认'),
            minimumSize: const Size(30, 30),
          ),
        ],
      ),
      child: Column(
        children: [
          if (showProgress)
            SizedBox(
              height: _progressBarHeight,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: CupertinoColors.systemGrey5.resolveFrom(context),
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: (_progress <= 0 && _isLoading)
                        ? _progressMinFactor
                        : (progress / 100.0),
                    child: DecoratedBox(
                      decoration: BoxDecoration(color: _accentColor(context)),
                    ),
                  ),
                ),
              ),
            ),
          if (_checking)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
              child: Text(
                _checkHint,
                style: TextStyle(
                  fontSize: 12,
                  color: CupertinoColors.secondaryLabel.resolveFrom(context),
                ),
              ),
            ),
          Expanded(
            child: WebViewWidget(controller: _controller),
          ),
          AppWebViewToolbar(
            canGoBack: _canGoBack,
            canGoForward: _canGoForward,
            isLoading: _isLoading,
            onBack: () => unawaited(_goBack()),
            onForward: () => unawaited(_goForward()),
            onReload: () => unawaited(_reloadOrStop()),
            onMore: _showMoreMenu,
          ),
        ],
      ),
    );
  }
}
