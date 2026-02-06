import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../core/services/webview_cookie_bridge.dart';
import '../services/rule_parser_engine.dart';

class SourceWebVerifyView extends StatefulWidget {
  final String initialUrl;

  const SourceWebVerifyView({
    super.key,
    required this.initialUrl,
  });

  @override
  State<SourceWebVerifyView> createState() => _SourceWebVerifyViewState();
}

class _SourceWebVerifyViewState extends State<SourceWebVerifyView> {
  late final WebViewController _controller;
  int _progress = 0;
  String _currentUrl = '';

  String? _lastImportHint;
  String? _lastImportCookieHeaderValue;

  @override
  void initState() {
    super.initState();
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
            setState(() => _currentUrl = url);
          },
          onUrlChange: (change) {
            final url = change.url;
            if (url == null) return;
            if (!mounted) return;
            setState(() => _currentUrl = url);
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.initialUrl));
  }

  Future<void> _showMessage(String message) async {
    if (!mounted) return;
    showCupertinoDialog(
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
    if (!Platform.isIOS) {
      await _showMessage('仅 iOS 支持从 WebView 导入 Cookie');
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
    await _showMessage('已复制 Cookie 值（可用于书源 header 的 Cookie 字段）');
  }

  @override
  Widget build(BuildContext context) {
    final progress = _progress;
    final showProgress = progress > 0 && progress < 100;
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('网页验证'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () {
            showCupertinoModalPopup(
              context: context,
              builder: (_) => CupertinoActionSheet(
                title: const Text('操作'),
                message: Text(
                  (_currentUrl.isEmpty ? widget.initialUrl : _currentUrl),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                actions: [
                  CupertinoActionSheetAction(
                    child: const Text('刷新'),
                    onPressed: () {
                      Navigator.of(context).pop();
                      _controller.reload();
                    },
                  ),
                  CupertinoActionSheetAction(
                    child: const Text('导入 Cookie 到解析引擎'),
                    onPressed: () async {
                      Navigator.of(context).pop();
                      await _importCookies();
                    },
                  ),
                  CupertinoActionSheetAction(
                    child: const Text('复制 Cookie 值'),
                    onPressed: () async {
                      Navigator.of(context).pop();
                      await _copyCookieHeader();
                    },
                  ),
                  CupertinoActionSheetAction(
                    isDestructiveAction: true,
                    child: const Text('清空 WebView Cookie'),
                    onPressed: () async {
                      Navigator.of(context).pop();
                      final ok = await WebViewCookieBridge.clearAllCookies();
                      await _showMessage(ok ? '已清空 Cookie' : '清空失败或不支持');
                    },
                  ),
                ],
                cancelButton: CupertinoActionSheetAction(
                  child: const Text('取消'),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            );
          },
          child: const Icon(CupertinoIcons.ellipsis),
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            if (showProgress)
              SizedBox(
                height: 2,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: CupertinoColors.systemGrey5.resolveFrom(context),
                  ),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: progress / 100.0,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: CupertinoColors.activeBlue.resolveFrom(context),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
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
          ],
        ),
      ),
    );
  }
}
