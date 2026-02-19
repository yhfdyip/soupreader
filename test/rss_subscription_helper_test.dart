import 'package:flutter_test/flutter_test.dart';
import 'package:soupreader/core/services/js_runtime.dart';
import 'package:soupreader/features/rss/models/rss_source.dart';
import 'package:soupreader/features/rss/services/rss_subscription_helper.dart';

RssSource _source({
  required String url,
  required String name,
  bool enabled = true,
  bool singleUrl = false,
  String? group,
  String? comment,
  String? sortUrl,
  String? jsLib,
  int customOrder = 0,
}) {
  return RssSource(
    sourceUrl: url,
    sourceName: name,
    enabled: enabled,
    singleUrl: singleUrl,
    sourceGroup: group,
    sourceComment: comment,
    sortUrl: sortUrl,
    jsLib: jsLib,
    customOrder: customOrder,
  );
}

class _FakeJsRuntime implements JsRuntime {
  _FakeJsRuntime(this._onEvaluate);

  final String Function(String script) _onEvaluate;

  @override
  String evaluate(String script) => _onEvaluate(script);
}

void main() {
  test('filterEnabledSourcesByQuery 对齐 upRssFlowJob 分支语义', () {
    final all = <RssSource>[
      _source(
        url: 'https://a.example/rss',
        name: '科技日报',
        group: '科技',
        enabled: true,
        customOrder: 2,
      ),
      _source(
        url: 'https://b.example/rss',
        name: '体育快讯',
        group: '体育',
        enabled: true,
        customOrder: 1,
      ),
      _source(
        url: 'https://c.example/rss',
        name: '禁用源',
        group: '科技',
        enabled: false,
        customOrder: 0,
      ),
    ];

    final allEnabled = RssSubscriptionHelper.filterEnabledSourcesByQuery(
      all,
      '',
    );
    expect(allEnabled.map((e) => e.sourceName), <String>['体育快讯', '科技日报']);

    final byGroup = RssSubscriptionHelper.filterEnabledSourcesByQuery(
      all,
      RssSubscriptionHelper.buildGroupQuery('科技'),
    );
    expect(byGroup.map((e) => e.sourceName), <String>['科技日报']);

    final byKeyword = RssSubscriptionHelper.filterEnabledSourcesByQuery(
      all,
      '体育',
    );
    expect(byKeyword.map((e) => e.sourceName), <String>['体育快讯']);
  });

  test('decideOpenAction 在 non-singleUrl 时进入文章列表链路', () {
    final source = _source(
      url: 'https://s.example/rss',
      name: '普通订阅源',
      singleUrl: false,
    );
    final decision = RssSubscriptionHelper.decideOpenAction(source);
    expect(decision.action, RssSubscriptionOpenAction.openArticleList);
    expect(decision.url, 'https://s.example/rss');
  });

  test('resolveSingleUrl 支持 sortUrl 的 :: 分支解析', () {
    final source = _source(
      url: 'https://fallback.example/rss',
      name: '单链接源',
      singleUrl: true,
      sortUrl: '栏目::https://target.example/article',
    );
    final result = RssSubscriptionHelper.resolveSingleUrl(source);
    expect(result.success, isTrue);
    expect(result.url, 'https://target.example/article');
  });

  test('resolveSingleUrl 支持 @js: 分支输出并可进入阅读链路', () {
    final source = _source(
      url: 'https://fallback.example/rss',
      name: '脚本单链接源',
      singleUrl: true,
      sortUrl: '@js:return "分类::https://reader.example/post/1";',
    );
    final runtime = _FakeJsRuntime(
      (_) =>
          '__SR_RSS_JS_OK__${Uri.encodeComponent('分类::https://reader.example/post/1')}',
    );

    final result = RssSubscriptionHelper.resolveSingleUrl(
      source,
      runtime: runtime,
    );
    expect(result.success, isTrue);
    expect(result.url, 'https://reader.example/post/1');

    final decision = RssSubscriptionHelper.decideOpenAction(
      source,
      runtime: runtime,
    );
    expect(decision.action, RssSubscriptionOpenAction.openReadDetail);
    expect(decision.url, 'https://reader.example/post/1');
  });

  test('decideOpenAction 对非 http singleUrl 走外部打开分支', () {
    final source = _source(
      url: 'https://fallback.example/rss',
      name: '外链源',
      singleUrl: true,
      sortUrl: '分类::legado://rss/open?id=1',
    );
    final decision = RssSubscriptionHelper.decideOpenAction(source);
    expect(decision.action, RssSubscriptionOpenAction.openExternal);
    expect(decision.url, 'legado://rss/open?id=1');
  });

  test('resolveSingleUrl 脚本失败时返回错误分支', () {
    final source = _source(
      url: 'https://fallback.example/rss',
      name: '脚本失败源',
      singleUrl: true,
      sortUrl: '<js>throw new Error("boom")</js>',
    );
    final runtime = _FakeJsRuntime(
      (_) => '__SR_RSS_JS_ERR__${Uri.encodeComponent('boom')}',
    );

    final result = RssSubscriptionHelper.resolveSingleUrl(
      source,
      runtime: runtime,
    );
    expect(result.success, isFalse);
    expect(result.errorMessage, contains('boom'));

    final decision = RssSubscriptionHelper.decideOpenAction(
      source,
      runtime: runtime,
    );
    expect(decision.action, RssSubscriptionOpenAction.showError);
    expect(decision.message, contains('boom'));
  });
}
