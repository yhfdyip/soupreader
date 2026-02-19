import 'package:flutter_test/flutter_test.dart';
import 'package:soupreader/features/rss/services/rss_default_xml_parser.dart';

void main() {
  test('默认 XML 解析：提取标题/链接/时间/描述/图片', () {
    const xml = '''
<rss>
  <channel>
    <item>
      <title>第一条</title>
      <link>https://example.com/a</link>
      <pubDate>2026-02-19</pubDate>
      <description><![CDATA[<p>desc-a</p><img src="https://img.example.com/a.jpg" />]]></description>
    </item>
    <item>
      <title>第二条</title>
      <link>https://example.com/b</link>
      <time>2026-02-20</time>
      <media:thumbnail url="https://img.example.com/b.jpg" />
      <content:encoded><![CDATA[正文-b]]></content:encoded>
    </item>
  </channel>
</rss>
''';

    final articles = RssDefaultXmlParser.parse(
      sortName: '默认分组',
      xml: xml,
      sourceUrl: 'https://source.example.com/rss',
    );

    expect(articles.length, 2);
    expect(articles[0].title, '第一条');
    expect(articles[0].link, 'https://example.com/a');
    expect(articles[0].pubDate, '2026-02-19');
    expect(articles[0].description, contains('desc-a'));
    expect(articles[0].image, 'https://img.example.com/a.jpg');
    expect(articles[0].origin, 'https://source.example.com/rss');
    expect(articles[0].sort, '默认分组');

    expect(articles[1].title, '第二条');
    expect(articles[1].link, 'https://example.com/b');
    expect(articles[1].pubDate, '2026-02-20');
    expect(articles[1].image, 'https://img.example.com/b.jpg');
    expect(articles[1].content, '正文-b');
  });

  test('enclosure 图片回退：当 media:thumbnail 缺失时使用 enclosure[type=image/*]', () {
    const xml = '''
<rss><channel><item>
  <title>封面回退</title>
  <link>https://example.com/c</link>
  <enclosure type="image/jpeg" url="https://img.example.com/c.jpg" />
</item></channel></rss>
''';
    final articles = RssDefaultXmlParser.parse(
      sortName: '默认分组',
      xml: xml,
      sourceUrl: 'https://source.example.com/rss',
    );

    expect(articles.length, 1);
    expect(articles.first.image, 'https://img.example.com/c.jpg');
  });
}
