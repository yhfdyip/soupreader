import 'package:flutter/cupertino.dart';

import '../../../app/widgets/cupertino_bottom_dialog.dart';
import '../../source/models/book_source.dart';
import '../../source/services/source_login_url_resolver.dart';
import '../../source/views/source_login_form_view.dart';
import '../../source/views/source_login_webview_view.dart';
import '../../../core/database/repositories/rss_source_repository.dart';
import '../models/rss_article.dart';
import '../models/rss_source.dart';
import '../models/rss_star.dart';

BookSource bookSourceFromRssSource(RssSource source) {
  return BookSource(
    bookSourceUrl: source.sourceUrl,
    bookSourceName: source.sourceName,
    bookSourceGroup: source.sourceGroup,
    customOrder: source.customOrder,
    enabled: source.enabled,
    enabledExplore: false,
    jsLib: source.jsLib,
    enabledCookieJar: source.enabledCookieJar ?? true,
    concurrentRate: source.concurrentRate,
    header: source.header,
    loginUrl: source.loginUrl,
    loginUi: source.loginUi,
    loginCheckJs: source.loginCheckJs,
    coverDecodeJs: source.coverDecodeJs,
    bookSourceComment: source.sourceComment,
    variableComment: source.variableComment,
    lastUpdateTime: source.lastUpdateTime,
    respondTime: 180000,
    weight: 0,
  );
}

RssStar rssStarFromArticle(
  RssArticle article, {
  int? starTime,
}) {
  return RssStar(
    origin: article.origin,
    sort: article.sort,
    title: article.title,
    starTime: starTime ?? DateTime.now().millisecondsSinceEpoch,
    link: article.link,
    pubDate: article.pubDate,
    description: article.description,
    content: article.content,
    image: article.image,
    group: article.group,
    variable: article.variable,
  );
}

Future<void> showRssLoginMessage(
  BuildContext context,
  String message,
) async {
  if (!context.mounted) return;
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

Future<void> openRssSourceLogin({
  required BuildContext context,
  required RssSourceRepository repository,
  required RssSource source,
}) async {
  final current = repository.getByKey(source.sourceUrl) ?? source;
  final loginSource = bookSourceFromRssSource(current);
  final hasLoginUi = (current.loginUi ?? '').trim().isNotEmpty;

  if (hasLoginUi) {
    if (!context.mounted) return;
    await Navigator.of(context).push<void>(
      CupertinoPageRoute<void>(
        builder: (_) => SourceLoginFormView(source: loginSource),
      ),
    );
    return;
  }

  final resolvedUrl = SourceLoginUrlResolver.resolve(
    baseUrl: current.sourceUrl,
    loginUrl: current.loginUrl ?? '',
  );
  if (resolvedUrl.isEmpty) {
    await showRssLoginMessage(context, '当前源未配置登录地址');
    return;
  }
  final uri = Uri.tryParse(resolvedUrl);
  final scheme = uri?.scheme.toLowerCase();
  if (scheme != 'http' && scheme != 'https') {
    await showRssLoginMessage(context, '登录地址不是有效网页地址');
    return;
  }

  if (!context.mounted) return;
  await Navigator.of(context).push<void>(
    CupertinoPageRoute<void>(
      builder: (_) => SourceLoginWebViewView(
        source: loginSource,
        initialUrl: resolvedUrl,
      ),
    ),
  );
}
