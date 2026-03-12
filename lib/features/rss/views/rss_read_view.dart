import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../app/widgets/app_cupertino_page_scaffold.dart';
import '../../../app/widgets/app_toast.dart';
import '../../../app/widgets/cupertino_bottom_dialog.dart';
import '../../../core/database/database_service.dart';
import '../../../core/database/repositories/rss_article_repository.dart';
import '../../../core/database/repositories/rss_source_repository.dart';
import '../../../core/database/repositories/rss_star_repository.dart';
import '../../../core/services/exception_log_service.dart';
import '../models/rss_article.dart';
import '../models/rss_source.dart';
import '../models/rss_star.dart';
import 'rss_view_helpers.dart';

enum _RssReadMenuAction {
  login,
  browserOpen,
}

enum _RssFavoriteDialogAction {
  cancel,
  confirm,
  delete,
}
class RssReadPlaceholderView extends StatefulWidget {
  const RssReadPlaceholderView({
    super.key,
    required this.title,
    required this.origin,
    this.link,
    this.repository,
  });

  final String title;
  final String origin;
  final String? link;
  final RssSourceRepository? repository;

  @override
  State<RssReadPlaceholderView> createState() => _RssReadPlaceholderViewState();
}

class _RssReadPlaceholderViewState extends State<RssReadPlaceholderView> {
  late final RssSourceRepository _repo;
  late final RssArticleRepository _articleRepo;
  late final RssStarRepository _starRepo;
  int _refreshVersion = 0;
  RssArticle? _rssArticle;
  RssStar? _rssStar;
  int _favoriteLoadVersion = 0;
  bool _favoriteActionRunning = false;
  FlutterTts? _readAloudTts;
  bool _readAloudTtsReady = false;
  bool _readAloudPlaying = false;

  @override
  void initState() {
    super.initState();
    _repo = widget.repository ?? RssSourceRepository(DatabaseService());
    _articleRepo = RssArticleRepository(DatabaseService());
    _starRepo = RssStarRepository(DatabaseService());
    _reloadFavoriteContext();
  }

  @override
  void dispose() {
    unawaited(_disposeReadAloudTts());
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant RssReadPlaceholderView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldOrigin = oldWidget.origin.trim();
    final oldLink = (oldWidget.link ?? '').trim();
    if (oldOrigin != _originKey || oldLink != _linkKey) {
      _reloadFavoriteContext();
    }
  }

  String get _originKey => widget.origin.trim();
  String get _linkKey => (widget.link ?? '').trim();

  RssSource? _resolveCurrentSource(List<RssSource>? sources) {
    final key = _originKey;
    if (key.isEmpty) return null;
    if (sources != null) {
      for (final source in sources) {
        if (source.sourceUrl.trim() == key) {
          return source;
        }
      }
    }
    return _repo.getByKey(key);
  }

  bool _canOpenLogin(RssSource? source) {
    return (source?.loginUrl ?? '').trim().isNotEmpty;
  }

  bool get _canShowFavoriteAction => _rssArticle != null;
  bool get _isInFavorites => _rssStar != null;

  String? _resolveShareTarget() {
    final currentLink = _linkKey;
    if (currentLink.isNotEmpty) {
      return currentLink;
    }
    final articleLink = (_rssArticle?.link ?? '').trim();
    if (articleLink.isNotEmpty) {
      return articleLink;
    }
    return null;
  }

  String? _resolveBrowserOpenTarget() {
    final currentLink = _linkKey;
    if (currentLink.isNotEmpty) {
      return currentLink;
    }
    final articleLink = (_rssArticle?.link ?? '').trim();
    if (articleLink.isNotEmpty) {
      return articleLink;
    }
    final origin = _originKey;
    if (origin.isNotEmpty) {
      return origin;
    }
    return null;
  }

  String _normalizeReadAloudText(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return '';
    final parsed = html_parser.parse(trimmed);
    final bodyText = parsed.body?.text ?? '';
    final documentText = parsed.documentElement?.text ?? '';
    final source = bodyText.trim().isNotEmpty ? bodyText : documentText;
    final lines = source
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList(growable: false);
    if (lines.isNotEmpty) {
      return lines.join('\n');
    }
    return trimmed;
  }

