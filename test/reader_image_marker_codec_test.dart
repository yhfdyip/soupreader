import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:soupreader/features/reader/services/reader_image_marker_codec.dart';
import 'package:soupreader/features/reader/widgets/reader_page_agent.dart';

void main() {
  test('reader image marker codec encode/decode round trip', () {
    const src = 'https://example.com/a/b/c.jpg?x=1&y=2';
    final marker = ReaderImageMarkerCodec.encode(src);
    expect(marker, startsWith(ReaderImageMarkerCodec.prefix));
    expect(marker, endsWith(ReaderImageMarkerCodec.suffix));
    expect(ReaderImageMarkerCodec.decode(marker), src);
    expect(ReaderImageMarkerCodec.decodeLine(marker), src);
  });

  test('reader image marker codec supports metadata and legacy payload', () {
    const src = 'https://example.com/cover.png';
    final marker = ReaderImageMarkerCodec.encode(
      src,
      width: 320,
      height: 180,
    );
    final meta = ReaderImageMarkerCodec.decodeMeta(marker);
    expect(meta, isNotNull);
    expect(meta!.src, src);
    expect(meta.width, 320);
    expect(meta.height, 180);

    final legacyPayload = base64UrlEncode(utf8.encode(src));
    final legacyMarker =
        '${ReaderImageMarkerCodec.prefix}$legacyPayload${ReaderImageMarkerCodec.suffix}';
    expect(ReaderImageMarkerCodec.decode(legacyMarker), src);
    expect(ReaderImageMarkerCodec.decodeLine(legacyMarker), src);
  });

  test('reader image marker codec size cache stores and deduplicates', () {
    ReaderImageMarkerCodec.clearResolvedSizeCache();
    const src = 'https://example.com/image.webp';
    expect(
      ReaderImageMarkerCodec.rememberResolvedSize(
        src,
        width: 640,
        height: 360,
      ),
      isTrue,
    );
    final size = ReaderImageMarkerCodec.lookupResolvedSize(src);
    expect(size, isNotNull);
    expect(size!.width, 640);
    expect(size.height, 360);
    expect(
      ReaderImageMarkerCodec.rememberResolvedSize(
        src,
        width: 640,
        height: 360,
      ),
      isFalse,
    );
  });

  test('reader image marker codec normalizes legacy url option cache key', () {
    ReaderImageMarkerCodec.clearResolvedSizeCache();
    const srcWithOption =
        'https://example.com/image.webp,{"headers":{"Referer":"https://example.com"}}';
    const srcWithOtherOption =
        'https://example.com/image.webp,{"header":{"User-Agent":"reader"}}';

    expect(
      ReaderImageMarkerCodec.rememberResolvedSize(
        srcWithOption,
        width: 600,
        height: 900,
      ),
      isTrue,
    );

    final hit = ReaderImageMarkerCodec.lookupResolvedSize(srcWithOtherOption);
    expect(hit, isNotNull);
    expect(hit!.width, 600);
    expect(hit.height, 900);
  });

  test('reader image marker codec supports snapshot restore', () {
    ReaderImageMarkerCodec.clearResolvedSizeCache();
    ReaderImageMarkerCodec.rememberResolvedSize(
      'https://example.com/1.jpg',
      width: 180,
      height: 320,
    );
    ReaderImageMarkerCodec.rememberResolvedSize(
      'https://example.com/2.jpg',
      width: 240,
      height: 420,
    );

    final snapshot = ReaderImageMarkerCodec.snapshotResolvedSizeCache(
      maxEntries: 8,
    );
    expect(snapshot.length, 2);

    ReaderImageMarkerCodec.clearResolvedSizeCache();
    final restored = ReaderImageMarkerCodec.restoreResolvedSizeCache(
      snapshot.map((key, value) => MapEntry(key, value)),
    );
    expect(restored, 2);
    expect(
      ReaderImageMarkerCodec.lookupResolvedSize('https://example.com/1.jpg'),
      isNotNull,
    );
    expect(
      ReaderImageMarkerCodec.lookupResolvedSize('https://example.com/2.jpg'),
      isNotNull,
    );
  });

  test('reader page agent paginates image marker in single mode', () {
    final marker =
        ReaderImageMarkerCodec.encode('https://example.com/cover.jpg');
    final pages = ReaderPageAgent.paginateContent(
      '第一段文本\n$marker\n第二段文本',
      120,
      220,
      18,
      lineHeight: 1.5,
      imageStyle: 'SINGLE',
    );

    expect(pages.length, greaterThanOrEqualTo(2));
    expect(
      pages.where(ReaderImageMarkerCodec.containsMarker).isNotEmpty,
      isTrue,
    );
  });

  test('reader page agent prefers intrinsic image size hints when available',
      () {
    const src = 'https://example.com/wide-cover.jpg';
    final markerWithHint = ReaderImageMarkerCodec.encode(
      src,
      width: 400,
      height: 100,
    );
    final markerWithoutHint = ReaderImageMarkerCodec.encode(src);

    final withHint = ReaderPageAgent.paginateContent(
      '第一段文本\n$markerWithHint\n第二段文本',
      160,
      220,
      18,
      lineHeight: 1.5,
      imageStyle: 'FULL',
    );
    final withoutHint = ReaderPageAgent.paginateContent(
      '第一段文本\n$markerWithoutHint\n第二段文本',
      160,
      220,
      18,
      lineHeight: 1.5,
      imageStyle: 'FULL',
    );

    // 宽图在 FULL 模式下高度更小，应不比无尺寸提示时产生更多页。
    expect(withHint.length, lessThanOrEqualTo(withoutHint.length));
  });
}