  String _resolveReadAloudText() {
    final candidates = <String?>[
      _rssArticle?.description,
      _rssArticle?.content,
      _rssArticle?.title,
      widget.title,
    ];
    for (final candidate in candidates) {
      final normalized = _normalizeReadAloudText(candidate ?? '');
      if (normalized.isNotEmpty) {
        return normalized;
      }
    }
    return '';
  }

  void _showToast(String message) {
    if (!mounted) return;
    unawaited(showAppToast(context, message: message));
  }

  Future<void> _reloadFavoriteContext() async {
    final loadVersion = ++_favoriteLoadVersion;
    final origin = _originKey;
    final link = _linkKey;
    if (origin.isEmpty || link.isEmpty) {
      if (!mounted || loadVersion != _favoriteLoadVersion) return;
      setState(() {
        _rssArticle = null;
        _rssStar = null;
      });
      return;
    }
    try {
      final star = await _starRepo.get(origin, link);
      final article =
          star?.toRssArticle() ?? await _articleRepo.get(origin, link);
      if (!mounted || loadVersion != _favoriteLoadVersion) return;
      setState(() {
        _rssStar = star;
        _rssArticle = article;
      });
    } catch (error, stackTrace) {
      if (!mounted || loadVersion != _favoriteLoadVersion) return;
      setState(() {
        _rssStar = null;
        _rssArticle = null;
      });
      ExceptionLogService().record(
        node: 'rss_read.menu_rss_star',
        message: '加载 RSS 收藏状态失败',
        error: error,
        stackTrace: stackTrace,
        context: <String, dynamic>{
          'origin': origin,
          'link': link,
        },
      );
    }
  }

  void _handleRefresh() {
    if (!mounted) return;
    setState(() {
      _refreshVersion += 1;
    });
  }

  Future<void> _handleShare() async {
    final target = _resolveShareTarget();
    if (target == null) {
      _showToast('Null url');
      return;
    }
    try {
      await SharePlus.instance.share(
        ShareParams(
          text: target,
          subject: '分享',
        ),
      );
    } catch (_) {
      // 对齐 legado Context.share(text)：分享异常静默吞掉，不追加提示。
    }
  }

  Future<void> _handleBrowserOpen() async {
    final target = _resolveBrowserOpenTarget();
    if (target == null) {
      _showToast('url null');
      return;
    }
    final uri = Uri.tryParse(target);
    if (uri == null) {
      ExceptionLogService().record(
        node: 'rss_read.menu_browser_open',
        message: 'RSS 阅读页浏览器打开失败（URL 解析失败）',
        context: <String, dynamic>{
          'origin': _originKey,
          'link': _linkKey,
          'target': target,
        },
      );
      _showToast('open url error');
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
        node: 'rss_read.menu_browser_open',
        message: 'RSS 阅读页浏览器打开失败（launchUrl=false）',
        context: <String, dynamic>{
          'origin': _originKey,
          'link': _linkKey,
          'target': target,
        },
      );
      _showToast('open url error');
    } catch (error, stackTrace) {
      ExceptionLogService().record(
        node: 'rss_read.menu_browser_open',
        message: 'RSS 阅读页浏览器打开失败',
        error: error,
        stackTrace: stackTrace,
        context: <String, dynamic>{
          'origin': _originKey,
          'link': _linkKey,
          'target': target,
        },
      );
      _showToast('open url error');
    }
  }

  Future<FlutterTts> _ensureReadAloudTtsReady() async {
    final existing = _readAloudTts;
    if (existing != null && _readAloudTtsReady) {
      return existing;
    }
    final tts = existing ?? FlutterTts();
    _readAloudTts ??= tts;
    if (!_readAloudTtsReady) {
      tts.setStartHandler(() {
        if (!mounted) return;
        setState(() {
          _readAloudPlaying = true;
        });
      });
      tts.setCompletionHandler(() {
        if (!mounted) return;
        setState(() {
          _readAloudPlaying = false;
        });
      });
      tts.setCancelHandler(() {
        if (!mounted) return;
        setState(() {
          _readAloudPlaying = false;
        });
      });
      tts.setErrorHandler((_) {
        if (!mounted) return;
        setState(() {
          _readAloudPlaying = false;
        });
      });
      await tts.awaitSpeakCompletion(true);
      _readAloudTtsReady = true;
    }
    return tts;
  }

  Future<void> _stopReadAloud() async {
    final tts = _readAloudTts;
    if (tts == null) return;
    try {
      await tts.stop();
    } catch (error, stackTrace) {
      ExceptionLogService().record(
        node: 'rss_read.menu_aloud',
        message: '停止 RSS 朗读失败',
        error: error,
        stackTrace: stackTrace,
        context: <String, dynamic>{
          'origin': _originKey,
          'link': _linkKey,
        },
      );
    }
    if (!mounted) return;
    setState(() {
      _readAloudPlaying = false;
    });
  }

  Future<void> _handleReadAloud() async {
    if (_readAloudPlaying) {
      await _stopReadAloud();
      return;
    }
    final text = _resolveReadAloudText();
    if (text.isEmpty) {
      return;
    }
    try {
      final tts = await _ensureReadAloudTtsReady();
      await tts.stop();
      final result = await tts.speak(text);
      final success = result == null || result == 1 || result == true;
      if (!success) {
        ExceptionLogService().record(
          node: 'rss_read.menu_aloud',
          message: '启动 RSS 朗读失败',
          context: <String, dynamic>{
            'origin': _originKey,
            'link': _linkKey,
            'ttsResult': result.toString(),
          },
        );
        return;
      }
      if (!mounted) return;
      setState(() {
        _readAloudPlaying = true;
      });
    } catch (error, stackTrace) {
      ExceptionLogService().record(
        node: 'rss_read.menu_aloud',
        message: '启动 RSS 朗读失败',
        error: error,
        stackTrace: stackTrace,
        context: <String, dynamic>{
          'origin': _originKey,
          'link': _linkKey,
        },
      );
    }
  }

  Future<void> _disposeReadAloudTts() async {
    final tts = _readAloudTts;
    _readAloudTts = null;
    _readAloudTtsReady = false;
    _readAloudPlaying = false;
    if (tts == null) return;
    try {
      await tts.stop();
    } catch (_) {
      // 页面销毁阶段与 legado 同义静默清理，不额外提示。
    }
  }

  Future<void> _handleFavoriteAction() async {
    final article = _rssArticle;
    if (article == null || _favoriteActionRunning) return;
    setState(() {
      _favoriteActionRunning = true;
    });
    try {
      if (_rssStar == null) {
        final createdStar = rssStarFromArticle(article);
        await _starRepo.upsert(createdStar);
        if (!mounted) return;
        setState(() {
          _rssStar = createdStar;
          _rssArticle = article.copyWith(
            title: createdStar.title,
            group: createdStar.group,
          );
        });
      }
    } catch (error, stackTrace) {
      ExceptionLogService().record(
        node: 'rss_read.menu_rss_star',
        message: '添加 RSS 收藏失败',
        error: error,
        stackTrace: stackTrace,
        context: <String, dynamic>{
          'origin': article.origin,
          'link': article.link,
        },
      );
      return;
    } finally {
      if (mounted) {
        setState(() {
          _favoriteActionRunning = false;
        });
      }
    }
    if (!mounted) return;
    await _openFavoriteDialog();
  }

  Future<void> _openFavoriteDialog() async {
    final article = _rssArticle;
    if (article == null || !mounted) return;
    final titleController = TextEditingController(text: article.title);
    final groupController = TextEditingController(text: article.group);
    try {
      final action = await showCupertinoBottomSheetDialog<_RssFavoriteDialogAction>(
        context: context,
        builder: (dialogContext) => CupertinoAlertDialog(
          title: const Text('收藏设置'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              CupertinoTextField(
                controller: titleController,
                placeholder: '标题',
              ),
              const SizedBox(height: 8),
              CupertinoTextField(
                controller: groupController,
                placeholder: '分组',
              ),
            ],
          ),
          actions: [
            CupertinoDialogAction(
              isDestructiveAction: true,
              onPressed: () {
                Navigator.of(dialogContext)
                    .pop(_RssFavoriteDialogAction.delete);
              },
              child: const Text('删除收藏'),
            ),
            CupertinoDialogAction(
              onPressed: () {
                Navigator.of(dialogContext)
                    .pop(_RssFavoriteDialogAction.cancel);
              },
              child: const Text('取消'),
            ),
            CupertinoDialogAction(
              onPressed: () {
                Navigator.of(dialogContext)
                    .pop(_RssFavoriteDialogAction.confirm);
              },
              child: const Text('确定'),
            ),
          ],
        ),
      );
      switch (action) {
        case _RssFavoriteDialogAction.delete:
          await _deleteFavorite();
          break;
        case _RssFavoriteDialogAction.confirm:
          final current = _rssArticle;
          if (current == null) return;
          var nextTitle = current.title;
          final editedTitle = titleController.text;
          if (editedTitle.trim().isNotEmpty) {
            nextTitle = editedTitle;
          }
          var nextGroup = current.group;
          final editedGroup = groupController.text;
          if (editedGroup.trim().isNotEmpty) {
            nextGroup = editedGroup;
          }
          await _updateFavorite(title: nextTitle, group: nextGroup);
          break;
        case _RssFavoriteDialogAction.cancel:
        case null:
          break;
      }
    } finally {
      titleController.dispose();
      groupController.dispose();
    }
  }

  Future<void> _updateFavorite({
    required String title,
    required String group,
  }) async {
    final current = _rssArticle;
    if (current == null) return;
    final updatedArticle = current.copyWith(
      title: title,
      group: group,
    );
    final updatedStar = rssStarFromArticle(updatedArticle);
    try {
      await _starRepo.update(updatedStar);
      if (!mounted) return;
      setState(() {
        _rssArticle = updatedArticle;
        _rssStar = updatedStar;
      });
    } catch (error, stackTrace) {
      ExceptionLogService().record(
        node: 'rss_read.menu_rss_star',
        message: '更新 RSS 收藏失败',
        error: error,
        stackTrace: stackTrace,
        context: <String, dynamic>{
          'origin': updatedArticle.origin,
          'link': updatedArticle.link,
        },
      );
    }
  }

  Future<void> _deleteFavorite() async {
    final star = _rssStar;
    if (star == null) return;
    try {
      await _starRepo.delete(star.origin, star.link);
      if (!mounted) return;
      setState(() {
        _rssStar = null;
      });
    } catch (error, stackTrace) {
      ExceptionLogService().record(
        node: 'rss_read.menu_rss_star',
        message: '删除 RSS 收藏失败',
        error: error,
        stackTrace: stackTrace,
        context: <String, dynamic>{
          'origin': star.origin,
          'link': star.link,
        },
      );
    }
  }

  String _readMenuActionText(_RssReadMenuAction action) {
    switch (action) {
      case _RssReadMenuAction.login:
        return '登录';
      case _RssReadMenuAction.browserOpen:
        return '浏览器打开';
    }
  }

  List<_RssReadMenuAction> _buildReadMenuActions(RssSource? source) {
    final actions = <_RssReadMenuAction>[];
    if (_canOpenLogin(source)) {
      actions.add(_RssReadMenuAction.login);
    }
    actions.add(_RssReadMenuAction.browserOpen);
    return actions;
  }

  Future<void> _showMoreMenu(RssSource? source) async {
    if (!mounted) return;
    final actions = _buildReadMenuActions(source);
    final selected = await showCupertinoBottomSheetDialog<_RssReadMenuAction>(
      context: context,
      barrierDismissible: true,
      builder: (sheetContext) => CupertinoActionSheet(
        actions: actions
            .map(
              (action) => CupertinoActionSheetAction(
                onPressed: () {
                  Navigator.pop(sheetContext, action);
                },
                child: Text(_readMenuActionText(action)),
              ),
            )
            .toList(growable: false),
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(sheetContext),
          child: const Text('取消'),
        ),
      ),
    );
    if (selected == null) return;
    switch (selected) {
      case _RssReadMenuAction.login:
        if (source == null) return;
        await _openSourceLogin(source);
        break;
      case _RssReadMenuAction.browserOpen:
        await _handleBrowserOpen();
        break;
    }
  }

  Future<void> _openSourceLogin(RssSource source) async {
    if (!mounted) return;
    await openRssSourceLogin(
      context: context,
      repository: _repo,
      source: source,
    );
  }

  Widget _buildTrailingAction(RssSource? source) {
    final showFavorite = _canShowFavoriteAction;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CupertinoButton(
          padding: EdgeInsets.zero,
          minimumSize: const Size(28, 28),
          onPressed: _handleRefresh,
          child: const Icon(
            CupertinoIcons.refresh,
            size: 19,
          ),
        ),
        if (showFavorite) ...[
          const SizedBox(width: 6),
          CupertinoButton(
            padding: EdgeInsets.zero,
            minimumSize: const Size(28, 28),
            onPressed: _favoriteActionRunning ? null : _handleFavoriteAction,
            child: Icon(
              _isInFavorites ? CupertinoIcons.star_fill : CupertinoIcons.star,
              size: 19,
            ),
          ),
        ],
        const SizedBox(width: 6),
        CupertinoButton(
          padding: EdgeInsets.zero,
          minimumSize: const Size(28, 28),
          onPressed: _handleShare,
          child: const Icon(
            CupertinoIcons.share,
            size: 19,
          ),
        ),
        const SizedBox(width: 6),
        CupertinoButton(
          padding: EdgeInsets.zero,
          minimumSize: const Size(28, 28),
          onPressed: _handleReadAloud,
          child: Icon(
            _readAloudPlaying
                ? CupertinoIcons.stop_circle
                : CupertinoIcons.volume_up,
            size: 19,
          ),
        ),
        const SizedBox(width: 6),
        CupertinoButton(
          padding: EdgeInsets.zero,
          minimumSize: const Size(28, 28),
          onPressed: () => _showMoreMenu(source),
          child: const Icon(CupertinoIcons.ellipsis_circle, size: 20),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<RssSource>>(
      stream: _repo.watchAllSources(),
      builder: (context, snapshot) {
        final source = _resolveCurrentSource(snapshot.data);
        return AppCupertinoPageScaffold(
          title: widget.title.isEmpty ? 'RSS 阅读' : widget.title,
          trailing: _buildTrailingAction(source),
          child: _RssReadContentView(
            refreshVersion: _refreshVersion,
            article: _rssArticle,
            link: _linkKey,
            origin: _originKey,
          ),
        );
      },
    );
  }
}

/// RSS 阅读内容视图：优先用 WebView 加载 link；无 link 时渲染 HTML 内容。
class _RssReadContentView extends StatefulWidget {
  const _RssReadContentView({
    required this.refreshVersion,
    required this.article,
    required this.link,
    required this.origin,
  });

  final int refreshVersion;
  final RssArticle? article;
  final String link;
  final String origin;

  @override
  State<_RssReadContentView> createState() => _RssReadContentViewState();
}

class _RssReadContentViewState extends State<_RssReadContentView> {
  late final WebViewController _controller;
  bool _isLoading = true;
  String? _lastLoadedKey;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) {
          if (mounted) setState(() => _isLoading = true);
        },
        onPageFinished: (_) {
          if (mounted) setState(() => _isLoading = false);
        },
        onWebResourceError: (_) {
          if (mounted) setState(() => _isLoading = false);
        },
      ));
    _loadContent();
  }

  @override
  void didUpdateWidget(covariant _RssReadContentView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newKey =
        '${widget.refreshVersion}::${widget.link}::${widget.article?.link}';
    if (_lastLoadedKey != newKey) _loadContent();
  }

  void _loadContent() {
    final key =
        '${widget.refreshVersion}::${widget.link}::${widget.article?.link}';
    _lastLoadedKey = key;
    final link = widget.link.trim();
    if (link.isNotEmpty) {
      _controller.loadRequest(Uri.parse(link));
      return;
    }
    final article = widget.article;
    if (article == null) {
      _controller.loadHtmlString('<html><body></body></html>');
      return;
    }
    final content = (article.content?.trim().isNotEmpty == true
            ? article.content!
            : article.description) ??
        '';
    final html = _buildHtml(
      title: article.title,
      content: content,
      baseUrl: widget.origin,
    );
    _controller.loadHtmlString(
      html,
      baseUrl: widget.origin.isNotEmpty ? widget.origin : null,
    );
  }

  String _buildHtml({
    required String title,
    required String content,
    required String baseUrl,
  }) {
    final escapedTitle = title
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;');
    return '''
<!DOCTYPE html><html><head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1.0,user-scalable=yes">
<style>
body{font-family:-apple-system,sans-serif;font-size:16px;line-height:1.6;color:#1c1c1e;padding:16px;margin:0;word-wrap:break-word;}
h1{font-size:20px;font-weight:700;margin-bottom:12px;}
img{max-width:100%;height:auto;border-radius:6px;}
a{color:#007aff;}
@media(prefers-color-scheme:dark){body{background:#1c1c1e;color:#e5e5ea;}a{color:#0a84ff;}}
</style></head><body>
${title.isNotEmpty ? '<h1>$escapedTitle</h1>' : ''}
$content
</body></html>''';
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        WebViewWidget(controller: _controller),
        if (_isLoading)
          const Positioned(
            top: 12,
            left: 0,
            right: 0,
            child: Center(child: CupertinoActivityIndicator()),
          ),
      ],
    );
  }
}
